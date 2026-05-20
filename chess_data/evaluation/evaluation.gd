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

func evaluate(p_board: Board) -> int:
	board = p_board
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
	# mop-up eval, pawn shield, etc.
	var perspective: int = 1 if board.is_white_to_move else -1
	return (white_eval.sum() - black_eval.sum()) * perspective


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
		for attack_file in range(clamped_king_file, clamped_king_file + 1):
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

	func sum() -> int:
		return material_score + mop_up_score + piece_square_score + pawn_score + pawn_shield_score


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
