extends Node2D

var card_type
var hand_position
var card_id: int = 0
var cards_current_slot: Node2D


func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)

func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)
