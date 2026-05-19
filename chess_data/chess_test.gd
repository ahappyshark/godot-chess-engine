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
	run_tests()
	
static func run_tests() -> void:
	_test_move_count_from_start()
	_test_make_unmake_roundtrip()
	_test_perft_depth()

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
