class_name EvalBar
extends Control

@onready var white_rect: ColorRect = $WhiteRect
@onready var black_rect: ColorRect = $BlackRect

func update_eval(white_sum: int, black_sum: int) -> void:
	var total: int = white_sum + black_sum
	if total == 0:
		return
	var white_pct: float = float(white_sum) / float(total)
	var white_height: float = size.y * white_pct
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(white_rect, "size:y", white_height, 0.3)
	tween.tween_property(black_rect, "size:y", size.y - white_height, 0.3)
	tween.tween_property(black_rect, "position:y", white_height, 0.3)
