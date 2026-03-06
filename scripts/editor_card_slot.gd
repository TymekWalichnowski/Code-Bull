extends Control

var card_data: CardDataResource
var source_grid: String # "Inventory" or "Deck"

func _get_drag_data(_at_position):
	# Create a preview of the card to follow the mouse
	var preview = Control.new()
	var card_visual = get_child(0).duplicate() # Duplicate the Node2D Card
	card_visual.position = Vector2.ZERO
	card_visual.scale = Vector2(0.5, 0.5) # Shrink it slightly while dragging
	preview.add_child(card_visual)
	set_drag_preview(preview)
	
	# Return the data we are carrying
	return {"card_data": card_data, "source": source_grid}
