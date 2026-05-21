class_name MinimaxBot
extends ChessBot

const INF_SCORE: int = 9999999
const SEARCH_DEPTH: int = 2

var _gen: MoveGenerator
var _eval: Evaluation

func _init(bot_name: String = "MinimaxBot") -> void:
	name = bot_name
	_gen = MoveGenerator.new()
	_eval = Evaluation.new()

func get_move() -> Move:
	var moves: Array = _gen.generate_moves(board)
	if moves.is_empty():
		return Move.NULL_MOVE

	var best_move: Move = moves[0]
	var best_score: int = -INF_SCORE - 1
	var bot_is_white: bool = board.is_white_to_move

	for move in moves:
		board.make_move(move, true)
		var score: int = minimax(SEARCH_DEPTH - 1, -INF_SCORE, INF_SCORE, not bot_is_white)
		board.unmake_move(move, true)
		# Flip to bot's perspective: white wants high scores, black wants low
		var adjusted: int = score if bot_is_white else -score
		if adjusted > best_score:
			best_score = adjusted
			best_move = move

	return best_move

func minimax(depth: int, alpha: int, beta: int, is_maximizing: bool) -> int:
	var moves: Array = _gen.generate_moves(board)

	if moves.is_empty():
		if _gen.in_check():
			# Checkmate — prefer delayed mate (avoid) / faster mate (deliver)
			return -INF_SCORE + depth if is_maximizing else INF_SCORE - depth
		return 0  # Stalemate

	if board.fifty_move_counter >= 100:
		return 0

	if depth == 0:
		return _absolute_evaluate()

	if is_maximizing:
		var best: int = -INF_SCORE
		for move in moves:
			board.make_move(move, true)
			best = max(best, minimax(depth - 1, alpha, beta, false))
			board.unmake_move(move, true)
			alpha = max(alpha, best)
			if beta <= alpha:
				break  # β cutoff
		return best
	else:
		var best: int = INF_SCORE
		for move in moves:
			board.make_move(move, true)
			best = min(best, minimax(depth - 1, alpha, beta, true))
			board.unmake_move(move, true)
			beta = min(beta, best)
			if beta <= alpha:
				break  # α cutoff
		return best

# Returns white's absolute advantage (positive = white winning)
func _absolute_evaluate() -> int:
	var score: int = _eval.evaluate(board)
	# evaluate() returns perspective-relative; un-flip to get absolute
	return score if board.is_white_to_move else -score
