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
	await run_activation_phase()
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

func run_activation_phase():
	
	var slot_count = max(player_slots.size(), opponent_slots.size()) # chooses the larger of the two slot counts
	
	for slot_index in range(slot_count):
		print("\n ---- CARD SLOT " , slot_index + 1, " ----" )
		
		var player_card = player_slots[slot_index].card
		var opponent_card = opponent_slots[slot_index].card
		var player_action_manager = player_slots.get_node("CardActionManager")
		
		if slot_index < player_slots.size():
			player_card = player_slots[slot_index].card

		if slot_index < opponent_slots.size():
			opponent_card = opponent_slots[slot_index].card
		
		## Cards moves to position
		move_card_to_battle_point(player_card)
		move_card_to_battle_point(opponent_card)
		
	## slot 1
	
	#priority 0 animations
	#Apply priority 0 effect [e.g nullification]
	#
	#priority 1 animations
	#Apply priority 1 effect [e.g shield, multiply]
	#
	#priority 2 animations
	#Apply priority 2 effect [e.g attack]
	#
	
#priority

	pass

func move_card_to_battle_point(card):
	var target_pos
	if card.card_owner == "Player":
		target_pos = %PlayerCardPoint.global_position 
	else:
		target_pos = %OpponentCardPoint.global_position 
	var move_tween = get_tree().create_tween()
	move_tween.tween_property(card, "position", target_pos, CARD_MOVE_SPEED)
	move_tween.tween_property(card, "scale", Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE), CARD_MOVE_SPEED)
	card.z_index = 10

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
