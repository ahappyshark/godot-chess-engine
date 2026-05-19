class_name GameState

var captured_piece_type: int
var en_passant_file: int
var castling_rights: int
var fifty_move_counter: int
var zobrist_key: int

func _init(p_captured_piece_type: int, p_en_passant_file: int, p_castling_rights: int, p_fifty_move_counter: int, p_zobrist_key: int) -> void:
	captured_piece_type = p_captured_piece_type
	en_passant_file = p_en_passant_file
	castling_rights = p_castling_rights
	fifty_move_counter = p_fifty_move_counter
	zobrist_key = p_zobrist_key

func has_kingside_castle_right(white: bool) -> bool:
	var mask: int = 1 if white else 4
	return (castling_rights & mask) != 0

func has_queenside_castle_right(white: bool) -> bool:
	var mask: int = 2 if white else 8
	return (castling_rights & mask) != 0
