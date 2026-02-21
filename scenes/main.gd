extends Control

@onready var card_manager: CardManager = $CardManager
@onready var player_hand: Hand = $PlayerHand
@onready var client_name_label: Label = $ClientPanel/ClientName
@onready var client_story_label: RichTextLabel = $ClientPanel/ClientStory
@onready var client_counter_label: Label = $ClientCounter
@onready var resolution_panel: Control = $ResolutionPanel
@onready var resolution_title: Label = $ResolutionPanel/StoryBox/ResolutionTitle
@onready var resolution_text: RichTextLabel = $ResolutionPanel/StoryBox/ResolutionText
@onready var next_button: Button = $ResolutionPanel/StoryBox/NextButton
@onready var claude_api: Node = $ClaudeAPI

var slot_piles: Array[Pile] = []
var slot_labels: Array[Label] = []
var reading_labels: Array[RichTextLabel] = []

var all_card_names: Array[String] = []
var deck: Array[String] = []
var discard: Array[String] = []

var clients: Array = []
var current_client: Dictionary = {}
var previous_client_index: int = -1
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

var back_texture: Texture2D

const MAJOR_MEANINGS := {
	"the_fool": "a leap of faith into the unknown",
	"the_magician": "the power to shape reality through will alone",
	"the_high_priestess": "hidden knowledge waiting to surface",
	"empress": "abundant creation overflowing its bounds",
	"the_emperor": "order imposed by an unyielding hand",
	"the_hierophant": "wisdom passed down through sacred tradition",
	"lovers": "a choice that reveals the heart's true desire",
	"the_chariot": "relentless momentum that cannot be stopped",
	"the_strength": "quiet courage that tames what force cannot",
	"the_hermit": "solitary truth found only in withdrawal",
	"the_wheel_of_fortune": "the turning of fate beyond mortal control",
	"the_justice": "a reckoning that weighs every deed",
	"the_hanged_man": "surrender that reveals what struggle hid",
	"the_death": "an ending that clears the way for what must come next",
	"the_temperance": "patience blending opposites into harmony",
	"the_devil": "chains worn willingly in the name of desire",
	"tower": "a sudden collapse of everything once trusted",
	"the_stars": "fragile hope glimmering after devastation",
	"the_moon": "illusions and fears rising from deep waters",
	"the_sun": "radiant joy that burns away all shadow",
	"the_judgement": "a final call to account for who you have become",
	"the_world": "completion of a cycle and the threshold of a new one",
}

const SUIT_THEMES := {
	"cups": "the heart's longing",
	"gold": "earthly fortune",
	"swords": "cutting truth",
	"wands": "burning ambition",
}

const VALUE_INTENSITIES := {
	"ace": "the pure seed of",
	"two": "a delicate balance of",
	"three": "the first fruits of",
	"four": "a settled foundation of",
	"five": "the upheaval of",
	"six": "the harmony of",
	"seven": "the mystery of",
	"eight": "the momentum of",
	"nine": "the culmination of",
	"ten": "the overwhelming weight of",
	"page": "a youthful messenger of",
	"knight": "a fierce pursuit of",
	"queen": "the deep mastery of",
	"king": "the commanding authority of",
}

const READING_TEMPLATES := [
	"The cards reveal %s, and its influence spreads across everything.",
	"Here the cards speak of %s, a thread woven deep into this tale.",
	"What emerges now is %s, quiet but undeniable.",
	"The reading turns upon %s, reshaping all that came before.",
	"Through the veil, %s makes itself known.",
	"The cards whisper of %s, and the whisper becomes a roar.",
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

	next_button.pressed.connect(_on_next_button_pressed)
	resolution_panel.visible = false

	claude_api.request_completed.connect(_on_claude_request_completed)
	claude_api.request_failed.connect(_on_claude_request_failed)

	_build_card_name_list()
	_load_clients()
	_shuffle_deck()
	_next_client()


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
	var file = FileAccess.open("res://data/clients.json", FileAccess.READ)
	var fallback = [{
		"name": "The Stranger",
		"story_parts": [
			"A figure in a dark cloak sits before you. They say nothing, only wait.",
			"The silence deepens between you like a well with no bottom.",
			"Something stirs in the dark behind their eyes.",
			"The stranger rises, pulls their cloak tight, and vanishes into the night."
		]
	}]

	if file:
		var json_text = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_text)
		if parsed is Array and not parsed.is_empty():
			clients = parsed
		else:
			push_error("clients.json failed to parse or is not an array")
			clients = fallback
	else:
		push_error("Failed to load clients.json")
		clients = fallback


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
	var index = randi() % clients.size()
	while clients.size() > 1 and index == previous_client_index:
		index = randi() % clients.size()
	previous_client_index = index
	current_client = clients[index]
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

	client_name_label.text = current_client["name"]
	client_counter_label.text = "Client #%d" % client_count

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


func _deal_hand() -> void:
	var drawn = _draw_cards(3)
	for card_name in drawn:
		card_manager.card_factory.create_card(card_name, player_hand)


