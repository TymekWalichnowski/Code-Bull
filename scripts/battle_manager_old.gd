extends Node

func run_action_phase():
	var slot_count = max(player_slots.size(), opponent_slots.size()) # chooses the larger of the two slot counts

	for slot_index in range(slot_count):
		print("\n ---- CARD SLOT " , slot_index + 1, " ----" )
		var player_card = null # initialize cards as null before assigning them, to be safe
		var opponent_card = null

		if slot_index < player_slots.size():
			player_card = player_slots[slot_index].card

		if slot_index < opponent_slots.size():
			opponent_card = opponent_slots[slot_index].card
			
		# resetting nullifications
		%Player.nullified = false
		%Opponent.nullified = false
		
		# ---- ACTION 1 ---- don't need to skip this as card always has 1 action
		print("\n -- action 1 --")
		await resolve_action_step(player_card, opponent_card, 1, 2)
		await wait(2.0)

		# ---- ACTION 2 ---- checks if card actions are null, if they are, skips the action
		if has_action(player_card, 3) or has_action(opponent_card, 3, ):
			print("\n -- action 2 --")
			await resolve_action_step(player_card, opponent_card, 3, 4)
			await wait(2.0)
		else:
			print("\n action 2 skipped (both null)")

		# ---- ACTION 3 ---- checks if card actions are null, if they are, skips the action
		if has_action(player_card, 5) or has_action(opponent_card, 5):
			print("\n -- action 3 --")
			await resolve_action_step(player_card, opponent_card, 5, 6)
			await wait(2.0)
		else:
			print("\n action 3 skipped (both null)")
		
		# Move used cards to graveyards
		collect_used_card(player_card)
		collect_used_card(opponent_card)
		reset_opponent_slots()
		

func resolve_action_step(player_card, opponent_card, action_index, value_index):
	
	# Phase 1 - Getting the intent of the cards
	var tweens = []
	
	if player_card != null: # checking that there's a player card
		var t = check_card_action(player_card, action_index, value_index) 
		if t:
			tweens.append(t)

	if opponent_card != null: # checking that there's an opponent card
		var t = check_card_action(opponent_card, action_index, value_index)
		if t:
			tweens.append(t)
	
	$"../PlayerHealth".text = str(%Player.health)
	$"../OpponentHealth".text = str(%Opponent.health) 
	# Add a proper way of differentiating the card owner and their enemies later, clean this up
	
	
	# Phase 2 - Actually applying the animations and effects
	if player_card != null: # checking that there's a player card
		var t = activate_card_action(player_card, action_index, value_index) 
		if t:
			tweens.append(t)

	if opponent_card != null: # checking that there's an opponent card
		var t = activate_card_action(opponent_card, action_index, value_index) 
		if t:
			tweens.append(t)

	# Use until BOTH finish
	for tween in tweens:
		await tween.finished

func check_card_action(card, action_index, value_index): # Activate that card's action, tells it what action to use and the value associated with it 
	var card_data = CardDatabase.CARDS[card.card_name] # Gets the card from the database by checking its name

	var action = card_data[action_index]
	var value = card_data[value_index]

	if action == null: # Returns if no action
		print("USER:", card.OWNER, " had no action.")
		return null

	# Displaying what the card action is
	print("USER:", card.OWNER, " CARD_NAME:", card.card_name, " WANTS_TO_USE_ACTION:", action," VALUE:", value)
	
	var target
	var self_target
	
	if card.OWNER == "Player":
		target = %Opponent
		self_target = %Player
	else:
		target = %Player
		self_target = %Opponent
		
	match action:
		"Attack":
			print(card.OWNER,"wants to attack")
		"Shield":
			print(card.OWNER, "wants to shield")
		"Nullify":
			print(card.OWNER, " wants to nullify ")
			target.nullified = true
		
	
func activate_card_action(card, action_index, value_index): # Activate that card's action, tells it what action to use and the value associated with it 
	var card_data = CardDatabase.CARDS[card.card_name] # Gets the card from the database by checking its name

	var action = card_data[action_index]
	var value = card_data[value_index]

	if action == null: # Returns if no action
		print("USER:", card.OWNER, " had no action.")
		return null

	# Displaying what the card action is
	print("USER:", card.OWNER, " CARD_NAME:", card.card_name, " USED_ACTION:", action," VALUE:", value)
	
	# Example animation - replace later
	var new_pos = $"../OpponentCardPoint".global_position if card.cards_current_slot in opponent_slots else $"../PlayerCardPoint".global_position
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", new_pos, CARD_MOVE_SPEED)
	tween.finished.connect(func():
		await get_tree().create_timer(0.2).timeout # just using a temporary timer, add functionality for a pause + left click.
		if card.OWNER == "Player":
			if %Player.nullified == true: # dont apply if nullfied
				print("skipping player card application, it was nullified")
			else:
				apply_action(card, action, value)
		else:
			if %Opponent.nullified == true: # dont apply if nullfied
				print("skipping opponent card application, it was nullified")
			else:
				apply_action(card, action, value)
			
	)
	return tween # Returns the tween, lets us know if it's finished or not

func apply_action(card, action, value):
	var target
	var self_target
	
	if card.OWNER == "Player":
		target = %Opponent
		self_target = %Player
	else:
		target = %Player
		self_target = %Opponent
		
	match action:
		"Attack":
			print(card.OWNER, " deals ", value, " damage.")
			target.health -= value
		"Shield":
			print(card.OWNER, " gains ", value, " shield.")
			self_target.health += value
	
	# Change animation functionality elsewher
	card.get_node("AnimationPlayer").play("card_basic_use")
	
	$"../PlayerHealth".text = str(%Player.health)
	$"../OpponentHealth".text = str(%Opponent.health) 
	# Add a proper way of differentiating the card owner and their enemies later, clean this up

func has_action(card, action_index) -> bool: # checking if a card has an action
	if card == null:
		return false
	return CardDatabase.CARDS[card.card_name][action_index] != null

func collect_used_card(card):
	if card == null:
		return
	
	if card.OWNER == "Player":
		player_graveyard.append(card.card_name)
	else:
		opponent_graveyard.append(card.card_name)
	
	# Free the node from scene
	if is_instance_valid(card):
		card.queue_free()
	
	# Clear its slot
	if card.cards_current_slot:
		card.cards_current_slot.card = null
		card.cards_current_slot.card_in_slot = false
		card.cards_current_slot = null
