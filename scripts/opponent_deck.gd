extends Node2D

const CARD_SCENE_PATH = "res://scenes/opponent_card.tscn"
const CARD_DRAW_SPEED = 0.2
const STARTING_HAND_SIZE = 4 # starts with 1 hand less than player since automatically draws but probably want to fix this later

var opponent_deck = ["Draw 2", "Multiply", "Block", "Block", "Basic", "Sword", "Sword"]
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

	print("draw opponent card")
	var card_drawn_name = opponent_deck[0]
	opponent_deck.erase(card_drawn_name)
	
	$RichTextLabel.text = str(opponent_deck.size())
	var card_data = card_database_reference.CARDS[card_drawn_name]
	var card_id = card_data[0]
	
	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()
	
	# Assign properties directly
	new_card.card_id = card_id        # For battle logic
	new_card.card_name = card_drawn_name  # Optional, human-readable
	
	var card_image_path = str("res://Assets/Textures/Cards/card_" + card_drawn_name + ".png")
	new_card.get_node("CardImage").texture = load(card_image_path)

	# Set card_id FIRST
	new_card.card_id = card_database_reference.CARDS[card_drawn_name][0]  # store as int property
	new_card.get_node("CardLabel").text = str(new_card.card_id)

	$"../CardManager".add_child(new_card)
	new_card.name = "Card"
	$"../OpponentHand".add_card_to_hand(new_card, CARD_DRAW_SPEED)
	print(new_card.card_id)
