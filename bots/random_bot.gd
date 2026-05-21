class_name RandomBot
extends ChessBot

func _init(bot_name: String = "RandomBot") -> void:
	name = bot_name

func get_move() -> Move:
	var gen = MoveGenerator.new()
	var moves = gen.generate_moves(board)
	if moves.is_empty():
		return Move.NULL_MOVE
	return moves[randi() % moves.size()]
