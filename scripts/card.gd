extends Node2D
class_name Card

signal hovered
signal hovered_off

@export var card_data: CardDataResource
@export var card_owner: String
@export var interactable: bool = true

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
	"use": preload("res://assets/audio/card-slide-2.ogg")
}

var card_id: int = 0
var card_name: String = ""
var retriggers: int = 0


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
	update_hover_ui()

func _process(delta: float) -> void:
	%UIOverlay.rotation = -rotation
	if not card_image or not card_image.texture:
		return

	# Slot-aware z_index
	if cards_current_slot:
		z_index = cards_current_slot.z_index + 1
	else:
		z_index = original_z_index

	if hovering and interactable: 
		update_hover_ui()
		var local_mouse = card_image.to_local(get_global_mouse_position())
		var half = card_image.texture.get_size() * 0.5
		var x_ratio = clamp(local_mouse.x / half.x, -1.0, 1.0)
		var y_ratio = clamp(local_mouse.y / half.y, -1.0, 1.0)

		var target_y = -x_ratio * (max_rotation * 0.4 if cards_current_slot else max_rotation)
		var target_x = y_ratio * (max_rotation * 0.4 if cards_current_slot else max_rotation)

		_lerp_shader_rotations(target_x, target_y, follow_speed * delta)
		z_index = 100
	else:
		_lerp_shader_rotations(0.0, 0.0, return_speed * delta)

func _lerp_shader_rotations(tx: float, ty: float, weight: float):
	for img in [card_image, card_back_image]:
		if img and img.material:
			img.material.set_shader_parameter("y_rot", lerp(img.material.get_shader_parameter("y_rot"), ty, weight))
			img.material.set_shader_parameter("x_rot", lerp(img.material.get_shader_parameter("x_rot"), tx, weight))

func _on_area_2d_mouse_entered() -> void:
	if not interactable: 
		return
	hovering = true
	update_hover_ui()
	emit_signal("hovered", self)

func _on_area_2d_mouse_exited() -> void:
	if not interactable:
		return
	hovering = false
	tag_container.visible = false
	update_hover_ui()
	emit_signal("hovered_off", self)

func play_audio(name: String) -> void:
	if sounds.has(name):
		$AudioStreamPlayer.stream = sounds[name]
		$AudioStreamPlayer.play()
	else:
		push_warning("Sound not found: " + name)

func update_hover_ui():
	if desc_label == null or card_data == null:
		return

	# -----------------------------
	# VISIBILITY RULES
	# -----------------------------
	var is_enemy_hand_card = (card_owner == "Opponent" and cards_current_slot == null)

	# Description: always visible except enemy hand
	var show_description = not is_enemy_hand_card or is_preview or is_inventory

	# Tags: ONLY when hovering (unless preview/inventory)
	var show_tags = hovering and (show_description or is_preview or is_inventory)

	%DescriptionOverlay.visible = show_description
	%UIOverlay.visible = show_tags

	# -----------------------------
	# 2. BUILD DESCRIPTION TEXT
	# -----------------------------
	var full_description := ""
	var tag_list := []

	var c_mult = card_data.multiplier if card_data.multiplier != 0 else 1.0

	for action in card_data.actions:
		if not action or action.description == "":
			continue

		var a_mult = action.action_multiplier if action.action_multiplier != 0 else 1.0
		var total_multiplier = c_mult * a_mult
		var final_value = action.value * total_multiplier

		var display_value := ""
		if total_multiplier != 1.0:
			var color = "#00ff00" if total_multiplier > 1.0 else "#ff4444"
			display_value = "[color=%s]%.1f[/color]" % [color, final_value]
		else:
			display_value = str(action.value)

		var action_text = action.description.replace("[value]", display_value)
		full_description += "- " + action_text + "\n"

		for tag in action.tags:
			if not tag_list.has(tag):
				tag_list.append(tag)

	desc_label.text = full_description.strip_edges()

	# -----------------------------
	# 3. BUILD TAG TEXT
	# -----------------------------
	var lines = []
	
	# Add the card type for debugging
	if card_data and card_data.type != "":
		lines.append("[b]Type[/b]: " + card_data.type)

	if tag_list.size() > 0 or lines.size() > 0:
		var tag_descriptions = {
			"Ethereal": "Cannot be modified by external effects.",
			"Retrigger": "Triggers again when activated."
		}

		for tag in tag_list:
			var d = tag_descriptions.get(tag, "")
			if d != "":
				lines.append("[b]%s[/b]: %s" % [tag, d])
			else:
				lines.append(tag)

		tag_label.text = "TAGS:\n" + "\n".join(lines)
		tag_container.visible = show_tags
	else:
		tag_container.visible = false


# Helper to find which slot index this card is currently sitting in, may be useless rn?
func _get_current_slot_index() -> int:
	if not cards_current_slot: return -1
	var slots = get_node("/root/Main/BattleManager").player_slots
	return slots.find(cards_current_slot)

func update_retrigger_visuals():
	var is_active = (retriggers > 0)
	
	if not glow_sprite or not effect_animation_player:
		return
		
	glow_sprite.visible = is_active
	
	if is_active:
		if effect_animation_player.has_animation("retrigger_glow"):
			effect_animation_player.play("retrigger_glow")
	else:
		effect_animation_player.stop()
