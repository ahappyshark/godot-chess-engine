class_name PieceSquareTable

static var _tables: Array

static func _static_init() -> void:
	_tables = []
	_tables.resize(Piece.MAX_PIECE_INDEX + 1)
	_tables[Piece.make_piece(Piece.PAWN, Piece.WHITE)] = pawns
	_tables[Piece.make_piece(Piece.ROOK, Piece.WHITE)] = rooks
	_tables[Piece.make_piece(Piece.KNIGHT, Piece.WHITE)] = knights
	_tables[Piece.make_piece(Piece.BISHOP, Piece.WHITE)] = bishops
	_tables[Piece.make_piece(Piece.QUEEN, Piece.WHITE)] = queens

	_tables[Piece.make_piece(Piece.KING, Piece.WHITE)] = king_start
	_tables[Piece.make_piece(Piece.PAWN, Piece.BLACK)] = get_flipped_table(pawns)
	_tables[Piece.make_piece(Piece.ROOK, Piece.BLACK)] = get_flipped_table(rooks)
	_tables[Piece.make_piece(Piece.KNIGHT, Piece.BLACK)] = get_flipped_table(knights)
	_tables[Piece.make_piece(Piece.BISHOP, Piece.BLACK)] = get_flipped_table(bishops)
	_tables[Piece.make_piece(Piece.QUEEN, Piece.BLACK)] = get_flipped_table(queens)
	_tables[Piece.make_piece(Piece.KING, Piece.BLACK)] = get_flipped_table(king_start)

static func read(table: Array[int], square: int, is_white: bool) -> int:
	if is_white:
		var file: int = BoardHelper.file_index(square)
		var rank: int = BoardHelper.rank_index(square)
		rank = 7 - rank
		square = BoardHelper.index_from_values(file, rank)
	return table[square]

static func read_two(piece: int, square: int) -> int:
	return _tables[piece][square]

static func get_flipped_table(table: Array[int]) -> Array[int]:
	var flipped_table: Array[int] = []
	flipped_table.resize(table.size())
	for i: int in table.size():
		var coord: Coord = Coord.coord_from_square_index(i)
		var flipped_coord: Coord = Coord.new(coord.file_index, 7 - coord.rank_index)
		flipped_table[BoardHelper.index_from_values(flipped_coord.file_index, flipped_coord.rank_index)] = table[i]
	return flipped_table

static var pawns: Array[int] = [
	 0,   0,   0,   0,   0,   0,   0,   0,
	50,  50,  50,  50,  50,  50,  50,  50,
	10,  10,  20,  30,  30,  20,  10,  10,
	 5,   5,  10,  25,  25,  10,   5,   5,
	 0,   0,   0,  20,  20,   0,   0,   0,
	 5,  -5, -10,   0,   0, -10,  -5,   5,
	 5,  10,  10, -20, -20,  10,  10,   5,
	 0,   0,   0,   0,   0,   0,   0,   0
]

static var pawns_end: Array[int] = [
	 0,   0,   0,   0,   0,   0,   0,   0,
	80,  80,  80,  80,  80,  80,  80,  80,
	50,  50,  50,  50,  50,  50,  50,  50,
	30,  30,  30,  30,  30,  30,  30,  30,
	20,  20,  20,  20,  20,  20,  20,  20,
	10,  10,  10,  10,  10,  10,  10,  10,
	10,  10,  10,  10,  10,  10,  10,  10,
	 0,   0,   0,   0,   0,   0,   0,   0
]

static var rooks: Array[int] = [
	 0,  0,  0,  0,  0,  0,  0,  0,
	 5, 10, 10, 10, 10, 10, 10,  5,
	-5,  0,  0,  0,  0,  0,  0, -5,
	-5,  0,  0,  0,  0,  0,  0, -5,
	-5,  0,  0,  0,  0,  0,  0, -5,
	-5,  0,  0,  0,  0,  0,  0, -5,
	-5,  0,  0,  0,  0,  0,  0, -5,
	 0,  0,  0,  5,  5,  0,  0,  0
]

static var knights: Array[int] = [
	-50,-40,-30,-30,-30,-30,-40,-50,
	-40,-20,  0,  0,  0,  0,-20,-40,
	-30,  0, 10, 15, 15, 10,  0,-30,
	-30,  5, 15, 20, 20, 15,  5,-30,
	-30,  0, 15, 20, 20, 15,  0,-30,
	-30,  5, 10, 15, 15, 10,  5,-30,
	-40,-20,  0,  5,  5,  0,-20,-40,
	-50,-40,-30,-30,-30,-30,-40,-50,
]

static var bishops: Array[int] = [
	-20,-10,-10,-10,-10,-10,-10,-20,
	-10,  0,  0,  0,  0,  0,  0,-10,
	-10,  0,  5, 10, 10,  5,  0,-10,
	-10,  5,  5, 10, 10,  5,  5,-10,
	-10,  0, 10, 10, 10, 10,  0,-10,
	-10, 10, 10, 10, 10, 10, 10,-10,
	-10,  5,  0,  0,  0,  0,  5,-10,
	-20,-10,-10,-10,-10,-10,-10,-20,
]

static var queens: Array[int] = [
	-20,-10,-10, -5, -5,-10,-10,-20,
	-10,  0,  0,  0,  0,  0,  0,-10,
	-10,  0,  5,  5,  5,  5,  0,-10,
	 -5,  0,  5,  5,  5,  5,  0, -5,
	  0,  0,  5,  5,  5,  5,  0, -5,
	-10,  5,  5,  5,  5,  5,  0,-10,
	-10,  0,  5,  0,  0,  0,  0,-10,
	-20,-10,-10, -5, -5,-10,-10,-20
]

static var king_start: Array[int] = [
	-80, -70, -70, -70, -70, -70, -70, -80,
	-60, -60, -60, -60, -60, -60, -60, -60,
	-40, -50, -50, -60, -60, -50, -50, -40,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-20, -30, -30, -40, -40, -30, -30, -20,
	-10, -20, -20, -20, -20, -20, -20, -10,
	 20,  20,  -5,  -5,  -5,  -5,  20,  20,
	 20,  30,  10,   0,   0,  10,  30,  20
]

static var king_end: Array[int] = [
	-20, -10, -10, -10, -10, -10, -10, -20,
	 -5,   0,   5,   5,   5,   5,   0,  -5,
	-10,  -5,  20,  30,  30,  20,  -5, -10,
	-15, -10,  35,  45,  45,  35, -10, -15,
	-20, -15,  30,  40,  40,  30, -15, -20,
	-25, -20,  20,  25,  25,  20, -20, -25,
	-30, -25,   0,   0,   0,   0, -25, -30,
	-50, -30, -30, -30, -30, -30, -30, -50
]
