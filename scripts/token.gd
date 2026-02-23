# token.gd
extends Node2D

@onready var icon_sprite: Sprite2D = $Texture
@onready var count_label: Label = $Label

@export var vertical_offset: float = -6.0  # Moves chips UP
@export var max_visual_stack: int = 10

func update_token(token_data: TokenResource, amount: int):
	if icon_sprite == null: icon_sprite = get_node("Texture")
	if count_label == null: count_label = get_node("Label")
		
	icon_sprite.texture = token_data.token_image
	icon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_sprite.position = Vector2.ZERO
	
	for child in get_children():
		if child is Sprite2D and child != icon_sprite:
			child.queue_free()
	
	var visual_count = min(amount, max_visual_stack)
	
	for i in range(1, visual_count):
		var extra_chip = Sprite2D.new()
		extra_chip.texture = token_data.token_image
		extra_chip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		extra_chip.scale = icon_sprite.scale
		extra_chip.centered = icon_sprite.centered
		extra_chip.position.y = i * vertical_offset 
		
		add_child(extra_chip)
		move_child(extra_chip, get_child_count() - 1)

	# --- 5. POSITION LABEL BELOW THE STACK ---
	count_label.text = str(amount)
	count_label.visible = amount > 0 # Changed from >1 so 1 is still visible if preferred
	
	# Since the base chip is at 0, a positive Y value puts the label below it.
	# 25 pixels down should clear the bottom chip's sprite.
	count_label.position.y = 25 
	
	# Center the label horizontally relative to the chip
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Adjust this if your Label's pivot/size isn't centered by default
	count_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	count_label.position.x = 0 
	
	# Keep label visible on top of all chips
	move_child(count_label, get_child_count() - 1)
