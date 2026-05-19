class_name MoveOrdering

var move_scores: Array[int]
const MAX_MOVE_COUNT: int = 218

const SQUARE_CONTROLLED_BY_OPPONENT_PAWN_PENALTY: int = 350
const CAPTURED_PIECE_VALUE_MULTIPLIER: int = 100

var transposition_table: TranspositionTable
var invalid_move: Move

var killer_moves: Array
var history: Array
const MAX_KILLER_MOVE_PLY: int = 32

const MILLION: int = 1000000
const HASH_MOVE_SCORE: int = 100 * MILLION
const WINNING_CAPTURE_BIAS: int = 8 * MILLION
const PROMOTE_BIAS: int = 6 * MILLION
const KILLER_BIAS: int = 4 * MILLION
const LOSING_CAPTURE_BIAS: int = 2 * MILLION
const REGULAR_BIAS: int = 0


func _init(m: MoveGenerator, tt: TranspositionTable) -> void:
	move_scores = []
	move_scores.resize(MAX_MOVE_COUNT)
	move_scores.fill(0)
	transposition_table = tt
	invalid_move = Move.NULL_MOVE
	killer_moves = []
	killer_moves.resize(MAX_KILLER_MOVE_PLY)
	for i in MAX_KILLER_MOVE_PLY:
		killer_moves[i] = Killers.new()
	history = _make_history()


func _make_history() -> Array:
	var h: Array = []
	h.resize(2)
	for i in 2:
		h[i] = []
		h[i].resize(64)
		for j in 64:
			h[i][j] = []
			h[i][j].resize(64)
			h[i][j].fill(0)
	return h


func clear_history() -> void:
	history = _make_history()


func clear_killers() -> void:
	killer_moves = []
	killer_moves.resize(MAX_KILLER_MOVE_PLY)
	for i in MAX_KILLER_MOVE_PLY:
		killer_moves[i] = Killers.new()


func clear() -> void:
	clear_killers()
	clear_history()


func order_moves(hash_move: Move, board: Board, moves: Array, opp_attacks: int, opp_pawn_attacks: int, in_q_search: bool, ply: int) -> void:
	var opp_pieces: int = board.enemy_diagonal_sliders | board.enemy_orthogonal_sliders | board.piece_bitboards[Piece.make_piece(Piece.KNIGHT, board.opponent_colour)]
	var pawn_attacks: Array = BitBoardUtility.white_pawn_attacks if board.is_white_to_move else BitBoardUtility.black_pawn_attacks

	for i in moves.size():
		var move: Move = moves[i]

		if Move.same_move(move, hash_move):
			move_scores[i] = HASH_MOVE_SCORE
			continue

		var score: int = 0
		var start_square: int = move.start_square
		var target_square: int = move.target_square

		var move_piece: int = board.square[start_square]
		var move_piece_type: int = Piece.piece_type(move_piece)
		var capture_piece_type: int = Piece.piece_type(board.square[target_square])
		var is_capture: bool = capture_piece_type != Piece.NONE
		var flag: int = moves[i].move_flag
		var piece_value: int = get_piece_value(move_piece_type)

		if is_capture:
			var capture_material_delta: int = get_piece_value(capture_piece_type) - piece_value
			var opponent_can_recapture: bool = BitBoardUtility.contains_square(opp_pawn_attacks | opp_attacks, target_square)
			if opponent_can_recapture:
				score += (WINNING_CAPTURE_BIAS if capture_material_delta >= 0 else LOSING_CAPTURE_BIAS) + capture_material_delta
			else:
				score += WINNING_CAPTURE_BIAS + capture_material_delta

		if move_piece_type == Piece.PAWN:
			if flag == Move.PROMOTE_TO_QUEEN_FLAG and not is_capture:
				score += PROMOTE_BIAS
		elif move_piece_type == Piece.KING:
			pass
		else:
			var to_score: int = PieceSquareTable.read_two(move_piece, target_square)
			var from_score: int = PieceSquareTable.read_two(move_piece, start_square)
			score += to_score - from_score

			if BitBoardUtility.contains_square(opp_pawn_attacks, target_square):
				score -= 50
			elif BitBoardUtility.contains_square(opp_attacks, target_square):
				score -= 25

		if not is_capture:
			var is_killer: bool = not in_q_search and ply < MAX_KILLER_MOVE_PLY and killer_moves[ply].match(move)
			score += KILLER_BIAS if is_killer else REGULAR_BIAS
			score += history[board.move_colour_index][move.start_square][move.target_square]

		move_scores[i] = score

	quicksort(moves, move_scores, 0, moves.size() - 1)


static func get_piece_value(piece_type: int) -> int:
	match piece_type:
		Piece.QUEEN:
			return Evaluation.QUEEN_VALUE
		Piece.ROOK:
			return Evaluation.ROOK_VALUE
		Piece.KNIGHT:
			return Evaluation.KNIGHT_VALUE
		Piece.BISHOP:
			return Evaluation.BISHOP_VALUE
		Piece.PAWN:
			return Evaluation.PAWN_VALUE
		_:
			return 0


func get_score(index: int) -> String:
	var score: int = move_scores[index]

	var score_types: Array[int] = [HASH_MOVE_SCORE, WINNING_CAPTURE_BIAS, LOSING_CAPTURE_BIAS, PROMOTE_BIAS, KILLER_BIAS, REGULAR_BIAS]
	var type_names: Array[String] = ["Hash Move", "Good Capture", "Bad Capture", "Promote", "Killer Move", "Regular"]
	var type_name: String = ""
	var closest: int = 9223372036854775807

	for i in score_types.size():
		var delta: int = abs(score - score_types[i])
		if delta < closest:
			closest = delta
			type_name = type_names[i]

	return "%d (%s)" % [score, type_name]


static func sort(moves: Array, scores: Array) -> void:
	for i in range(moves.size() - 1):
		for j in range(i + 1, 0, -1):
			var swap_index: int = j - 1
			if scores[swap_index] < scores[j]:
				var temp_move = moves[j]
				moves[j] = moves[swap_index]
				moves[swap_index] = temp_move
				var temp_score: int = scores[j]
				scores[j] = scores[swap_index]
				scores[swap_index] = temp_score


static func quicksort(values: Array, scores: Array, low: int, high: int) -> void:
	if low < high:
		var pivot_index: int = partition(values, scores, low, high)
		quicksort(values, scores, low, pivot_index - 1)
		quicksort(values, scores, pivot_index + 1, high)


static func partition(values: Array, scores: Array, low: int, high: int) -> int:
	var pivot_score: int = scores[high]
	var i: int = low - 1

	for j in range(low, high):
		if scores[j] > pivot_score:
			i += 1
			var temp_val = values[i]
			values[i] = values[j]
			values[j] = temp_val
			var temp_score: int = scores[i]
			scores[i] = scores[j]
			scores[j] = temp_score

	var temp_val = values[i + 1]
	values[i + 1] = values[high]
	values[high] = temp_val
	var temp_score: int = scores[i + 1]
	scores[i + 1] = scores[high]
	scores[high] = temp_score

	return i + 1


class Killers:
	var move_a: Move
	var move_b: Move

	func _init() -> void:
		move_a = Move.NULL_MOVE
		move_b = Move.NULL_MOVE

	func add(move: Move) -> void:
		if move.value != move_a.value:
			move_b = move_a
			move_a = move

	func match(move: Move) -> bool:
		return move.value == move_a.value or move.value == move_b.value
