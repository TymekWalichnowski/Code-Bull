extends Resource
class_name CardAction

@export var action_name: String
@export_multiline var description: String
@export var value: float = 0.0
@export var action_multiplier: float = 1.0
@export var priority: int = 0
@export var target: String # mainly used for animations rather than logic
@export var action_animation_override: String # might not be relevant enough to use
@export var tags: Array[String] = []
