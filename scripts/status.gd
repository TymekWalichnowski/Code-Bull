extends Node2D

signal damage_taken(amount, is_shield)

var current_health = 1.0
var current_shield = 0.0
var nullified = false
var max_health = 10
var max_shield = 10
var speed = 5.0

@onready var healthbar = $HealthBar
@onready var shieldbar = $ShieldBar

@export var entity_sprite: Node2D #make a scene later? might have to consider how it works with animation manager
var original_scale: Vector2

func _ready() -> void:
	healthbar.max_value = max_health
	shieldbar.max_value = max_shield
	if entity_sprite:
		original_scale = entity_sprite.scale

func _process(delta: float) -> void:
	healthbar.value = current_health
	shieldbar.value = current_shield
	
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


func gain_shield(shield_amount):
	current_shield += shield_amount

func play_hit_effect():
	# 1. FLASH RED (Parallel)
	var flash_tween = create_tween()
	entity_sprite.modulate = Color(2, 0.5, 0.5, 1) # Overbright red for a "punchier" look
	flash_tween.tween_property(entity_sprite, "modulate", Color.WHITE, 0.2).set_trans(Tween.TRANS_SINE)
	
	# 2. SQUASH AND STRETCH (Sequence)
	var bounce_tween = create_tween()
	# Squash down slightly
	bounce_tween.tween_property(entity_sprite, "scale", Vector2(original_scale.x * 1.2, original_scale.y * 0.8), 0.05) 
	# Snap back with an elastic bounce
	bounce_tween.tween_property(entity_sprite, "scale", original_scale, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
