class_name MoveGenerator

const MAX_MOVES: int = 218

enum PromotionMode { ALL, QUEEN_ONLY, QUEEN_AND_KNIGHT }

var promotions_to_generate: PromotionMode = PromotionMode.ALL

var is_white_to_move: bool
var friendly_colour: int
var opponent_colour: int
var friendly_king_square: int
var friendly_index: int
var enemy_index: int

var _in_check: bool
var _in_double_check: bool

var check_ray_bitmask: int
var pin_rays: int
var not_pin_rays: int
var opponent_attack_map_no_pawns: int
var opponent_attack_map: int
var opponent_pawn_attack_map: int
var opponent_sliding_attack_map: int

var generate_quiet_moves: bool
var board: Board
var curr_move_index: int

var enemy_pieces: int
var friendly_pieces: int
var all_pieces: int
var empty_squares: int
var empty_or_enemy_squares: int
var move_type_mask: int


func generate_moves(temp_board: Board, captures_only: bool = false) -> Array:
	var moves: Array = []
	moves.resize(MAX_MOVES)
	generate_moves_into(temp_board, moves, captures_only)
	return moves


func generate_moves_into(temp_board: Board, moves: Array, captures_only: bool = false) -> int:
	board = temp_board
	generate_quiet_moves = not captures_only

	_setup()

	_generate_king_moves(moves)

	if not _in_double_check:
		_generate_sliding_moves(moves)
		_generate_knight_moves(moves)
		_generate_pawn_moves(moves)

	moves.resize(curr_move_index)
	return moves.size()


func in_check() -> bool:
	return _in_check


func _setup() -> void:
	curr_move_index = 0
	_in_check = false
	_in_double_check = false
	check_ray_bitmask = 0
	pin_rays = 0

	is_white_to_move = board.move_colour == Piece.WHITE
	friendly_colour = board.move_colour
	opponent_colour = board.opponent_colour
	friendly_king_square = board.king_square[board.move_colour_index]
	friendly_index = board.move_colour_index
	enemy_index = 1 - friendly_index

	enemy_pieces = board.colour_bitboards[enemy_index]
	friendly_pieces = board.colour_bitboards[friendly_index]
	all_pieces = board.all_pieces_bitboard
	# DEBUG
	var d7: int = 51
	#print("d7 in all_pieces: ", (all_pieces >> d7) & 1)  # should be 0
	#print("d7 in white bitboard: ", (board.colour_bitboards[board.WHITE_INDEX] >> d7) & 1)
	#print("d7 in black bitboard: ", (board.colour_bitboards[board.BLACK_INDEX] >> d7) & 1)
	empty_squares = ~all_pieces
	empty_or_enemy_squares = empty_squares | enemy_pieces
	move_type_mask = -1 if generate_quiet_moves else enemy_pieces

	_calculate_attack_data()


func _generate_king_moves(moves: Array) -> void:
	var legal_mask: int = ~(opponent_attack_map | friendly_pieces)
	var king_moves: int = BitBoardUtility.king_moves[friendly_king_square] & legal_mask & move_type_mask
	while king_moves != 0:
		var lsb = BitBoardUtility.pop_lsb(king_moves)
		king_moves = lsb[0]
		var target_square: int = lsb[1]
		moves[curr_move_index] = Move.create_with_squares(friendly_king_square, target_square)
		curr_move_index += 1

	if not _in_check and generate_quiet_moves:
		var castle_blockers: int = opponent_attack_map | board.all_pieces_bitboard
		if board.current_game_state.has_kingside_castle_right(board.is_white_to_move):
			var castle_mask: int = Bits.WHITE_KINGSIDE_MASK if board.is_white_to_move else Bits.BLACK_KINGSIDE_MASK
			if (castle_mask & castle_blockers) == 0:
				var target_square: int = BoardHelper.G1 if board.is_white_to_move else BoardHelper.G8
				moves[curr_move_index] = Move.create_with_flag(friendly_king_square, target_square, Move.CASTLE_FLAG)
				curr_move_index += 1
		if board.current_game_state.has_queenside_castle_right(board.is_white_to_move):
			var castle_mask: int = Bits.WHITE_QUEENSIDE_MASK2 if board.is_white_to_move else Bits.BLACK_QUEENSIDE_MASK2
			var castle_block_mask: int = Bits.WHITE_QUEENSIDE_MASK if board.is_white_to_move else Bits.BLACK_QUEENSIDE_MASK
			if (castle_mask & castle_blockers) == 0 and (castle_block_mask & board.all_pieces_bitboard) == 0:
				var target_square: int = BoardHelper.C1 if board.is_white_to_move else BoardHelper.C8
				moves[curr_move_index] = Move.create_with_flag(friendly_king_square, target_square, Move.CASTLE_FLAG)
				curr_move_index += 1


