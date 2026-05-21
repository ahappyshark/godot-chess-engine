# CLAUDE.md

## Project

Godot 4 chess engine with a visual board and pluggable bots.

## Key reference

`chess_data/ENGINE.md` — full architecture, data types, and API reference.
Read that before touching engine code.

## Required autoloads (project.godot)

1. `Magic` → `chess_data/move_generation/magics/magic.gd`
2. `ChessEngine` → `chess_data/chess_engine.gd`

## Threading rule

The bot search runs on a background thread (`_ai_thread` in
`scenes/chess_match.gd`). **Never read or write the shared `Board` object
from the main thread while that thread is active.** In particular,
`scenes/chess_board.gd` guards all board access in `_handle_hover` with an
early return when `board.move_colour != player_color`.

## Tests

Run perft and regression tests via `test/chess_test.gd` (attach to a Node
or run headless). Expected perft counts are in `ENGINE.md`.
