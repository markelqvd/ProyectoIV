extends "res://addons/drawer_interaction/drawer.gd"
## Interruptor de luz. Usa el mismo sistema de interacción que los cajones:
## "abierto" significa encendido. Sirve para interruptores de pared, lámparas, la tele...

## Estado al empezar la partida.
@export var start_on: bool = false
## Luces que se encienden y apagan (se muestran u ocultan).
@export var lights: Array[NodePath] = []
## Mallas a las que se les cambia el material (bombilla encendida / apagada).
@export var lamp_meshes: Array[NodePath] = []
@export var on_material: Material
@export var off_material: Material
## Giro de la tecla del interruptor al encenderlo (solo gira la tecla, el indicador queda fijo).
@export var key_tilt_degrees: float = 14.0

var _tecla: Node3D


func _ready() -> void:
	super()
	# El nodo Moving lleva el indicador: no debe moverse. Solo gira la tecla.
	open_offset = Vector3.ZERO
	open_rotation_degrees = Vector3.ZERO
	moving.position = Vector3.ZERO
	moving.rotation_degrees = Vector3.ZERO
	_tecla = moving.get_node_or_null("Tecla") as Node3D
	opened.connect(_apply.bind(true))
	closed.connect(_apply.bind(false))
	if start_on:
		is_open = true
	_apply.call_deferred(is_open)


func _apply(on: bool) -> void:
	if _tecla:
		_tecla.rotation_degrees.x = -key_tilt_degrees if on else key_tilt_degrees
	for p in lights:
		var light := get_node_or_null(p) as Node3D
		if light:
			light.visible = on
	for p in lamp_meshes:
		var mesh := get_node_or_null(p) as GeometryInstance3D
		if mesh:
			mesh.visible = true
			mesh.material_override = on_material if on else off_material
