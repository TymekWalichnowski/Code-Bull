@icon("res://Assets/icons/32x32/character.png")
extends Node2D

const CARD_WIDTH = 110 # Reduced slightly to keep the "fan" tight
const HAND_Y_POSITION = 950 # Lowered slightly to account for the arch height
const DEFAULT_CARD_MOVE_SPEED = 0.2
const DEFAULT_CARD_SCALE = 1.2

# --- FANNING SETTINGS ---
const MAX_ROTATION_DEGREES = 15.0 # Max tilt for the outer cards
const VERTICAL_ARCH_HEIGHT = 40.0 # How much the center card "pops up"
const HORIZONTAL_BEND = 10.0      # Extra horizontal spacing as the fan spreads

var player_hand = []
var center_screen_x

func _ready() -> void:
	center_screen_x = get_viewport_rect().size.x / 2

func add_card_to_hand(card, speed):
	if card not in player_hand:
		var index = get_insert_index(card)
		player_hand.insert(index, card)
		update_hand_positions(speed)
		card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)
	else:
		update_hand_positions(speed)

func update_hand_positions(speed):
	var hand_size = player_hand.size()
	
	for i in range(hand_size):
		var card = player_hand[i]
		
		# 1. Calculate the normalized index (-1.0 to 1.0)
		# This tells us if the card is on the left (-), center (0), or right (+)
		var ratio = 0.0
		if hand_size > 1:
			ratio = (float(i) / (hand_size - 1) - 0.5) * 2.0
		
		# 2. Calculate X Position
		var x_offset = (hand_size - 1) * CARD_WIDTH
		var x_pos = center_screen_x + (i * CARD_WIDTH) - (x_offset / 2.0)
		
		# 3. Calculate Y Position (The Arch)
		# Uses a parabola: y = height * (1 - x^2)
		var y_offset = VERTICAL_ARCH_HEIGHT * (1.0 - pow(ratio, 2))
		var y_pos = HAND_Y_POSITION - y_offset
		
		# 4. Calculate Rotation
		var target_rotation = deg_to_rad(ratio * MAX_ROTATION_DEGREES)
		
		var new_transform = {
			"position": Vector2(x_pos, y_pos),
			"rotation": target_rotation
		}
		
		card.hand_position = new_transform.position
		animate_card_to_fan(card, new_transform, speed)

func animate_card_to_fan(card, transform, speed):
	var tween = get_tree().create_tween().set_parallel(true)
	# Animate position and rotation at the same time
	tween.tween_property(card, "position", transform.position, speed)
	tween.tween_property(card, "rotation", transform.rotation, speed)

func remove_card_from_hand(card):
	if card in player_hand:
		player_hand.erase(card)
		# Reset rotation when leaving the hand
		var tween = get_tree().create_tween()
		tween.tween_property(card, "rotation", 0.0, DEFAULT_CARD_MOVE_SPEED)
		update_hand_positions(DEFAULT_CARD_MOVE_SPEED)

func get_insert_index(card):
	for i in range(player_hand.size()):
		if card.global_position.x < player_hand[i].global_position.x:
			return i
	return player_hand.size()
