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
@onready var card_hover_info_panel: NinePatchRect = $CardHoverInfoPanel
@onready var card_hover_info_inner: ColorRect = $CardHoverInfoPanel/CardHoverInfoInner
@onready var card_hover_info_title: Label = $CardHoverInfoPanel/CardHoverInfoTitle
@onready var card_hover_info_body: RichTextLabel = $CardHoverInfoPanel/CardHoverInfoBody

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
var _hover_info_showing: bool = false
var _hover_info_tween: Tween = null
var _last_hovered_card_pos: Vector2 = Vector2.ZERO

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

const HOVER_INFO_PANEL_MARGIN := 8.0
const HOVER_INFO_PANEL_X_OFFSET := 10.0
const HOVER_INFO_PANEL_Y_OFFSET := 0.0
const HOVER_DESCRIPTION_COLOR := "#f2e6c9"
const HOVER_RULE_COLOR := "#9c8455"
const HOVER_TAG_COLOR := "#93abd1"
const HOVER_PANEL_BASE_COLOR := Color(0.09, 0.06, 0.04, 0.93)
const HOVER_DEFAULT_ICON := "res://art/fantasy_pixelart_ui/icons/silver_right.png"

const ARCANA_VISUALS := {
	"major": {
		"abbr": "MJR",
		"icon": "res://art/fantasy_pixelart_ui/icons/gold_flag.png",
		"color": "#ddb76d",
	},
	"minor": {
		"abbr": "MNR",
		"icon": "res://art/fantasy_pixelart_ui/icons/silver_flag.png",
		"color": "#97b5d5",
	},
}

const SUIT_VISUALS := {
	"cups": {
		"abbr": "CUP",
		"icon": "res://art/fantasy_pixelart_ui/icons/silver_down.png",
		"color": "#7bc2d4",
	},
	"gold": {
		"abbr": "GLD",
		"icon": "res://art/fantasy_pixelart_ui/icons/gold_star.png",
		"color": "#e0bc6a",
	},
	"swords": {
		"abbr": "SWD",
		"icon": "res://art/fantasy_pixelart_ui/icons/silver_sword.png",
		"color": "#c8d7ee",
	},
	"wands": {
		"abbr": "WND",
		"icon": "res://art/fantasy_pixelart_ui/icons/wood_up.png",
		"color": "#d9a270",
	},
	"major": {
		"abbr": "ARC",
		"icon": "res://art/fantasy_pixelart_ui/icons/gold_flag.png",
		"color": "#d6af67",
	},
}

const RARITY_VISUALS := {
	"common": {
		"abbr": "C",
		"icon": "res://art/fantasy_pixelart_ui/icons/silver_tick.png",
		"color": "#bbc0cb",
	},
	"rare": {
		"abbr": "R",
		"icon": "res://art/fantasy_pixelart_ui/icons/gold_tick.png",
		"color": "#e3c173",
	},
	"epic": {
		"abbr": "E",
		"icon": "res://art/fantasy_pixelart_ui/icons/gold_star.png",
		"color": "#cd8fe6",
	},
	"legendary": {
		"abbr": "L",
		"icon": "res://art/fantasy_pixelart_ui/icons/gold_castle.png",
		"color": "#f0cb6f",
	},
}

const OUTCOME_VISUALS := {
	"bright": {
		"abbr": "+",
		"icon": "res://art/fantasy_pixelart_ui/icons/gold_up.png",
		"color": "#92d5a8",
	},
	"dark": {
		"abbr": "-",
		"icon": "res://art/fantasy_pixelart_ui/icons/gold_down.png",
		"color": "#dd8f8f",
	},
	"mixed": {
		"abbr": "=",
		"icon": "res://art/fantasy_pixelart_ui/icons/silver_right.png",
		"color": "#d8bf89",
	},
}

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
	card_hover_info_panel.z_index = 4096

	claude_api.request_completed.connect(_on_claude_request_completed)
	claude_api.request_failed.connect(_on_claude_request_failed)
	claude_api.client_request_completed.connect(_on_client_request_completed)
	claude_api.client_request_failed.connect(_on_client_request_failed)

	player_hand.max_hand_size = 10
	player_hand.max_hand_spread = 520 # Fit within the middle column

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
	var pool := all_card_names.duplicate()
	pool.shuffle()
	deck = pool.slice(0, 10) as Array[String]
	discard.clear()


