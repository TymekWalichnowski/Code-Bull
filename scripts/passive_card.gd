extends Node2D
class_name PassiveCard

@export_group("Logic")
@export_enum("On_Phase_Start", "On_Slot_Start", "On_Damage_Taken") var trigger_condition: String = "On_Phase_Start"
@export var passive_effect_name: String = "Retrigger_Slot"
@export var value: float = 1.0
@export var target_slot: int = -1

@export_group("Visuals")
@export var card_name: String = "Passive"

func _ready():
	# Update the label text when the card enters the scene
	if has_node("Label"):
		$Label.text = card_name

func play_trigger_anim():
	if $AnimationPlayer.has_animation("passive_trigger"):
		$AnimationPlayer.play("passive_trigger")
		await $AnimationPlayer.animation_finished
