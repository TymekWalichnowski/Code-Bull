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

func execute_card_action(card: Card, action_index: int):
	var action_data = card.card_data.actions[action_index]
	var action = action_data.action_name
	var value = action_data.value
	
	var target
	var self_target
	var anim_node
	
	if card.card_owner == "Player":
		target = opponent
		self_target = player
		anim_node = player_action_anim
	else:
		target = player
		self_target = opponent
		anim_node = opponent_action_anim
	
	# Apply Multipliers
	value = value * self_target.current_mult
	
	if self_target.nullified:
		print("Action nullified for ", card.card_owner)
		return

	# Pre-application logic, cards that do something before their main action
	if action == "Multiply_Or_Divide":
		if randf() < 0.5:
			await animation_manager.play_anim("Multiply_Or_Divide1", anim_node, card.card_owner)
			action = "Multiply_Next_Card"
		else:
			await animation_manager.play_anim("Multiply_Or_Divide2", anim_node, card.card_owner)
			action = "Divide_Next_Card"
	
	# Visuals
	card.get_node("AnimationPlayer").play("card_basic_use")
	await animation_manager.play_anim(action, anim_node, card.card_owner)
	
	# Effect Application
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
			target.next_mult /= value
			
		"Nullify":
			target.nullified = true
			
		"Draw_Card":
			var deck = player_deck if self_target == player else opponent_deck
			for i in range(int(value)):
				deck.draw_card()
				
		"Retrigger_Next_Slot":
			_handle_retrigger(card, int(value))
			battle_manager.update_card_effects()
		
		"Apply_Flame":
			if target == player:
				%PlayerTokens.add_token(flame_token_res, value)
			else:
				%OpponentTokens.add_token(flame_token_res, value)
	
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
