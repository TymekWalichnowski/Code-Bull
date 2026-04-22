extends "res://scripts/status.gd"

func take_damage(damage_amount):
	var initial_shield = current_shield
	var was_shielded = initial_shield > 0
	
	if current_shield > 0:
		if damage_amount >= current_shield: # damage overflow from shield to health
			var remaining_damage = damage_amount - current_shield
			current_shield = 0
			current_health -= remaining_damage
			%AudioManager.play_sfx("Shatter")
		else:
			current_shield -= damage_amount
	else:
		current_health -= damage_amount
	
	damage_taken.emit(damage_amount, was_shielded)
	
	if was_shielded:
		%AudioManager.play_sfx("Shield")
	else:
		%AudioManager.play_sfx("Impact")
	# Only play the effect if a sprite is assigned (The Opponent)
	if entity_sprite:
		play_hit_effect()
