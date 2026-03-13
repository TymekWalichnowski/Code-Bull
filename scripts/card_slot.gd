extends Node2D

@export_enum("Player", "Opponent") var slot_owner: String = "Player"

var card_in_slot = false
var card: Node2D = null

func _ready() -> void:
	pass
	
func _process(delta: float) -> void:
	pass
