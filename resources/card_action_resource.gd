@icon("res://Assets/icons/16x16/sword.png")

extends Resource
class_name CardAction

@export var action_name: String
@export_multiline var description: String
@export var value: float = 0.0
@export var static_value: float = 0.0
@export var action_multiplier: float = 1.0
@export var priority: int = 0
@export var animation_array: Array[CardActionAnimation] = []
@export var tags: Array[TagResource] = []
