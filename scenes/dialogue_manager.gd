extends CanvasLayer

const DIALOGUE_UI_SCENE = preload("res://scenes/dialogue_ui.tscn")

var _ui: Control = null
var _blocks: Dictionary = {}
var _current_block: Array = []
var _current_line: int = 0

func run(path: String) -> void:
	var json = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(json.get_as_text())
	_blocks = data["blocks"]
	_load_block(data["start"])
	_ui = DIALOGUE_UI_SCENE.instantiate()
	add_child(_ui)
	GameEvents.advance_requested.connect(_on_advance_requested)
	GameEvents.dialogue_started.emit()
	_show_current_line()

func _load_block(block_id: String) -> void:
	_current_block = _blocks[block_id]["lines"]
	_current_line = 0

func _show_current_line() -> void:
	var line = _current_block[_current_line]
	_ui.show_line(line)
	
func _on_advance_requested() -> void:
	_current_line += 1
	if _current_line >= _current_block.size():
		_close()
		return
	_show_current_line()

func _close() -> void:
	_ui.queue_free()
	_ui = null
	GameEvents.dialogue_finished.emit()
