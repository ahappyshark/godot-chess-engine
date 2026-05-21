# Chess Engine — Developer Reference

A GDScript chess engine for Godot 4. This document covers architecture,
file layout, data representations, and the public API surfaces that outside
code (UI, bots, tests) should connect through.

---

## Project layout

```
chess_data/
  chess_engine.gd          # Autoload — initialises all subsystems (add to project.godot)
  core/
    board.gd               # Central mutable game state
    piece.gd               # Piece type/colour constants and helpers
    piece_list.gd          # Fast square-lookup list used by Board
    move.gd                # Packed move value object
    game_state.gd          # Immutable snapshot pushed onto Board's history stack
    coord.gd               # (file, rank) coordinate helper
    zobrist.gd             # Zobrist hashing tables (static init)
    rng_service.gd         # Deterministic RNG used by Zobrist
  move_generation/
    move_generator.gd      # Pseudo-legal + legal move generator
    precomputed_move_data.gd  # Direction rays, alignment masks (static init)
    bitboards/
      bit_board_utility.gd # Bitboard ops, attack tables (needs initialize() call)
      bits.gd              # Named castle/rank/file masks (needs initialize() call)
    magics/
      magic.gd             # Magic-bitboard slider attack lookup (autoload)
      magic_helper.gd      # Internal helper
      precomputed_magics.gd # Precomputed magic numbers
  search/
    searcher.gd            # Iterative-deepening alpha-beta + quiescence search
    move_ordering.gd       # MVV-LVA, killer moves, history heuristic
    transposition_table.gd # Zobrist-keyed TT (64 MB default)
    repetition_table.gd    # Threefold-repetition tracker used during search
  evaluation/
    evaluation.gd          # Static evaluator (material + PST + endgame)
    piece_square_table.gd  # Piece-square tables (static init)
    precomputed_evaluation_data.gd  # Passed-pawn masks etc. (static init)
  utilities/
    fen_utility.gd         # FEN parse / generate
    board_helper.gd        # Square index helpers, named square constants
    move_utility.gd        # Move → UCI / SAN string
    pgn_creator.gd         # PGN export
    generate_magics.gd     # One-shot script used to regenerate magic numbers
  game_result/
    arbiter.gd             # Terminal-state detection (checkmate, draw rules)

bots/
  chess_bot.gd             # Abstract base — extend to make a new bot
  searcher_bot.gd          # SearcherBot: iterative deepening to fixed depth
  minimax_bot.gd           # MinimaxBot: plain negamax without TT/ordering
  random_bot.gd            # RandomBot: picks a random legal move

scenes/
  chess_board.gd           # Visual board + player input (Node2D scene)
  chess_match.gd           # Game controller (bot thread management)
  chess_piece.gd           # Single piece sprite
  board_highlights.gd      # Square highlight overlay

test/
  chess_test.gd            # Perft tests, make/unmake round-trip, tournament
  headless_game.gd         # Runs a full game without UI
  tournament.gd            # Pits two bots against each other N times
```

---

## Initialisation order

Two autoloads are required in `project.godot`:

| Order | Name          | Script                              |
|-------|---------------|-------------------------------------|
| 1     | `Magic`       | `chess_data/move_generation/magics/magic.gd` |
| 2     | `ChessEngine` | `chess_data/chess_engine.gd`         |

`ChessEngine._ready()` calls:
1. `BitBoardUtility.initialize()` — builds king/knight/pawn attack tables.
2. `Bits.initialize()` — builds castle and safety masks (depends on BitBoardUtility).

`PrecomputedMoveData`, `Zobrist`, `PieceSquareTable`, and
`PrecomputedEvaluationData` use `_static_init()` and initialise
automatically on first reference.

---

## Core data types

### `Piece` (static constants only)

```
Type constants : NONE=0  KING=1  PAWN=2  KNIGHT=3  BISHOP=4  ROOK=5  QUEEN=6
Colour constants: WHITE=0  BLACK=8
Combined        : WHITE_PAWN=2  BLACK_PAWN=10  … BLACK_QUEEN=14
MAX_PIECE_INDEX : 14
```

A piece integer is `type | colour`. Extract with:

```gdscript
Piece.piece_type(piece)   # → 0-6
Piece.piece_color(piece)  # → 0 or 8
Piece.is_white(piece)
Piece.make_piece(type, colour)
```

### `Move` (packed int, `RefCounted`)

Encoded as a 16-bit value: `flag(4) | target(6) | start(6)`.

