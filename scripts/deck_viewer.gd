extends CanvasLayer

@export var card_scene: PackedScene = preload("res://scenes/player_card.tscn")
@onready var grid = %CardGrid

# Set these to match your card's visual size
const PREVIEW_SIZE = Vector2(200, 280) 

func display_deck(card_resources: Array[CardDataResource]):
	# 1. Clear previous cards
	for child in grid.get_children():
		child.queue_free()
	
	# 2. Create a copy so we don't mess up the actual draw order
	var display_list = card_resources.duplicate()
	
	# 3. Sort alphabetically by the card's display_name
	display_list.sort_custom(func(a, b): return a.display_name < b.display_name)
	
	# 4. Instance the visuals
	for card_data in display_list:
		if card_data:
			var wrapper = Control.new()
			wrapper.custom_minimum_size = PREVIEW_SIZE
			grid.add_child(wrapper)

			var new_card = card_scene.instantiate() as Card
			new_card.is_preview = true 
			wrapper.add_child(new_card)
			
			new_card.position = PREVIEW_SIZE / 2
			new_card.scale = Vector2(0.8, 0.8) 

			new_card.setup(card_data, "Player")
	
	show()

func _input(event):
	# Close viewer on ESC or right click
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT):
		hide_deck()

func hide_deck():
	hide()


func _on_close_button_pressed() -> void:
	hide_deck()
