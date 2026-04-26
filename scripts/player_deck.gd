extends Node2D

@export var card_database: CardDatabase 
var starting_deck = PlayerDeckGlobal.global_player_cards
var starting_passives = PlayerDeckGlobal.global_player_passives

const CARD_SCENE_PATH = "res://scenes/card.tscn"
const PASSIVE_SCENE_PATH = "res://scenes/passive_card.tscn"
const CARD_DRAW_SPEED = 0.2

var current_deck: Array[CardDataResource] = []
var graveyard: Array[CardDataResource] = []
var drawn_card_this_turn = false

# 1. Prepare data (Step 1 of setup)
func prepare_deck() -> void:
	if starting_deck.is_empty():
		push_warning("Starting deck is empty!")
	
	current_deck = starting_deck.duplicate()
	current_deck.shuffle()

	if card_database:
		card_database._initialize_database()
	
	$RichTextLabel.text = str(current_deck.size())

# 2. Draw a single card (Step 2 of setup, called by BattleManager)
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
		new_card.global_position = global_position 

		if new_card.has_node("AnimationPlayer"):
			new_card.get_node("AnimationPlayer").play("card_flip")
		
		new_card.play_audio("pickup")
		%PlayerHand.add_card_to_hand(new_card, CARD_DRAW_SPEED)
		# We don't await the timer here anymore, BattleManager handles timing
	else:
		print("Player Deck and Graveyard are empty!")

# 3. Spawn passives (Step 3 of setup)
func spawn_starting_passives():
	for i in range(starting_passives.size()):
		var res = starting_passives[i]
		var new_passive_card = preload(PASSIVE_SCENE_PATH).instantiate() as PassiveCard
		
		%PlayerPassives.add_child(new_passive_card)
		new_passive_card.setup(res)
		
		# FIX: Ensure it starts at the right scale before anything else happens
		new_passive_card.scale = Vector2(%PlayerPassives.CARD_SCALE, %PlayerPassives.CARD_SCALE)
		new_passive_card.global_position = self.global_position
		
		if new_passive_card.has_node("AnimationPlayer"):
			new_passive_card.get_node("AnimationPlayer").play("card_flip")
		
		# Give it one frame to "settle" in the scene tree
		await get_tree().process_frame
		
		if %PlayerPassives.has_method("add_to_passive_hand"):
			%PlayerPassives.add_to_passive_hand(new_passive_card)
			
		new_passive_card.play_audio("pickup")
