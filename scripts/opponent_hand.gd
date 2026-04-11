extends Node2D

const CARD_WIDTH = 110 # Reduced to match player feel, adjust as needed
const HAND_Y_POSITION = 30
const DEFAULT_CARD_MOVE_SPEED = 0.2
const DEFAULT_CARD_SCALE = 0.8

const MAX_ROTATION_DEGREES = 12.0 
const VERTICAL_ARCH_HEIGHT = 25.0 

var opponent_hand = []
var hand_tweens = {} # To prevent jumpy animations

func get_center_x() -> float:
	return get_viewport_rect().size.x / 2.0

func add_card_to_hand(card, speed):
	if card not in opponent_hand:
		var index = get_insert_index(card)
		opponent_hand.insert(index, card)
		card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)
	
	update_hand_positions(speed)

func update_hand_positions(speed):
	var hand_size = opponent_hand.size()
	var center_x = get_center_x()
	
	for i in range(hand_size):
		var card = opponent_hand[i]
		
		# Set Z-index so center cards are "on top" or just ordered left-to-right
		card.z_index = -10 + i 

		var ratio = 0.0
		if hand_size > 1:
			# This gives a value from -1.0 (left) to 1.0 (right)
			ratio = (float(i) / (hand_size - 1) - 0.5) * 2.0
		
		var x_offset = (hand_size - 1) * CARD_WIDTH
		var x_pos = center_x + (i * CARD_WIDTH) - (x_offset / 2.0)
		
		# MIRROR LOGIC: 
		# Subtract the arch height so cards move UP toward the screen edge as they fan out
		var y_pos = HAND_Y_POSITION - (VERTICAL_ARCH_HEIGHT * pow(ratio, 2))
		
		# Negate rotation so the "top" of the card fans outward at the top of the screen
		var target_rot = deg_to_rad(ratio * -MAX_ROTATION_DEGREES)
		
		card.hand_position = Vector2(x_pos, y_pos)
		animate_card_to_fan(card, card.hand_position, target_rot, speed)

func animate_card_to_fan(card, target_pos, target_rot, speed):
	if hand_tweens.has(card):
		if is_instance_valid(hand_tweens[card]):
			hand_tweens[card].kill()
	
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(card, "position", target_pos, speed)
	tween.tween_property(card, "rotation", target_rot, speed)
	
	hand_tweens[card] = tween

func remove_card_from_hand(card):
	if card in opponent_hand:
		opponent_hand.erase(card)
		if hand_tweens.has(card):
			if is_instance_valid(hand_tweens[card]):
				hand_tweens[card].kill()
			hand_tweens.erase(card)
		update_hand_positions(DEFAULT_CARD_MOVE_SPEED)

func get_insert_index(card):
	# Maintain the opponent's ID sorting or use position
	for i in range(opponent_hand.size()):
		if card.card_id > opponent_hand[i].card_id:
			return i
	return opponent_hand.size()
