class_name MoveUtility

static func get_move_from_uci_name(move_name: String, board: Board) -> Move:
	var start_square: int = BoardHelper.square_index_from_name(move_name.substr(0, 2))
	var target_square: int = BoardHelper.square_index_from_name(move_name.substr(2, 2))
	var moved_piece_type: int = Piece.piece_type(board.square[start_square])
	var start_coord: Coord = Coord.coord_from_square_index(start_square)
	var target_coord: Coord = Coord.coord_from_square_index(target_square)

	var flag: int = Move.NO_FLAG
	if moved_piece_type == Piece.PAWN:
		if move_name.length() > 4:
			match move_name[move_name.length() - 1]:
				"q": flag = Move.PROMOTE_TO_QUEEN_FLAG
				"r": flag = Move.PROMOTE_TO_ROOK_FLAG
				"n": flag = Move.PROMOTE_TO_KNIGHT_FLAG
				"b": flag = Move.PROMOTE_TO_BISHOP_FLAG
				_: flag = Move.NO_FLAG
		elif abs(target_coord.rank_index - start_coord.rank_index) == 2:
			flag = Move.PAWN_TWO_UP_FLAG
		elif start_coord.file_index != target_coord.file_index and board.square[target_square] == Piece.NONE:
			flag = Move.EN_PASSANT_CAPTURE_FLAG
	elif moved_piece_type == Piece.KING:
		if abs(start_coord.file_index - target_coord.file_index) > 1:
			flag = Move.CASTLE_FLAG

	return Move.create_with_flag(start_square, target_square, flag)


static func get_move_name_uci(move: Move) -> String:
	if move == null or move.is_null:
		return "0000"
	var name: String = BoardHelper.square_name_from_index(move.start_square)
	name += BoardHelper.square_name_from_index(move.target_square)
	if move.is_promotion:
		match move.promotion_piece_type:
			Piece.QUEEN:  name += "q"
			Piece.ROOK:   name += "r"
			Piece.BISHOP: name += "b"
			Piece.KNIGHT: name += "n"
	return name


static func get_move_name_san(move: Move, board: Board) -> String:
	# Basic SAN — full disambiguation added in a later pass if needed
	if move == null or move.is_null:
		return "--"
	var moved_piece_type: int = Piece.piece_type(board.square[move.start_square])
	var is_capture: bool = board.square[move.target_square] != Piece.NONE or move.move_flag == Move.EN_PASSANT_CAPTURE_FLAG

	if move.move_flag == Move.CASTLE_FLAG:
		return "O-O" if move.target_square > move.start_square else "O-O-O"

	var san: String = ""
	if moved_piece_type != Piece.PAWN:
		san += Piece.get_symbol(Piece.make_piece(moved_piece_type, Piece.WHITE))
	if is_capture:
		if moved_piece_type == Piece.PAWN:
			san += BoardHelper.FILES[BoardHelper.file_index(move.start_square)]
		san += "x"
	san += BoardHelper.square_name_from_index(move.target_square)
	if move.is_promotion:
		san += "=" + Piece.get_symbol(Piece.make_piece(move.promotion_piece_type, Piece.WHITE))
	return san
