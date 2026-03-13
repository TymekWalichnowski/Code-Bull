extends Node

signal battle_click_received

var player_retrigger_counts = [0, 0, 0]
var opponent_retrigger_counts = [0, 0, 0]

@onready var action_manager = %ActionManager
@onready var passive_manager = %PassiveManager
@onready var token_manager = %TokenManager 

@onready var player_slots = [
	$"../CardSlots/CardSlot",
	$"../CardSlots/CardSlot2",
	$"../CardSlots/CardSlot3"
]

@onready var opponent_slots = [
	$"../CardSlots/CardSlotOpponent1",
	$"../CardSlots/CardSlotOpponent2",
	$"../CardSlots/CardSlotOpponent3"
]

@onready var battle_timer = %BattleTimer

const STARTING_HEALTH = 10.0
const SMALLER_CARD_SCALE = 1.05
const CARD_MOVE_SPEED = 0.2

var player_health
var opponent_health
var empty_opponent_card_slots = []
var player_has_initiative: bool = true

func _ready() -> void:
	battle_timer.one_shot = true
	battle_timer.wait_time = 0.2
	
	# Automatically find empty slots from the array
	reset_opponent_slots()
	
	%Player.current_health = STARTING_HEALTH
	%Opponent.current_health = STARTING_HEALTH
	
	opponent_turn()

func _process(_delta: float) -> void:
	%PlayerLabel.text = "HP: %.1f  |\n Shield: %.1f " % [
		%Player.current_health, %Player.current_shield]
	%OpponentLabel.text = "HP: %.1f  |\n Shield: %.1f" % [
		%Opponent.current_health, %Opponent.current_shield]

func _on_end_turn_button_pressed() -> void:
	$"../EndTurnButton".disabled = true
	$"../EndTurnButton".visible = false
	await run_activation_phase()
	await trigger_tokens("On_Phase_End")
	opponent_turn()
	%PlayerDeck.draw_card()
	%PlayerDeck.draw_card()
	%PlayerDeck.draw_card()

func opponent_turn():
	await wait(0.2)
	%OpponentDeck.draw_card()
	await wait(1)
	
	if empty_opponent_card_slots.size() != 0:
		await play_opponent_cards() 
	
	end_opponent_turn()

func play_opponent_cards():
	var hand = %OpponentHand.opponent_hand.duplicate()

	while hand.size() > 0 and empty_opponent_card_slots.size() > 0:
		var card_to_play = hand[0]
		for card in hand:
			if card.card_id > card_to_play.card_id:
				card_to_play = card

		var slot = empty_opponent_card_slots[0]

		var tween1 = get_tree().create_tween().set_parallel(true)
		tween1.tween_property(card_to_play, "position", slot.position, CARD_MOVE_SPEED)
		tween1.tween_property(card_to_play, "scale", Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE), CARD_MOVE_SPEED)
		
		# When the card moves to the slot:
		card_to_play.get_node("CardImage").visible = true
		card_to_play.get_node("AnimationPlayer").play("card_flip")
		card_to_play.play_audio("place")
		await tween1.finished
		card_to_play.interactable = true
		
		card_to_play.cards_current_slot = slot
		slot.card_in_slot = true
		slot.card = card_to_play
		card_to_play.update_hover_ui()

		%OpponentHand.remove_card_from_hand(card_to_play)
		empty_opponent_card_slots.erase(slot)
		hand.erase(card_to_play)

func end_opponent_turn():
	$"../EndTurnButton".disabled = false
	$"../EndTurnButton".visible = true

func reset_opponent_slots():
	empty_opponent_card_slots.clear()
	for slot in opponent_slots:
		if is_instance_valid(slot) and not slot.card_in_slot:
			empty_opponent_card_slots.append(slot)

func wait(wait_time):
	battle_timer.wait_time = wait_time
	battle_timer.start()
	await battle_timer.timeout

