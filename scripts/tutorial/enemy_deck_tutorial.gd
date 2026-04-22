extends "res://scripts/enemy_deck.gd"

func prepare_deck() -> void:
	if starting_deck.is_empty():
		push_warning("Enemy starting deck is empty!")
	
	active_deck = starting_deck.duplicate()
	$RichTextLabel.text = str(active_deck.size())

func draw_card():
	if active_deck.is_empty() and graveyard.size() > 0:
		active_deck = graveyard.duplicate()
		graveyard.clear()
		active_deck.shuffle()
	
	if !active_deck.is_empty():
		var card_data = active_deck.pop_front()
		$RichTextLabel.text = str(active_deck.size())

		var new_card = preload(CARD_SCENE_PATH).instantiate() as Card
		new_card.setup(card_data, "Enemy")
		new_card.interactable = false 
		
		if new_card.has_node("CardImage"):
			new_card.get_node("CardImage").visible = false
		if new_card.has_node("CardBackImage"):
			new_card.get_node("CardBackImage").visible = true

		%CardManager.add_child(new_card)
		new_card.global_position = global_position
		new_card.name = "Enemy_Card_" + card_data.display_name
		%EnemyHand.add_card_to_hand(new_card, CARD_DRAW_SPEED)
		new_card.play_audio("pickup")
	else:
		print("Enemy deck empty!")

func spawn_starting_passives():
	for i in range(starting_passives.size()):
		var res = starting_passives[i]
		var new_passive_card = preload(PASSIVE_SCENE_PATH).instantiate() as PassiveCard
		%EnemyPassives.add_child(new_passive_card)
		new_passive_card.setup(res)
		if new_passive_card.has_node("AnimationPlayer"):
			new_passive_card.get_node("AnimationPlayer").play("card_flip")
		
		new_passive_card.setup(res)
		var offset_x = 40 + (i * 140)
		new_passive_card.global_position = %EnemyPassives.global_position + Vector2(offset_x, 0)
		new_passive_card.play_audio("pickup")