func _draw_cards(count: int) -> Array[String]:
	var drawn: Array[String] = []
	for i in range(mini(count, deck.size())):
		drawn.append(deck.pop_back())
	return drawn


func _next_client() -> void:
	if current_encounter_index >= game_state["encounters"].size():
		_show_client_loading()
		claude_api.generate_client("client_req", game_state)
		return

	current_encounter = game_state["encounters"][current_encounter_index]
	current_encounter_index += 1

	_setup_current_client_ui()

func _show_client_loading() -> void:
	story_title_label.text = "Waiting..."
	client_context_text.text = "The cards are shuffling..."
	story_rich_text.text = "[color=#6a5a80][i][wave amp=20.0 freq=5.0]A new presence approaches the table...[/wave][/i][/color]"
	for i in range(3):
		reading_labels[i].text = ""
		slot_labels[i].text = ""
		slot_piles[i].enable_drop_zone = false
	resolution_panel.visible = false
	card_hover_info_panel.visible = false

func _on_client_request_completed(_request_id: String, client_data: Dictionary) -> void:
	var new_encounter := {
		"client": {
			"name": client_data.get("name", "Unknown"),
			"context": client_data.get("context", "")
		},
		"story": client_data.get("story", "{0}\n\n{1}\n\n{2}"),
		"slots": [
			{"card": "", "text": ""},
			{"card": "", "text": ""},
			{"card": "", "text": ""}
		]
	}
	game_state["encounters"].append(new_encounter)
	_next_client()

func _on_client_request_failed(_request_id: String, error_message: String) -> void:
	story_rich_text.text = "[color=#a05a5a]No one came to the table. (%s)[/color]" % error_message

func _setup_current_client_ui() -> void:
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
	_hover_info_showing = false
	if _hover_info_tween != null and _hover_info_tween.is_running():
		_hover_info_tween.kill()
	card_hover_info_panel.visible = false
	card_hover_info_panel.modulate = Color(1, 1, 1, 1)

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
	deck_count_label.text = "%d remaining" % player_hand.get_card_count()


func _update_progress_icons() -> void:
	for i in range(3):
		if slot_filled[i]:
			progress_icons[i].modulate = Color(0.85, 0.7, 0.4, 1.0)
		else:
			progress_icons[i].modulate = Color(0.3, 0.25, 0.4, 0.5)


func _deal_hand() -> void:
	var available = deck.size()
	if available <= 0: return
	var drawn = _draw_cards(available)
	for card_name in drawn:
		card_manager.card_factory.create_card(card_name, player_hand)
	_update_deck_count()


func _find_held_card() -> Card:
	for card in player_hand._held_cards:
		if card.current_state == DraggableObject.DraggableState.HOLDING:
			return card
	return null


func _find_hovered_hand_card() -> Card:
	for card in player_hand._held_cards:
		if card.current_state == DraggableObject.DraggableState.HOVERING:
			return card
	return null


func _update_card_hover_info_panel() -> void:
	var hovered_card := _find_hovered_hand_card()

	if hovered_card != null:
		card_hover_info_title.text = _humanize_token(hovered_card.card_name)
		_apply_hover_panel_visuals(hovered_card.card_info)
		card_hover_info_body.text = _build_hover_body_text(hovered_card.card_info)
		_last_hovered_card_pos = hovered_card.global_position

		if not _hover_info_showing:
			_hover_info_showing = true
			_slide_hover_info_in(hovered_card)
		else:
			if _hover_info_tween == null or not _hover_info_tween.is_running():
				_position_hover_info_panel(hovered_card)
	else:
		if _hover_info_showing:
			_hover_info_showing = false
			_slide_hover_info_out()