func _generate_sliding_moves(moves: Array) -> void:
	var move_mask: int = empty_or_enemy_squares & check_ray_bitmask & move_type_mask

	var orthogonal_sliders: int = board.friendly_orthogonal_sliders
	var diagonal_sliders: int = board.friendly_diagonal_sliders

	if _in_check:
		orthogonal_sliders &= ~pin_rays
		diagonal_sliders &= ~pin_rays

	while orthogonal_sliders != 0:
		var lsb = BitBoardUtility.pop_lsb(orthogonal_sliders)
		orthogonal_sliders = lsb[0]
		var start_square: int = lsb[1]
		var move_squares: int = Magic.get_rook_attacks(start_square, all_pieces) & move_mask
		if _is_pinned(start_square):
			move_squares &= PrecomputedMoveData.align_mask[start_square][friendly_king_square]
		while move_squares != 0:
			var lsb2 = BitBoardUtility.pop_lsb(move_squares)
			move_squares = lsb2[0]
			var target_square: int = lsb2[1]
			moves[curr_move_index] = Move.create_with_squares(start_square, target_square)
			curr_move_index += 1

	while diagonal_sliders != 0:
		var lsb = BitBoardUtility.pop_lsb(diagonal_sliders)
		diagonal_sliders = lsb[0]
		var start_square: int = lsb[1]
		# DEBUG
		var raw_attacks = Magic.get_bishop_attacks(start_square, all_pieces)
		#print("Bishop/Queen diagonal from sq %d | raw_attacks: %d | move_mask: %d | result: %d" % [
			#start_square, raw_attacks, move_mask, raw_attacks & move_mask
		#])
		var move_squares: int = Magic.get_bishop_attacks(start_square, all_pieces) & move_mask
		if _is_pinned(start_square):
			move_squares &= PrecomputedMoveData.align_mask[start_square][friendly_king_square]
		while move_squares != 0:
			var lsb2 = BitBoardUtility.pop_lsb(move_squares)
			move_squares = lsb2[0]
			var target_square: int = lsb2[1]
			moves[curr_move_index] = Move.create_with_squares(start_square, target_square)
			curr_move_index += 1


func _generate_knight_moves(moves: Array) -> void:
	var friendly_knight_piece: int = Piece.make_piece(Piece.KNIGHT, board.move_colour)
	var knights: int = board.piece_bitboards[friendly_knight_piece] & not_pin_rays
	var move_mask: int = empty_or_enemy_squares & check_ray_bitmask & move_type_mask

	while knights != 0:
		var lsb = BitBoardUtility.pop_lsb(knights)
		knights = lsb[0]
		var knight_square: int = lsb[1]
		var move_squares: int = BitBoardUtility.knight_attacks[knight_square] & move_mask
		while move_squares != 0:
			var lsb2 = BitBoardUtility.pop_lsb(move_squares)
			move_squares = lsb2[0]
			var target_square: int = lsb2[1]
			moves[curr_move_index] = Move.create_with_squares(knight_square, target_square)
			curr_move_index += 1


