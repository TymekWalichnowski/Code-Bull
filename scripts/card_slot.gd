extends Node2D

@export_enum("Player", "Opponent") var slot_owner: String = "Player"

var card_in_slot = false
var card: Node2D = null
var bonus_retriggers: int = 0

func _ready() -> void:
	if has_node("%Glow"):
		%Glow.visible = false

# Safely attaches a card to this slot and applies buffs
func set_card(new_card: Node2D):
	if card: 
		remove_card() # Clear existing if swapping
	
	card = new_card
	card_in_slot = true
	card.cards_current_slot = self
	card.position = global_position
	
	# Apply slot buffs to the card
	card.retriggers += bonus_retriggers
	card.update_visuals()
	visible = false

# Safely removes the card and strips slot buffs
func remove_card():
	if not card: 
		return
	
	# Remove slot buffs before the card leaves
	card.retriggers -= bonus_retriggers
	card.update_visuals()
	
	card.cards_current_slot = null
	card = null
	card_in_slot = false
	visible = true

# Called by passives or other cards to buff this specific slot
func add_retrigger_buff(amount: int):
	bonus_retriggers += amount
	
	if has_node("%Glow"):
		%Glow.visible = (bonus_retriggers > 0)
		
	# If a card is already sitting here, update it immediately
	if card:
		card.retriggers += amount
		card.update_visuals()

# Called at the end of the turn/phase
func clear_buffs():
	bonus_retriggers = 0
	if has_node("%Glow"):
		%Glow.visible = false
	
	if card:
		card.update_visuals()
