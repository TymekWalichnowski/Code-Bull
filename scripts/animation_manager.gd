extends Node

const PLAYER_POSITION = Vector2(960, 850)
const OPPONENT_POSITION = Vector2(960, 440)

@onready var anim_node = $ActionAnim
@export var damage_label_scene: PackedScene

var self_position
var target_position

func _ready():
	# Connect the signals from your Player and Opponent status nodes
	%Player.damage_taken.connect(_on_entity_damage_taken.bind("Player"))
	%Opponent.damage_taken.connect(_on_entity_damage_taken.bind("Opponent"))

func play_anim(action_name, card_owner):
	if card_owner == "Player":
		self_position = PLAYER_POSITION
		target_position = OPPONENT_POSITION
	else:
		self_position = OPPONENT_POSITION
		target_position = PLAYER_POSITION
	
	match action_name:
		"Attack":
			anim_node.position = target_position
			anim_node.visible = true
			anim_node.play("attack_slash")
		"Shield":
			anim_node.position = self_position
			anim_node.visible = true
			anim_node.play("shield_bubble")
		"Multiply_Or_Divide1":
			anim_node.position = self_position
			anim_node.visible = true
			anim_node.play("multiply_or_divide1")
		"Multiply_Or_Divide2":
			anim_node.position = self_position
			anim_node.visible = true
			anim_node.play("multiply_or_divide2")
		_:
			return
	await anim_node.animation_finished


func _on_entity_damage_taken(amount: float, is_shield: bool, side: String):
	# If 'side' is Player, spawn on Player position. If Opponent, spawn there.
	var spawn_pos = PLAYER_POSITION if side == "Player" else OPPONENT_POSITION
	spawn_damage_number_at(amount, spawn_pos, is_shield)

func spawn_damage_number_at(amount: float, pos: Vector2, is_shield: bool):
	var popup = damage_label_scene.instantiate()
	add_child(popup)
	
	# Randomize slightly so numbers don't stack
	var offset = Vector2(randf_range(-30, 30), randf_range(-10, 10))
	popup.global_position = pos + offset
	popup.setup(amount, is_shield)

func _on_action_anim_animation_finished() -> void:
	anim_node.visible = false
