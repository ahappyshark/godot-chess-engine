# Chess Engine — Developer Reference

A self-contained GDScript chess engine. This document covers the internals of
`chess_data/` only: architecture, data representations, and the public API
surfaces that external code connects through. For project-level integration
(autoloads, bot wiring, UI, tests) see `INTEGRATION.md` in the project root.

---

## chess_data/ layout

```
chess_data/
  chess_engine.gd               # Initialises all subsystems — must be an autoload
  book.txt                      # Opening book lines (do not read this file)
  core/
    board.gd                    # Central mutable game state
    piece.gd                    # Piece type/colour constants and helpers
    piece_list.gd               # Fast square-lookup list used by Board
    move.gd                     # Packed move value object
    game_state.gd               # Immutable snapshot pushed onto Board's history stack
    coord.gd                    # (file, rank) coordinate helper
    zobrist.gd                  # Zobrist hashing tables (static init)
  move_generation/
    move_generator.gd           # Pseudo-legal + legal move generator
    precomputed_move_data.gd    # Direction rays, alignment masks (static init)
    bitboards/
      bit_board_utility.gd      # Bitboard ops, attack tables (needs initialize() call)
      bits.gd                   # Named castle/rank/file masks (needs initialize() call)
    magics/
      magic.gd                  # Magic-bitboard slider attack lookup (autoload)
      magic_helper.gd           # Internal helper
      precomputed_magics.gd     # Precomputed magic numbers
  search/
    searcher.gd                 # Iterative-deepening alpha-beta + quiescence search
    move_ordering.gd            # MVV-LVA, killer moves, history heuristic
    transposition_table.gd      # Zobrist-keyed TT (64 MB default)
    repetition_table.gd         # Threefold-repetition tracker used during search
  evaluation/
    evaluation.gd               # Static evaluator (material + PST + tactics + endgame)
    eval_weights.gd             # Per-component weight multipliers
    piece_square_table.gd       # Piece-square tables (static init)
    precomputed_evaluation_data.gd  # Passed-pawn masks etc. (static init)
  game_result/
    arbiter.gd                  # Terminal-state detection (checkmate, draw rules)
  utilities/
    fen_utility.gd              # FEN parse / generate
    board_helper.gd             # Square index helpers, named square constants
    move_utility.gd             # Move → UCI / SAN string
    pgn_creator.gd              # PGN export
    generate_magics.gd          # One-shot script used to regenerate magic numbers
```

---

## Initialisation order

`chess_engine.gd` must be registered as a Godot autoload **after** `magic.gd`.
Its `_ready()` calls:

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
NO_FLAG                = 0
EN_PASSANT_CAPTURE_FLAG= 1
CASTLE_FLAG            = 2
PAWN_TWO_UP_FLAG       = 3
PROMOTE_TO_QUEEN_FLAG  = 4
PROMOTE_TO_KNIGHT_FLAG = 5
PROMOTE_TO_ROOK_FLAG   = 6
PROMOTE_TO_BISHOP_FLAG = 7
```

### `PositionData`

A snapshot of all derived position information for the side to move. Computed once
per position and cached on `Board` — use `board.get_position_data()` rather than
constructing directly.

```gdscript
data.all_legal_moves: Array              # all legal moves for the side to move
data.legal_moves_by_square: Dictionary  # square (int) -> Array[Move]
data.opponent_attack_map: int           # bitboard of squares attacked by the opponent
data.friendly_attack_map: int           # bitboard of squares attacked/defended by the mover
data.pin_rays: int                      # bitboard of active pin rays
data.in_check: bool
data.in_double_check: bool
data.hanging_pieces_friendly: int       # mover's pieces that are attacked and undefended (kings excluded)
data.hanging_pieces_enemy: int          # opponent's pieces that are attacked and undefended (kings excluded)
data.material_balance: int              # positive = white ahead, in centipawns (always white-relative)
data.game_phase: int                    # PositionData.MIDDLEGAME or ENDGAME
```

Phase constants: `PositionData.OPENING = 0`, `PositionData.MIDDLEGAME = 1`, `PositionData.ENDGAME = 2`.
Endgame threshold: `total_piece_count_without_pawns_and_kings <= 6`.

---

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

# Cached position data (lazy, invalidated by make_move / unmake_move):
board.get_position_data() -> PositionData
```

**Important invariant**: every `make_move(m, true)` in a search branch
**must** be paired with exactly one `unmake_move(m, true)` before the
function returns. Do not share a `Board` object between threads while
either thread is calling `make_move`/`unmake_move` — use
`Board.create_board_from_source` to give each thread a private copy.

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
gen.in_double_check() -> bool     # valid after the last generate_moves call
gen.opponent_attack_map: int      # bitboard of squares attacked by the opponent
gen.opponent_pawn_attack_map: int

# Raw attack map for one side (no legality filtering — used by PositionData.compute):
MoveGenerator.compute_attack_map_for_color(board: Board, for_white: bool) -> int
```

`promotions_to_generate` controls which under-promotions are emitted:

```gdscript
gen.promotions_to_generate = MoveGenerator.PromotionMode.ALL
gen.promotions_to_generate = MoveGenerator.PromotionMode.QUEEN_ONLY
gen.promotions_to_generate = MoveGenerator.PromotionMode.QUEEN_AND_KNIGHT  # default in Searcher
```

---

## Search

Alpha-beta with iterative deepening, quiescence search, transposition table,
late-move reduction, move ordering (MVV-LVA + killers + history heuristic),
and check/pawn-push extensions.

```gdscript
var searcher := Searcher.new(board, eval_weights)  # eval_weights set bot personality

