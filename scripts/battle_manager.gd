extends Node

signal battle_click_received

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
	
	# EXAMPLE: Manual retrigger for Player Slot 2, put above slot index
	# We check if there is actually a card there before scheduling a retrigger
	#if player_slots[1].card != null:
		#player_retrigger_counts[1] += 1 
		#print("DEBUG: Player Slot 2 scheduled for 1 extra run.")
func run_check_phase():
	var slot_count = max(player_slots.size(), opponent_slots.size())
	player_retrigger_counts = [0, 0, 0]
	opponent_retrigger_counts = [0, 0, 0]

	for slot_index in range(slot_count):
		%Player.nullified = false
		%Opponent.nullified = false

		var player_card = player_slots[slot_index].card
		var opponent_card = opponent_slots[slot_index].card
		
		if player_card:
			%Player.current_mult = %Player.next_mult
			%Player.next_mult = 1.0
		if opponent_card:
			%Opponent.current_mult = %Opponent.next_mult
			%Opponent.next_mult = 1.0

		# --- NEW: MOVEMENT PHASE ---
		var p_move = move_card_to_battle_point(player_card)
		var o_move = move_card_to_battle_point(opponent_card)
		
		# Wait for movement to finish
		if p_move: await p_move.finished
		if o_move: await o_move.finished

		# --- NEW: WAIT FOR CLICK PHASE ---
		# Only wait if there is at least one card to act
		if player_card or opponent_card:
			print("Cards moved. Waiting for click...")
			await battle_click_received 

		# --- ACTION PHASE ---
		var p_total_runs = 1 + player_retrigger_counts[slot_index] if player_card else 0
		var o_total_runs = 1 + opponent_retrigger_counts[slot_index] if opponent_card else 0
		var max_runs_for_this_slot = max(p_total_runs, o_total_runs)

		for run_idx in range(max_runs_for_this_slot):
			for action_index in [1, 5, 9]:
				var p_tween: Tween = null
				var o_tween: Tween = null

				if player_card and run_idx < p_total_runs:
					if has_action(player_card, action_index):
						var p_data = check_card_action(player_card, action_index, action_index+1, action_index+2, action_index+3)
						# Use the new execution function
						p_tween = execute_card_action(player_card, p_data)

				if opponent_card and run_idx < o_total_runs:
					if has_action(opponent_card, action_index):
						var o_data = check_card_action(opponent_card, action_index, action_index+1, action_index+2, action_index+3)
						# Use the new execution function
						o_tween = execute_card_action(opponent_card, o_data)

				if p_tween: await p_tween.finished
				if o_tween: await o_tween.finished
				
				if p_tween != null or o_tween != null:
					await wait(0.4)

		# CLEANUP
		%Player.current_mult = 1.0
		%Opponent.current_mult = 1.0
		if player_card: collect_used_card(player_card)
		if opponent_card: collect_used_card(opponent_card)

	reset_opponent_slots()

func has_action(card, action_index) -> bool: # checking if a card has an action
	if card == null:
		return false
	return CardDatabase.CARDS[card.card_name][action_index] != null

func check_card_action(card, action_index, value_index, priority_index, tags_index):
	var card_data = CardDatabase.CARDS[card.card_name]
	var action = card_data[action_index]
	if action == null:
		return [null, null, INF]

	var value = card_data[value_index]
	var priority = card_data[priority_index]
	var tags = card_data[tags_index]

	return [action, value, priority, tags_index]


# Activates a card action, returns the Tween for awaiting
# Now returns void but is awaitable
# Step 1: Just move the card to the center point
func move_card_to_battle_point(card) -> Tween:
	if card == null: return null
	
	var target_pos = %OpponentCardPoint.global_position if card.OWNER == "Opponent" else %PlayerCardPoint.global_position
	var move_tween = get_tree().create_tween()
	
	if card.global_position.distance_to(target_pos) > 10:
		move_tween.set_parallel(true)
		move_tween.tween_property(card, "position", target_pos, CARD_MOVE_SPEED)
		move_tween.tween_property(card, "scale", Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE), CARD_MOVE_SPEED)
		card.z_index = 10
	else:
		# If already there, return a finished tween or null
		return null
		
	return move_tween

# Step 2: Play the animation and apply the specific action
func execute_card_action(card, action_data) -> Tween:
	if action_data[0] == null: return null

	var action_tween = get_tree().create_tween()
	
	# Play Animation
	action_tween.tween_callback(func():
		if card.has_node("AnimationPlayer"):
			card.get_node("AnimationPlayer").play("card_basic_use")
	)
	
	# Wait for animation duration
	var duration = 0.5
	if card.has_node("AnimationPlayer") and card.get_node("AnimationPlayer").has_animation("card_basic_use"):
		duration = card.get_node("AnimationPlayer").get_animation("card_basic_use").length
	
	action_tween.tween_interval(duration)
	action_tween.tween_callback(apply_action.bind(card, action_data))
	
	return action_tween

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
	
	# CURRENTLY WE JUST APPLY THE MULT TO THE VALUE, BUT LATER ADD A SYSTEM TO CHECK THE TAGS AND THEN APPLY THE MULT TO THE VALUE DEPENDING ON TAGS 
	#if action ["Attack", "Shield"]:
		#value = value * self_target.current_mult
	
	value = value * self_target.current_mult
	# After applying current mult, apply next mult, this is to prevent issues such as same-turn divides
	
	if self_target.nullified == true:
		print("returning ", card.OWNER, " action as it was nullified")
		return
	
	match action:
		"Attack":
			print(card.OWNER, " deals ", value, " damage.")
			target.health -= value
		"Shield":
			print(card.OWNER, " gains ", value, " shield.")
			self_target.health += value
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

func _input(event: InputEvent) -> void:
	# Detect any left mouse click that isn't on a UI button
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		battle_click_received.emit()
