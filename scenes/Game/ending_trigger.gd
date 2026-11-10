extends Area3D
## Al entrar el jugador, termina la demo.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var story: Node = get_tree().get_first_node_in_group("story")
		if story:
			story.call("finish")
