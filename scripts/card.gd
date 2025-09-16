extends Node2D

signal hovered
signal hovered_off

var hand_position

func _ready() -> void:
	get_parent().connect_card_signals(self) 	# All cards must be child of CardManager or error will occur

func _process(delta: float) -> void:
	pass


func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)


func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)
