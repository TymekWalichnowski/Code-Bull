extends Node

signal battle_click_received

var player_retrigger_counts = [0, 0, 0]
var opponent_retrigger_counts = [0, 0, 0]
var player_slot_mults = [1.0, 1.0, 1.0]
var opponent_slot_mults = [1.0, 1.0, 1.0]

@onready var action_manager = %ActionManager
@onready var passive_manager = %PassiveManager
@onready var token_manager = %TokenManager 
@export var bleed_token_res: TokenResource # For testing
@export var flame_token_res: TokenResource # For testing

@onready var player_slots = [
	$"../CardSlots/CardSlot",
	$"../CardSlots/CardSlot2",
	$"../CardSlots/CardSlot3"
]

@onready var opponent_slots = [
	$"../CardSlots/OpponentCardSlot",
	$"../CardSlots/OpponentCardSlot2",
	$"../CardSlots/OpponentCardSlot3"
]

@onready var battle_timer = %BattleTimer

const STARTING_HEALTH = 10.0

const SMALLER_CARD_SCALE = 1.05
const CARD_MOVE_SPEED = 0.2

var player_health
var opponent_health

var empty_opponent_card_slots = []
var current_slot
var finished_count = 0
var total_needed = 2

func _ready() -> void:
	
	battle_timer.one_shot = true
	battle_timer.wait_time = 0.2
	
	empty_opponent_card_slots.append($"../CardSlots/OpponentCardSlot")
	empty_opponent_card_slots.append($"../CardSlots/OpponentCardSlot2")
	empty_opponent_card_slots.append($"../CardSlots/OpponentCardSlot3")
	
	# A bit awkward, clean this up
	%Player.current_health = STARTING_HEALTH
	%Opponent.current_health = STARTING_HEALTH
	
	#if bleed_token_res:
		#%OpponentTokens.add_token(bleed_token_res, 5)
		#%PlayerTokens.add_token(bleed_token_res, 20)
	opponent_turn()

func _process(float) -> void:
	#temporary debug
	%PlayerLabel.text = "HP: %.1f  |\n Shield: %.1f |\n Mult: x%.2f |\n Next Mult x%.2f" % [
		%Player.current_health, %Player.current_shield, %Player.current_mult, %Player.next_mult]
	%OpponentLabel.text = "HP: %.1f  |\n Shield: %.1f |\nMult: x%.2f |\n Next Mult x%.2f" % [
		%Opponent.current_health, %Opponent.current_shield, %Opponent.current_mult, %Opponent.next_mult]
	pass

func _on_end_turn_button_pressed() -> void:
	$"../EndTurnButton".disabled = true
	$"../EndTurnButton".visible = false
	await run_activation_phase()
	await trigger_tokens("On_Phase_End")
	opponent_turn()
	%PlayerDeck.draw_card()
	


func opponent_turn():
	# wait a bit
	await wait(0.2)
	%OpponentDeck.draw_card()
	await wait(1)
	
	# Add proper AI here
	if empty_opponent_card_slots.size() != 0:
		await play_opponent_cards() # just picks highest id for now
	
	end_opponent_turn()

func play_opponent_cards():
	# Make a safe copy of the hand to iterate
	var hand = %OpponentHand.opponent_hand.duplicate()

	# Play cards while there are cards in hand and empty slots
	while hand.size() > 0 and empty_opponent_card_slots.size() > 0:
		# Pick the card with the highest ID
		var card_to_play = hand[0]
		for card in hand:
			if card.card_id > card_to_play.card_id:
				card_to_play = card

		var slot = empty_opponent_card_slots[0]

		# Animate card to slot
		var tween1 = get_tree().create_tween()
		tween1.tween_property(card_to_play, "position", slot.position, CARD_MOVE_SPEED)
		var tween2 = get_tree().create_tween()
		tween2.tween_property(card_to_play, "scale", Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE), CARD_MOVE_SPEED)

		card_to_play.get_node("AnimationPlayer").play("card_flip")
		card_to_play.play_audio("place")
		# Wait for animation to finish
		await tween1.finished

		# Assign card to slot
		card_to_play.cards_current_slot = slot
		slot.card_in_slot = true
		slot.card = card_to_play

		# Remove from the real hand and update free slots
		%OpponentHand.remove_card_from_hand(card_to_play)
		empty_opponent_card_slots.erase(slot)

		# Remove from local copy to avoid picking again
		hand.erase(card_to_play)

func end_opponent_turn():
	$"../EndTurnButton".disabled = false
	$"../EndTurnButton".visible = true

func reset_opponent_slots():
	empty_opponent_card_slots.clear()
	for slot in opponent_slots:
		if not slot.card_in_slot:
			empty_opponent_card_slots.append(slot)

func wait(wait_time):
	battle_timer.wait_time = wait_time
	battle_timer.start()
	await battle_timer.timeout


var slot_retriggers = [0, 0, 0] # Track extra runs for Slot 1, 2, and 3, move this outta the way
	
	# EXAMPLE: Manual retrigger for Player Slot 2, put above slot index
	# We check if there is actually a card there before scheduling a retrigger
	#if player_slots[1].card != null:
		#player_retrigger_counts[1] += 1 
		#print("DEBUG: Player Slot 2 scheduled for 1 extra run.")

