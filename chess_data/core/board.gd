class_name Board

const WHITE_INDEX: int = 0
const BLACK_INDEX: int = 1

const CLEAR_WHITE_KINGSIDE_MASK: int = 0b1110
const CLEAR_WHITE_QUEENSIDE_MASK: int = 0b1101
const CLEAR_BLACK_KINGSIDE_MASK: int = 0b1011
const CLEAR_BLACK_QUEENSIDE_MASK: int = 0b0111

var square: Array[int] = []
var king_square: Array[int] = []

# Bitboard for each piece type and colour (white pawns, white knights, ... black pawns, etc.)
var piece_bitboards: Array[int]
# Bitboards for all pieces of either colour
var colour_bitboards: Array[int]
var all_pieces_bitboard: int
var friendly_orthogonal_sliders: int
var friendly_diagonal_sliders: int
var enemy_orthogonal_sliders: int
var enemy_diagonal_sliders: int

var total_piece_count_without_pawns_and_kings: int

# Piece Lists
var rooks: Array[PieceList]
var bishops: Array[PieceList]
var queens: Array[PieceList]
var knights: Array[PieceList]
var pawns: Array[PieceList]

# Side to move info
var is_white_to_move: bool
var move_colour: int:
	get:
		return Piece.WHITE if is_white_to_move else Piece.BLACK
var opponent_colour: int:
	get:
		return Piece.BLACK if is_white_to_move else Piece.WHITE
var move_colour_index: int:
	get:
		return WHITE_INDEX if is_white_to_move else BLACK_INDEX
var opponent_colour_index: int:
	get:
		return BLACK_INDEX if is_white_to_move else WHITE_INDEX

# List of (hashed) positions since last pawn move or capture (for detecting repetitions)
var repetition_position_history: Array[int]
# Game State and stack of gamestate history
var current_game_state: GameState
var game_state_history: Array[GameState]

# Total plies (half-moves) played in game
var ply_count: int
var fifty_move_counter: int:
	get:
		return current_game_state.fifty_move_counter
var zobrist_key: int:
	get:
		return current_game_state.zobrist_key

var current_fen: String:
	get:
		return FenUtility.current_fen(self)

var game_start_fen: String:
	get:
		return start_position_info.fen

var start_position_info: FenUtility.PositionInfo
var all_game_moves: Array[Move]

var _all_piece_lists: Array
var _cached_in_check_value: bool
var _has_cached_in_check_value: bool


func _init() -> void:
	square.resize(64)


