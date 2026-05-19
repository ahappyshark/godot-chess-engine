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

func evaluate(_p_board: Board) -> int:
	return 0

func king_pawn_shield(_color_index: int, _enemy_material: MaterialInfo, _enemy_piece_square_score: float) -> int:
	return 0

func evaluate_pawns(_color_index: int) -> int:
	return 0

func endgame_phase_weight() -> void:
	pass

func mop_up_eval() -> void:
	pass

func _count_material(_color_index: int) -> int:
	return 0

func _evaluate_piece_square_tables(_is_white: bool, _end_game_t: float) -> int:
	return 0

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