func _position_hover_info_panel(card: Card) -> void:
	var card_rect: Rect2 = card.get_global_rect()
	var panel_size: Vector2 = card_hover_info_panel.size
	var viewport_size: Vector2 = get_viewport_rect().size

	# Default: extend out from the left side of the card
	var target_x := card_rect.position.x - panel_size.x - HOVER_INFO_PANEL_X_OFFSET

	# Fall back to right side if no room on the left
	if target_x < HOVER_INFO_PANEL_MARGIN:
		target_x = card_rect.position.x + card_rect.size.x + HOVER_INFO_PANEL_X_OFFSET

	var target_y := card_rect.position.y + HOVER_INFO_PANEL_Y_OFFSET

	target_x = clampf(
		target_x,
		HOVER_INFO_PANEL_MARGIN,
		viewport_size.x - panel_size.x - HOVER_INFO_PANEL_MARGIN
	)
	target_y = clampf(
		target_y,
		HOVER_INFO_PANEL_MARGIN,
		viewport_size.y - panel_size.y - HOVER_INFO_PANEL_MARGIN
	)

	card_hover_info_panel.global_position = Vector2(target_x, target_y)


func _slide_hover_info_in(card: Card) -> void:
	if _hover_info_tween != null and _hover_info_tween.is_running():
		_hover_info_tween.kill()

	card_hover_info_panel.visible = true

	# Set final position first, then read it back
	_position_hover_info_panel(card)
	var final_pos := card_hover_info_panel.global_position

	# Start behind the card edge
	var card_rect := card.get_global_rect()
	var start_pos := Vector2(card_rect.position.x, final_pos.y)

	card_hover_info_panel.global_position = start_pos
	card_hover_info_panel.modulate = Color(1, 1, 1, 0)

	_hover_info_tween = create_tween()
	_hover_info_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_hover_info_tween.set_parallel(true)
	_hover_info_tween.tween_property(card_hover_info_panel, "global_position", final_pos, 0.15)
	_hover_info_tween.tween_property(card_hover_info_panel, "modulate", Color(1, 1, 1, 1), 0.15)


func _slide_hover_info_out() -> void:
	if _hover_info_tween != null and _hover_info_tween.is_running():
		_hover_info_tween.kill()

	var current_pos := card_hover_info_panel.global_position
	var target_pos := Vector2(_last_hovered_card_pos.x, current_pos.y)

	_hover_info_tween = create_tween()
	_hover_info_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_hover_info_tween.set_parallel(true)
	_hover_info_tween.tween_property(card_hover_info_panel, "global_position", target_pos, 0.1)
	_hover_info_tween.tween_property(card_hover_info_panel, "modulate", Color(1, 1, 1, 0), 0.1)
	_hover_info_tween.set_parallel(false)
	_hover_info_tween.tween_callback(func(): card_hover_info_panel.visible = false)


