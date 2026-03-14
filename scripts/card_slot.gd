extends Node2D

@export_enum("Player", "Opponent") var slot_owner: String = "Player"

var card_in_slot = false
var card: Node2D = null
var bonus_retriggers: int = 0

func _ready() -> void:
	if has_node("%Glow"):
		%Glow.visible = false

# Called by passives or other cards to buff this specific slot
func add_retrigger_buff(amount: int):
	bonus_retriggers += amount
	
	if has_node("%Glow"):
		%Glow.visible = (bonus_retriggers > 0)
		
	# If a card is already sitting here, update it immediately
	if card:
		card.retriggers += amount
		card.update_retrigger_visuals()

# Called at the end of the turn/phase
func clear_buffs():
	bonus_retriggers = 0
	if has_node("%Glow"):
		%Glow.visible = false
	if card:
		card.retriggers = 0
		card.update_retrigger_visuals()
