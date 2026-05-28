class_name Evaluation

const PAWN_VALUE: int = 100
const KNIGHT_VALUE: int = 300
const BISHOP_VALUE: int = 320
const ROOK_VALUE: int = 500
const QUEEN_VALUE: int = 900

const PASSED_PAWN_BONUSES: Array[int] = [0, 120, 80, 50, 30, 15, 15]
const ISOLATED_PAWN_PENALTY_BY_COUNT: Array[int] = [0, -10, -25, -50, -75, -75, -75, -75, -75]
const KING_PAWN_SHIELD_SCORES: Array[int] = [4, 7, 4, 3, 6, 3]

const ENDGAME_MATERIAL_START: int = ROOK_VALUE * 2 + BISHOP_VALUE + KNIGHT_VALUE

var board: Board
var white_eval: EvaluationData
var black_eval: EvaluationData

func evaluate(p_board: Board, eval_weights: EvalWeights) -> int:
	board = p_board
	var perspective: int = 1 if board.is_white_to_move else -1

	# Check for forced mate patterns FIRST
	var mate_score = check_mate_patterns()
	if mate_score != 0:
		return mate_score * perspective

	# General eval data
	white_eval = EvaluationData.new()
	black_eval = EvaluationData.new()
	var white_material = get_material_info(Board.WHITE_INDEX)
	var black_material = get_material_info(Board.BLACK_INDEX)
	white_eval.material_score = white_material.material_score
	black_eval.material_score = black_material.material_score
	white_eval.piece_square_score = _evaluate_piece_square_tables(true, white_material.end_game_t)
	black_eval.piece_square_score = _evaluate_piece_square_tables(false, black_material.end_game_t)
	white_eval.pawn_score = evaluate_pawns(Board.WHITE_INDEX)
	black_eval.pawn_score = evaluate_pawns(Board.BLACK_INDEX)
	white_eval.mop_up_score = mop_up_eval(true, white_material, black_material)
	black_eval.mop_up_score = mop_up_eval(false, black_material, white_material)
	white_eval.pawn_shield_score = king_pawn_shield(Board.WHITE_INDEX, black_material, black_eval.piece_square_score)
	black_eval.pawn_shield_score = king_pawn_shield(Board.BLACK_INDEX, white_material, white_eval.piece_square_score)
	white_eval.tactics_score = evaluate_tactics(Board.WHITE_INDEX)
	black_eval.tactics_score = evaluate_tactics(Board.BLACK_INDEX)
	
	return (white_eval.sum(eval_weights) - black_eval.sum(EvalWeights.new())) * perspective

func check_mate_patterns() -> int:
	return 0

func king_pawn_shield(color_index: int, enemy_material: MaterialInfo, _enemy_piece_square_score: float) -> int:
	if enemy_material.end_game_t >= 1:
		return 0
	var penalty: int = 0
	var is_white: bool = color_index == board.WHITE_INDEX
	var friendly_pawn: int = Piece.make_piece(Piece.PAWN, is_white)
	var king_square: int = board.king_square[color_index]
	var king_file: int = BoardHelper.file_index(king_square)
	
	var uncastled_king_penalty: int = 0
	
	if king_file <=2 || king_file >= 5:
		var squares: Array[int] = PrecomputedEvaluationData.pawn_shield_squares_white[king_square] if is_white else PrecomputedEvaluationData.pawn_shield_squares_black[king_square]
		
		for i in squares.size() / 2:
			var shield_square_index: int = squares[i]
			if board.square[shield_square_index] != friendly_pawn:
				if squares.size() > 3 && board.square[squares[i + 3]] == friendly_pawn:
					penalty += KING_PAWN_SHIELD_SCORES[i + 3]
				else:
					penalty += KING_PAWN_SHIELD_SCORES[i]
		
		penalty *= penalty
	else:
		var enemy_development_score: float = clampf((_enemy_piece_square_score + 10) / 130, 0, 1)
		uncastled_king_penalty = 50 * enemy_development_score
	
	var open_file_against_king_penalty = 0
	if enemy_material.num_rooks > 1 || (enemy_material.num_rooks > 0 && enemy_material.num_queens > 0):
		var clamped_king_file: int = clamp(king_file, 1, 6)
		var my_pawns: int = enemy_material.enemy_pawns
		for attack_file in range(clamped_king_file - 1, clamped_king_file + 2):
			var file_mask: int = Bits.file_mask[attack_file]
			var is_king_file: bool = attack_file == king_file
			if (enemy_material.pawns & file_mask) == 0:
				open_file_against_king_penalty += 25 if is_king_file else 15
				if (my_pawns & file_mask) == 0:
					open_file_against_king_penalty += 15 if is_king_file else 10

	var pawn_shield_weight: int = 1 - enemy_material.end_game_t
	if board.queens[1 - color_index].count() == 0:
		pawn_shield_weight *= 0.6
	
	return (-penalty - uncastled_king_penalty - open_file_against_king_penalty) * pawn_shield_weight

