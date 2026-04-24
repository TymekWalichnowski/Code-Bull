extends Node2D

@onready var dialog_player : DialogPlayer = $DialogPlayer

func _ready() -> void:
	#dialog_player.start()
	pass

func _on_enter_level_button_pressed() -> void:
	print("changing to main scene")
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_edit_deck_button_pressed() -> void:
	$DeckEditor.display_deck()


func _on_tutorial_button_pressed() -> void:
	print("changing to tutorial scene")
	get_tree().change_scene_to_file("res://scenes/main_tutorial.tscn")
