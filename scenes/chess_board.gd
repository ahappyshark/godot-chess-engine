extends Node2D

signal move_made(move: Move)

const ChessPieceScene = preload("res://scenes/chess_piece.tscn")
const TILE_SIZE: int = 32
const TWEEN_DURATION: float = 0.22

@onready var highlights: Node2D = $Highlights
@onready var pieces: Node2D = $Pieces

var player_color: int = Piece.WHITE
var board: Board

var _gen: MoveGenerator
var _piece_at_sq: Array  # ChessPiece | null, 0..63

var _dragging: ChessPiece = null
var _drag_origin_sq: int = -1
var _drag_offset: Vector2
var _legal_moves: Array

var _hovered_sq: int = -1


# --- Setup ---

func _ready() -> void:
	_piece_at_sq.resize(64)
	_piece_at_sq.fill(null)
	_gen = MoveGenerator.new()
	board = Board.new()
	board.load_position(FenUtility.position_from_fen(FenUtility.START_POSITION_FEN))
	_spawn_pieces()


func reset() -> void:
	for child in pieces.get_children():
		child.queue_free()
	_piece_at_sq.fill(null)
	highlights.clear()
	_hovered_sq = -1
	board = Board.new()
	board.load_position(FenUtility.position_from_fen(FenUtility.START_POSITION_FEN))
	_spawn_pieces()


func _spawn_pieces() -> void:
	for sq in 64:
		var code: int = board.square[sq]
		if code == Piece.NONE:
			continue
		var piece: ChessPiece = ChessPieceScene.instantiate()
		pieces.add_child(piece)
		piece.set_piece(code)
		piece.position = _sq_to_local(sq)
		_piece_at_sq[sq] = piece


# --- Public: Bot Move (animated) ---

func apply_move(move: Move) -> void:
	var piece_node: ChessPiece = _piece_at_sq[move.start_square]
	var piece_start := piece_node.position

	# Grab rook start before commit overwrites _piece_at_sq.
	var rook_node: ChessPiece = null
	var rook_start := Vector2.ZERO
	if move.move_flag == Move.CASTLE_FLAG:
		var rank := move.start_square / 8
		var kingside := move.target_square % 8 == 6
		var rook_from := rank * 8 + (7 if kingside else 0)
		rook_node = _piece_at_sq[rook_from]
		if rook_node:
			rook_start = rook_node.position

	_dragging = piece_node
	_commit_move(move)
	_dragging = null

	# Commit already set final positions — snap back then tween forward.
	var piece_end := piece_node.position
	piece_node.position = piece_start

	var tween := create_tween().set_parallel()
	tween.tween_property(piece_node, "position", piece_end, TWEEN_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	if rook_node:
		var rook_end := rook_node.position
		rook_node.position = rook_start
		tween.tween_property(rook_node, "position", rook_end, TWEEN_DURATION) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


# --- Input ---

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.global_position)
		else:
			_end_drag(event.global_position)
	elif event is InputEventMouseMotion:
		if _dragging != null:
			_dragging.global_position = event.global_position - _drag_offset
		else:
			_handle_hover(event.global_position)


func _begin_drag(global_pos: Vector2) -> void:
	var sq := _world_to_sq(to_local(global_pos))
	if sq < 0:
		return
	var code := board.square[sq]
	if code == Piece.NONE:
		return
	if not Piece.is_color(code, player_color) or board.move_colour != player_color:
		return
	var piece: ChessPiece = _piece_at_sq[sq]
	if piece == null:
		return

	highlights.clear()
	_hovered_sq = -1

	_dragging = piece
	_drag_origin_sq = sq
	_drag_offset = global_pos - piece.global_position

	var all_moves := _gen.generate_moves(board)
	_legal_moves = all_moves.filter(func(m): return m.start_square == sq)

	pieces.move_child(_dragging, -1)


func _end_drag(global_pos: Vector2) -> void:
	if _dragging == null:
		return

	var sq := _world_to_sq(to_local(global_pos))
	var matched: Move = _pick_move(sq)

	if matched != null:
		_commit_move(matched)
		move_made.emit(matched)
	else:
		_dragging.position = _sq_to_local(_drag_origin_sq)

	_dragging = null
	_drag_origin_sq = -1
	_legal_moves = []
	_hovered_sq = -1