func evaluate_pawns(color_index: int) -> int:
	var pawns: PieceList = board.pawns[color_index]
	var is_white: bool = color_index == board.WHITE_INDEX
	var opponent_pawns = board.piece_bitboards[Piece.make_piece(Piece.PAWN, Piece.BLACK if is_white else Piece.WHITE)]
	var friendly_pawns = board.piece_bitboards[Piece.make_piece(Piece.PAWN, Piece.WHITE if is_white else Piece.BLACK)]
	var masks: Array[int] = Bits.white_passed_pawn_mask if is_white else Bits.black_passed_pawn_mask
	var bonus: int = 0
	var num_isolated_pawns: int = 0
	
	for i in pawns.count():
		var square: int = pawns.occupied_squares[i]
		var passed_mask: int = masks[square]
		if (opponent_pawns & passed_mask) == 0:
			var rank: int = BoardHelper.rank_index(square)
			var num_squares_from_promotion: int = 7 - rank if is_white else rank
			bonus += PASSED_PAWN_BONUSES[num_squares_from_promotion]
			
		if (friendly_pawns & Bits.adjacent_file_masks[BoardHelper.file_index(square)]) == 0:
			num_isolated_pawns += 1
	
	return bonus + ISOLATED_PAWN_PENALTY_BY_COUNT[num_isolated_pawns]
			
func endgame_phase_weight(material_count_without_pawns: int) -> float:
	var multiplier: float = 1 / ENDGAME_MATERIAL_START
	return 1 - min(1, material_count_without_pawns * multiplier)

func mop_up_eval(is_white: bool, my_material: MaterialInfo, enemy_material: MaterialInfo) -> int:
	if my_material.material_score > enemy_material.material_score + PAWN_VALUE * 2 && enemy_material.end_game_t > 0:
		var mop_up_score: int = 0
		var friendly_index: int = board.WHITE_INDEX if is_white else board.BLACK_INDEX
		var opponent_index: int = board.BLACK_INDEX if is_white else board.WHITE_INDEX
		
		var friendly_king_square = board.king_square[friendly_index]
		var opponent_king_square = board.king_square[opponent_index]
		mop_up_score += (14 - PrecomputedMoveData.orthogonal_distance[friendly_king_square][opponent_king_square]) * 4
		mop_up_score += PrecomputedMoveData.centre_manhattan_distance[opponent_king_square] * 10
		return mop_up_score * enemy_material.end_game_t
	return 0

func _count_material(_color_index: int) -> int:
	return 0

