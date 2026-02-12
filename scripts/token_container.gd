extends Node2D
class_name TokenContainer

@export var token_scene: PackedScene = preload("res://scenes/token.tscn")

var tokens = {} # { "Bleed": 5 }
var token_resources = {} # { "Bleed": TokenResource }
var token_nodes = {} # { "Bleed": Node }

func add_token(resource: TokenResource, amount: int):
	var t_name = resource.token_name
	
	if not tokens.has(t_name):
		tokens[t_name] = 0
		token_resources[t_name] = resource
		var ui = token_scene.instantiate()
		add_child(ui)
		token_nodes[t_name] = ui
		
	tokens[t_name] += amount
	
	if tokens[t_name] <= 0:
		_remove_token(t_name)
	else:
		# Changed from update_ui to update_token to match your token script
		token_nodes[t_name].update_token(resource, tokens[t_name])

func _remove_token(t_name: String):
	tokens.erase(t_name)
	token_resources.erase(t_name)
	if token_nodes.has(t_name):
		token_nodes[t_name].queue_free()
		token_nodes.erase(t_name)

func get_token_count(t_name: String) -> int:
	return tokens.get(t_name, 0)