func make_move(move: Move, in_search: bool = false) -> void:
	var start_square: int = move.start_square
	var target_square: int = move.target_square
	var move_flag: int = move.move_flag
	var is_promotion: bool = move.is_promotion
	var is_en_passant: bool = move_flag == Move.EN_PASSANT_CAPTURE_FLAG

	var moved_piece: int = square[start_square]
	var moved_piece_type: int = Piece.piece_type(moved_piece)
	var captured_piece: int = Piece.make_piece(Piece.PAWN, opponent_colour) if is_en_passant else square[target_square]
	var captured_piece_type: int = Piece.piece_type(captured_piece)

	var prev_castle_state: int = current_game_state.castling_rights
	var prev_en_passant_file: int = current_game_state.en_passant_file
	var new_zobrist_key: int = current_game_state.zobrist_key
	var new_castling_rights: int = current_game_state.castling_rights
	var new_en_passant_file: int = 0

	_move_piece(moved_piece, start_square, target_square)

	if captured_piece_type != Piece.NONE:
		var capture_square: int = target_square
		if is_en_passant:
			capture_square = target_square + (-8 if is_white_to_move else 8)
			square[capture_square] = Piece.NONE
		if captured_piece_type != Piece.PAWN:
			total_piece_count_without_pawns_and_kings -= 1
		_all_piece_lists[captured_piece].remove_piece_at_square(capture_square)
		piece_bitboards[captured_piece] = BitBoardUtility.toggle_square(piece_bitboards[captured_piece], capture_square)
		colour_bitboards[opponent_colour_index] = BitBoardUtility.toggle_square(colour_bitboards[opponent_colour_index], capture_square)
		new_zobrist_key ^= Zobrist.pieces_array[captured_piece][capture_square]

	if moved_piece_type == Piece.KING:
		king_square[move_colour_index] = target_square
		new_castling_rights &= (0b1100 if is_white_to_move else 0b0011)

		if move_flag == Move.CASTLE_FLAG:
			var rook_piece: int = Piece.make_piece(Piece.ROOK, move_colour)
			var kingside: bool = target_square == BoardHelper.G1 or target_square == BoardHelper.G8
			var castling_rook_from: int = target_square + 1 if kingside else target_square - 2
			var castling_rook_to: int = target_square - 1 if kingside else target_square + 1

			piece_bitboards[rook_piece] = BitBoardUtility.toggle_squares(piece_bitboards[rook_piece], castling_rook_from, castling_rook_to)
			colour_bitboards[move_colour_index] = BitBoardUtility.toggle_squares(colour_bitboards[move_colour_index], castling_rook_from, castling_rook_to)
			_all_piece_lists[rook_piece].move_piece(castling_rook_from, castling_rook_to)
			square[castling_rook_from] = Piece.NONE
			square[castling_rook_to] = Piece.ROOK | move_colour

			new_zobrist_key ^= Zobrist.pieces_array[rook_piece][castling_rook_from]
			new_zobrist_key ^= Zobrist.pieces_array[rook_piece][castling_rook_to]

	if is_promotion:
		total_piece_count_without_pawns_and_kings += 1
		var promotion_piece_type: int = move.promotion_piece_type
		var promotion_piece: int = Piece.make_piece(promotion_piece_type, move_colour)

		piece_bitboards[moved_piece] = BitBoardUtility.toggle_square(piece_bitboards[moved_piece], target_square)
		piece_bitboards[promotion_piece] = BitBoardUtility.toggle_square(piece_bitboards[promotion_piece], target_square)
		_all_piece_lists[moved_piece].remove_piece_at_square(target_square)
		_all_piece_lists[promotion_piece].add_piece_at_square(target_square)
		square[target_square] = promotion_piece

	if move_flag == Move.PAWN_TWO_UP_FLAG:
		var file: int = BoardHelper.file_index(start_square) + 1
		new_en_passant_file = file
		new_zobrist_key ^= Zobrist.en_passant_file[file]

	if prev_castle_state != 0:
		if target_square == BoardHelper.H1 or start_square == BoardHelper.H1:
			new_castling_rights &= CLEAR_WHITE_KINGSIDE_MASK
		elif target_square == BoardHelper.A1 or start_square == BoardHelper.A1:
			new_castling_rights &= CLEAR_WHITE_QUEENSIDE_MASK
		if target_square == BoardHelper.H8 or start_square == BoardHelper.H8:
			new_castling_rights &= CLEAR_BLACK_KINGSIDE_MASK
		elif target_square == BoardHelper.A8 or start_square == BoardHelper.A8:
			new_castling_rights &= CLEAR_BLACK_QUEENSIDE_MASK

	new_zobrist_key ^= Zobrist.side_to_move
	new_zobrist_key ^= Zobrist.pieces_array[moved_piece][start_square]
	new_zobrist_key ^= Zobrist.pieces_array[square[target_square]][target_square]
	new_zobrist_key ^= Zobrist.en_passant_file[prev_en_passant_file]

	if new_castling_rights != prev_castle_state:
		new_zobrist_key ^= Zobrist.castling_rights[prev_castle_state]
		new_zobrist_key ^= Zobrist.castling_rights[new_castling_rights]

	is_white_to_move = not is_white_to_move
	ply_count += 1
	var new_fifty_move_counter: int = current_game_state.fifty_move_counter + 1

	all_pieces_bitboard = colour_bitboards[WHITE_INDEX] | colour_bitboards[BLACK_INDEX]
	update_slider_bitboards()

	if moved_piece_type == Piece.PAWN or captured_piece_type != Piece.NONE:
		if not in_search:
			repetition_position_history.clear()
		new_fifty_move_counter = 0

	var new_state: GameState = GameState.new(captured_piece_type, new_en_passant_file, new_castling_rights, new_fifty_move_counter, new_zobrist_key)
	game_state_history.push_back(new_state)
	current_game_state = new_state
	_has_cached_in_check_value = false

	if not in_search:
		repetition_position_history.push_back(new_state.zobrist_key)
		all_game_moves.append(move)


