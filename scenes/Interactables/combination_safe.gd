extends Node3D

@export var combination: String = "472"
@export var door: NodePath
@export var wheels: Array[NodePath] = []
@export var reveal: Array[NodePath] = []

var solved: bool = false

@onready var _door: Openable = get_node(door)


func open_keypad() -> void:
	if not solved:
		UI.show_keypad(Texts.SAFE_TITLE, combination.length(), _try_code)


func _try_code(code: String) -> bool:
	if solved:
		return true
	if code != combination:
		Sfx.play("rattle", global_position)
		return false
	for i in mini(wheels.size(), combination.length()):
		(get_node(wheels[i]) as SafeWheel).set_value(int(combination[i]))
	_solve()
	return true


func _solve() -> void:
	solved = true
	Sfx.play("clack", global_position)
	await get_tree().create_timer(0.35).timeout
	Sfx.play("success")
	_door.locked = false
	_door.toggle()
	for path in reveal:
		(get_node(path) as Node3D).visible = true
	Game.event("safe_open")
