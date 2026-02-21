class_name DeckManager
extends RefCounted

var all_card_names: Array[String] = []
var deck: Array[String] = []
var discard: Array[String] = []


func build_card_names() -> void:
	var major: Array[String] = [
		"the_fool", "the_magician", "the_high_priestess", "the_empress",
		"the_emperor", "the_hierophant", "the_lovers", "the_chariot",
		"the_strength", "the_hermit", "the_wheel_of_fortune", "the_justice",
		"the_hanged_man", "the_death", "the_temperance", "the_devil",
		"the_tower", "the_stars", "the_moon", "the_sun",
		"the_judgement", "the_world"
	]
	all_card_names.append_array(major)

	var suits: Array[String] = ["cups", "gold", "swords", "wands"]
	var values: Array[String] = [
		"ace", "two", "three", "four", "five", "six", "seven",
		"eight", "nine", "ten", "page", "knight", "queen", "king"
	]
	for suit: String in suits:
		for val: String in values:
			all_card_names.append("%s_of_%s" % [val, suit])


func shuffle(hand_size: int) -> void:
	var pool: Array[String] = all_card_names.duplicate()
	pool.shuffle()
	deck = pool.slice(0, hand_size) as Array[String]
	discard.clear()


func draw(count: int) -> Array[String]:
	var drawn: Array[String] = []
	for i: int in range(mini(count, deck.size())):
		drawn.append(deck.pop_back())
	return drawn
