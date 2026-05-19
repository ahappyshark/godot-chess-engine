class_name PrecomputedMoveData

static var align_mask: Array
static var dir_ray_mask: Array

static var direction_offsets: Array[int] = [8, -8, -1, 1, 7, -7, 9, -9]

static var _dir_offsets_2d: Array = [
	Coord.new(0, 1),
	Coord.new(0, -1),
	Coord.new(-1, 0),
	Coord.new(1, 0),
	Coord.new(-1, 1),
	Coord.new(1, -1),
	Coord.new(1, 1),
	Coord.new(-1, -1),
]

static var num_squares_to_edge: Array
static var knight_moves: Array
static var king_moves: Array

static var pawn_attack_directions: Array = [
	[4, 6],
	[7, 5],
]

static var pawn_attacks_white: Array
static var pawn_attacks_black: Array
static var direction_lookup: Array[int]

static var king_attack_bitboards: Array[int]
static var knight_attack_bitboards: Array[int]
static var pawn_attack_bitboards: Array

static var rook_moves: Array[int]
static var bishop_moves: Array[int]
static var queen_moves: Array[int]

static var orthogonal_distance: Array
static var king_distance: Array
static var centre_manhattan_distance: Array[int]


static func num_rook_moves_to_reach_square(start_square: int, target_square: int) -> int:
	return orthogonal_distance[start_square][target_square]


static func num_king_moves_to_reach_square(start_square: int, target_square: int) -> int:
	return king_distance[start_square][target_square]


