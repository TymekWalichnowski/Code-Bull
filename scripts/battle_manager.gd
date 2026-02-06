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

const STARTING_HEALTH = 10.0

const SMALLER_CARD_SCALE = 1.05
const CARD_MOVE_SPEED = 0.2

var player_health
var opponent_health

var empty_opponent_card_slots = []
var current_slot
var finished_count = 0
var total_needed = 2

@onready var passive_map: Dictionary = {
	"Retrigger_Slot": _passive_retrigger,
	"Add_Shield_Start": _passive_shield_start,
}
@onready var player_passive_container = %PlayerPassives
@onready var opponent_passive_container = %OpponentPassives

func _ready() -> void:
	battle_timer.one_shot = true
	battle_timer.wait_time = 0.2
	
	empty_opponent_card_slots.append($"../CardSlots/OpponentCardSlot")
	empty_opponent_card_slots.append($"../CardSlots/OpponentCardSlot2")
	empty_opponent_card_slots.append($"../CardSlots/OpponentCardSlot3")
	
	# A bit awkward, clean this up
	%Player.current_health = STARTING_HEALTH
	%Opponent.current_health = STARTING_HEALTH
	#$"../PlayerHealth".text = str(%Player.health) # replace this later, we're just updating it every frame at the moment
	#$"../OpponentHealth".text = str(%Opponent.health)
	opponent_turn()

func _process(float) -> void:
	#temporary debug
	%PlayerLabel.text = "HP: %.1f  |\n Shield: %.1f |\n Mult: x%.2f |\n Next Mult x%.2f" % [
		%Player.current_health, %Player.current_shield, %Player.current_mult, %Player.next_mult]
	%OpponentLabel.text = "HP: %.1f  |\n Shield: %.1f |\nMult: x%.2f |\n Next Mult x%.2f" % [
		%Opponent.current_health, %Opponent.current_shield, %Opponent.current_mult, %Opponent.next_mult]
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


var slot_retriggers = [0, 0, 0] # Track extra runs for Slot 1, 2, and 3, move this outta the way
	
	# EXAMPLE: Manual retrigger for Player Slot 2, put above slot index
	# We check if there is actually a card there before scheduling a retrigger
	#if player_slots[1].card != null:
		#player_retrigger_counts[1] += 1 
		#print("DEBUG: Player Slot 2 scheduled for 1 extra run.")

