extends Node

signal battle_click_received

var player_retrigger_counts = [0, 0, 0]
var opponent_retrigger_counts = [0, 0, 0]

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
	
	if bleed_token_res:
		%OpponentTokens.add_token(bleed_token_res, 5)
		%PlayerTokens.add_token(bleed_token_res, 20)
	opponent_turn()

func _process(float) -> void:
	#temporary debug
	%PlayerLabel.text = "HP: %.1f  |\n Shield: %.1f |\n Mult: x%.2f |\n Next Mult x%.2f" % [
		%Player.current_health, %Player.current_shield, %Player.current_mult, %Player.next_mult]
	%OpponentLabel.text = "HP: %.1f  |\n Shield: %.1f |\nMult: x%.2f |\n Next Mult x%.2f" % [
		%Opponent.current_health, %Opponent.current_shield, %Opponent.current_mult, %Opponent.next_mult]
	pass

func _on_end_turn_button_pressed() -> void:
	await run_activation_phase()
	await trigger_tokens("On_Phase_End")
	opponent_turn()
	%PlayerDeck.draw_card()
	$"../EndTurnButton".disabled = true
	$"../EndTurnButton".visible = false

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

		if card_to_play.has_node("AnimationPlayer"):
			card_to_play.get_node("AnimationPlayer").play("card_flip")

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
		
		# resetting stuff
		%Player.current_mult = %Player.next_mult
		%Player.next_mult = 1.0
		%Opponent.current_mult = %Opponent.next_mult
		%Opponent.next_mult = 1.0
		
		%Player.nullified = false
		%Opponent.nullified = false

		# 1. Update total_needed based on how many cards are actually present
		total_needed = 0
		if p_card: total_needed += 1
		if o_card: total_needed += 1
		
		if total_needed == 0:
			continue # No cards in this slot index for either side, skip to next slot

		# 2. Move existing cards to battle point
		finished_count = 0
		if p_card: move_card_to_battle_point(p_card)
		if o_card: move_card_to_battle_point(o_card)
		
		# Wait for the cards that exist to finish moving
		while finished_count < total_needed:
			await get_tree().process_frame
		
		# Trigger slot passives
		await trigger_passives("On_Slot_Start", slot_index)
		await trigger_tokens("On_Slot_Start")
		# retrigger logic
		var p_runs = 1
		var o_runs = 1
		if p_card:
			p_runs += player_retrigger_counts[slot_index]
		if o_card:
			o_runs += opponent_retrigger_counts[slot_index]
		var total_runs = max(p_runs, o_runs)
		
		# 3. Determine max actions
		var p_action_count = p_card.card_data.actions.size() if p_card else 0
		var o_action_count = o_card.card_data.actions.size() if o_card else 0
		var max_actions = max(p_action_count, o_action_count)

		# 4. Action Loop 
		for run_idx in range(total_runs):
			print("Slot", slot_index + 1, "Run", run_idx + 1, "/", total_runs)

			for action_idx in range(max_actions):
				var first_actor = null
				var second_actor = null

				var p_has_act = (
					p_card != null
					and run_idx < p_runs
					and action_idx < p_card.card_data.actions.size()
					and p_card.card_data.actions[action_idx] != null
				)

				var o_has_act = (
					o_card != null
					and run_idx < o_runs
					and action_idx < o_card.card_data.actions.size()
					and o_card.card_data.actions[action_idx] != null
				)

				if p_has_act and o_has_act:
					var p_priority = p_card.card_data.actions[action_idx].priority
					var o_priority = o_card.card_data.actions[action_idx].priority
					
					if p_priority <= o_priority: #player gets priority if tie
						first_actor = p_card
						second_actor = o_card
					elif o_priority < p_priority:
						first_actor = o_card
						second_actor = p_card
				elif p_has_act:
					first_actor = p_card
				elif o_has_act:
					first_actor = o_card

				if first_actor:
					await action_manager.execute_card_action(first_actor, action_idx)
					await wait(1.0)
				if second_actor:
					await action_manager.execute_card_action(second_actor, action_idx)
					await wait(1.0)
		
		
		# 5. End of Slot Cleanup
		%Player.current_mult = 1.0
		%Opponent.current_mult = 1.0
		
		player_retrigger_counts[slot_index] = 0
		opponent_retrigger_counts[slot_index] = 0
		update_card_effects()
		
		if p_card: collect_used_card(p_card)
		if o_card: collect_used_card(o_card)

		reset_opponent_slots()
		await wait(0.8)

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
	if card.card_owner == "Player":
		%PlayerDeck.graveyard.append(card)
	else:
		%OpponentDeck.graveyard.append(card)
	
	# Clear its slot
	if card.cards_current_slot:
		card.cards_current_slot.card = null
		card.cards_current_slot.card_in_slot = false
		card.cards_current_slot = null
		
	card.visible = false # doesnt always hide it for some reason, fix this later
	card.position = Vector2(-100.0, 0.0)

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
			
