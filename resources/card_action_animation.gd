extends Resource
class_name CardActionAnimation

@export var animation_name: String
@export_enum("1a", "1b",
			 "2a", "2b")
var animation_id: String = "1a" # id is used to help if card has multiple anims
@export_enum("Self", "Opponent", "Next_Self_Card", 
			 "Next_Self_Card", "Specific_Self_Slot",
			 "Specific_Opponent_Slot") 
var animation_target: String = "Self"
@export var animation_sound: String = ""

#unsure of how to get this working, leave it for now
