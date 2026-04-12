extends Node

signal play_sound()

const PLAYER_POSITION = Vector2(960, 850)
const OPPONENT_POSITION = Vector2(960, 440)

@onready var anim_node = $ActionAnim
@export var damage_label_scene: PackedScene

var original_scale

func _ready():
	%Player.damage_taken.connect(_on_entity_damage_taken.bind("Player"))
	%Opponent.damage_taken.connect(_on_entity_damage_taken.bind("Opponent"))
	original_scale = $OpponentSprite.scale
	start_idle($OpponentSprite)

func play_anim(action_name, card_owner, slot_idx: int = -1):
	var battle_m = get_parent()
	var is_player = (card_owner == "Player")
	
	var self_pos = PLAYER_POSITION if is_player else OPPONENT_POSITION
	var target_pos = OPPONENT_POSITION if is_player else PLAYER_POSITION
	var card_point = %PlayerCardPoint.position if is_player else %OpponentCardPoint.position
	
	anim_node.visible = true
	
	match action_name:
		"Attack":
			anim_node.position = target_pos
			%AudioManager.play_sfx("Attack")
			anim_node.play("attack_slash")
		"Shield":
			anim_node.position = self_pos
			%AudioManager.play_sfx("Shield Summon")
			anim_node.play("shield_bubble")
		"Multiply_Next_Card", "Retrigger_Next_Slot":
			if slot_idx >= 0 and slot_idx < 3:
				var slots = battle_m.player_slots if is_player else battle_m.opponent_slots
				anim_node.position = slots[slot_idx].global_position
			else:
				anim_node.position = self_pos
			anim_node.play("multiply")

		"Divide_Next_Card", "Divide_Specific_Slot", "Nullify":
			if slot_idx >= 0 and slot_idx < 3:
				# Divide always targets the opponent's side
				var target_slots = battle_m.opponent_slots if is_player else battle_m.player_slots
				anim_node.position = target_slots[slot_idx].global_position
			else:
				anim_node.position = target_pos
			anim_node.play("divide")
		"Multiply_Or_Divide1", "Multiply_Or_Divide2":
			anim_node.position = card_point
			%AudioManager.play_sfx("Magic")
			anim_node.play(action_name.to_lower())
		"Nullify_Start":
			anim_node.position = card_point
			anim_node.play("wip")
		_:
			anim_node.position = card_point
			anim_node.play("wip")
	
	await anim_node.animation_finished
	anim_node.visible = false

func start_idle(target_node: Node2D):
	var tween = create_tween().set_loops()
	tween.tween_property(target_node, "scale", 
		Vector2(original_scale.x * 1.03, original_scale.y * 0.97), 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(target_node, "scale", 
		Vector2(original_scale.x * 0.98, original_scale.y * 1.02), 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_entity_damage_taken(amount: float, is_shield: bool, side: String):
	var spawn_pos = PLAYER_POSITION if side == "Player" else OPPONENT_POSITION
	spawn_damage_number_at(amount, spawn_pos, is_shield)

func spawn_damage_number_at(amount: float, pos: Vector2, is_shield: bool):
	var popup = damage_label_scene.instantiate()
	add_child(popup)
	var offset = Vector2(randf_range(-30, 30), randf_range(-10, 10))
	popup.global_position = pos + offset
	popup.setup(amount, is_shield)

func _on_action_anim_animation_finished() -> void:
	anim_node.visible = false