func _evaluate_piece_square_tables(is_white: bool, end_game_t: float) -> int:
	var value: int = 0
	var color_index: int = board.WHITE_INDEX if is_white else board.BLACK_INDEX
	value += evaluate_piece_square_table(PieceSquareTable.rooks, board.rooks[color_index], is_white)
	value += evaluate_piece_square_table(PieceSquareTable.knights, board.knights[color_index], is_white)
	value += evaluate_piece_square_table(PieceSquareTable.bishops, board.bishops[color_index], is_white)
	value += evaluate_piece_square_table(PieceSquareTable.queens, board.queens[color_index], is_white)

	var pawn_early: int = evaluate_piece_square_table(PieceSquareTable.pawns, board.pawns[color_index], is_white)
	var pawn_late: int = evaluate_piece_square_table(PieceSquareTable.pawns_end, board.pawns[color_index], is_white)

	value += pawn_early * (1 - end_game_t)
	value += pawn_late * end_game_t

	var king_early_phase = PieceSquareTable.read(PieceSquareTable.king_start, board.king_square[color_index], is_white)
	value += king_early_phase * (1 - end_game_t)
	var king_late_phase = PieceSquareTable.read(PieceSquareTable.king_end, board.king_square[color_index], is_white)
	value += king_late_phase * end_game_t

	return value

static func evaluate_piece_square_table(table: Array[int], piece_list: PieceList, is_white: bool) -> int:
	var value: int = 0
	for i: int in piece_list.count():
		value += PieceSquareTable.read(table, piece_list.occupied_squares[i], is_white)
	return value

func evaluate_tactics(color_index: int) -> int:
	var score: int = 0
	var eval_data = white_eval if color_index == Board.WHITE_INDEX else black_eval
	
	# Each detector returns a bonus + optionally pushes a tag
	var fork_result = detect_forks(color_index)
	score += fork_result.score
	if fork_result.found: eval_data.detected_tactics.append("fork")

	var pin_result = detect_pins(color_index)
	score += pin_result.score
	if pin_result.found: eval_data.detected_tactics.append("pin")

	var skewer_result = detect_skewers(color_index)
	score += skewer_result.score
	if skewer_result.found: eval_data.detected_tactics.append("skewer")

	return score

func detect_forks(color_index: int) -> TacticResult:
	var result = TacticResult.new()
	var is_white = color_index == Board.WHITE_INDEX

	# Build enemy piece occupancy - everything, including king
	# King fork = you're threatening mate, worth detecting
	var enemy_color = Piece.BLACK if is_white else Piece.WHITE
	var enemy_occ: int = 0
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.PAWN,   enemy_color)]
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.KNIGHT, enemy_color)]
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.BISHOP, enemy_color)]
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.ROOK,   enemy_color)]
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.QUEEN,  enemy_color)]
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.KING,   enemy_color)]

	# Knight forks
	var knights: PieceList = board.knights[color_index]
	for i in knights.count():
		var sq: int = knights.occupied_squares[i]
		var attacks: int = PrecomputedMoveData.knight_attack_bitboards[sq]
		var hits: int = attacks & enemy_occ
		if BitBoardUtility.popcount(hits) >= 2:
			# Bonus scales with value of pieces being forked
			result.score += _fork_value(hits, is_white)
			result.found = true

	return result

func _fork_value(hit_mask: int, attacker_is_white: bool) -> int:
	# Sum the two lowest-value pieces being hit (you can only take one,
	# so the fork wins you the lesser of the two threatened pieces)
	var enemy_color = Piece.BLACK if attacker_is_white else Piece.WHITE
	var values: Array[int] = []

	var piece_types = [
		[Piece.PAWN,   Evaluation.PAWN_VALUE],
		[Piece.KNIGHT, Evaluation.KNIGHT_VALUE],
		[Piece.BISHOP, Evaluation.BISHOP_VALUE],
		[Piece.ROOK,   Evaluation.ROOK_VALUE],
		[Piece.QUEEN,  Evaluation.QUEEN_VALUE],
		[Piece.KING,   10000],
	]

	for entry in piece_types:
		var bb: int = board.piece_bitboards[Piece.make_piece(entry[0], enemy_color)]
		var n: int = BitBoardUtility.popcount(bb & hit_mask)
		for _j in n:
			values.append(entry[1])

	if values.size() < 2:
		return 0
	values.sort()
	# The fork wins you the smaller piece (opponent saves the bigger one)
	return values[0]

