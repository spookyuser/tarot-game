@tool
## Central orchestrator for the card framework system.
##
## Coordinates card factories, container registration, drag-drop routing,
## and history tracking. Must appear above all CardContainers in the scene tree.
class_name CardManager
extends Control

const CARD_ACCEPT_TYPE = "card"

@export var card_size := CardFrameworkSettings.LAYOUT_DEFAULT_CARD_SIZE
@export var card_factory_scene: PackedScene
@export var debug_mode := false

var card_factory: CardFactory
var card_container_dict: Dictionary = {}
var history: Array[HistoryElement] = []


func _init() -> void:
	if Engine.is_editor_hint():
		return


func _ready() -> void:
	if not _pre_process_exported_variables():
		return
	if Engine.is_editor_hint():
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root:
		scene_root.set_meta("card_manager", self)
		if debug_mode:
			print("CardManager registered to scene root: ", scene_root.name)

	card_factory.card_size = card_size
	card_factory.preload_card_data()


func _exit_tree() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root and scene_root.has_meta("card_manager"):
		scene_root.remove_meta("card_manager")
		if debug_mode:
			print("CardManager unregistered from scene root")


func undo() -> void:
	if history.is_empty():
		return
	var last: HistoryElement = history.pop_back()
	if last.from != null:
		last.from.undo(last.cards, last.from_indices)


func reset_history() -> void:
	history.clear()


func _add_card_container(id: int, card_container: CardContainer) -> void:
	card_container_dict[id] = card_container
	card_container.debug_mode = debug_mode


func _delete_card_container(id: int) -> void:
	card_container_dict.erase(id)


func _on_drag_dropped(cards: Array[Card]) -> void:
	if cards.is_empty():
		return

	var original_mouse_filters: Dictionary = {}
	for card: Card in cards:
		original_mouse_filters[card] = card.mouse_filter
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for key: Variant in card_container_dict.keys():
		var card_container: CardContainer = card_container_dict[key]
		if card_container.check_card_can_be_dropped(cards):
			var index: int = card_container.get_partition_index()
			for card: Card in cards:
				card.mouse_filter = original_mouse_filters[card]
			card_container.move_cards(cards, index)
			return

	for card: Card in cards:
		card.mouse_filter = original_mouse_filters[card]
		card.return_card()


func _add_history(to: CardContainer, cards: Array[Card]) -> void:
	var from: CardContainer = null
	var from_indices: Array[int] = []

	for i: int in range(cards.size()):
		var c: Card = cards[i]
		var current: CardContainer = c.card_container
		if i == 0:
			from = current
		elif from != current:
			push_error("All cards must be from the same container!")
			return

		if from != null:
			var original_index: int = from._held_cards.find(c)
			if original_index == -1:
				push_error("Card not found in source container during history recording!")
				return
			from_indices.append(original_index)

	var history_element := HistoryElement.new()
	history_element.from = from
	history_element.to = to
	history_element.cards = cards
	history_element.from_indices = from_indices
	history.append(history_element)


func _pre_process_exported_variables() -> bool:
	if card_factory_scene == null:
		push_error("CardFactory is not assigned! Please set it in the CardManager Inspector.")
		return false

	var factory_instance: CardFactory = card_factory_scene.instantiate() as CardFactory
	if factory_instance == null:
		push_error("Failed to create an instance of CardFactory! CardManager imported an incorrect card factory scene.")
		return false

	add_child(factory_instance)
	card_factory = factory_instance
	return true
