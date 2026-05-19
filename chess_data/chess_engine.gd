extends Node
## ChessEngine — global autoload that initializes all chess subsystems in
## dependency order. Add this to project.godot autoloads as "ChessEngine"
## AFTER the "Magic" autoload.

func _ready() -> void:
	# 1. BitBoardUtility has no deps — king_moves/knight_attacks/pawn_attacks
	BitBoardUtility.initialize()
	# 2. Bits needs BitBoardUtility.king_moves for king_safety_mask
	Bits.initialize()
	# PrecomputedMoveData, Zobrist, PieceSquareTable, PrecomputedEvaluationData
	# all use _static_init() which fires automatically on first class reference.
