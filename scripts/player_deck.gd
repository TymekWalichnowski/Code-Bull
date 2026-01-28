extends Node2D

const CARD_SCENE_PATH = "res://scenes/player_card.tscn"
const CARD_DRAW_SPEED = 0.2
const STARTING_HAND_SIZE = 5

var player_deck = ["Double Hit", "2 Of Spades", "Fifty Fifty", "Multiply", "Divide", "Draw 2", "Sword", "Sword"]
var card_database_reference 
var drawn_card_this_turn = false

var graveyard = []

func _ready() -> void:
	$RichTextLabel.text = str(player_deck.size())
	card_database_reference = preload("res://scripts/card_database.gd")
	for i in range(STARTING_HAND_SIZE):
		draw_card()
		drawn_card_this_turn = false
	drawn_card_this_turn = true

func draw_card():
	if player_deck.size() == 0 and graveyard.size() > 0:
		# Refill deck from graveyard
		for card_node in graveyard:
			player_deck.append(card_node.card_name)
			card_node.visible = true  # make sure it’s usable again
		graveyard.clear()
		player_deck.shuffle()  # optional shuffle
		$Area2D/CollisionShape2D.disabled = true

	var card_drawn_name = player_deck.pop_front() # pop_front is cleaner than erase
	$RichTextLabel.text = str(player_deck.size())

	# Check if card exists in database
	if not CardDatabase.CARDS.has(card_drawn_name):
		push_error("Card name not found in database: " + card_drawn_name)
		return

	var card_data = CardDatabase.CARDS[card_drawn_name]
	var card_owner = "Player"
	# Instantiate
	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate() as Card

	# Logic: Pass the data to the card itself to handle setup
	new_card.setup(card_drawn_name, card_data, card_owner)

	# Visuals: Add to hand
	%CardManager.add_child(new_card)
	new_card.name = "Card_" + card_drawn_name # Avoid duplicate node names
	
	if new_card.has_node("AnimationPlayer"):
		new_card.get_node("AnimationPlayer").play("card_flip")
		
	%PlayerHand.add_card_to_hand(new_card, CARD_DRAW_SPEED)

func reset_draw():
	drawn_card_this_turn = false
