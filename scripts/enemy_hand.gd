extends Node2D

const CARD_WIDTH = 75 # <-- Reduced from 110 to pack them tighter
const HAND_Y_POSITION = 40
const DEFAULT_CARD_MOVE_SPEED = 0.2
const DEFAULT_CARD_SCALE = 0.8

const MAX_ROTATION_DEGREES = 12.0 
const VERTICAL_ARCH_HEIGHT = 25.0 

var enemy_hand = []
var hand_tweens = {} 

func get_center_x() -> float:
	return get_viewport_rect().size.x / 2.0

func add_card_to_hand(card, speed):
	if card not in enemy_hand:
		var index = get_insert_index(card)
		enemy_hand.insert(index, card)
		card.scale = Vector2(DEFAULT_CARD_SCALE, DEFAULT_CARD_SCALE)
	
	update_hand_positions(speed)

func update_hand_positions(speed):
	var hand_size = enemy_hand.size()
	var center_x = get_center_x()
	
	for i in range(hand_size):
		var card = enemy_hand[i]
		
		card.z_index = -10 + i 

		var ratio = 0.0
		if hand_size > 1:
			ratio = (float(i) / (hand_size - 1) - 0.5) * 2.0
		
		var x_pos = center_x + (i - (hand_size - 1) / 2.0) * min(CARD_WIDTH, 800.0 / max(1, hand_size))
		var y_pos = HAND_Y_POSITION - (VERTICAL_ARCH_HEIGHT * pow(ratio, 2))
		
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
	if card in enemy_hand:
		enemy_hand.erase(card)
		if hand_tweens.has(card):
			if is_instance_valid(hand_tweens[card]):
				hand_tweens[card].kill()
			hand_tweens.erase(card)
		update_hand_positions(DEFAULT_CARD_MOVE_SPEED)

func get_insert_index(card):
	for i in range(enemy_hand.size()):
		if card.card_id > enemy_hand[i].card_id:
			return i
	return enemy_hand.size()
