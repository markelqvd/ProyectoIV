class_name SafeWheel
extends Openable

@export var safe: NodePath

@onready var _digit: Label3D = $Moving/Digito
@onready var _disc: Node3D = $Moving/Rueda


func _ready() -> void:
	super()
	set_value(0)


func toggle() -> void:
	_play("tick")
	get_node(safe).call("open_keypad")


func set_value(value: int) -> void:
	_digit.text = str(value)
	_disc.rotation.z = -TAU / 10.0 * value