func run_activation_phase():
	var slot_count = max(player_slots.size(), opponent_slots.size())
	player_retrigger_counts = [0, 0, 0]
	opponent_retrigger_counts = [0, 0, 0]
	
	await trigger_passives("On_Phase_Start")
	await wait(0.4)
	
	for slot_index in range(slot_count):
		print("\n ---- CARD SLOT ", slot_index + 1, " ----")
		

		var p_card = player_slots[slot_index].card
		var o_card = opponent_slots[slot_index].card
		
		
		# resetting stuff
		%Player.current_mult = %Player.next_mult
		%Player.next_mult = 1.0
		%Opponent.current_mult = %Opponent.next_mult
		%Opponent.next_mult = 1.0
		
		%Player.nullified = false
		%Opponent.nullified = false

		# 1. Update total_needed based on how many cards are actually present
		total_needed = 0
		if p_card: total_needed += 1
		if o_card: total_needed += 1
		
		if total_needed == 0:
			continue # No cards in this slot index for either side, skip to next slot

		# 2. Move existing cards to battle point
		finished_count = 0
		if p_card: move_card_to_battle_point(p_card)
		if o_card: move_card_to_battle_point(o_card)
		
		# Wait for the cards that exist to finish moving
		while finished_count < total_needed:
			await get_tree().process_frame
		
		# Trigger slot passives
		await trigger_passives("On_Slot_Start", slot_index)
		
		# retrigger logic
		var p_runs = 1
		var o_runs = 1
		if p_card:
			p_runs += player_retrigger_counts[slot_index]
		if o_card:
			o_runs += opponent_retrigger_counts[slot_index]
		var total_runs = max(p_runs, o_runs)
		
		# 3. Determine max actions
		var p_action_count = p_card.card_data.actions.size() if p_card else 0
		var o_action_count = o_card.card_data.actions.size() if o_card else 0
		var max_actions = max(p_action_count, o_action_count)

		# 4. Action Loop (with retriggers)
		for run_idx in range(total_runs):
			print("Slot", slot_index + 1, "Run", run_idx + 1, "/", total_runs)

			for action_idx in range(max_actions):
				var first_actor = null
				var second_actor = null
				var is_simultaneous = false

				var p_has_act = (
					p_card != null
					and run_idx < p_runs
					and action_idx < p_card.card_data.actions.size()
					and p_card.card_data.actions[action_idx] != null
				)

				var o_has_act = (
					o_card != null
					and run_idx < o_runs
					and action_idx < o_card.card_data.actions.size()
					and o_card.card_data.actions[action_idx] != null
				)

				if p_has_act and o_has_act:
					var p_priority = p_card.card_data.actions[action_idx].priority
					var o_priority = o_card.card_data.actions[action_idx].priority
					
					if p_priority < o_priority:
						first_actor = p_card
						second_actor = o_card
					elif o_priority < p_priority:
						first_actor = o_card
						second_actor = p_card
					else:
						is_simultaneous = true
						first_actor = p_card
						second_actor = o_card
				elif p_has_act:
					first_actor = p_card
				elif o_has_act:
					first_actor = o_card

				if is_simultaneous:
					execute_card_action(first_actor, action_idx)
					execute_card_action(second_actor, action_idx)
					#dont use awaits, use the counter instead because it needs to be simultaneous
					while finished_count < total_needed:
						await get_tree().process_frame
					await wait(1.0)
				else:
					if first_actor:
						await execute_card_action(first_actor, action_idx)
						await wait(1.0)
					if second_actor:
						await execute_card_action(second_actor, action_idx)
						await wait(1.0)
		
		# 5. End of Slot Cleanup
		%Player.current_mult = 1.0
		%Opponent.current_mult = 1.0
		
		player_retrigger_counts[slot_index] = 0
		opponent_retrigger_counts[slot_index] = 0
		
		if p_card: collect_used_card(p_card)
		if o_card: collect_used_card(o_card)

		reset_opponent_slots()
		await wait(0.8)

func execute_card_action(card: Card, action_index: int):
	var action_data = card.card_data.actions[action_index]
	var action = action_data.action_name
	var value = action_data.value
	var tags = action_data.tags
	
	print(card.card_owner, " Executing: ", card.card_name, " uses ", action_data.action_name, " value ", action_data.value)
	print("Tags: ", tags)
	var target
	var self_target
	var anim_node
	
	if card.card_owner == "Player":
		target = %Opponent
		self_target = %Player
		anim_node = %PlayerActionAnim

	else:
		target = %Player
		self_target = %Opponent
		anim_node = %OpponentActionAnim
	
	#
	
	# Check tags
	

	# CURRENTLY WE JUST APPLY THE MULT TO THE VALUE, 
	# BUT LATER ADD A SYSTEM TO CHECK THE TAGS AND THEN
	# APPLY THE MULT TO THE VALUE DEPENDING ON TAGS 
	value = value * self_target.current_mult
	
	if self_target.nullified == true:
		print("returning ", card.card_owner, " action as it was nullified")
		finished_count += 1
		return
	
	# PRE-APPLICATION, Certain cards like the 50/50 need to do their logic before the action application
	match action:
		"Multiply_Or_Divide":
			if randf() < 0.5:
				action = "Multiply_Or_Divide1"
				await %AnimationManager.play_anim(action, anim_node, card.card_owner) #action animation
				action = "Multiply_Next_Card"
			else:
				action = "Multiply_Or_Divide2"
				await %AnimationManager.play_anim(action, anim_node, card.card_owner) #action animation
				action = "Divide_Next_Card"
			print(card.card_owner, " Used multiply or divide, action is now: ", action)
		
	card.get_node("AnimationPlayer").play("card_basic_use") #card animation
	await %AnimationManager.play_anim(action, anim_node, card.card_owner) #action animation
	
	# APPLICATION, Applying the effect like damage or shield
	match action:
		"Attack":
			print(card.card_owner, " deals ", value, " damage.")
			target.take_damage(value)
		"Shield":
			print(card.card_owner, " gains ", value, " shield.")
			self_target.gain_shield(value)
		"Multiply_Next_Card":
			print(card.card_owner, " gains ", value, " mult.") 
			self_target.next_mult = self_target.next_mult * value
		"Divide_Next_Card":
			print(card.card_owner, " applies ", value, " divide to ", target) # need to change how mult works because currently 1 mult becomes 3 mult when you add 2
			target.next_mult = target.next_mult / value
		"Nullify":
			print(card.card_owner, " nullifies ", target) # need to change how mult works because currently 1 mult becomes 3 mult when you add 2
			target.nullified = true
		"Draw_Card":
			if self_target == %Player:
				for i in value:
					%PlayerDeck.draw_card()
			else:
				for i in value:
					%OpponentDeck.draw_card()
		"Retrigger_Next_Slot":
			var current_idx = -1
			# Find slot index
			for i in range(player_slots.size()):
				if player_slots[i].card == card:
					current_idx = i
					break
			# Only increment the retrigger count for the OWNER of the card
			if current_idx != -1 and current_idx + 1 < 3:
				if card.card_owner == "Player":
					player_retrigger_counts[current_idx + 1] += int(value)
				else:
					opponent_retrigger_counts[current_idx + 1] += int(value)
		"Multiply_Or_Divide":
			pass
	finished_count += 1

