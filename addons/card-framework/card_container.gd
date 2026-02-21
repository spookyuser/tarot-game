## Abstract base class for all card containers in the card framework.
##
## Manages a collection of cards, drop zone, undo history, and position layout.
## Subclasses (Hand, Pile) override virtual methods to implement their layout.
##
## CardManager must appear above all CardContainers in the scene tree so that
## scene root meta registration completes before containers call _ready().
class_name CardContainer
extends Control

static var next_id: int = 0

@export_group("drop_zone")
@export var enable_drop_zone := true
@export_subgroup("Sensor")
@export var sensor_size: Vector2
@export var sensor_position: Vector2
@export var sensor_texture: Texture
@export var sensor_visibility := false

var unique_id: int
var drop_zone_scene: PackedScene = preload("drop_zone.tscn")
var drop_zone: DropZone = null

var _held_cards: Array[Card] = []
var _holding_cards: Array[Card] = []

var cards_node: Control
var card_manager: CardManager
var debug_mode := false


func _init() -> void:
	unique_id = next_id
	next_id += 1


func _ready() -> void:
	if has_node("Cards"):
		cards_node = $Cards
	else:
		cards_node = Control.new()
		cards_node.name = "Cards"
		cards_node.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(cards_node)

	_find_and_register_card_manager()


func _exit_tree() -> void:
	if card_manager != null:
		card_manager._delete_card_container(unique_id)


func add_card(card: Card, index: int = -1) -> void:
	if index == -1:
		_assign_card_to_container(card)
	else:
		_insert_card_to_container(card, index)
	_move_object(card, cards_node, index)


func remove_card(card: Card) -> bool:
	var index: int = _held_cards.find(card)
	if index != -1:
		_held_cards.remove_at(index)
	else:
		return false
	update_card_ui()
	return true


func get_card_count() -> int:
	return _held_cards.size()


func has_card(card: Card) -> bool:
	return _held_cards.has(card)


func clear_cards() -> void:
	for card: Card in _held_cards:
		_remove_object(card)
	_held_cards.clear()
	update_card_ui()


func check_card_can_be_dropped(cards: Array[Card]) -> bool:
	if not enable_drop_zone:
		return false
	if drop_zone == null:
		return false
	if drop_zone.accept_types.has(CardManager.CARD_ACCEPT_TYPE) == false:
		return false
	if not drop_zone.check_mouse_is_in_drop_zone():
		return false
	return _card_can_be_added(cards)


func get_partition_index() -> int:
	var vertical_index: int = drop_zone.get_vertical_layers()
	if vertical_index != -1:
		return vertical_index
	var horizontal_index: int = drop_zone.get_horizontal_layers()
	if horizontal_index != -1:
		return horizontal_index
	return -1


func shuffle() -> void:
	_fisher_yates_shuffle(_held_cards)
	for i: int in range(_held_cards.size()):
		var card: Card = _held_cards[i]
		cards_node.move_child(card, i)
	update_card_ui()


func move_cards(cards: Array[Card], index: int = -1, with_history: bool = true) -> bool:
	if not _card_can_be_added(cards):
		return false
	if not cards.all(func(card: Card) -> bool: return _held_cards.has(card)) and with_history:
		card_manager._add_history(self, cards)
	_move_cards(cards, index)
	return true


func undo(cards: Array[Card], from_indices: Array[int] = []) -> void:
	if not from_indices.is_empty() and cards.size() != from_indices.size():
		push_error("Mismatched cards and indices arrays in undo operation!")
		_move_cards(cards)
		return

	if from_indices.is_empty():
		_move_cards(cards)
		return

	for i: int in range(from_indices.size()):
		if from_indices[i] < 0:
			push_error("Invalid index found during undo: %d" % from_indices[i])
			_move_cards(cards)
			return

	var sorted_indices: Array[int] = from_indices.duplicate()
	sorted_indices.sort()
	var is_consecutive: bool = true
	for i: int in range(1, sorted_indices.size()):
		if sorted_indices[i] != sorted_indices[i - 1] + 1:
			is_consecutive = false
			break

	if is_consecutive and sorted_indices.size() > 1:
		var lowest_index: int = sorted_indices[0]
		var card_index_pairs: Array = []
		for i: int in range(cards.size()):
			card_index_pairs.append({"card": cards[i], "index": from_indices[i]})
		card_index_pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.index < b.index)
		for i: int in range(card_index_pairs.size()):
			var target_index: int = min(lowest_index + i, _held_cards.size())
			_move_cards([card_index_pairs[i].card], target_index)
	else:
		var card_index_pairs: Array = []
		for i: int in range(cards.size()):
			card_index_pairs.append({"card": cards[i], "index": from_indices[i], "original_order": i})
		card_index_pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a.index == b.index:
				return a.original_order < b.original_order
			return a.index > b.index
		)
		for pair: Dictionary in card_index_pairs:
			var target_index: int = min(pair.index, _held_cards.size())
			_move_cards([pair.card], target_index)


