extends Node

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
	$"../EndTurnButton".disabled = false
	$"../EndTurnButton".visible = true
	

func attack(attacking_card, attacker):
	var new_pos_y
	if attacker == "Opponent":
		new_pos_y = 1080
	else:
		new_pos_y = 0
	
	var new_pos = Vector2(attacking_card.position.x, new_pos_y)
	var tween = get_tree().create_tween()
	tween.tween_property(attacking_card, "position", new_pos, CARD_MOVE_SPEED)

	print("activate card")

func wait(wait_time):
	battle_timer.wait_time = wait_time
	battle_timer.start()
	await battle_timer.timeout
