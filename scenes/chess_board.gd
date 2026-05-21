extends Node2D

signal move_made(move: Move)

const ChessPieceScene = preload("res://scenes/chess_piece.tscn")
const TILE_SIZE: int = 32

@onready var pieces: Node2D = $Pieces

# Which color the human controls. Only that color's pieces are draggable.
var player_color: int = Piece.WHITE

var board: Board
var _gen: MoveGenerator
var _piece_at_sq: Array  # ChessPiece | null, indexed 0..63

var _dragging: ChessPiece = null
var _drag_origin_sq: int = -1
var _drag_offset: Vector2
var _legal_moves: Array  # Move objects for the piece being dragged


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
	board = Board.new()
	board.load_position(FenUtility.position_from_fen(FenUtility.START_POSITION_FEN))
	_spawn_pieces()


# Called by ChessMatch to play the bot's chosen move.
func apply_move(move: Move) -> void:
	_dragging = _piece_at_sq[move.start_square]
	_commit_move(move)
	_dragging = null


# --- Input ---

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.global_position)
		else:
			_end_drag(event.global_position)
	elif event is InputEventMouseMotion and _dragging != null:
		_dragging.global_position = event.global_position - _drag_offset


func _begin_drag(global_pos: Vector2) -> void:
	var sq := _world_to_sq(to_local(global_pos))
	if sq < 0:
		return
	var code := board.square[sq]
	if code == Piece.NONE:
		return
	# Only let the human move their own color, and only on their turn.
	if not Piece.is_color(code, player_color) or board.move_colour != player_color:
		return
	var piece: ChessPiece = _piece_at_sq[sq]
	if piece == null:
		return

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


func _pick_move(target_sq: int) -> Move:
	var best: Move = null
	for move in _legal_moves:
		if move.target_square == target_sq:
			if best == null or move.move_flag == Move.PROMOTE_TO_QUEEN_FLAG:
				best = move
	return best


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


# --- Coordinate Helpers ---

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


func _sq_to_local(sq: int) -> Vector2:
	var file := sq % 8
	var rank := sq / 8
	return Vector2(
		file * TILE_SIZE + TILE_SIZE * 0.5,
		(7 - rank) * TILE_SIZE + TILE_SIZE * 0.5
	)


func _world_to_sq(local_pos: Vector2) -> int:
	var file := int(local_pos.x / TILE_SIZE)
	var rank := 7 - int(local_pos.y / TILE_SIZE)
	if file < 0 or file > 7 or rank < 0 or rank > 7:
		return -1
	return rank * 8 + file
