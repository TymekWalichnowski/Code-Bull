extends Node2D

@onready var dialog_player : DialogPlayer = $DialogPlayer
@export var main_battle_scene: PackedScene

func _ready() -> void:
	#dialog_player.start()
	pass

func _on_enter_level_button_pressed() -> void:
	enter_level(preload("res://objects/enemies/wizard2.tres"))

func _on_edit_deck_button_pressed() -> void:
	$DeckEditor.display_deck()


func _on_tutorial_button_pressed() -> void:
	print("changing to tutorial scene")
	get_tree().change_scene_to_file("res://scenes/main_tutorial.tscn")

func enter_level(selected_enemy: EnemyResource):
	# 1. Instantiate the scene
	var battle_instance = main_battle_scene.instantiate()
	
	# 2. Find the BattleManager inside that scene and "Push" the data
	# Adjust the path to where your BattleManager lives in main.tscn
	var manager = battle_instance.get_node("%BattleManager") 
	manager.enemy_data = selected_enemy
	
	# 3. Add to the root and remove the level select
	get_tree().root.add_child(battle_instance)
	get_tree().current_scene = battle_instance # Tells Godot this is the new main scene
	self.queue_free() # Remove level select from memory
