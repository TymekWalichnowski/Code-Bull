extends Node

@onready var battle_manager = get_parent()
@onready var player_passive_container = %PlayerPassives
@onready var opponent_passive_container = %OpponentPassives

# Map effects to local functions
@onready var passive_map: Dictionary = {
	"Retrigger_Slot": _passive_retrigger,
	"Add_Shield_Start": _passive_shield_start,
	"Spike_Armour": _passive_spike_armour
}

# Main entry point for the BattleManager to call
func trigger_passives(trigger_type: String, current_slot_idx: int = -1, side_to_trigger: String = "Both"):
	
	# Check Player Passives - only if side is "Both" or "Player"
	if side_to_trigger == "Both" or side_to_trigger == "Player":
		for card in player_passive_container.get_children():
			if card is PassiveCard and card.data and card.data.trigger_condition == trigger_type:
				await _execute_passive(card, "Player", current_slot_idx)
			
	# Check Opponent Passives - only if side is "Both" or "Opponent"
	if side_to_trigger == "Both" or side_to_trigger == "Opponent":
		for card in opponent_passive_container.get_children():
			if card is PassiveCard and card.data and card.data.trigger_condition == trigger_type:
				await _execute_passive(card, "Opponent", current_slot_idx)

func _execute_passive(card: PassiveCard, owner_name: String, current_slot_idx: int):
	var effect = card.data.effect_name 
	var val = card.data.value
	var target_slot = card.data.target_slot 
	
	if passive_map.has(effect):
		# FIX: Treat 0 and -1 as "Global/All Slots" so older cards don't break
		if target_slot > 0 and target_slot != (current_slot_idx + 1):
			return
			
		# Visual feedback
		if card.has_node("AnimationPlayer"):
			var anim = card.get_node("AnimationPlayer")
			anim.play("passive_trigger") 
			await anim.animation_finished
		
		# Small pause
		await get_tree().create_timer(0.4).timeout
		
		# Execute the specific logic
		await passive_map[effect].call(owner_name, val, target_slot)

# --- EFFECT LOGIC ---

func _passive_retrigger(owner_name: String, value: float, slot_to_hit: int):
	var index = slot_to_hit - 1
	if owner_name == "Player":
		battle_manager.player_retrigger_counts[index] += int(value)
	else:
		battle_manager.opponent_retrigger_counts[index] += int(value)
	print("Passive: ", owner_name, " scheduled retrigger for slot ", slot_to_hit)
	battle_manager.update_card_effects()

func _passive_shield_start(owner_name: String, value: float, _slot: int):
	var target = %Player if owner_name == "Player" else %Opponent
	target.gain_shield(value)

func _passive_spike_armour(owner_name: String, value: float, _slot: int):
	# If the Player owns this passive, they hit the Opponent back.
	# If the Opponent owns it, they hit the Player back.
	var target = %Opponent if owner_name == "Player" else %Player
	
	# We use a small flag or separate call to ensure this damage 
	# doesn't count as a "Hit" to avoid infinite recursion.
	target.take_damage(value)
	print("Spike Armour: ", owner_name, " dealt ", value, " recoil damage.")
