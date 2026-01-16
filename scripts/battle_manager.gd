extends Node

var player_graveyard = []
var opponent_graveyard = []

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

func _ready() -> void:
	battle_timer.one_shot = true
	battle_timer.wait_time = 0.2
	
	empty_opponent_card_slots.append($"../CardSlots/OpponentCardSlot")
	empty_opponent_card_slots.append($"../CardSlots/OpponentCardSlot2")
	empty_opponent_card_slots.append($"../CardSlots/OpponentCardSlot3")
	
	# A bit awkward, clean this up
	%Player.health = STARTING_HEALTH
	%Opponent.health = STARTING_HEALTH
	$"../PlayerHealth".text = str(%Player.health)
	$"../OpponentHealth".text = str(%Opponent.health)
	opponent_turn()

func _on_end_turn_button_pressed() -> void:
	await run_action_phase()
	opponent_turn()
	%PlayerDeck.draw_card()
	
	$"../EndTurnButton".disabled = true
	$"../EndTurnButton".visible = false

func opponent_turn():
	# wait a bit
	await wait(0.2)
	
	# Draw a card if the deck isn't empty
	if %OpponentDeck.opponent_deck.size() != 0:
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
		
		
		# ---- ACTION 1 ---- don't need to skip this as card always has 1 action
		print("\n -- action 1 --")
		await resolve_action_step(player_card, opponent_card, 1, 2)
		await wait(2.0)

		# ---- ACTION 2 ---- checks if card actions are null, if they are, skips the action
		if has_action(player_card, 3) or has_action(opponent_card, 3):
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
	var tweens = []
	
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
		
func reset_opponent_slots():
	empty_opponent_card_slots.clear()
	for slot in opponent_slots:
		if not slot.card_in_slot:
			empty_opponent_card_slots.append(slot)

func wait(wait_time):
	battle_timer.wait_time = wait_time
	battle_timer.start()
	await battle_timer.timeout
