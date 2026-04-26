extends Node2D

@export var CARD_WIDTH = 140.0 # Reduced this to bunch them up more by default
@export var MAX_HAND_WIDTH = 220.0 
@export var MOVE_SPEED = 0.4
@export var CARD_SCALE: float = 1.2
@export var is_enemy: bool = false

var passives_list = []
var hand_tweens = {}

func add_to_passive_hand(passive_node):
	if passive_node not in passives_list:
		# Force the scale immediately so it doesn't start at Vector2(0,0) or (1,1)
		passive_node.scale = Vector2(CARD_SCALE, CARD_SCALE)
		passives_list.append(passive_node)
		update_passive_positions()

func update_passive_positions():
	var count = passives_list.size()
	if count == 0: return

	# 1. Dynamic Spacing Logic
	var spacing = CARD_WIDTH
	
	# Check if the hand is getting too long
	if (count * CARD_WIDTH) > MAX_HAND_WIDTH:
		# Calculate tighter spacing to fit the limit
		spacing = MAX_HAND_WIDTH / (count if count > 0 else 1)

	# 2. Rotation Logic
	var fixed_rot_deg = 2.6 if is_enemy else -2.6
	var final_rotation = deg_to_rad(fixed_rot_deg)

	for i in range(count):
		var card = passives_list[i]
		
		# 3. Z-Index Logic (Left-most is highest)
		card.original_z_index = 15 - i
		if not ("hovering" in card and card.hovering):
			card.z_index = card.original_z_index

		# 4. FIXED LEFT POSITIONING
		# We removed the centering math. 
		# Card 0 will always be at 0. Card 1 at 1*spacing, etc.
		var x_pos = i * spacing
		var y_pos = 0.0 
		
		card.hand_position = Vector2(x_pos, y_pos)
		animate_passive(card, card.hand_position, final_rotation)

func animate_passive(card, target_pos, target_rot):
	if hand_tweens.has(card):
		if is_instance_valid(hand_tweens[card]): 
			hand_tweens[card].kill()
	
	var tween = get_tree().create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Explicitly ensure we are tweening to the desired scale
	tween.tween_property(card, "scale", Vector2(CARD_SCALE, CARD_SCALE), MOVE_SPEED)
	tween.tween_property(card, "position", target_pos, MOVE_SPEED)
	tween.tween_property(card, "rotation", target_rot, MOVE_SPEED)
	
	hand_tweens[card] = tween
