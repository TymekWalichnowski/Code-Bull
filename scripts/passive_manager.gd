extends Node

@onready var battle_manager = get_parent()
@onready var player_passive_container = %PlayerPassives
@onready var enemy_passive_container = %EnemyPassives

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
			
	# Check Enemy Passives - only if side is "Both" or "Enemy"
	if side_to_trigger == "Both" or side_to_trigger == "Enemy":
		for card in enemy_passive_container.get_children():
			if card is PassiveCard and card.data and card.data.trigger_condition == trigger_type:
				await _execute_passive(card, "Enemy", current_slot_idx)

func _execute_passive(card: PassiveCard, owner_name: String, current_slot_idx: int):
	var effect = card.data.effect_name 
	var val = card.data.value
	var target_slot = card.data.target_slot 
	
	if passive_map.has(effect):
		# LOGIC CHECK:
		# If we are doing a slot-specific trigger (like On_Slot_Start), check the index.
		# If we are doing a turn-wide trigger (like On_Turn_Start), skip the index check.
		if current_slot_idx != -1: 
			if target_slot > 0 and target_slot != (current_slot_idx + 1):
				return
			
		# Visual feedback
		if card.has_node("AnimationPlayer"):
			var anim = card.get_node("AnimationPlayer")
			anim.play("passive_trigger") 
			await anim.animation_finished
		
		await get_tree().create_timer(0.4).timeout
		
		# Execute (target_slot is passed as 2 in your case)
		await passive_map[effect].call(owner_name, val, target_slot)

# --- EFFECT LOGIC ---

func _passive_retrigger(owner_name: String, value: float, slot_to_hit: int):
	var index = slot_to_hit - 1
	var target_slot
	
	if owner_name == "Player":
		target_slot = battle_manager.player_slots[index]
	else:
		target_slot = battle_manager.enemy_slots[index]
		
	# Apply the buff directly to the slot
	if target_slot:
		target_slot.add_retrigger_buff(int(value))
		print("Passive: ", owner_name, " buffed slot ", slot_to_hit, " with ", value, " retriggers.")

func _passive_shield_start(owner_name: String, value: float, _slot: int):
	var target = %Player if owner_name == "Player" else %Enemy
	target.gain_shield(value)

func _passive_spike_armour(owner_name: String, value: float, _slot: int):
	# If the Player owns this passive, they hit the Enemy back.
	# If the Enemy owns it, they hit the Player back.
	var target = %Enemy if owner_name == "Player" else %Player
	
	# We use a small flag or separate call to ensure this damage 
	# doesn't count as a "Hit" to avoid infinite recursion.
	target.take_damage(value)
	print("Spike Armour: ", owner_name, " dealt ", value, " recoil damage.")