func _pick_move(target_sq: int) -> Move:
	var best: Move = null
	for move in _legal_moves:
		if move.target_square == target_sq:
			if best == null or move.move_flag == Move.PROMOTE_TO_QUEEN_FLAG:
				best = move
	return best


# --- Hover Highlights ---

func _handle_hover(global_pos: Vector2) -> void:
	var sq := _world_to_sq(to_local(global_pos))
	if sq == _hovered_sq:
		return
	_hovered_sq = sq
	highlights.clear()

	if sq < 0:
		return
	var code := board.square[sq]
	if code == Piece.NONE:
		return

	if board.move_colour != player_color:
		return

	if Piece.is_color(code, player_color):
		# Own piece: green for safe valid moves, orange for risky ones — no red noise.
		var all_moves := _gen.generate_moves(board)
		var piece_moves := all_moves.filter(func(m): return m.start_square == sq)
		var move_sqs := piece_moves.map(func(m): return m.target_square)
		var threat_sqs := _bb_to_squares(_gen.opponent_attack_map)
		# Only pass threats that overlap with valid moves so orange fires but red doesn't.
		var risky_sqs := threat_sqs.filter(func(s): return move_sqs.has(s))
		highlights.show_moves(move_sqs)
		highlights.show_threats(risky_sqs)
	else:
		# Opponent piece: show its legal destinations in red.
		highlights.show_threats(_get_piece_attacks(sq))


# Public toggle for showing all squares the opponent currently threatens.
func show_threatened_squares() -> void:
	_gen.generate_moves(board)
	highlights.show_threats(_bb_to_squares(_gen.opponent_attack_map))


func hide_threatened_squares() -> void:
	highlights.clear_threats()


# --- Move Application ---

func _commit_move(move: Move) -> void:
	var ep_sq: int = -1
	var rook_from: int = -1
	var rook_to: int = -1

	if move.move_flag == Move.EN_PASSANT_CAPTURE_FLAG:
		var push := 1 if board.is_white_to_move else -1
		ep_sq = move.target_square - push * 8

	if move.move_flag == Move.CASTLE_FLAG:
		var rank := move.start_square / 8
		var kingside := move.target_square % 8 == 6
		rook_from = rank * 8 + (7 if kingside else 0)
		rook_to   = rank * 8 + (5 if kingside else 3)

	board.make_move(move)

	if _piece_at_sq[move.target_square] != null:
		_piece_at_sq[move.target_square].queue_free()
		_piece_at_sq[move.target_square] = null

	if ep_sq >= 0 and _piece_at_sq[ep_sq] != null:
		_piece_at_sq[ep_sq].queue_free()
		_piece_at_sq[ep_sq] = null

	if rook_from >= 0:
		var rook: ChessPiece = _piece_at_sq[rook_from]
		if rook != null:
			_piece_at_sq[rook_from] = null
			_piece_at_sq[rook_to] = rook
			rook.position = _sq_to_local(rook_to)

	_piece_at_sq[move.start_square] = null
	_piece_at_sq[move.target_square] = _dragging
	_dragging.position = _sq_to_local(move.target_square)

	if move.is_promotion:
		_dragging.set_piece(board.square[move.target_square])


# --- Helpers ---

func _get_piece_attacks(sq: int) -> Array:
	# Use a clone so we never mutate the shared board that the bot thread may be reading.
	var clone := Board.create_board_from_source(board)
	clone.is_white_to_move = not clone.is_white_to_move
	var opp_moves := _gen.generate_moves(clone)
	return opp_moves.filter(func(m): return m.start_square == sq) \
		.map(func(m): return m.target_square)


func _bb_to_squares(bb: int) -> Array:
	var squares := []
	while bb != 0:
		var lsb := BitBoardUtility.pop_lsb(bb)
		bb = lsb[0]
		squares.append(lsb[1])
	return squares


func _sq_to_local(sq: int) -> Vector2:
	var file := sq % 8
	var rank := sq / 8
	return Vector2(file * TILE_SIZE + TILE_SIZE * 0.5, (7 - rank) * TILE_SIZE + TILE_SIZE * 0.5)


func _world_to_sq(local_pos: Vector2) -> int:
	var file := int(local_pos.x / TILE_SIZE)
	var rank := 7 - int(local_pos.y / TILE_SIZE)
	if file < 0 or file > 7 or rank < 0 or rank > 7:
		return -1
	return rank * 8 + file
