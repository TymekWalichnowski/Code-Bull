extends CanvasLayer

@export var card_scene: PackedScene = preload("res://scenes/player_card.tscn")

# Set these to match your card's visual size
const PREVIEW_SIZE = Vector2(200, 280) 

func display_deck(card_resources: Array[CardDataResource], inventory_resources: Array[CardDataResource]):
	
	# --- DECK GRID ---
	for child in %DeckGrid.get_children():
		child.queue_free()
	
	var display_list = card_resources.duplicate()
	display_list.sort_custom(func(a, b): return a.display_name < b.display_name)
	
	for card_data in display_list:
		if card_data:
			var wrapper = Control.new()
			wrapper.custom_minimum_size = PREVIEW_SIZE
			wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
			
			# Store the data on the wrapper so the CardManager can find this slot
			wrapper.set_meta("card_data", card_data) 
			
			%DeckGrid.add_child(wrapper)

			var new_card = card_scene.instantiate() as Card
			new_card.is_preview = true 
			wrapper.add_child(new_card)

			new_card.position = PREVIEW_SIZE / 2
			new_card.setup(card_data, "Player")

			var card_manager = get_node("%CardManagerInventory")
			card_manager.connect_card_signals(new_card)

			wrapper.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					card_manager.start_drag(new_card)
			)
	
	# --- INVENTORY GRID ---
	for child in %InventoryGrid.get_children():
		child.queue_free()
	
	var display_list2 = inventory_resources.duplicate()
	display_list2.sort_custom(func(a, b): return a.display_name < b.display_name)
	
	for card_data in display_list2:
		if card_data:
			var wrapper = Control.new()
			wrapper.custom_minimum_size = PREVIEW_SIZE
			wrapper.mouse_filter = Control.MOUSE_FILTER_PASS 
			wrapper.set_meta("card_data", card_data)
			%InventoryGrid.add_child(wrapper)

			var new_card = card_scene.instantiate() as Card
			new_card.is_inventory = true 
			wrapper.add_child(new_card)

			new_card.position = PREVIEW_SIZE / 2
			new_card.setup(card_data, "Player")

			var card_manager = get_node("%CardManagerInventory")
			card_manager.connect_card_signals(new_card)

			wrapper.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					card_manager.start_drag(new_card)
			)
	show()

func _input(event):
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT):
		hide_deck()

func hide_deck():
	hide()

func _on_close_button_pressed() -> void:
	hide_deck()
