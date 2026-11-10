extends "res://addons/drawer_interaction/drawer.gd"
## Rueda numerada de la caja fuerte. Cada clic suma 1 (del 9 vuelve al 0).

@export var index: int = 0

var value: int = 0
@onready var _digit: Label3D = $Moving/Digito
@onready var _wheel: Node3D = $Moving/Rueda


func _ready() -> void:
	super()
	_digit.text = "0"


## Al clicar una rueda se abre el teclado de la caja (más cómodo que girarlas una a una).
func toggle() -> void:
	var safe: Node = get_parent()
	if safe and safe.get("solved"):
		return
	_sfx("tick")
	if safe and safe.has_method("open_keypad"):
		safe.call("open_keypad")


func set_value(v: int) -> void:
	value = v
	_digit.text = str(v)
	_wheel.rotation.z = -TAU / 10.0 * v
