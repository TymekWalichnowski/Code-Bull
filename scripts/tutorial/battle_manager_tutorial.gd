extends "res://scripts/battle_manager.gd"

func _ready() -> void:
	battle_timer.one_shot = true
	battle_timer.wait_time = 0.2
	advance_turn()
	
	%Player.current_health = STARTING_HEALTH
	%Enemy.current_health = STARTING_HEALTH
	%PlayerDeck.prepare_deck()
	%EnemyDeck.prepare_deck()
	%Player.speed = 3
	%Enemy.speed = 2
	
	for i in range(START_DRAW_COUNT):
		if i < 1: %PlayerDeck.draw_card()
		if i < 1: %EnemyDeck.draw_card()
		await get_tree().create_timer(0.4).timeout
	
	await trigger_passives("On_Turn_Start")
	analyze_board_state()
	await enemy_turn()
	%TutorialText.text = "Welcome to card mania!\n
See that red card above the opponent? That's the card they're planning to use on you.
See those yellow diamonds with numbers on them? That's your speed. Whoever has the higher speed will play their cards first.
Slot in a shield card to defend yourself, then press activate!"

func _process(_delta: float) -> void:
	%Player/HealthHolder/HealthLabel.text = "%d" % %Player.current_health
	%Player/ShieldHolder/ShieldLabel.text = "%d" % %Player.current_shield
	%PlayerSpeedHolder/SpeedLabel.text = "%d" % %Player.speed
	%Enemy/HealthHolder/HealthLabel.text = "%d" % %Enemy.current_health
	%Enemy/ShieldHolder/ShieldLabel.text = "%d" % %Enemy.current_shield
	%EnemySpeedHolder/SpeedLabel.text = "%d" % %Enemy.speed
	analyze_board_state()

func advance_turn():
	turn_count += 1
	if has_node("%TurnLabel"):
		%TurnLabel.text = "Turn: " + str(turn_count)
	
	var slot_limit = 1
	if turn_count == 2:
		slot_limit = 2
	elif turn_count >= 3:
		slot_limit = 3
	
	setup_active_slots(slot_limit)

func setup_active_slots(limit: int):
	player_slots.clear()
	enemy_slots.clear()
	
	var viewport_width = get_viewport().get_visible_rect().size.x
	var center_x = viewport_width / 2.0
	var start_x = center_x - ((limit - 1) * SLOT_GAP) / 2.0
	
	for i in range(5):
		var p_slot = player_slots_all[i]
		var o_slot = enemy_slots_all[i]
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
			enemy_slots.append(o_slot)
			var target_x = start_x + (i * SLOT_GAP)
			p_slot.global_position.x = target_x
			o_slot.global_position.x = target_x
			
			if p_slot.card: p_slot.card.position = p_slot.global_position
			if o_slot.card: o_slot.card.position = o_slot.global_position
	# speed holder positioning
	
	# Calculate the exact X position of the furthest right active slot
	var last_slot_x = start_x + ((limit - 1) * SLOT_GAP)
	
	# Determine how many pixels to the right the speed holder should sit.
	# You will likely need to adjust this number based on your card/slot widths!
	var right_padding = 130.0 
	
	# Fetch the nodes (I used the exact names you provided. If your tree uses
	# "%Player/SpeedHolder" like in your _process function, change the string below!)
	var p_speed_holder = get_node_or_null("%PlayerSpeedHolder")
	var e_speed_holder = get_node_or_null("%EnemySpeedHolder")
	
	if p_speed_holder:
		p_speed_holder.global_position.x = last_slot_x + right_padding
	if e_speed_holder:
		e_speed_holder.global_position.x = last_slot_x + right_padding

func _on_end_turn_button_pressed() -> void:
	$"../EndTurnButton".disabled = true
	$"../EndTurnButton".visible = false
	board_locked = true
	
	await run_activation_phase()
	await trigger_tokens("On_Turn_End")
	
	advance_turn()
	

	if turn_count == 2:
		%Player.speed = 2
		%Enemy.speed = 4
		%PlayerDeck.draw_card()
		await wait(0.2)
		%PlayerDeck.draw_card()
		%TutorialText.text = "Nice going!\n
As the match progresses, you unlock more card slots!
See how the opponent readied up two shield cards?
Try slotting in two of your sword cards."
							  
	elif turn_count == 3:
		%Player.speed = 1
		%Enemy.speed = 3
		%PlayerDeck.draw_card()
		await wait(0.2)
		%PlayerDeck.draw_card()
		await wait(0.2)
		%PlayerDeck.draw_card()
		%TutorialText.text = "Hm!\n
