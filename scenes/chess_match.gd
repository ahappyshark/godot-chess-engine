class_name ChessMatch
extends Node2D

signal game_over(result: Arbiter.GameResult)

@onready var chess_board: Node2D = $ChessBoard

# Set in the editor or call new_game() directly to override.
@export var player_is_white: bool = true

var _bot: SearcherBot
var _ai_thread: Thread = null
var _game_over: bool = false


func _ready() -> void:
	new_game(Piece.WHITE if player_is_white else Piece.BLACK)


# Call this to start (or restart) a match with the given human color.
func new_game(human_color: int) -> void:
	_game_over = false

	# Wait for any in-flight bot thread before resetting.
	if _ai_thread != null:
		_ai_thread.wait_to_finish()
		_ai_thread = null

	chess_board.player_color = human_color
	chess_board.reset()

	# Disconnect stale signal connection before reconnecting.
	if chess_board.move_made.is_connected(_on_player_move):
		chess_board.move_made.disconnect(_on_player_move)
	chess_board.move_made.connect(_on_player_move)

	# Board is fresh after reset(), so give the bot the new reference.
	_bot = SearcherBot.new()
	_bot.set_board(chess_board.board)

	# If the human plays black, the bot (white) moves first.
	if human_color == Piece.BLACK:
		_trigger_bot()


# --- Turn Flow ---

func _on_player_move(_move: Move) -> void:
	if _game_over:
		return
	var result := Arbiter.get_game_state(chess_board.board)
	if result != Arbiter.GameResult.IN_PROGRESS:
		_end_game(result)
		return
	_trigger_bot()


func _trigger_bot() -> void:
	_ai_thread = Thread.new()
	_ai_thread.start(_think)


func _think() -> void:
	var move: Move = _bot.get_move()
	call_deferred("_on_bot_done", move)


func _on_bot_done(move: Move) -> void:
	_ai_thread.wait_to_finish()
	_ai_thread = null

	if _game_over:
		return
	if move == null or move.is_null:
		return

	chess_board.apply_move(move)

	var result := Arbiter.get_game_state(chess_board.board)
	if result != Arbiter.GameResult.IN_PROGRESS:
		_end_game(result)


func _end_game(result: Arbiter.GameResult) -> void:
	_game_over = true
	game_over.emit(result)
