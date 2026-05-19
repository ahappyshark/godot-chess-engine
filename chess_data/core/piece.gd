class_name Piece

const NONE: int = 0
const KING: int = 1
const PAWN: int = 2
const KNIGHT: int = 3
const BISHOP: int = 4
const ROOK: int = 5
const QUEEN: int = 6
const WHITE: int = 0
const BLACK: int = 8

const WHITE_PAWN: int = PAWN | WHITE
const WHITE_KNIGHT: int = KNIGHT | WHITE
const WHITE_BISHOP: int = BISHOP | WHITE
const WHITE_ROOK: int = ROOK | WHITE
const WHITE_QUEEN: int = QUEEN | WHITE
const WHITE_KING: int = KING | WHITE

const BLACK_PAWN: int = PAWN | BLACK
const BLACK_KNIGHT: int = KNIGHT | BLACK
const BLACK_BISHOP: int = BISHOP | BLACK
const BLACK_ROOK: int = ROOK | BLACK
const BLACK_QUEEN: int = QUEEN | BLACK
const BLACK_KING: int = KING | BLACK

const MAX_PIECE_INDEX: int = BLACK_KING
const COLOR_MASK: int = 8
const TYPE_MASK: int = 7

static var piece_indices: Array[int] = [
	WHITE_PAWN, WHITE_KNIGHT, WHITE_BISHOP, WHITE_ROOK, WHITE_QUEEN, WHITE_KING,
	BLACK_PAWN, BLACK_KNIGHT, BLACK_BISHOP, BLACK_ROOK, BLACK_QUEEN, BLACK_KING
]

static func make_piece(p_type: int, p_color: int) -> int:
	return p_type | p_color

static func piece_color(piece: int) -> int:
	return piece & COLOR_MASK

static func piece_type(piece: int) -> int:
	return piece & TYPE_MASK

static func is_color(piece: int, color: int) -> bool:
	return (piece & color) != 0

static func is_white(piece: int) -> bool:
	return is_color(piece, WHITE)

static func is_opponent_color(piece: int, color: int) -> bool:
	return (piece & color) == 0

static func is_orthogonal_slider(piece: int) -> bool:
	return piece_type(piece) == QUEEN or piece_type(piece) == ROOK

static func is_diagonal_slider(piece: int) -> bool:
	return piece_type(piece) == QUEEN or piece_type(piece) == BISHOP

static func is_sliding_piece(piece: int) -> bool:
	return piece_type(piece) == BISHOP or piece_type(piece) == ROOK or piece_type(piece) == QUEEN

static func get_piece_type_from_symbol(symbol: String) -> int:
	symbol = symbol.to_upper()
	match symbol:
		'R': return ROOK
		'N': return KNIGHT
		'B': return BISHOP
		'Q': return QUEEN
		'K': return KING
		'P': return PAWN
		_: return NONE

static func get_symbol(piece: int) -> String:
	var type: int = piece_type(piece)
	var symbol: String
	match type:
		PAWN:   symbol = "P"
		KNIGHT: symbol = "N"
		BISHOP: symbol = "B"
		ROOK:   symbol = "R"
		QUEEN:  symbol = "Q"
		KING:   symbol = "K"
		_:      symbol = "?"
	return symbol if is_white(piece) else symbol.to_lower()
