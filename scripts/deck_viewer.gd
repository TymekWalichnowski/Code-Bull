extends CanvasLayer

@export var card_scene: PackedScene = preload("res://scenes/player_card.tscn")
@onready var grid = %CardGrid

func display_deck(card_names: Array, database: CardDatabase):
	# Clear previous cards
	for child in grid.get_children():
		child.queue_free()
	
	# Instance a visual for every card name in the deck
	for c_name in card_names:
		var data = database.get_by_name(c_name)
		if data:
			var new_card = card_scene.instantiate()
			grid.add_child(new_card)
			new_card.setup(data, "Player")
			# Disable any dragging/input logic on these preview cards 
			# so they don't mess with the game board
			new_card.input_pickable = false 
	
	show()

func hide_deck():
	hide()
