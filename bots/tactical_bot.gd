class_name TacticalBot
extends ChessBot

const SEARCH_DEPTH: int = 3

var _searcher: Searcher

func _init(bot_name: String = "TacticalBot") -> void:
	name = bot_name
	eval_weights.material = 0.8
	eval_weights.tactics = 3.0
	eval_weights.pawn_structure = 0.2

func set_board(p_board: Board) -> void:
	super.set_board(p_board)
	_searcher = Searcher.new(p_board, eval_weights)

func get_move() -> Move:
	return run_search(_searcher, SEARCH_DEPTH)