```gdscript
Move.create_with_squares(start, target)
Move.create_with_flag(start, target, flag)
Move.NULL_MOVE                  # sentinel — check with move.is_null

move.start_square               # 0-63
move.target_square              # 0-63
move.move_flag                  # one of the flag constants below
move.is_promotion               # flag >= PROMOTE_TO_QUEEN_FLAG
move.promotion_piece_type       # Piece.QUEEN / KNIGHT / ROOK / BISHOP
```

Flag constants (on `Move`):

```
NO_FLAG               = 0
EN_PASSANT_CAPTURE_FLAG = 1
CASTLE_FLAG           = 2
PAWN_TWO_UP_FLAG      = 3
PROMOTE_TO_QUEEN_FLAG = 4
PROMOTE_TO_KNIGHT_FLAG= 5
PROMOTE_TO_ROOK_FLAG  = 6
PROMOTE_TO_BISHOP_FLAG= 7
```

### `Board`

The single source of truth for game state. Mutable — modified by
`make_move` / `unmake_move`.

**Key fields (read-only from outside)**

```gdscript
board.square: Array[int]        # 64-element array; square[sq] → piece int
board.is_white_to_move: bool
board.move_colour: int          # Piece.WHITE or Piece.BLACK (computed)
board.opponent_colour: int      # (computed)
board.move_colour_index: int    # 0=white, 1=black (computed)
board.king_square: Array[int]   # [white_king_sq, black_king_sq]
board.ply_count: int
board.current_game_state: GameState
board.all_pieces_bitboard: int
board.piece_bitboards: Array[int]   # indexed by piece int (0-14)
board.colour_bitboards: Array[int]  # [white_bb, black_bb]

# PieceLists (indexed [WHITE_INDEX=0, BLACK_INDEX=1])
board.pawns:   Array[PieceList]
board.knights: Array[PieceList]
board.bishops: Array[PieceList]
board.rooks:   Array[PieceList]
board.queens:  Array[PieceList]
```

**Creating a board**

```gdscript
# From the standard starting position:
var board := Board.create_board()

# From a FEN string:
var board := Board.create_board("r1bqkbnr/pp1ppppp/2n5/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3")

# Deep copy of an existing board:
var clone := Board.create_board_from_source(source_board)

# Or load a position manually:
var board := Board.new()
board.load_position(FenUtility.position_from_fen(fen_string))
```

**Making / unmaking moves**

```gdscript
board.make_move(move)                # in_search=false (default) → updates repetition history
board.make_move(move, true)          # in_search=true → skips repetition history (use in search)
board.unmake_move(move)              # must be called in reverse order
board.unmake_move(move, true)
board.is_in_check() -> bool
```

**Important invariant**: every `make_move(m, true)` in a search branch
**must** be paired with exactly one `unmake_move(m, true)` before the
function returns. Do not share a `Board` object between threads while
either thread is calling `make_move`/`unmake_move` — modify only the
board the search owns, or use `Board.create_board_from_source` to get a
private copy.

### `GameState`

Immutable snapshot created by each `make_move` and pushed onto
`board.game_state_history`.

```gdscript
state.captured_piece_type: int   # Piece type (0=none)
state.en_passant_file: int       # 1-8, or 0 if none
state.castling_rights: int       # bitmask: bit0=WK, bit1=WQ, bit2=BK, bit3=BQ
state.fifty_move_counter: int
state.zobrist_key: int
state.has_kingside_castle_right(white: bool) -> bool
state.has_queenside_castle_right(white: bool) -> bool
```

### `PieceList`

Per-piece-type list that tracks occupied squares for fast iteration.

```gdscript
list.count() -> int
list.occupied_squares: Array[int]   # valid indices are 0 .. count()-1
```

Do not call `add_piece_at_square` / `remove_piece_at_square` /
`move_piece` directly — `Board.make_move` and `unmake_move` maintain
these automatically.

---

## Move generation

```gdscript
var gen := MoveGenerator.new()

# Generate all legal moves for the side to move.
var moves: Array = gen.generate_moves(board)

# Captures only (for quiescence search).
# Note: push-promotions are also included even in captures-only mode.
var captures: Array = gen.generate_moves(board, true)

gen.in_check() -> bool            # valid after the last generate_moves call
gen.opponent_attack_map: int      # bitboard of squares attacked by the opponent
gen.opponent_pawn_attack_map: int
```

`promotions_to_generate` controls which under-promotions are emitted:

