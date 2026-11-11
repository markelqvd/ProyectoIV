extends Openable

@export var start_on: bool = false
@export var lights: Array[NodePath] = []
@export var lamp_meshes: Array[NodePath] = []
@export var on_material: Material
@export var off_material: Material
@export var key_tilt_degrees: float = 14.0

var _key: Node3D


func _ready() -> void:
	super()
	open_offset = Vector3.ZERO
	open_rotation_degrees = Vector3.ZERO
	_key = moving.get_node_or_null("Tecla") as Node3D
	opened.connect(_apply.bind(true))
	closed.connect(_apply.bind(false))
	is_open = start_on
	_apply.call_deferred(is_open)


func _apply(on: bool) -> void:
	if _key:
		_key.rotation_degrees.x = -key_tilt_degrees if on else key_tilt_degrees
	for path in lights:
		(get_node(path) as Light3D).visible = on
	for path in lamp_meshes:
		(get_node(path) as GeometryInstance3D).material_override = on_material if on else off_material
