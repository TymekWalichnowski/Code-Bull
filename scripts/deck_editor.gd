extends CanvasLayer

@export var card_scene: PackedScene = preload("res://scenes/card.tscn")
const PREVIEW_SIZE = Vector2(200, 280)

func _ready():
	# Removed the broken signal connection from here.
	pass

func display_deck():
	# Use the real global data directly
	var deck_data = PlayerDeckGlobal.global_player_cards
	var inventory_data = PlayerDeckGlobal.global_player_inventory 
	
	_populate_grid(%DeckGrid, deck_data, false)
	_populate_grid(%InventoryGrid, inventory_data, true)
	show()

func _populate_grid(grid: GridContainer, data_array: Array, is_inventory: bool):
	for child in grid.get_children():
		child.queue_free()
	
	# Sort for a clean look
	data_array.sort_custom(func(a, b): return a.display_name < b.display_name)
	
	for card_data in data_array:
		var wrapper = Control.new()
		wrapper.custom_minimum_size = PREVIEW_SIZE
		wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
		wrapper.set_meta("card_data", card_data)
		wrapper.set_meta("from_inventory", is_inventory) 
		grid.add_child(wrapper)

		var new_card = card_scene.instantiate() as Card
		new_card.is_preview = !is_inventory
		new_card.is_inventory = is_inventory
		wrapper.add_child(new_card)
		new_card.position = PREVIEW_SIZE / 2
		new_card.setup(card_data, "Player")

		%CardManagerInventory.connect_card_signals(new_card)

		wrapper.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				# Call a specific editor drag function on the manager
				%CardManagerInventory.start_drag_editor(new_card, card_data, is_inventory)
		)

func _input(event):
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT):
		hide_deck()

func hide_deck():
	hide()

func _on_close_button_pressed() -> void:
	hide_deck()
