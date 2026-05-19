class_name PgnCreator


static func create_pgn(moves: Array) -> String:
	return create_pgn_with_result(moves, GameResult.IN_PROGRESS, FenUtility.START_POSITION_FEN)


static func create_pgn_from_board(board: Board, result: GameResult, white_name: String = "", black_name: String = "") -> String:
	return create_pgn_with_result(board.all_game_moves, result, board.game_start_fen, white_name, black_name)


static func create_pgn_with_result(moves: Array, result: GameResult, start_fen: String, white_name: String = "", black_name: String = "") -> String:
	start_fen = start_fen.replace("\n", "").replace("\r", "")

	var pgn: String = ""
	var board: Board = Board.new()
	board.load_position(FenUtility.position_from_fen(start_fen))

	if not white_name.is_empty():
		pgn += "[White \"%s\"]\n" % white_name
	if not black_name.is_empty():
		pgn += "[Black \"%s\"]\n" % black_name

	if start_fen != FenUtility.START_POSITION_FEN:
		pgn += "[FEN \"%s\"]\n" % start_fen
	if result not in [GameResult.NOT_STARTED, GameResult.IN_PROGRESS]:
		pgn += "[Result \"%s\"]\n" % result

	for ply_count: int in range(moves.size()):
		var move_string: String = MoveUtility.get_move_name_san(moves[ply_count], board)
		board.make_move(moves[ply_count])

		if ply_count % 2 == 0:
			pgn += str(ply_count / 2 + 1) + ". "
		pgn += move_string + " "

	return pgn
