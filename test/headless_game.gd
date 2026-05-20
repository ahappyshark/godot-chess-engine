class_name HeadlessGame

enum Result { WHITE_WIN, BLACK_WIN, DRAW }

const MAX_MOVES = 300  # prevent infinite games

static func play(white_bot: ChessBot, black_bot: ChessBot, start_fen: String = Board.game_start_fen) -> Result:
	var board = Board.new()
	board.load_position(start_fen)
	
	white_bot.set_board(board)
	black_bot.set_board(board)
	
	var move_gen = MoveGenerator.new()
	
	for _i in MAX_MOVES:
		var moves = move_gen.generate_moves(board)
		
		if moves.is_empty():
			if move_gen.in_check(board):
				return Result.BLACK_WIN if board.is_white_to_move else Result.WHITE_WIN
			return Result.DRAW  # stalemate
		
		if _is_draw_by_rule(board):
			return Result.DRAW
		
		var bot = white_bot if board.is_white_to_move else black_bot
		var chosen = bot.get_move()
		
		# validate the bot didn't return garbage
		if not moves.has(chosen):
			push_warning(bot.name + " returned illegal move, picking random")
			chosen = moves[randi() % moves.size()]
		
		var opponent = black_bot if board.is_white_to_move else white_bot
		board.make_move(chosen)
		opponent.on_opponent_move(chosen)
	
	return Result.DRAW  # hit move limit

static func _is_draw_by_rule(board: Board) -> bool:
	# fifty move rule, threefold repetition — check your board's state tracking
	return board.current_game_state.fifty_move_counter >= 100 \
		or board.repetition_position_history.count(board.current_game_state.zobrist_key) >= 3
