extends Node2D

const CARD_SCENE_PATH = "res://scenes/card.tscn"
const PASSIVE_SCENE_PATH = "res://scenes/passive_card.tscn"
const CARD_DRAW_SPEED = 0.2
const STARTING_HAND_SIZE = 6

@export var card_database: CardDatabase
@export var starting_deck: Array[CardDataResource] # Drag your opponent cards here
@export var starting_passives: Array[PassiveCardResource]

# Active deck and graveyard now store RESOURCES, not strings or nodes
var active_deck: Array[CardDataResource] = []
var graveyard: Array[CardDataResource] = []

func _ready() -> void:
	# Initialize the deck from our export
	if starting_deck.is_empty():
		push_warning("Opponent starting deck is empty!")
	
	active_deck = starting_deck.duplicate()
	active_deck.shuffle()
	
	$RichTextLabel.text = str(active_deck.size())

	for i in range(STARTING_HAND_SIZE):
		await draw_card()
	
	spawn_starting_passives()

func draw_card():
	if active_deck.is_empty() and graveyard.size() > 0:
		active_deck = graveyard.duplicate()
		graveyard.clear()
		active_deck.shuffle()
	
	if !active_deck.is_empty():
		var card_data = active_deck.pop_front()
		$RichTextLabel.text = str(active_deck.size())

		var new_card = preload(CARD_SCENE_PATH).instantiate() as Card
		new_card.setup(card_data, "Opponent")
		new_card.interactable = false 
		
		if new_card.has_node("CardImage"):
			new_card.get_node("CardImage").visible = false
		if new_card.has_node("CardBackImage"):
			new_card.get_node("CardBackImage").visible = true

		%CardManager.add_child(new_card)
		
		new_card.global_position = global_position

		new_card.name = "Opponent_Card_" + card_data.display_name
		%OpponentHand.add_card_to_hand(new_card, CARD_DRAW_SPEED)
		new_card.play_audio("pickup")
		await get_tree().create_timer(0.2).timeout


	else:
		print("opponent deck empty! nothing to draw!")

func spawn_starting_passives():
	for i in range(starting_passives.size()):
		var res = starting_passives[i]
		var passive_node = preload(PASSIVE_SCENE_PATH).instantiate() as PassiveCard

		# Changed this to %OpponentPassives (Assuming you have a separate container)
		# If you use the same one, change it back to %PlayerPassives
		if has_node("%OpponentPassives"):
			%OpponentPassives.add_child(passive_node)
		else:
			%PlayerPassives.add_child(passive_node)
		
		passive_node.setup(res)

		var offset_x = 140 + (i * 140)
		passive_node.global_position = self.global_position + Vector2(offset_x, 0)