func detect_pins(color_index: int) -> TacticResult:
	var result = TacticResult.new()
	var is_white: bool = color_index == Board.WHITE_INDEX
	var enemy_index: int = 1 - color_index
	var enemy_king_sq: int = board.king_square[enemy_index]
	var enemy_color: int = Piece.BLACK if is_white else Piece.WHITE
	var my_color: int = Piece.WHITE if is_white else Piece.BLACK

	var my_rooks_bb:   int = board.piece_bitboards[Piece.make_piece(Piece.ROOK,   my_color)]
	var my_bishops_bb: int = board.piece_bitboards[Piece.make_piece(Piece.BISHOP, my_color)]
	var my_queens_bb:  int = board.piece_bitboards[Piece.make_piece(Piece.QUEEN,  my_color)]

	var enemy_occ: int = 0
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.PAWN,   enemy_color)]
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.KNIGHT, enemy_color)]
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.BISHOP, enemy_color)]
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.ROOK,   enemy_color)]
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.QUEEN,  enemy_color)]
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.KING,   enemy_color)]

	var my_occ: int = my_rooks_bb | my_bishops_bb | my_queens_bb
	my_occ |= board.piece_bitboards[Piece.make_piece(Piece.PAWN,   my_color)]
	my_occ |= board.piece_bitboards[Piece.make_piece(Piece.KNIGHT, my_color)]
	my_occ |= board.piece_bitboards[Piece.make_piece(Piece.KING,   my_color)]

	var all_occ: int = my_occ | enemy_occ

	# Shoot rays from the enemy king in all 8 directions.
	# direction_offsets: [N(+8), S(-8), W(-1), E(+1), NW(+7), SE(-7), NE(+9), SW(-9)]
	# Directions 0-3 are orthogonal (rook), 4-7 are diagonal (bishop).
	for dir_idx in 8:
		var is_diagonal: bool = dir_idx >= 4
		var n: int = PrecomputedMoveData.num_squares_to_edge[enemy_king_sq][dir_idx]
		var dir_offset: int = PrecomputedMoveData.direction_offsets[dir_idx]
		var first_piece_sq: int = -1
		var first_is_enemy: bool = false  # "enemy" = belongs to the pinnable side

		for step in n:
			var sq: int = enemy_king_sq + dir_offset * (step + 1)
			var bit: int = 1 << sq

			if (all_occ & bit) != 0:
				if first_piece_sq == -1:
					first_piece_sq = sq
					first_is_enemy = (enemy_occ & bit) != 0
				else:
					if first_is_enemy:
						var is_our_slider: bool
						if is_diagonal:
							is_our_slider = ((my_bishops_bb | my_queens_bb) & bit) != 0
						else:
							is_our_slider = ((my_rooks_bb | my_queens_bb) & bit) != 0
						if is_our_slider:
							result.found = true
							result.score += _pin_value(first_piece_sq, enemy_color)
					break
	return result

func _pin_value(pinned_sq: int, pinned_color: int) -> int:
	#What piece is actually pinned? Higher value = more useful pin
	var piece_on_sq: int = board.square[pinned_sq]
	match Piece.piece_type(piece_on_sq):
		Piece.QUEEN: return 80
		Piece.ROOK: return 60
		Piece.BISHOP: return 40
		Piece.KNIGHT: return 40
		Piece.PAWN: return 15
	return 0

