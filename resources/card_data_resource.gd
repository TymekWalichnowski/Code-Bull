@icon("res://Assets/icons/16x16/page_data.png")

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
@export_enum("Cup", "Wand",
			 "Sword", "Star") 
var type: String = "Cup"
@export var one_time_use: bool = 0

@export var actions: Array[CardAction] = []
@export var tags: Array[TagResource] = []