func _generate_pawn_moves(moves: Array) -> void:
	var push_dir: int = 1 if board.is_white_to_move else -1
	var push_offset: int = push_dir * 8

	var friendly_pawn_piece: int = Piece.make_piece(Piece.PAWN, board.move_colour)
	var pawns: int = board.piece_bitboards[friendly_pawn_piece]

	var promotion_rank_mask: int = BitBoardUtility.rank_8 if board.is_white_to_move else BitBoardUtility.rank_1

	var single_push: int = BitBoardUtility.shift(pawns, push_offset) & empty_squares
	var push_promotions: int = single_push & promotion_rank_mask & check_ray_bitmask

	var capture_edge_file_mask: int = BitBoardUtility.not_a_file if board.is_white_to_move else BitBoardUtility.not_h_file
	var capture_edge_file_mask2: int = BitBoardUtility.not_h_file if board.is_white_to_move else BitBoardUtility.not_a_file
	var capture_a: int = BitBoardUtility.shift(pawns & capture_edge_file_mask, push_dir * 7) & enemy_pieces
	var capture_b: int = BitBoardUtility.shift(pawns & capture_edge_file_mask2, push_dir * 9) & enemy_pieces

	var single_push_no_promotions: int = single_push & ~promotion_rank_mask & check_ray_bitmask
	var capture_promotions_a: int = capture_a & promotion_rank_mask & check_ray_bitmask
	var capture_promotions_b: int = capture_b & promotion_rank_mask & check_ray_bitmask

	capture_a &= check_ray_bitmask & ~promotion_rank_mask
	capture_b &= check_ray_bitmask & ~promotion_rank_mask

	if generate_quiet_moves:
		while single_push_no_promotions != 0:
			var lsb = BitBoardUtility.pop_lsb(single_push_no_promotions)
			single_push_no_promotions = lsb[0]
			var target_square: int = lsb[1]
			var start_square: int = target_square - push_offset
			if not _is_pinned(start_square) or PrecomputedMoveData.align_mask[start_square][friendly_king_square] == PrecomputedMoveData.align_mask[target_square][friendly_king_square]:
				moves[curr_move_index] = Move.create_with_squares(start_square, target_square)
				curr_move_index += 1

		var double_push_target_rank_mask: int = BitBoardUtility.rank_4 if board.is_white_to_move else BitBoardUtility.rank_5
		var double_push: int = BitBoardUtility.shift(single_push, push_offset) & empty_squares & double_push_target_rank_mask & check_ray_bitmask
		while double_push != 0:
			var lsb = BitBoardUtility.pop_lsb(double_push)
			double_push = lsb[0]
			var target_square: int = lsb[1]
			var start_square: int = target_square - push_offset * 2
			if not _is_pinned(start_square) or PrecomputedMoveData.align_mask[start_square][friendly_king_square] == PrecomputedMoveData.align_mask[target_square][friendly_king_square]:
				moves[curr_move_index] = Move.create_with_flag(start_square, target_square, Move.PAWN_TWO_UP_FLAG)
				curr_move_index += 1

	while capture_a != 0:
		var lsb = BitBoardUtility.pop_lsb(capture_a)
		capture_a = lsb[0]
		var target_square: int = lsb[1]
		var start_square: int = target_square - push_dir * 7
		if not _is_pinned(start_square) or PrecomputedMoveData.align_mask[start_square][friendly_king_square] == PrecomputedMoveData.align_mask[target_square][friendly_king_square]:
			moves[curr_move_index] = Move.create_with_squares(start_square, target_square)
			curr_move_index += 1

	while capture_b != 0:
		var lsb = BitBoardUtility.pop_lsb(capture_b)
		capture_b = lsb[0]
		var target_square: int = lsb[1]
		var start_square: int = target_square - push_dir * 9
		if not _is_pinned(start_square) or PrecomputedMoveData.align_mask[start_square][friendly_king_square] == PrecomputedMoveData.align_mask[target_square][friendly_king_square]:
			moves[curr_move_index] = Move.create_with_squares(start_square, target_square)
			curr_move_index += 1

	while push_promotions != 0:
		var lsb = BitBoardUtility.pop_lsb(push_promotions)
		push_promotions = lsb[0]
		var target_square: int = lsb[1]
		var start_square: int = target_square - push_offset
		if not _is_pinned(start_square):
			_generate_promotions(start_square, target_square, moves)

	while capture_promotions_a != 0:
		var lsb = BitBoardUtility.pop_lsb(capture_promotions_a)
		capture_promotions_a = lsb[0]
		var target_square: int = lsb[1]
		var start_square: int = target_square - push_dir * 7
		if not _is_pinned(start_square) or PrecomputedMoveData.align_mask[start_square][friendly_king_square] == PrecomputedMoveData.align_mask[target_square][friendly_king_square]:
			_generate_promotions(start_square, target_square, moves)

	while capture_promotions_b != 0:
		var lsb = BitBoardUtility.pop_lsb(capture_promotions_b)
		capture_promotions_b = lsb[0]
		var target_square: int = lsb[1]
		var start_square: int = target_square - push_dir * 9
		if not _is_pinned(start_square) or PrecomputedMoveData.align_mask[start_square][friendly_king_square] == PrecomputedMoveData.align_mask[target_square][friendly_king_square]:
			_generate_promotions(start_square, target_square, moves)

	if board.current_game_state.en_passant_file > 0:
		var ep_file_index: int = board.current_game_state.en_passant_file - 1
		var ep_rank_index: int = 5 if board.is_white_to_move else 2
		var target_square: int = ep_rank_index * 8 + ep_file_index
		var captured_pawn_square: int = target_square - push_offset

		if BitBoardUtility.contains_square(check_ray_bitmask, captured_pawn_square):
			var pawns_that_can_capture_ep: int = pawns & BitBoardUtility.pawn_attacks(1 << target_square, not board.is_white_to_move)
			while pawns_that_can_capture_ep != 0:
				var lsb: Array = BitBoardUtility.pop_lsb(pawns_that_can_capture_ep)
				pawns_that_can_capture_ep = lsb[0]
				var start_square: int = lsb[1]
				if not _is_pinned(start_square) or PrecomputedMoveData.align_mask[start_square][friendly_king_square] == PrecomputedMoveData.align_mask[target_square][friendly_king_square]:
					if not _in_check_after_en_passant(start_square, target_square, captured_pawn_square):
						moves[curr_move_index] = Move.create_with_flag(start_square, target_square, Move.EN_PASSANT_CAPTURE_FLAG)
						curr_move_index += 1