# Run iterative-deepening search to a fixed depth:
for depth in range(1, max_depth + 1):
    searcher.best_move_this_iteration = Move.NULL_MOVE
    searcher.search(depth, 0, Searcher.NEGATIVE_INFINITY, Searcher.POSITIVE_INFINITY)
    if not searcher.best_move_this_iteration.is_null:
        best_move = searcher.best_move_this_iteration

searcher.end_search()              # sets search_cancelled = true
searcher.clear_for_new_position()  # clears TT and killer moves between games

# Diagnostics
searcher.search_diagnostics        # SearchDiagnostics inner class instance
searcher.best_move_so_far          # best move from last completed iteration
searcher.best_eval_so_far          # eval in centipawns (positive = good for side to move)
searcher.current_depth             # last fully-completed depth
```

`SearchDiagnostics` fields:

```gdscript
diagnostics.num_completed_iterations: int
diagnostics.num_positions_evaluated: int
diagnostics.num_cut_offs: int
diagnostics.move_val: String
diagnostics.eval: int
diagnostics.num_q_checks: int
diagnostics.num_q_mates: int
```

Mate score helpers:

```gdscript
Searcher.is_mate_score(score: int) -> bool
Searcher.num_ply_to_mate_from_score(score: int) -> int
Searcher.IMMEDIATE_MATE_SCORE  # 100000
```

---

## Evaluation

Evaluation is a two-phase process: compute raw components once (no weights),
then apply personality weights separately. This means the same component data
can be read by multiple consumers with different weightings without re-running
the expensive computation.

```gdscript
var evaluation := Evaluation.new()

# Phase 1 — objective: compute all component scores for the current position.
# Results stored in evaluation.white_eval and evaluation.black_eval.
evaluation.compute(board)

# Phase 2a — personality: score from side-to-move's perspective (positive = good for mover).
var weights := EvalWeights.new()   # set fields for bot personality
var score: int = evaluation.weighted_score(weights)

# Phase 2b — objective display: score always from white's perspective (positive = white ahead).
var white_pov: int = evaluation.white_relative_score(EvalWeights.new())
```

### `EvalWeights`

Multipliers applied to each evaluation component. Default all 1.0.

```gdscript
weights.material: float       # raw piece values
weights.piece_square: float   # piece-square table bonuses
weights.pawn_structure: float # passed-pawn bonus + isolated-pawn penalty
weights.pawn_shield: float    # king safety score
weights.mop_up: float         # king activity bonus in winning endgames
weights.tactics: float        # fork / pin / skewer bonuses
weights.patterns: float       # reserved for future pattern-based bonuses
```

Setting a weight to 0.0 disables that component entirely; values above 1.0
amplify it. Bots use this to express playing styles (e.g. `tactics = 3.0` for
an aggressive tactical bot).

### Evaluation components

| Component | Description |
|---|---|
| **Material** | Sum of piece values: P=100, N=300, B=320, R=500, Q=900 |
| **Piece-square tables** | Position bonuses per piece; opening/endgame tables blended by phase |
| **Pawn structure** | Passed-pawn bonus (scales with rank); isolated-pawn penalty |
| **King pawn shield** | Penalty for missing pawns in front of a castled king; scales down as queens leave |
| **Mop-up** | King activity and centralisation bonus when winning in an endgame |
| **Tactics** | Fork + pin + skewer detection bonuses (see below) |

### Tactical evaluation

`evaluate_tactics(color_index)` runs three detectors and accumulates their scores:

**Forks** — knight attacks two or more enemy pieces simultaneously. Bonus
= value of the lesser-valued piece being forked (the opponent saves the bigger
one). Scales with quality of the forked targets; king forks are included.

**Pins** — ray traced from the enemy king outward; a friendly slider (bishop/rook/queen)
is behind an enemy piece along the same ray. Bonus by pinned piece type:
Q=80, R=60, B/N=40, P=15 centipawns.

**Skewers** — ray traced from each friendly slider; an enemy high-value piece
(queen/rook/king) is the first hit and a second enemy piece hides behind it.
Bonus is the value of the exposed (second) piece, same table as pin values.

Detected tactic names ("fork", "pin", "skewer") are appended to
`EvaluationData.detected_tactics` for debugging.

### Endgame phase

Phase is determined by `total_piece_count_without_pawns_and_kings`.
Threshold ≤ 6 pieces → endgame (`end_game_t = 1.0`). Between 0 and the
threshold the blend factor interpolates linearly. Mop-up evaluation and
king-safety scaling both use this factor.

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

Arbiter.is_draw_result(result)       -> bool
Arbiter.is_win_result(result)        -> bool
Arbiter.is_white_wins_result(result) -> bool
Arbiter.is_black_wins_result(result) -> bool
```

---

## FEN utilities

```gdscript
FenUtility.START_POSITION_FEN            # standard starting FEN string
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

## Perft reference values

Used to verify move generation correctness from the standard starting position:

```
depth 1 →       20
depth 2 →      400
depth 3 →    8,902
depth 4 →  197,281
depth 5 → 4,865,609
```

---

## Integration seam summary

External code (bots, UI, tests) connects to the engine through these entry points:

| What | How |
|---|---|
| Start a position | `Board.create_board()` or `Board.create_board(fen)` |
| Generate moves | `MoveGenerator.new().generate_moves(board)` |
| Apply / undo a move | `board.make_move(move)` / `board.unmake_move(move)` |
| Run a search | `Searcher.new(board)`, then call `search(depth, ...)` |
| Evaluate a position | `Evaluation.new().evaluate(board, EvalWeights.new())` |
| Check game end | `Arbiter.get_game_state(board)` |
| Threading contract | Search owns the board — never read/write the board from another thread while search is running. Use `Board.create_board_from_source` for a safe copy. |

See `INTEGRATION.md` for the full project wiring (autoloads, bot base class, match controller).
