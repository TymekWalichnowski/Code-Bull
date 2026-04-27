extends Resource

class_name EnemyResource

@export var enemy_name: String
@export var health: int
@export var sprite: Texture2D # if sprites will have multiple parts in the future, may be better to change this
@export var cards: Array[CardDataResource] = []
@export var passive_cards: Array[PassiveCardResource] = []
@export var completion_rewards: Array[Resource]
