extends Node2D

signal hovered
signal hovered_off

@export var card_name: String = "Basic"  # Default card type
@export var card_id: int = 0

@export var max_rotation := 30.0
@export var follow_speed := 10.0
@export var return_speed := 7.0

var hand_position
var cards_current_slot
var hovering := false
var original_z_index := 0

var card_image: Sprite2D
var card_back_image: Sprite2D

func _ready() -> void:
	get_parent().connect_card_signals(self)

	card_image = $CardImage
	card_back_image = $CardBackImage

	if card_image and card_image.material:
		card_image.material = card_image.material.duplicate()
	if card_back_image and card_back_image.material:
		card_back_image.material = card_back_image.material.duplicate()

	original_z_index = z_index

func _process(delta: float) -> void:
	if not card_image or not card_image.texture:
		return

	# Reduce effect if card is in a slot
	var effect_max_rotation = max_rotation * 0.4 if cards_current_slot else max_rotation
	var effect_follow_speed = follow_speed * 0.5 if cards_current_slot else follow_speed


	if hovering:
		var local_mouse = card_image.to_local(get_global_mouse_position())
		var half = card_image.texture.get_size() * 0.5

		var x_ratio = clamp(local_mouse.x / half.x, -1.0, 1.0)
		var y_ratio = clamp(local_mouse.y / half.y, -1.0, 1.0)

		var target_y = -x_ratio * effect_max_rotation
		var target_x = y_ratio * effect_max_rotation

		if card_image.material:
			card_image.material.set_shader_parameter(
				"y_rot",
				lerp(card_image.material.get_shader_parameter("y_rot"), target_y, effect_follow_speed * delta)
			)
			card_image.material.set_shader_parameter(
				"x_rot",
				lerp(card_image.material.get_shader_parameter("x_rot"), target_x, effect_follow_speed * delta)
			)
		
		if card_back_image.material:
			card_back_image.material.set_shader_parameter(
				"y_rot",
				lerp(card_back_image.material.get_shader_parameter("y_rot"), target_y, effect_follow_speed * delta)
			)
			card_back_image.material.set_shader_parameter(
				"x_rot",
				lerp(card_back_image.material.get_shader_parameter("x_rot"), target_x, effect_follow_speed * delta)
			)

		# Hover always draws on top
		z_index = 100
	else:
		# Smoothly return rotation to 0
		if card_image.material:
			card_image.material.set_shader_parameter(
				"y_rot",
				lerp(card_image.material.get_shader_parameter("y_rot"), 0.0, return_speed * delta)
			)
			card_image.material.set_shader_parameter(
				"x_rot",
				lerp(card_image.material.get_shader_parameter("x_rot"), 0.0, return_speed * delta)
			)
		if card_back_image.material:
			card_back_image.material.set_shader_parameter(
				"y_rot",
				lerp(card_back_image.material.get_shader_parameter("y_rot"), 0.0, return_speed * delta)
			)
			card_back_image.material.set_shader_parameter(
				"x_rot",
				lerp(card_back_image.material.get_shader_parameter("x_rot"), 0.0, return_speed * delta)
			)

		# Slot-aware z_index
		if cards_current_slot:
			z_index = cards_current_slot.z_index + 1
		else:
			z_index = original_z_index

func _on_area_2d_mouse_entered() -> void:
	hovering = true
	emit_signal("hovered", self)

func _on_area_2d_mouse_exited() -> void:
	hovering = false
	emit_signal("hovered_off", self)
