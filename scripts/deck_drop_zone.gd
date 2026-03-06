extends Node

signal card_dropped

func _can_drop_data(_at_position, data):
	# Only accept if the data is our card dictionary
	return data is Dictionary and data.has("card_data")

func _drop_data(_at_position, data):
	var card = data["card_data"]
	var from_zone = data["source"]
	var to_zone = "Deck" if name == "DeckGrid" else "Inventory"

	# If moving from Inventory to Deck
	if from_zone == "Inventory" and to_zone == "Deck":
		PlayerDeckGlobal.global_player_inventory.erase(card)
		PlayerDeckGlobal.global_player_cards.append(card)
	
	# If moving from Deck back to Inventory
	elif from_zone == "Deck" and to_zone == "Inventory":
		PlayerDeckGlobal.global_player_cards.erase(card)
		PlayerDeckGlobal.global_player_inventory.append(card)

	card_dropped.emit()