func run_activation_phase():
	var slot_count = max(player_slots.size(), opponent_slots.size())
	player_retrigger_counts = [0, 0, 0]
	opponent_retrigger_counts = [0, 0, 0]
	
	await trigger_passives("On_Phase_Start")
	await trigger_tokens("On_Phase_Start")
	await wait(0.4)
	
	for slot_index in range(slot_count):
		print("\n ---- CARD SLOT ", slot_index + 1, " ----")
		
		var p_card = player_slots[slot_index].card
		var o_card = opponent_slots[slot_index].card
		
		# Reset slot stats
		%Player.current_mult = %Player.next_mult
		%Player.next_mult = 1.0
		%Opponent.current_mult = %Opponent.next_mult
		%Opponent.next_mult = 1.0
		%Player.nullified = false
		%Opponent.nullified = false

		# 1. Check for cards and move them
		total_needed = 0
		if p_card: total_needed += 1
		if o_card: total_needed += 1
		
		if total_needed == 0: continue 

		finished_count = 0
		if p_card: move_card_to_battle_point(p_card)
		if o_card: move_card_to_battle_point(o_card)
		
		while finished_count < total_needed:
			await get_tree().process_frame
		
		await trigger_passives("On_Slot_Start", slot_index)
		await trigger_tokens("On_Slot_Start")

		# 2. Sequential Execution: Player First
		if p_card:
			var p_runs = 1 + player_retrigger_counts[slot_index]
			for run_idx in range(p_runs):
				print("Player Slot ", slot_index + 1, " Run ", run_idx + 1)
				for action_idx in range(p_card.card_data.actions.size()):
					var action = p_card.card_data.actions[action_idx]
					if action != null:
						await action_manager.execute_card_action(p_card, action_idx)
						await wait(0.8) # Slight pause between actions

		# 3. Sequential Execution: Opponent Second
		if o_card:
			var o_runs = 1 + opponent_retrigger_counts[slot_index]
			for run_idx in range(o_runs):
				print("Opponent Slot ", slot_index + 1, " Run ", run_idx + 1)
				for action_idx in range(o_card.card_data.actions.size()):
					var action = o_card.card_data.actions[action_idx]
					if action != null:
						await action_manager.execute_card_action(o_card, action_idx)
						await wait(0.8)

		# 4. End of Slot Cleanup
		%Player.current_mult = 1.0
		%Opponent.current_mult = 1.0
		player_retrigger_counts[slot_index] = 0
		opponent_retrigger_counts[slot_index] = 0
		update_card_effects()
		
		if p_card: collect_used_card(p_card)
		if o_card: collect_used_card(o_card)

		reset_opponent_slots()
		await wait(0.6)

func check_done(): #making sure both actions are done before
	finished_count += 1
	print("finished count: ", finished_count)

func move_card_to_battle_point(card):
	var target_pos
	if card.card_owner == "Player":
		target_pos = %PlayerCardPoint.global_position 
	else:
		target_pos = %OpponentCardPoint.global_position 
	var move_tween = get_tree().create_tween()
	move_tween.tween_property(card, "position", target_pos, CARD_MOVE_SPEED)
	move_tween.tween_property(card, "scale", Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE), CARD_MOVE_SPEED)
	move_tween.finished.connect(check_done) # adds to finished count
	card.z_index = 10

func collect_used_card(card):
	if card == null:
		return
	
	card.set_retrigger_glow(false)
	
	# Store the DATA (resource) in the graveyard, not the Node
	if card.card_owner == "Player":
		%PlayerDeck.graveyard.append(card.card_data)
	else:
		%OpponentDeck.graveyard.append(card.card_data)
	
	# Clear slot logic...
	if card.cards_current_slot:
		card.cards_current_slot.card = null
		card.cards_current_slot.card_in_slot = false
		card.cards_current_slot = null
		
	card.queue_free() # Delete the node since we saved its data to the graveyard
func _input(event: InputEvent) -> void:
	# Detect any left mouse click that isn't on a UI button
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		battle_click_received.emit()

func trigger_passives(trigger_type: String, current_slot_idx: int = -1):
	await passive_manager.trigger_passives(trigger_type, current_slot_idx)

func trigger_tokens(trigger_type: String, side: String = "Both"):
	await token_manager.trigger_tokens(trigger_type, side)

func update_card_effects():
	# Update Player Cards
	for i in range(player_slots.size()):
		var slot = player_slots[i]
		var has_retrigger = player_retrigger_counts[i] > 0
		
		# If there is a card in this slot, update its glow
		if slot.card:
			slot.card.set_retrigger_glow(has_retrigger)
	
	# Update Opponent Cards
	for i in range(opponent_slots.size()):
		var slot = opponent_slots[i]
		var has_retrigger = opponent_retrigger_counts[i] > 0
		
		if slot.card:
			slot.card.set_retrigger_glow(has_retrigger)
			
