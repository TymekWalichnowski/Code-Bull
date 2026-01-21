extends Node

var player_retrigger_counts = [0, 0, 0]
var opponent_retrigger_counts = [0, 0, 0]

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

const STARTING_HEALTH = 10

const SMALLER_CARD_SCALE = 1.05
const CARD_MOVE_SPEED = 0.2

var player_health
var opponent_health

var empty_opponent_card_slots = []
var current_slot

func _ready() -> void:
	battle_timer.one_shot = true
	battle_timer.wait_time = 0.2
	
	empty_opponent_card_slots.append($"../CardSlots/OpponentCardSlot")
	empty_opponent_card_slots.append($"../CardSlots/OpponentCardSlot2")
	empty_opponent_card_slots.append($"../CardSlots/OpponentCardSlot3")
	
	# A bit awkward, clean this up
	%Player.health = STARTING_HEALTH
	%Opponent.health = STARTING_HEALTH
	#$"../PlayerHealth".text = str(%Player.health) # replace this later, we're just updating it every frame at the moment
	#$"../OpponentHealth".text = str(%Opponent.health)
	opponent_turn()

func _process(float) -> void:
	#temporary debug
	%PlayerLabel.text = "HP: %.1f  |  Mult: x%.2f | Next Mult x%.2f" % [%Player.health, %Player.current_mult, %Player.next_mult]
	%OpponentLabel.text = "HP: %.1f  |  Mult: x%.2f | Next Mult x%.2f" % [%Opponent.health, %Opponent.current_mult, %Opponent.next_mult]
	pass

func _on_end_turn_button_pressed() -> void:
	await run_check_phase()
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

var slot_retriggers = [0, 0, 0] # Track extra runs for Slot 1, 2, and 3

func run_check_phase():
	var slot_count = max(player_slots.size(), opponent_slots.size())
	
	# Reset counts at start of phase
	player_retrigger_counts = [0, 0, 0]
	opponent_retrigger_counts = [0, 0, 0]

	# --- EXAMPLE: Manual retrigger for Player Slot 2 ---
	# We check if there is actually a card there before scheduling a retrigger
	#if player_slots[1].card != null:
		#player_retrigger_counts[1] += 1 
		#print("DEBUG: Player Slot 2 scheduled for 1 extra run.")

	for slot_index in range(slot_count):
		# Reset global per-slot status
		%Player.nullified = false
		%Opponent.nullified = false

		var player_card = player_slots[slot_index].card
		var opponent_card = opponent_slots[slot_index].card

		# Determine how many times each card acts (0 if no card exists)
		var p_total_runs = 1 + player_retrigger_counts[slot_index] if player_card else 0
		var o_total_runs = 1 + opponent_retrigger_counts[slot_index] if opponent_card else 0
		
		# Iterate until the card with the most scheduled runs is done
		var max_runs_for_this_slot = max(p_total_runs, o_total_runs)

		for run_idx in range(max_runs_for_this_slot):
			# Process actions 1, 5, and 9 sequentially
			for action_index in [1, 5, 9]:
				# IMPORTANT: Reset tweens to null for EVERY action step
				var p_tween: Tween = null
				var o_tween: Tween = null

				# Player side acts only if they have runs remaining
				if player_card and run_idx < p_total_runs:
					if has_action(player_card, action_index):
						var p_data = check_card_action(player_card, action_index, action_index+1, action_index+2)
						p_tween = activate_card_action(player_card, p_data)

				# Opponent side acts only if they have runs remaining
				if opponent_card and run_idx < o_total_runs:
					if has_action(opponent_card, action_index):
						var o_data = check_card_action(opponent_card, action_index, action_index+1, action_index+2)
						o_tween = activate_card_action(opponent_card, o_data)

				# Wait for animations to finish before moving to next action index
				if p_tween: await p_tween.finished
				if o_tween: await o_tween.finished
				
				# If anyone did something, pause for readability
				if p_tween != null or o_tween != null:
					await wait(0.4)

		# 2. CLEANUP (Using your original logic)
		# Only teleport cards away after ALL runs (and retriggers) are done
		if player_card: collect_used_card(player_card)
		if opponent_card: collect_used_card(opponent_card)

	reset_opponent_slots()

