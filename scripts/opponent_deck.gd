extends Node2D

const CARD_SCENE_PATH = "res://scenes/opponent_card.tscn"
const PASSIVE_SCENE_PATH = "res://scenes/passive_card.tscn"
const CARD_DRAW_SPEED = 0.2
const STARTING_HAND_SIZE = 4

@export var card_database: CardDatabase2
@export var starting_passives: Array[PassiveCardResource]

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
	
	# Trigger passive spawning for the opponent
	spawn_starting_passives()

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

func spawn_starting_passives():
	for i in range(starting_passives.size()):
		var res = starting_passives[i]
		var passive_node = preload(PASSIVE_SCENE_PATH).instantiate() as PassiveCard

		%PlayerPassives.add_child(passive_node)
		
		# Pass the whole resource to the card
		passive_node.setup(res)

		# Position logic remains the same
		var offset_x = 140 + (i * 140)
		passive_node.global_position = self.global_position + Vector2(offset_x, 0)
