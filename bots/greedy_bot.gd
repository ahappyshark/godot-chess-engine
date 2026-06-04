class_name GreedyBot
extends ChessBot

const SEARCH_DEPTH: int = 3

var _searcher: Searcher

func _init(bot_name: String = "GreedyBot") -> void:
	name = bot_name
	eval_weights.material = 2.5
	eval_weights.tactics = 0.3
	eval_weights.pawn_shield = 0.1

func set_board(p_board: Board) -> void:
	super.set_board(p_board)
	_searcher = Searcher.new(p_board, eval_weights)

func get_move() -> Move:
	return run_search(_searcher, SEARCH_DEPTH)
