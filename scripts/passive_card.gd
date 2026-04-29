extends BaseCard
class_name PassiveCard

@export var data: PassiveCardResource

@onready var desc_label = %ActionDescriptionLabel
@onready var card_image = %CardImage
@onready var card_back_image = %CardBackImage

func setup(resource: PassiveCardResource):
	data = resource
	_initialize_visuals()

func _ready() -> void:
	super._ready() # Calls BaseCard's _ready()
	_initialize_visuals()
	
func _process(delta: float) -> void:
	super._process(delta) # Let BaseCard handle the rotation logic
	
	if has_node("%UIOverlay") and %UIOverlay:
		%UIOverlay.rotation = -rotation

func _initialize_visuals():
	# Tell BaseCard what to rotate
	visual_nodes_to_rotate = [card_image, card_back_image]
	duplicate_materials() # Setup shaders

	if not data: return
	
	if has_node("Label"): $Label.text = data.card_name
	if has_node("ValueLabel"): $ValueLabel.text = str(data.value)
	if card_image and data.card_image: card_image.texture = data.card_image
	
	if is_preview or is_inventory:
		if card_image: card_image.visible = true
		if card_back_image: card_back_image.visible = false
		if card_image.material:
			card_image.material.set_shader_parameter("y_rot", 0.0)
			card_image.material.set_shader_parameter("x_rot", 0.0)
			
	update_hover_ui()

func update_hover_ui():
	pass
	# not using currently
	#if desc_label == null or data == null: return
	#%DescriptionOverlay.visible = hovering
#
	#if not hovering: return
#
	#var full_description = data.description 
	#if "[value]" in full_description:
		#var val_string = str(data.value) if fmod(data.value, 1.0) != 0 else str(int(data.value))
		#full_description = full_description.replace("[value]", val_string)
#
	#if "[target_slot]" in full_description:
		#var slot_text = "Slot " + str(data.target_slot)
		#full_description = full_description.replace("[target_slot]", slot_text)
#
	#desc_label.text = "- " + full_description.strip_edges()

func play_trigger_anim():
	if has_node("AnimationPlayer") and $AnimationPlayer.has_animation("passive_trigger"):
		$AnimationPlayer.play("passive_trigger")