func _generate_promotions(start_square: int, target_square: int, moves: Array) -> void:
	moves[curr_move_index] = Move.create_with_flag(start_square, target_square, Move.PROMOTE_TO_QUEEN_FLAG)
	curr_move_index += 1
	if generate_quiet_moves:
		if promotions_to_generate == PromotionMode.ALL:
			moves[curr_move_index] = Move.create_with_flag(start_square, target_square, Move.PROMOTE_TO_KNIGHT_FLAG)
			curr_move_index += 1
			moves[curr_move_index] = Move.create_with_flag(start_square, target_square, Move.PROMOTE_TO_ROOK_FLAG)
			curr_move_index += 1
			moves[curr_move_index] = Move.create_with_flag(start_square, target_square, Move.PROMOTE_TO_BISHOP_FLAG)
			curr_move_index += 1
		elif promotions_to_generate == PromotionMode.QUEEN_AND_KNIGHT:
			moves[curr_move_index] = Move.create_with_flag(start_square, target_square, Move.PROMOTE_TO_KNIGHT_FLAG)
			curr_move_index += 1


func _is_pinned(square: int) -> bool:
	return ((pin_rays >> square) & 1) != 0


func _gen_sliding_attack_map() -> void:
	opponent_sliding_attack_map = 0
	_update_slide_attack(board.enemy_orthogonal_sliders, true)
	_update_slide_attack(board.enemy_diagonal_sliders, false)


func _update_slide_attack(piece_board: int, ortho: bool) -> void:
	var blockers: int = board.all_pieces_bitboard & ~(1 << friendly_king_square)
	while piece_board != 0:
		var lsb = BitBoardUtility.pop_lsb(piece_board)
		piece_board = lsb[0]
		var start_square: int = lsb[1]
		var move_board: int = Magic.get_slider_attacks(start_square, blockers, ortho)
		opponent_sliding_attack_map |= move_board


