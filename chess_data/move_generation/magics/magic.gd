extends Node

static var rook_mask: Array[int]
static var bishop_mask: Array[int]
static var rook_attacks: Array
static var bishop_attacks: Array

func _ready() -> void:
	rook_mask = []
	rook_mask.resize(64)
	bishop_mask = []
	bishop_mask.resize(64)

	for i in range(64):
		rook_mask[i] = MagicHelper.create_movement_mask(i, true)
		bishop_mask[i] = MagicHelper.create_movement_mask(i, false)

	rook_attacks = []
	rook_attacks.resize(64)
	bishop_attacks = []
	bishop_attacks.resize(64)

	for i in range(64):
		rook_attacks[i] = _create_table(i, true, PrecomputedMagics.ROOK_MAGICS[i], PrecomputedMagics.ROOK_SHIFTS[i])
		bishop_attacks[i] = _create_table(i, false, PrecomputedMagics.BISHOP_MAGICS[i], PrecomputedMagics.BISHOP_SHIFTS[i])

func get_slider_attacks(square: int, blockers: int, ortho: bool) -> int:
	return get_rook_attacks(square, blockers) if ortho else get_bishop_attacks(square, blockers)

func get_rook_attacks(square: int, blockers: int) -> int:
	var shift: int = PrecomputedMagics.ROOK_SHIFTS[square]
	var key: int = BitBoardUtility.lsr((blockers & rook_mask[square]) * PrecomputedMagics.ROOK_MAGICS[square], shift)
	return rook_attacks[square][key]

func get_bishop_attacks(square: int, blockers: int) -> int:
	var shift: int = PrecomputedMagics.BISHOP_SHIFTS[square]
	var key: int = BitBoardUtility.lsr((blockers & bishop_mask[square]) * PrecomputedMagics.BISHOP_MAGICS[square], shift)
	return bishop_attacks[square][key]

func _create_table(square: int, rook: bool, magic: int, left_shift: int) -> Array:
	var num_bits: int = 64 - left_shift
	var lookup_size: int = 1 << num_bits
	var table: Array = []
	table.resize(lookup_size)
	table.fill(0)

	var movement_mask: int = MagicHelper.create_movement_mask(square, rook)
	var blocker_patterns: Array = MagicHelper.create_all_blocker_bitboards(movement_mask)

	for pattern in blocker_patterns:
		var index: int = BitBoardUtility.lsr(pattern * magic, left_shift)
		var moves: int = MagicHelper.legal_move_bitboard_from_blockers(square, pattern, rook)
		table[index] = moves

	return table
