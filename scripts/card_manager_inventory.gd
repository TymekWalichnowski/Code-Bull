extends Node2D

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_CARD_SLOT = 2

const DEFAULT_CARD_MOVE_SPEED = 0.1
const DEFAULT_CARD_SCALE = 1.2
const BIGGER_CARD_SCALE = 1.4
const SMALLER_CARD_SCALE = 1.05

var screen_size
var card_being_dragged
var is_hovering_on_card
var player_hand_reference

# Track editor-specific data
var dragged_card_data = null
var dragged_from_inventory = false

func _ready() -> void:
	screen_size = get_viewport_rect().size
	player_hand_reference = get_node_or_null("%PlayerHand")
	if get_node_or_null("%InputManager"):
		%InputManager.connect("left_mouse_button_released", on_left_click_released)

func _process(_delta: float) -> void:
	if card_being_dragged:
		card_being_dragged.global_position = get_global_mouse_position()

# --- NEW: Specific function for dragging in the Deck Editor ---
func start_drag_editor(card, card_data, is_inventory):
	card_being_dragged = card
	dragged_card_data = card_data
	dragged_from_inventory = is_inventory
	
	var current_global_pos = card.global_position
	if card.get_parent():
		card.get_parent().remove_child(card)
	add_child(card) 
	card.global_position = current_global_pos
	
	card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)
	card.z_index = 100
	card.play_audio("pickup")

# --- Original drag for Battles ---
func start_drag(card):
	card_being_dragged = card
	dragged_card_data = null # Reset this so battle mode ignores it
	
	var current_global_pos = card.global_position
	if card.get_parent():
		card.get_parent().remove_child(card)
	add_child(card) 
	card.global_position = current_global_pos
	
	card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)
	
	if not card.is_preview and not card.is_inventory:
		if player_hand_reference:
			player_hand_reference.remove_card_from_hand(card_being_dragged)
	
	card.play_audio("pickup")

func finish_drag():
	var card = card_being_dragged
	var mouse_pos = get_global_mouse_position()
	
	if card.is_preview or card.is_inventory:
		var over_deck = get_node("%ScrollContainer").get_global_rect().has_point(mouse_pos) if get_node_or_null("%ScrollContainer") else false
		var over_inventory = get_node("%ScrollContainer2").get_global_rect().has_point(mouse_pos) if get_node_or_null("%ScrollContainer2") else false
		
		var target_grid = null
		
		if over_deck and dragged_from_inventory:
			PlayerDeckGlobal.global_player_inventory.erase(dragged_card_data)
			PlayerDeckGlobal.global_player_cards.append(dragged_card_data)
			target_grid = get_node_or_null("%DeckGrid")
		elif over_inventory and not dragged_from_inventory:
			PlayerDeckGlobal.global_player_cards.erase(dragged_card_data)
			PlayerDeckGlobal.global_player_inventory.append(dragged_card_data)
			target_grid = get_node_or_null("%InventoryGrid")

		var editor = get_node_or_null("../../DeckEditor")
		
		if target_grid and editor:
			editor.display_deck()
			
			# Wait for the frame so the new nodes are created
			await get_tree().process_frame
			
			var target_destination = Vector2.ZERO
			var target_node = null
			
			# Find the new slot
			for child in target_grid.get_children():
				if is_instance_valid(child) and child.has_meta("card_data") and child.get_meta("card_data") == dragged_card_data:
					target_node = child
					target_destination = child.global_position + (child.custom_minimum_size / 2)
					# Hide the new one immediately so we can animate into it
					target_node.modulate.a = 0 
					break
			
			if target_node:
				var tween = create_tween().set_parallel(true)
				tween.tween_property(card, "global_position", target_destination, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.2)
				tween.tween_property(card, "rotation", 0, 0.2)
				
				card.play_audio("place")
				await tween.finished
				
				# CRITICAL: Check if the node still exists before touching it!
				# If the user clicked something else or refreshed, it might be gone.
				if is_instance_valid(target_node):
					target_node.modulate.a = 1
			
			card.queue_free()
		else:
			if editor:
				editor.display_deck()
			card.queue_free()
			
		dragged_card_data = null

	else:
		# Battle logic
		pass
		
	card_being_dragged = null

func connect_card_signals(card):
	card.connect("hovered", on_hovered_over_card)
	card.connect("hovered_off", on_hovered_off_card)

func on_left_click_released():
	if card_being_dragged:
		finish_drag()

func on_hovered_over_card(card):
	if card.cards_current_slot:
		return
	if is_hovering_on_card:
		return

	is_hovering_on_card = true
	highlight_card(card, true)

func on_hovered_off_card(card):
	highlight_card(card, false)
	is_hovering_on_card = false

	if card_being_dragged: return

	var new_card_hovered = raycast_check_for_card()
	if new_card_hovered is Card and !new_card_hovered.cards_current_slot:
		is_hovering_on_card = true
		highlight_card(new_card_hovered, true)

func highlight_card(card, hovered):
	if hovered:
		card.scale = Vector2(BIGGER_CARD_SCALE,BIGGER_CARD_SCALE)
	else:
		if card.cards_current_slot:
			card.scale = Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE)
		else:
			card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)

func raycast_check_for_card():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return get_card_with_highest_z_index(result)
	return null

func raycast_check_for_card_slot(card):
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = card.global_position
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD_SLOT
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return result[0].collider.get_parent()
	return null

func get_card_with_highest_z_index(cards):
	var highest_z_card = cards[0].collider.get_parent()
	var highest_z_index = highest_z_card.z_index
	
	for i in range(1, cards.size()):
		var current_card = cards[i].collider.get_parent()
		if current_card.z_index > highest_z_index:
			highest_z_card = current_card
			highest_z_index = current_card.z_index
	return highest_z_card
