extends Node2D

const CARD_SCENE_PATH = "res://scenes/card.tscn"
const PASSIVE_SCENE_PATH = "res://scenes/passive_card.tscn"
const CARD_DRAW_SPEED = 0.2

var active_deck: Array[CardDataResource] = []
var graveyard: Array[CardDataResource] = []
var starting_passives: Array[PassiveCardResource] = []

func load_enemy_data(cards: Array[CardDataResource], passives: Array[PassiveCardResource]):
	active_deck = cards.duplicate()
	starting_passives = passives.duplicate()
	active_deck.shuffle()
	prepare_ui()

func prepare_ui():
	$RichTextLabel.text = str(active_deck.size())

func draw_card():
	if active_deck.is_empty() and graveyard.size() > 0:
		active_deck = graveyard.duplicate()
		graveyard.clear()
		active_deck.shuffle()
	
	if !active_deck.is_empty():
		var card_data = active_deck.pop_front()
		prepare_ui()

		var new_card = preload(CARD_SCENE_PATH).instantiate() as Card
		new_card.setup(card_data, "Enemy")
		new_card.interactable = false 
		
		# Flip handling
		if new_card.has_node("CardImage"): new_card.get_node("CardImage").visible = false
		if new_card.has_node("CardBackImage"): new_card.get_node("CardBackImage").visible = true

		%CardManager.add_child(new_card)
		new_card.global_position = global_position
		%EnemyHand.add_card_to_hand(new_card, CARD_DRAW_SPEED)
		new_card.play_audio("pickup")

func spawn_starting_passives():
	for res in starting_passives:
		var new_passive = preload(PASSIVE_SCENE_PATH).instantiate() as PassiveCard
		%EnemyPassives.add_child(new_passive)
		new_passive.setup(res)
		new_passive.global_position = self.global_position
		
		if new_passive.has_node("AnimationPlayer"):
			new_passive.get_node("AnimationPlayer").play("card_flip")
		
		if %EnemyPassives.has_method("add_to_passive_hand"):
			%EnemyPassives.add_to_passive_hand(new_passive)
