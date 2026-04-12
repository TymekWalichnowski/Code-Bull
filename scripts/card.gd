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

@export var effect_display_scene: PackedScene
@export var texture_retrigger: Texture2D
@export var texture_nullify: Texture2D

@onready var effect_display_container = %EffectDisplayContainer

@onready var desc_label = %ActionDescriptionLabel
@onready var tag_container = %TagContainer
@onready var tag_label = %TagLabel

@onready var glow_sprite = %Glow
@onready var debuff_sprite = %Glow 
@onready var buff_sprite = %Glow
@onready var effect_animation_player = %EffectPlayer
@onready var effect_label = get_node_or_null("%EffectLabel") # <-- Added for effect counts

var hovering = false
var is_dragged = false # <-- Tracks drag state
var original_z_index := 10
var cards_current_slot = null
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
var nullified: int = 0 # <-- Added for effect counts

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
		if card_image.material:
			card_image.material.set_shader_parameter("y_rot", 0.0)
			card_image.material.set_shader_parameter("x_rot", 0.0)
	
	update_hover_ui()

func _process(delta: float) -> void:
	if has_node("%UIOverlay") and %UIOverlay:
		%UIOverlay.rotation = -rotation
		
	if not card_image or not card_image.texture:
		return

	# --- FIX: Bypass hover logic if being dragged ---
	if is_dragged:
		_lerp_shader_rotations(0.0, 0.0, return_speed * delta)
		return 

	var base_z = original_z_index
	if cards_current_slot:
		base_z = cards_current_slot.z_index + 1
	
	if hovering and interactable: 
		update_hover_ui()
		var local_mouse = card_image.to_local(get_global_mouse_position())
		var half = card_image.texture.get_size() * 0.5
		var x_ratio = clamp(local_mouse.x / half.x, -1.0, 1.0)
		var y_ratio = clamp(local_mouse.y / half.y, -1.0, 1.0)

		var target_y = -x_ratio * (max_rotation * 0.4 if cards_current_slot else max_rotation)
		var target_x = y_ratio * (max_rotation * 0.4 if cards_current_slot else max_rotation)

		_lerp_shader_rotations(target_x, target_y, follow_speed * delta)
		
		if is_preview or is_inventory:
			z_index = base_z + 10
		else:
			z_index = base_z + (15 if cards_current_slot else 100)
	else:
		_lerp_shader_rotations(0.0, 0.0, return_speed * delta)
		z_index = base_z

func _lerp_shader_rotations(tx: float, ty: float, weight: float):
	for img in [card_image, card_back_image]:
		if img and img.material:
			img.material.set_shader_parameter("y_rot", lerp(img.material.get_shader_parameter("y_rot"), ty, weight))
			img.material.set_shader_parameter("x_rot", lerp(img.material.get_shader_parameter("x_rot"), tx, weight))

func _on_area_2d_mouse_entered() -> void:
	if not interactable or is_dragged: 
		return
	# --- FIX: Do not trigger hovers on cards if we are dragging something else ---
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return

	hovering = true
	update_hover_ui()
	emit_signal("hovered", self)

func _on_area_2d_mouse_exited() -> void:
	if not interactable:
		return
	hovering = false
	if tag_container:
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

	var is_enemy_hand_card = (card_owner == "Opponent" and cards_current_slot == null)
	var show_description = not is_enemy_hand_card or is_preview or is_inventory
	var show_tags = hovering and (show_description or is_preview or is_inventory)

	%DescriptionOverlay.visible = show_description
	%UIOverlay.visible = show_tags

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

	var lines = []
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

func update_visuals():
	var is_active = (retriggers > 0)
	
	if glow_sprite:
		glow_sprite.visible = is_active
		if is_active:
			if effect_animation_player and effect_animation_player.has_animation("retrigger_glow"):
				effect_animation_player.play("retrigger_glow")
		else:
			if effect_animation_player:
				effect_animation_player.stop()

	# --- NEW: Dynamic Effect UI ---
	if effect_display_container:
		# 1. Clear out the old displays so they don't infinitely stack
		for child in effect_display_container.get_children():
			child.queue_free()
			
		# 2. Rebuild the displays based on current counts
		if retriggers > 0:
			_add_effect_display(texture_retrigger, retriggers)
		if nullified > 0: 
			_add_effect_display(texture_nullify, nullified)

func _get_current_slot_index() -> int:
	if not cards_current_slot: 
		return -1
	var battle_manager = get_node_or_null("/root/Main/BattleManager")
	if battle_manager and "player_slots" in battle_manager:
		return battle_manager.player_slots.find(cards_current_slot)
	return -1

func declare_effect(effect_name) -> void:
	var label = %EffectDeclaration
	var display_time = 0.3
	# 1. Reset and Setup
	label.visible = true
	label.modulate.a = 1.0 # Ensure it's opaque
	label.pivot_offset = label.size / 2
	label.scale = Vector2.ZERO
	label.rotation_degrees = -25.0
	label.text = (effect_name)
	
	var tween = create_tween()
	
	# 2. THE APPEARANCE (Parallel)
	# We use a parallel sub-tween so scale and rotation happen at once
	var appearance = tween.parallel()
	appearance.tween_property(label, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appearance.tween_property(label, "rotation_degrees", 0.0, 0.6)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# 3. THE WAIT
	# The tween will pause here for the duration you specify
	tween.tween_interval(display_time)
	
	# 4. THE DISAPPEARANCE (Parallel)
	# Shrink it down and fade it out
	var disappearance = tween.parallel()
	disappearance.tween_property(label, "scale", Vector2.ZERO, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	disappearance.tween_property(label, "modulate:a", 0.0, 0.2)
	
	# 5. CLEANUP
	# Finally, hide the node entirely so it doesn't block mouse clicks
	tween.tween_callback(func(): label.visible = false)
	await tween.finished

func _add_effect_display(icon: Texture2D, count: int):
	if not effect_display_scene or not icon or not effect_display_container:
		return
		
	var display = effect_display_scene.instantiate()
	effect_display_container.add_child(display)
	
	# Unique names (%) work locally within instanced scenes!
	var img = display.get_node_or_null("%EffectImage")
	var lbl = display.get_node_or_null("%CountLabel")
	
	if img: img.texture = icon
	if lbl: lbl.text = "x" + str(count) # Optional: add "x" so it reads "x2"
