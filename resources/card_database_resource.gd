extends Resource
class_name CardDatabase

@export var cards: Array[CardDataResource] = []

var _by_name := {}
var _by_id := {}

func _ready():
	_initialize_database()

func _initialize_database():
	_by_name.clear()
	_by_id.clear()
	for card in cards:
		_by_name[card.display_name] = card
		_by_id[card.id] = card

func get_by_name(name: String) -> CardDataResource:
	if _by_name.has(name):
		return _by_name[name]
	push_warning("CardDatabase: card not found: " + name)
	return null

func get_by_id(id: int) -> CardDataResource:
	return _by_id.get(id)