func unmake_move(move: Move, in_search: bool = false) -> void:
	is_white_to_move = not is_white_to_move

	var undoing_white_move: bool = is_white_to_move

	var moved_from: int = move.start_square
	var moved_to: int = move.target_square
	var move_flag: int = move.move_flag

	var undoing_en_passant: bool = move_flag == Move.EN_PASSANT_CAPTURE_FLAG
	var undoing_promotion: bool = move.is_promotion
	var undoing_capture: bool = current_game_state.captured_piece_type != Piece.NONE

	var moved_piece: int = Piece.make_piece(Piece.PAWN, move_colour) if undoing_promotion else square[moved_to]
	var moved_piece_type: int = Piece.piece_type(moved_piece)
	var captured_piece_type: int = current_game_state.captured_piece_type

	if undoing_promotion:
		var promoted_piece: int = square[moved_to]
		var pawn_piece: int = Piece.make_piece(Piece.PAWN, move_colour)
		total_piece_count_without_pawns_and_kings -= 1
		_all_piece_lists[promoted_piece].remove_piece_at_square(moved_to)
		_all_piece_lists[moved_piece].add_piece_at_square(moved_to)
		piece_bitboards[promoted_piece] = BitBoardUtility.toggle_square(piece_bitboards[promoted_piece], moved_to)
		piece_bitboards[pawn_piece] = BitBoardUtility.toggle_square(piece_bitboards[pawn_piece], moved_to)

	_move_piece(moved_piece, moved_to, moved_from)

	if undoing_capture:
		var capture_square: int = moved_to
		var captured_piece: int = Piece.make_piece(captured_piece_type, opponent_colour)

		if undoing_en_passant:
			capture_square = moved_to + (-8 if undoing_white_move else 8)
		if captured_piece_type != Piece.PAWN:
			total_piece_count_without_pawns_and_kings += 1

		piece_bitboards[captured_piece] = BitBoardUtility.toggle_square(piece_bitboards[captured_piece], capture_square)
		colour_bitboards[opponent_colour_index] = BitBoardUtility.toggle_square(colour_bitboards[opponent_colour_index], capture_square)
		_all_piece_lists[captured_piece].add_piece_at_square(capture_square)
		square[capture_square] = captured_piece

	if moved_piece_type == Piece.KING:
		king_square[move_colour_index] = moved_from

		if move_flag == Move.CASTLE_FLAG:
			var rook_piece: int = Piece.make_piece(Piece.ROOK, move_colour)
			var kingside: bool = moved_to == BoardHelper.G1 or moved_to == BoardHelper.G8
			var rook_square_before: int = moved_to + 1 if kingside else moved_to - 2
			var rook_square_after: int = moved_to - 1 if kingside else moved_to + 1

			piece_bitboards[rook_piece] = BitBoardUtility.toggle_squares(piece_bitboards[rook_piece], rook_square_after, rook_square_before)
			colour_bitboards[move_colour_index] = BitBoardUtility.toggle_squares(colour_bitboards[move_colour_index], rook_square_after, rook_square_before)
			square[rook_square_after] = Piece.NONE
			square[rook_square_before] = rook_piece
			_all_piece_lists[rook_piece].move_piece(rook_square_after, rook_square_before)

	all_pieces_bitboard = colour_bitboards[WHITE_INDEX] | colour_bitboards[BLACK_INDEX]
	update_slider_bitboards()

	if not in_search and repetition_position_history.size() > 0:
		repetition_position_history.pop_back()
	if not in_search:
		all_game_moves.pop_back()

	game_state_history.pop_back()
	current_game_state = game_state_history.back()
	ply_count -= 1
	_has_cached_in_check_value = false


func make_null_move() -> void:
	is_white_to_move = not is_white_to_move
	ply_count += 1

	var new_zobrist_key: int = current_game_state.zobrist_key
	new_zobrist_key ^= Zobrist.side_to_move
	new_zobrist_key ^= Zobrist.en_passant_file[current_game_state.en_passant_file]

	var new_state: GameState = GameState.new(Piece.NONE, 0, current_game_state.castling_rights, current_game_state.fifty_move_counter + 1, new_zobrist_key)
	current_game_state = new_state
	game_state_history.push_back(current_game_state)
	update_slider_bitboards()
	_has_cached_in_check_value = true
	_cached_in_check_value = false


