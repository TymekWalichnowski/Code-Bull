extends Resource
class_name CardAction

@export var action_name: String
@export_multiline var description: String
@export var value: float = 0.0
@export var priority: int = 0
@export var target: String
@export var action_animation: SpriteFrames
@export var tags: Array[String] = []
