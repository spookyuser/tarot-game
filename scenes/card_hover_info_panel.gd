class_name CardHoverInfoPanel
extends NinePatchRect

@onready var body: RichTextLabel = $CardHoverInfoBody
@onready var reversed_label: Label = $ReversedLabel

const PANEL_MARGIN := 8.0
const X_OFFSET := 10.0
const Y_OFFSET := 0.0
const TEXT_COLOR := "#e8dcc4"

var _showing: bool = false
var _tween: Tween = null
var _last_hovered_card_pos: Vector2 = Vector2.ZERO


func update_display(player_hand: Hand) -> void:
	var hovered_card: Card = _find_hovered_hand_card(player_hand)

	if hovered_card != null:
		body.text = _build_body_text(hovered_card.card_info)
		reversed_label.visible = hovered_card.is_reversed
		_last_hovered_card_pos = hovered_card.global_position

		if not _showing:
			_showing = true
			_slide_in(hovered_card)
		elif _tween == null or not _tween.is_running():
			_position_panel(hovered_card)
	else:
		if _showing:
			_showing = false
			_slide_out()


func hide_immediately() -> void:
	if _showing:
		_showing = false
		if _tween != null and _tween.is_running():
			_tween.kill()
	visible = false
	modulate = Color(1, 1, 1, 1)


func _find_hovered_hand_card(player_hand: Hand) -> Card:
	for card: Card in player_hand._held_cards:
		if card.current_state == DraggableObject.DraggableState.HOVERING:
			return card
	return null


func _position_panel(card: Card) -> void:
	var card_rect: Rect2 = card.get_global_rect()
	var panel_size: Vector2 = size
	var viewport_size: Vector2 = get_viewport_rect().size

	var target_x: float = card_rect.position.x - panel_size.x - X_OFFSET
	if target_x < PANEL_MARGIN:
		target_x = card_rect.position.x + card_rect.size.x + X_OFFSET

	var target_y: float = card_rect.position.y + Y_OFFSET

	target_x = clampf(target_x, PANEL_MARGIN, viewport_size.x - panel_size.x - PANEL_MARGIN)
	target_y = clampf(target_y, PANEL_MARGIN, viewport_size.y - panel_size.y - PANEL_MARGIN)

	global_position = Vector2(target_x, target_y)


func _slide_in(card: Card) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()

	visible = true
	_position_panel(card)
	var final_pos: Vector2 = global_position

	var card_rect: Rect2 = card.get_global_rect()
	global_position = Vector2(card_rect.position.x, final_pos.y)
	modulate = Color(1, 1, 1, 0)

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)
	_tween.tween_property(self, "global_position", final_pos, 0.15)
	_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.15)


func _slide_out() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()

	var current_pos: Vector2 = global_position
	var target_pos: Vector2 = Vector2(_last_hovered_card_pos.x, current_pos.y)

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)
	_tween.tween_property(self, "global_position", target_pos, 0.1)
	_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.1)
	_tween.set_parallel(false)
	_tween.tween_callback(func() -> void: visible = false)


func _build_body_text(card_info: Dictionary) -> String:
	var description: String = String(card_info.get("description", "")).strip_edges()
	if description.is_empty():
		description = "No omen appears."
	return "[color=%s][i]%s[/i][/color]" % [TEXT_COLOR, description]