func _calculate_attack_data() -> void:
	_gen_sliding_attack_map()

	var start_dir_index: int = 0
	var end_dir_index: int = 8

	if board.queens[enemy_index].count() == 0:
		start_dir_index = 0 if board.rooks[enemy_index].count() > 0 else 4
		end_dir_index = 8 if board.bishops[enemy_index].count() > 0 else 4

	for dir in range(start_dir_index, end_dir_index):
		var is_diagonal: bool = dir > 3
		var slider: int = board.enemy_diagonal_sliders if is_diagonal else board.enemy_orthogonal_sliders
		if (PrecomputedMoveData.dir_ray_mask[dir][friendly_king_square] & slider) == 0:
			continue

		var n: int = PrecomputedMoveData.num_squares_to_edge[friendly_king_square][dir]
		var direction_offset: int = PrecomputedMoveData.direction_offsets[dir]
		var is_friendly_piece_along_ray: bool = false
		var ray_mask: int = 0

		for i in n:
			var square_index: int = friendly_king_square + direction_offset * (i + 1)
			ray_mask |= 1 << square_index
			var piece: int = board.square[square_index]

			if piece != Piece.NONE:
				if Piece.is_color(piece, friendly_colour):
					if not is_friendly_piece_along_ray:
						is_friendly_piece_along_ray = true
					else:
						break
				else:
					var piece_type: int = Piece.piece_type(piece)
					if (is_diagonal and Piece.is_diagonal_slider(piece_type)) or (not is_diagonal and Piece.is_orthogonal_slider(piece_type)):
						if is_friendly_piece_along_ray:
							pin_rays |= ray_mask
						else:
							check_ray_bitmask |= ray_mask
							_in_double_check = _in_check
							_in_check = true
						break
					else:
						break

		if _in_double_check:
			break

	not_pin_rays = ~pin_rays

	var opponent_knight_attacks: int = 0
	var knights: int = board.piece_bitboards[Piece.make_piece(Piece.KNIGHT, board.opponent_colour)]
	var friendly_king_board: int = board.piece_bitboards[Piece.make_piece(Piece.KING, board.move_colour)]

	while knights != 0:
		var lsb = BitBoardUtility.pop_lsb(knights)
		knights = lsb[0]
		var knight_square: int = lsb[1]
		var knight_attacks: int = BitBoardUtility.knight_attacks[knight_square]
		opponent_knight_attacks |= knight_attacks
		if (knight_attacks & friendly_king_board) != 0:
			_in_double_check = _in_check
			_in_check = true
			check_ray_bitmask |= 1 << knight_square

	var opponent_pawns_board: int = board.piece_bitboards[Piece.make_piece(Piece.PAWN, board.opponent_colour)]
	opponent_pawn_attack_map = BitBoardUtility.pawn_attacks(opponent_pawns_board, not is_white_to_move)
	if BitBoardUtility.contains_square(opponent_pawn_attack_map, friendly_king_square):
		_in_double_check = _in_check
		_in_check = true
		var possible_pawn_attack_origins: int = BitBoardUtility.white_pawn_attacks[friendly_king_square] if board.is_white_to_move else BitBoardUtility.black_pawn_attacks[friendly_king_square]
		var pawn_check_map: int = opponent_pawns_board & possible_pawn_attack_origins
		check_ray_bitmask |= pawn_check_map

	var enemy_king_square: int = board.king_square[enemy_index]
	opponent_attack_map_no_pawns = opponent_sliding_attack_map | opponent_knight_attacks | BitBoardUtility.king_moves[enemy_king_square]
	opponent_attack_map = opponent_attack_map_no_pawns | opponent_pawn_attack_map

	if not _in_check:
		check_ray_bitmask = -1


func _in_check_after_en_passant(start_square: int, target_square: int, ep_capture_square: int) -> bool:
	var enemy_ortho: int = board.enemy_orthogonal_sliders
	if enemy_ortho != 0:
		var masked_blockers: int = all_pieces ^ (1 << ep_capture_square | 1 << start_square | 1 << target_square)
		var rook_attacks: int = Magic.get_rook_attacks(friendly_king_square, masked_blockers)
		return (rook_attacks & enemy_ortho) != 0
	return false
