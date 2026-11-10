extends Area3D
## Lugar donde hay que dejar un objeto concreto (por ejemplo, la concha en la bañera).

signal accepted

@export var accepted_item: String = ""
## Nodo que aparece al dejar el objeto (la concha colocada).
@export var placed_visual: NodePath
@export var story_event: String = ""
@export var empty_message: String = "Aquí podría ir algo."

var filled: bool = false


func _ready() -> void:
	add_to_group("receptors")
	var v := get_node_or_null(placed_visual) as Node3D
	if v:
		v.visible = false
	# Si el jugador deja el objeto en la zona (botón derecho), también cuenta.
	monitoring = true
	area_entered.connect(_on_area_entered)


func _on_area_entered(other: Area3D) -> void:
	if filled or not other.is_in_group("pickups"):
		return
	if str(other.get("item_id")) != accepted_item:
		return
	other.queue_free()
	_fill()


## Devuelve true si se ha colocado el objeto.
func try_accept(player: Node) -> bool:
	if filled:
		return false
	if str(player.call("get_selected_item_id")) != accepted_item:
		var ui: Node = get_tree().get_first_node_in_group("game_ui")
		if ui:
			ui.call("subtitle", empty_message, 2.5)
		return false
	player.call("remove_item", accepted_item)
	_fill()
	return true


func _fill() -> void:
	filled = true
	var v := get_node_or_null(placed_visual) as Node3D
	if v:
		v.visible = true
	var sfx: Node = get_tree().get_first_node_in_group("sfx")
	if sfx:
		sfx.call("play", "place", global_position)
	var story: Node = get_tree().get_first_node_in_group("story")
	if story and story_event != "":
		story.call("event", story_event)
	accepted.emit()