func _build_hover_body_text(card_info: Dictionary) -> String:
	var arcana: String = String(card_info.get("arcana", "")).to_lower()
	var suit: String = String(card_info.get("suit", "")).to_lower()
	var value: String = String(card_info.get("value", ""))
	var numeric_value: int = int(card_info.get("numeric_value", -1))
	var rarity: String = String(card_info.get("rarity", "")).to_lower()
	var outcome: String = String(card_info.get("outcome", "")).to_lower()
	var description: String = _compact_hover_description(String(card_info.get("description", "")))
	var tags: Array = card_info.get("tags", [])
	var arcana_visual := _lookup_visual(ARCANA_VISUALS, arcana)
	var suit_visual := _lookup_visual(SUIT_VISUALS, suit)
	var rarity_visual := _lookup_visual(RARITY_VISUALS, rarity)
	var outcome_visual := _lookup_visual(OUTCOME_VISUALS, outcome)
	var parts: Array[String] = []

	var arcana_text := String(arcana_visual.get("abbr", "UNK"))
	var suit_text := "%s %s" % [
		String(suit_visual.get("abbr", "UNK")),
		_compact_value_token(value, numeric_value),
	]
	var rarity_text := String(rarity_visual.get("abbr", "?"))
	var outcome_text := String(outcome_visual.get("abbr", "?"))

	# MTG-style body: rules text first, compact stat line footer.
	parts.append("[color=%s][i]%s[/i][/color]" % [HOVER_DESCRIPTION_COLOR, _escape_bbcode(description)])
	parts.append("")
	parts.append("[color=%s]------------[/color]" % HOVER_RULE_COLOR)
	parts.append(_build_compact_row(arcana_visual, arcana_text, suit_visual, suit_text))
	parts.append(_build_compact_row(rarity_visual, rarity_text, outcome_visual, outcome_text))

	var tag_line := _compact_tag_line(tags)
	if not tag_line.is_empty():
		parts.append(tag_line)

	return "\n".join(parts)


func _apply_hover_panel_visuals(card_info: Dictionary) -> void:
	var suit_key := String(card_info.get("suit", "")).to_lower()
	var suit_visual := _lookup_visual(SUIT_VISUALS, suit_key)
	var accent_hex := String(suit_visual.get("color", "#c7b289"))
	var accent := Color.from_string(accent_hex, Color(0.85, 0.7, 0.4, 1.0))

	card_hover_info_title.add_theme_color_override("font_color", accent.lightened(0.15))
	card_hover_info_inner.color = Color(
		HOVER_PANEL_BASE_COLOR.r * 0.78 + accent.r * 0.16,
		HOVER_PANEL_BASE_COLOR.g * 0.78 + accent.g * 0.16,
		HOVER_PANEL_BASE_COLOR.b * 0.78 + accent.b * 0.16,
		HOVER_PANEL_BASE_COLOR.a
	)


func _lookup_visual(visual_map: Dictionary, key: String) -> Dictionary:
	var normalized := key.to_lower()
	if visual_map.has(normalized):
		return visual_map[normalized]

	var fallback_abbr := "UNK"
	if not normalized.is_empty():
		fallback_abbr = normalized.substr(0, mini(3, normalized.length())).to_upper()

	return {
		"abbr": fallback_abbr,
		"icon": HOVER_DEFAULT_ICON,
		"color": "#c7b289",
	}


func _build_compact_row(left_visual: Dictionary, left_text: String, right_visual: Dictionary, right_text: String) -> String:
	return "%s [color=%s][b]%s[/b][/color]  %s [color=%s][b]%s[/b][/color]" % [
		_build_hover_icon(String(left_visual.get("icon", HOVER_DEFAULT_ICON))),
		String(left_visual.get("color", "#c7b289")),
		_escape_bbcode(left_text),
		_build_hover_icon(String(right_visual.get("icon", HOVER_DEFAULT_ICON))),
		String(right_visual.get("color", "#c7b289")),
		_escape_bbcode(right_text),
	]


func _build_hover_icon(icon_path: String) -> String:
	if icon_path.is_empty():
		return "*"
	return "[img]%s[/img]" % icon_path


func _compact_hover_description(text: String, max_chars: int = 72) -> String:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return "No omen appears."
	if trimmed.length() <= max_chars:
		return trimmed
	return "%s..." % trimmed.substr(0, max_chars).strip_edges()


func _compact_value_token(value: String, numeric_value: int) -> String:
	if numeric_value >= 0:
		return str(numeric_value)

	var compact := _humanize_token(value).to_upper()
	if compact.length() <= 3:
		return compact
	return compact.substr(0, 3)