func detect_skewers(color_index: int) -> TacticResult:
	var result = TacticResult.new()
	var is_white: bool = color_index == Board.WHITE_INDEX
	var enemy_color: int = Piece.BLACK if is_white else Piece.WHITE
	var my_color: int = Piece.WHITE if is_white else Piece.BLACK

	var my_rooks_bb:   int = board.piece_bitboards[Piece.make_piece(Piece.ROOK,   my_color)]
	var my_bishops_bb: int = board.piece_bitboards[Piece.make_piece(Piece.BISHOP, my_color)]
	var my_queens_bb:  int = board.piece_bitboards[Piece.make_piece(Piece.QUEEN,  my_color)]

	var enemy_occ: int = 0
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.PAWN,   enemy_color)]
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.KNIGHT, enemy_color)]
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.BISHOP, enemy_color)]
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.ROOK,   enemy_color)]
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.QUEEN,  enemy_color)]
	enemy_occ |= board.piece_bitboards[Piece.make_piece(Piece.KING,   enemy_color)]

	var my_occ: int = my_rooks_bb | my_bishops_bb | my_queens_bb
	my_occ |= board.piece_bitboards[Piece.make_piece(Piece.PAWN,   my_color)]
	my_occ |= board.piece_bitboards[Piece.make_piece(Piece.KNIGHT, my_color)]
	my_occ |= board.piece_bitboards[Piece.make_piece(Piece.KING,   my_color)]

	var all_occ: int = my_occ | enemy_occ

	# Only queen/rook/king are valuable enough that the opponent is forced to flee
	# rather than accept the trade, so they are the only valid skewer targets.
	var enemy_high_bb: int = 0
	enemy_high_bb |= board.piece_bitboards[Piece.make_piece(Piece.QUEEN, enemy_color)]
	enemy_high_bb |= board.piece_bitboards[Piece.make_piece(Piece.ROOK,  enemy_color)]
	enemy_high_bb |= board.piece_bitboards[Piece.make_piece(Piece.KING,  enemy_color)]

	# Shoot rays from each of our sliders.
	# Skewer: [our slider] → [enemy high-value] → [enemy any piece]
	# The high-value piece flees and we capture what was hiding behind it.
	# Inverted from detect_pins: origin is our slider (not enemy king), first hit is
	# the high-value target, and we score the *second* piece instead of the first.
	for i in board.rooks[color_index].count():
		var origin_sq: int = board.rooks[color_index].occupied_squares[i]
		for dir_idx in 4:  # orthogonal only
			var n: int = PrecomputedMoveData.num_squares_to_edge[origin_sq][dir_idx]
			var dir_offset: int = PrecomputedMoveData.direction_offsets[dir_idx]
			var first_piece_sq: int = -1
			for step in n:
				var sq: int = origin_sq + dir_offset * (step + 1)
				var bit: int = 1 << sq
				if (all_occ & bit) != 0:
					if first_piece_sq == -1:
						if (enemy_high_bb & bit) == 0:
							break
						first_piece_sq = sq
					else:
						if (enemy_occ & bit) != 0:
							result.found = true
							result.score += _skewer_value(sq, enemy_color)
						break

	for i in board.bishops[color_index].count():
		var origin_sq: int = board.bishops[color_index].occupied_squares[i]
		for dir_idx in range(4, 8):  # diagonal only
			var n: int = PrecomputedMoveData.num_squares_to_edge[origin_sq][dir_idx]
			var dir_offset: int = PrecomputedMoveData.direction_offsets[dir_idx]
			var first_piece_sq: int = -1
			for step in n:
				var sq: int = origin_sq + dir_offset * (step + 1)
				var bit: int = 1 << sq
				if (all_occ & bit) != 0:
					if first_piece_sq == -1:
						if (enemy_high_bb & bit) == 0:
							break
						first_piece_sq = sq
					else:
						if (enemy_occ & bit) != 0:
							result.found = true
							result.score += _skewer_value(sq, enemy_color)
						break

	for i in board.queens[color_index].count():
		var origin_sq: int = board.queens[color_index].occupied_squares[i]
		for dir_idx in 8:
			var n: int = PrecomputedMoveData.num_squares_to_edge[origin_sq][dir_idx]
			var dir_offset: int = PrecomputedMoveData.direction_offsets[dir_idx]
			var first_piece_sq: int = -1
			for step in n:
				var sq: int = origin_sq + dir_offset * (step + 1)
				var bit: int = 1 << sq
				if (all_occ & bit) != 0:
					if first_piece_sq == -1:
						if (enemy_high_bb & bit) == 0:
							break
						first_piece_sq = sq
					else:
						if (enemy_occ & bit) != 0:
							result.found = true
							result.score += _skewer_value(sq, enemy_color)
						break

	return result

