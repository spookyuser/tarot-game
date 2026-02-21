extends Control

@onready var card_manager: CardManager = $CardManager
@onready var player_hand: Hand = $PlayerHand
@onready var resolution_panel: Control = $ResolutionPanel
@onready var resolution_title: Label = $ResolutionPanel/StoryBox/ResolutionTitle
@onready var resolution_text: RichTextLabel = $ResolutionPanel/StoryBox/ResolutionText
@onready var next_button: Button = $ResolutionPanel/StoryBox/NextButton
@onready var claude_api: Node = $ClaudeAPI

@onready var client_name_left: Label = $ClientNameLeft
@onready var client_counter_left: Label = $ClientCounterLeft
@onready var portrait_frame: TextureRect = $PortraitFrame
@onready var deck_count_label: Label = $DeckCountLabel
@onready var deck_icon: TextureRect = $DeckIcon
@onready var story_title_label: Label = $StoryTitleLabel
@onready var story_rich_text: RichTextLabel = $StoryRichText
@onready var progress_icons: Array[TextureRect] = [
	$ProgressIcon0, $ProgressIcon1, $ProgressIcon2
]

var slot_piles: Array[Pile] = []
var slot_labels: Array[Label] = []
var reading_labels: Array[RichTextLabel] = []
var slot_bgs: Array[NinePatchRect] = []

var all_card_names: Array[String] = []
var deck: Array[String] = []
var discard: Array[String] = []

@onready var client_context_text: RichTextLabel = $ClientContextText