func _compact_tag_line(tags: Array, max_count: int = 2) -> String:
	if tags.is_empty():
		return ""

	var tag_tokens: Array[String] = []
	for i in range(mini(tags.size(), max_count)):
		var compact := _humanize_token(String(tags[i])).to_upper()
		if compact.length() > 4:
			compact = compact.substr(0, 4)
		tag_tokens.append("#%s" % _escape_bbcode(compact))

	return "[color=%s]%s[/color]" % [HOVER_TAG_COLOR, " ".join(tag_tokens)]


func _escape_bbcode(value: String) -> String:
	return value.replace("[", "\\[").replace("]", "\\]")


func _humanize_token(value: String) -> String:
	if value.is_empty():
		return value

	var words: Array[String] = []
	for part in value.split("_"):
		if part.is_empty():
			continue
		words.append(part.capitalize())
	return " ".join(words)





func _build_slot_cards(hover_slot: int, hover_card: Card) -> Array[String]:
	var cards: Array[String] = ["", "", ""]
	for i in range(3):
		if slot_filled[i]:
			var pile_cards = slot_piles[i].get_top_cards(1)
			if pile_cards.size() > 0:
				var slot_card: Card = pile_cards[0]
				cards[i] = slot_card.card_name
		elif i == hover_slot and hover_card != null:
			cards[i] = hover_card.card_name
	return cards


func _build_slot_texts() -> Array[String]:
	var texts: Array[String] = ["", "", ""]
	for i in range(3):
		texts[i] = slot_readings[i]
	return texts


func _build_reading_request_state(slot_cards: Array[String], slot_texts: Array[String]) -> Dictionary:
	var full_game_state: Dictionary = game_state.duplicate(true)
	var encounter_index := maxi(current_encounter_index - 1, 0)
	var encounters: Array = full_game_state.get("encounters", [])
	if encounter_index < encounters.size() and encounters[encounter_index] is Dictionary:
		var encounter_state: Dictionary = encounters[encounter_index]
		var encounter_slots: Array = encounter_state.get("slots", [])
		for i in range(mini(3, encounter_slots.size())):
			var runtime_card := ""
			if i < slot_cards.size():
				runtime_card = slot_cards[i]

			var runtime_text := ""
			if i < slot_texts.size():
				runtime_text = slot_texts[i]

			var card_value := ""
			if not runtime_card.is_empty():
				card_value = runtime_card

			var slot_state := {
				"card": card_value,
				"text": runtime_text,
			}
			encounter_slots[i] = slot_state

		encounter_state["slots"] = encounter_slots
		encounters[encounter_index] = encounter_state
		full_game_state["encounters"] = encounters

	return {
		"game_state": full_game_state,
		"active_encounter_index": encounter_index,
		"runtime_state": {
			"slot_cards": slot_cards.duplicate(true),
			"slot_texts": slot_texts.duplicate(true),
		},
	}


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
		if _hover_info_showing:
			_hover_info_showing = false
			if _hover_info_tween != null and _hover_info_tween.is_running():
				_hover_info_tween.kill()
		card_hover_info_panel.visible = false
		card_hover_info_panel.modulate = Color(1, 1, 1, 1)
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

	_update_card_hover_info_panel()
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

	var slot_cards: Array[String] = _build_slot_cards(new_hover_slot, held_card)
	var slot_texts: Array[String] = _build_slot_texts()
	var request_state := _build_reading_request_state(slot_cards, slot_texts)

	claude_api.generate_reading(
		request_id,
		request_state
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
	_hover_info_showing = false
	if _hover_info_tween != null and _hover_info_tween.is_running():
		_hover_info_tween.kill()
	card_hover_info_panel.visible = false
	card_hover_info_panel.modulate = Color(1, 1, 1, 1)

	player_hand.clear_cards()
	for pile in slot_piles:
		pile.clear_cards()
	card_manager.reset_history()
	Card.holding_card_count = 0
	Card.hovering_card_count = 0
