extends Node

signal battle_click_received

@onready var action_manager = %ActionManager
@onready var passive_manager = %PassiveManager
@onready var token_manager = %TokenManager 

@onready var player_slots_all = [$"../CardSlots/CardSlot", $"../CardSlots/CardSlot2", $"../CardSlots/CardSlot3", $"../CardSlots/CardSlot4", $"../CardSlots/CardSlot5"]
@onready var opponent_slots_all = [$"../CardSlots/CardSlotOpponent1", $"../CardSlots/CardSlotOpponent2", $"../CardSlots/CardSlotOpponent3", $"../CardSlots/CardSlotOpponent4", $"../CardSlots/CardSlotOpponent5"]

var player_slots = []
var opponent_slots = []

@onready var battle_timer = %BattleTimer

const STARTING_HEALTH = 10.0
const SMALLER_CARD_SCALE = 1.05
const CARD_MOVE_SPEED = 0.2
const START_DRAW_COUNT = 6 
const SLOT_GAP = 170.0

var turn_count: int = 0
var player_has_initiative: bool = true
var empty_opponent_card_slots = []
var player_snapshot: Dictionary = {}
var opponent_snapshot: Dictionary = {}
var board_locked: bool = false 

func _ready() -> void:
	battle_timer.one_shot = true
	battle_timer.wait_time = 0.2
	advance_turn()
	
	%Player.current_health = STARTING_HEALTH
	%Opponent.current_health = STARTING_HEALTH
	%PlayerDeck.prepare_deck()
	%OpponentDeck.prepare_deck()
	
	for i in range(START_DRAW_COUNT):
		if i < 5: %PlayerDeck.draw_card()
		if i < 6: %OpponentDeck.draw_card()
		await get_tree().create_timer(0.4).timeout
	
	%PlayerDeck.spawn_starting_passives()
	%OpponentDeck.spawn_starting_passives()
	
	await get_tree().create_timer(0.2).timeout
	await trigger_passives("On_Turn_Start")
	analyze_board_state()
	opponent_turn()

func _process(_delta: float) -> void:
	%PlayerLabel.text = "HP: %.1f  |\n Shield: %.1f " % [%Player.current_health, %Player.current_shield]
	%Player/SpeedHolder/SpeedLabel.text = str(%Player.speed)
	%OpponentLabel.text = "HP: %.1f  |\n Shield: %.1f" % [%Opponent.current_health, %Opponent.current_shield]
	%Opponent/SpeedHolder/SpeedLabel.text = str(%Opponent.speed)
	analyze_board_state()

func advance_turn():
	turn_count += 1
	if has_node("%TurnLabel"):
		%TurnLabel.text = "Turn: " + str(turn_count)
	
	var slot_limit = 3
	if turn_count == 2:
		slot_limit = 4
	elif turn_count >= 3:
		slot_limit = 5
	
	setup_active_slots(slot_limit)

func setup_active_slots(limit: int):
	player_slots.clear()
	opponent_slots.clear()
	
	var viewport_width = get_viewport().get_visible_rect().size.x
	var center_x = viewport_width / 2.0
	var start_x = center_x - ((limit - 1) * SLOT_GAP) / 2.0
	
	for i in range(5):
		var p_slot = player_slots_all[i]
		var o_slot = opponent_slots_all[i]
		var active = (i < limit)
		
		# Set Visibility
		p_slot.visible = active
		o_slot.visible = active
		
		# --- STERN FIX: Physically disable the collision shapes ---
		# We find the CollisionShape2D inside the Area2D and disable it entirely.
		# This prevents the Raycast in CardManager from ever seeing the slot.
		var p_collision = p_slot.find_child("CollisionShape2D", true)
		var o_collision = o_slot.find_child("CollisionShape2D", true)
		
		if p_collision:
			p_collision.disabled = !active
		if o_collision:
			o_collision.disabled = !active
		# -----------------------------------------------------------

		if active:
			player_slots.append(p_slot)
			opponent_slots.append(o_slot)
			var target_x = start_x + (i * SLOT_GAP)
			p_slot.global_position.x = target_x
			o_slot.global_position.x = target_x
			
			if p_slot.card: p_slot.card.position = p_slot.global_position
			if o_slot.card: o_slot.card.position = o_slot.global_position

func _on_end_turn_button_pressed() -> void:
	$"../EndTurnButton".disabled = true
	$"../EndTurnButton".visible = false
	board_locked = true
	
	await run_activation_phase()
	await trigger_tokens("On_Phase_End")
	
	%Player.speed = randi_range(1, 5)
	%Opponent.speed = randi_range(1, 5)
	
	advance_turn()
	%PlayerDeck.draw_card()
	%PlayerDeck.draw_card()
	
	await trigger_passives("On_Turn_Start")
	await trigger_tokens("On_Turn_Start")
	
	board_locked = false
	opponent_turn()

func opponent_turn():
	await wait(0.2)
	%OpponentDeck.draw_card()
	await wait(1)
	reset_opponent_slots()
	if empty_opponent_card_slots.size() != 0:
		await play_opponent_cards() 
	end_opponent_turn()

func play_opponent_cards():
	var hand = %OpponentHand.opponent_hand.duplicate()
	while hand.size() > 0 and empty_opponent_card_slots.size() > 0:
		var card_to_play = hand[0]
		for card in hand:
			if card.card_id > card_to_play.card_id: card_to_play = card

		var slot = empty_opponent_card_slots[0]
		var tween1 = get_tree().create_tween().set_parallel(true)
		tween1.tween_property(card_to_play, "position", slot.position, CARD_MOVE_SPEED)
		tween1.tween_property(card_to_play, "scale", Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE), CARD_MOVE_SPEED)
		tween1.tween_property(card_to_play, "rotation", 0, CARD_MOVE_SPEED)
		
		card_to_play.get_node("CardImage").visible = true
		card_to_play.get_node("AnimationPlayer").play("card_flip")
		card_to_play.play_audio("place")
		await tween1.finished
		
		card_to_play.interactable = true
		slot.set_card(card_to_play)
		%OpponentHand.remove_card_from_hand(card_to_play)
		empty_opponent_card_slots.erase(slot)
		hand.erase(card_to_play)