func unmake_null_move() -> void:
	is_white_to_move = not is_white_to_move
	ply_count -= 1
	game_state_history.pop_back()
	current_game_state = game_state_history.back()
	update_slider_bitboards()
	_has_cached_in_check_value = true
	_cached_in_check_value = false


func is_in_check() -> bool:
	if _has_cached_in_check_value:
		return _cached_in_check_value
	_cached_in_check_value = calculate_in_check_state()
	_has_cached_in_check_value = true
	return _cached_in_check_value


func calculate_in_check_state() -> bool:
	var king_sq: int = king_square[move_colour_index]
	var blockers: int = all_pieces_bitboard

	if enemy_orthogonal_sliders != 0:
		var rook_attacks: int = Magic.get_rook_attacks(king_sq, blockers)
		if (rook_attacks & enemy_orthogonal_sliders) != 0:
			return true

	if enemy_diagonal_sliders != 0:
		var bishop_attacks: int = Magic.get_bishop_attacks(king_sq, blockers)
		if (bishop_attacks & enemy_diagonal_sliders) != 0:
			return true

	var enemy_knights: int = piece_bitboards[Piece.make_piece(Piece.KNIGHT, opponent_colour)]
	if (BitBoardUtility.knight_attacks[king_sq] & enemy_knights) != 0:
		return true

	var enemy_pawns: int = piece_bitboards[Piece.make_piece(Piece.PAWN, opponent_colour)]
	var pawn_attack_mask: int = BitBoardUtility.white_pawn_attacks[king_sq] if is_white_to_move else BitBoardUtility.black_pawn_attacks[king_sq]
	if (pawn_attack_mask & enemy_pawns) != 0:
		return true

	return false


func load_start_position() -> void:
	load_position(FenUtility.position_from_fen(FenUtility.START_POSITION_FEN))


func load_position(pos_info: FenUtility.PositionInfo) -> void:
	start_position_info = pos_info
	_initialize()

	for square_index: int in range(64):
		var piece: int = pos_info.squares[square_index]
		var piece_type: int = Piece.piece_type(piece)
		var colour_index: int = WHITE_INDEX if Piece.is_white(piece) else BLACK_INDEX
		square[square_index] = piece

		if piece != Piece.NONE:
			piece_bitboards[piece] = BitBoardUtility.set_square(piece_bitboards[piece], square_index)
			colour_bitboards[colour_index] = BitBoardUtility.set_square(colour_bitboards[colour_index], square_index)

			if piece_type == Piece.KING:
				king_square[colour_index] = square_index
			else:
				_all_piece_lists[piece].add_piece_at_square(square_index)
			if piece_type != Piece.PAWN and piece_type != Piece.KING:
				total_piece_count_without_pawns_and_kings += 1

	is_white_to_move = pos_info.white_to_move

	all_pieces_bitboard = colour_bitboards[WHITE_INDEX] | colour_bitboards[BLACK_INDEX]
	update_slider_bitboards()

	var white_castle: int = (1 if pos_info.white_castle_kingside else 0) | (2 if pos_info.white_castle_queenside else 0)
	var black_castle: int = (4 if pos_info.black_castle_kingside else 0) | (8 if pos_info.black_castle_queenside else 0)
	var castling_rights: int = white_castle | black_castle

	ply_count = (pos_info.move_count - 1) * 2 + (0 if is_white_to_move else 1)

	current_game_state = GameState.new(Piece.NONE, pos_info.ep_file, castling_rights, pos_info.fifty_move_ply_count, 0)
	var zobrist: int = Zobrist.calculate_zobrist_key(self)
	current_game_state = GameState.new(Piece.NONE, pos_info.ep_file, castling_rights, pos_info.fifty_move_ply_count, zobrist)

	repetition_position_history.push_back(zobrist)
	game_state_history.push_back(current_game_state)


