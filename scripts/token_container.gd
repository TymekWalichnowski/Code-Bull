# TokenContainer.gd
extends Node2D
class_name TokenContainer

@export var token_scene: PackedScene = preload("res://scenes/token.tscn")
@export var horizontal_spacing: float = 100.0 # How far apart to space token types

var tokens = {} 
var token_resources = {} 
var token_nodes = {} 

func add_token(resource: TokenResource, amount: int):
	var t_name = resource.token_name
	
	if not tokens.has(t_name):
		tokens[t_name] = 0
		token_resources[t_name] = resource
		var ui = token_scene.instantiate()
		add_child(ui)
		token_nodes[t_name] = ui
		
		# Position the new token type horizontally
		_realign_tokens()
		
	tokens[t_name] += amount
	
	if tokens[t_name] <= 0:
		_remove_token(t_name)
	else:
		token_nodes[t_name].update_token(resource, tokens[t_name])

func _remove_token(t_name: String):
	tokens.erase(t_name)
	token_resources.erase(t_name)
	if token_nodes.has(t_name):
		token_nodes[t_name].queue_free()
		token_nodes.erase(t_name)
		# Wait a frame for queue_free to finish, then realign
		await get_tree().process_frame
		_realign_tokens()

func _realign_tokens():
	var i = 0
	for t_name in token_nodes:
		var node = token_nodes[t_name]
		# Smoothly slide tokens into their new horizontal positions
		var tween = create_tween()
		tween.tween_property(node, "position:x", i * horizontal_spacing, 0.25)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1

func get_token_count(t_name: String) -> int:
	return tokens.get(t_name, 0)
