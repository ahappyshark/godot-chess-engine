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
	_searcher.search_cancelled = false
	_searcher.has_searched_at_least_one_move = false
	_searcher.search_diagnostics = Searcher.SearchDiagnostics.new()
	_searcher.repetition_table.init(board)
	_searcher.is_playing_white = board.is_white_to_move
	_searcher.best_move = Move.NULL_MOVE
	_searcher.best_move_this_iteration = Move.NULL_MOVE

	var best_move: Move = Move.NULL_MOVE

	# Iterative deepening: each completed depth improves move ordering for the next,
	# so the last completed depth gives the best result for the time spent.
	for depth in range(1, SEARCH_DEPTH + 1):
		_searcher.best_move_this_iteration = Move.NULL_MOVE
		_searcher.search(depth, 0, Searcher.NEGATIVE_INFINITY, Searcher.POSITIVE_INFINITY)
		if not _searcher.best_move_this_iteration.is_null:
			best_move = _searcher.best_move_this_iteration

	if best_move.is_null:
		var gen := MoveGenerator.new()
		var moves := gen.generate_moves(board)
		return moves[0] if not moves.is_empty() else Move.NULL_MOVE

	return best_move