They had the speed advantage that round and their shield absorbed all your damage!
What if you were to hit them with something a little harder? Here is where the true combo-creation of this game comes in: Slot your multiply card in the first and second slots, then a sword in the third."
	elif turn_count == 4:
		%Player.speed = 4
		%Enemy.speed = 2
		%PlayerDeck.draw_card()
		await wait(0.2)
		%PlayerDeck.draw_card()
		await wait(0.2)
		%PlayerDeck.draw_card()
		%TutorialText.text = "Did you see that!? The first multiply card multiplied your second multiply card into a 4x multiply card, which then multiplied your sword card, increasing the attach damage from a measly 2 into a staggering 8,breaking through the opponent's shield and dealing some health damage. \n
Now. Finish him off. Generate some shield and then use a multiply card to boost the power of a double hit card, a card that hits twice in one use!"
	elif turn_count == 5:
		%TutorialText.text = "The Opponent's health hit 0, you won!!!"
		await wait(2.0)
		get_tree().change_scene_to_file("res://scenes/level_select.tscn")
		
	await trigger_passives("On_Turn_Start")
	await trigger_tokens("On_Turn_Start")

	
	board_locked = false
	enemy_turn()

func enemy_turn():
	if turn_count == 2:
		%EnemyDeck.draw_card()
		await wait(0.2)
		%EnemyDeck.draw_card()
	elif turn_count == 3:
		%EnemyDeck.draw_card()
		await wait(0.2)
		%EnemyDeck.draw_card()
		await wait(0.2)
		%EnemyDeck.draw_card()
	elif turn_count == 4:
		%EnemyDeck.draw_card()
		await wait(0.2)
		%EnemyDeck.draw_card()
		await wait(0.2)
		%EnemyDeck.draw_card()
	await wait(0.5)
	reset_enemy_slots()
	if empty_enemy_card_slots.size() != 0:
		await play_enemy_cards() 
	end_enemy_turn()

func play_enemy_cards():
	var hand = %EnemyHand.enemy_hand.duplicate()
	while hand.size() > 0 and empty_enemy_card_slots.size() > 0:
		var card_to_play = hand[0]
		for card in hand:
			if card.card_id > card_to_play.card_id: card_to_play = card

		var slot = empty_enemy_card_slots[0]
		var tween1 = get_tree().create_tween().set_parallel(true)
		tween1.tween_property(card_to_play, "position", slot.position, CARD_MOVE_SPEED)
		tween1.tween_property(card_to_play, "scale", Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE), CARD_MOVE_SPEED)
		tween1.tween_property(card_to_play, "rotation", 0, CARD_MOVE_SPEED)
		
		card_to_play.get_node("%CardImage").visible = true
		card_to_play.get_node("AnimationPlayer").play("card_flip")
		card_to_play.play_audio("place")
		await tween1.finished
		
		card_to_play.interactable = true
		slot.set_card(card_to_play)
		%EnemyHand.remove_card_from_hand(card_to_play)
		empty_enemy_card_slots.erase(slot)
		hand.erase(card_to_play)

func end_enemy_turn():
	$"../EndTurnButton".disabled = false
	$"../EndTurnButton".visible = true

func reset_enemy_slots():
	empty_enemy_card_slots.clear()
	for slot in enemy_slots:
		if is_instance_valid(slot) and not slot.card_in_slot:
			empty_enemy_card_slots.append(slot)

func wait(wait_time):
	battle_timer.wait_time = wait_time
	battle_timer.start()
	await battle_timer.timeout

func run_activation_phase():
	var slot_count = max(player_slots.size(), enemy_slots.size())
	player_has_initiative = (%Player.speed >= %Enemy.speed)
	
	await wait(0.4)
	
	for slot_index in range(slot_count):
		var order = ["Player", "Enemy"] if player_has_initiative else ["Enemy", "Player"]
		await trigger_passives("On_Slot_Start", slot_index)
		await trigger_tokens("On_Slot_Start")
		
		for side in order:
			var active_set = player_slots if side == "Player" else enemy_slots
			if slot_index >= active_set.size(): continue
			
			var slot = active_set[slot_index]
			var card = slot.card
			
			if not card: continue
			
			await move_card_to_battle_point(card).finished
			
			# Nullified card check
			if card.nullified > 0:
				card.nullified = 0
				await card.declare_effect("Nullified!")
				collect_used_card(card) 
				await wait(0.3)
				continue
				
			var runs = 1 + card.retriggers
			for run_idx in range(runs):
				if run_idx > 0:
					await card.declare_effect("Retrigger!")
				for action_idx in range(card.card_data.actions.size()):
					if card.card_data.actions[action_idx] != null:
						await action_manager.execute_card_action(card, action_idx)
						await wait(0.6)
			
			collect_used_card(card)
			await wait(0.3)

		if slot_index < player_slots.size(): player_slots[slot_index].clear_buffs()
		if slot_index < enemy_slots.size(): enemy_slots[slot_index].clear_buffs()
		reset_enemy_slots()
		await wait(0.6)
	# Making slots visible again
	for slot in player_slots:
		slot.visible = true
	for slot in enemy_slots:
		slot.visible = true

