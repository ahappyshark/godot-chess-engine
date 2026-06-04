class_name Searcher

const TRANSPOSITION_TABLE_SIZE_MB: int = 64
const MAX_EXTENSIONS: int = 16

const IMMEDIATE_MATE_SCORE: int = 100000
const POSITIVE_INFINITY: int = 9999999
const NEGATIVE_INFINITY: int = -POSITIVE_INFINITY

var current_depth: int
var best_move_so_far: Move:
	get:
		return best_move
var best_eval_so_far: int:
	get:
		return best_eval

var is_playing_white: bool
var best_move_this_iteration: Move
var best_eval_this_iteration: int
var best_move: Move
var best_eval: int
var has_searched_at_least_one_move: bool
var search_cancelled: bool

var search_diagnostics: SearchDiagnostics

var transposition_table: TranspositionTable
var repetition_table: RepetitionTable
var move_generator: MoveGenerator
var move_orderer: MoveOrdering
var evaluation: Evaluation
var board: Board
var eval_weights: EvalWeights


func _init(board: Board, eval_weights: EvalWeights) -> void:	
	self.board = board
	self.eval_weights = eval_weights
	evaluation = Evaluation.new()
	move_generator = MoveGenerator.new()
	transposition_table = TranspositionTable.new(board, TRANSPOSITION_TABLE_SIZE_MB)
	move_orderer = MoveOrdering.new(move_generator, transposition_table)
	repetition_table = RepetitionTable.new()

	move_generator.promotions_to_generate = MoveGenerator.PromotionMode.QUEEN_AND_KNIGHT


func get_search_result() -> Dictionary:
	return {"move": best_move, "eval": best_eval}


func end_search() -> void:
	search_cancelled = true


func search(ply_remaining: int, ply_from_root: int, alpha: int, beta: int, num_extensions: int = 0, prev_move: Move = null, prev_was_capture: bool = false) -> int:
	if search_cancelled:
		return 0

	if ply_from_root > 0:
		if board.current_game_state.fifty_move_counter >= 100 or repetition_table.contains(board.current_game_state.zobrist_key):
			return 0

		alpha = max(alpha, -IMMEDIATE_MATE_SCORE + ply_from_root)
		beta = min(beta, IMMEDIATE_MATE_SCORE - ply_from_root)
		if alpha >= beta:
			return alpha

	var tt_val: int = transposition_table.lookup_evaluation(ply_remaining, ply_from_root, alpha, beta)
	if tt_val != TranspositionTable.LOOKUP_FAILED:
		if ply_from_root == 0:
			best_move_this_iteration = transposition_table.try_get_stored_move()
			best_eval_this_iteration = transposition_table.entries[transposition_table.index].value
		return tt_val

	if ply_remaining == 0:
		return quiescence_search(alpha, beta)

	var moves: Array = move_generator.generate_moves(board, false)
	var prev_best_move: Move = best_move if ply_from_root == 0 else transposition_table.try_get_stored_move()
	move_orderer.order_moves(prev_best_move, board, moves, move_generator.opponent_attack_map, move_generator.opponent_pawn_attack_map, false, ply_from_root)

	if moves.size() == 0:
		if move_generator.in_check():
			return -(IMMEDIATE_MATE_SCORE - ply_from_root)
		else:
			return 0

	if ply_from_root > 0:
		var was_pawn_move: bool = Piece.piece_type(board.square[prev_move.target_square]) == Piece.PAWN
		repetition_table.push(board.current_game_state.zobrist_key, prev_was_capture or was_pawn_move)

	var evaluation_bound: int = TranspositionTable.UPPER_BOUND
	var best_move_in_this_position: Move = Move.NULL_MOVE

	for i in moves.size():
		var move: Move = moves[i]
		var captured_piece_type: int = Piece.piece_type(board.square[move.target_square])
		var is_capture: bool = captured_piece_type != Piece.NONE
		board.make_move(moves[i], true)

		var extension: int = 0
		if num_extensions < MAX_EXTENSIONS:
			var moved_piece_type: int = Piece.piece_type(board.square[move.target_square])
			var target_rank: int = BoardHelper.rank_index(move.target_square)
			if board.is_in_check():
				extension = 1
			elif moved_piece_type == Piece.PAWN and (target_rank == 1 or target_rank == 6):
				extension = 1

		var needs_full_search: bool = true
		var eval: int = 0

		if extension == 0 and ply_remaining >= 3 and i >= 3 and not is_capture:
			const REDUCE_DEPTH: int = 1
			eval = -search(ply_remaining - 1 - REDUCE_DEPTH, ply_from_root + 1, -alpha - 1, -alpha, num_extensions, move, is_capture)
			needs_full_search = eval > alpha

		if needs_full_search:
			eval = -search(ply_remaining - 1 + extension, ply_from_root + 1, -beta, -alpha, num_extensions + extension, move, is_capture)

		board.unmake_move(moves[i], true)

		if search_cancelled:
			return 0

		if eval >= beta:
			transposition_table.store_evaluation(ply_remaining, ply_from_root, beta, TranspositionTable.LOWER_BOUND, moves[i])

			if not is_capture:
				if ply_from_root < MoveOrdering.MAX_KILLER_MOVE_PLY:
					move_orderer.killer_moves[ply_from_root].add(move)
				var history_score: int = ply_remaining * ply_remaining
				move_orderer.history[board.move_colour_index][moves[i].start_square][moves[i].target_square] += history_score

			if ply_from_root > 0:
				repetition_table.try_pop()

			search_diagnostics.num_cut_offs += 1
			return beta

		if eval > alpha:
			evaluation_bound = TranspositionTable.EXACT
			best_move_in_this_position = moves[i]
			alpha = eval
			if ply_from_root == 0:
				best_move_this_iteration = moves[i]
				best_eval_this_iteration = eval
				has_searched_at_least_one_move = true

	if ply_from_root > 0:
		repetition_table.try_pop()

	transposition_table.store_evaluation(ply_remaining, ply_from_root, alpha, evaluation_bound, best_move_in_this_position)

	return alpha


