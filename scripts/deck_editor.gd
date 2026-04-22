extends CanvasLayer

@export var card_scene: PackedScene = preload("res://scenes/card.tscn")
@export var passive_scene: PackedScene = preload("res://scenes/passive_card.tscn")
const PREVIEW_SIZE = Vector2(200, 280)

var dragged_data: Resource = null
var dragged_from: String = ""
var dragged_original_card: Node2D = null # Tracks the card you picked up
var drag_visual: Node2D = null
var is_animating: bool = false # Prevents bugs if you click while a card is flying

@onready var scroll_deck = %ScrollContainerDeck
@onready var scroll_inventory = %ScrollContainerInventory
@onready var scroll_passives = %ScrollContainerPassives
@onready var scroll_passives_inventory = %ScrollContainerPassivesInventory

func _ready():
	set_process_input(true)

func display_deck():
	# Cards
	var deck_data = PlayerDeckGlobal.global_player_cards
	var inventory_data = PlayerDeckGlobal.global_player_inventory 
	_populate_grid(scroll_deck, deck_data, "deck", false)
	_populate_grid(scroll_inventory, inventory_data, "inventory", false)
	
	# Passives
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
	new_grid.columns = 3 # Adjust columns if needed
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
		
		# Store reference to data so we can find it later for the drop animation
		new_card.set_meta("linked_data", data)
		
		if new_card.has_node("Area2D"):
			new_card.get_node("Area2D").monitoring = false
			new_card.get_node("Area2D").monitorable = false
			new_card.get_node("%CardBackImage").visible = false
			new_card.z_index = 1000

		wrapper.mouse_entered.connect(func():
			if is_animating: return
			new_card.hovering = true
			new_card.update_hover_ui()
		)
		wrapper.mouse_exited.connect(func():
			new_card.hovering = false
			new_card.update_hover_ui()
		)

		wrapper.gui_input.connect(func(event):
			if is_animating: return
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				start_drag(data, source_id, is_passive, new_card)
		)

func start_drag(data: Resource, source_id: String, is_passive: bool, original_card: Node2D):
	dragged_data = data
	dragged_from = source_id
	dragged_original_card = original_card
	
	# Hide the real card so it looks like we picked it up, leaving the grid space empty
	original_card.visible = false 
	
	if is_passive:
		drag_visual = passive_scene.instantiate() as PassiveCard
		drag_visual.is_preview = true # SET BEFORE SETUP so front is shown
		drag_visual.is_inventory = true
		add_child(drag_visual)
		drag_visual.setup(data)
	else:
		drag_visual = card_scene.instantiate() as Card
		drag_visual.is_preview = true # SET BEFORE SETUP so front is shown
		drag_visual.is_inventory = true
		add_child(drag_visual)
		drag_visual.setup(data, "Player")
		
	drag_visual.global_position = get_viewport().get_mouse_position()
	drag_visual.z_index = 300
	drag_visual.scale = Vector2(1.2, 1.2)

func _process(_delta):
	# Only follow the mouse if we aren't currently animating it snapping into place
	if drag_visual and not is_animating:
		drag_visual.global_position = get_viewport().get_mouse_position()

func _input(event):
	if is_animating: return
	
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

	var is_valid_swap = false
	if target_area != "" and target_area != dragged_from:
		var is_card_swap = ("passive" not in dragged_from and "passive" not in target_area)
		var is_passive_swap = ("passive" in dragged_from and "passive" in target_area)
		if is_card_swap or is_passive_swap:
			is_valid_swap = true

	if is_valid_swap:
		_transfer_data(dragged_data, dragged_from, target_area)
		display_deck() # This recreates the nodes
		
		# We look for the NEW card created by display_deck()
		var new_card = _find_card_in_grid(target_area, dragged_data)
		if is_instance_valid(new_card):
			_animate_drop(new_card)
		else:
			_cleanup_drag()
	else:
		# If invalid, we try to go back to the original card
		if is_instance_valid(dragged_original_card):
			_animate_drop(dragged_original_card)
		else:
			_cleanup_drag()

func _animate_drop(target_card: Node2D):
	# Safety check 1: Did the nodes survive the transition?
	if not is_instance_valid(drag_visual) or not is_instance_valid(target_card):
		_cleanup_drag()
		return

	is_animating = true
	target_card.visible = false 
	
	# Let the UI engine finish one frame so it knows where the new nodes are positioned
	await get_tree().process_frame 
	
	# Safety check 2: Checking again after the 'await' (timing is everything!)
	if not is_instance_valid(drag_visual) or not is_instance_valid(target_card):
		_cleanup_drag()
		return
	
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Smoothly move to the new slot
	tween.tween_property(drag_visual, "global_position", target_card.global_position, 0.2)
	tween.parallel().tween_property(drag_visual, "scale", Vector2(1.0, 1.0), 0.2)
	
	await tween.finished
	
	# Final reveal
	if is_instance_valid(target_card):
		target_card.visible = true 
		
	_cleanup_drag()

func cancel_drag():
	if is_instance_valid(dragged_original_card):
		_animate_drop(dragged_original_card)
	else:
		_cleanup_drag()

func _cleanup_drag():
	dragged_data = null
	dragged_from = ""
	dragged_original_card = null
	if drag_visual:
		drag_visual.queue_free()
		drag_visual = null
	is_animating = false

func _is_mouse_in_control(control: Control) -> bool:
	if not control or not control.is_visible_in_tree():
		return false
	return control.get_global_rect().has_point(get_viewport().get_mouse_position())

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

func _find_card_in_grid(area_id: String, target_data: Resource) -> Node2D:
	var scroll: ScrollContainer
	match area_id:
		"deck": scroll = scroll_deck
		"inventory": scroll = scroll_inventory
		"deck_passive": scroll = scroll_passives
		"inventory_passive": scroll = scroll_passives_inventory
		
	if not scroll: return null
	var grid = _get_or_create_grid(scroll)
	
	# Search the rebuilt grid for the specific card data
	for wrapper in grid.get_children():
		if wrapper.get_child_count() > 0:
			var card = wrapper.get_child(0)
			if card.has_meta("linked_data") and card.get_meta("linked_data") == target_data:
				return card
	return null

func hide_deck():
	hide()

func _on_close_button_pressed() -> void:
	hide_deck()
