extends Node2D

const TILE_SIZE: int = 32
const COLOR_MOVE:   Color = Color(0.20, 0.80, 0.20, 0.50)  # green  — safe destination
const COLOR_THREAT: Color = Color(0.80, 0.15, 0.15, 0.45)  # red    — opponent threat
const COLOR_RISKY:  Color = Color(0.90, 0.55, 0.10, 0.55)  # orange — valid move that's also threatened

var _move_squares:   Array = []
var _threat_squares: Array = []


func show_moves(squares: Array) -> void:
	_move_squares = squares
	queue_redraw()


func show_threats(squares: Array) -> void:
	_threat_squares = squares
	queue_redraw()


func clear_moves() -> void:
	_move_squares = []
	queue_redraw()


func clear_threats() -> void:
	_threat_squares = []
	queue_redraw()


func clear() -> void:
	_move_squares = []
	_threat_squares = []
	queue_redraw()


func _draw() -> void:
	# Pre-build sets for O(1) lookup.
	var move_set: Dictionary = {}
	for sq in _move_squares:
		move_set[sq] = true
	var threat_set: Dictionary = {}
	for sq in _threat_squares:
		threat_set[sq] = true

	# Red for pure threats (not a valid destination).
	for sq in _threat_squares:
		if not move_set.has(sq):
			draw_rect(_sq_rect(sq), COLOR_THREAT)

	# Green or orange for valid moves.
	for sq in _move_squares:
		var color := COLOR_RISKY if threat_set.has(sq) else COLOR_MOVE
		draw_rect(_sq_rect(sq), color)


func _sq_rect(sq: int) -> Rect2:
	var file := sq % 8
	var rank := sq / 8
	return Rect2(file * TILE_SIZE, (7 - rank) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
