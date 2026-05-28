class_name ChessBot

var name: String = "BaseBot"
var board: Board
var eval_weights: EvalWeights = EvalWeights.new()

func set_board(p_board: Board) -> void:
	board = p_board

# Override this. Return a Move.
func get_move() -> Move:
	push_error("get_move() not implemented in " + name)
	return Move.NULL_MOVE

# Optional — called when opponent moves, lets bots track state
func on_opponent_move(_move: Move) -> void:
	pass