func _skewer_value(exposed_sq: int, _exposed_color: int) -> int:
	# Score based on the piece exposed behind the skewered piece (what we capture).
	# Inverted from _pin_value: we call this on the second piece, not the first.
	var piece_on_sq: int = board.square[exposed_sq]
	match Piece.piece_type(piece_on_sq):
		Piece.QUEEN:  return 80
		Piece.ROOK:   return 60
		Piece.BISHOP: return 40
		Piece.KNIGHT: return 40
		Piece.PAWN:   return 15
	return 0

func get_material_info(color_index: int) -> MaterialInfo:
	var num_pawns: int = board.pawns[color_index].count()
	var num_knights: int = board.knights[color_index].count()
	var num_bishops: int = board.bishops[color_index].count()
	var num_rooks: int = board.rooks[color_index].count()
	var num_queens: int = board.queens[color_index].count()

	var is_white: bool = color_index == Board.WHITE_INDEX
	var my_pawns: int = board.piece_bitboards[Piece.make_piece(Piece.PAWN, Piece.WHITE if is_white else Piece.BLACK)]
	var enemy_pawns: int = board.piece_bitboards[Piece.make_piece(Piece.PAWN, Piece.BLACK if is_white else Piece.WHITE)]

	return MaterialInfo.new(num_pawns, num_knights, num_bishops, num_queens, num_rooks, my_pawns, enemy_pawns)


class EvaluationData:
	var material_score: int
	var mop_up_score: int
	var piece_square_score: int
	var pawn_score: int
	var pawn_shield_score: int
	var tactics_score: int
	var pattern_score: int
	var detected_tactics: Array[String] = []

	func sum(w: EvalWeights) -> int:
		return int(
			material_score * w.material + 
			mop_up_score * w.mop_up + 
			piece_square_score * w.piece_square + 
			pawn_score * w.pawn_structure + 
			pawn_shield_score * w.pawn_shield + 
			tactics_score * w.tactics + 
			pattern_score * w.patterns
		)


class MaterialInfo:
	var material_score: int
	var num_pawns: int
	var num_majors: int
	var num_minors: int
	var num_bishops: int
	var num_queens: int
	var num_rooks: int
	var pawns: int
	var enemy_pawns: int
	var end_game_t: float

	func _init(
		p_num_pawns: int,
		p_num_knights: int,
		p_num_bishops: int,
		p_num_queens: int,
		p_num_rooks: int,
		p_my_pawns: int,
		p_enemy_pawns: int
	) -> void:
		num_pawns = p_num_pawns
		num_bishops = p_num_bishops
		num_queens = p_num_queens
		num_rooks = p_num_rooks
		pawns = p_my_pawns
		enemy_pawns = p_enemy_pawns
		num_majors = num_rooks + num_queens
		num_minors = num_bishops + p_num_knights
		material_score = 0
		material_score += num_pawns * Evaluation.PAWN_VALUE
		material_score += p_num_knights * Evaluation.KNIGHT_VALUE
		material_score += num_bishops * Evaluation.BISHOP_VALUE
		material_score += num_rooks * Evaluation.ROOK_VALUE
		material_score += num_queens * Evaluation.QUEEN_VALUE

		# Endgame transition (0 -> 1)
		const QUEEN_ENDGAME_WEIGHT: int = 45
		const ROOK_ENDGAME_WEIGHT: int = 20
		const BISHOP_ENDGAME_WEIGHT: int = 10
		const KNIGHT_ENDGAME_WEIGHT: int = 10

		const ENDGAME_START_WEIGHT: int = 2 * ROOK_ENDGAME_WEIGHT + 2 * BISHOP_ENDGAME_WEIGHT + 2 * KNIGHT_ENDGAME_WEIGHT + QUEEN_ENDGAME_WEIGHT
		var endgame_weight_sum: int = num_queens * QUEEN_ENDGAME_WEIGHT + num_rooks * ROOK_ENDGAME_WEIGHT + num_bishops * BISHOP_ENDGAME_WEIGHT + p_num_knights * KNIGHT_ENDGAME_WEIGHT
		end_game_t = 1 - min(1, endgame_weight_sum / float(ENDGAME_START_WEIGHT))

class TacticResult:
	var found: bool = false
	var score: int = 0
