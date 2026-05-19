class_name PrecomputedEvaluationData

static var pawn_shield_squares_white: Array
static var pawn_shield_squares_black: Array

static func _static_init() -> void:
	pawn_shield_squares_white = []
	pawn_shield_squares_white.resize(64)
	pawn_shield_squares_black = []
	pawn_shield_squares_black.resize(64)
	for square_index: int in 64:
		_create_pawn_shield_square(square_index)

static func _create_pawn_shield_square(square_index: int) -> void:
	var shield_indices_white: Array[int] = []
	var shield_indices_black: Array[int] = []
	var coord: Coord = Coord.new(BoardHelper.file_index(square_index), BoardHelper.rank_index(square_index))
	var rank: int = coord.rank_index
	var file: int = clampi(coord.file_index, 1, 6)

	for file_offset: int in range(-1, 2):
		_add_if_valid(Coord.new(file + file_offset, rank + 1), shield_indices_white)
		_add_if_valid(Coord.new(file + file_offset, rank - 1), shield_indices_black)

	for file_offset: int in range(-1, 2):
		_add_if_valid(Coord.new(file + file_offset, rank + 2), shield_indices_white)
		_add_if_valid(Coord.new(file + file_offset, rank - 2), shield_indices_black)

	pawn_shield_squares_white[square_index] = shield_indices_white
	pawn_shield_squares_black[square_index] = shield_indices_black

static func _add_if_valid(coord: Coord, list: Array[int]) -> void:
	if coord.is_valid_square():
		list.append(BoardHelper.index_from_values(coord.file_index, coord.rank_index))
