class_name FenUtility

const START_POSITION_FEN: String = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

static func position_from_fen(fen: String) -> PositionInfo:
	return PositionInfo.new(fen)

static func current_fen(board: Board, always_include_ep_square: bool = true) -> String:
	var fen: String = ""

	for rank: int in range(7, -1, -1):
		var num_empty_files: int = 0
		for file: int in range(0, 8):
			var i: int = rank * 8 + file
			var piece: int = board.square[i]
			if piece != 0:
				if num_empty_files != 0:
					fen += str(num_empty_files)
					num_empty_files = 0
				var is_black: bool = Piece.is_color(piece, Piece.BLACK)
				var piece_type: int = Piece.piece_type(piece)
				var piece_char: String = ""
				match piece_type:
					Piece.ROOK:   piece_char = "R"
					Piece.KNIGHT: piece_char = "N"
					Piece.BISHOP: piece_char = "B"
					Piece.QUEEN:  piece_char = "Q"
					Piece.KING:   piece_char = "K"
					Piece.PAWN:   piece_char = "P"
				fen += piece_char.to_lower() if is_black else piece_char
			else:
				num_empty_files += 1

		if num_empty_files != 0:
			fen += str(num_empty_files)
		if rank != 0:
			fen += "/"

	# Side to move
	fen += " "
	fen += "w" if board.is_white_to_move else "b"

	# Castling
	var castling_rights: int = board.current_game_state.castling_rights
	var white_kingside: bool = (castling_rights & 1) == 1
	var white_queenside: bool = (castling_rights >> 1 & 1) == 1
	var black_kingside: bool = (castling_rights >> 2 & 1) == 1
	var black_queenside: bool = (castling_rights >> 3 & 1) == 1
	fen += " "
	fen += "K" if white_kingside else ""
	fen += "Q" if white_queenside else ""
	fen += "k" if black_kingside else ""
	fen += "q" if black_queenside else ""
	fen += "-" if castling_rights == 0 else ""

	# En passant
	fen += " "
	var ep_file_index: int = board.current_game_state.en_passant_file - 1
	var ep_rank_index: int = 5 if board.is_white_to_move else 2
	var is_en_passant: bool = ep_file_index != -1
	var include_ep: bool = always_include_ep_square or _en_passant_can_be_captured(ep_file_index, ep_rank_index, board)
	if is_en_passant and include_ep:
		fen += BoardHelper.square_name_from_coord(ep_file_index, ep_rank_index)
	else:
		fen += "-"

	# 50-move counter
	fen += " "
	fen += str(board.current_game_state.fifty_move_counter)

	# Full-move count
	fen += " "
	fen += str((board.ply_count >> 1) + 1)

	return fen

static func _en_passant_can_be_captured(ep_file_index: int, ep_rank_index: int, board: Board) -> bool:
	var rank_offset: int = -1 if board.is_white_to_move else 1
	var capture_from_a: Vector2i = Vector2i(ep_file_index - 1, ep_rank_index + rank_offset)
	var capture_from_b: Vector2i = Vector2i(ep_file_index + 1, ep_rank_index + rank_offset)
	var ep_capture_square: int = ep_rank_index * 8 + ep_file_index
	var friendly_pawn: int = Piece.make_piece(Piece.PAWN, board.move_colour)

	return (
		_can_capture(capture_from_a, ep_capture_square, friendly_pawn, board)
		or _can_capture(capture_from_b, ep_capture_square, friendly_pawn, board)
	)

static func _can_capture(from: Vector2i, ep_capture_square: int, friendly_pawn: int, board: Board) -> bool:
	if not _is_valid_square(from):
		return false
	var from_index: int = from.y * 8 + from.x
	if board.square[from_index] != friendly_pawn:
		return false
	var move: Move = Move.create_with_flag(from_index, ep_capture_square, Move.EN_PASSANT_CAPTURE_FLAG)
	board.make_move(move)
	board.make_null_move()
	var was_legal: bool = not board.calculate_in_check_state()
	board.unmake_null_move()
	board.unmake_move(move)
	return was_legal

static func _is_valid_square(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < 8 and coord.y >= 0 and coord.y < 8

static func flip_fen(fen: String) -> String:
	var flipped_fen: String = ""
	var sections: PackedStringArray = fen.split(" ")
	var fen_ranks: PackedStringArray = sections[0].split("/")

	for i: int in range(fen_ranks.size() - 1, -1, -1):
		var rank: String = fen_ranks[i]
		for j: int in range(rank.length()):
			flipped_fen += _invert_case(rank[j])
		if i != 0:
			flipped_fen += "/"

	flipped_fen += " " + ("b" if sections[1][0] == "w" else "w")

	var castling_rights: String = sections[2]
	var flipped_rights: String = ""
	for c: String in ["k", "q", "K", "Q"]:
		if castling_rights.contains(c):
			flipped_rights += _invert_case(c)
	flipped_fen += " " + ("-" if flipped_rights.is_empty() else flipped_rights)

	var ep: String = sections[3]
	var flipped_ep: String = ep[0]
	if ep.length() > 1:
		flipped_ep += "3" if ep[1] == "6" else "6"
	flipped_fen += " " + flipped_ep
	flipped_fen += " " + sections[4] + " " + sections[5]

	return flipped_fen

static func _invert_case(c: String) -> String:
	if c >= "a" and c <= "z":
		return c.to_upper()
	return c.to_lower()

class PositionInfo:
	var fen: String
	var squares: Array[int]

	var white_castle_kingside: bool
	var white_castle_queenside: bool
	var black_castle_kingside: bool
	var black_castle_queenside: bool
	var ep_file: int
	var white_to_move: bool
	var fifty_move_ply_count: int
	var move_count: int

	func _init(fen_string: String) -> void:
		fen = fen_string
		squares = []
		squares.resize(64)
		squares.fill(0)

		var sections: PackedStringArray = fen_string.split(" ")

		var file: int = 0
		var rank: int = 7

		for symbol: String in sections[0]:
			if symbol == "/":
				file = 0
				rank -= 1
			elif symbol >= "1" and symbol <= "8":
				file += int(symbol)
			else:
				var piece_colour: int = Piece.WHITE if symbol == symbol.to_upper() else Piece.BLACK
				var piece_type: int = Piece.NONE
				match symbol.to_lower():
					"k": piece_type = Piece.KING
					"p": piece_type = Piece.PAWN
					"n": piece_type = Piece.KNIGHT
					"b": piece_type = Piece.BISHOP
					"r": piece_type = Piece.ROOK
					"q": piece_type = Piece.QUEEN
				squares[rank * 8 + file] = piece_type | piece_colour
				file += 1

		white_to_move = sections[1] == "w"

		var castling_rights: String = sections[2]
		white_castle_kingside = castling_rights.contains("K")
		white_castle_queenside = castling_rights.contains("Q")
		black_castle_kingside = castling_rights.contains("k")
		black_castle_queenside = castling_rights.contains("q")

		ep_file = 0
		fifty_move_ply_count = 0
		move_count = 0

		if sections.size() > 3:
			var ep_file_name: String = sections[3][0]
			if BoardHelper.FILES.contains(ep_file_name):
				ep_file = BoardHelper.FILES.find(ep_file_name) + 1

		if sections.size() > 4:
			fifty_move_ply_count = sections[4].to_int()

		if sections.size() > 5:
			move_count = sections[5].to_int()
