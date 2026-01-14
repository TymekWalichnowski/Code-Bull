extends Sprite2D

@export var max_rotation := 30.0
@export var follow_speed := 10.0  # how fast the tilt follows the mouse
@export var return_speed := 7.0    # how fast it returns to 0 when not hovering

func _ready():
	# Make the shader unique per card
	if material:
		material = material.duplicate()

func _process(delta):
	if not material or not texture:
		return

	var hovering := _is_mouse_over()

	if hovering:
		# Get local mouse position relative to card center
		var local_mouse := to_local(get_global_mouse_position())
		var half := texture.get_size() * 0.5

		# Map mouse position to -1 .. 1 range
		var x_ratio = clamp(local_mouse.x / half.x, -1.0, 1.0)
		var y_ratio = clamp(local_mouse.y / half.y, -1.0, 1.0)

		# Compute target rotations
		var target_y = -x_ratio * max_rotation
		var target_x = y_ratio * max_rotation

		# Smoothly interpolate current shader values
		material.set_shader_parameter(
			"y_rot",
			lerp(material.get_shader_parameter("y_rot"), target_y, follow_speed * delta)
		)
		material.set_shader_parameter(
			"x_rot",
			lerp(material.get_shader_parameter("x_rot"), target_x, follow_speed * delta)
		)
	else:
		# Smoothly return to zero when not hovering
		material.set_shader_parameter(
			"y_rot",
			lerp(material.get_shader_parameter("y_rot"), 0.0, return_speed * delta)
		)
		material.set_shader_parameter(
			"x_rot",
			lerp(material.get_shader_parameter("x_rot"), 0.0, return_speed * delta)
		)

# Helper function to check if mouse is over the sprite
func _is_mouse_over() -> bool:
	var local_mouse := to_local(get_global_mouse_position())
	var half := texture.get_size() * 0.5
	return abs(local_mouse.x) <= half.x and abs(local_mouse.y) <= half.y