func move_card_to_battle_point(card) -> Tween:
	var target_pos = %PlayerCardPoint.global_position if card.card_owner == "Player" else %EnemyCardPoint.global_position 
	var move_tween = get_tree().create_tween().set_parallel(true)
	move_tween.tween_property(card, "position", target_pos, CARD_MOVE_SPEED)
	move_tween.tween_property(card, "scale", Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE), CARD_MOVE_SPEED)
	move_tween.tween_property(card, "rotation", 0, CARD_MOVE_SPEED) 
	card.z_index = 10
	return move_tween

func collect_used_card(card):
	if card == null: return
	if card.cards_current_slot:
		card.cards_current_slot.remove_card(false)
	card.retriggers = 0
	card.update_visuals()
	if card.card_data:
		card.card_data.multiplier = 1.0
		for action in card.card_data.actions:
			if action != null: action.action_multiplier = 1.0
	if card.card_owner == "Player":
		%PlayerDeck.graveyard.append(card.card_data)
	else:
		%EnemyDeck.graveyard.append(card.card_data)
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
		enemy_snapshot = _analyze_slots(enemy_slots)
	_update_board_label()

func _update_board_label():
	var display_text = "--- ENEMY BOARD ---\n"
	display_text += "Slots: " + str(enemy_snapshot.slot_types) + "\n"
	display_text += "Chain: %dx %s" % [enemy_snapshot.highest_chain_length, enemy_snapshot.highest_chain_type] + "\n"
	display_text += "--- PLAYER BOARD ---\n"
	display_text += "Slots: " + str(player_snapshot.slot_types) + "\n"
	display_text += "Chain: %dx %s\n\n" % [player_snapshot.highest_chain_length, player_snapshot.highest_chain_type]

	if has_node("%BoardStateLabel"):
		%BoardStateLabel.text = display_text

func _analyze_slots(slots_array: Array) -> Dictionary:
	var type_counts = {}
	var current_chain_type = ""
	var current_chain_length = 0
	var highest_chain_type = ""
	var highest_chain_length = 0
	var slot_types = []
	# TUTORIAL CHECKER - Only run for Player slots
	if slots_array == player_slots:
		var end_turn_btn = $"../EndTurnButton"
		
		match turn_count:
			1:
				end_turn_btn.disabled = !(_is_card_in_player_slot(0, "Block"))
			2:
				var has_sword = _is_card_in_player_slot(0, "Sword")
				var has_sword_2 = _is_card_in_player_slot(1, "Sword")
				end_turn_btn.disabled = !(has_sword and has_sword_2)
			3:
				var has_multiply = _is_card_in_player_slot(0, "Multiply")
				var has_multiply_2 = _is_card_in_player_slot(1, "Multiply")
				var has_sword = _is_card_in_player_slot(2, "Sword")
				end_turn_btn.disabled = !(has_multiply and has_multiply_2 and has_sword)
			4:
				var has_block = _is_card_in_player_slot(0, "Block")
				var has_multiply = _is_card_in_player_slot(1, "Multiply")
				var has_double_hit = _is_card_in_player_slot(2, "Double Hit")
				end_turn_btn.disabled = !(has_block and has_multiply and has_double_hit)
			_:
				# After tutorial turns, ensure the button isn't stuck disabled
				# (Unless you have other logic that disables it)
				if not board_locked:
					%EndTurnButton.disabled = false
	
	# CODE FOR CHAINS
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
	
func _is_card_in_player_slot(slot_index: int, target_card_name: String) -> bool:
	if slot_index < 0 or slot_index >= player_slots.size():
		return false
	
	var slot = player_slots[slot_index]
	if is_instance_valid(slot) and slot.card and slot.card.card_data:
		# Changed '.card_name' to '.display_name' to match your Resource script
		return slot.card.card_data.display_name == target_card_name
	
	return false
