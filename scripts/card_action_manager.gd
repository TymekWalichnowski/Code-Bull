extends Node

func execute_action(action_data):
	print("wwww")
	var card_name = get_parent().card_name
	var card_id = get_parent().card_id
	var card_owner = get_parent().card_owner
		
		# Action 1 (Indices 1, 2, 3, 4)
	var card_action_1 = get_parent().card_action_1
	var card_action_1_value = get_parent().card_action_1_value
	var card_action_1_priority = get_parent().card_action_1_priority
	var card_action_1_tags = get_parent().card_action_1_tags
		
		# Action 2 (Indices 5, 6, 7, 8)
	var card_action_2 = get_parent().card_action_2
	var card_action_2_value = get_parent().card_action_2_value
	var card_action_2_priority = get_parent().card_action_2_priority
	var card_action_2_tags = get_parent().card_action_2_tags
		
		# Action 3 (Indices 9, 10, 11, 12)
	var card_action_3 = get_parent().card_action_3
	var card_action_3_value = get_parent().card_action_3_value
	var card_action_3_priority = get_parent().card_action_3_priority
	var card_action_3_tags = get_parent().card_action_3_tags
