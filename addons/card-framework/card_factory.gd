@tool
## Abstract base class for card creation factories.
##
## Defines the interface for creating cards. Concrete implementations
## (e.g. JsonCardFactory) provide specific loading and instantiation logic.
class_name CardFactory
extends Node

var preloaded_cards: Dictionary = {}
var card_size: Vector2


func create_card(card_name: String, target: CardContainer) -> Card:
	return null


func preload_card_data() -> void:
	pass
