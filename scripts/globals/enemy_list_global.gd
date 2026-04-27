extends Node

# Dictionary using unique keys for each enemy
var enemy_data: Dictionary = {
	"wizard_1": {
		"enemy_name": "First Wizard",
		"health": 15,
		"deck": ["res://resources/cards/slime_hit.tres"],
		"passives": [],
		"sprite": "res://assets/sprites/slime.png",
		"rewards": ["res://resources/cards/strike_plus.tres"],
		"defeated": false
	},
	"wizard_2": {
		"enemy_name": "Second Wizard",
		"health": 25,
		"deck": ["res://resources/cards/goblin_stab.tres"],
		"passives": ["res://resources/passives/dodge.tres"],
		"sprite": "res://assets/sprites/goblin.png",
		"rewards": ["res://resources/cards/big_shield.tres"],
		"defeated": false
	},
	"wizard_3": {
		"enemy_name": "Third Wizard",
		"health": 35,
		"deck": ["res://resources/cards/goblin_stab.tres"],
		"passives": ["res://resources/passives/dodge.tres"],
		"sprite": "res://assets/sprites/goblin.png",
		"rewards": ["res://resources/cards/big_shield.tres"],
		"defeated": false
	}
}

var current_enemy_id: String = "slime_forest" # Set this when clicking level select buttons

func mark_current_as_defeated():
	if enemy_data.has(current_enemy_id):
		enemy_data[current_enemy_id].defeated = true

func get_current_enemy():
	return enemy_data.get(current_enemy_id, {})
