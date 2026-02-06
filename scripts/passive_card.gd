extends Node2D
class_name PassiveCard

# We hold a reference to the resource data
var data: PassiveCardResource

func setup(resource: PassiveCardResource):
	data = resource
	update_visuals()

func update_visuals():
	if not data: return
	
	if has_node("Label"):
		$Label.text = data.card_name
	
	if has_node("ValueLabel"):
		$ValueLabel.text = str(data.value)
		
	if has_node("CardImage") and data.card_image:
		$CardImage.texture = data.card_image

func play_trigger_anim():
	if has_node("AnimationPlayer") and $AnimationPlayer.has_animation("passive_trigger"):
		$AnimationPlayer.play("passive_trigger")
