extends Resource
class_name CardDataResource

@export var id: int
@export var display_name: String
@export var image_texture: Texture2D
@export var priority: int
@export var multiplier: float = 1.0
@export var nullified: bool = 0.0

@export var actions: Array[CardAction] = []
