class_name PortraitLoader
extends RefCounted

const CLIENT_PORTRAITS: Dictionary = {
	"Maria the Widow": "res://assets/portraits/MiniVillagerWoman.png",
	"The Stranger": "res://assets/portraits/MiniNobleMan.png",
}

const PORTRAIT_FALLBACKS: Array[String] = [
	"res://assets/portraits/MiniPeasant.png",
	"res://assets/portraits/MiniWorker.png",
	"res://assets/portraits/MiniVillagerMan.png",
	"res://assets/portraits/MiniOldMan.png",
	"res://assets/portraits/MiniOldWoman.png",
	"res://assets/portraits/MiniNobleWoman.png",
	"res://assets/portraits/MiniPrincess.png",
	"res://assets/portraits/MiniQueen.png",
]

const FRAME_SIZE := 32

var _textures: Dictionary = {}


func load_all() -> void:
	var all_paths: Dictionary = {}
	for client_name: String in CLIENT_PORTRAITS:
		all_paths[CLIENT_PORTRAITS[client_name]] = true
	for path: String in PORTRAIT_FALLBACKS:
		all_paths[path] = true

	for path: String in all_paths.keys():
		var sheet: Texture2D = load(path) as Texture2D
		if sheet == null:
			continue
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(0, 0, FRAME_SIZE, FRAME_SIZE)
		_textures[path] = atlas


func get_portrait(client_name: String) -> Texture2D:
	if CLIENT_PORTRAITS.has(client_name):
		var path: String = CLIENT_PORTRAITS[client_name]
		if _textures.has(path):
			return _textures[path]

	var fallback_index: int = client_name.hash() % PORTRAIT_FALLBACKS.size()
	if fallback_index < 0:
		fallback_index += PORTRAIT_FALLBACKS.size()
	var fallback_path: String = PORTRAIT_FALLBACKS[fallback_index]
	if _textures.has(fallback_path):
		return _textures[fallback_path]

	return null