func check_done(): #making sure both actions are done before
	finished_count += 1
	print("finished count: ", finished_count)

func move_card_to_battle_point(card):
	var target_pos
	if card.card_owner == "Player":
		target_pos = %PlayerCardPoint.global_position 
	else:
		target_pos = %OpponentCardPoint.global_position 
	var move_tween = get_tree().create_tween()
	move_tween.tween_property(card, "position", target_pos, CARD_MOVE_SPEED)
	move_tween.tween_property(card, "scale", Vector2(SMALLER_CARD_SCALE, SMALLER_CARD_SCALE), CARD_MOVE_SPEED)
	move_tween.finished.connect(check_done) # adds to finished count
	card.z_index = 10

func collect_used_card(card):
	if card == null:
		return
	
	if card.card_owner == "Player":
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

func trigger_passives(trigger_type: String, current_slot_idx: int = -1):
	# Check Player Passives
	for card in player_passive_container.get_children():
		if card.trigger_condition == trigger_type:
			await _execute_passive(card, "Player", current_slot_idx)
			
	# Check Opponent Passives
	for card in opponent_passive_container.get_children():
		if card.trigger_condition == trigger_type:
			await _execute_passive(card, "Opponent", current_slot_idx)

func _execute_passive(card, owner_name, current_slot_idx):
	var effect = card.passive_effect_name # e.g. "Retrigger_Slot"
	var val = card.value
	var target_slot = card.target_slot # e.g. 2
	
	if passive_map.has(effect):
		# If it's a slot-specific passive, only run it if we are on that slot
		if target_slot != -1 and target_slot != (current_slot_idx + 1):
			return
			
		# Visual feedback
		var anim = card.get_node("AnimationPlayer")
		anim.play("passive_trigger") 
		await anim.animation_finished
		await wait(0.4)
		passive_map[effect].call(owner_name, val, target_slot)


func _passive_retrigger(owner_name: String, value: float, slot_to_hit: int):
	# value could be 'how many extra runs'
	# slot_to_hit comes from the card data (e.g., 2 for slot 2)
	var index = slot_to_hit - 1
	if owner_name == "Player":
		player_retrigger_counts[index] += int(value)
	else:
		opponent_retrigger_counts[index] += int(value)
	print("Passive: ", owner_name, " scheduled retrigger for slot ", slot_to_hit)

func _passive_shield_start(owner_name: String, value: float, _slot: int):
	var target = %Player if owner_name == "Player" else %Opponent
	target.gain_shield(value)
