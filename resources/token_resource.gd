extends Resource
class_name TokenResource
@export_group("Visuals")
@export var token_name: String = "Token Name"
@export var token_image: Texture2D
@export var description: String = ""

@export_group("Logic")
@export_enum("On_Phase_Start", "On_Phase_End", "On_Slot_Start", 
			 "On_Damage_Taken_Player", "On_Damage_Taken_Opponent",
			 "After_Action") 

var trigger_condition: String = "On_Phase_Start"
@export var effect_name: String = "Effect_Name"
@export var value: float = 1.0
@export var target_slot: int = -1