static func _static_init() -> void:
	pawn_attacks_white = []
	pawn_attacks_white.resize(64)
	pawn_attacks_black = []
	pawn_attacks_black.resize(64)
	num_squares_to_edge = []
	num_squares_to_edge.resize(64)
	knight_moves = []
	knight_moves.resize(64)
	king_moves = []
	king_moves.resize(64)

	rook_moves = []
	rook_moves.resize(64)
	rook_moves.fill(0)
	bishop_moves = []
	bishop_moves.resize(64)
	bishop_moves.fill(0)
	queen_moves = []
	queen_moves.resize(64)
	queen_moves.fill(0)

	var all_knight_jumps: Array[int] = [15, 17, -17, -15, 10, -6, 6, -10]
	knight_attack_bitboards = []
	knight_attack_bitboards.resize(64)
	knight_attack_bitboards.fill(0)
	king_attack_bitboards = []
	king_attack_bitboards.resize(64)
	king_attack_bitboards.fill(0)
	pawn_attack_bitboards = []
	pawn_attack_bitboards.resize(64)

	for square_index in 64:
		var y: int = square_index / 8
		var x: int = square_index - y * 8

		var north: int = 7 - y
		var south: int = y
		var west: int = x
		var east: int = 7 - x

		num_squares_to_edge[square_index] = []
		num_squares_to_edge[square_index].resize(8)
		num_squares_to_edge[square_index][0] = north
		num_squares_to_edge[square_index][1] = south
		num_squares_to_edge[square_index][2] = west
		num_squares_to_edge[square_index][3] = east
		num_squares_to_edge[square_index][4] = min(north, west)
		num_squares_to_edge[square_index][5] = min(south, east)
		num_squares_to_edge[square_index][6] = min(north, east)
		num_squares_to_edge[square_index][7] = min(south, west)

		var legal_knight_jumps: Array = []
		var knight_bitboard: int = 0
		for knight_jump_delta in all_knight_jumps:
			var knight_jump_square: int = square_index + knight_jump_delta
			if knight_jump_square >= 0 and knight_jump_square < 64:
				var knight_square_y: int = knight_jump_square / 8
				var knight_square_x: int = knight_jump_square - knight_square_y * 8
				var max_coord_move_dst: int = max(abs(x - knight_square_x), abs(y - knight_square_y))
				if max_coord_move_dst == 2:
					legal_knight_jumps.append(knight_jump_square)
					knight_bitboard |= 1 << knight_jump_square
		knight_moves[square_index] = legal_knight_jumps
		knight_attack_bitboards[square_index] = knight_bitboard

		var legal_king_moves: Array = []
		for king_move_delta in direction_offsets:
			var king_move_square: int = square_index + king_move_delta
			if king_move_square >= 0 and king_move_square < 64:
				var king_square_y: int = king_move_square / 8
				var king_square_x: int = king_move_square - king_square_y * 8
				var max_coord_move_dst: int = max(abs(x - king_square_x), abs(y - king_square_y))
				if max_coord_move_dst == 1:
					legal_king_moves.append(king_move_square)
					king_attack_bitboards[square_index] |= 1 << king_move_square
		king_moves[square_index] = legal_king_moves

		var pawn_captures_white: Array = []
		var pawn_captures_black: Array = []
		pawn_attack_bitboards[square_index] = [0, 0]
		if x > 0:
			if y < 7:
				pawn_captures_white.append(square_index + 7)
				pawn_attack_bitboards[square_index][Board.WHITE_INDEX] |= 1 << (square_index + 7)
			if y > 0:
				pawn_captures_black.append(square_index - 9)
				pawn_attack_bitboards[square_index][Board.BLACK_INDEX] |= 1 << (square_index - 9)
		if x < 7:
			if y < 7:
				pawn_captures_white.append(square_index + 9)
				pawn_attack_bitboards[square_index][Board.WHITE_INDEX] |= 1 << (square_index + 9)
			if y > 0:
				pawn_captures_black.append(square_index - 7)
				pawn_attack_bitboards[square_index][Board.BLACK_INDEX] |= 1 << (square_index - 7)
		pawn_attacks_white[square_index] = pawn_captures_white
		pawn_attacks_black[square_index] = pawn_captures_black

		for direction_index in 4:
			var current_dir_offset: int = direction_offsets[direction_index]
			for n in num_squares_to_edge[square_index][direction_index]:
				var target_square: int = square_index + current_dir_offset * (n + 1)
				rook_moves[square_index] |= 1 << target_square

		for direction_index in range(4, 8):
			var current_dir_offset: int = direction_offsets[direction_index]
			for n in num_squares_to_edge[square_index][direction_index]:
				var target_square: int = square_index + current_dir_offset * (n + 1)
				bishop_moves[square_index] |= 1 << target_square

		queen_moves[square_index] = rook_moves[square_index] | bishop_moves[square_index]

	direction_lookup = []
	direction_lookup.resize(127)
	for i in 127:
		var offset: int = i - 63
		var abs_offset: int = abs(offset)
		var abs_dir: int = 1
		if abs_offset % 9 == 0:
			abs_dir = 9
		elif abs_offset % 8 == 0:
			abs_dir = 8
		elif abs_offset % 7 == 0:
			abs_dir = 7
		direction_lookup[i] = abs_dir * sign(offset)

	orthogonal_distance = []
	orthogonal_distance.resize(64)
	king_distance = []
	king_distance.resize(64)
	centre_manhattan_distance = []
	centre_manhattan_distance.resize(64)
	centre_manhattan_distance.fill(0)

	for square_a in 64:
		orthogonal_distance[square_a] = []
		orthogonal_distance[square_a].resize(64)
		orthogonal_distance[square_a].fill(0)
		king_distance[square_a] = []
		king_distance[square_a].resize(64)
		king_distance[square_a].fill(0)

		var coord_a: Coord = BoardHelper.coord_from_index(square_a)
		var file_dst_from_centre: int = max(3 - coord_a.file_index, coord_a.file_index - 4)
		var rank_dst_from_centre: int = max(3 - coord_a.rank_index, coord_a.rank_index - 4)
		centre_manhattan_distance[square_a] = file_dst_from_centre + rank_dst_from_centre

		for square_b in 64:
			var coord_b: Coord = BoardHelper.coord_from_index(square_b)
			var rank_distance: int = abs(coord_a.rank_index - coord_b.rank_index)
			var file_distance: int = abs(coord_a.file_index - coord_b.file_index)
			orthogonal_distance[square_a][square_b] = file_distance + rank_distance
			king_distance[square_a][square_b] = max(file_distance, rank_distance)

	align_mask = []
	align_mask.resize(64)
	for square_a in 64:
		align_mask[square_a] = []
		align_mask[square_a].resize(64)
		align_mask[square_a].fill(0)

	for square_a in 64:
		for square_b in 64:
			var c_a: Coord = BoardHelper.coord_from_index(square_a)
			var c_b: Coord = BoardHelper.coord_from_index(square_b)
			var delta: Coord = c_b.minus(c_a)
			var dir: Coord = Coord.new(sign(delta.file_index), sign(delta.rank_index))
			for i in range(-8, 8):
				var coord: Coord = BoardHelper.coord_from_index(square_a).plus(dir.multiply(i))
				if coord.is_valid_square():
					align_mask[square_a][square_b] |= 1 << BoardHelper.index_from_coord(coord)

	dir_ray_mask = []
	dir_ray_mask.resize(8)
	for dir_index in 8:
		dir_ray_mask[dir_index] = []
		dir_ray_mask[dir_index].resize(64)
		dir_ray_mask[dir_index].fill(0)

	for dir_index in _dir_offsets_2d.size():
		for square_index in 64:
			var square: Coord = BoardHelper.coord_from_index(square_index)
			for i in 8:
				var coord: Coord = square.plus(_dir_offsets_2d[dir_index].multiply(i))
				if coord.is_valid_square():
					dir_ray_mask[dir_index][square_index] |= 1 << BoardHelper.index_from_coord(coord)
				else:
					break
