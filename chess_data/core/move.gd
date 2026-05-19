class_name Move
extends RefCounted

# The format is as follows (ffffttttttssssss)
# Bits 0-5: start square index
# Bits 6-11: target square index
# Bits 12-15: flag (promotion type, etc)

var _move_value: int

const NO_FLAG: int = 0b0000
const EN_PASSANT_CAPTURE_FLAG: int = 0b0001
const CASTLE_FLAG: int = 0b0010
const PAWN_TWO_UP_FLAG: int = 0b0011
const PROMOTE_TO_QUEEN_FLAG: int = 0b0100
const PROMOTE_TO_KNIGHT_FLAG: int = 0b0101
const PROMOTE_TO_ROOK_FLAG: int = 0b0110
const PROMOTE_TO_BISHOP_FLAG: int = 0b0111

# Masks
const START_SQUARE_MASK: int = 0b0000000000111111
const TARGET_SQUARE_MASK: int = 0b0000111111000000
const FLAG_MASK: int = 0b1111000000000000

static var NULL_MOVE: Move

static func _static_init() -> void:
	NULL_MOVE = create(0)

static func create(move_value: int) -> Move:
	var m: Move = Move.new()
	m._move_value = move_value
	return m

static func create_with_squares(p_start_square: int, p_target_square: int) -> Move:
	var m: Move = Move.new()
	m._move_value = p_start_square | p_target_square << 6
	return m

static func create_with_flag(p_start_square: int, p_target_square: int, flag: int) -> Move:
	var m: Move = Move.new()
	m._move_value = p_start_square | p_target_square << 6 | flag << 12
	return m

static func same_move(a: Move, b: Move) -> bool:
	return a._move_value == b._move_value

var value: int:
	get:
		return _move_value

var is_null: bool:
	get:
		return _move_value == 0

var start_square: int:
	get:
		return _move_value & START_SQUARE_MASK

var target_square: int:
	get:
		return (_move_value & TARGET_SQUARE_MASK) >> 6

var move_flag: int:
	get:
		return _move_value >> 12

var is_promotion: bool:
	get:
		return move_flag >= PROMOTE_TO_QUEEN_FLAG

var promotion_piece_type: int:
	get:
		match move_flag:
			PROMOTE_TO_ROOK_FLAG: return Piece.ROOK
			PROMOTE_TO_KNIGHT_FLAG: return Piece.KNIGHT
			PROMOTE_TO_BISHOP_FLAG: return Piece.BISHOP
			PROMOTE_TO_QUEEN_FLAG: return Piece.QUEEN
			_: return Piece.NONE
