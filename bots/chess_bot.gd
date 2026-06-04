class_name ChessBot

var name: String = "BaseBot"
var board: Board
var eval_weights: EvalWeights = EvalWeights.new()

func set_board(p_board: Board) -> void:
	board = p_board

# Override this. Return a Move.
func get_move() -> Move:
	push_error("get_move() not implemented in " + name)
	return Move.NULL_MOVE

# Optional — called when opponent moves, lets bots track state
func on_opponent_move(_move: Move) -> void:
	pass

# Shared iterative-deepening loop for searcher-based bots.
# Resets diagnostics, runs depths 1..max_depth, prints profiling, returns best move.
func run_search(searcher: Searcher, max_depth: int) -> Move:
	searcher.search_cancelled = false
	searcher.has_searched_at_least_one_move = false
	searcher.search_diagnostics = Searcher.SearchDiagnostics.new()
	searcher.repetition_table.init(board)
	searcher.is_playing_white = board.is_white_to_move
	searcher.best_move = Move.NULL_MOVE
	searcher.best_move_this_iteration = Move.NULL_MOVE

	var t_start: int = Time.get_ticks_usec()
	var best_move: Move = Move.NULL_MOVE

	for depth in range(1, max_depth + 1):
		searcher.best_move_this_iteration = Move.NULL_MOVE
		searcher.search(depth, 0, Searcher.NEGATIVE_INFINITY, Searcher.POSITIVE_INFINITY)
		if not searcher.best_move_this_iteration.is_null:
			best_move = searcher.best_move_this_iteration

	var total_usec: int = Time.get_ticks_usec() - t_start
	var d := searcher.search_diagnostics
	var eval_pct: float = (float(d.eval_time_usec) / float(total_usec) * 100.0) if total_usec > 0 else 0.0
	print("[%s] depth=%d | %.0f ms total | eval: %.0f ms, %d calls, %.1f%%" % [
		name, max_depth,
		total_usec / 1000.0,
		d.eval_time_usec / 1000.0,
		d.eval_call_count,
		eval_pct
	])

	if best_move.is_null:
		var gen := MoveGenerator.new()
		var moves := gen.generate_moves(board)
		return moves[0] if not moves.is_empty() else Move.NULL_MOVE

	return best_move
