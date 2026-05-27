extends Control

@onready var speaker_name: Label = $SpeechBubble/MarginContainer/VBoxContainer/SpeakerName
@onready var dialogue_text: RichTextLabel = $SpeechBubble/MarginContainer/VBoxContainer/DialogueText
@onready var advance_indicator: Control = $SpeechBubble/AdvanceIndicator
@onready var speaker_portrait: TextureRect = $SpeakerPortrait

func show_line(line: Dictionary) -> void:
	speaker_name.text = line.get("speaker", "")
	dialogue_text.text = line.get("text", "")
	speaker_portrait.texture = _resolve_portrait(line.get("portrait", ""))
	advance_indicator.visible = true

func _resolve_portrait(key: String) -> Texture2D:
	if key.is_empty():
		return null
	return load("res://assets/portraits/" + key + ".png")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		GameEvents.advance_requested.emit()
		get_viewport().set_input_as_handled()
