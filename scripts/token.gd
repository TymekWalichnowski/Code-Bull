# token.gd
extends Node2D
@onready var icon_sprite = $Texture
@onready var count_label = $Label

func update_token(token_data: TokenResource, amount: int):
	# SAFETY CHECK: If @onready hasn't fired yet, find them manually
	if icon_sprite == null:
		icon_sprite = $Texture
	if count_label == null:
		count_label = $Label
		
	# Now apply the data
	if icon_sprite:
		icon_sprite.texture = token_data.token_image
	
	if count_label:
		count_label.text = str(amount)
		count_label.visible = amount > 1
