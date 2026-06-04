# Project Integration Guide

How the chess engine (`chess_data/`) connects to the rest of the Godot project.
For engine internals (data types, APIs, search, evaluation) see `chess_data/ENGINE.md`.

---

## Full project layout

```
chess_data/       # Self-contained chess engine — see chess_data/ENGINE.md
  chess_engine.gd
  …

bots/
  chess_bot.gd        # Abstract base — extend to make a new bot
  searcher_bot.gd     # SearcherBot: iterative deepening to fixed depth (default 4)
  minimax_bot.gd      # MinimaxBot: plain negamax, depth 2, no TT/ordering
  random_bot.gd       # RandomBot: picks a random legal move
  greedy_bot.gd       # GreedyBot: SearcherBot with material weight 2.5×, depth 3
  tactical_bot.gd     # TacticalBot: SearcherBot with tactics weight 3.0×, depth 3

scenes/
  chess_board.gd      # Visual board + player input (Node2D)
  chess_match.gd      # Game controller — manages match state and bot thread
  chess_piece.gd      # Single piece sprite
  board_highlights.gd # Square highlight overlay
  eval_bar.gd         # Evaluation bar display

test/
  chess_test.gd       # Perft tests, make/unmake round-trip, tournament runner
  headless_game.gd    # Runs a full game without UI (used by tournament)
  tournament.gd       # Round-robin tournament with Elo ratings

utilities/
  rng_service.gd      # Deterministic RNG autoload (used by Zobrist and bots)
  game_events.gd      # Signal bus autoload — single source of truth for all signals
```

---

## Autoload setup (project.godot)

Register these in order:

| Order | Name          | Script                                        |
|-------|---------------|-----------------------------------------------|
| 1     | `RngService`  | `utilities/rng_service.gd`                    |
| 2     | `GameEvents`  | `utilities/game_events.gd`                    |
| 3     | `Magic`       | `chess_data/move_generation/magics/magic.gd`  |
| 4     | `ChessEngine` | `chess_data/chess_engine.gd`                  |

`Magic` must come before `ChessEngine`. `RngService` must come before `Magic`
(Zobrist uses it for seeded randomness).

---

## Bot interface

All bots extend `ChessBot`:

```gdscript
class_name MyBot
extends ChessBot

func get_move() -> Move:
    # self.board is set before this is called
    # self.eval_weights (EvalWeights) can be customised in _init()
    ...

func on_opponent_move(move: Move) -> void:
    pass   # optional hook — called after each opponent move
```

`ChessBot` fields:

```gdscript
bot.name: String          # display name
bot.board: Board          # set via bot.set_board(board)
bot.eval_weights: EvalWeights  # defaults to all 1.0; override in _init() to tune behaviour
```

Register a bot with a match:

```gdscript
var bot := MyBot.new()
bot.set_board(chess_board.board)
# Then pass bot to the match controller or headless game
```

---

## Threading contract

The match controller (`scenes/chess_match.gd`) runs `bot.get_move()` on a
background thread:

```gdscript
func _trigger_bot() -> void:
    _ai_thread = Thread.new()
    _ai_thread.start(_think)

func _think() -> void:
    var move: Move = _bot.get_move()
    call_deferred("_on_bot_done", move)   # marshals result back to main thread
```

**Rules:**
- Never read or write the shared `Board` from the main thread while the bot
  thread is running. `chess_board.gd` guards all board access in `_handle_hover`
  with an early return when `board.move_colour != player_color`.
- If a bot or search needs its own board copy, use `Board.create_board_from_source`.
- `_ai_thread.wait_to_finish()` is called in `_on_bot_done` and again in
  `new_game()` to prevent thread leaks across game resets.

---

## Signals (GameEvents autoload)

All cross-scene communication goes through `GameEvents`. Key signals:

```gdscript
GameEvents.move_made(move: Move)        # emitted by chess_board after a player move
GameEvents.game_over(result: Arbiter.GameResult)  # emitted by chess_match
```

Connect in `new_game()` (after disconnecting stale connections) rather than in
`_ready()` to avoid duplicate handlers across game resets.

---

## Testing

**Perft tests** (move generation correctness):

```gdscript
# Attach chess_test.gd to a Node and call:
ChessTest.run_tests()
```

Expected counts from the standard starting position are in `chess_data/ENGINE.md`.

**Bot tournaments**:

```gdscript
var t := Tournament.new()
t.add_bot(SearcherBot.new())
t.add_bot(TacticalBot.new())
t.add_bot(GreedyBot.new())
# run_round_robin(n) plays each pair n times and prints Elo results
t.run_round_robin(10)
```

Run tournaments on a background thread (see `chess_test.gd` for the pattern).

A Python helper `compare_perft.py` in the project root can cross-check perft
counts against a reference engine.

---

## Performance notes

Bot search speed in GDScript is fundamentally limited by the interpreter:
GDScript runs roughly 10–50× slower than equivalent compiled code.

Expected timings at typical search depths:

| Bot | Depth | Approx. time/move |
|-----|-------|-------------------|
| MinimaxBot | 2 | < 100 ms |
| GreedyBot / TacticalBot | 3 | 0.5 – 3 s |
| SearcherBot | 4 | 1 – 10 s |

A 40-move game between two SearcherBots can take 2–10 minutes. This is normal
for an interpreted-language engine. The TT, move ordering, LMR, and killer
moves are all in place — the bottleneck is GDScript itself, not missing
algorithmic optimizations.

If you need faster games for testing, use depth-3 bots or run headless games
in a thread so the main thread stays responsive.
