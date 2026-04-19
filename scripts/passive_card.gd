extends Node2D
class_name PassiveCard

signal hovered
signal hovered_off

@export var data: PassiveCardResource
@export var interactable: bool = true

@export var max_rotation = 20.0
@export var follow_speed = 10.0
@export var return_speed = 7.0

@onready var desc_label = %ActionDescriptionLabel
@onready var card_image = %CardImage

var hovering = false
var original_z_index := 10
var is_preview: bool = false
var is_inventory: bool = false

func setup(resource: PassiveCardResource):
	data = resource
	if card_image and card_image.material:
		card_image.material = card_image.material.duplicate()
	
	update_visuals()
	update_hover_ui()

func _ready() -> void:
	original_z_index = z_index
	var card_manager = get_tree().get_first_node_in_group("card_manager") 
	if card_manager and card_manager.has_method("connect_card_signals"):
		card_manager.connect_card_signals(self)

func _process(delta: float) -> void:
	if has_node("%UIOverlay") and %UIOverlay:
		%UIOverlay.rotation = -rotation
	
	if not card_image or not card_image.texture:
		return

	if hovering and interactable:
		var local_mouse = card_image.to_local(get_global_mouse_position())
		var half = card_image.texture.get_size() * 0.5
		var x_ratio = clamp(local_mouse.x / half.x, -1.0, 1.0)
		var y_ratio = clamp(local_mouse.y / half.y, -1.0, 1.0)

		var target_y = -x_ratio * max_rotation
		var target_x = y_ratio * max_rotation

		_lerp_shader_rotations(target_x, target_y, follow_speed * delta)
		z_index = 100 if not (is_preview or is_inventory) else original_z_index + 10
	else:
		_lerp_shader_rotations(0.0, 0.0, return_speed * delta)
		z_index = original_z_index

func _lerp_shader_rotations(tx: float, ty: float, weight: float):
	if card_image and card_image.material:
		card_image.material.set_shader_parameter("y_rot", lerp(card_image.material.get_shader_parameter("y_rot"), ty, weight))
		card_image.material.set_shader_parameter("x_rot", lerp(card_image.material.get_shader_parameter("x_rot"), tx, weight))

func _on_area_2d_mouse_entered() -> void:
	if not interactable: return
	hovering = true
	update_hover_ui()
	emit_signal("hovered", self)

func _on_area_2d_mouse_exited() -> void:
	if not interactable: return
	hovering = false
	update_hover_ui()
	emit_signal("hovered_off", self)

func update_visuals():
	if not data: return
	
	if has_node("Label"):
		$Label.text = data.card_name
	
	if has_node("ValueLabel"):
		$ValueLabel.text = str(data.value)
		
	if card_image and data.card_image:
		card_image.texture = data.card_image

func update_hover_ui():
	if desc_label == null or data == null:
		return

	# Match the visibility logic of your Action Card
	%DescriptionOverlay.visible = hovering

	if not hovering:
		return

	var full_description = data.description 
	
	# 1. Handle [value] replacement
	if "[value]" in full_description:
		# Format to 1 decimal if it's not a whole number, else keep it clean
		var val_string = str(data.value) if fmod(data.value, 1.0) != 0 else str(int(data.value))
		full_description = full_description.replace("[value]", val_string)

	# 2. Handle [target_slot] replacement
	if "[target_slot]" in full_description:
		var slot_text = ""
		slot_text = "Slot " + str(data.target_slot)
		
		full_description = full_description.replace("[target_slot]", slot_text)

	# 3. Apply formatting (Bullet point like the Action Cards)
	desc_label.text = "- " + full_description.strip_edges()

	# 4. Handle Type Labels (Optional: you can add more metadata here)
	# If you have a separate label for type:
	# type_label.text = "[b]Type[/b]: Passive"

func play_trigger_anim():
	if has_node("AnimationPlayer") and $AnimationPlayer.has_animation("passive_trigger"):
		$AnimationPlayer.play("passive_trigger")
