class_name Searcher

const TRANSPOSITION_TABLE_SIZE_MB: int = 64
const MAX_EXTENSIONS: int = 16

const IMMEDIATE_MATE_SCORE: int = 100000
const POSITIVE_INFINITY: int = 9999999
const NEGATIVE_INFINITY: int = -POSITIVE_INFINITY

signal on_search_complete(move: Move)

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
var current_iteration_depth: int
var search_iteration_timer: float
var search_total_timer: float
var debug_info: String

var transposition_table: TranspositionTable
var repetition_table: RepetitionTable
var move_generator: MoveGenerator
var move_orderer: MoveOrdering
var evaluation: Evaluation
var board: Board


func _init(board: Board) -> void:
	self.board = board

	evaluation = Evaluation.new()
	move_generator = MoveGenerator.new()
	transposition_table = TranspositionTable.new(board, TRANSPOSITION_TABLE_SIZE_MB)
	move_orderer = MoveOrdering.new(move_generator, transposition_table)
	repetition_table = RepetitionTable.new()

	move_generator.promotions_to_generate = MoveGenerator.PromotionMode.QUEEN_AND_KNIGHT


func start_search() -> void:
	best_eval_this_iteration = 0
	best_eval = 0
	best_move_this_iteration = Move.NULL_MOVE
	best_move = Move.NULL_MOVE

	is_playing_white = board.is_white_to_move

	move_orderer.clear_history()
	repetition_table.init(board)

	current_depth = 0
	debug_info = "Starting search with FEN " + FenUtility.current_fen(board)
	search_cancelled = false
	search_diagnostics = SearchDiagnostics.new()
	search_iteration_timer = 0.0
	search_total_timer = Time.get_ticks_msec() / 1000.0

	_run_iterative_deepening_search()

	if best_move.is_null:
		best_move = move_generator.generate_moves(board)[0]
	on_search_complete.emit(best_move)
	search_cancelled = false


func _run_iterative_deepening_search() -> void:
	for search_depth in range(1, 257):
		has_searched_at_least_one_move = false
		debug_info += "\nStarting Iteration: " + str(search_depth)
		search_iteration_timer = Time.get_ticks_msec() / 1000.0
		current_iteration_depth = search_depth
		search(search_depth, 0, NEGATIVE_INFINITY, POSITIVE_INFINITY)

		if search_cancelled:
			if has_searched_at_least_one_move:
				best_move = best_move_this_iteration
				best_eval = best_eval_this_iteration
				search_diagnostics.move = MoveUtility.get_move_name_uci(best_move)
				search_diagnostics.eval = best_eval
				search_diagnostics.move_is_from_partial_search = true
				debug_info += "\nUsing partial search result: " + MoveUtility.get_move_name_uci(best_move) + " Eval: " + str(best_eval)

			debug_info += "\nSearch aborted"
			break
		else:
			current_depth = search_depth
			best_move = best_move_this_iteration
			best_eval = best_eval_this_iteration

			debug_info += "\nIteration result: " + MoveUtility.get_move_name_uci(best_move) + " Eval: " + str(best_eval)
			if is_mate_score(best_eval):
				debug_info += " Mate in ply: " + str(num_ply_to_mate_from_score(best_eval))

			best_eval_this_iteration = -9223372036854775808
			best_move_this_iteration = Move.NULL_MOVE

			search_diagnostics.num_completed_iterations = search_depth
			search_diagnostics.move = MoveUtility.get_move_name_uci(best_move)
			search_diagnostics.eval = best_eval

			if is_mate_score(best_eval) and num_ply_to_mate_from_score(best_eval) <= search_depth:
				debug_info += "\nExitting search due to mate found within search depth"
				break


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

	var eval: int = evaluation.evaluate(board)
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
	var move_is_from_partial_search: bool
	var num_q_checks: int
	var num_q_mates: int

	var is_book: bool

	var max_extension_reached_in_search: int
