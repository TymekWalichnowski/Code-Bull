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
	
	# --- NEW MULTIPLIER LOGIC ---
	# Calculate value using internal Card and Action multipliers
	var base_value = action_data.value
	var action_mult = action_data.action_multiplier
	var card_mult = card.card_data.multiplier
	
	# Ensure multipliers aren't 0 by default (unless intended)
	if action_mult == 0: action_mult = 1.0
	if card_mult == 0: card_mult = 1.0
	
	var final_value = (base_value * action_mult) * card_mult
	# ----------------------------

	var target
	var self_target
	if card.card_owner == "Player":
		target = opponent
		self_target = player
	else:
		target = player
		self_target = opponent
	
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
	
	# Effect Application
	match action:
		"Attack":
			target.take_damage(final_value) # Use final_value
		"Shield":
			self_target.gain_shield(final_value) # Use final_value
		"Multiply_Next_Card":
			# Target Self, Next Slot
			_apply_multiplier_to_next_slot(card, final_value, false)
			
		"Divide_Next_Card":
			# Target Opponent, Next Card in timeline
			# We use 1.0 / value because "Divide by 2" is "Multiply by 0.5"
			_apply_multiplier_to_next_slot(card, 1.0 / final_value, true)
		"Draw_Card":
			var deck = player_deck if self_target == player else opponent_deck
			for i in range(int(final_value)):
				await deck.draw_card()
		"Nullify":
			target.nullified = true
			
		"Retrigger_Next_Slot":
			_handle_retrigger(card, int(final_value))
			battle_manager.update_card_effects()
			
		"Apply_Flame":
			if target == player:
				%PlayerTokens.add_token(flame_token_res, final_value)
			else:
				%OpponentTokens.add_token(flame_token_res, final_value)
		
		"Apply_Bleed":
			if target == player:
				%PlayerTokens.add_token(bleed_token_res, final_value)
			else:
				%OpponentTokens.add_token(bleed_token_res, final_value)
	
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

func _apply_multiplier_to_next_slot(current_card: Card, multiplier_value: float, target_opponent: bool = false):
	var current_idx = -1
	var p_slots = battle_manager.player_slots
	var o_slots = battle_manager.opponent_slots
	
	# 1. Find where we are
	if current_card.card_owner == "Player":
		current_idx = p_slots.find(current_card.cards_current_slot)
	else:
		current_idx = o_slots.find(current_card.cards_current_slot)
	
	if current_idx == -1: return

	# 2. Determine the target slot and side
	var target_slot_idx = current_idx
	var target_is_player = (current_card.card_owner == "Player")
	
	if target_opponent:
		# If Player 1 targets Opponent, the next is Opponent 1 (same index)
		# If Opponent 1 targets Player, the next is Player 2 (index + 1)
		if current_card.card_owner == "Player":
			target_is_player = false
			target_slot_idx = current_idx
		else:
			target_is_player = true
			target_slot_idx = current_idx + 1
	else:
		# Targeting self: always the next slot
		target_slot_idx = current_idx + 1

	# 3. Apply the buff/debuff to the card in that slot
	if target_slot_idx < 3:
		var target_slot = p_slots[target_slot_idx] if target_is_player else o_slots[target_slot_idx]
		if target_slot.card:
			# Multiply the card-wide multiplier
			target_slot.card.card_data.multiplier *= multiplier_value
			# Force the UI to refresh so the player sees the new number
			target_slot.card.update_hover_ui()
			print("Applied x", multiplier_value, " to ", target_slot.card.card_name)