static func create_board(fen: String = FenUtility.START_POSITION_FEN) -> Board:
	var board: Board = Board.new()
	board.load_position(FenUtility.position_from_fen(fen))
	return board


static func create_board_from_source(source: Board) -> Board:
	var board: Board = Board.new()
	board.load_position(source.start_position_info)
	for i: int in range(source.all_game_moves.size()):
		board.make_move(source.all_game_moves[i])
	return board


func _move_piece(piece: int, start_square_idx: int, target_square_idx: int) -> void:
	piece_bitboards[piece] = BitBoardUtility.toggle_squares(piece_bitboards[piece], start_square_idx, target_square_idx)
	colour_bitboards[move_colour_index] = BitBoardUtility.toggle_squares(colour_bitboards[move_colour_index], start_square_idx, target_square_idx)
	_all_piece_lists[piece].move_piece(start_square_idx, target_square_idx)
	square[start_square_idx] = Piece.NONE
	square[target_square_idx] = piece


func update_slider_bitboards() -> void:
	var friendly_rook: int = Piece.make_piece(Piece.ROOK, move_colour)
	var friendly_queen: int = Piece.make_piece(Piece.QUEEN, move_colour)
	var friendly_bishop: int = Piece.make_piece(Piece.BISHOP, move_colour)
	friendly_orthogonal_sliders = piece_bitboards[friendly_rook] | piece_bitboards[friendly_queen]
	friendly_diagonal_sliders = piece_bitboards[friendly_bishop] | piece_bitboards[friendly_queen]

	var enemy_rook: int = Piece.make_piece(Piece.ROOK, opponent_colour)
	var enemy_queen: int = Piece.make_piece(Piece.QUEEN, opponent_colour)
	var enemy_bishop: int = Piece.make_piece(Piece.BISHOP, opponent_colour)
	enemy_orthogonal_sliders = piece_bitboards[enemy_rook] | piece_bitboards[enemy_queen]
	enemy_diagonal_sliders = piece_bitboards[enemy_bishop] | piece_bitboards[enemy_queen]


func _initialize() -> void:
	all_game_moves.clear()
	king_square.resize(2)
	king_square.fill(0)
	square.fill(0)

	repetition_position_history.clear()
	game_state_history.clear()

	current_game_state = GameState.new(0, 0, 0, 0, 0)
	ply_count = 0

	knights = [PieceList.new(10), PieceList.new(10)]
	pawns = [PieceList.new(8), PieceList.new(8)]
	rooks = [PieceList.new(10), PieceList.new(10)]
	bishops = [PieceList.new(10), PieceList.new(10)]
	queens = [PieceList.new(9), PieceList.new(9)]

	_all_piece_lists.resize(Piece.MAX_PIECE_INDEX + 1)
	_all_piece_lists[Piece.WHITE_PAWN] = pawns[WHITE_INDEX]
	_all_piece_lists[Piece.WHITE_KNIGHT] = knights[WHITE_INDEX]
	_all_piece_lists[Piece.WHITE_BISHOP] = bishops[WHITE_INDEX]
	_all_piece_lists[Piece.WHITE_ROOK] = rooks[WHITE_INDEX]
	_all_piece_lists[Piece.WHITE_QUEEN] = queens[WHITE_INDEX]
	_all_piece_lists[Piece.WHITE_KING] = PieceList.new(1)
	_all_piece_lists[Piece.BLACK_PAWN] = pawns[BLACK_INDEX]
	_all_piece_lists[Piece.BLACK_KNIGHT] = knights[BLACK_INDEX]
	_all_piece_lists[Piece.BLACK_BISHOP] = bishops[BLACK_INDEX]
	_all_piece_lists[Piece.BLACK_ROOK] = rooks[BLACK_INDEX]
	_all_piece_lists[Piece.BLACK_QUEEN] = queens[BLACK_INDEX]
	_all_piece_lists[Piece.BLACK_KING] = PieceList.new(1)

	total_piece_count_without_pawns_and_kings = 0

	piece_bitboards.resize(Piece.MAX_PIECE_INDEX + 1)
	piece_bitboards.fill(0)
	colour_bitboards.resize(2)
	colour_bitboards.fill(0)
	all_pieces_bitboard = 0
