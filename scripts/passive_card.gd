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
	# Use a small call_deferred to ensure the deck has finished 
	# setting variables before we update the text
	update_labels.call_deferred()

func play_trigger_anim(): #this code isnt getting activated, I believe. It's handled in the battlemanager currently
	if $AnimationPlayer.has_animation("passive_trigger"):
		$AnimationPlayer.play("passive_trigger")

func update_labels():
	if has_node("Label"):
		$Label.text = card_name
	# Maybe add a sub-label for the value?
	if has_node("ValueLabel"):
		$ValueLabel.text = str(value)
