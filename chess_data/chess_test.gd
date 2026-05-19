# Run via: gdscript chess_data/test/chess_test.gd
# or attach to a Node and call run_tests() from _ready()
static func run_tests() -> void:
    _test_move_count_from_start()
    _test_make_unmake_roundtrip()
    _test_perft_depth1()

static func _test_move_count_from_start() -> void:
    var board = Board.new()
    board.load_position(FenUtility.position_from_fen(FenUtility.START_POSITION_FEN))
    var gen = MoveGenerator.new()
    var moves = gen.generate_moves(board)
    assert(moves.size() == 20, "Start position should have 20 moves, got %d" % moves.size())
    print("PASS: move count from start = 20")

static func _test_make_unmake_roundtrip() -> void:
    var board = Board.new()
    board.load_position(FenUtility.position_from_fen(FenUtility.START_POSITION_FEN))
    var fen_before = FenUtility.current_fen(board)
    var gen = MoveGenerator.new()
    var moves = gen.generate_moves(board)
    board.make_move(moves[0])
    board.unmake_move(moves[0])
    var fen_after = FenUtility.current_fen(board)
    assert(fen_before == fen_after, "FEN mismatch after make/unmake")
    print("PASS: make/unmake roundtrip")

static func _test_perft_depth1() -> void:
    # Perft(1) from start = 20 nodes
    var board = Board.new()
    board.load_position(FenUtility.position_from_fen(FenUtility.START_POSITION_FEN))
    var count = _perft(board, 1)
    assert(count == 20, "Perft(1) should be 20, got %d" % count)
    print("PASS: perft depth 1 = 20")

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
