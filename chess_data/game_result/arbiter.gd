class_name Arbiter

enum GameResult {
	NOT_STARTED,
	IN_PROGRESS,
	WHITE_IS_MATED,
	BLACK_IS_MATED,
	STALEMATE,
	REPETITION,
	FIFTY_MOVE_RULE,
	INSUFFICIENT_MATERIAL,
	DRAW_BY_ARBITER,
	WHITE_TIMEOUT,
	BLACK_TIMEOUT,
	WHITE_ILLEGAL_MOVE,
	BLACK_ILLEGAL_MOVE
}


static func is_draw_result(result: GameResult) -> bool:
	return result in [
		GameResult.DRAW_BY_ARBITER,
		GameResult.FIFTY_MOVE_RULE,
		GameResult.REPETITION,
		GameResult.STALEMATE,
		GameResult.INSUFFICIENT_MATERIAL,
	]


static func is_win_result(result: GameResult) -> bool:
	return is_white_wins_result(result) or is_black_wins_result(result)


static func is_white_wins_result(result: GameResult) -> bool:
	return result in [GameResult.BLACK_IS_MATED, GameResult.BLACK_TIMEOUT, GameResult.BLACK_ILLEGAL_MOVE]


static func is_black_wins_result(result: GameResult) -> bool:
	return result in [GameResult.WHITE_IS_MATED, GameResult.WHITE_TIMEOUT, GameResult.WHITE_ILLEGAL_MOVE]


static func get_game_state(board: Board) -> GameResult:
	var move_generator: MoveGenerator = MoveGenerator.new()
	var moves: Array = move_generator.generate_moves(board)

	if moves.size() == 0:
		if move_generator.in_check():
			return GameResult.WHITE_IS_MATED if board.is_white_to_move else GameResult.BLACK_IS_MATED
		return GameResult.STALEMATE

	if board.fifty_move_counter >= 100:
		return GameResult.FIFTY_MOVE_RULE

	var rep_count: int = board.repetition_position_history.count(board.zobrist_key)
	if rep_count == 3:
		return GameResult.REPETITION

	if insufficient_material(board):
		return GameResult.INSUFFICIENT_MATERIAL

	return GameResult.IN_PROGRESS


static func insufficient_material(board: Board) -> bool:
	if board.pawns[Board.WHITE_INDEX].count() > 0 or board.pawns[Board.BLACK_INDEX].count() > 0:
		return false

	if board.friendly_orthogonal_sliders != 0 or board.enemy_orthogonal_sliders != 0:
		return false

	var num_white_bishops: int = board.bishops[Board.WHITE_INDEX].count()
	var num_black_bishops: int = board.bishops[Board.BLACK_INDEX].count()
	var num_white_knights: int = board.knights[Board.WHITE_INDEX].count()
	var num_black_knights: int = board.knights[Board.BLACK_INDEX].count()
	var num_white_minors: int = num_white_bishops + num_white_knights
	var num_black_minors: int = num_black_bishops + num_black_knights
	var num_minors: int = num_white_minors + num_black_minors

	if num_minors <= 1:
		return true

	if num_minors == 2 and num_white_bishops == 1 and num_black_bishops == 1:
		var white_bishop_is_light_square: bool = BoardHelper.light_square(board.bishops[Board.WHITE_INDEX].occupied_squares[0])
		var black_bishop_is_light_square: bool = BoardHelper.light_square(board.bishops[Board.BLACK_INDEX].occupied_squares[0])
		return white_bishop_is_light_square == black_bishop_is_light_square

	return false
