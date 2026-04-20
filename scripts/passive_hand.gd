extends Node2D

@export var CARD_WIDTH = 110.0
@export var MAX_ROTATION_DEGREES = 8.0
@export var VERTICAL_ARCH_HEIGHT = 15.0
@export var MOVE_SPEED = 0.4
@export var CARD_SCALE: float = 1.2
@export var is_enemy: bool = false # Toggle this in the Inspector for EnemyPassives

var passives_list = []
var hand_tweens = {}

func add_to_passive_hand(passive_node):
	if passive_node not in passives_list:
		passives_list.append(passive_node)
		# Passives are us ually not interactable for enemy, but visible
		passive_node.interactable = !is_enemy 
		update_passive_positions()

func update_passive_positions():
	var count = passives_list.size()
	var flip = -1.0 if is_enemy else 1.0
	
	for i in range(count):
		var card = passives_list[i]
		card.original_z_index = 50 + i
		card.z_index = card.original_z_index

		var ratio = 0.0
		if count > 1:
			ratio = (float(i) / (count - 1) - 0.5) * 2.0
		
		var x_pos = (i * CARD_WIDTH) - ((count - 1) * CARD_WIDTH / 2.0)
		# Arch goes UP for player, DOWN for enemy
		var y_pos = (VERTICAL_ARCH_HEIGHT * pow(ratio, 2)) * flip
		
		# Rotate 180 degrees (PI) if enemy
		var base_rot = PI if is_enemy else 0.0
		var fan_rot = deg_to_rad(ratio * MAX_ROTATION_DEGREES) * flip
		
		card.hand_position = Vector2(x_pos, y_pos)
		animate_passive(card, card.hand_position, base_rot + fan_rot)

func animate_passive(card, target_pos, target_rot):
	if hand_tweens.has(card):
		if is_instance_valid(hand_tweens[card]): hand_tweens[card].kill()
	
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(CARD_SCALE, CARD_SCALE), MOVE_SPEED)
	tween.tween_property(card, "position", target_pos, MOVE_SPEED)
	tween.tween_property(card, "rotation", target_rot, MOVE_SPEED)
	hand_tweens[card] = tween
