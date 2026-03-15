extends Resource
class_name CardDataResource

@export_group("Visuals")
@export var id: int
@export var display_name: String
@export var image_texture: Texture2D

@export_group("Logic")
@export var priority: int
@export var multiplier: float = 1.0
@export var nullified: bool = 0.0
@export_enum("Purity", "Faith", "Temperance", 
			 "Charity", "Diligence", "Kindness",
			 "Patience", "Humility") 
var type: String = "Purity"

@export var actions: Array[CardAction] = []
