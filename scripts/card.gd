extends Node2D
class_name Card

signal hovered
signal hovered_off

@export var card_name: String = "Basic"  # Default card type
@export var card_id: int = 0

@export var card_action_1: String 
@export var card_action_1_value: int 
@export var card_action_1_priority: int
@export var card_action_1_tags: Array
@export var card_action_2: String 
@export var card_action_2_value: int 
@export var card_action_2_priority: int
@export var card_action_2_tags: Array
@export var card_action_3: String 
@export var card_action_3_value: int 
@export var card_action_3_priority: int
@export var card_action_3_tags: Array

@export var card_owner: String

@export var max_rotation := 30.0
@export var follow_speed := 10.0
@export var return_speed := 7.0

@onready var desc_label = %ActionDescriptionLabel
@onready var tag_container = %TagContainer
@onready var tag_label = %TagLabel

var hand_position
var cards_current_slot
var hovering := false
var original_z_index := 1

var card_image: Sprite2D
var card_back_image: Sprite2D

var sounds = {
	"place": preload("res://Assets/Audio/card-place-2.ogg"),
	"pickup": preload("res://Assets/Audio/card-place-1.ogg")
}

func _ready() -> void:
	get_parent().connect_card_signals(self)

	card_image = $CardImage
	card_back_image = $CardBackImage

	if card_image and card_image.material:
		card_image.material = card_image.material.duplicate()
	if card_back_image and card_back_image.material:
		card_back_image.material = card_back_image.material.duplicate()

	original_z_index = z_index

func setup(c_name: String, data: Array, c_owner: String) -> void:
	card_name = c_name
	card_id = data[0]
	card_owner = c_owner
	
	# Action 1 (Indices 1, 2, 3, 4)
	card_action_1 = str(data[1]) if data[1] != null else ""
	card_action_1_value = data[2] if data[2] != null else 0.0
	card_action_1_priority = data[3] if data[3] != null else 0
	card_action_1_tags = data[4] if data[4] != null else []
	
	# Action 2 (Indices 5, 6, 7, 8)
	card_action_2 = str(data[5]) if data[5] != null else ""
	card_action_2_value = data[6] if data[6] != null else 0.0
	card_action_2_priority = data[7] if data[7] != null else 0
	card_action_2_tags = data[8] if data[8] != null else []
	
	# Action 3 (Indices 9, 10, 11, 12)
	card_action_3 = str(data[9]) if data[9] != null else ""
	card_action_3_value = data[10] if data[10] != null else 0.0
	card_action_3_priority = data[11] if data[11] != null else 0
	card_action_3_tags = data[12] if data[12] != null else []
	
	# Update Visuals
	var texture_path = "res://Assets/Textures/Cards/card_" + c_name + ".png"
	if FileAccess.file_exists(texture_path):
		$CardImage.texture = load(texture_path)

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
	var card_data = CardDatabase.CARDS[card_name]
	var full_description = ""
	var tag_list = []
	
	var player = get_node("/root/Main/%Player")
	var battle_manager = get_node("/root/Main/BattleManager") # Adjust path to your BattleManager
	
	# Determine the active multiplier for this hover
	var current_mult = player.current_mult
	if current_mult == 1.0: 
		current_mult = player.next_mult
		
	var is_multiplied = current_mult != 1.0

	# 1. TEMPLATES: Define how each action should read
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

	for i in [1, 5, 9]:
		var action_name = card_data[i]
		if action_name == null: continue
		
		var base_value = card_data[i+1]
		var tags = card_data[i+3]
		var display_value = str(base_value)
		
		# 2. FORMAT VALUE (with BBCode color)
		if typeof(base_value) == TYPE_FLOAT or typeof(base_value) == TYPE_INT:
			if is_multiplied:
				var new_val = base_value * current_mult
				var color = "#00ff00" if current_mult > 1.0 else "#ff4444"
				display_value = "[color=%s]%s[/color]" % [color, str(new_val)]

		# 3. BUILD NATURAL STRING
		var template = action_templates.get(action_name, action_name + ": %s")
		
		# If the action doesn't use a value (like Nullify), don't pass one
		if action_name == "Nullify" or action_name == "Nothing":
			full_description += template + "\n"
		else:
			full_description += (template % display_value) + "\n"
		
		# 4. TAGS & RETRIGGERS
		for tag_id in tags:
			var tag_name = CardDatabase.tags.keys()[tag_id]
			if not tag_list.has(tag_name):
				tag_list.append(tag_name)

	# 5. SPECIAL: Add "REPLAY" tag if card is going to retrigger
	# We check which slot this card is in to see if it has a scheduled retrigger
	var slot_idx = _get_current_slot_index()
	if slot_idx != -1:
		var extra_runs = battle_manager.player_retrigger_counts[slot_idx]
		if extra_runs > 0:
			tag_list.append("REPLAY x" + str(extra_runs))

	# Update UI elements
	desc_label.text = "[center]" + full_description + "[/center]"
	
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
