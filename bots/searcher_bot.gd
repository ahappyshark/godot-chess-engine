class_name SearcherBot
extends ChessBot

# Iterative deepening target depth. The Searcher uses move ordering + TT + quiescence,
# so depth 4 here is far stronger and faster than MinimaxBot at depth 3.
const SEARCH_DEPTH: int = 4

var _searcher: Searcher

func _init(bot_name: String = "SearcherBot") -> void:
	name = bot_name

func set_board(p_board: Board) -> void:
	super.set_board(p_board)
	_searcher = Searcher.new(p_board, eval_weights)

func get_move() -> Move:
	return run_search(_searcher, SEARCH_DEPTH)
