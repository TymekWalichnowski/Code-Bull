extends Node

const PLAYER_POSITION = Vector2(960, 850)
const OPPONENT_POSITION = Vector2(960, 140)

var self_position
var target_position

#func _on_player_action_anim_animation_finished() -> void:
	#%PlayerActionAnim.visible = false
#
#
#func _on_opponent_action_anim_animation_finished() -> void:
	#%OpponentActionAnim.visible = false

func play_anim(action_name, anim_node, card_owner):
	
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
