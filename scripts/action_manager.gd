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
	
	# Core variables to simplify logic downstream
	var is_player = (card.card_owner == "Player")
	var target = opponent if is_player else player
	var self_target = player if is_player else opponent
	var slots = battle_manager.player_slots if is_player else battle_manager.opponent_slots
	var current_idx = slots.find(card.cards_current_slot)
	
	# Pre-application value math
	var action_mult = action_data.action_multiplier if action_data.action_multiplier != 0 else 1.0
	var card_mult = card.card_data.multiplier if card.card_data.multiplier != 0 else 1.0
	var final_value = (action_data.value * action_mult) * card_mult

	# Secondary safety check
	if self_target.nullified:
		print(card.card_owner, " action blocked by nullify!")
		return

	# Handle Multiply/Divide randomizer
	if action == "Multiply_Or_Divide":
		if randf() < 0.5:
			await animation_manager.play_anim("Multiply_Or_Divide1", card.card_owner)
			action = "Multiply_Next_Card"
		else:
			await animation_manager.play_anim("Multiply_Or_Divide2", card.card_owner)
			action = "Divide_Next_Card"

	# Calculate animation target
	var anim_target_idx = -1
	match action:
		"Multiply_Next_Card", "Retrigger_Next_Slot":
			anim_target_idx = current_idx + 1
		"Divide_Next_Card":
			var p_init = battle_manager.player_has_initiative
			# is_player == p_init is a clean shorthand for your previous logic
			anim_target_idx = current_idx if (is_player == p_init) else current_idx + 1
		"Divide_Specific_Slot":
			anim_target_idx = int(action_data.static_value)

	# Visuals
	card.get_node("AnimationPlayer").play("card_basic_use")
	card.play_audio("use")
	await animation_manager.play_anim(action, card.card_owner, anim_target_idx)
	
	# Effect Application
	match action:
		"Attack":
			target.take_damage(final_value)
			var hit_side = "Opponent" if is_player else "Player"
			
			if battle_manager.has_method("trigger_passives"):
				# We send the clean "On_Hit_Taken" and tell the manager WHICH side took the hit
				await battle_manager.trigger_passives("On_Hit_Taken", -1, hit_side)
		"Shield":
			self_target.gain_shield(final_value)
		"Multiply_Next_Card":
			_apply_multiplier(is_player, current_idx + 1, final_value)
		"Divide_Next_Card":
			_apply_multiplier(!is_player, anim_target_idx, 1.0 / final_value)
		"Divide_Specific_Slot":
			_apply_multiplier(!is_player, anim_target_idx, 1.0 / final_value)
		"Draw_Card":
			var deck = player_deck if is_player else opponent_deck
			for i in range(int(final_value)): await deck.draw_card()
		"Nullify":
			target.nullified = true
			print("Setting ", target.name, " nullified to TRUE")
		"Retrigger_Next_Slot":
			_handle_retrigger(is_player, current_idx + 1, int(final_value))
		"Apply_Flame":
			_apply_token(target, flame_token_res, final_value)
		"Apply_Bleed":
			_apply_token(target, bleed_token_res, final_value)
	
	await battle_manager.token_manager.trigger_tokens("After_Action", card.card_owner)

# --- HELPER FUNCTIONS ---

func _handle_retrigger(is_target_player: bool, target_idx: int, value: int):
	if target_idx >= 0 and target_idx < 3:
		if is_target_player:
			battle_manager.player_retrigger_counts[target_idx] += value
		else:
			battle_manager.opponent_retrigger_counts[target_idx] += value
		battle_manager.update_card_effects()

func _apply_multiplier(is_target_player: bool, target_idx: int, multiplier_value: float):
	if target_idx < 0 or target_idx >= 3: return
	
	var target_slots = battle_manager.player_slots if is_target_player else battle_manager.opponent_slots
	var target_slot = target_slots[target_idx]
	
	if target_slot.card:
		target_slot.card.card_data.multiplier *= multiplier_value
		target_slot.card.update_hover_ui()
		print("Applied x", multiplier_value, " to ", target_slot.card.card_name, " at index ", target_idx)

func _apply_token(target_node: Node, token_res: TokenResource, amount: float):
	var token_container = %PlayerTokens if target_node == player else %OpponentTokens
	token_container.add_token(token_res, amount)
