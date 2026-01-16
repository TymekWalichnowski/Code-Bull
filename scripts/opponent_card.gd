extends Node2D

@export var card_name: String = "Basic"  # Default card type
@export var card_id: int = 0

var card_type
var hand_position
var cards_current_slot: Node2D

const OWNER = "Opponent"

func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)

func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)
