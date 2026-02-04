extends Node2D

const CARD_SCENE_PATH = "res://scenes/opponent_card.tscn"
const CARD_DRAW_SPEED = 0.2
const STARTING_HAND_SIZE = 4

@export var card_database: CardDatabase2

var opponent_deck = [
	"Divide",
	"Fifty Fifty",
	"Sword",
	"Block",
	"Basic",
	"Sword",
	"Sword",
	"Sword"
]

var graveyard = []

func _ready() -> void:
	$RichTextLabel.text = str(opponent_deck.size())

	for i in range(STARTING_HAND_SIZE):
		draw_card()

func draw_card():
	print("opponent draw_card starting")
	if opponent_deck.is_empty() and graveyard.size() > 0:
		# Refill deck from graveyard
		for card_node in graveyard:
			opponent_deck.append(card_node.card_name)
			card_node.visible = true  # make sure it’s usable again
		graveyard.clear()
		opponent_deck.shuffle()  # optional shuffle
	
	if !opponent_deck.is_empty():
		# Get and remove the top card
		var card_name = opponent_deck.pop_front()
		$RichTextLabel.text = str(opponent_deck.size())

		var card_data = card_database.get_by_name(card_name)
		if not card_data:
			push_error("Opponent tried to draw missing card: " + card_name)
			return

		var new_card = preload(CARD_SCENE_PATH).instantiate() as Card
		new_card.setup(card_data, "Opponent")

		$"../CardManager".add_child(new_card)
		new_card.name = "Opponent_Card_" + card_name
		$"../OpponentHand".add_card_to_hand(new_card, CARD_DRAW_SPEED)
	else:
		print("opponent deck empty! nothing to draw!")
