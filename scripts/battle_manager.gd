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
	var slot_count = max(player_slots.size(), opponent_slots.size())

	for slot_index in range(slot_count):
		print("\n ---- CARD SLOT ", slot_index + 1, " ----")

		# Reset nullifications each slot
		%Player.nullified = false
		%Opponent.nullified = false

		# Get cards in slot
		var player_card = player_slots[slot_index].card if slot_index < player_slots.size() else null
		var opponent_card = opponent_slots[slot_index].card if slot_index < opponent_slots.size() else null

		# Action indices to check
		var action_indices = [1, 5, 9]

	# Loop over each action index
		for action_index in action_indices:
		# PLAYER ACTION
			if player_card and has_action(player_card, action_index):
				print("\n[PLAYER CARD ACTION] Index:", action_index)
				var action_data = check_card_action(player_card, action_index, action_index + 1, action_index + 2)
				var tween = activate_card_action(player_card, action_data)
				if tween != null:
					await tween.finished  # Wait for the animation to finish before continuing

			# OPPONENT ACTION
			if opponent_card and has_action(opponent_card, action_index):
				print("\n[OPPONENT CARD ACTION] Index:", action_index)
				var action_data = check_card_action(opponent_card, action_index, action_index + 1, action_index + 2)
				var tween = activate_card_action(opponent_card, action_data)
				if tween != null:
					await tween.finished  # Wait for the animation to finish before continuing

		# Small pause after both player and opponent actions
		await wait(1.5)

		# Move used cards to graveyards
		collect_used_card(player_card)
		collect_used_card(opponent_card)

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
func activate_card_action(card, action_data) -> Tween:
	if action_data[0] == null:
		return null

	var action = action_data[0]
	var value = action_data[1]

	# Determine target position
	var new_pos = $"../OpponentCardPoint".global_position if card.cards_current_slot in opponent_slots else $"../PlayerCardPoint".global_position

	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", new_pos, CARD_MOVE_SPEED)
	tween.tween_property(card, "scale", Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE), CARD_MOVE_SPEED)

	tween.finished.connect(func():
		await _play_animation_and_apply(card, action_data)
	)

	return tween

# Await this to guarantee animation plays before applying effect
func _play_animation_and_apply(card, action_data) -> void:
	if card.has_node("AnimationPlayer"):
		var anim = card.get_node("AnimationPlayer")
		anim.play("card_basic_use")
		await anim.animation_finished
	apply_action(card, action_data)

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
