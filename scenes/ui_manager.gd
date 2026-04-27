extends Node

@onready var info_panel = %InfoPanel # Your Panel node
@onready var card_title_label = %CardTitle
@onready var card_image2 = %CardImage
@onready var desc_container = %DescriptionContainer # A VBoxContainer inside the Panel
@onready var tag_container = %TagDisplayContainer
@export var tag_display_scene: PackedScene

var panel_tween: Tween

func _ready():
	# Position panel off-screen left initially
	info_panel.position.x = -info_panel.size.x - 50
	
	# Connect to the CardManager signals
	var card_manager = %CardManager
	card_manager.connect("hovered_over_card_signal", _on_card_hovered)
	card_manager.connect("hovered_off_card_signal", _on_card_unhovered)

func _on_card_hovered(card):
	_update_panel_content(card)
	_animate_panel(true)

func _on_card_unhovered(_card):
	_animate_panel(false)

func _update_panel_content(card):
	# Clear old Actions & Tags
	for child in desc_container.get_children(): child.queue_free()
	for child in tag_container.get_children(): child.queue_free()

	# If it's a Normal Card
	if card is Card:
		card_title_label.text = card.card_name
		card_image2.texture = card.card_image.texture
		
		var c_mult = card.card_data.multiplier if card.card_data.multiplier != 0 else 1.0
		var all_tags: Array[TagResource] = []
		if "tags" in card.card_data: all_tags.append_array(card.card_data.tags)

		for action in card.card_data.actions:
			if not action or action.description == "": continue
			
			var row = HBoxContainer.new()
			desc_container.add_child(row)
			
			if action.icon:
				var rect = TextureRect.new()
				rect.texture = action.icon
				rect.custom_minimum_size = Vector2(24, 24)
				rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				row.add_child(rect)
			
			var lbl = RichTextLabel.new()
			lbl.bbcode_enabled = true
			lbl.fit_content = true
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			var a_mult = action.action_multiplier if action.action_multiplier != 0 else 1.0
			var final_val = action.value * a_mult * c_mult
			var val_str = "[color=%s]%.1f[/color]" % ["#00ff00" if (a_mult*c_mult) > 1.0 else "#ff4444", final_val] if (a_mult*c_mult) != 1.0 else str(action.value)
			
			lbl.text = action.description.replace("[value]", val_str)
			row.add_child(lbl)
			
			if "tags" in action: all_tags.append_array(action.tags)

		# Build Tags
		var seen_tags = []
		for tag in all_tags:
			if not tag or not tag.visible or tag.tag_name in seen_tags: continue
			seen_tags.append(tag.tag_name)
			
			var t_ui = tag_display_scene.instantiate()
			tag_container.add_child(t_ui)
			t_ui.get_node("%TagTitle").text = tag.tag_name
			t_ui.get_node("%TagDescription").text = tag.description

	# If it's a Passive Card
	elif card is PassiveCard:
		card_title_label.text = card.data.card_name
		if card.data.card_image:
			card_image2.texture = card.data.card_image
		
		var lbl = RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Replace [value] with the passive card's value
		var val_string = str(card.data.value) if fmod(card.data.value, 1.0) != 0 else str(int(card.data.value))
		lbl.text = card.data.description.replace("[value]", val_string)
		
		desc_container.add_child(lbl)

func _animate_panel(show: bool):
	if panel_tween: panel_tween.kill()
	panel_tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var target_x
	if show:
		target_x = 20 
		tag_container.show()
	else:
		target_x = (-info_panel.size.x - 50)
		tag_container.hide()
	panel_tween.tween_property(info_panel, "position:x", target_x, 0.4)
