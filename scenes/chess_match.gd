class_name ChessMatch
extends Control

enum ChessMatchState { SETUP, PLAYER_TURN, BOT_TURN, AWAITING_PROMOTION, GAME_OVER }
var _state: ChessMatchState = ChessMatchState.SETUP

@onready var chess_board: Node2D = $ChessBoard
@onready var setup_overlay: CanvasLayer = $SetupOverlay
@onready var game_end_overlay: CanvasLayer = $GameEndOverlay
@onready var game_end_label: Label = $GameEndOverlay/VBoxContainer/Label
@onready var eval_bars: EvalBar = $EvalBar
var _evaluation: Evaluation = Evaluation.new()
# Set in the editor or call new_game() directly to override.
@export var player_is_white: bool = true

var _bot: SearcherBot
var _ai_thread: Thread = null
var _game_over: bool = false


func _ready() -> void:
	DialogueManager.run("res://new_game_dialogue.json")
	setup_overlay.visible = true
	
	
# Call this to start (or restart) a match with the given human color.
func new_game(human_color: int) -> void:
	setup_overlay.visible = false
	_game_over = false

	# Wait for any in-flight bot thread before resetting.
	if _ai_thread != null:
		_ai_thread.wait_to_finish()
		_ai_thread = null

	chess_board.player_color = human_color
	chess_board.reset()

	# Disconnect stale signal connection before reconnecting.
	if GameEvents.move_made.is_connected(_on_player_move):
		GameEvents.move_made.disconnect(_on_player_move)
	GameEvents.move_made.connect(_on_player_move)
	if GameEvents.game_over.is_connected(_on_game_over):
		GameEvents.game_over.disconnect(_on_game_over)
	GameEvents.game_over.connect(_on_game_over)

	# Board is fresh after reset(), so give the bot the new reference.
	_bot = SearcherBot.new()
	_bot.set_board(chess_board.board)

	# If the human plays black, the bot (white) moves first.
	if human_color == Piece.BLACK:
		_set_state(ChessMatchState.BOT_TURN)
		_trigger_bot()
	else:
		_set_state(ChessMatchState.PLAYER_TURN)


# --- Turn Flow ---

func _on_player_move(_move: Move) -> void:
	if _game_over:
		return
	var result := Arbiter.get_game_state(chess_board.board)
	if result != Arbiter.GameResult.IN_PROGRESS:
		_end_game(result)
		return
	_set_state(ChessMatchState.BOT_TURN)
	_refresh_eval_bar()
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
	_refresh_eval_bar()

	var result := Arbiter.get_game_state(chess_board.board)
	if result != Arbiter.GameResult.IN_PROGRESS:
		_end_game(result)
		return
	_set_state(ChessMatchState.PLAYER_TURN)


func _end_game(result: Arbiter.GameResult) -> void:
	_game_over = true
	_set_state(ChessMatchState.GAME_OVER)
	GameEvents.game_over.emit(result)

func _set_state(s: ChessMatchState) -> void:
	_state = s
	chess_board.input_enabled = (s == ChessMatchState.PLAYER_TURN)


func _on_white_pressed() -> void:
	new_game(Piece.WHITE)


func _on_black_pressed() -> void:
	new_game(Piece.BLACK)


func _on_random_pressed() -> void:
	var color: int = Piece.WHITE if RngService.chance(0.5) else Piece.BLACK
	new_game(color)


func _on_rematch_pressed() -> void:
	game_end_overlay.visible = false
	setup_overlay.visible = true

func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _on_game_over(result: Arbiter.GameResult) -> void:
	if player_is_white and Arbiter.is_white_wins_result(result):
		game_end_label.text = "GAME OVER! You Won!"
	else:
		game_end_label.text = "GAME OVER! You Lost!"
	game_end_overlay.visible = true

func _refresh_eval_bar() -> void:
	_evaluation.evaluate(chess_board.board)
	eval_bars.update_eval(_evaluation.white_eval.sum() - _evaluation.black_eval.sum())
