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
var empty_opponent_card_slots = []

const SMALLER_CARD_SCALE = 1.05
const CARD_MOVE_SPEED = 0.2

func _ready() -> void:
	battle_timer.one_shot = true
	battle_timer.wait_time = 0.2
	
	empty_opponent_card_slots.append($"../CardSlots/OpponentCardSlot")
	empty_opponent_card_slots.append($"../CardSlots/OpponentCardSlot2")
	empty_opponent_card_slots.append($"../CardSlots/OpponentCardSlot3")


func _on_end_turn_button_pressed() -> void:
	$"../EndTurnButton".disabled = true
	$"../EndTurnButton".visible = false
	opponent_turn()


func opponent_turn():
	# wait a bit
	await wait(0.2)
	
	# Draw a card if the deck isn't empty
	if %OpponentDeck.opponent_deck.size() != 0:
		%OpponentDeck.draw_card()
		await wait(1)
	
	if empty_opponent_card_slots.size() != 0:
		await play_opponent_cards() # just picks highest id for now
	
	end_opponent_turn()

func play_opponent_cards():
	# Make a safe copy of the hand to iterate
	var hand = %OpponentHand.opponent_hand.duplicate()

	# Play cards while there are cards in hand and free slots
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


# Helper function for sort_custom
func _sort_card_descending(a, b):
	# Return -1 if a should come before b, 1 if after
	if a.card_id == b.card_id:
		return 0
	elif a.card_id > b.card_id:
		return -1
	else:
		return 1

func end_opponent_turn():
	%PlayerDeck.reset_draw()
	start_clash()
	
func start_clash():
	#attack()
	await run_action_phase()
	$"../EndTurnButton".disabled = false
	$"../EndTurnButton".visible = true
	
func run_action_phase():
	var slot_count = max(player_slots.size(), opponent_slots.size())

	for slot_index in range(slot_count):
		var player_card = null
		var opponent_card = null

		if slot_index < player_slots.size():
			player_card = player_slots[slot_index].card

		if slot_index < opponent_slots.size():
			opponent_card = opponent_slots[slot_index].card

		# ---- ACTION 1 (SIMULTANEOUS) ----
		print(" ")
		print("action 1")
		await resolve_action_step(player_card, opponent_card, 1, 2)
		await wait(3.3)

		# ---- ACTION 2 (SIMULTANEOUS) ----
		print("action 2")
		await resolve_action_step(player_card, opponent_card, 3, 4)
		await wait(5.3)

func resolve_action_step(card_a, card_b, action_index, value_index):
	var tweens = []

	if card_a != null:
		var t = activate_card_action(card_a, action_index, value_index)
		if t:
			tweens.append(t)

	if card_b != null:
		var t = activate_card_action(card_b, action_index, value_index)
		if t:
			tweens.append(t)

	# Wait until BOTH finish
	for tween in tweens:
		await tween.finished

func activate_card_action(card, action_index, value_index):
	var card_data = CardDatabase.CARDS[card.card_name]

	var action = card_data[action_index]
	var value = card_data[value_index]

	if action == null:
		return null

	print("card name:", card.card_name, " uses:", action," value:", value)

	# Example visual motion
	var new_y = 0 if card.cards_current_slot in opponent_slots else 1080
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position:y", new_y, CARD_MOVE_SPEED)

	# Apply gameplay effect
	apply_action(card, action, value)

	return tween

func apply_action(card, action, value):
	match action:
		"Attack":
			print("Deal: ", value, "damage")
		"Shield":
			print("Gain shield", value)

func perform_action(acting_card, actor):
	var new_pos_y
	if actor == "Opponent":
		new_pos_y = 1080
	else:
		new_pos_y = 0
	
	var new_pos = Vector2(acting_card.position.x, new_pos_y)
	var tween = get_tree().create_tween()
	tween.tween_property(acting_card, "position", new_pos, CARD_MOVE_SPEED)

	print("activate card")
	
	await tween.finished
	await wait(15.0) # small pause between attacks, doesnt activate when tween is finished, figure that out

func wait(wait_time):
	battle_timer.wait_time = wait_time
	battle_timer.start()
	await battle_timer.timeout
