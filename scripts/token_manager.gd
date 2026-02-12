extends Node

@onready var battle_manager = get_parent()

@onready var token_effect_map: Dictionary = {
	"Bleed": _effect_bleed,
	"Flame": _effect_flame
}

# side can be "Player", "Opponent", or "Both" (default for phase starts)
func trigger_tokens(trigger_type: String, side: String = "Both"):
	if side == "Player" or side == "Both":
		await _process_container(%PlayerTokens, "Player", trigger_type)
	
	if side == "Opponent" or side == "Both":
		await _process_container(%OpponentTokens, "Opponent", trigger_type)

func _process_container(container: TokenContainer, side: String, trigger_type: String):
	# We use a duplicate of keys because tokens might be removed during the loop
	var active_tokens = container.tokens.keys().duplicate()
	
	for t_name in active_tokens:
		var token_res = container.token_resources[t_name]
		var stacks = container.tokens[t_name]
		
		if token_res.trigger_condition == trigger_type:
			if token_effect_map.has(token_res.effect_name):
				# Visual feedback similar to Passive trigger
				# If your TokenUI has an AnimationPlayer, play it here
				if container.token_nodes.has(t_name):
					pass
					#container.token_nodes[t_name].play_trigger_anim() no anim atm
				
				await token_effect_map[token_res.effect_name].call(side, stacks, token_res)

# --- EFFECT LOGIC ---

func _effect_bleed(side: String, stacks: int, resource: TokenResource):
	var target = %Player if side == "Player" else %Opponent
	var container = %PlayerTokens if side == "Player" else %OpponentTokens
	
	print("Bleed Triggered: ", side, " taking ", stacks, " damage.")
	target.take_damage(float(stacks))
	
	# Ticks down by 1
	container.add_token(resource, -1)
	await get_tree().create_timer(0.3).timeout

func _effect_flame(side: String, stacks: int, resource: TokenResource):
	print("flame effect!!!")
