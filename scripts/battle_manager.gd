extends Node

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

func run_check_phase():
	var slot_count = max(player_slots.size(), opponent_slots.size()) # chooses the larger of the two slot counts

	for slot_index in range(slot_count):
		print("\n ---- CARD SLOT " , slot_index + 1, " ----" ) # printing the current slot
		var player_card = null # initialize cards as null before assigning them, to be safe
		var opponent_card = null
		
		# resetting nullifications
		if %Player.nullified == true:
			%Player.nullified = false
		if %Opponent.nullified == true:
			%Opponent.nullified = false

		if slot_index < player_slots.size():
			player_card = player_slots[slot_index].card
		if slot_index < opponent_slots.size():
			opponent_card = opponent_slots[slot_index].card
		
		
		# ---- ACTION 1 ---- don't need to skip this as card always has 1 action
		print("\n -- action 1 --")
		await resolve_action_step(player_card, opponent_card, 1, 2, 3, 4)
		await wait(1.0)

		# ---- ACTION 2 ---- checks if card actions are null, if they are, skips the action
		if has_action(player_card, 5) or has_action(opponent_card, 5, ):
			print("\n -- action 2 --")
			await resolve_action_step(player_card, opponent_card, 5, 6, 7, 8)
			await wait(1.0)
		else:
			print("\n action 2 skipped (both null)")

		# ---- ACTION 3 ---- checks if card actions are null, if they are, skips the action
		if has_action(player_card, 9) or has_action(opponent_card, 9, ):
			print("\n -- action 3 --")
			await resolve_action_step(player_card, opponent_card, 9, 10, 11, 12)
			await wait(1.0)
		else:
			print("\n action 3 skipped (both null)")
		
		# Move used cards to graveyards
		# Move used cards to graveyards
		collect_used_card(player_card)
		collect_used_card(opponent_card)
		reset_opponent_slots()

func resolve_action_step(player_card, opponent_card, action_index, value_index, priority_index, tags_index):
	# PHASE 1, checking actions
	var pending_player_action_data = []
	var pending_opponent_action_data = []

	if player_card != null:
		pending_player_action_data = check_card_action(player_card, action_index, value_index, priority_index)
	if opponent_card != null:
		pending_opponent_action_data = check_card_action(opponent_card, action_index, value_index, priority_index)

	# PHASE 2, activating actions
	var action_queue = []

	if player_card != null and pending_player_action_data[0] != null:
		action_queue.append({
			"card": player_card,
			"owner": "Player",
			"action_data": pending_player_action_data,
			"priority": pending_player_action_data[2]
		})
	if opponent_card != null and pending_opponent_action_data[0] != null:
		action_queue.append({
			"card": opponent_card,
			"owner": "Opponent",
			"action_data": pending_opponent_action_data,
			"priority": pending_opponent_action_data[2]
		})

	# Sort by priority
	action_queue.sort_custom(func(a, b):
		return a["priority"] < b["priority"]
	)

	# Start all animations and collect tweens
	var tweens = []
	for entry in action_queue:
		var tween = activate_card_action(entry["card"], entry["action_data"])
		if tween:
			tweens.append(tween)

	# Wait for all tweens to finish simultaneously
	for tween in tweens:
		if tween:
			await tween.finished

	# Small delay after all
	await get_tree().create_timer(0.25).timeout
	
func has_action(card, action_index) -> bool: # checking if a card has an action
	if card == null:
		return false
	return CardDatabase.CARDS[card.card_name][action_index] != null

func check_card_action(card, action_index, value_index, priority_index): # Activate that card's action, tells it what action to use and the value associated with it 
	var card_data = CardDatabase.CARDS[card.card_name] # Gets the card from the database by checking its name

	var action = card_data[action_index]
	var value = card_data[value_index]
	var priority = card_data[priority_index]
	
	if action == null: # Returns if no action
		print("USER:", card.OWNER, " has no action.")
		return [null, null, INF]
	
	# sets up mult if we know the card has an action, so same-turn divides are not an issue kinda unclean,
	var target
	var self_target
	if card.OWNER == "Player":
		target = %Opponent
		self_target = %Player
	else:
		target = %Player
		self_target = %Opponent
	self_target.current_mult = self_target.next_mult
	self_target.next_mult = 1.0
	
	# Displaying what the card action is
	print("USER:", card.OWNER, " CARD NAME:", card.card_name, " ACTION:", action," VALUE:", value, " PRIORITY:", priority)
	return [action, value, priority]

func activate_card_action(card, action_data):
	var action = action_data[0]
	var value = action_data[1]

	if action == null:
		print("USER:", card.OWNER, " had no action.")
		return null

	print("USER:", card.OWNER, " CARD NAME:", card.card_name, " ACTIVATING ACTION:", action, " VALUE:", value)

	# Target position
	var new_pos = $"../OpponentCardPoint".global_position if card.cards_current_slot in opponent_slots else $"../PlayerCardPoint".global_position

	# Create a tween that moves AND scales the card
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", new_pos, CARD_MOVE_SPEED)
	tween.tween_property(card, "scale", Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE), CARD_MOVE_SPEED)

	# When tween finishes, play the card animation AND apply the action
	tween.finished.connect(func():
		if card.has_node("AnimationPlayer"):
			card.get_node("AnimationPlayer").play("card_basic_use")
		apply_action(card, action_data)
	)

	return tween

	

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
	self_target.current_mult = self_target.next_mult
	self_target.next_mult = 1.0
	
	if self_target.nullified == true:
		print("returning ", card.OWNER, " action as it was nullified")
		return
	
	match action:
		"Attack":
			print(card.OWNER, " deals ", value, " damage.")
			target.health -= value
			self_target.current_mult = 1
		"Shield":
			print(card.OWNER, " gains ", value, " shield.")
			self_target.health += value
			self_target.current_mult = 1
		"Multiply_Next_Value":
			print(card.OWNER, " gains ", value, " mult.") 
			self_target.next_mult = self_target.next_mult * 2
		"Divide_Next_Value":
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
			
	
	# Change animation functionality elsewher
	card.get_node("AnimationPlayer").play("card_basic_use")
	
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
