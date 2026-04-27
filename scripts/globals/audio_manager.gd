extends Node

# we keep card sounds located in the card scene so they work in scenes without an audio manager
@onready var sfx_library = {
	"Attack": preload("res://assets/audio/sfx/sfx_sword_attack.mp3"),
	"Shield": preload("res://assets/audio/sfx/sfx_shield.mp3"),
	"Magic": preload("res://assets/audio/sfx/sfx_magic.mp3"),
	"Impact": preload("res://assets/audio/sfx/sfx_impact.mp3"),
	"Shatter": preload("res://assets/audio/sfx/sfx_shatter.wav"),
	"Shield Summon": preload("res://assets/audio/sfx/sfx_shield_summon.wav"),
	"Burn_Card": preload("res://assets/audio/sfx/sfx_fire.mp3")
}

func play_sfx(sfx_name: String):
	if sfx_library.has(sfx_name):
		var asp = AudioStreamPlayer.new()
		add_child(asp)
		asp.stream = sfx_library[sfx_name]
		asp.play()
		asp.finished.connect(asp.queue_free) # clean up when done
	else:
		print("Warning: Sound ", sfx_name, " not found in library.")
