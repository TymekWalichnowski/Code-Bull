extends CanvasLayer

@export var card_scene: PackedScene = preload("res://scenes/player_card.tscn")

# Set these to match your card's visual size
const PREVIEW_SIZE = Vector2(200, 280) 

func display_deck(card_resources: Array[CardDataResource], graveyard_resources: Array[CardDataResource]):
	
	# DECK
	
	# 1. Clear previous cards
	for child in %DeckGrid.get_children():
		child.queue_free()
	
	# 2. Create a copy so we don't mess up the actual draw order
	var display_list = card_resources.duplicate()
	
	# 3. Sort alphabetically by the card's display_name
	display_list.sort_custom(func(a, b): return a.display_name < b.display_name)
	
	# 4. Instance the visuals
	for card_data in display_list:
		if card_data:
			var wrapper = Control.new()
			wrapper.custom_minimum_size = PREVIEW_SIZE

			# IMPORTANT: This allows your Raycasts/Clicks to pass through the wrapper
			wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE 

			%DeckGrid.add_child(wrapper)

			# Instance the actual card and child it to the wrapper
			var new_card = card_scene.instantiate() as Card
			new_card.is_preview = true 
			wrapper.add_child(new_card)

			# Center the Node2D card inside the Control wrapper
			new_card.position = PREVIEW_SIZE / 2
			new_card.setup(card_data, "Player")
	
	# GRAVEYARD
	# 1. Clear previous cards
	for child in %GraveyardGrid.get_children():
		child.queue_free()
	
	# 2. Create a copy so we don't mess up the actual draw order
	var display_list2 = graveyard_resources.duplicate()
	
	# 3. Sort alphabetically by the card's display_name
	display_list2.sort_custom(func(a, b): return a.display_name < b.display_name)
	
	# 4. Instance the visuals
	for card_data in display_list2:
		if card_data:
			var wrapper = Control.new()
			wrapper.custom_minimum_size = PREVIEW_SIZE

			# IMPORTANT: This allows your Raycasts/Clicks to pass through the wrapper
			wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE 

			%GraveyardGrid.add_child(wrapper)

			# Instance the actual card and child it to the wrapper
			var new_card = card_scene.instantiate() as Card
			new_card.is_preview = true 
			wrapper.add_child(new_card)

			# Center the Node2D card inside the Control wrapper
			new_card.position = PREVIEW_SIZE / 2
			new_card.setup(card_data, "Player")
			new_card.visible = true
	show()

func _input(event):
	# Close viewer on ESC or right click
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT):
		hide_deck()

func hide_deck():
	hide()


func _on_close_button_pressed() -> void:
	hide_deck()
