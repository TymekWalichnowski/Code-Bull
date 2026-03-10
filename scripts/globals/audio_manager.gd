extends Node

@onready var sfx_library = {
	"Attack": preload("res://Assets/audio/sfx/sfx_sword_attack.mp3"),
	"Shield": preload("res://Assets/audio/sfx/sfx_shield.mp3"),
	"Magic": preload("res://Assets/audio/sfx/sfx_magic.mp3"),
	"Impact": preload("res://Assets/audio/sfx/sfx_impact.mp3"),
	"Shatter": preload("res://Assets/audio/sfx/sfx_shatter.wav"),
	"Shield Summon": preload("res://Assets/audio/sfx/sfx_shield_summon.wav")
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
