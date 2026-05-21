# game_events.gd
# registered as GameEvents Autoload
extends Node

# --- Chess Clock ---
signal player_lost_on_time
signal goblin_lost_on_time
signal player_low_time(pressure: int)   # ChessGameState.ClockPressure
signal goblin_low_time(pressure: int)   # ChessGameState.ClockPressure

# --- Move Events ---
signal move_made(move: Move)
signal on_search_complete(move: Move)
#signal player_move_completed(move: ChessMove, state: ChessGameState)
#signal goblin_move_completed(move: ChessMove, state: ChessGameState)
signal move_was_blunder(color: int, eval_loss: float)   # ChessPiece.PlayerColor
signal move_was_brillian(color: int)                    # ChessPiece.PlayerColor

# --- Game State ---
signal check_issued(color: int)         # ChessPiece.PlayerColor
signal checkmate(winner: int)           # ChessPiece.PlayerColor
signal stalemate
#signal game_started(state: ChessGameState)
signal game_over(result: Arbiter.GameResult)

# --- Opening Events ---
signal opening_identified(opening: Dictionary)
signal player_deviated_from_book
signal transposition_reached(opening: Dictionary)
signal player_off_book_first_move

# --- Narrative Hooks ---
signal piece_hanging(color: int, cell: Vector2i)    # ChessPiece.PlayerColor
signal material_swing(delta: float)
signal endgame_entered
