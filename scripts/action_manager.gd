extends Node # not using this at the moment
#
@onready var player = %Player
@onready var opponent = %Opponent
@onready var animation_manager = %AnimationManager
@onready var player_action_anim = %PlayerActionAnim
@onready var opponent_action_anim = %OpponentActionAnim
@onready var player_deck = %PlayerDeck
@onready var opponent_deck = %OpponentDeck


# We need a reference back to BattleManager to update retrigger counts
@onready var battle_manager = get_parent()

@export var flame_token_res: TokenResource # For testing
@export var bleed_token_res: TokenResource # should probably od this more efficiently

func execute_card_action(card: Card, action_index: int):
	var action_data = card.card_data.actions[action_index]
	var action = action_data.action_name
	var value = action_data.value
	
	var target
	var self_target
	if card.card_owner == "Player":
		target = opponent
		self_target = player
	else:
		target = player
		self_target = opponent
	
	# Apply Multipliers
	value = value * self_target.current_mult
	
	if self_target.nullified:
		return

	# Handle the random Or/Divide logic
	if action == "Multiply_Or_Divide":
		if randf() < 0.5:
			await animation_manager.play_anim("Multiply_Or_Divide1", card.card_owner)
			action = "Multiply_Next_Card"
		else:
			await animation_manager.play_anim("Multiply_Or_Divide2", card.card_owner)
			action = "Divide_Next_Card"

	# --- CALCULATE CORRECT INDEX FOR ANIMATION ---
	var slots = battle_manager.player_slots if card.card_owner == "Player" else battle_manager.opponent_slots
	var current_idx = -1
	for i in range(slots.size()):
		if slots[i].card == card:
			current_idx = i
			break

	var anim_target_idx = current_idx
	
	# LOGIC: 
	# If Player targets Self (Multiply), they target the NEXT slot (idx + 1).
	# If Player targets Opponent (Divide), the very next card is the Opponent in the CURRENT slot (idx).
	if action == "Multiply_Next_Card" or action == "Retrigger_Next_Slot":
		anim_target_idx = current_idx + 1
	elif action == "Divide_Next_Card":
		if card.card_owner == "Player":
			anim_target_idx = current_idx # Opponent 1 acts after Player 1
		else:
			anim_target_idx = current_idx + 1 # Player 2 acts after Opponent 1

	# Visuals
	card.get_node("AnimationPlayer").play("card_basic_use")
	card.play_audio("use")
	# Pass our specifically calculated anim_target_idx
	await animation_manager.play_anim(action, card.card_owner, anim_target_idx)
	
	# --- EFFECT APPLICATION ---
	match action:
		"Attack":
			target.take_damage(value)
			var trigger = "On_Damage_Taken_Player" if target == player else "On_Damage_Taken_Opponent"
			await battle_manager.trigger_passives(trigger)
		"Shield":
			self_target.gain_shield(value)
		"Multiply_Next_Card":
			self_target.next_mult *= value
		"Divide_Next_Card":
			# IMPORTANT: If Player 1 wants to affect Opponent 1, 
			# use current_mult because Opponent 1 is about to act in this same slot
			if card.card_owner == "Player":
				target.current_mult /= value
			else:
				target.next_mult /= value
		
		"Nullify":
			target.nullified = true
			
		"Retrigger_Next_Slot":
			_handle_retrigger(card, int(value))
			battle_manager.update_card_effects()
			
		"Apply_Flame":
			if target == player:
				%PlayerTokens.add_token(flame_token_res, value)
			else:
				%OpponentTokens.add_token(flame_token_res, value)
		
		"Apply_Bleed":
			if target == player:
				%PlayerTokens.add_token(bleed_token_res, value)
			else:
				%OpponentTokens.add_token(bleed_token_res, value)
	
	# after effect
	await battle_manager.token_manager.trigger_tokens("After_Action", card.card_owner)

func _handle_retrigger(card: Card, value: int):
	# We find the index from the parent's slot lists
	var slots = battle_manager.player_slots if card.card_owner == "Player" else battle_manager.opponent_slots
	var current_idx = -1
	for i in range(slots.size()):
		if slots[i].card == card:
			current_idx = i
			break
			
	if current_idx != -1 and current_idx + 1 < 3:
		if card.card_owner == "Player":
			battle_manager.player_retrigger_counts[current_idx + 1] += value
		else:
			battle_manager.opponent_retrigger_counts[current_idx + 1] += value
