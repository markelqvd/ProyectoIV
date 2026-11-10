extends Node3D
## Cuadro con ventanas encendidas. Siempre se ven; con la luz del pasillo apagada brillan mucho más
## (pintura fosforescente), lo que ayuda a contarlas.

## Luz del pasillo.
@export var lamp_light: NodePath
## Brillo de las ventanas con la luz encendida y apagada.
@export var energy_lit_room: float = 0.8
@export var energy_dark_room: float = 3.5

@onready var _glow: Node3D = $Brillo
var _material: StandardMaterial3D


func _ready() -> void:
	_glow.visible = true
	for child in _glow.get_children():
		var mesh := child as MeshInstance3D
		if mesh and mesh.material_override is StandardMaterial3D:
			_material = mesh.material_override as StandardMaterial3D
			break


func _process(_delta: float) -> void:
	if _material == null:
		return
	var lamp := get_node_or_null(lamp_light) as Node3D
	var dark: bool = lamp == null or not lamp.visible
	_material.emission_energy_multiplier = energy_dark_room if dark else energy_lit_room
