extends Node2D
class_name Card

signal hovered
signal hovered_off

@export var card_data: CardData
@export var card_owner: String

@export var max_rotation := 30.0
@export var follow_speed := 10.0
@export var return_speed := 7.0

@onready var desc_label = %ActionDescriptionLabel
@onready var tag_container = %TagContainer
@onready var tag_label = %TagLabel

var hovering := false
var original_z_index := 1
var cards_current_slot
var hand_position: Vector2 = Vector2.ZERO


var card_image: Sprite2D
var card_back_image: Sprite2D

var sounds = {
	"place": preload("res://assets/audio/card-place-2.ogg"),
	"pickup": preload("res://assets/audio/card-place-1.ogg")
}

var card_id: int = 0
var card_name: String = ""


func setup(data: CardData, owner: String) -> void:
	card_data = data
	card_owner = owner
	card_id = card_data.id
	card_name = card_data.display_name
	card_image = %CardImage
	card_back_image = %CardBackImage
	_apply_visuals()

func _ready() -> void:
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

func _process(delta: float) -> void:
	%UIOverlay.rotation = -rotation
	if not card_image or not card_image.texture:
		return

	# Reduce effect if card is in a slot
	var effect_max_rotation = max_rotation * 0.4 if cards_current_slot else max_rotation
	var effect_follow_speed = follow_speed * 0.5 if cards_current_slot else follow_speed


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
	desc_label.text = "" # clear text when not hovering
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

	if not card_data:
		return

	var full_description := ""
	var tag_list := []

	var player = get_node("/root/Main/Player")
	var battle_manager = get_node("/root/Main/BattleManager")

	var current_mult = player.current_mult
	if current_mult == 1.0:
		current_mult = player.next_mult

	var is_multiplied = current_mult != 1.0

	var action_templates = {
		"Attack": "Deal %s damage.",
		"Shield": "Gain %s shield.",
		"Multiply_Next_Card": "Multiply next played card by %s.",
		"Divide_Next_Card": "Divide opponent's next card by %s.",
		"Nullify": "Negate the opponent's next action.",
		"Draw_Card": "Draw %s card(s).",
		"Retrigger_Next_Slot": "Trigger next card slot %s extra time(s).",
		"Nothing": "Do nothing."
	}

	for action in card_data.actions:
		if not action:
			continue

		var display_value := str(action.value)

		if is_multiplied and action.value != 0:
			var new_val = action.value * current_mult
			var color = "#00ff00" if current_mult > 1.0 else "#ff4444"
			display_value = "[color=%s]%s[/color]" % [color, new_val]

		var template = action_templates.get(action.action_name, "%s")

		if action.action_name in ["Nullify", "Nothing"]:
			full_description += template + "\n"
		else:
			full_description += (template % display_value) + "\n"

		for tag in action.tags:
			if not tag_list.has(tag):
				tag_list.append(tag)

	desc_label.text = "[center]%s[/center]" % full_description

	if tag_list.size() > 0:
		tag_label.text = "TAGS:\n" + "\n".join(tag_list)
		tag_container.visible = true
	else:
		tag_container.visible = false

# Helper to find which slot index this card is currently sitting in, may be useless rn?
func _get_current_slot_index() -> int:
	if not cards_current_slot: return -1
	var slots = get_node("/root/Main/BattleManager").player_slots
	return slots.find(cards_current_slot)
