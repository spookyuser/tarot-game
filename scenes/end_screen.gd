class_name EndScreen
extends Control

signal play_again_requested

@onready var title: Label = $EndBox/EndTitle
@onready var list: VBoxContainer = $EndBox/EndScroll/EndList
@onready var play_again_button: Button = $EndBox/PlayAgainButton


func _ready() -> void:
	visible = false
	play_again_button.pressed.connect(func() -> void: play_again_requested.emit())


func show_summary(encounters: Array, portrait_getter: Callable, back_texture: Texture2D) -> void:
	for child: Node in list.get_children():
		child.queue_free()

	title.text = "The Reading Concludes"

	for encounter: Dictionary in encounters:
		var client_name: String = encounter.get("client", {}).get("name", "Unknown")
		var slots: Array = encounter.get("slots", [])

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		row.alignment = BoxContainer.ALIGNMENT_CENTER

		var portrait_rect := TextureRect.new()
		var p_tex: Texture2D = portrait_getter.call(client_name)
		if p_tex:
			portrait_rect.texture = p_tex
		portrait_rect.custom_minimum_size = Vector2(48, 48)
		portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		row.add_child(portrait_rect)

		var name_label := Label.new()
		name_label.text = client_name
		name_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4, 1.0))
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.custom_minimum_size = Vector2(160, 0)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(name_label)

		var cards_box := HBoxContainer.new()
		cards_box.add_theme_constant_override("separation", 8)
		cards_box.alignment = BoxContainer.ALIGNMENT_CENTER

		for slot: Dictionary in slots:
			var c_name: String = slot.get("card", "")
			var orient: String = slot.get("orientation", "upright")

			var c_rect := TextureRect.new()
			c_rect.custom_minimum_size = Vector2(36, 52)
			c_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL

			if c_name.is_empty():
				c_rect.texture = back_texture
			else:
				var tex_path: String = "res://assets/cards/%s.png" % c_name
				c_rect.texture = load(tex_path) if ResourceLoader.exists(tex_path) else back_texture

			c_rect.flip_v = (orient == "reversed")
			cards_box.add_child(c_rect)

		row.add_child(cards_box)
		list.add_child(row)

	visible = true
