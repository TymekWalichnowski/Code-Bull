extends Node2D

const CARD_SCENE_PATH = "res://scenes/card.tscn"
const PASSIVE_SCENE_PATH = "res://scenes/passive_card.tscn"
const CARD_DRAW_SPEED = 0.2

var current_deck: Array[CardDataResource] = []
var graveyard: Array[CardDataResource] = []

func prepare_deck() -> void:
	# Pulling directly from your Global script
	var cards = PlayerDeckGlobal.global_player_cards
	var passives = PlayerDeckGlobal.global_player_passives
	
	if cards.is_empty():
		push_warning("PlayerDeckGlobal cards are empty!")
	
	current_deck = cards.duplicate()
	current_deck.shuffle()
	
	$RichTextLabel.text = str(current_deck.size())

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
		
		%CardManager.add_child(new_card)
		new_card.global_position = global_position 

		if new_card.has_node("AnimationPlayer"):
			new_card.get_node("AnimationPlayer").play("card_flip")
		
		new_card.play_audio("pickup")
		%PlayerHand.add_card_to_hand(new_card, CARD_DRAW_SPEED)

func spawn_starting_passives():
	# Use the global passives
	for res in PlayerDeckGlobal.global_player_passives:
		var new_passive = preload(PASSIVE_SCENE_PATH).instantiate() as PassiveCard
		%PlayerPassives.add_child(new_passive)
		new_passive.setup(res)
		new_passive.scale = Vector2(%PlayerPassives.CARD_SCALE, %PlayerPassives.CARD_SCALE)
		new_passive.global_position = self.global_position
		
		if new_passive.has_node("AnimationPlayer"):
			new_passive.get_node("AnimationPlayer").play("card_flip")
		
		await get_tree().process_frame
		if %PlayerPassives.has_method("add_to_passive_hand"):
			%PlayerPassives.add_to_passive_hand(new_passive)
