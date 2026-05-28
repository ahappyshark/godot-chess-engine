extends Node
# Run via: gdscript chess_data/test/chess_test.gd

const PERFT_DICT: Dictionary = {
	0: 1,
	1: 20,
	2: 400,
	3: 8902,
	4: 197281,
	5: 4865609
}

# or attach to a Node and call run_tests() from _ready()
func _ready() -> void:
	# perft_divide_from_fen("rnbqkbnr/ppp1pppp/8/3p4/4P3/P7/1PPP1PPP/RNBQKBNR b KQkq - 0 2", 1)
	# perft_divide(4)
	run_tests()
	
static func run_tests() -> void:
	#_test_move_count_from_start()
	#_test_make_unmake_roundtrip()
	#_test_perft_depth()
	_test_tournament()

static func _test_move_count_from_start() -> void:
	var board = _new_board()
	var gen = MoveGenerator.new()
	var moves = gen.generate_moves(board)
	assert(moves.size() == 20, "Start position should have 20 moves, got %d" % moves.size())
	print("PASS: move count from start = 20")

static func _test_make_unmake_roundtrip() -> void:
	var board = _new_board()
	var fen_before = FenUtility.current_fen(board)
	var gen = MoveGenerator.new()
	var moves = gen.generate_moves(board)
	board.make_move(moves[0])
	board.unmake_move(moves[0])
	var fen_after = FenUtility.current_fen(board)
	assert(fen_before == fen_after, "FEN mismatch after make/unmake")
	print("PASS: make/unmake roundtrip")

static func _test_perft_depth() -> void:
	# Perft(1) from start = 20 nodes
	var board: Board
	var count: int
	for p in PERFT_DICT.keys():
		board = _new_board()
		count = _perft(board, p)
		if count == PERFT_DICT[p]:
			print("PASS: perft depth %d = %d" % [p, PERFT_DICT[p]])
		else:
			print("Perft(%d) should be %d, got %d" % [p, PERFT_DICT[p], count])

static func _perft(board: Board, depth: int) -> int:
	if depth == 0: return 1
	var gen = MoveGenerator.new()
	var moves = gen.generate_moves(board)
	var nodes = 0
	for move in moves:
		board.make_move(move)
		nodes += _perft(board, depth - 1)
		board.unmake_move(move)
	return nodes

static func _new_board() -> Board:
	var board = Board.new()
	board.load_position(FenUtility.position_from_fen(FenUtility.START_POSITION_FEN))
	return board
	
static func _move_to_uci(move: Move) -> String:
	const FILE_NAMES = "abcdefgh"
	var from = move.start_square
	var to = move.target_square
	var result = "%s%d%s%d" % [
		FILE_NAMES[from % 8], (from / 8) + 1,
		FILE_NAMES[to % 8], (to / 8) + 1
	]
	if move.is_promotion:
		match move.move_flag:
			Move.PROMOTE_TO_QUEEN_FLAG:  result += "q"
			Move.PROMOTE_TO_ROOK_FLAG:   result += "r"
			Move.PROMOTE_TO_BISHOP_FLAG: result += "b"
			Move.PROMOTE_TO_KNIGHT_FLAG: result += "n"
	return result
	
static func perft_divide(depth: int) -> void:
	var board = _new_board()
	var gen = MoveGenerator.new()
	var moves = gen.generate_moves(board)
	var total = 0
	var results = []

	for move in moves:
		board.make_move(move)
		var count = _perft(board, depth - 1)
		board.unmake_move(move)
		total += count
		results.append([_move_to_uci(move), count])

	results.sort_custom(func(a, b): return a[0] < b[0])
	for r in results:
		print("%s: %d" % [r[0], r[1]])
	print("Total: %d" % total)

static func perft_divide_from_fen(fen: String, depth: int) -> void:
	var board = Board.new()
	board.load_position(FenUtility.position_from_fen(fen))
	var gen = MoveGenerator.new()
	var moves = gen.generate_moves(board)
	var total = 0
	var results = []
	for move in moves:
		board.make_move(move)
		var count = _perft(board, depth - 1)
		board.unmake_move(move)
		total += count
		results.append([_move_to_uci(move), count])
	results.sort_custom(func(a, b): return a[0] < b[0])
	for r in results:
		print("%s: %d" % [r[0], r[1]])
	print("Total: %d" % total)

static func _test_tournament() -> void:
	var t = Tournament.new()
	t.add_bot(RandomBot.new("RandomBot-A"))
	t.add_bot(MinimaxBot.new())   # depth 2, ~ms per move
	t.add_bot(SearcherBot.new())  # depth 4 with TT + move ordering, ~ms per move
	t.add_bot(GreedyBot.new())
	t.run_round_robin(10)
