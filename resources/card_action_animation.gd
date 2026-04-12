extends Resource
class_name CardActionAnimation

@export var animation_name: String
@export_enum("Self_Target", "Target", "Next_Self_Card", 
			 "Next_Self_Target_Card", "Specific_Self_Card",
			 "Specific_Target_Card") 

var animation_target: String = "Self_Target"

#unsure of how to get this working, leave it for now
