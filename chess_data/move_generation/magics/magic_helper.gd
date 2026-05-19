class_name MagicHelper

static func create_all_blocker_bitboards(movement_mask: int) -> Array[int]:
	var move_square_indices: Array[int] = []

	for i: int in range(64):
		if ((movement_mask >> i) & 1) == 1:
			move_square_indices.append(i)

	var num_patterns: int = 1 << move_square_indices.size()
	var blocker_bitboards: Array[int] = []
	blocker_bitboards.resize(num_patterns)
	blocker_bitboards.fill(0)

	for pattern_index: int in range(num_patterns):
		for bit_index: int in range(move_square_indices.size()):
			var bit: int = (pattern_index >> bit_index) & 1
			blocker_bitboards[pattern_index] |= bit << move_square_indices[bit_index]

	return blocker_bitboards


static func create_movement_mask(square_index: int, ortho: bool) -> int:
	var mask: int = 0
	var directions: Array[Vector2i] = BoardHelper.rook_directions if ortho else BoardHelper.bishop_directions
	var start_coord: Vector2i = Vector2i(BoardHelper.file_index(square_index), BoardHelper.rank_index(square_index))

	for dir: Vector2i in directions:
		for dst: int in range(1, 8):
			var coord: Vector2i = start_coord + dir * dst
			var next_coord: Vector2i = start_coord + dir * (dst + 1)

			if coord.x >= 0 and coord.x < 8 and coord.y >= 0 and coord.y < 8:
				# Only include this square if the next one is also on-board (i.e. not an edge blocker)
				if next_coord.x >= 0 and next_coord.x < 8 and next_coord.y >= 0 and next_coord.y < 8:
					mask = BitBoardUtility.set_square(mask, BoardHelper.index_from_values(coord.x, coord.y))
			else:
				break

	return mask


static func legal_move_bitboard_from_blockers(start_square: int, blocker_bitboard: int, ortho: bool) -> int:
	var bitboard: int = 0
	var directions: Array[Vector2i] = BoardHelper.rook_directions if ortho else BoardHelper.bishop_directions
	var start_coord: Vector2i = Vector2i(BoardHelper.file_index(start_square), BoardHelper.rank_index(start_square))

	for dir: Vector2i in directions:
		for dst: int in range(1, 8):
			var coord: Vector2i = start_coord + dir * dst

			if coord.x >= 0 and coord.x < 8 and coord.y >= 0 and coord.y < 8:
				var square_index: int = BoardHelper.index_from_values(coord.x, coord.y)
				bitboard = BitBoardUtility.set_square(bitboard, square_index)
				if BitBoardUtility.contains_square(blocker_bitboard, square_index):
					break
			else:
				break

	return bitboard
