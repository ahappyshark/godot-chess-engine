class_name Board

const WHITE_INDEX: int = 0
const BLACK_INDEX: int = 1

const CLEAR_WHITE_KINGSIDE_MASK: int = 0b1110
const CLEAR_WHITE_QUEENSIDE_MASK: int = 0b1101
const CLEAR_BLACK_KINGSIDE_MASK: int = 0b1011
const CLEAR_BLACK_QUEENSIDE_MASK: int = 0b0111

var square: Array[int] = []
var king_square: Array[int] = []

# Bitboards
# Bitboard for each piece type and colour (white pawns, white knights, ... black pawns, etc.)
var piece_bitboards: Array[int]
# Bitboards for all pieces of either colour (all white pieces, all black pieces)
var colour_bitboards: Array[int]
var all_pieces_bitboard: int
var friendly_orthogonal_sliders: int
var friendly_diagonal_sliders: int
var enemy_orthogonal_sliders: int
var enemy_diagonal_sliders: int

var total_piece_count_without_pawns_and_kings: int

# Piece Lists
var rooks: Array[PieceList]
var bishops: Array[PieceList]
var queens: Array[PieceList]
var knights: Array[PieceList]
var pawns: Array[PieceList]

# Side to move info
var is_white_to_move: bool
var move_colour: int:
	get:
		return Piece.WHITE if is_white_to_move else Piece.BLACK
var opponent_colour: int:
	get:
		return Piece.BLACK if is_white_to_move else Piece.WHITE
var move_colour_index: int:
	get:
		return WHITE_INDEX if is_white_to_move else BLACK_INDEX
var opponent_colour_index: int:
	get:
		return BLACK_INDEX if is_white_to_move else WHITE_INDEX

# List of (hashed) positions since last pawn move or capture (for detecting repetitions)
var repetition_position_history: Array[int]
# Game State and stack of gamestate history
var current_game_state: GameState
var game_state_history: Array[GameState]

# Total plies (half-moves) played in game
var ply_count: int
var fifty_move_counter: int:
	get:
		return current_game_state.fifty_move_counter
var zobrist_key: int:
	get:
		return current_game_state.zobrist_key

var current_fen: String:
	get:
		return FenUtility.current_fen(self)

var game_start_fen: String:
	get:
		return start_position_info.fen

var start_position_info: FenUtility.PositionInfo

func _init() -> void:
	square.resize(64)

func make_move(_move: Move, _in_search: bool = false) -> void:
	pass

func unmake_move(_move: Move, _in_search: bool = false) -> void:
	pass

func make_null_move() -> void:
	pass

func unmake_null_move() -> void:
	pass

func is_in_check() -> bool:
	return false

func calculate_in_check_state() -> bool:
	return false

func load_start_position() -> void:
	pass

func load_position(_pos_info: FenUtility.PositionInfo) -> void:
	pass

func create_board() -> void:
	pass

func create_board_2() -> void:
	pass

func move_piece() -> void:
	pass

func update_slider_bitboards() -> void:
	pass

func initialize() -> void:
	pass
