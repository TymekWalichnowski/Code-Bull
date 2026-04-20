extends Node

@onready var battle_manager = get_parent()

@onready var token_effect_map: Dictionary = {
	"Bleed": _effect_bleed,
	"Flame": _effect_flame,
	"Haste": _effect_haste
}

# side can be "Player", "Enemy", or "Both" (default for phase starts)
func trigger_tokens(trigger_type: String, side: String = "Both"):
	if side == "Player" or side == "Both":
		await _process_container(%PlayerTokens, "Player", trigger_type)
	
	if side == "Enemy" or side == "Both":
		await _process_container(%EnemyTokens, "Enemy", trigger_type)

func _process_container(container: TokenContainer, side: String, trigger_type: String):
	# We use a duplicate of keys because tokens might be removed during the loop
	var active_tokens = container.tokens.keys().duplicate()
	
	for t_name in active_tokens:
		var token_res = container.token_resources[t_name]
		var stacks = container.tokens[t_name]
		
		if token_res.trigger_condition == trigger_type:
			if token_effect_map.has(token_res.effect_name):
				# --- TRIGGER ANIMATION ---
				if container.token_nodes.has(t_name):
					var token_node = container.token_nodes[t_name]
					
					# Find the actual top sprite. 
					# Since we use move_child(extra, get_child_count()-1), the last child is the top.
					# We skip the Label (usually the very last child).
					var top_sprite: Sprite2D = null
					for i in range(token_node.get_child_count() - 1, -1, -1):
						var child = token_node.get_child(i)
						if child is Sprite2D:
							top_sprite = child
							break
					
					if top_sprite:
						var tween = create_tween().set_parallel(true)
						# Toss the chip up and away
						tween.tween_property(top_sprite, "position:y", top_sprite.position.y - 40, 0.2).set_ease(Tween.EASE_OUT)
						tween.tween_property(top_sprite, "position:x", top_sprite.position.x + 20, 0.2)
						tween.tween_property(top_sprite, "modulate:a", 0.0, 0.2) # Fade out
						
						await tween.finished
				
				await token_effect_map[token_res.effect_name].call(side, stacks, token_res)
				

# --- EFFECT LOGIC ---

func _effect_bleed(side: String, stacks: int, resource: TokenResource):
	var target = %Player if side == "Player" else %Enemy
	var container = %PlayerTokens if side == "Player" else %EnemyTokens
	
	print("Bleed Triggered: ", side, " taking ", stacks, " damage.")
	target.take_damage(float(stacks))
	
	# Ticks down by 1
	container.add_token(resource, -1)
	await get_tree().create_timer(0.3).timeout

func _effect_flame(side: String, stacks: int, resource: TokenResource):
	var target = %Player if side == "Player" else %Enemy
	var container = %PlayerTokens if side == "Player" else %EnemyTokens
	
	print("Burn Triggered: ", side, " taking ", stacks, " damage.")
	target.take_damage(float(stacks))
	
	# Ticks down by 1
	container.add_token(resource, -1)
	await get_tree().create_timer(0.3).timeout

func _effect_haste(side: String, stacks: int, resource: TokenResource):
	var target = %Player if side == "Player" else %Enemy
	var container = %PlayerTokens if side == "Player" else %EnemyTokens
	
	print("Haste Triggered: ", side, " earns ", stacks, " speed.")
	target.speed += stacks
	container.add_token(resource, -stacks)
	await get_tree().create_timer(0.3).timeout
	
