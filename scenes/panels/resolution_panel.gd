extends Control

signal next_requested

@onready var resolution_title: Label = $StoryBox/ResolutionTitle
@onready var resolution_text: RichTextLabel = $StoryBox/ResolutionText
@onready var next_button: Button = $StoryBox/NextButton

var _blackboard: Blackboard


func initialize(blackboard: Blackboard) -> void:
	_blackboard = blackboard
	next_button.pressed.connect(_on_next_pressed)


func populate(title: String, readings: Array[String]) -> void:
	resolution_title.text = title

	var lines: Array[String] = []
	for i: int in range(readings.size()):
		if i < StoryRenderer.SLOT_COLORS.size():
			lines.append("[color=%s]%s[/color]" % [StoryRenderer.SLOT_COLORS[i], readings[i]])
		else:
			lines.append(readings[i])
	resolution_text.text = "\n\n".join(lines)
	visible = true


func _on_next_pressed() -> void:
	if _blackboard != null:
		_blackboard.set_value("next_pressed", true)
	next_requested.emit()
