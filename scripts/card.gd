extends Node2D
class_name Card

signal hovered
signal hovered_off

@export var card_data: CardDataResource
@export var card_owner: String

@export var max_rotation = 30.0
@export var follow_speed = 10.0
@export var return_speed = 7.0

@onready var desc_label = %ActionDescriptionLabel
@onready var tag_container = %TagContainer
@onready var tag_label = %TagLabel

@onready var glow_sprite = %Glow
@onready var debuff_sprite = %Glow
@onready var buff_sprite = %Glow
@onready var effect_animation_player = %EffectPlayer

var hovering = false
var original_z_index := 10
var cards_current_slot
var hand_position: Vector2 = Vector2.ZERO


var card_image: Sprite2D
var card_back_image: Sprite2D

var is_preview: bool = false
var is_inventory: bool = false

var sounds = {
	"place": preload("res://assets/audio/card-place-2.ogg"),
	"pickup": preload("res://assets/audio/card-place-1.ogg"),
	"use": preload("res://Assets/audio/card-shove-3.ogg")
}

var card_id: int = 0
var card_name: String = ""


func setup(data: CardDataResource, owner: String) -> void:
	card_data = data.duplicate(true) 
	card_owner = owner
	card_id = card_data.id
	card_name = card_data.display_name
	card_image = %CardImage
	card_back_image = %CardBackImage
	_apply_visuals()

func _ready() -> void:
	if get_parent().has_method("connect_card_signals"):
		get_parent().connect_card_signals(self)

	card_image = %CardImage
	card_back_image = %CardBackImage

	if card_image.material:
		card_image.material = card_image.material.duplicate()
	if card_back_image.material:
		card_back_image.material = card_back_image.material.duplicate()

	original_z_index = z_index

	# Only apply visuals if data already exists (editor preview)
	if card_data:
		_apply_visuals()

func _apply_visuals():
	if not card_data:
		return
	if card_data.image_texture:
		card_image.texture = card_data.image_texture
	
	if is_preview or is_inventory:
		card_image.visible = true
		card_back_image.visible = false
		# Reset shader rotations so they aren't slanted in the grid
		if card_image.material:
			card_image.material.set_shader_parameter("y_rot", 0.0)
			card_image.material.set_shader_parameter("x_rot", 0.0)

func _process(delta: float) -> void:
	%UIOverlay.rotation = -rotation
	if not card_image or not card_image.texture:
		return

	# Reduce effect if card is in a slot
	var effect_max_rotation = max_rotation * 0.4 if cards_current_slot else max_rotation
	var effect_follow_speed = follow_speed * 0.5 if cards_current_slot else follow_speed
	
	if cards_current_slot:
		z_index = cards_current_slot.z_index + 1
	else:
		# This is the key: player_hand.gd updates this value constantly
		z_index = original_z_index


	if hovering:
		update_hover_ui()
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
		%UIOverlay.visible = false
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
	update_hover_ui()
	emit_signal("hovered", self)

func _on_area_2d_mouse_exited() -> void:
	hovering = false
	tag_container.visible = false
	emit_signal("hovered_off", self)

func play_audio(name: String) -> void:
	if sounds.has(name):
		$AudioStreamPlayer.stream = sounds[name]
		$AudioStreamPlayer.play()
	else:
		push_warning("Sound not found: " + name)

func update_hover_ui():
	%UIOverlay.visible = true
	if not card_data: return

	var full_description := ""
	var tag_list = []
	
	# Get the Card-Wide Multiplier
	var c_mult = card_data.multiplier if card_data.multiplier != 0 else 1.0

	for action in card_data.actions:
		if not action or action.description == "": continue

		# Calculate Logic
		var a_mult = action.action_multiplier if action.action_multiplier != 0 else 1.0
		var total_multiplier = c_mult * a_mult
		var final_value = action.value * total_multiplier
		
		var display_value_str := ""

		# UI feedback: If the value is different from base, color it
		if total_multiplier != 1.0:
			var color = "#00ff00" if total_multiplier > 1.0 else "#ff4444"
			display_value_str = "[color=%s]%.1f[/color]" % [color, final_value]
		else:
			display_value_str = str(action.value)
		
		var action_text = action.description.replace("[value]", display_value_str)
		full_description += "- " + action_text + "\n"

		# Collect tags for the tag box
		for tag in action.tags:
			if not tag_list.has(tag):
				tag_list.append(tag)

	desc_label.text = full_description

	# Tag Handling
	if tag_list.size() > 0:
		var tag_descriptions = {
			"Ethereal": "Cannot be modified by external effects.",
			"Retrigger": "Test description"
		}
		var lines = []
		for tag in tag_list:
			var d = tag_descriptions.get(tag, "")
			lines.append("[b]%s[/b]: %s" % [tag, d] if d != "" else tag)
		tag_label.text = "TAGS:\n" + "\n".join(lines)
		tag_container.visible = true
	else:
		tag_container.visible = false


# Helper to find which slot index this card is currently sitting in, may be useless rn?
func _get_current_slot_index() -> int:
	if not cards_current_slot: return -1
	var slots = get_node("/root/Main/BattleManager").player_slots
	return slots.find(cards_current_slot)

func set_retrigger_glow(is_active: bool):
	if not glow_sprite or not effect_animation_player:
		return
		
	glow_sprite.visible = is_active
	
	if is_active:
		# Ensure the animation name matches exactly what you named it in the editor
		if effect_animation_player.has_animation("retrigger_glow"):
			effect_animation_player.play("retrigger_glow")
	else:
		effect_animation_player.stop()
