extends "res://addons/drawer_interaction/drawer.gd"
## Mando de la tele: cada clic cambia de canal y muestra una pista más concreta.


func toggle() -> void:
	var story: Node = get_tree().get_first_node_in_group("story")
	if story:
		story.call("next_hint")
	_sfx("click")