func hold_card(card: Card) -> void:
	if _held_cards.has(card):
		_holding_cards.append(card)


func release_holding_cards() -> void:
	if _holding_cards.is_empty():
		return
	for card: Card in _holding_cards:
		card.change_state(DraggableObject.DraggableState.IDLE)
	var copied_holding_cards: Array[Card] = _holding_cards.duplicate()
	if card_manager != null:
		card_manager._on_drag_dropped(copied_holding_cards)
	_holding_cards.clear()


func get_string() -> String:
	return "card_container: %d" % unique_id


func on_card_move_done(_card: Card) -> void:
	pass


func on_card_pressed(_card: Card) -> void:
	pass


func _assign_card_to_container(card: Card) -> void:
	if card.card_container != self:
		card.card_container = self
	if not _held_cards.has(card):
		_held_cards.append(card)
	update_card_ui()


func _insert_card_to_container(card: Card, index: int) -> void:
	if card.card_container != self:
		card.card_container = self
	if not _held_cards.has(card):
		var clamped_index: int = clamp(index, 0, _held_cards.size())
		_held_cards.insert(clamped_index, card)
	update_card_ui()


func _move_to_card_container(card: Card, index: int = -1) -> void:
	if card.card_container != null:
		card.card_container.remove_card(card)
	add_card(card, index)


func _fisher_yates_shuffle(array: Array) -> void:
	for i: int in range(array.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var temp: Variant = array[i]
		array[i] = array[j]
		array[j] = temp


func _move_cards(cards: Array[Card], index: int = -1) -> void:
	var cur_index: int = index
	for i: int in range(cards.size() - 1, -1, -1):
		var card: Card = cards[i]
		if cur_index == -1:
			_move_to_card_container(card)
		else:
			_move_to_card_container(card, cur_index)
			cur_index += 1


func _card_can_be_added(_cards: Array[Card]) -> bool:
	return true


func update_card_ui() -> void:
	_update_target_z_index()
	_update_target_positions()


func _update_target_z_index() -> void:
	pass


func _update_target_positions() -> void:
	pass


func _move_object(target: Node, to: Node, index: int = -1) -> void:
	if target.get_parent() == to:
		if index != -1:
			to.move_child(target, index)
		else:
			to.move_child(target, to.get_child_count() - 1)
		return

	var global_pos: Vector2 = target.global_position
	if target.get_parent() != null:
		target.get_parent().remove_child(target)
	if index != -1:
		to.add_child(target)
		to.move_child(target, index)
	else:
		to.add_child(target)
	target.global_position = global_pos


func _find_and_register_card_manager() -> void:
	if card_manager != null:
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root and scene_root.has_meta("card_manager"):
		card_manager = scene_root.get_meta("card_manager")
		if debug_mode:
			print("CardContainer found CardManager via scene root meta: ", name)
	else:
		card_manager = _find_card_manager_in_parents()
		if card_manager and debug_mode:
			print("CardContainer found CardManager via parent traversal: ", name)

	if card_manager == null:
		push_error("CardContainer '%s' could not find CardManager.\n" % name +
			"SOLUTION: Ensure CardManager is positioned ABOVE CardContainers in scene tree:\n" +
			"✅ Correct:   Scene → CardManager → UI → CardContainer\n" +
			"❌ Incorrect: Scene → UI → CardContainer → CardManager")
		return

	card_manager._add_card_container(unique_id, self)
	_initialize_drop_zone()


func _find_card_manager_in_parents() -> CardManager:
	var parent: Node = get_parent()
	while parent != null:
		if parent is CardManager:
			return parent
		parent = parent.get_parent()
	return null


func _initialize_drop_zone() -> void:
	if not enable_drop_zone:
		return
	drop_zone = drop_zone_scene.instantiate()
	add_child(drop_zone)
	drop_zone.init(self, [CardManager.CARD_ACCEPT_TYPE])
	if sensor_size == Vector2(0, 0):
		sensor_size = card_manager.card_size
	drop_zone.set_sensor(sensor_size, sensor_position, sensor_texture, sensor_visibility)
	drop_zone.sensor_outline.visible = debug_mode


func _remove_object(target: Node) -> void:
	var parent: Node = target.get_parent()
	if parent != null:
		parent.remove_child(target)
	target.queue_free()
