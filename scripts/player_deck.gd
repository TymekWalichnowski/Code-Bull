extends Node2D

@export var card_database: CardDatabase2

const CARD_SCENE_PATH = "res://scenes/player_card.tscn"
const PASSIVE_SCENE_PATH = "res://scenes/passive_card.tscn"
const CARD_DRAW_SPEED = 0.2
const STARTING_HAND_SIZE = 5

var player_deck = [
	"Double Hit",
	"2 Of Spades",
	"Fifty Fifty",
	"Nullify",
	"Divide",
	"Draw 2",
	"Sword",
	"Sword"]

var drawn_card_this_turn = false
var graveyard = []

func _ready() -> void:
	if card_database:
		card_database._initialize_database()  # <-- safe call
	else:
		push_warning("No card database assigned!")
	
	print("im ready")
	$RichTextLabel.text = str(player_deck.size())
	for i in range(STARTING_HAND_SIZE):
		draw_card()
		drawn_card_this_turn = false
	drawn_card_this_turn = true
	spawn_starting_passives()

func draw_card():
	print("player draw_card starting")
	if player_deck.is_empty() and graveyard.size() > 0:
		# Refill deck from graveyard
		print("refilling from graveyard")
		for card_node in graveyard:
			player_deck.append(card_node.card_name)
			card_node.visible = true  # make sure it’s usable again
		graveyard.clear()
		player_deck.shuffle()  # optional shuffle
		$Area2D/CollisionShape2D.disabled = true
	
	if !player_deck.is_empty():
		print("gonna do card stuff now")
		var card_name = player_deck.pop_front()
		$RichTextLabel.text = str(player_deck.size())
		print("Trying to get card:", card_name)
		var card_data = card_database.get_by_name(card_name)
		if not card_data:
			print("uhh error happened")
			push_error("Missing card data: " + card_name)
			return

		var new_card = preload(CARD_SCENE_PATH).instantiate() as Card
		new_card.setup(card_data, "Player")
	
		print("setup da card loool")
		%CardManager.add_child(new_card)
		print("%CardManager:", %CardManager)
		print("%PlayerHand:", %PlayerHand)
		print("hello")
		new_card.name = "Card_" + card_name

		if new_card.has_node("AnimationPlayer"):
			new_card.get_node("AnimationPlayer").play("card_flip")
			
		%PlayerHand.add_card_to_hand(new_card, CARD_DRAW_SPEED)
		print("Drawing card: ", card_name, " | Card data: ", card_data)
	else:
		print("player deck empty! nothing to draw!")

func reset_draw():
	drawn_card_this_turn = false
	
func spawn_starting_passives():
	# 1. Define our two example cards
	var starting_passives = [
		{
			"name": "Retrigger Slot 2",
			"image": "res://Assets/textures/cards_passive/passive_Retrigger_Slot_2.png",
			"effect": "Retrigger_Slot",
			"condition": "On_Slot_Start",
			"val": 1.0,
			"slot": 2
		},
		{
			"name": "Early Guard",
			"image": "res://Assets/textures/cards_passive/passive_Initial_Shield.png",
			"effect": "Add_Shield_Start",
			"condition": "On_Phase_Start",
			"val": 5.0,
			"slot": -1 #-1 doesnt tie it to any slot
		}
	]

	# 2. Spawn them
	for i in range(starting_passives.size()):
		var data = starting_passives[i]
		var p_card = preload(PASSIVE_SCENE_PATH).instantiate() as PassiveCard

		# Add to the container so BattleManager sees it
		%PlayerPassives.add_child(p_card)
		
		#image logic
		if p_card.has_node("CardImage"):
			var tex = load(data.image)
			if tex:
				p_card.get_node("CardImage").texture = tex
			else:
				print("Could not find image at: " + data.image)
		
		# Set the logic data
		p_card.card_name = data.name
		p_card.passive_effect_name = data.effect
		p_card.trigger_condition = data.condition
		p_card.value = data.val
		p_card.target_slot = data.slot

		# Position it: "Slightly off to the right of the deck"
		# We use global_position to match the Deck's world spot, 
		# then offset it by X (width) and Y (slight stagger)
		var offset_x = 140 + (i * 140) # Adjust distance from deck
		var offset_y = 0
		p_card.global_position = self.global_position + Vector2(offset_x, offset_y)