var game_state: Dictionary = {
	"encounters": [
		{
			"client": {
				"name": "Maria the Widow",
				"context": "I lost my husband, and i don't know what to do" 		},
			"story": "{0}\n\n{1}\n\n{2}",
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

var slot_filled: Array[bool] = [false, false, false]
var slot_prev_counts: Array[int] = [0, 0, 0]
var slot_readings: Array[String] = ["", "", ""]
var _reading_cache: Dictionary = {}

var _active_slot: int = 0
var _current_hover_slot: int = -1
var _current_hover_card_name: String = ""
var _hover_preview_text: String = ""
var _pending_requests: Dictionary = {}
var _loading_slots: Dictionary = {}
var _time_passed: float = 0.0

var back_texture: Texture2D
var portrait_textures: Dictionary = {}

const CLIENT_PORTRAITS := {
	"Maria the Widow": "res://art/MinifolksVillagers/Outline/MiniVillagerWoman.png",
	"The Stranger": "res://art/MinifolksVillagers/Outline/MiniNobleMan.png",
}

const PORTRAIT_FALLBACKS := [
	"res://art/MinifolksVillagers/Outline/MiniPeasant.png",
	"res://art/MinifolksVillagers/Outline/MiniWorker.png",
	"res://art/MinifolksVillagers/Outline/MiniVillagerMan.png",
	"res://art/MinifolksVillagers/Outline/MiniOldMan.png",
	"res://art/MinifolksVillagers/Outline/MiniOldWoman.png",
	"res://art/MinifolksVillagers/Outline/MiniNobleWoman.png",
	"res://art/MinifolksVillagers/Outline/MiniPrincess.png",
	"res://art/MinifolksVillagers/Outline/MiniQueen.png",
]

const PORTRAIT_FRAME_SIZE := 32

const SLOT_COLORS := [
	"#e0b8c8", # Slot 0: Pinkish
	"#b8e0c8", # Slot 1: Greenish
	"#b8c8e0", # Slot 2: Bluish
]

const HOVER_COLORS := [
	"#a07888", # Slot 0 hover
	"#78a088", # Slot 1 hover
	"#7888a0", # Slot 2 hover
]




func _ready() -> void:
	back_texture = load("res://assets/card_back.png")

	if card_manager.card_factory is JsonCardFactory:
		var factory := card_manager.card_factory as JsonCardFactory
		factory.back_image = back_texture

	for i in range(3):
		slot_piles.append(get_node("SlotPile%d" % i) as Pile)
		slot_labels.append(get_node("SlotLabel%d" % i) as Label)
		reading_labels.append(get_node("ReadingLabel%d" % i) as RichTextLabel)
		slot_bgs.append(get_node("SlotBg%d" % i) as NinePatchRect)

	next_button.pressed.connect(_on_next_button_pressed)
	resolution_panel.visible = false

	claude_api.request_completed.connect(_on_claude_request_completed)
	claude_api.request_failed.connect(_on_claude_request_failed)

	_load_portrait_textures()

	_build_card_name_list()
	_load_clients()
	_shuffle_deck()
	_next_client()


func _load_portrait_textures() -> void:
	var all_paths := {}
	for client_name in CLIENT_PORTRAITS:
		all_paths[CLIENT_PORTRAITS[client_name]] = true
	for path in PORTRAIT_FALLBACKS:
		all_paths[path] = true

	for path in all_paths.keys():
		var sheet := load(path) as Texture2D
		if sheet == null:
			continue
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(0, 0, PORTRAIT_FRAME_SIZE, PORTRAIT_FRAME_SIZE)
		portrait_textures[path] = atlas


func _get_portrait_for_client(client_name: String) -> Texture2D:
	if CLIENT_PORTRAITS.has(client_name):
		var path: String = CLIENT_PORTRAITS[client_name]
		if portrait_textures.has(path):
			return portrait_textures[path]

	var fallback_index := client_name.hash() % PORTRAIT_FALLBACKS.size()
	if fallback_index < 0:
		fallback_index += PORTRAIT_FALLBACKS.size()
	var fallback_path: String = PORTRAIT_FALLBACKS[fallback_index]
	if portrait_textures.has(fallback_path):
		return portrait_textures[fallback_path]

	return null


func _build_card_name_list() -> void:
	var major = [
		"the_fool", "the_magician", "the_high_priestess", "empress",
		"the_emperor", "the_hierophant", "lovers", "the_chariot",
		"the_strength", "the_hermit", "the_wheel_of_fortune", "the_justice",
		"the_hanged_man", "the_death", "the_temperance", "the_devil",
		"tower", "the_stars", "the_moon", "the_sun",
		"the_judgement", "the_world"
	]
	all_card_names.append_array(major)

	var suits = ["cups", "gold", "swords", "wands"]
	var values = [
		"ace", "two", "three", "four", "five", "six", "seven",
		"eight", "nine", "ten", "page", "knight", "queen", "king"
	]
	for suit in suits:
		for val in values:
			all_card_names.append("%s_of_%s" % [val, suit])


func _load_clients() -> void:
	# `clients.json` logic removed. Game state is now initialized at the script level.
	pass


func _shuffle_deck() -> void:
	deck = all_card_names.duplicate()
	deck.shuffle()
	discard.clear()


func _draw_cards(count: int) -> Array[String]:
	if deck.size() < count:
		deck.append_array(discard)
		discard.clear()
		deck.shuffle()

	var drawn: Array[String] = []
	for i in range(mini(count, deck.size())):
		drawn.append(deck.pop_back())
	return drawn


func _next_client() -> void:
	if game_state["encounters"].size() > 0:
		if current_encounter_index >= game_state["encounters"].size():
			current_encounter_index = 0 # loop for now
		current_encounter = game_state["encounters"][current_encounter_index]
		current_encounter_index += 1
	else:
		return

	client_count += 1

	slot_filled = [false, false, false]
	slot_prev_counts = [0, 0, 0]
	slot_readings = ["", "", ""]
	_reading_cache.clear()
	_active_slot = 0
	_current_hover_slot = -1
	_current_hover_card_name = ""
	_hover_preview_text = ""
	_pending_requests.clear()
	_loading_slots.clear()

	_update_sidebar()
	story_title_label.text = current_encounter["client"]["name"]
	client_context_text.text = current_encounter["client"]["context"]

	for i in range(3):
		reading_labels[i].text = ""
		if i == 0:
			slot_piles[i].enable_drop_zone = true
		else:
			slot_piles[i].enable_drop_zone = false

	_update_slot_labels()
	_render_story()

	resolution_panel.visible = false

	_deal_hand()


func _update_sidebar() -> void:
	client_name_left.text = current_encounter["client"]["name"]
	client_counter_left.text = "Client #%d" % client_count

	var portrait := _get_portrait_for_client(current_encounter["client"]["name"])
	if portrait != null:
		portrait_frame.texture = portrait
	else:
		portrait_frame.texture = null

	_update_deck_count()
	_update_progress_icons()


func _update_deck_count() -> void:
	deck_count_label.text = "%d remaining" % deck.size()


func _update_progress_icons() -> void:
	for i in range(3):
		if slot_filled[i]:
			progress_icons[i].modulate = Color(0.85, 0.7, 0.4, 1.0)
		else:
			progress_icons[i].modulate = Color(0.3, 0.25, 0.4, 0.5)


func _deal_hand() -> void:
	var drawn = _draw_cards(3)
	for card_name in drawn:
		card_manager.card_factory.create_card(card_name, player_hand)
	_update_deck_count()


func _find_held_card() -> Card:
	for card in player_hand._held_cards:
		if card.current_state == DraggableObject.DraggableState.HOLDING:
			return card
	return null






func _build_slot_cards(hover_slot: int, hover_card: Card) -> Array:
	var cards: Array = [{}, {}, {}]
	for i in range(3):
		if slot_filled[i]:
			var pile_cards = slot_piles[i].get_top_cards(1)
			if pile_cards.size() > 0:
				cards[i] = pile_cards[0].card_info
		elif i == hover_slot and hover_card != null:
			cards[i] = hover_card.card_info
	return cards


func _build_slot_texts() -> Array[String]:
	var texts: Array[String] = ["", "", ""]
	for i in range(3):
		texts[i] = slot_readings[i]
	return texts


func _update_slot_labels() -> void:
	for i in range(3):
		if slot_filled[i]:
			slot_labels[i].text = ""
		elif i == _active_slot:
			slot_labels[i].text = "Place a card"
			slot_labels[i].self_modulate = Color(0.85, 0.7, 0.4, 1.0)
		else:
			slot_labels[i].text = ""


func _render_story() -> void:
	var text: String = current_encounter["story"]

	for i in range(3):
		var placeholder := "{%d}" % i
		if slot_filled[i]:
			var colored := "[color=%s]%s[/color]" % [SLOT_COLORS[i], slot_readings[i]]
			text = text.replace(placeholder, colored)
		elif i == _current_hover_slot and _hover_preview_text != "":
			var preview := "[color=%s][i][wave amp=20.0 freq=5.0]%s[/wave][/i][/color]" % [HOVER_COLORS[i], _hover_preview_text]
			text = text.replace(placeholder, preview)
		else:
			text = text.replace(placeholder, "[color=#4a3a60]__________________________________________[/color]")

	story_rich_text.text = text


func _process(delta: float) -> void:
	if resolution_panel.visible:
		return

	_time_passed += delta * 3.0
	for i in range(3):
		if i == _active_slot and not slot_filled[i]:
			var pulse := (sin(_time_passed) + 1.0) * 0.5 # 0.0 to 1.0
			var active_color := Color(SLOT_COLORS[i])
			slot_bgs[i].modulate = active_color.lerp(Color.WHITE, 0.2)
			slot_bgs[i].modulate.a = lerp(0.5, 1.0, pulse)
		else:
			slot_bgs[i].modulate = Color(1.0, 1.0, 1.0, 0.4)

	_update_hover_previews()
	_detect_drops()


func _update_hover_previews() -> void:
	if _active_slot >= 3:
		return

	var new_hover_slot := -1
	var new_hover_card_name := ""

	if Card.holding_card_count > 0:
		var held_card = _find_held_card()
		if held_card != null:
			new_hover_card_name = held_card.card_name
			if slot_piles[_active_slot].drop_zone != null and slot_piles[_active_slot].drop_zone.check_mouse_is_in_drop_zone():
				new_hover_slot = _active_slot

	# Hover exit
	if _current_hover_slot != -1 and (_current_hover_slot != new_hover_slot or _current_hover_card_name != new_hover_card_name):
		if not slot_filled[_current_hover_slot] and not _loading_slots.has(_current_hover_slot):
			reading_labels[_current_hover_slot].text = ""
			_hover_preview_text = ""
			_render_story()

	# No hover
	if new_hover_slot == -1:
		if _current_hover_slot != -1 and not _loading_slots.has(_active_slot):
			reading_labels[_active_slot].text = ""
			_hover_preview_text = ""
			_render_story()
		_current_hover_slot = -1
		_current_hover_card_name = ""
		return

	# Same hover as last frame
	if new_hover_slot == _current_hover_slot and new_hover_card_name == _current_hover_card_name:
		return

	# Hover enter
	_current_hover_slot = new_hover_slot
	_current_hover_card_name = new_hover_card_name

	var cache_key := "%s:%d" % [new_hover_card_name, new_hover_slot]

	if _reading_cache.has(cache_key):
		var cached: String = _reading_cache[cache_key]
		reading_labels[new_hover_slot].text = "[color=%s][i][wave amp=20.0 freq=5.0]%s[/wave][/i][/color]" % [HOVER_COLORS[new_hover_slot], cached]
		_hover_preview_text = cached
		_render_story()
		return

	var loading_text := "The cards are speaking..."
	# Use a grayish purple for loading state, keeping the wave effect
	reading_labels[new_hover_slot].text = "[color=#6a5a80][i][wave amp=20.0 freq=5.0]%s[/wave][/i][/color]" % loading_text
	_hover_preview_text = loading_text
	_render_story()
	_loading_slots[new_hover_slot] = true

	var held_card = _find_held_card()
	if held_card == null:
		return

	var request_id := cache_key
	_pending_requests[request_id] = new_hover_slot

	var slot_cards: Array = _build_slot_cards(new_hover_slot, held_card)
	var slot_texts: Array[String] = _build_slot_texts()

	claude_api.generate_reading(
		request_id,
		current_encounter["client"]["name"],
		current_encounter["client"]["context"],
		slot_cards,
		slot_texts,
		new_hover_slot
	)


func _on_claude_request_completed(request_id: String, text: String) -> void:
	_reading_cache[request_id] = text

	if not _pending_requests.has(request_id):
		return
	var slot_index: int = _pending_requests[request_id]
	_pending_requests.erase(request_id)
	_loading_slots.erase(slot_index)

	var card_name: String = request_id.get_slice(":", 0)

	if slot_filled[slot_index]:
		slot_readings[slot_index] = text
		reading_labels[slot_index].text = text
		_render_story()
		if resolution_panel.visible:
			_show_resolution()
	elif _current_hover_slot == slot_index and _current_hover_card_name == card_name:
		reading_labels[slot_index].text = "[color=%s][i][wave amp=20.0 freq=5.0]%s[/wave][/i][/color]" % [HOVER_COLORS[slot_index], text]
		_hover_preview_text = text
		_render_story()


func _on_claude_request_failed(request_id: String, _error_message: String) -> void:
	if not _pending_requests.has(request_id):
		return
	var slot_index: int = _pending_requests[request_id]
	_pending_requests.erase(request_id)
	_loading_slots.erase(slot_index)

	var error_text := "The cards are silent..."
	_reading_cache[request_id] = error_text

	var card_name: String = request_id.get_slice(":", 0)

	if slot_filled[slot_index]:
		slot_readings[slot_index] = error_text
		reading_labels[slot_index].text = error_text
		_render_story()
		if resolution_panel.visible:
			_show_resolution()
	elif _current_hover_slot == slot_index and _current_hover_card_name == card_name:
		reading_labels[slot_index].text = "[color=#a05a5a][i][wave amp=20.0 freq=5.0]%s[/wave][/i][/color]" % error_text
		_hover_preview_text = error_text
		_render_story()


func _detect_drops() -> void:
	if _active_slot >= 3:
		return

	var i := _active_slot
	var current_count = slot_piles[i].get_card_count()
	if current_count > 0 and slot_prev_counts[i] == 0:
		_lock_slot(i)
	slot_prev_counts[i] = current_count


func _lock_slot(slot_index: int) -> void:
	slot_filled[slot_index] = true
	slot_piles[slot_index].enable_drop_zone = false

	var cards = slot_piles[slot_index].get_top_cards(1)
	if cards.size() > 0:
		var card: Card = cards[0]
		var cache_key := "%s:%d" % [card.card_name, slot_index]

		var reading: String
		if _reading_cache.has(cache_key):
			reading = _reading_cache[cache_key]
		else:
			reading = "The cards are speaking..."

		slot_readings[slot_index] = reading
		reading_labels[slot_index].text = reading
		discard.append(card.card_name)

	_invalidate_unfilled_caches()

	_current_hover_slot = -1
	_current_hover_card_name = ""
	_hover_preview_text = ""
	_loading_slots.erase(slot_index)

	_active_slot = slot_index + 1

	if _active_slot < 3:
		slot_piles[_active_slot].enable_drop_zone = true

	_update_slot_labels()
	_render_story()
	_update_progress_icons()
	_update_deck_count()

	if slot_filled[0] and slot_filled[1] and slot_filled[2]:
		get_tree().create_timer(1.2).timeout.connect(_show_resolution)


func _invalidate_unfilled_caches() -> void:
	var keys_to_erase: Array[String] = []
	for key in _reading_cache.keys():
		var parts: PackedStringArray = key.split(":")
		if parts.size() == 2:
			var idx := parts[1].to_int()
			if not slot_filled[idx]:
				keys_to_erase.append(key)
	for key in keys_to_erase:
		_reading_cache.erase(key)


func _show_resolution() -> void:
	resolution_panel.visible = true
	resolution_title.text = "Reading for %s" % current_encounter["client"]["name"]

	var text: String = current_encounter["story"]
	for i in range(3):
		text = text.replace("{%d}" % i, "[color=%s]%s[/color]" % [SLOT_COLORS[i], slot_readings[i]])

	resolution_text.text = text


func _on_next_button_pressed() -> void:
	_destroy_all_card_nodes()
	_next_client()


func _destroy_all_card_nodes() -> void:
	for request_id in _pending_requests.keys():
		claude_api.cancel_request(request_id)
	_pending_requests.clear()
	_loading_slots.clear()
	_current_hover_slot = -1
	_current_hover_card_name = ""
	_hover_preview_text = ""

	player_hand.clear_cards()
	for pile in slot_piles:
		pile.clear_cards()
	card_manager.reset_history()
	Card.holding_card_count = 0
	Card.hovering_card_count = 0
