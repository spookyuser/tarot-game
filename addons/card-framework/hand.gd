## A fan-shaped card container that arranges cards in an arc formation.
##
## Uses Curve resources for rotation and vertical displacement to create natural
## card arrangements. Supports reordering via swap or shift modes.
class_name Hand
extends CardContainer

@export_group("hand_meta_info")
@export var max_hand_size := CardFrameworkSettings.LAYOUT_MAX_HAND_SIZE
@export var max_hand_spread := CardFrameworkSettings.LAYOUT_MAX_HAND_SPREAD
@export var card_face_up := true
@export var card_hover_distance := CardFrameworkSettings.PHYSICS_CARD_HOVER_DISTANCE

@export_group("hand_shape")
@export var hand_rotation_curve: Curve
@export var hand_vertical_curve: Curve

@export_group("drop_zone")
@export var align_drop_zone_size_with_current_hand_size := true
@export var swap_only_on_reorder := false

var vertical_partitions_from_outside: Array[float] = []
var vertical_partitions_from_inside: Array[float] = []


func _ready() -> void:
	super._ready()


func get_random_cards(n: int) -> Array[Card]:
	var pool: Array[Card] = _held_cards.duplicate()
	pool.shuffle()
	var count: int = min(n, pool.size())
	return pool.slice(0, count)


func _card_can_be_added(cards: Array[Card]) -> bool:
	var all_contained: bool = cards.all(func(card: Card) -> bool: return _held_cards.has(card))
	if all_contained:
		return true
	return _held_cards.size() + cards.size() <= max_hand_size


func _update_target_z_index() -> void:
	for i: int in range(_held_cards.size()):
		_held_cards[i].stored_z_index = i


func _update_target_positions() -> void:
	var card_size: Vector2 = card_manager.card_size
	var _w: float = card_size.x
	var _h: float = card_size.y

	var x_min: float = 0.0
	var x_max: float = 0.0
	var y_min: float = 0.0
	var y_max: float = 0.0

	vertical_partitions_from_outside.clear()

	for i: int in range(_held_cards.size()):
		var card: Card = _held_cards[i]

		var hand_ratio: float = 0.5
		if _held_cards.size() > 1:
			hand_ratio = float(i) / float(_held_cards.size() - 1)

		var target_pos: Vector2 = global_position
		@warning_ignore("integer_division")
		var card_spacing: float = max_hand_spread / (_held_cards.size() + 1)
		target_pos.x += (i + 1) * card_spacing - max_hand_spread / 2.0

		if hand_vertical_curve:
			target_pos.y -= hand_vertical_curve.sample(hand_ratio)

		var target_rotation: float = 0.0
		if hand_rotation_curve:
			target_rotation = deg_to_rad(hand_rotation_curve.sample(hand_ratio))

		var _x: float = target_pos.x
		var _y: float = target_pos.y
		var _t1: float = atan2(_h, _w) + target_rotation
		var _t2: float = atan2(_h, -_w) + target_rotation
		var _t3: float = _t1 + PI + target_rotation
		var _t4: float = _t2 + PI + target_rotation
		var _c: Vector2 = Vector2(_x + _w / 2.0, _y + _h / 2.0)
		var _r: float = sqrt(pow(_w / 2.0, 2.0) + pow(_h / 2.0, 2.0))

		var _p1: Vector2 = Vector2(_r * cos(_t1), _r * sin(_t1)) + _c
		var _p2: Vector2 = Vector2(_r * cos(_t2), _r * sin(_t2)) + _c
		var _p3: Vector2 = Vector2(_r * cos(_t3), _r * sin(_t3)) + _c
		var _p4: Vector2 = Vector2(_r * cos(_t4), _r * sin(_t4)) + _c

		var current_x_min: float = min(_p1.x, _p2.x, _p3.x, _p4.x)
		var current_x_max: float = max(_p1.x, _p2.x, _p3.x, _p4.x)
		var current_y_min: float = min(_p1.y, _p2.y, _p3.y, _p4.y)
		var current_y_max: float = max(_p1.y, _p2.y, _p3.y, _p4.y)
		var current_x_mid: float = (current_x_min + current_x_max) / 2.0
		vertical_partitions_from_outside.append(current_x_mid)

		if i == 0:
			x_min = current_x_min
			x_max = current_x_max
			y_min = current_y_min
			y_max = current_y_max
		else:
			x_min = minf(x_min, current_x_min)
			x_max = maxf(x_max, current_x_max)
			y_min = minf(y_min, current_y_min)
			y_max = maxf(y_max, current_y_max)

		card.move(target_pos, target_rotation)
		card.show_front = card_face_up
		card.can_be_interacted_with = true

	vertical_partitions_from_inside.clear()
	if vertical_partitions_from_outside.size() > 1:
		for j: int in range(vertical_partitions_from_outside.size() - 1):
			var mid: float = (vertical_partitions_from_outside[j] + vertical_partitions_from_outside[j + 1]) / 2.0
			vertical_partitions_from_inside.append(mid)

	if align_drop_zone_size_with_current_hand_size:
		if _held_cards.size() == 0:
			drop_zone.return_sensor_size()
		else:
			var sensor_sz: Vector2 = Vector2(x_max - x_min, y_max - y_min)
			var sensor_pos: Vector2 = Vector2(x_min, y_min) - position
			drop_zone.set_sensor_size_flexibly(sensor_sz, sensor_pos)
		drop_zone.set_vertical_partitions(vertical_partitions_from_outside)


func move_cards(cards: Array[Card], index: int = -1, with_history: bool = true) -> bool:
	if cards.size() == 1 and _held_cards.has(cards[0]) and index >= 0 and index < _held_cards.size():
		var current_index: int = _held_cards.find(cards[0])

		if swap_only_on_reorder:
			swap_card(cards[0], index)
			return true

		if current_index == index:
			update_card_ui()
			_restore_mouse_interaction(cards)
			return true

		_reorder_card_in_hand(cards[0], current_index, index, with_history)
		_restore_mouse_interaction(cards)
		return true

	return super.move_cards(cards, index, with_history)


func swap_card(card: Card, index: int) -> void:
	var current_index: int = _held_cards.find(card)
	if current_index == index:
		return
	var temp: Card = _held_cards[current_index]
	_held_cards[current_index] = _held_cards[index]
	_held_cards[index] = temp
	update_card_ui()


func _restore_mouse_interaction(cards: Array[Card]) -> void:
	for card: Card in cards:
		card.mouse_filter = Control.MOUSE_FILTER_STOP


func _reorder_card_in_hand(card: Card, from_index: int, to_index: int, with_history: bool) -> void:
	if with_history:
		card_manager._add_history(self, [card])
	_held_cards.remove_at(from_index)
	_held_cards.insert(to_index, card)
	update_card_ui()


func hold_card(card: Card) -> void:
	if _held_cards.has(card):
		drop_zone.set_vertical_partitions(vertical_partitions_from_inside)
	super.hold_card(card)
