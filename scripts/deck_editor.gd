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
			# CHANGE THIS: We need the wrapper to catch the click
			wrapper.mouse_filter = Control.MOUSE_FILTER_PASS 

			%DeckGrid.add_child(wrapper)

			var new_card = card_scene.instantiate() as Card
			new_card.is_preview = true 
			wrapper.add_child(new_card)

			# Center and setup
			new_card.position = PREVIEW_SIZE / 2
			new_card.setup(card_data, "Player")

			# 1. MANUALLY connect the signals since the parent is a Control wrapper
			var card_manager = get_node("%CardManagerInventory") # Make sure this path is correct
			card_manager.connect_card_signals(new_card)

			# 2. Connect the wrapper's click to the CardManager
			wrapper.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					card_manager.start_drag(new_card)
			)
	
	# GRAVEYARD
	# 1. Clear previous cards
	for child in %InventoryGrid.get_children():
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

			# FIX 1: Allow clicks on the inventory wrappers
			wrapper.mouse_filter = Control.MOUSE_FILTER_PASS 

			%InventoryGrid.add_child(wrapper)

			var new_card = card_scene.instantiate() as Card
			new_card.is_inventory = true 
			wrapper.add_child(new_card)

			new_card.position = PREVIEW_SIZE / 2
			new_card.setup(card_data, "Player")

			# FIX 2: Connect inventory cards to the manager
			var card_manager = get_node("%CardManagerInventory")
			card_manager.connect_card_signals(new_card)

			wrapper.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					card_manager.start_drag(new_card)
			)
	show()

func _input(event):
	# Close viewer on ESC or right click
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT):
		hide_deck()

func hide_deck():
	hide()


func _on_close_button_pressed() -> void:
	hide_deck()
