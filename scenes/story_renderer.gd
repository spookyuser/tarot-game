class_name StoryRenderer
extends Node

var story_text: RichTextLabel

const SLOT_COLORS: Array[String] = [
	"#e0b8c8",
	"#b8e0c8",
	"#b8c8e0",
]

const HOVER_COLORS: Array[String] = [
	"#a07888",
	"#78a088",
	"#7888a0",
]


func render(slot_filled: Array[bool], slot_readings: Array[String], active_slot: int, hover_slot: int, hover_text: String) -> void:
	var lines: Array[String] = []
	for i: int in range(3):
		if slot_filled[i]:
			lines.append("[color=%s]%s[/color]" % [SLOT_COLORS[i], slot_readings[i]])
		elif i == hover_slot and hover_text != "":
			lines.append("[color=%s][i][wave amp=20.0 freq=5.0]%s[/wave][/i][/color]" % [HOVER_COLORS[i], hover_text])
		elif i <= active_slot:
			lines.append("[color=#4a3a60]...[/color]")
	story_text.text = "\n\n".join(lines)


static func humanize_token(value: String) -> String:
	if value.is_empty():
		return value
	var words: Array[String] = []
	for part: String in value.split("_"):
		if part.is_empty():
			continue
		words.append(part.capitalize())
	return " ".join(words)