func run_activation_phase():
	var slot_count = max(player_slots.size(), opponent_slots.size())
	player_retrigger_counts = [0, 0, 0]
	opponent_retrigger_counts = [0, 0, 0]
	
	player_has_initiative = randf() < 0.5
	print("Initiative: ", "Player" if player_has_initiative else "Opponent")
	
	await wait(0.4)
	
	for slot_index in range(slot_count):
		var order = ["Player", "Opponent"] if player_has_initiative else ["Opponent", "Player"]
		
		await trigger_passives("On_Slot_Start", slot_index)
		await trigger_tokens("On_Slot_Start")
		update_card_effects()
		for side in order:
			var card = player_slots[slot_index].card if side == "Player" else opponent_slots[slot_index].card
			var current_side_node = %Player if side == "Player" else %Opponent
			
			if not card: continue

			# --- FIX: CHECK NULLIFY BEFORE RESETTING IT ---
			if current_side_node.nullified:
				print(side, " is NULLIFIED! Skipping slot ", slot_index + 1)
				current_side_node.nullified = false # Reset it AFTER skipping the turn
				collect_used_card(card) # Discard the card because its turn was "spent"
				await wait(0.3)
				continue 
			# ----------------------------------------------
			update_card_effects()

			await move_card_to_battle_point(card).finished
			
			var counts = player_retrigger_counts if side == "Player" else opponent_retrigger_counts
			var runs = 1 + counts[slot_index]
			
			for run_idx in range(runs):
				for action_idx in range(card.card_data.actions.size()):
					if card.card_data.actions[action_idx] != null:
						await action_manager.execute_card_action(card, action_idx)
						await wait(0.6)
			
			collect_used_card(card)
			await wait(0.3)

		player_retrigger_counts[slot_index] = 0
		opponent_retrigger_counts[slot_index] = 0
		reset_opponent_slots()
		await wait(0.6)

func move_card_to_battle_point(card) -> Tween:
	var target_pos
	if card.card_owner == "Player":
		target_pos = %PlayerCardPoint.global_position 
	else:
		target_pos = %OpponentCardPoint.global_position 
		
	var move_tween = get_tree().create_tween().set_parallel(true)
	move_tween.tween_property(card, "position", target_pos, CARD_MOVE_SPEED)
	move_tween.tween_property(card, "scale", Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE), CARD_MOVE_SPEED)
	card.z_index = 10
	return move_tween

func collect_used_card(card):
	if card == null: return
	
	card.set_retrigger_glow(false)
	
	# --- RESET CARD STATS BEFORE GRAVEYARD ---
	if card.card_data:
		card.card_data.multiplier = 1.0
		for action in card.card_data.actions:
				if action != null: # Check if the action slot is actually filled
					action.action_multiplier = 1.0
		# If you eventually add other temporary buffs (like flat damage), reset them here too
	
	if card.card_owner == "Player":
		%PlayerDeck.graveyard.append(card.card_data)
	else:
		%OpponentDeck.graveyard.append(card.card_data)
	
	if card.cards_current_slot:
		card.cards_current_slot.card = null
		card.cards_current_slot.card_in_slot = false
		card.cards_current_slot = null
		
	card.queue_free()

func update_card_effects():
	# Update Player Cards
	for i in range(player_slots.size()):
		var slot = player_slots[i]
		var has_retrigger = player_retrigger_counts[i] > 0
		if slot.card:
			slot.card.set_retrigger_glow(has_retrigger)
	
	# Update Opponent Cards
	for i in range(opponent_slots.size()):
		var slot = opponent_slots[i]
		var has_retrigger = opponent_retrigger_counts[i] > 0
		if slot.card:
			slot.card.set_retrigger_glow(has_retrigger)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		battle_click_received.emit()

func trigger_passives(trigger_type: String, current_slot_idx: int = -1, side: String = "Both"):
	await passive_manager.trigger_passives(trigger_type, current_slot_idx, side)

func trigger_tokens(trigger_type: String, side: String = "Both"):
	await token_manager.trigger_tokens(trigger_type, side)
