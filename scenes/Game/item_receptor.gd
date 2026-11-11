extends Area3D

signal accepted

@export var accepted_item: String = ""
@export var placed_position: Vector3 = Vector3.ZERO
@export var placed_rotation_degrees: Vector3 = Vector3.ZERO
@export var story_event: String = ""
@export var empty_message_id: String = ""

var filled: bool = false


func _ready() -> void:
	add_to_group("receptors")
	area_entered.connect(_on_area_entered)


func try_accept(player: Player) -> void:
	if filled:
		return
	if player.get_selected_item_id() != accepted_item:
		UI.subtitle(Texts.SUBTITLES.get(empty_message_id, ""), 2.5)
		return
	player.remove_item(accepted_item)
	_fill()


func _on_area_entered(other: Area3D) -> void:
	if filled or not (other is Pickup) or (other as Pickup).item_id != accepted_item:
		return
	other.queue_free()
	_fill()


func _fill() -> void:
	filled = true
	var item: ItemData = Items.find(accepted_item)
	var mesh := MeshInstance3D.new()
	mesh.mesh = item.build_mesh(item.world_scale)
	mesh.material_override = item.make_material()
	mesh.position = placed_position
	mesh.rotation_degrees = placed_rotation_degrees
	add_child(mesh)
	Sfx.play("place", global_position)
	Game.event(story_event)
	accepted.emit()