func end_opponent_turn():
	$"../EndTurnButton".disabled = false
	$"../EndTurnButton".visible = true

func reset_opponent_slots():
	empty_opponent_card_slots.clear()
	for slot in opponent_slots:
		if is_instance_valid(slot) and not slot.card_in_slot:
			empty_opponent_card_slots.append(slot)

func wait(wait_time):
	battle_timer.wait_time = wait_time
	battle_timer.start()
	await battle_timer.timeout

func run_activation_phase():
	var slot_count = max(player_slots.size(), opponent_slots.size())
	player_has_initiative = (%Player.speed > %Opponent.speed)
	
	await wait(0.4)
	
	for slot_index in range(slot_count):
		var order = ["Player", "Opponent"] if player_has_initiative else ["Opponent", "Player"]
		await trigger_passives("On_Slot_Start", slot_index)
		await trigger_tokens("On_Slot_Start")
		
		for side in order:
			var active_set = player_slots if side == "Player" else opponent_slots
			if slot_index >= active_set.size(): continue
			
			var slot = active_set[slot_index]
			var card = slot.card
			var current_side_node = %Player if side == "Player" else %Opponent
			
			if not card: continue
			if current_side_node.nullified:
				current_side_node.nullified = false 
				collect_used_card(card) 
				await wait(0.3)
				continue 

			await move_card_to_battle_point(card).finished
			
			var runs = 1 + card.retriggers
			for run_idx in range(runs):
				for action_idx in range(card.card_data.actions.size()):
					if card.card_data.actions[action_idx] != null:
						await action_manager.execute_card_action(card, action_idx)
						await wait(0.6)
			
			collect_used_card(card)
			await wait(0.3)

		if slot_index < player_slots.size(): player_slots[slot_index].clear_buffs()
		if slot_index < opponent_slots.size(): opponent_slots[slot_index].clear_buffs()
		reset_opponent_slots()
		await wait(0.6)

func move_card_to_battle_point(card) -> Tween:
	var target_pos = %PlayerCardPoint.global_position if card.card_owner == "Player" else %OpponentCardPoint.global_position 
	var move_tween = get_tree().create_tween().set_parallel(true)
	move_tween.tween_property(card, "position", target_pos, CARD_MOVE_SPEED)
	move_tween.tween_property(card, "scale", Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE), CARD_MOVE_SPEED)
	move_tween.tween_property(card, "rotation", 0, CARD_MOVE_SPEED) 
	card.z_index = 10
	return move_tween

func collect_used_card(card):
	if card == null: return
	if card.cards_current_slot:
		card.cards_current_slot.remove_card()
	card.retriggers = 0
	card.update_retrigger_visuals()
	if card.card_data:
		card.card_data.multiplier = 1.0
		for action in card.card_data.actions:
			if action != null: action.action_multiplier = 1.0
	if card.card_owner == "Player":
		%PlayerDeck.graveyard.append(card.card_data)
	else:
		%OpponentDeck.graveyard.append(card.card_data)
	card.queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		battle_click_received.emit()

func trigger_passives(trigger_type: String, current_slot_idx: int = -1, side: String = "Both"):
	await passive_manager.trigger_passives(trigger_type, current_slot_idx, side)

func trigger_tokens(trigger_type: String, side: String = "Both"):
	await token_manager.trigger_tokens(trigger_type, side)

func analyze_board_state():
	if not board_locked:
		player_snapshot = _analyze_slots(player_slots)
		opponent_snapshot = _analyze_slots(opponent_slots)
	_update_board_label()

func _update_board_label():
	var display_text = "--- PLAYER BOARD ---\n"
	display_text += "Slots: " + str(player_snapshot.slot_types) + "\n"
	display_text += "Chain: %dx %s\n\n" % [player_snapshot.highest_chain_length, player_snapshot.highest_chain_type]
	display_text += "--- OPPONENT BOARD ---\n"
	display_text += "Slots: " + str(opponent_snapshot.slot_types) + "\n"
	display_text += "Chain: %dx %s" % [opponent_snapshot.highest_chain_length, opponent_snapshot.highest_chain_type]
	if has_node("%BoardStateLabel"):
		%BoardStateLabel.text = display_text

func _analyze_slots(slots_array: Array) -> Dictionary:
	var type_counts = {}
	var current_chain_type = ""
	var current_chain_length = 0
	var highest_chain_type = ""
	var highest_chain_length = 0
	var slot_types = []
	for slot in slots_array:
		if is_instance_valid(slot) and slot.card_in_slot and slot.card and slot.card.card_data:
			var c_type = slot.card.card_data.type
			slot_types.append(c_type)
			type_counts[c_type] = type_counts.get(c_type, 0) + 1
			if c_type == current_chain_type:
				current_chain_length += 1
			else:
				current_chain_type = c_type
				current_chain_length = 1
			if current_chain_length > highest_chain_length:
				highest_chain_length = current_chain_length
				highest_chain_type = current_chain_type
		else:
			slot_types.append("Empty")
			current_chain_type = ""
			current_chain_length = 0
	return {"slot_types": slot_types, "type_counts": type_counts, "highest_chain_type": highest_chain_type, "highest_chain_length": highest_chain_length}