func quiescence_search(alpha: int, beta: int) -> int:
	if search_cancelled:
		return 0

	var eval_t0: int = Time.get_ticks_usec()
	evaluation.compute(board)
	var eval: int = evaluation.weighted_score(eval_weights)
	search_diagnostics.eval_time_usec += Time.get_ticks_usec() - eval_t0
	search_diagnostics.eval_call_count += 1
	search_diagnostics.num_positions_evaluated += 1
	if eval >= beta:
		search_diagnostics.num_cut_offs += 1
		return beta
	if eval > alpha:
		alpha = eval

	var moves: Array = move_generator.generate_moves(board, true)
	move_orderer.order_moves(Move.NULL_MOVE, board, moves, move_generator.opponent_attack_map, move_generator.opponent_pawn_attack_map, true, 0)

	for i in moves.size():
		board.make_move(moves[i], true)
		eval = -quiescence_search(-beta, -alpha)
		board.unmake_move(moves[i], true)

		if eval >= beta:
			search_diagnostics.num_cut_offs += 1
			return beta
		if eval > alpha:
			alpha = eval

	return alpha


static func is_mate_score(score: int) -> bool:
	if score == -9223372036854775808:
		return false
	const MAX_MATE_DEPTH: int = 1000
	return abs(score) > IMMEDIATE_MATE_SCORE - MAX_MATE_DEPTH


static func num_ply_to_mate_from_score(score: int) -> int:
	return IMMEDIATE_MATE_SCORE - abs(score)


func announce_mate() -> String:
	if is_mate_score(best_eval_this_iteration):
		var num_ply_to_mate: int = num_ply_to_mate_from_score(best_eval_this_iteration)
		var num_moves_to_mate: int = int(ceil(num_ply_to_mate / 2.0))
		var side_with_mate: String = "Black" if best_eval_this_iteration * (1 if board.is_white_to_move else -1) < 0 else "White"
		return "%s can mate in %d move%s" % [side_with_mate, num_moves_to_mate, "s" if num_moves_to_mate > 1 else ""]
	return "No mate found"


func clear_for_new_position() -> void:
	transposition_table.clear()
	move_orderer.clear_killers()


func get_transposition_table() -> TranspositionTable:
	return transposition_table


class SearchDiagnostics:
	var num_completed_iterations: int
	var num_positions_evaluated: int
	var num_cut_offs: int

	var move_val: String
	var move: String
	var eval: int
	var num_q_checks: int
	var num_q_mates: int

	var eval_call_count: int
	var eval_time_usec: int   # total microseconds spent inside evaluation.compute()

	var is_book: bool

	var max_extension_reached_in_search: int
