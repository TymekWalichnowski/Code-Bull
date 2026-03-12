extends Node2D

@export var card_database: CardDatabase # Keep if other systems need it
#@export var starting_deck: Array[CardDataResource]
#@export var starting_passives: Array[PassiveCardResource]

var starting_deck = PlayerDeckGlobal.global_player_cards
var starting_passives = PlayerDeckGlobal.global_player_passives

const CARD_SCENE_PATH = "res://scenes/card.tscn"
const PASSIVE_SCENE_PATH = "res://scenes/passive_card.tscn"
const CARD_DRAW_SPEED = 0.2
const STARTING_HAND_SIZE = 5

# This now stores the actual Resources, not strings
var current_deck: Array[CardDataResource] = []
var graveyard: Array[CardDataResource] = []
var drawn_card_this_turn = false

func _ready() -> void:
	# 1. Initialize the deck from the export
	if starting_deck.is_empty():
		push_warning("Starting deck is empty! Add cards in the Inspector.")
	
	# Duplicate the resources into our active deck so we don't modify the originals
	current_deck = starting_deck.duplicate()
	current_deck.shuffle()

	if card_database:
		card_database._initialize_database()
	
	$RichTextLabel.text = str(current_deck.size())
	
	for i in range(STARTING_HAND_SIZE):
		await draw_card()
		drawn_card_this_turn = false
	
	drawn_card_this_turn = true
	spawn_starting_passives()

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
		
		# --- ADD THIS LINE ---
		# This sets the card's starting point to this deck's location
		new_card.global_position = global_position 

		if new_card.has_node("AnimationPlayer"):
			new_card.get_node("AnimationPlayer").play("card_flip")
		
		new_card.play_audio("pickup")
		%PlayerHand.add_card_to_hand(new_card, CARD_DRAW_SPEED)
		await get_tree().create_timer(0.5).timeout
	else:
		print("Deck and Graveyard are empty!")

func spawn_starting_passives():
	for i in range(starting_passives.size()):
		var res = starting_passives[i]
		var passive_node = preload(PASSIVE_SCENE_PATH).instantiate() as PassiveCard
		%PlayerPassives.add_child(passive_node)
		passive_node.setup(res)
		var offset_x = 140 + (i * 140)
		passive_node.global_position = self.global_position + Vector2(offset_x, 0)
