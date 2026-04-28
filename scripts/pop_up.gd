extends CanvasLayer

@onready var panel = %Panel
@onready var label = %Label
@onready var button = %Button

var tween: Tween
var screen_size: Vector2

func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	
	# Center it vertically, push it off-screen horizontally
	panel.global_position.y = (screen_size.y / 2) - (panel.size.y / 2)
	panel.global_position.x = screen_size.x + 200 
	
	button.pressed.connect(hide_pop)

func show_pop(text: String):
	label.text = text
	
	var target_x = screen_size.x - panel.size.x - 100 # 50px gap from the right edge
	if tween: tween.kill()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(panel, "global_position:x", target_x, 0.5)

func hide_pop():
	if tween: tween.kill()
	tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tween.tween_property(panel, "global_position:x", screen_size.x + 200, 0.5)
