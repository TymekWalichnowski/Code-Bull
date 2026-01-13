extends Node2D

signal left_mouse_button_clicked
signal left_mouse_button_released


const COLLISION_MASK_CARD = 1
const COLLISION_MASK_SLOT = 2
const COLLISION_MASK_DECK = 4

var card_manager_reference
var deck_reference

func _ready() -> void:
	card_manager_reference = $"../CardManager"
	deck_reference = $"../PlayerDeck"

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			emit_signal("left_mouse_button_clicked")
			print("left click")
			raycast_at_cursor()
		else:
			emit_signal("left_mouse_button_released")
			print("left click release")

func raycast_at_cursor():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	var results = space_state.intersect_point(parameters)

	for result in results:
		var collider = result.collider
		if collider.collision_mask == COLLISION_MASK_CARD:
			var card_found = collider.get_parent()
			if card_found:
				print("card found")
				card_manager_reference.start_drag(card_found)
			return  # Stop after finding the card

	for result in results:
		var collider = result.collider
		if collider.collision_mask == COLLISION_MASK_DECK:
			deck_reference.draw_card()
			return
