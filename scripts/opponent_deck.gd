extends Node2D

const CARD_SCENE_PATH = "res://scenes/opponent_card.tscn"
const CARD_DRAW_SPEED = 0.2
const STARTING_HAND_SIZE = 4 # starts with 1 hand less than player since automatically draws but probably want to fix this later

var opponent_deck = ["Draw 2", "Divide", "Block", "Block", "Basic", "Sword", "Sword"]
var card_database_reference 

var graveyard = []

func _ready() -> void:
	$RichTextLabel.text = str(opponent_deck.size())
	card_database_reference = preload("res://scripts/card_database.gd")
	for i in range(STARTING_HAND_SIZE):
		draw_card()

func draw_card():
	if opponent_deck.size() == 0 and graveyard.size() > 0:
		# Refill deck from graveyard
		for card_node in graveyard:
			opponent_deck.append(card_node.card_name)
			card_node.visible = true  # make sure it’s usable again
		graveyard.clear()
		opponent_deck.shuffle()  # optional shuffle

	# Get and remove the top card
	var card_drawn_name = opponent_deck.pop_front()
	$RichTextLabel.text = str(opponent_deck.size())

	# Safety check for database entry
	if not CardDatabase.CARDS.has(card_drawn_name):
		push_error("Opponent tried to draw non-existent card: " + card_drawn_name)
		return

	var card_data = CardDatabase.CARDS[card_drawn_name]

	# Instantiate the opponent card scene
	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()

	# Use the setup function
	new_card.setup(card_drawn_name, card_data)

	# Add to the world
	$"../CardManager".add_child(new_card)
	new_card.name = "Opponent_Card_" + card_drawn_name # Specific naming for debugging
	
	# Send to opponent hand
	$"../OpponentHand".add_card_to_hand(new_card, CARD_DRAW_SPEED)