```gdscript
gen.promotions_to_generate = MoveGenerator.PromotionMode.ALL
gen.promotions_to_generate = MoveGenerator.PromotionMode.QUEEN_ONLY
gen.promotions_to_generate = MoveGenerator.PromotionMode.QUEEN_AND_KNIGHT  # default in Searcher
```

---

## Search

### `Searcher`

Alpha-beta with iterative deepening, quiescence search, TT, LMR,
move ordering, and check/pawn-push extensions.

```gdscript
var searcher := Searcher.new(board)   # board is the shared game board

# Run a full iterative-deepening search (async-safe via on_search_complete signal):
searcher.start_search()
# signal: searcher.on_search_complete(move: Move)

# Or call search() directly for a synchronous fixed-depth result:
searcher.search(depth, 0, Searcher.NEGATIVE_INFINITY, Searcher.POSITIVE_INFINITY)
var best: Move = searcher.best_move_this_iteration

searcher.end_search()              # sets search_cancelled = true
searcher.clear_for_new_position()  # clears TT and killer moves between games

# Diagnostics
searcher.search_diagnostics        # SearchDiagnostics inner class
searcher.best_move_so_far          # best move from last completed iteration
searcher.best_eval_so_far          # eval in centipawns (positive = good for side to move)
searcher.current_depth             # last fully-completed depth
```

### `SearcherBot` (recommended bot)

Wraps `Searcher` with a fixed iterative-deepening depth (default 4).
Use this as the reference bot implementation.

```gdscript
var bot := SearcherBot.new()
bot.set_board(board)
var move: Move = bot.get_move()   # blocks until search is complete
```

---

## Bot interface

All bots extend `ChessBot`:

```gdscript
class_name MyBot
extends ChessBot

func get_move() -> Move:
    # inspect self.board, return a legal Move
    ...

func on_opponent_move(move: Move) -> void:
    pass   # optional hook
```

Register with the match:

```gdscript
var bot := MyBot.new()
bot.set_board(chess_board.board)
```

---

## Game result / Arbiter

```gdscript
var result: Arbiter.GameResult = Arbiter.get_game_state(board)

Arbiter.GameResult enum values:
  IN_PROGRESS, NOT_STARTED,
  WHITE_IS_MATED, BLACK_IS_MATED,
  STALEMATE, REPETITION, FIFTY_MOVE_RULE,
  INSUFFICIENT_MATERIAL, DRAW_BY_ARBITER,
  WHITE_TIMEOUT, BLACK_TIMEOUT,
  WHITE_ILLEGAL_MOVE, BLACK_ILLEGAL_MOVE

Arbiter.is_draw_result(result)   -> bool
Arbiter.is_win_result(result)    -> bool
Arbiter.is_white_wins_result(result) -> bool
Arbiter.is_black_wins_result(result) -> bool
```

---

## FEN utilities

```gdscript
FenUtility.START_POSITION_FEN           # standard starting FEN string
FenUtility.position_from_fen(fen) -> FenUtility.PositionInfo
FenUtility.current_fen(board) -> String
```

---

## Board square indexing

Squares are integers 0-63: `index = rank * 8 + file` (rank 0 = rank 1,
file 0 = a-file).

```
a1=0  b1=1  …  h1=7
a2=8  b2=9  …  h2=15
…
a8=56 b8=57 …  h8=63
```

Named constants live on `BoardHelper`:

```gdscript
BoardHelper.A1, BoardHelper.H1, BoardHelper.A8, BoardHelper.H8
BoardHelper.G1, BoardHelper.G8   # king castled-to squares
BoardHelper.rank_index(sq) -> int
BoardHelper.file_index(sq) -> int
BoardHelper.index_from_values(file, rank) -> int
BoardHelper.light_square(sq) -> bool
```

---

## Testing

```gdscript
# Perft (node count) from standard start:
ChessTest.run_tests()

# Known perft values:
# depth 1 → 20
# depth 2 → 400
# depth 3 → 8902
# depth 4 → 197281
# depth 5 → 4865609
```

A Python helper script `compare_perft.py` in the project root can
cross-check perft counts against a reference engine.

---

## Evaluation notes

`Evaluation.evaluate(board)` returns a score in centipawns from the
perspective of the **side to move** (positive = good for mover).

It combines:
- Material balance
- Piece-square table bonuses (separate middlegame / endgame tables,
  interpolated by a `total_piece_count_without_pawns_and_kings` phase
  factor stored on the board)
- Mop-up evaluation in the endgame (king proximity bonus when up material)