func _find_held_card() -> Card:
	for card in player_hand._held_cards:
		if card.current_state == DraggableObject.DraggableState.HOLDING:
			return card
	return null


func _get_card_meaning(card_info: Dictionary) -> String:
	var card_name: String = card_info.get("name", "")
	var arcana: String = card_info.get("arcana", "minor")

	if arcana == "major":
		return MAJOR_MEANINGS.get(card_name, "something beyond understanding")

	var suit: String = card_info.get("suit", "cups")
	var value: String = card_info.get("value", "ace")
	var intensity: String = VALUE_INTENSITIES.get(value, "the essence of")
	var theme: String = SUIT_THEMES.get(suit, "hidden forces")
	return "%s %s" % [intensity, theme]


func _generate_reading_template(card_info: Dictionary, slot_index: int) -> String:
	var key = "%s:%d" % [card_info.get("name", ""), slot_index]
	if _reading_cache.has(key):
		return _reading_cache[key]

	var meaning = _get_card_meaning(card_info)
	var template: String = READING_TEMPLATES[randi() % READING_TEMPLATES.size()]
	var reading = template % meaning

	_reading_cache[key] = reading
	return reading


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
	var parts: Array = current_client["story_parts"]
	var text := ""

	for i in range(3):
		if i > _active_slot and not slot_filled[i]:
			break

		text += "%s\n\n" % parts[i]

		if slot_filled[i]:
			text += "[i]%s[/i]\n\n" % slot_readings[i]
		elif i == _active_slot and _hover_preview_text != "":
			text += "[color=#8878a0][i]%s[/i][/color]\n\n" % _hover_preview_text
		else:
			text += "[color=#4a3a60]__________________________________________[/color]\n\n"

	if slot_filled[0] and slot_filled[1] and slot_filled[2]:
		text += "%s" % parts[3]

	client_story_label.text = text


func _process(_delta: float) -> void:
	if resolution_panel.visible:
		return

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
		reading_labels[new_hover_slot].text = "[color=#8878a0][i]%s[/i][/color]" % cached
		_hover_preview_text = cached
		_render_story()
		return

	if claude_api.is_available():
		var loading_text := "The cards are speaking..."
		reading_labels[new_hover_slot].text = "[color=#6a5a80][i]%s[/i][/color]" % loading_text
		_hover_preview_text = loading_text
		_render_story()
		_loading_slots[new_hover_slot] = true

		var held_card = _find_held_card()
		if held_card == null:
			return

		var card_meaning := _get_card_meaning(held_card.card_info)
		var story_parts: Array = current_client["story_parts"]

		var locked_paragraphs: Array[String] = []
		for i in range(3):
			locked_paragraphs.append(slot_readings[i])

		var request_id := cache_key
		_pending_requests[request_id] = new_hover_slot

		claude_api.generate_reading(
			request_id,
			current_client["name"],
			story_parts,
			new_hover_slot,
			new_hover_card_name,
			card_meaning,
			locked_paragraphs
		)
	else:
		var held_card = _find_held_card()
		if held_card == null:
			return
		var reading = _generate_reading_template(held_card.card_info, new_hover_slot)
		reading_labels[new_hover_slot].text = "[color=#8878a0][i]%s[/i][/color]" % reading
		_hover_preview_text = reading
		_render_story()


func _on_claude_request_completed(request_id: String, text: String) -> void:
	_reading_cache[request_id] = text

	if not _pending_requests.has(request_id):
		return
	var slot_index: int = _pending_requests[request_id]
	_pending_requests.erase(request_id)
	_loading_slots.erase(slot_index)

	if slot_filled[slot_index]:
		return

	var card_name: String = request_id.get_slice(":", 0)
	if _current_hover_slot == slot_index and _current_hover_card_name == card_name:
		reading_labels[slot_index].text = "[color=#8878a0][i]%s[/i][/color]" % text
		_hover_preview_text = text
		_render_story()


func _on_claude_request_failed(request_id: String, _error_message: String) -> void:
	if not _pending_requests.has(request_id):
		return
	var slot_index: int = _pending_requests[request_id]
	_pending_requests.erase(request_id)
	_loading_slots.erase(slot_index)

	var card_name: String = request_id.get_slice(":", 0)
	var held_card = _find_held_card()
	if held_card != null and held_card.card_name == card_name:
		var fallback := _generate_reading_template(held_card.card_info, slot_index)
		_reading_cache[request_id] = fallback
		if _current_hover_slot == slot_index:
			reading_labels[slot_index].text = "[color=#8878a0][i]%s[/i][/color]" % fallback
			_hover_preview_text = fallback
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
			reading = _generate_reading_template(card.card_info, slot_index)
			_reading_cache[cache_key] = reading

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
	resolution_title.text = "Reading for %s" % current_client["name"]

	var parts: Array = current_client["story_parts"]
	var full_text := ""
	for i in range(3):
		full_text += "[i][color=#9a8ab0]%s[/color][/i]\n\n" % parts[i]
		full_text += "%s\n\n" % slot_readings[i]
	full_text += "[i][color=#9a8ab0]%s[/color][/i]" % parts[3]

	resolution_text.text = full_text


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
