class_name Sidebar
extends Control

signal restart_requested

@onready var portrait_frame: TextureRect = $PortraitFrame
@onready var client_name_label: Label = $ClientNameLeft
@onready var client_counter_label: Label = $ClientCounterLeft
@onready var deck_count_label: Label = $DeckCountLabel
@onready var progress_icons: Array[TextureRect] = [
	$ProgressIcon0, $ProgressIcon1, $ProgressIcon2
]
@onready var restart_button: Button = $RestartButton


func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())


func update_client(client_name: String, client_number: int, portrait: Texture2D) -> void:
	client_name_label.text = client_name
	client_counter_label.text = "Client #%d" % client_number
	portrait_frame.texture = portrait


func update_deck_count(remaining: int) -> void:
	deck_count_label.text = "%d remaining" % remaining


func update_progress(slot_filled: Array[bool]) -> void:
	for i: int in range(3):
		if slot_filled[i]:
			progress_icons[i].modulate = Color(0.85, 0.7, 0.4, 1.0)
		else:
			progress_icons[i].modulate = Color(0.3, 0.25, 0.4, 0.5)
