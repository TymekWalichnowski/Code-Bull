extends Node

const PLAYER_POSITION = Vector2(960, 850)
const OPPONENT_POSITION = Vector2(960, 140)

@onready var anim_node = $ActionAnim

var self_position
var target_position

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


func _on_action_anim_animation_finished() -> void:
	anim_node.visible = false
