extends Control

signal begin_requested

@onready var intro_portrait: TextureRect = $IntroBox/IntroPortrait
@onready var intro_name: Label = $IntroBox/IntroName
@onready var intro_context: RichTextLabel = $IntroBox/IntroContext
@onready var begin_button: Button = $IntroBox/BeginButton

var _blackboard: Blackboard


func initialize(blackboard: Blackboard) -> void:
	_blackboard = blackboard
	begin_button.pressed.connect(_on_begin_pressed)


func populate(client_name: String, context: String, portrait_texture: Texture2D) -> void:
	intro_name.text = client_name
	intro_context.text = "[center]%s[/center]" % context
	intro_portrait.texture = portrait_texture
	visible = true


func _on_begin_pressed() -> void:
	if _blackboard != null:
		_blackboard.set_value("begin_pressed", true)
	begin_requested.emit()
