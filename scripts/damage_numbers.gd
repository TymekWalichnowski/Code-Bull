# DamagePopup.gd
extends Label

func setup(amount: float, is_shield: bool = false):
	# Snapping to 1 decimal place so it's clean
	text = str(snapped(amount, 0.1))
	
	# Color: Red for health, Cyan for shield
	modulate = Color.CYAN if is_shield else Color.RED
	
	# The Animation
	var tween = create_tween().set_parallel(true)
	
	# Float upwards and fade out
	# Using TRANS_QUART for a smooth deceleration and EASE_OUT to make it slow down at the top
	tween.tween_property(self, "position:y", position.y - 80, 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	
	# Slight "bounce" scale effect
	scale = Vector2(0.5, 0.5)
	var scale_tween = create_tween() # Separate tween so it's not parallel to the fade
	scale_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Cleanup when done
	await tween.finished
	queue_free()
