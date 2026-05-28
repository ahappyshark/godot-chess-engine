class_name BitBoardUtility

const file_a: int = 0x101010101010101

const rank_1: int = 0b11111111
const rank_2: int = rank_1 << 8
const rank_3: int = rank_2 << 8
const rank_4: int = rank_3 << 8
const rank_5: int = rank_4 << 8
const rank_6: int = rank_5 << 8
const rank_7: int = rank_6 << 8
const rank_8: int = rank_7 << 8  # wraps to negative as signed — correct bit pattern for bitwise ops
const not_a_file: int = ~file_a
const not_h_file: int = ~(file_a << 7)

static var knight_attacks: Array[int] = []
static var king_moves: Array[int] = []
static var white_pawn_attacks: Array[int] = []
static var black_pawn_attacks: Array[int] = []

# Logical (unsigned) right shift. GDScript >> is arithmetic (sign-extending),
# which corrupts bitboards with bit 63 set. This masks off the extended sign bits.
static func lsr(value: int, shift_int: int) -> int:
	if shift_int <= 0:
		return value
	if shift_int >= 64:
		return 0
	return (value >> shift_int) & (0x7FFFFFFFFFFFFFFF >> (shift_int - 1))

# Returns [new_bitboard, square_index] — pops the least-significant set bit.
static func pop_lsb(b: int) -> Array:
	var i: int = trailing_zero_count(b)
	var new_b: int = b & (b - 1)
	return [new_b, i]

static func popcount(b: int) -> int:
	var count: int = 0
	while b != 0:
		b &= b - 1
		count += 1
	return count

static func trailing_zero_count(b: int) -> int:
	if b == 0:
		return 64
	var count: int = 0
	while (b & 1) == 0:
		b >>= 1
		count += 1
	return count

static func set_square(bitboard: int, square_index: int) -> int:
	bitboard |= 1 << square_index
	return bitboard

static func clear_square(bitboard: int, square_index: int) -> int:
	bitboard &= ~(1 << square_index)
	return bitboard

static func toggle_square(bitboard: int, square_index: int) -> int:
	bitboard ^= 1 << square_index
	return bitboard

static func toggle_squares(bitboard: int, square_a: int, square_b: int) -> int:
	bitboard ^= (1 << square_a | 1 << square_b)
	return bitboard

static func contains_square(bitboard: int, square: int) -> bool:
	return ((bitboard >> square) & 1) != 0

static func pawn_attacks(pawn_bitboard: int, is_white: bool) -> int:
	if is_white:
		return ((pawn_bitboard << 9) & not_a_file) | ((pawn_bitboard << 7) & not_h_file)
	# Use lsr for black — right-shifting a negative bitboard (pawns on ranks 7-8) sign-extends.
	return ((lsr(pawn_bitboard, 7)) & not_a_file) | ((lsr(pawn_bitboard, 9)) & not_h_file)

static func shift(bitboard: int, num_squares_to_shift: int) -> int:
	if num_squares_to_shift > 0:
		return bitboard << num_squares_to_shift
	return lsr(bitboard, -num_squares_to_shift)

static func initialize() -> void:
	knight_attacks.resize(64)
	king_moves.resize(64)
	white_pawn_attacks.resize(64)
	black_pawn_attacks.resize(64)

	var ortho_dir: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1)]
	var diag_dir: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(1, -1)]
	var knight_jumps: Array[Vector2i] = [Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2), Vector2i(-1, -2)]

	for y in range(8):
		for x in range(8):
			var square_index: int = y * 8 + x

			for dir_index in range(4):
				for dst in range(1, 8):
					var ortho_x: int = x + ortho_dir[dir_index].x * dst
					var ortho_y: int = y + ortho_dir[dir_index].y * dst
					var diag_x: int = x + diag_dir[dir_index].x * dst
					var diag_y: int = y + diag_dir[dir_index].y * dst

					var ortho_target: int = _valid_square_index(ortho_x, ortho_y)
					if ortho_target != -1 and dst == 1:
						king_moves[square_index] |= 1 << ortho_target

					var diag_target: int = _valid_square_index(diag_x, diag_y)
					if diag_target != -1 and dst == 1:
						king_moves[square_index] |= 1 << diag_target

			# Knight and pawn tables computed once per square (outside dir_index loop)
			for jump in knight_jumps:
				var knight_target: int = _valid_square_index(x + jump.x, y + jump.y)
				if knight_target != -1:
					knight_attacks[square_index] |= 1 << knight_target

			var wp_right: int = _valid_square_index(x + 1, y + 1)
			if wp_right != -1:
				white_pawn_attacks[square_index] |= 1 << wp_right

			var wp_left: int = _valid_square_index(x - 1, y + 1)
			if wp_left != -1:
				white_pawn_attacks[square_index] |= 1 << wp_left

			var bp_right: int = _valid_square_index(x + 1, y - 1)
			if bp_right != -1:
				black_pawn_attacks[square_index] |= 1 << bp_right

			var bp_left: int = _valid_square_index(x - 1, y - 1)
			if bp_left != -1:
				black_pawn_attacks[square_index] |= 1 << bp_left

static func _valid_square_index(x: int, y: int) -> int:
	if x >= 0 and x < 8 and y >= 0 and y < 8:
		return y * 8 + x
	return -1
