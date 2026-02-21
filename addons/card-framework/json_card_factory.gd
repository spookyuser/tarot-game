@tool
## JSON-based card factory implementation with asset management and caching.
##
## Loads card definitions from JSON files and corresponding PNG assets.
## Preloads all cards during initialization for zero-I/O card creation at runtime.
##
## File structure:
##   card_info_dir/  → ace_spades.json, king_hearts.json, ...
##   card_asset_dir/ → ace_spades.png,  king_hearts.png,  ...
##
## JSON schema: {"name": "ace_spades", "front_image": "ace_spades.png", "suit": "spades", "value": "ace"}
class_name JsonCardFactory
extends CardFactory

@export_group("card_scenes")
@export var default_card_scene: PackedScene

@export_group("asset_paths")
@export var card_asset_dir: String
@export var card_info_dir: String

@export_group("default_textures")
@export var back_image: Texture2D


func _ready() -> void:
	if default_card_scene == null:
		push_error("default_card_scene is not assigned!")
		return

	var temp_instance: Node = default_card_scene.instantiate()
	if not (temp_instance is Card):
		push_error("Invalid node type! default_card_scene must reference a Card.")
		default_card_scene = null
	temp_instance.queue_free()


func create_card(card_name: String, target: CardContainer) -> Card:
	if preloaded_cards.has(card_name):
		var card_info: Dictionary = preloaded_cards[card_name]["info"]
		var front_image: Texture2D = preloaded_cards[card_name]["texture"]
		var reversed_image: Texture2D = preloaded_cards[card_name].get("reversed_texture")
		return _create_card_node(card_info.name, front_image, target, card_info, reversed_image)

	var card_info: Dictionary = _load_card_info(card_name)
	if card_info.is_empty():
		push_error("Card info not found for card: %s" % card_name)
		return null

	if not card_info.has("front_image"):
		push_error("Card info does not contain 'front_image' key for card: %s" % card_name)
		return null

	var front_image_path: String = card_asset_dir + "/" + card_info["front_image"]
	var front_image: Texture2D = _load_image(front_image_path)
	if front_image == null:
		push_error("Card image not found: %s" % front_image_path)
		return null

	var reversed_image: Texture2D = _create_reversed_texture(front_image)
	return _create_card_node(card_info.name, front_image, target, card_info, reversed_image)


func preload_card_data() -> void:
	var dir: DirAccess = DirAccess.open(card_info_dir)
	if dir == null:
		push_error("Failed to open directory: %s" % card_info_dir)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not file_name.ends_with(".json"):
			file_name = dir.get_next()
			continue

		var card_name: String = file_name.get_basename()
		var card_info: Dictionary = _load_card_info(card_name)
		if card_info.is_empty():
			push_error("Failed to load card info for %s" % card_name)
			file_name = dir.get_next()
			continue

		var front_image_path: String = card_asset_dir + "/" + card_info.get("front_image", "")
		var front_image_texture: Texture2D = _load_image(front_image_path)
		if front_image_texture == null:
			push_error("Failed to load card image: %s" % front_image_path)
			file_name = dir.get_next()
			continue

		var reversed_texture: Texture2D = _create_reversed_texture(front_image_texture)
		preloaded_cards[card_name] = {
			"info": card_info,
			"texture": front_image_texture,
			"reversed_texture": reversed_texture
		}

		file_name = dir.get_next()


func _load_card_info(card_name: String) -> Dictionary:
	var json_path: String = card_info_dir + "/" + card_name + ".json"
	if not FileAccess.file_exists(json_path):
		return {}

	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_error("Failed to parse JSON: %s" % json_path)
		return {}

	return json.data


func _load_image(image_path: String) -> Texture2D:
	var texture: Texture2D = load(image_path) as Texture2D
	if texture == null:
		push_error("Failed to load image resource: %s" % image_path)
		return null
	return texture


func _create_card_node(card_name: String, front_image: Texture2D, target: CardContainer, card_info: Dictionary, reversed_image: Texture2D = null) -> Card:
	var card: Card = _generate_card(card_info)

	if not target._card_can_be_added([card]):
		print("[JsonCardFactory] Card cannot be added to container: %s" % card_name)
		card.queue_free()
		return null

	card.card_info = card_info
	card.card_size = card_size

	var cards_node: Control = target.get_node("Cards")
	cards_node.add_child(card)
	target.add_card(card)

	card.card_name = card_name
	card.reversed_front_image = reversed_image
	card.set_faces(front_image, back_image)

	return card


func _generate_card(_card_info: Dictionary) -> Card:
	if default_card_scene == null:
		push_error("default_card_scene is not assigned!")
		return null
	return default_card_scene.instantiate()


func _create_reversed_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var img: Image = source.get_image()
	if img == null:
		return null
	img = img.duplicate()
	img.flip_x()
	img.flip_y()
	return ImageTexture.create_from_image(img)
