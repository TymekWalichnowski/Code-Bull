extends Sprite2D

@export var max_rotation := 20.0
@export var follow_speed := 10.0
@export var return_speed := 8.0

var hovering := false

func _ready():
	# Make shader material unique per card
	if material:
		material = material.duplicate()

func _process(delta):
	if not material or not texture:
		return

	if hovering:
		var local_mouse := to_local(get_global_mouse_position())
		var half := texture.get_size() * 0.5

		var x_ratio = clamp(local_mouse.x / half.x, -1.0, 1.0)
		var y_ratio = clamp(local_mouse.y / half.y, -1.0, 1.0)

		var target_y = -x_ratio * max_rotation
		var target_x = y_ratio * max_rotation

		var current_y = material.get_shader_parameter("y_rot")
		var current_x = material.get_shader_parameter("x_rot")

		material.set_shader_parameter(
			"y_rot",
			lerp(current_y, target_y, follow_speed * delta)
		)
		material.set_shader_parameter(
			"x_rot",
			lerp(current_x, target_x, follow_speed * delta)
		)
	else:
		var current_y = material.get_shader_parameter("y_rot")
		var current_x = material.get_shader_parameter("x_rot")

		material.set_shader_parameter(
			"y_rot",
			lerp(current_y, 0.0, return_speed * delta)
		)
		material.set_shader_parameter(
			"x_rot",
			lerp(current_x, 0.0, return_speed * delta)
		)

func _on_mouse_entered():
	hovering = true

func _on_mouse_exited():
	hovering = false
