extends Control

@onready var card_manager: CardManager = $SceneRoot/Gameplay/CardManager
@onready var player_hand: Hand = $SceneRoot/Gameplay/ReadingArea/PlayerHand
@onready var resolution_panel: Control = $SceneRoot/OverlayLayer/ResolutionPanel
@onready var resolution_title: Label = $SceneRoot/OverlayLayer/ResolutionPanel/StoryBox/ResolutionTitle
@onready var resolution_text: RichTextLabel = $SceneRoot/OverlayLayer/ResolutionPanel/StoryBox/ResolutionText
@onready var next_button: Button = $SceneRoot/OverlayLayer/ResolutionPanel/StoryBox/NextButton
@onready var claude_api: Node = $Systems/ClaudeAPI
@onready var sound_manager: Node = $Systems/SoundManager

@onready var card_hover_panel: CardHoverInfoPanel = $SceneRoot/Gameplay/ReadingArea/CardHoverInfoPanel
@onready var reading_vignette: VignetteEffect = $SceneRoot/OverlayLayer/ReadingVignetteOverlay
@onready var reading_slot_mgr: ReadingSlotManager = $Systems/ReadingSlotManager
@onready var story_renderer: StoryRenderer = $Systems/StoryRenderer
@onready var end_screen: EndScreen = $SceneRoot/OverlayLayer/EndPanel

@onready var sidebar: Sidebar = $SceneRoot/Gameplay/Sidebar
@onready var story_title_label: Label = $SceneRoot/Gameplay/StoryArea/StoryTitleLabel
@onready var story_rich_text: RichTextLabel = $SceneRoot/Gameplay/StoryArea/StoryRichText
@onready var client_context_text: RichTextLabel = $SceneRoot/Gameplay/StoryArea/ClientContextText

@onready var loading_panel: Control = $SceneRoot/OverlayLayer/LoadingPanel
@onready var intro_panel: Control = $SceneRoot/OverlayLayer/IntroPanel
@onready var intro_portrait: TextureRect = $SceneRoot/OverlayLayer/IntroPanel/IntroBox/IntroPortrait
@onready var intro_name: Label = $SceneRoot/OverlayLayer/IntroPanel/IntroBox/IntroName
@onready var intro_context: RichTextLabel = $SceneRoot/OverlayLayer/IntroPanel/IntroBox/IntroContext
@onready var begin_button: Button = $SceneRoot/OverlayLayer/IntroPanel/IntroBox/BeginButton

var slot_piles: Array[Pile] = []
var slot_labels: Array[Label] = []
var reading_labels: Array[RichTextLabel] = []
var slot_bgs: Array[NinePatchRect] = []

var portraits := PortraitLoader.new()
var deck := DeckManager.new()

var game_state: Dictionary = {
	"encounters": [
		{
			"client": {
				"name": "Maria the Widow",
				"context": "I got married at 23. Everyone told me not to but i did and last week, my husband just, he's just dead, i'm sad and i don't know what to do. is he at peace?"},
			"slots": [
				{"card": "", "text": ""},
				{"card": "", "text": ""},
				{"card": "", "text": ""}
			]
		}
	]
}
var current_encounter_index: int = 0
var current_encounter: Dictionary = {}
var client_count: int = 0

var back_texture: Texture2D
var _time_passed: float = 0.0


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

	next_button.pressed.connect(_on_next_button_pressed)
	begin_button.pressed.connect(_on_begin_button_pressed)
	sidebar.restart_requested.connect(func() -> void: get_tree().reload_current_scene())
	resolution_panel.visible = false
	intro_panel.visible = false
	card_hover_panel.z_index = 4096

	claude_api.client_request_completed.connect(_on_client_request_completed)
	claude_api.client_request_failed.connect(_on_client_request_failed)

	end_screen.play_again_requested.connect(func() -> void: get_tree().reload_current_scene())

	# Reading slot manager wiring
	reading_slot_mgr.initialize(slot_piles, slot_labels, reading_labels, player_hand, claude_api)
	reading_slot_mgr.slot_locked.connect(_on_slot_locked)
	reading_slot_mgr.all_slots_filled.connect(_on_all_slots_filled)
	reading_slot_mgr.story_changed.connect(_render_story)
	reading_slot_mgr.reading_received.connect(_on_reading_received)
	reading_slot_mgr.request_reading_sound.connect(sound_manager.play_reading)
	reading_slot_mgr.request_stop_reading_sound.connect(sound_manager.stop_reading)
	reading_slot_mgr.request_card_drop_sound.connect(sound_manager.play_card_drop)
	reading_slot_mgr.waiting_for_reading_started.connect(func(_i: int) -> void: reading_vignette.fade_in())
	reading_slot_mgr.waiting_for_reading_ended.connect(func(_i: int) -> void: reading_vignette.fade_out())

	# Story renderer wiring
	story_renderer.story_text = story_rich_text

	player_hand.max_hand_size = 9
	player_hand.max_hand_spread = 700

	portraits.load_all()
	deck.build_card_names()
	deck.shuffle(9)
	sound_manager.play_shuffle()
	_next_client()
	sound_manager.play_ambient()


