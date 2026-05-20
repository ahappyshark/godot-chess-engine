extends Node

func _ready() -> void:
	MagicGenerator.generate_and_save()

class MagicGenerator:
	const ROOK_SHIFTS: Array[int] = [
		52,53,53,53,53,53,53,52,
		53,54,54,54,54,54,54,53,
		53,54,54,54,54,54,54,53,
		53,54,54,54,54,54,54,53,
		53,54,54,54,54,54,54,53,
		53,54,54,54,54,54,54,53,
		53,54,54,54,54,54,54,53,
		52,53,53,53,53,53,53,52
	]
	const BISHOP_SHIFTS: Array[int] = [
		58,59,59,59,59,59,59,58,
		59,59,59,59,59,59,59,59,
		59,59,57,57,57,57,59,59,
		59,59,57,55,55,57,59,59,
		59,59,57,55,55,57,59,59,
		59,59,57,57,57,57,59,59,
		59,59,59,59,59,59,59,59,
		58,59,59,59,59,59,59,58
	]

	static func generate_and_save() -> void:
		print("Generating magic numbers...")
		var rook_magics: Array[int] = []
		var bishop_magics: Array[int] = []
		rook_magics.resize(64)
		bishop_magics.resize(64)

		for sq in range(64):
			var rook_mask = _rook_mask(sq)
			rook_magics[sq] = _find_magic(sq, rook_mask, true, ROOK_SHIFTS[sq])
			print("Rook sq %d: %d" % [sq, rook_magics[sq]])

		for sq in range(64):
			var bishop_mask = _bishop_mask(sq)
			bishop_magics[sq] = _find_magic(sq, bishop_mask, false, BISHOP_SHIFTS[sq])
			print("Bishop sq %d: %d" % [sq, bishop_magics[sq]])

		_write_output(rook_magics, bishop_magics)

	static func _find_magic(square: int, mask: int, is_rook: bool, shift: int) -> int:
		var bits = _pop_count(mask)
		var num_occupancies = 1 << bits

		var occupancies: Array[int] = []
		var attacks: Array[int] = []
		occupancies.resize(num_occupancies)
		attacks.resize(num_occupancies)

		for i in num_occupancies:
			occupancies[i] = _index_to_occupancy(i, bits, mask)
			attacks[i] = _compute_attacks(square, occupancies[i], is_rook)

		for _attempt in range(100000000):
			var magic = _random_sparse_int()
			var used: Dictionary = {}
			var failed = false

			for i in num_occupancies:
				var key = _lsr(occupancies[i] * magic, shift)
				if not used.has(key):
					used[key] = attacks[i]
				elif used[key] != attacks[i]:
					failed = true
					break

			if not failed:
				return magic

		push_error("Failed to find magic for square %d" % square)
		return 0

	static func _index_to_occupancy(index: int, bits: int, mask: int) -> int:
		var occupancy = 0
		var m = mask
		for i in bits:
			var lsb = m & -m
			m &= m - 1
			if (index >> i) & 1:
				occupancy |= lsb
		return occupancy

	static func _compute_attacks(square: int, blockers: int, is_rook: bool) -> int:
		var attacks = 0
		var directions = [8, -8, 1, -1] if is_rook else [9, 7, -9, -7]

		for dir in directions:
			var sq = square
			for _step in range(7):
				var prev = sq
				sq += dir
				if sq < 0 or sq > 63:
					break
				var prev_file = prev % 8
				var curr_file = sq % 8
				if abs(curr_file - prev_file) > 1:
					break
				attacks |= 1 << sq
				if (blockers >> sq) & 1:
					break

		return attacks

	static func _rook_mask(square: int) -> int:
		var mask = 0
		var rank = square / 8
		var file = square % 8
		for r in range(1, 7):
			if r != rank:
				mask |= 1 << (r * 8 + file)
		for f in range(1, 7):
			if f != file:
				mask |= 1 << (rank * 8 + f)
		return mask

	static func _bishop_mask(square: int) -> int:
		var mask = 0
		var rank = square / 8
		var file = square % 8
		for dirs in [[1,1],[1,-1],[-1,1],[-1,-1]]:
			var r = rank + dirs[0]
			var f = file + dirs[1]
			while r >= 1 and r <= 6 and f >= 1 and f <= 6:
				mask |= 1 << (r * 8 + f)
				r += dirs[0]
				f += dirs[1]
		return mask

	static func _random_sparse_int() -> int:
		return (randi() | randi() << 32) & (randi() | randi() << 32) & (randi() | randi() << 32) & 0x7FFFFFFFFFFFFFFF

	static func _lsr(value: int, shift: int) -> int:
		if shift <= 0: return value
		if shift >= 64: return 0
		return (value >> shift) & (0x7FFFFFFFFFFFFFFF >> (shift - 1))

	static func _pop_count(b: int) -> int:
		var count = 0
		while b != 0:
			b &= b - 1
			count += 1
		return count

	static func _write_output(rook_magics: Array[int], bishop_magics: Array[int]) -> void:
		var output = "class_name PrecomputedMagics\n\n"

		output += "const ROOK_SHIFTS: Array[int] = [\n\t"
		for i in 64:
			output += str(ROOK_SHIFTS[i])
			output += ",\n\t" if (i + 1) % 8 == 0 and i != 63 else ", "
		output += "\n]\n\n"

		output += "const BISHOP_SHIFTS: Array[int] = [\n\t"
		for i in 64:
			output += str(BISHOP_SHIFTS[i])
			output += ",\n\t" if (i + 1) % 8 == 0 and i != 63 else ", "
		output += "\n]\n\n"

		output += "const ROOK_MAGICS: Array[int] = [\n\t"
		for i in 64:
			output += str(rook_magics[i])
			output += ",\n\t" if (i + 1) % 8 == 0 and i != 63 else ", "
		output += "\n]\n\n"

		output += "const BISHOP_MAGICS: Array[int] = [\n\t"
		for i in 64:
			output += str(bishop_magics[i])
			output += ",\n\t" if (i + 1) % 8 == 0 and i != 63 else ", "
		output += "\n]\n"
		var file_name: String = "res://chess_data/move_generation/magics/precomputed_magics.gd"
		var file = FileAccess.open(file_name, FileAccess.WRITE)
		if file:
			file.store_string(output)
			file.close()
			print("Written to %s" % file_name)
		else:
			print("File write failed — here's the output to copy manually:\n")
			print(output)
