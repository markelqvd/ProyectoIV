extends Node3D

@export var lamp: NodePath
@export var energy_lit_room: float = 0.8
@export var energy_dark_room: float = 3.5

var _lamp: Light3D
var _material: StandardMaterial3D


func _ready() -> void:
	_lamp = get_node_or_null(lamp) as Light3D
	var glow: Node3D = $Brillo
	glow.visible = true
	for child in glow.get_children():
		var mesh := child as MeshInstance3D
		if mesh and mesh.material_override is StandardMaterial3D:
			_material = mesh.material_override
			break


func _process(_delta: float) -> void:
	if _material:
		var dark: bool = _lamp == null or not _lamp.visible
		_material.emission_energy_multiplier = energy_dark_room if dark else energy_lit_room
