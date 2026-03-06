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

func _ready() -> void:
	screen_size = get_viewport_rect().size
	player_hand_reference = %PlayerHand
	%InputManager.connect("left_mouse_button_released", on_left_click_released)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if card_being_dragged:
		# FIX 3: Use global_position so it follows the mouse exactly
		card_being_dragged.global_position = get_global_mouse_position()

func start_drag(card):
	card_being_dragged = card
	
	# FIX 4: Reparent the card to the Manager while dragging
	# This pulls it out of the Grid so it can't be "cut off" by scroll containers
	var current_global_pos = card.global_position
	card.get_parent().remove_child(card)
	add_child(card) 
	card.global_position = current_global_pos
	
	card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)
	
	if not card.is_preview and not card.is_inventory:
		player_hand_reference.remove_card_from_hand(card_being_dragged)
	
	card_being_dragged.play_audio("pickup")

func finish_drag():
	card_being_dragged.scale = Vector2(BIGGER_CARD_SCALE,BIGGER_CARD_SCALE)
	var card_slot_found = raycast_check_for_card_slot(card_being_dragged)
	
	if card_slot_found and not card_slot_found.card_in_slot:
		card_being_dragged.scale = Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE)
		card_being_dragged.cards_current_slot = card_slot_found
		#Card dropped in empty card slot
		card_being_dragged.position = card_slot_found.position
		card_slot_found.card_in_slot = true
		card_slot_found.card = card_being_dragged #add card being dragged to the slot
		card_being_dragged.play_audio("place")
	else:
		# FIX 5: If we are in the Deck Editor, we shouldn't just leave it
		# as a child of the CardManager. We should refresh the UI.
		if card_being_dragged.is_preview or card_being_dragged.is_inventory:
			# Here you should call a function to update your Global Arrays
			# For now, let's just put it back where it came from by refreshing the UI:
			get_node("../../DeckEditor").display_deck(PlayerDeckGlobal.global_player_cards, PlayerDeckGlobal.global_player_inventory)
		else:
			player_hand_reference.add_card_to_hand(card_being_dragged, DEFAULT_CARD_MOVE_SPEED)
	
	card_being_dragged = null

func connect_card_signals(card):
	card.connect("hovered", on_hovered_over_card)
	card.connect("hovered_off", on_hovered_off_card)

func on_left_click_released():
	if card_being_dragged:
		finish_drag()

func on_hovered_over_card(card):
	#print("hovered over card")

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
	# Change 'is CardDataResource' to 'is Card' (the class_name of your card.gd)
	if new_card_hovered is Card and !new_card_hovered.cards_current_slot:
		is_hovering_on_card = true
		highlight_card(new_card_hovered, true)

func highlight_card(card, hovered):
	if hovered:
		card.scale = Vector2(BIGGER_CARD_SCALE,BIGGER_CARD_SCALE)
		print(card.cards_current_slot)
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
		# return result[0].collider.get_parent() # Returns the Card You Clicked
		return get_card_with_highest_z_index(result)
	return null # Returns Nothing

func raycast_check_for_card_slot(card):
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = card.global_position
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD_SLOT
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return result[0].collider.get_parent()
	return null # Returns Nothing

func get_card_with_highest_z_index(cards):
	# Assume first card in cards array has highest z index
	var highest_z_card = cards[0].collider.get_parent()
	var highest_z_index = highest_z_card.z_index
	
	# Loop through rest of cards lchecking for card with higher z index
	for i in range(1, cards.size()):
		var current_card = cards[i].collider.get_parent()
		if current_card.z_index > highest_z_index:
			highest_z_card = current_card
			highest_z_index = current_card.z_index
	return highest_z_card
