class_name Zobrist

static var pieces_array: Array
static var castling_rights: Array[int]
static var en_passant_file: Array[int]
static var side_to_move: int

static func _static_init() -> void:
	pieces_array = []
	pieces_array.resize(Piece.MAX_PIECE_INDEX + 1)
	for i: int in Piece.MAX_PIECE_INDEX + 1:
		pieces_array[i] = []
	castling_rights = []
	castling_rights.resize(16)
	en_passant_file = []
	en_passant_file.resize(9) # 0 = no en passant, 1-8 = file a-h

	for _i: int in 64:
		for piece: int in Piece.piece_indices:
			pieces_array[piece].append(RngService.randi64())

	for i: int in 16:
		castling_rights[i] = RngService.randi64()

	for i: int in 9:
		en_passant_file[i] = RngService.randi64()

	side_to_move = RngService.randi64()

static func calculate_zobrist_key(board: Board) -> int:
	var zobrist_key: int = 0
	for square_index: int in range(64):
		var piece: int = board.square[square_index]
		if Piece.piece_type(piece) != Piece.NONE:
			zobrist_key ^= pieces_array[piece][square_index]

	zobrist_key ^= en_passant_file[board.current_game_state.en_passant_file]

	if board.move_colour == Piece.BLACK:
		zobrist_key ^= side_to_move

	zobrist_key ^= castling_rights[board.current_game_state.castling_rights]

	return zobrist_key
