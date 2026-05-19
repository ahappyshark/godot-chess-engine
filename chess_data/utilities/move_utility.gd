class_name MoveUtility

static func get_move_from_uci_name(move_name: String, board: Board) -> Move:
	var start_square: int = BoardHelper.square_index_from_name(move_name.substr(0, 2))
	var target_square: int = BoardHelper.square_index_from_name(move_name.substr(2, 2))
	var moved_piece_type: int = Piece.piece_type(board.square[start_square])
	var start_coord: Coord = Coord.coord_from_square_index(start_square)
	var target_coord: Coord = Coord.coord_from_square_index(target_square)

	# Figure out move flag
	var flag: int = Move.NO_FLAG
	if moved_piece_type == Piece.PAWN:
		# Promotion
		if move_name.length() > 4:
			match move_name[move_name.length() - 1]:
				"q": flag = Move.PROMOTE_TO_QUEEN_FLAG
				"r": flag = Move.PROMOTE_TO_ROOK_FLAG
				"n": flag = Move.PROMOTE_TO_KNIGHT_FLAG
				"b": flag = Move.PROMOTE_TO_BISHOP_FLAG
				_: flag = Move.NO_FLAG
		# Double pawn push
		elif abs(target_coord.rank_index - start_coord.rank_index) == 2:
			flag = Move.PAWN_TWO_UP_FLAG
		# En-passant
		elif start_coord.file_index != target_coord.file_index and board.square[target_square] == Piece.NONE:
			flag = Move.EN_PASSANT_CAPTURE_FLAG
	elif moved_piece_type == Piece.KING:
		if abs(start_coord.file_index - target_coord.file_index) > 1:
			flag = Move.CASTLE_FLAG

	return Move.create_with_flag(start_square, target_square, flag)
