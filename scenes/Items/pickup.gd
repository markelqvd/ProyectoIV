class_name Pickup
extends Area3D

@export var item_id: String = ""

var item: ItemData
var _material: StandardMaterial3D
var _time: float = 0.0


func _ready() -> void:
	add_to_group("pickups")
	item = Items.find(item_id)
	if item == null:
		push_error("Pickup: no existe el objeto '%s'." % item_id)
		return

	var mesh := MeshInstance3D.new()
	mesh.mesh = item.build_mesh(item.world_scale)
	mesh.rotation_degrees = item.world_rotation_degrees
	_material = item.make_material(true)
	mesh.material_override = _material
	add_child(mesh)

	var bounds: AABB = mesh.transform * mesh.mesh.get_aabb()
	var shape := BoxShape3D.new()
	shape.size = bounds.size + Vector3(0.04, 0.04, 0.04)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = bounds.get_center()
	add_child(collision)

	if item.glow > 0.0:
		var light := OmniLight3D.new()
		light.light_color = item.color.lightened(0.4)
		light.light_energy = 0.6
		light.omni_range = 0.6
		light.position = bounds.get_center() + Vector3(0.0, 0.12, 0.05)
		add_child(light)
	else:
		set_process(false)


func _process(delta: float) -> void:
	_time += delta
	_material.emission_energy_multiplier = item.glow * (0.6 + 0.4 * sin(_time * 3.0))
