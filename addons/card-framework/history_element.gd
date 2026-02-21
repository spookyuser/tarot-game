## History tracking element for card movement operations with precise undo support.
##
## Stores source container, destination, moved cards, and original indices to
## enable accurate undo restoration via CardManager.undo().
class_name HistoryElement
extends Object

var from: CardContainer
var to: CardContainer
var cards: Array[Card] = []
var from_indices: Array[int] = []


func get_string() -> String:
	var from_str: String = from.get_string() if from != null else "null"
	var to_str: String = to.get_string() if to != null else "null"

	var card_strings: Array[String] = []
	for c: Card in cards:
		card_strings.append(c.get_string())

	var cards_str: String = ", ".join(card_strings)
	var indices_str: String = str(from_indices) if not from_indices.is_empty() else "[]"
	return "from: [%s], to: [%s], cards: [%s], indices: %s" % [from_str, to_str, cards_str, indices_str]