func _process(delta: float) -> void:
	if resolution_panel.visible:
		card_hover_panel.hide_immediately()
		return

	_time_passed += delta * 3.0
	var rsm_active: int = reading_slot_mgr.active_slot
	var rsm_filled: Array[bool] = reading_slot_mgr.slot_filled
	for i: int in range(3):
		if i == rsm_active and not rsm_filled[i]:
			var pulse: float = (sin(_time_passed) + 1.0) * 0.5
			var active_color := Color(StoryRenderer.SLOT_COLORS[i])
			slot_bgs[i].modulate = active_color.lerp(Color.WHITE, 0.2)
			slot_bgs[i].modulate.a = lerp(0.5, 1.0, pulse)
		else:
			slot_bgs[i].modulate = Color(1.0, 1.0, 1.0, 0.4)

	card_hover_panel.update_display(player_hand)
	reading_slot_mgr.process_frame()


# --- Client Flow ---


func _next_client() -> void:
	if current_encounter_index >= game_state["encounters"].size():
		_show_client_loading()
		claude_api.generate_client("client_req", game_state)
		return

	current_encounter = game_state["encounters"][current_encounter_index]
	current_encounter_index += 1
	_show_intro()


func _show_intro() -> void:
	loading_panel.visible = false
	resolution_panel.visible = false

	var client_name: String = current_encounter["client"]["name"]
	intro_name.text = client_name
	intro_context.text = "[center]%s[/center]" % current_encounter["client"]["context"]
	intro_portrait.texture = portraits.get_portrait(client_name)
	intro_panel.visible = true


func _on_begin_button_pressed() -> void:
	intro_panel.visible = false
	_setup_current_client_ui()


func _show_client_loading() -> void:
	loading_panel.visible = true
	resolution_panel.visible = false
	card_hover_panel.visible = false
	for i: int in range(3):
		reading_labels[i].text = ""
		slot_labels[i].text = ""
		slot_piles[i].enable_drop_zone = false


func _on_client_request_completed(_request_id: String, client_data: Dictionary) -> void:
	loading_panel.visible = false
	var new_encounter: Dictionary = {
		"client": {
			"name": client_data.get("name", "Unknown"),
			"context": client_data.get("context", "")
		},
		"slots": [
			{"card": "", "text": ""},
			{"card": "", "text": ""},
			{"card": "", "text": ""}
		]
	}
	game_state["encounters"].append(new_encounter)
	_next_client()


func _on_client_request_failed(_request_id: String, error_message: String) -> void:
	loading_panel.visible = false
	story_rich_text.text = "[color=#a05a5a]No one came to the table. (%s)[/color]" % error_message


# --- Session Setup ---


func _setup_current_client_ui() -> void:
	client_count += 1
	loading_panel.visible = false

	card_hover_panel.hide_immediately()
	reading_vignette.reset()

	reading_slot_mgr.reset_for_client(game_state, current_encounter_index - 1)

	var client_name: String = current_encounter["client"]["name"]
	sidebar.update_client(client_name, client_count, portraits.get_portrait(client_name))
	sidebar.update_deck_count(player_hand.get_card_count())
	sidebar.update_progress(reading_slot_mgr.slot_filled)
	story_title_label.text = client_name
	client_context_text.text = current_encounter["client"]["context"]

	_render_story()
	resolution_panel.visible = false
	_deal_hand()


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


# --- Slot Event Handlers ---


func _on_slot_locked(_slot_index: int, card_name: String, _display_name: String, _reading: String) -> void:
	deck.discard.append(card_name)
	sidebar.update_progress(reading_slot_mgr.slot_filled)
	sidebar.update_deck_count(player_hand.get_card_count())


func _on_all_slots_filled() -> void:
	get_tree().create_timer(1.2).timeout.connect(_show_resolution)


func _render_story() -> void:
	story_renderer.render(
		reading_slot_mgr.slot_filled,
		reading_slot_mgr.slot_readings,
		reading_slot_mgr.active_slot,
		reading_slot_mgr.current_hover_slot,
		reading_slot_mgr.hover_preview_text
	)


func _on_reading_received(_slot_index: int, _text: String) -> void:
	if resolution_panel.visible:
		_show_resolution()


# --- Resolution / End ---


func _show_resolution() -> void:
	resolution_panel.visible = true
	resolution_title.text = "Reading for %s" % current_encounter["client"]["name"]

	var lines: Array[String] = []
	for i: int in range(3):
		lines.append("[color=%s]%s[/color]" % [StoryRenderer.SLOT_COLORS[i], reading_slot_mgr.slot_readings[i]])
	resolution_text.text = "\n\n".join(lines)


func _on_next_button_pressed() -> void:
	_destroy_all_card_nodes()
	if player_hand.get_card_count() < 3:
		end_screen.show_summary(
			game_state.get("encounters", []),
			portraits.get_portrait,
			back_texture
		)
		loading_panel.visible = false
		resolution_panel.visible = false
	else:
		_next_client()


func _destroy_all_card_nodes() -> void:
	reading_slot_mgr.cleanup()
	card_hover_panel.hide_immediately()
	reading_vignette.reset()

	for pile: Pile in slot_piles:
		pile.clear_cards()
	card_manager.reset_history()
	Card.holding_card_count = 0
	Card.hovering_card_count = 0
