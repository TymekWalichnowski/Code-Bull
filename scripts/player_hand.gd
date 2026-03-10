extends Node2D

const CARD_WIDTH = 110 
const HAND_Y_POSITION = 900 
const DEFAULT_CARD_MOVE_SPEED = 0.2
const DEFAULT_CARD_SCALE = 1.2

const MAX_ROTATION_DEGREES = 12.0 
const VERTICAL_ARCH_HEIGHT = 25.0 

var player_hand = []
var center_screen_x
var hand_tweens = {} # Dictionary to store [Card: Tween]

func _ready() -> void:
	center_screen_x = get_viewport_rect().size.x / 2

func add_card_to_hand(card, speed):
	if card not in player_hand:
		var index = get_insert_index(card)
		player_hand.insert(index, card)
		card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)
	
	update_hand_positions(speed)

func update_hand_positions(speed):
	var hand_size = player_hand.size()
	for i in range(hand_size):
		var card = player_hand[i]
		
		card.original_z_index = -5 + i 
		if not card.hovering:
			card.z_index = card.original_z_index

		var ratio = 0.0
		if hand_size > 1:
			ratio = (float(i) / (hand_size - 1) - 0.5) * 2.0
		
		var x_offset = (hand_size - 1) * CARD_WIDTH
		var x_pos = center_screen_x + (i * CARD_WIDTH) - (x_offset / 2.0)
		var y_pos = HAND_Y_POSITION + (VERTICAL_ARCH_HEIGHT * pow(ratio, 2))
		var target_rot = deg_to_rad(ratio * MAX_ROTATION_DEGREES)
		
		card.hand_position = Vector2(x_pos, y_pos)
		animate_card_to_fan(card, card.hand_position, target_rot, speed)

func animate_card_to_fan(card, target_pos, target_rot, speed):
	# ANTI-SPAM: If this card is already moving, stop that movement first
	if hand_tweens.has(card):
		hand_tweens[card].kill()
	
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(card, "position", target_pos, speed)
	tween.tween_property(card, "rotation", target_rot, speed)
	
	# Store the tween so we can kill it if the player clicks again immediately
	hand_tweens[card] = tween

func remove_card_from_hand(card):
	if card in player_hand:
		player_hand.erase(card)
		# Clean up the tween tracking
		if hand_tweens.has(card):
			hand_tweens[card].kill()
			hand_tweens.erase(card)
		update_hand_positions(DEFAULT_CARD_MOVE_SPEED)

func get_insert_index(card):
	# Stable sorting: Use the mouse X position compared to the stable 'hand_position' 
	# of cards already in hand, rather than their currently-moving physics position.
	var mouse_x = get_global_mouse_position().x
	for i in range(player_hand.size()):
		if mouse_x < player_hand[i].hand_position.x:
			return i
	return player_hand.size()
