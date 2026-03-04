extends Node2D

@onready var dialog_player : DialogPlayer = $DialogPlayer

func _ready() -> void:
	dialog_player.start()

func _on_enter_level_button_pressed() -> void:
	print("changing to main scene")
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_edit_deck_button_pressed() -> void:
	pass # Replace with function body.
