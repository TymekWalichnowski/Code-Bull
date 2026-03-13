extends Node

@onready var player = %Player
@onready var opponent = %Opponent
@onready var animation_manager = %AnimationManager
@onready var player_deck = %PlayerDeck
@onready var opponent_deck = %OpponentDeck

# Reference to BattleManager for initiative and retrigger counts
@onready var battle_manager = get_parent()

@export var flame_token_res: TokenResource 
@export var bleed_token_res: TokenResource 

func execute_card_action(card: Card, action_index: int):
	var action_data = card.card_data.actions[action_index]
	var action = action_data.action_name
	
	# Pre-application logic
	var base_value = action_data.value
	var action_mult = action_data.action_multiplier if action_data.action_multiplier != 0 else 1.0
	var card_mult = card.card_data.multiplier if card.card_data.multiplier != 0 else 1.0
	var final_value = (base_value * action_mult) * card_mult

	var target = opponent if card.card_owner == "Player" else player
	var self_target = player if card.card_owner == "Player" else opponent

	# This is a secondary safety check
	if self_target.nullified:
		print(card.card_owner, " action blocked by nullify!")
		return

	# Handle Multiply/Divide logic...
	if action == "Multiply_Or_Divide":
		if randf() < 0.5:
			await animation_manager.play_anim("Multiply_Or_Divide1", card.card_owner)
			action = "Multiply_Next_Card"
		else:
			await animation_manager.play_anim("Multiply_Or_Divide2", card.card_owner)
			action = "Divide_Next_Card"

	# Calculate animation target...
	var p_init = battle_manager.player_has_initiative
	var is_p = (card.card_owner == "Player")
	var slots = battle_manager.player_slots if is_p else battle_manager.opponent_slots
	var current_idx = slots.find(card.cards_current_slot)
	var anim_target_idx = -1
	
	if action == "Multiply_Next_Card" or action == "Retrigger_Next_Slot":
		anim_target_idx = current_idx + 1
	elif action == "Divide_Next_Card":
		if (is_p and p_init) or (!is_p and !p_init):
			anim_target_idx = current_idx
		else:
			anim_target_idx = current_idx + 1

	# Visuals
	card.get_node("AnimationPlayer").play("card_basic_use")
	card.play_audio("use")
	await animation_manager.play_anim(action, card.card_owner, anim_target_idx)
	
	# Effect Application
	match action:
		"Attack":
			target.take_damage(final_value)
		"Shield":
			self_target.gain_shield(final_value)
		"Multiply_Next_Card":
			_apply_multiplier_to_next_slot(card, final_value, false)
		"Divide_Next_Card":
			_apply_multiplier_to_next_slot(card, 1.0 / final_value, true)
		"Draw_Card":
			var deck = player_deck if self_target == player else opponent_deck
			for i in range(int(final_value)):
				await deck.draw_card()
		"Nullify":
			target.nullified = true
			print("Setting ", target.name, " nullified to TRUE") # Debug
		"Retrigger_Next_Slot":
			_handle_retrigger(card, int(final_value))
			battle_manager.update_card_effects()
		"Apply_Flame":
			var t_node = %PlayerTokens if target == player else %OpponentTokens
			t_node.add_token(flame_token_res, final_value)
		"Apply_Bleed":
			var t_node = %PlayerTokens if target == player else %OpponentTokens
			t_node.add_token(bleed_token_res, final_value)
	
	await battle_manager.token_manager.trigger_tokens("After_Action", card.card_owner)

func _handle_retrigger(card: Card, value: int):
	var is_p = (card.card_owner == "Player")
	var slots = battle_manager.player_slots if is_p else battle_manager.opponent_slots
	var current_idx = slots.find(card.cards_current_slot)
			
	if current_idx != -1 and current_idx + 1 < 3:
		if is_p:
			battle_manager.player_retrigger_counts[current_idx + 1] += value
		else:
			battle_manager.opponent_retrigger_counts[current_idx + 1] += value

func _apply_multiplier_to_next_slot(current_card: Card, multiplier_value: float, target_opponent: bool = false):
	var p_init = battle_manager.player_has_initiative
	var is_p = (current_card.card_owner == "Player")
	var current_idx = (battle_manager.player_slots if is_p else battle_manager.opponent_slots).find(current_card.cards_current_slot)
	
	if current_idx == -1: return

	var target_is_player = is_p
	var target_slot_idx = current_idx + 1 # Default for Self

	if target_opponent:
		target_is_player = !is_p
		# Logic matches the animation calculation:
		if (is_p and p_init) or (!is_p and !p_init):
			target_slot_idx = current_idx
		else:
			target_slot_idx = current_idx + 1

	if target_slot_idx >= 0 and target_slot_idx < 3:
		var target_slots = battle_manager.player_slots if target_is_player else battle_manager.opponent_slots
		var target_slot = target_slots[target_slot_idx]
		if target_slot.card:
			target_slot.card.card_data.multiplier *= multiplier_value
			target_slot.card.update_hover_ui()
			print("Applied x", multiplier_value, " to ", target_slot.card.card_name)
