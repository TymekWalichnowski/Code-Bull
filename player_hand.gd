extends Node2D

const CARD_WIDTH = 175
const HAND_Y_POSITION = 900
const DEFAULT_CARD_MOVE_SPEED = 0.1
const DEFAULT_CARD_SCALE = 1.2 ## make this const global later


var player_hand = []
var center_screen_x

func _ready() -> void:
	center_screen_x = get_viewport().size.x / 2

func add_card_to_hand(card, speed):
	if card not in player_hand:
		var index = get_insert_index(card)
		player_hand.insert(index, card)
		update_hand_positions(speed)
		card.scale = Vector2(1.2,1.2)
	else:
		animate_card_to_position(card, card.hand_position, speed)


func update_hand_positions(speed):
	for i in range(player_hand.size()):
		# get bew card position based on index
		var new_position = Vector2(calculate_card_position(i), HAND_Y_POSITION)
		var card = player_hand[i]
		card.hand_position = new_position
		animate_card_to_position(card, new_position, speed)

func calculate_card_position(index):
	var x_offset = (player_hand.size() -1) * CARD_WIDTH
	var x_position = center_screen_x + index * CARD_WIDTH - x_offset / 2
	return x_position
	

func animate_card_to_position(card, new_position, speed):
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", new_position, speed)

func remove_card_from_hand(card):
	if card in player_hand: # Will only remove if the card is in the player hand, this is good as I also call this when it's in the slots and not just card
		player_hand.erase(card)
		update_hand_positions(DEFAULT_CARD_MOVE_SPEED)

func get_insert_index(card): # gets position of all hand cards to know where to insert it into hand
	for i in range(player_hand.size()):
		if card.global_position.x < player_hand[i].global_position.x:
			return i
	return player_hand.size() # otherwise insert at end

func _process(delta: float) -> void:
	pass
