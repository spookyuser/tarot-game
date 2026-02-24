extends Control

@onready var card_manager: CardManager = $SceneRoot/Gameplay/CardManager
@onready var player_hand: Hand = $SceneRoot/Gameplay/ReadingArea/PlayerHand
@onready var resolution_panel: Control = $SceneRoot/OverlayLayer/ResolutionPanel
@onready var claude_api: Node = $Systems/ClaudeAPI
@onready var sound_manager: Node = $Systems/SoundManager
@onready var game_blackboard: Blackboard = $Systems/GameBlackboard

@onready var card_hover_panel: CardHoverInfoPanel = $SceneRoot/Gameplay/ReadingArea/CardHoverInfoPanel
@onready var reading_vignette: VignetteEffect = $SceneRoot/OverlayLayer/ReadingVignetteOverlay
@onready var reading_slot_mgr: ReadingSlotManager = $Systems/ReadingSlotManager
@onready var story_renderer: StoryRenderer = $Systems/StoryRenderer
@onready var end_screen: EndScreen = $SceneRoot/OverlayLayer/EndPanel
@onready var reading_area: Control = $SceneRoot/Gameplay/ReadingArea

@onready var sidebar: Sidebar = $SceneRoot/Gameplay/Sidebar
@onready var story_title_label: Label = $SceneRoot/Gameplay/StoryArea/StoryTitleLabel
@onready var story_rich_text: RichTextLabel = $SceneRoot/Gameplay/StoryArea/StoryRichText
@onready var client_context_text: RichTextLabel = $SceneRoot/Gameplay/StoryArea/ClientContextText

@onready var loading_panel: Control = $SceneRoot/OverlayLayer/LoadingPanel
@onready var intro_panel: Control = $SceneRoot/OverlayLayer/IntroPanel
@onready var hover_spotlight_mgr: HoverSpotlightManager = $Systems/HoverSpotlightManager
@onready var behavior_tree: Node = $Systems/BehaviorTree

var slot_piles: Array[Pile] = []
var slot_labels: Array[Label] = []
var reading_labels: Array[RichTextLabel] = []
var slot_bgs: Array[NinePatchRect] = []

var portraits := PortraitLoader.new()
var deck := DeckManager.new()
var back_texture: Texture2D


func _ready() -> void:
	back_texture = load("res://assets/card_back.png")

	if card_manager.card_factory is JsonCardFactory:
		var factory := card_manager.card_factory as JsonCardFactory
		factory.back_image = back_texture

	for i: int in range(3):
		var slot_root: Node = get_node("SceneRoot/Gameplay/ReadingArea/ReadingSlots/Slot%d" % i)
		slot_piles.append(slot_root.get_node("SlotPile") as Pile)
		slot_labels.append(slot_root.get_node("SlotLabel") as Label)
		reading_labels.append(slot_root.get_node("ReadingLabel") as RichTextLabel)
		slot_bgs.append(slot_root.get_node("SlotBg") as NinePatchRect)

	sidebar.restart_requested.connect(func() -> void: get_tree().reload_current_scene())
	resolution_panel.visible = false
	intro_panel.visible = false
	card_hover_panel.z_index = 4096
	_set_cards_visible(false)

	end_screen.play_again_requested.connect(func() -> void: get_tree().reload_current_scene())

	if claude_api.has_method("initialize"):
		claude_api.initialize(game_blackboard)

	intro_panel.initialize(game_blackboard)
	resolution_panel.initialize(game_blackboard)

	# Reading slot manager wiring
	reading_slot_mgr.initialize(slot_piles, slot_labels, reading_labels, player_hand, claude_api, game_blackboard)
	reading_slot_mgr.slot_locked.connect(_on_slot_locked)
	reading_slot_mgr.story_changed.connect(_render_story)
	reading_slot_mgr.request_reading_sound.connect(sound_manager.play_reading)
	reading_slot_mgr.request_stop_reading_sound.connect(sound_manager.stop_reading)
	reading_slot_mgr.request_card_drop_sound.connect(sound_manager.play_card_drop)
	reading_slot_mgr.waiting_for_reading_started.connect(func(_i: int) -> void: reading_vignette.fade_in())
	reading_slot_mgr.waiting_for_reading_ended.connect(func(_i: int) -> void: reading_vignette.fade_out())

	story_renderer.story_text = story_rich_text

	player_hand.max_hand_size = 9
	player_hand.max_hand_spread = 700

	# Wire event signals to blackboard for behavior tree
	reading_slot_mgr.all_slots_filled.connect(func() -> void: game_blackboard.set_value("all_slots_filled", true))
	claude_api.client_request_completed.connect(_on_client_request_completed)
	claude_api.client_request_failed.connect(_on_client_request_failed)
	reading_slot_mgr.reading_received.connect(_on_reading_received)

	# Start behavior tree
	behavior_tree.actor = self
	behavior_tree.blackboard = game_blackboard
	game_blackboard.set_value("phase", "init")
	behavior_tree.enabled = true


# --- Signal Handlers ---


func _on_client_request_completed(_request_id: String, client_data: Dictionary) -> void:
	game_blackboard.set_value("client_data", client_data)
	game_blackboard.set_value("client_data_ready", true)


func _on_client_request_failed(_request_id: String, error_message: String) -> void:
	game_blackboard.set_value("client_error_message", error_message)
	game_blackboard.set_value("client_request_failed", true)


func _on_reading_received(_slot_index: int, _text: String) -> void:
	if resolution_panel.visible:
		var encounter: Variant = game_blackboard.get_value("current_encounter", {})
		if encounter is Dictionary:
			encounter = (encounter as Dictionary).duplicate(true)
		var title: String = "Reading for %s" % (encounter as Dictionary).get("client", {}).get("name", "Unknown")
		var readings: Array[String] = []
		for i: int in range(3):
			readings.append(reading_slot_mgr.slot_readings[i])
		resolution_panel.populate(title, readings)


func _on_slot_locked(_slot_index: int, card_name: String, _display_name: String, _reading: String) -> void:
	deck.discard.append(card_name)
	sidebar.update_progress(reading_slot_mgr.slot_filled)
	sidebar.update_deck_count(player_hand.get_card_count())


# --- Helpers called by BT action leaves ---


func _render_story() -> void:
	story_renderer.render(
		reading_slot_mgr.slot_filled,
		reading_slot_mgr.slot_readings,
		reading_slot_mgr.active_slot,
		reading_slot_mgr.current_hover_slot,
		reading_slot_mgr.hover_preview_text
	)


func _deal_hand() -> void:
	var available: int = deck.deck.size()
	if available <= 0:
		return
	var drawn: Array[String] = deck.draw(available)
	for card_name: String in drawn:
		var card: Card = card_manager.card_factory.create_card(card_name, player_hand)
		if card != null:
			card.is_reversed = randf() < 0.5
	sidebar.update_deck_count(player_hand.get_card_count())


func _destroy_all_card_nodes() -> void:
	reading_slot_mgr.cleanup()
	card_hover_panel.hide_immediately()
	hover_spotlight_mgr.clear(reading_vignette)
	reading_vignette.reset()

	for pile: Pile in slot_piles:
		pile.clear_cards()
	card_manager.reset_history()
	Card.holding_card_count = 0
	Card.hovering_card_count = 0


func _set_cards_visible(is_visible: bool) -> void:
	reading_area.visible = is_visible
	if not is_visible:
		card_hover_panel.hide_immediately()
		hover_spotlight_mgr.clear(reading_vignette)