func resolve_action_step(card, action_index):
	if card == null:
		return

	# --- Check the card action ---
	var action_data = check_card_action(card, action_index, action_index + 1, action_index + 2)  # [action, value, priority]
	if action_data[0] == null:
		return  # No action to perform

	# --- Build action queue ---
	var action_entry = {
		"card": card,
		"owner": card.OWNER,
		"action_data": action_data,
		"priority": action_data[2]
	}

	var action_queue = [action_entry]

	# --- Sort by priority (though here queue has 1 item, ready for future multi-card handling) ---
	action_queue.sort_custom(func(a, b):
		return a["priority"] < b["priority"]
	)

	# --- Execute actions and collect tweens ---
	var tweens = []
	for entry in action_queue:
		var tween = activate_card_action(entry["card"], entry["action_data"])
		if tween:
			tweens.append(tween)

	# --- Await all tweens simultaneously ---
	for tween in tweens:
		if tween:
			await tween.finished

	# Small pause after actions
	await get_tree().create_timer(0.25).timeout
	
func has_action(card, action_index) -> bool: # checking if a card has an action
	if card == null:
		return false
	return CardDatabase.CARDS[card.card_name][action_index] != null

func check_card_action(card, action_index, value_index, priority_index):
	var card_data = CardDatabase.CARDS[card.card_name]
	var action = card_data[action_index]
	if action == null:
		return [null, null, INF]

	var value = card_data[value_index]
	var priority = card_data[priority_index]

	return [action, value, priority]


# Activates a card action, returns the Tween for awaiting
# Now returns void but is awaitable
func activate_card_action(card, action_data) -> Tween:
	if action_data[0] == null: return null

	var target_pos = %OpponentCardPoint.global_position if card.OWNER == "Opponent" else %PlayerCardPoint.global_position
	var main_tween = get_tree().create_tween()
	
	# Only tween position if we aren't already at the center point
	if card.global_position.distance_to(target_pos) > 10:
		main_tween.set_parallel(true)
		main_tween.tween_property(card, "position", target_pos, CARD_MOVE_SPEED)
		main_tween.tween_property(card, "scale", Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE), CARD_MOVE_SPEED)
		card.z_index = 10 
		main_tween.set_parallel(false) # Subsequent steps happen after move
	
	# Play Animation
	main_tween.tween_callback(func():
		if card.has_node("AnimationPlayer"):
			card.get_node("AnimationPlayer").play("card_basic_use")
	)
	
	# Wait for animation duration (defaulting to 0.5s if no player found)
	var duration = 0.5
	if card.has_node("AnimationPlayer") and card.get_node("AnimationPlayer").has_animation("card_basic_use"):
		duration = card.get_node("AnimationPlayer").get_animation("card_basic_use").length
	
	main_tween.tween_interval(duration)
	main_tween.tween_callback(apply_action.bind(card, action_data))
	
	return main_tween

func apply_action(card, action_data):
	var target
	var self_target
	
	var action = action_data[0]
	var value = action_data[1]
	
	if card.OWNER == "Player":
		target = %Opponent
		self_target = %Player
	else:
		target = %Player
		self_target = %Opponent
	
	# applying mult to be whatever the next mult is
	value = value * self_target.current_mult
	# After applying current mult, apply next mult, this is to prevent issues such as same-turn divides
	
	if self_target.nullified == true:
		print("returning ", card.OWNER, " action as it was nullified")
		return
	
	match action:
		"Attack":
			print(card.OWNER, " deals ", value, " damage.")
			target.health -= value
			self_target.current_mult = 1.0
		"Shield":
			print(card.OWNER, " gains ", value, " shield.")
			self_target.health += value
			self_target.current_mult = 1.0
		"Multiply_Next_Card":
			print(card.OWNER, " gains ", value, " mult.") 
			self_target.next_mult = self_target.next_mult * value
		"Divide_Next_Card":
			print(card.OWNER, " applies ", value, " divide to ", target) # need to change how mult works because currently 1 mult becomes 3 mult when you add 2
			target.next_mult = target.next_mult / value
		"Nullify":
			print(card.OWNER, " nullifies ", target) # need to change how mult works because currently 1 mult becomes 3 mult when you add 2
			target.nullified = true
		"Draw_Card":
			if self_target == %Player:
				for i in value:
					%PlayerDeck.draw_card()
			else:
				for i in value:
					%OpponentDeck.draw_card()
		"Retrigger_Next_Slot":
			var current_idx = -1
			# Find slot index
			for i in range(player_slots.size()):
				if player_slots[i].card == card:
					current_idx = i
					break
			
			# Only increment the retrigger count for the OWNER of the card
			if current_idx != -1 and current_idx + 1 < 3:
				if card.OWNER == "Player":
					player_retrigger_counts[current_idx + 1] += int(value)
				else:
					opponent_retrigger_counts[current_idx + 1] += int(value)

	self_target.current_mult = self_target.next_mult
	self_target.next_mult = 1.0
	
	
	#%PlayerLabel.text = str(%Player.health) Not needed right now since we're updating every frame for debug purposes
	#%OpponentLabel.text = str(%Opponent.health)

func collect_used_card(card):
	if card == null:
		return
	
	if card.OWNER == "Player":
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
