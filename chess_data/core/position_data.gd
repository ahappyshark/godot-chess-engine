class_name PositionData

const OPENING: int = 0
const MIDDLEGAME: int = 1
const ENDGAME: int = 2

var all_legal_moves: Array = []
var legal_moves_by_square: Dictionary = {}  # int -> Array[Move]
var opponent_attack_map: int = 0
var friendly_attack_map: int = 0
var pin_rays: int = 0
var in_check: bool = false
var in_double_check: bool = false
var hanging_pieces_friendly: int = 0  # friendly pieces attacked and undefended
var hanging_pieces_enemy: int = 0     # enemy pieces attacked and undefended
var material_balance: int = 0         # positive = white ahead, in centipawns
var game_phase: int = MIDDLEGAME      # TODO (item 4a): OPENING when position is in the book


static func compute(board: Board) -> PositionData:
	var data := PositionData.new()

	var gen := MoveGenerator.new()
	data.all_legal_moves = gen.generate_moves(board)
	data.opponent_attack_map = gen.opponent_attack_map
	data.pin_rays = gen.pin_rays
	data.in_check = gen.in_check()
	data.in_double_check = gen.in_double_check()

	for move in data.all_legal_moves:
		var sq: int = move.start_square
		if not data.legal_moves_by_square.has(sq):
			data.legal_moves_by_square[sq] = []
		data.legal_moves_by_square[sq].append(move)

	data.friendly_attack_map = MoveGenerator.compute_attack_map_for_color(
		board, board.is_white_to_move
	)

	var friendly_bb: int = board.colour_bitboards[board.move_colour_index]
	var enemy_bb: int = board.colour_bitboards[board.opponent_colour_index]
	var friendly_king_bb: int = board.piece_bitboards[Piece.make_piece(Piece.KING, board.move_colour)]
	var enemy_king_bb: int = board.piece_bitboards[Piece.make_piece(Piece.KING, board.opponent_colour)]
	var friendly_no_king: int = friendly_bb & ~friendly_king_bb
	var enemy_no_king: int = enemy_bb & ~enemy_king_bb

	data.hanging_pieces_friendly = data.opponent_attack_map & friendly_no_king & ~data.friendly_attack_map
	data.hanging_pieces_enemy = data.friendly_attack_map & enemy_no_king & ~data.opponent_attack_map

	var white_score: int = (
		board.queens[Board.WHITE_INDEX].count() * Evaluation.QUEEN_VALUE
		+ board.rooks[Board.WHITE_INDEX].count() * Evaluation.ROOK_VALUE
		+ board.bishops[Board.WHITE_INDEX].count() * Evaluation.BISHOP_VALUE
		+ board.knights[Board.WHITE_INDEX].count() * Evaluation.KNIGHT_VALUE
		+ board.pawns[Board.WHITE_INDEX].count() * Evaluation.PAWN_VALUE
	)
	var black_score: int = (
		board.queens[Board.BLACK_INDEX].count() * Evaluation.QUEEN_VALUE
		+ board.rooks[Board.BLACK_INDEX].count() * Evaluation.ROOK_VALUE
		+ board.bishops[Board.BLACK_INDEX].count() * Evaluation.BISHOP_VALUE
		+ board.knights[Board.BLACK_INDEX].count() * Evaluation.KNIGHT_VALUE
		+ board.pawns[Board.BLACK_INDEX].count() * Evaluation.PAWN_VALUE
	)
	data.material_balance = white_score - black_score

	# TODO (item 4a): query opening book here — set OPENING if position is on a known line
	if board.total_piece_count_without_pawns_and_kings <= 6:
		data.game_phase = ENDGAME
	else:
		data.game_phase = MIDDLEGAME

	return data
