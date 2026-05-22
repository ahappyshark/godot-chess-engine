class_name EvalBar
extends Control

const MAX_CP: int = 1000

@onready var white_rect: ColorRect = $WhiteRect
@onready var black_rect: ColorRect = $BlackRect

func update_eval(score: int) -> void:
	var clamped: float = clamp(score, -MAX_CP, MAX_CP)
	var white_pct: float = (clamped + MAX_CP) / float(MAX_CP * 2)
	var white_height: float = size.y * white_pct
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(white_rect, "size:y", white_height, 0.3)
	tween.tween_property(black_rect, "size:y", size.y - white_height, 0.3)
	tween.tween_property(black_rect, "position:y", white_height, 0.3)
