extends Node2D

var current_health = 1.0
var current_shield = 0.0
var nullified = false
var current_mult = 1.0 
var next_mult = 1.0
var max_health = 10
var max_shield = 10

@onready var healthbar = $HealthBar
@onready var shieldbar = $ShieldBar

func _ready() -> void:
	healthbar.max_value = max_health
	shieldbar.max_value = max_shield

func _process(delta: float) -> void:
	healthbar.value = current_health
	shieldbar.value = current_shield
	
func take_damage(damage_amount):
	if current_shield > 0:
		if damage_amount > current_shield: # damage overflow from shield to health
			var remaining_damage = damage_amount - current_shield
			current_shield = 0
			current_health -= remaining_damage
		else:
			current_shield -= damage_amount
	else:
		current_health -= damage_amount
	

func gain_shield(shield_amount):
	current_shield += shield_amount
