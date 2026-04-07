extends CanvasLayer

@export var card_scene: PackedScene = preload("res://scenes/card.tscn")
@export var passive_scene: PackedScene = preload("res://scenes/passive_card.tscn")
const PREVIEW_SIZE = Vector2(200, 280)

var dragged_data: Resource = null
var dragged_from: String = "" # "deck", "inventory", "deck_passive", "inventory_passive"
var drag_visual: Node2D = null

@onready var scroll_deck = $ScrollContainerDeck
@onready var scroll_inventory = $ScrollContainerInventory
@onready var scroll_passives = $ScrollContainerPassives
@onready var scroll_passives_inventory = $ScrollContainerPassivesInventory

func _ready():
	set_process_input(true)

func display_deck():
	# Cards
	var deck_data = PlayerDeckGlobal.global_player_cards
	var inventory_data = PlayerDeckGlobal.global_player_inventory 
	_populate_grid(scroll_deck, deck_data, "deck", false)
	_populate_grid(scroll_inventory, inventory_data, "inventory", false)
	
	# Passives (if nodes exist)
	if scroll_passives and scroll_passives_inventory:
		var passive_deck = PlayerDeckGlobal.global_player_passives
		var passive_inv = PlayerDeckGlobal.global_player_inventory_passives
		_populate_grid(scroll_passives, passive_deck, "deck_passive", true)
		_populate_grid(scroll_passives_inventory, passive_inv, "inventory_passive", true)
		
	show()

func _get_or_create_grid(scroll: ScrollContainer) -> GridContainer:
	for child in scroll.get_children():
		if child is GridContainer:
			return child
	var new_grid = GridContainer.new()
	new_grid.columns = 4 # Adjust if needed
	scroll.add_child(new_grid)
	return new_grid

func _populate_grid(scroll: ScrollContainer, data_array: Array, source_id: String, is_passive: bool):
	if not scroll: return
	var grid = _get_or_create_grid(scroll)
	
	for child in grid.get_children():
		child.queue_free()
	
	if is_passive:
		data_array.sort_custom(func(a, b): return a.card_name < b.card_name)
	else:
		data_array.sort_custom(func(a, b): return a.display_name < b.display_name)
	
	for data in data_array:
		var wrapper = Control.new()
		wrapper.custom_minimum_size = PREVIEW_SIZE
		wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(wrapper)

		var new_card: Node2D
		if is_passive:
			new_card = passive_scene.instantiate() as PassiveCard
			new_card.is_preview = (source_id == "deck_passive")
			new_card.is_inventory = (source_id == "inventory_passive")
			wrapper.add_child(new_card)
			new_card.setup(data)
		else:
			new_card = card_scene.instantiate() as Card
			new_card.is_preview = (source_id == "deck")
			new_card.is_inventory = (source_id == "inventory")
			wrapper.add_child(new_card)
			new_card.setup(data, "Player")

		new_card.position = PREVIEW_SIZE / 2
		
		# Disable Area2D so it doesn't fight the base game physics!
		if new_card.has_node("Area2D"):
			new_card.get_node("Area2D").monitoring = false
			new_card.get_node("Area2D").monitorable = false

		# Route Control hover signals into the Card's native hover functions
		wrapper.mouse_entered.connect(func():
			new_card.hovering = true
			new_card.update_hover_ui()
		)
		wrapper.mouse_exited.connect(func():
			new_card.hovering = false
			if "tag_container" in new_card and new_card.tag_container: 
				new_card.tag_container.visible = false
			new_card.update_hover_ui()
		)

		wrapper.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				start_drag(data, source_id, is_passive)
		)

func start_drag(data: Resource, source_id: String, is_passive: bool):
	dragged_data = data
	dragged_from = source_id
	
	# Create a floating visual clone
	if is_passive:
		drag_visual = passive_scene.instantiate() as PassiveCard
	else:
		drag_visual = card_scene.instantiate() as Card
		
	add_child(drag_visual)
	if is_passive:
		drag_visual.setup(data)
	else:
		drag_visual.setup(data, "Player")
		
	drag_visual.global_position = get_viewport().get_mouse_position()
	drag_visual.z_index = 4000
	drag_visual.scale = Vector2(1.2, 1.2)

func _process(_delta):
	if drag_visual:
		drag_visual.global_position = get_viewport().get_mouse_position()

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragged_data != null:
			finish_drag()
			
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT):
		if dragged_data != null:
			cancel_drag()
		else:
			hide_deck()

func finish_drag():
	var target_area = ""
	
	if _is_mouse_in_control(scroll_deck): target_area = "deck"
	elif _is_mouse_in_control(scroll_inventory): target_area = "inventory"
	elif _is_mouse_in_control(scroll_passives): target_area = "deck_passive"
	elif _is_mouse_in_control(scroll_passives_inventory): target_area = "inventory_passive"

	# Swap if dropped in a valid new container of the same type (card vs passive)
	if target_area != "" and target_area != dragged_from:
		var is_card_swap = ("passive" not in dragged_from and "passive" not in target_area)
		var is_passive_swap = ("passive" in dragged_from and "passive" in target_area)
		
		if is_card_swap or is_passive_swap:
			_transfer_data(dragged_data, dragged_from, target_area)

	cancel_drag()
	display_deck()

func cancel_drag():
	dragged_data = null
	dragged_from = ""
	if drag_visual:
		drag_visual.queue_free()
		drag_visual = null

func _is_mouse_in_control(control: Control) -> bool:
	if not control or not control.is_visible_in_tree():
		return false
	return control.get_global_rect().has_point(control.get_global_mouse_position())

func _transfer_data(data, from_id, to_id):
	var from_arr = _get_array_by_id(from_id)
	var to_arr = _get_array_by_id(to_id)
	if from_arr != null and to_arr != null:
		from_arr.erase(data)
		to_arr.append(data)

func _get_array_by_id(id: String) -> Array:
	match id:
		"deck": return PlayerDeckGlobal.global_player_cards
		"inventory": return PlayerDeckGlobal.global_player_inventory
		"deck_passive": return PlayerDeckGlobal.global_player_passives
		"inventory_passive": return PlayerDeckGlobal.global_player_inventory_passives
	return []

func hide_deck():
	hide()

func _on_close_button_pressed() -> void:
	hide_deck()
