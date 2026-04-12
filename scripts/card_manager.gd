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
var source_slot

func _ready() -> void:
	screen_size = get_viewport_rect().size
	player_hand_reference = %PlayerHand
	%InputManager.connect("left_mouse_button_released", on_left_click_released)

func _process(_delta: float) -> void:
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		card_being_dragged.position = Vector2(clamp(mouse_pos.x, 0, screen_size.x), 
											  clamp(mouse_pos.y, 0, screen_size.y))

func start_drag(card):
	card_being_dragged = card
	card_being_dragged.is_dragged = true # Lock card physics
	source_slot = card.cards_current_slot 
	
	var tween = get_tree().create_tween()
	tween.tween_property(card, "rotation", 0.0, 0.05)
	
	card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)
	card.z_index = 200 
	
	if source_slot:
		source_slot.remove_card()
	else:
		player_hand_reference.remove_card_from_hand(card_being_dragged)
		
	card_being_dragged.play_audio("pickup")

func finish_drag():
	if card_being_dragged:
		card_being_dragged.is_dragged = false # Unlock card physics
	
	card_being_dragged.scale = Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE)
	var target_slot = raycast_check_for_card_slot(card_being_dragged)
	
	if target_slot and target_slot.slot_owner == card_being_dragged.card_owner:
		if target_slot.card_in_slot:
			var occupied_card = target_slot.card
			
			if source_slot:
				target_slot.remove_card()
				source_slot.set_card(occupied_card)
				target_slot.set_card(card_being_dragged)
			else:
				target_slot.remove_card()
				player_hand_reference.add_card_to_hand(occupied_card, DEFAULT_CARD_MOVE_SPEED)
				target_slot.set_card(card_being_dragged)
		else:
			target_slot.set_card(card_being_dragged)
		
		card_being_dragged.play_audio("place")
	else:
		player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
	
	card_being_dragged = null
	source_slot = null

func connect_card_signals(card):
	if not card.is_connected("hovered", on_hovered_over_card):
		card.connect("hovered", on_hovered_over_card)
	if not card.is_connected("hovered_off", on_hovered_off_card):
		card.connect("hovered_off", on_hovered_off_card)

func on_left_click_released():
	if card_being_dragged:
		finish_drag()

func on_hovered_over_card(card):
	if not card.interactable or is_hovering_on_card or card_being_dragged != null:
		return
		
	is_hovering_on_card = true
	highlight_card(card, true)

func on_hovered_off_card(card):
	if card_being_dragged != null: 
		return
		
	highlight_card(card, false)
	is_hovering_on_card = false

	var new_card_hovered = raycast_check_for_card()
	if new_card_hovered and (new_card_hovered is Card or new_card_hovered.get_class() == "PassiveCard"):
		var is_slotted = ("cards_current_slot" in new_card_hovered and new_card_hovered.cards_current_slot != null)
		if not is_slotted:
			is_hovering_on_card = true
			highlight_card(new_card_hovered, true)

func highlight_card(card, hovered):
	if not card.interactable:
		return
	
	var is_in_slot = ("cards_current_slot" in card and card.cards_current_slot != null)

	if hovered:
		if not is_in_slot:
			card.scale = Vector2(BIGGER_CARD_SCALE, BIGGER_CARD_SCALE)
	else:
		if is_in_slot:
			card.scale = Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE)
		elif "PassiveCard" in card.get_class():
			card.scale = Vector2(1.0, 1.0)
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
