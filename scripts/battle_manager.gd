extends Node


func _on_end_turn_button_pressed() -> void:
	$"../EndTurnButton".disabled = true
	$"../EndTurnButton".visible = false
	
	$"../OpponentDeck".draw_card()
	
	# wait 1 second
