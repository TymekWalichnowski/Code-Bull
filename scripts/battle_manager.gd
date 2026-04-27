extends Node

signal battle_click_received

@onready var action_manager = %ActionManager
@onready var audio_manager = %AudioManager
@onready var animation_manager = %AnimationManager
@onready var passive_manager = %PassiveManager
@onready var token_manager = %TokenManager 

@onready var player_slots_all = [$"../CardSlots/CardSlot", $"../CardSlots/CardSlot2", $"../CardSlots/CardSlot3", $"../CardSlots/CardSlot4", $"../CardSlots/CardSlot5"]
@onready var enemy_slots_all = [$"../CardSlots/CardSlotEnemy1", $"../CardSlots/CardSlotEnemy2", $"../CardSlots/CardSlotEnemy3", $"../CardSlots/CardSlotEnemy4", $"../CardSlots/CardSlotEnemy5"]

@onready var battle_timer = %BattleTimer

# THE DATA PUSHED FROM LEVEL SELECT
@export var enemy_data: EnemyResource

var player_slots = []
var enemy_slots = []

const SMALLER_CARD_SCALE = 1.05
const CARD_MOVE_SPEED = 0.2
const START_DRAW_COUNT = 5 
const SLOT_GAP = 170.0

var turn_count: int = 0
var player_has_initiative: bool = true
var empty_enemy_card_slots = []
var player_snapshot: Dictionary = {}
var enemy_snapshot: Dictionary = {}
var board_locked: bool = false 
var battle_active: bool = true

func _ready() -> void:
	%Player.defeated.connect(_on_battle_over)
	%Enemy.defeated.connect(_on_battle_over)
	
	battle_timer.one_shot = true
	battle_timer.wait_time = 0.2
	
	if not enemy_data:
		push_warning("BattleManager started without Enemy Data! Run from Level Select or assign a .tres in the Inspector for testing.")
		return
		
	setup_battle(enemy_data)

func setup_battle(resource: EnemyResource):
	# 1. Setup Enemy Visuals/Stats from Resource
	%Enemy.max_health = resource.health
	%Enemy.current_health = resource.health
	%Player.current_health = %Player.max_health
	if %Enemy.entity_sprite:
		%Enemy.entity_sprite.texture = resource.sprite
	
	# 2. Setup Decks (This replaces all old editor assignments)
	%EnemyDeck.load_enemy_data(resource.cards, resource.passive_cards)
	%PlayerDeck.prepare_deck() # PlayerDeck pulls from PlayerDeckGlobal internally
	
	# 3. Game State Initialization
	%Player.speed = randi_range(1, 5)
	%Enemy.speed = randi_range(1, 5)
	advance_turn()
	
	# 4. Opening Sequence
	for i in range(START_DRAW_COUNT):
		%PlayerDeck.draw_card()
		%EnemyDeck.draw_card()
		await get_tree().create_timer(0.3).timeout
	
	%PlayerDeck.spawn_starting_passives()
	%EnemyDeck.spawn_starting_passives()
	
	await get_tree().create_timer(0.2).timeout
	await trigger_passives("On_Turn_Start")
	analyze_board_state()
	enemy_turn()

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
	
	var slot_limit = 3
	if turn_count == 2:
		slot_limit = 4
	elif turn_count >= 3:
		slot_limit = 5
	
	setup_active_slots(slot_limit)
	action_manager.set_slot_amount(slot_limit)
	animation_manager.set_slot_amount(slot_limit)

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
	
	# Fix: If the battle ended during the activation phase, stop everything right here.
	if not battle_active: return
	await trigger_tokens("On_Turn_End")
	
	advance_turn()

	%Player.speed = randi_range(1, 5)
	%Enemy.speed = randi_range(1, 5)
	
	%PlayerDeck.draw_card()
	%PlayerDeck.draw_card()
	
	await trigger_passives("On_Turn_Start")
	await trigger_tokens("On_Turn_Start")

	
	board_locked = false
	enemy_turn()

func enemy_turn():
	await wait(0.2)
	if turn_count > 1: %EnemyDeck.draw_card()
	await wait(1)
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
		if not battle_active: break 	# CHECKING IF DEAD: Before a new slot starts
		var order = ["Player", "Enemy"] if player_has_initiative else ["Enemy", "Player"]
		await trigger_passives("On_Slot_Start", slot_index)
		await trigger_tokens("On_Slot_Start")
		
		for side in order:
			if not battle_active: break 	# CHECKING IF DEAD: Before a specific side acts
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
				if not battle_active: break 	# CHECKING IF DEAD: Before a retrigger
				if run_idx > 0:
					await card.declare_effect("Retrigger!")
				for action_idx in range(card.card_data.actions.size()):
					if not battle_active: break 	# CHECKING IF DEAD: Before an action
					if card.card_data.actions[action_idx] != null:
						await action_manager.execute_card_action(card, action_idx)
						await wait(0.6)
			
			collect_used_card(card)
			await wait(1.0)
		if not battle_active: # Fix: If someone died during the attack, immediately clean up and EXIT.
			clear_entire_board()
			return
		if slot_index < player_slots.size(): player_slots[slot_index].clear_buffs()
		if slot_index < enemy_slots.size(): enemy_slots[slot_index].clear_buffs()
		reset_enemy_slots()
		await wait(0.6)
	if not battle_active: clear_entire_board()  # DEAD: do cleanup
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
	audio_manager.play_sfx("Burn_Card")
	await card.burn_away(0.6)
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

func _on_battle_over(defeated_side: String):
	if not battle_active: return
	battle_active = false
	board_locked = true
	
	if defeated_side == "Enemy":
		# Tracks win against enemy
		if not PlayerDeckGlobal.global_enemies_defeated.has(enemy_data.enemy_name):
			PlayerDeckGlobal.global_enemies_defeated.append(enemy_data.enemy_name)
			print(PlayerDeckGlobal.global_enemies_defeated)
			grant_rewards()
	
	show_win_loss_ui(defeated_side)

func grant_rewards():
	for reward in enemy_data.completion_rewards:
		if reward is CardDataResource:
			PlayerDeckGlobal.global_player_inventory.append(reward)
		elif reward is PassiveCardResource:
			PlayerDeckGlobal.global_player_inventory_passives.append(reward)

func clear_entire_board():
	# Remove all cards from slots and hands
	for slot in player_slots_all + enemy_slots_all:
		if slot.card:
			slot.card.queue_free()
			slot.card_in_slot = false

	# Optionally clear hands
	for card in %PlayerHand.get_children(): card.queue_free()
	for card in %EnemyHand.get_children(): card.queue_free()

func show_win_loss_ui(side):
	# Just a simple example, you should make a nice UI node for this
	var label = Label.new()
	label.text = "YOU WIN!" if side == "Enemy" else "YOU LOSE!" # If enemy died, you win
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 64)
	add_child(label)
	await get_tree().create_timer(5.0).timeout
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")
