extends Node2D
class_name BaseCard

signal hovered(card)
signal hovered_off(card)

@export var interactable: bool = true
@export var max_rotation: float = 30.0
@export var follow_speed: float = 10.0
@export var return_speed: float = 7.0

var hovering: bool = false
var is_dragged: bool = false 
var cards_current_slot = null
var original_z_index := 10
var hand_position: Vector2 = Vector2.ZERO

var is_preview: bool = false
var is_inventory: bool = false

# Child classes will add their specific visual nodes (SubViewportContainer, Sprites, etc.) to this array
var visual_nodes_to_rotate: Array = []

var sounds = {
	"place": preload("res://assets/audio/card-place-2.ogg"),
	"pickup": preload("res://assets/audio/card-place-1.ogg"),
	"use": preload("res://assets/audio/card-slide-2.ogg")
}

func _ready() -> void:
	original_z_index = z_index
	
	# Try three ways to find the manager to ensure we connect
	var manager = get_tree().get_first_node_in_group("card_manager")
	if not manager:
		manager = get_node_or_null("/root/Main/CardManager") # Adjust path if needed
	if not manager and get_parent().has_method("connect_card_signals"):
		manager = get_parent()

	if manager and manager.has_method("connect_card_signals"):
		manager.connect_card_signals(self)
	else:
		push_warning("BaseCard: Could not find CardManager to connect signals!")

func duplicate_materials():
	for node in visual_nodes_to_rotate:
		if node and node.material:
			node.material = node.material.duplicate()

func _process(delta: float) -> void:
	if visual_nodes_to_rotate.is_empty(): return
	
	if is_dragged:
		_lerp_shader_rotations(0.0, 0.0, return_speed * delta)
		return 

	# Use the original_z_index that the Hand script assigned!
	var base_z = original_z_index
	if cards_current_slot:
		base_z = cards_current_slot.z_index + 1

	if hovering and interactable:
		# Grab the first node as our reference for mouse position
		var ref_node = visual_nodes_to_rotate[0]
		var local_mouse = ref_node.get_local_mouse_position()
		
		var half_x = 1.0
		var half_y = 1.0
		var x_ratio = 0.0
		var y_ratio = 0.0
		
		# Handle logic regardless of if it's a Control (Container) or Sprite2D
		if ref_node is Control:
			half_x = ref_node.size.x * 0.5
			half_y = ref_node.size.y * 0.5
			x_ratio = clamp(local_mouse.x / half_x - 1.0, -1.0, 1.0)
			y_ratio = clamp(local_mouse.y / half_y - 1.0, -1.0, 1.0)
		else:
			half_x = ref_node.texture.get_size().x * 0.5
			half_y = ref_node.texture.get_size().y * 0.5
			x_ratio = clamp(local_mouse.x / half_x, -1.0, 1.0)
			y_ratio = clamp(local_mouse.y / half_y, -1.0, 1.0)

		var target_y = -x_ratio * (max_rotation * 0.4 if cards_current_slot else max_rotation)
		var target_x = y_ratio * (max_rotation * 0.4 if cards_current_slot else max_rotation)

		_lerp_shader_rotations(target_x, target_y, follow_speed * delta)
		
		z_index = (base_z + 10) if (is_preview or is_inventory) else (base_z + (15 if cards_current_slot else 100))
	else:
		_lerp_shader_rotations(0.0, 0.0, return_speed * delta)
		z_index = base_z

func _lerp_shader_rotations(tx: float, ty: float, weight: float):
	for node in visual_nodes_to_rotate:
		if node and node.material:
			var current_y = node.material.get_shader_parameter("y_rot")
			var current_x = node.material.get_shader_parameter("x_rot")
			node.material.set_shader_parameter("y_rot", lerp(current_y, ty, weight))
			node.material.set_shader_parameter("x_rot", lerp(current_x, tx, weight))

func _on_area_2d_mouse_entered() -> void:
	if not interactable or is_dragged or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): 
		return
	# NO MORE FALLBACK LOGIC HERE. The CardManager is the absolute authority.
	emit_signal("hovered", self)

func _on_area_2d_mouse_exited() -> void:
	if not interactable: return
	emit_signal("hovered_off", self)

func play_audio(name: String) -> void:
	if sounds.has(name) and has_node("AudioStreamPlayer"):
		$AudioStreamPlayer.stream = sounds[name]
		$AudioStreamPlayer.play()
