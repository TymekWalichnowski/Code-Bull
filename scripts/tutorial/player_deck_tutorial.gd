extends "res://scripts/player_deck.gd"

@export var starting_deck_tutorial: Array[CardDataResource]

func prepare_deck() -> void:
	# TUTORIAL DECK
	if starting_deck.is_empty():
		push_warning("Starting deck is empty!")
	
	current_deck = starting_deck_tutorial.duplicate()

	if card_database:
		card_database._initialize_database()
	
	$RichTextLabel.text = str(current_deck.size())

# 2. Draw a single card (Step 2 of setup, called by BattleManager)
func draw_card():
	if current_deck.is_empty() and graveyard.size() > 0:
		current_deck = graveyard.duplicate()
		current_deck.shuffle()
		graveyard.clear()
	
	if !current_deck.is_empty():
		var card_data = current_deck.pop_front()
		$RichTextLabel.text = str(current_deck.size())

		var new_card = preload(CARD_SCENE_PATH).instantiate() as Card
		new_card.setup(card_data, "Player")
		new_card.interactable = true 
		new_card.name = "Card_" + card_data.display_name
		
		%CardManager.add_child(new_card)
		new_card.global_position = global_position 

		if new_card.has_node("AnimationPlayer"):
			new_card.get_node("AnimationPlayer").play("card_flip")
		
		new_card.play_audio("pickup")
		%PlayerHand.add_card_to_hand(new_card, CARD_DRAW_SPEED)
		# We don't await the timer here anymore, BattleManager handles timing
	else:
		print("Player Deck and Graveyard are empty!")

# 3. Spawn passives (Step 3 of setup)
func spawn_starting_passives():
	for i in range(starting_passives.size()):
		var res = starting_passives[i]
		var new_passive_card = preload(PASSIVE_SCENE_PATH).instantiate() as PassiveCard
		
		# 1. Add child to the container
		%PlayerPassives.add_child(new_passive_card)
		
		# 2. Setup data
		new_passive_card.setup(res)
		
		# 3. Start at deck position so they "fly" out to the hand
		new_passive_card.global_position = self.global_position
		
		if new_passive_card.has_node("AnimationPlayer"):
			new_passive_card.get_node("AnimationPlayer").play("card_flip")
		
		# 4. Tell the passive hand to fan it
		if %PlayerPassives.has_method("add_to_passive_hand"):
			await %PlayerPassives.add_to_passive_hand(new_passive_card)
		new_passive_card.play_audio("pickup")
