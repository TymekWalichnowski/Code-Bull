extends Node2D

const CARD_SCENE_PATH = "res://scenes/card.tscn"
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

	
	var card_drawn_name = player_deck[0] # add error proofing here later for when draw cards but dont have enough in graveyard
	player_deck.erase(card_drawn_name)
	print("draw player card")
	$RichTextLabel.text = str(player_deck.size())

	var card_data = card_database_reference.CARDS[card_drawn_name]
	var card_id = card_data[0]

	# Instantiate the card scene
	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate()

	# Assign properties directly
	new_card.card_id = card_id        # For battle logic
	new_card.card_name = card_drawn_name  # Optional, human-readable

	# Cache nodes
	var card_image = new_card.get_node("CardImage")
	var card_label = new_card.get_node("CardLabel")
	var anim_player = new_card.get_node("AnimationPlayer")

	# Set up visuals
	card_image.texture = load("res://Assets/Textures/Cards/card_" + card_drawn_name + ".png")
	card_label.text = str(card_id)

	# Play flip animation
	if anim_player:
		anim_player.play("card_flip")

	# Add to scene tree and hand
	$"../CardManager".add_child(new_card)
	new_card.name = "Card"
	$"../PlayerHand".add_card_to_hand(new_card, CARD_DRAW_SPEED)

func reset_draw():
	drawn_card_this_turn = false
