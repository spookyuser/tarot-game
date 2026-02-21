extends Node

@export var ambient_stream: AudioStream
@export var shuffle_stream: AudioStream
@export var card_drop_stream: AudioStream
@export var reading_cups_stream: AudioStream
@export var reading_swords_stream: AudioStream
@export var reading_wands_stream: AudioStream
@export var reading_gold_stream: AudioStream
@export var reading_major_stream: AudioStream

@onready var ambient_player: AudioStreamPlayer = $AmbientPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer
@onready var reading_player: AudioStreamPlayer = $ReadingPlayer

const MIX_RATE := 22050
const AMBIENT_FREQ := 80.0
const SHUFFLE_FREQ := 300.0
const CARD_DROP_FREQ := 200.0

const READING_FREQS: Dictionary = {
	"cups": 440.0,
	"swords": 520.0,
	"wands": 392.0,
	"gold": 349.0,
	"major": 587.0,
}

var _generated_ambient: AudioStreamWAV
var _generated_shuffle: AudioStreamWAV
var _generated_card_drop: AudioStreamWAV
var _generated_readings: Dictionary = {}


func _ready() -> void:
	_generated_ambient = _generate_tone(AMBIENT_FREQ, 4.0, -18.0)
	_generated_ambient.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_generated_ambient.loop_begin = 0
	_generated_ambient.loop_end = MIX_RATE * 4

	_generated_shuffle = _generate_tone(SHUFFLE_FREQ, 0.3, -10.0)
	_generated_card_drop = _generate_tone(CARD_DROP_FREQ, 0.2, -10.0)

	for suit: String in READING_FREQS:
		var tone: AudioStreamWAV = _generate_tone(READING_FREQS[suit], 2.0, -14.0)
		tone.loop_mode = AudioStreamWAV.LOOP_FORWARD
		tone.loop_begin = 0
		tone.loop_end = MIX_RATE * 2
		_generated_readings[suit] = tone

	_set_loop(ambient_stream, true)
	_set_loop(reading_cups_stream, true)
	_set_loop(reading_swords_stream, true)
	_set_loop(reading_wands_stream, true)
	_set_loop(reading_gold_stream, true)
	_set_loop(reading_major_stream, true)


func play_ambient() -> void:
	ambient_player.stream = ambient_stream if ambient_stream != null else _generated_ambient
	ambient_player.play()


func stop_ambient() -> void:
	ambient_player.stop()


func play_shuffle() -> void:
	sfx_player.stream = shuffle_stream if shuffle_stream != null else _generated_shuffle
	sfx_player.play()


func play_card_drop() -> void:
	sfx_player.stream = card_drop_stream if card_drop_stream != null else _generated_card_drop
	sfx_player.play()


func play_reading(suit: String) -> void:
	var key: String = suit.to_lower()
	if not READING_FREQS.has(key):
		key = "major"

	var override_map: Dictionary = {
		"cups": reading_cups_stream,
		"swords": reading_swords_stream,
		"wands": reading_wands_stream,
		"gold": reading_gold_stream,
		"major": reading_major_stream,
	}

	var override: AudioStream = override_map.get(key)
	reading_player.stream = override if override != null else _generated_readings[key]

	if not reading_player.playing:
		reading_player.play()
		var length: float = reading_player.stream.get_length()
		if length > 0.0:
			reading_player.seek(length * 0.5)


func stop_reading() -> void:
	reading_player.stop()


func _set_loop(stream: AudioStream, enabled: bool) -> void:
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = enabled
	elif stream is AudioStreamOggVorbis:
		stream.loop = enabled
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED


func _generate_tone(frequency: float, duration: float, volume_db: float) -> AudioStreamWAV:
	var sample_count: int = int(MIX_RATE * duration)
	var amplitude: int = int(32767.0 * db_to_linear(volume_db))
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var sample_f: float = sin(TAU * frequency * t)
		var sample_i: int = clampi(int(sample_f * amplitude), -32768, 32767)
		data[i * 2] = sample_i & 0xFF
		data[i * 2 + 1] = (sample_i >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
