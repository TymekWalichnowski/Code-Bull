extends Resource
class_name PassiveCardResource

@export_group("Visuals")
@export var card_name: String = "Passive Name"
@export var card_image: Texture2D
@export var description: String = "" # Useful for tooltips later!

@export_group("Logic")
@export_enum("On_Phase_Start", "On_Slot_Start", "On_Damage_Taken") var trigger_condition: String = "On_Phase_Start"
@export var effect_name: String = "Effect_Name"
@export var value: float = 1.0
@export var target_slot: int = -1

func apply_effect(owner_node, enemy_node, retrigger_array):
	match effect_name:
		"Retrigger_Slot":
			var index = target_slot - 1
			retrigger_array[index] += int(value)
			
		"Add_Shield_Start":
			owner_node.gain_shield(value)
			
		"Spike_Armour":
			# Spike armor hits the ENEMY when the OWNER is touched
			enemy_node.take_damage(value)
