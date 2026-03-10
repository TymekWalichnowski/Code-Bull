extends Node

signal play_sound()

const PLAYER_POSITION = Vector2(960, 850)
const OPPONENT_POSITION = Vector2(960, 440)


@onready var anim_node = $ActionAnim
@export var damage_label_scene: PackedScene

var self_position
var target_position
var card_position
var original_scale

func _ready():
	# Connect the signals from your Player and Opponent status nodes
	%Player.damage_taken.connect(_on_entity_damage_taken.bind("Player"))
	%Opponent.damage_taken.connect(_on_entity_damage_taken.bind("Opponent"))
	original_scale = $OpponentSprite.scale
	start_idle($OpponentSprite)

func play_anim(action_name, card_owner):
	if card_owner == "Player":
		self_position = PLAYER_POSITION
		target_position = OPPONENT_POSITION
		card_position = %PlayerCardPoint.position
	else:
		self_position = OPPONENT_POSITION
		target_position = PLAYER_POSITION
		card_position = %OpponentCardPoint.position
	
	match action_name:
		"Attack":
			anim_node.position = target_position
			anim_node.visible = true
			%AudioManager.play_sfx("Attack")
			anim_node.play("attack_slash")
		"Shield":
			anim_node.position = self_position
			anim_node.visible = true
			%AudioManager.play_sfx("Shield Summon")
			anim_node.play("shield_bubble")
		"Multiply_Or_Divide1":
			anim_node.position = card_position
			anim_node.visible = true
			%AudioManager.play_sfx("Magic")
			anim_node.play("multiply_or_divide1")
		"Multiply_Or_Divide2":
			anim_node.position = card_position
			anim_node.visible = true
			%AudioManager.play_sfx("Magic")
			anim_node.play("multiply_or_divide2")
		"Multiply_Next_Card":
			anim_node.position = self_position
			anim_node.visible = true
			%AudioManager.play_sfx("Magic")
			anim_node.play("multiply")
		"Divide_Next_Card":
			anim_node.position = target_position
			anim_node.visible = true
			%AudioManager.play_sfx("Magic")
			anim_node.play("divide")
		_:
			anim_node.position = card_position
			anim_node.visible = true
			anim_node.play("wip")
	await anim_node.animation_finished

func start_idle(target_node: Node2D):
	var tween = create_tween().set_loops() # This makes it loop forever
	# Inhale: Slightly wider and shorter
	# Multiplying by original_scale keeps the base size correct
	tween.tween_property(target_node, "scale", 
		Vector2(original_scale.x * 1.03, original_scale.y * 0.97), 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Exhale: Slightly thinner and taller
	tween.tween_property(target_node, "scale", 
		Vector2(original_scale.x * 0.98, original_scale.y * 1.02), 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

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
