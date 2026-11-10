extends Node3D
## Caja fuerte de combinación. Las ruedas (safe_wheel.gd) son hijas de este nodo.

@export var combination: String = "472"
## Puerta de la caja (usa drawer.gd con locked = true).
@export var door: NodePath
## Nodos que aparecen al abrirla (por ejemplo, la llave de dentro).
@export var reveal: Array[NodePath] = []

var digits: Array[int] = [0, 0, 0]
var solved: bool = false


## Abre el panel con el teclado numérico.
func open_keypad() -> void:
	if solved:
		return
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui:
		ui.call("show_keypad", "Caja fuerte", combination.length(), _try_code)


## Lo llama el teclado. Devuelve true si la combinación es correcta.
func _try_code(code: String) -> bool:
	if solved:
		return true
	if code != combination:
		var sfx: Node = get_tree().get_first_node_in_group("sfx")
		if sfx:
			sfx.call("play", "rattle", global_position)
		return false
	# Mostrar la combinación en las ruedas y abrir.
	for i in combination.length():
		var w: Node = get_node_or_null("Rueda%d" % (i + 1))
		if w and w.has_method("set_value"):
			w.call("set_value", int(combination[i]))
	_solve()
	return true


func wheel_changed(index: int, value: int) -> void:
	if solved:
		return
	if index >= 0 and index < digits.size():
		digits[index] = value
	var code: String = ""
	for d in digits:
		code += str(d)
	if code == combination:
		_solve()


func _solve() -> void:
	solved = true
	var sfx: Node = get_tree().get_first_node_in_group("sfx")
	if sfx:
		sfx.call("play", "clack", global_position)
	await get_tree().create_timer(0.35).timeout
	if sfx:
		sfx.call("play", "success")
	var d: Node = get_node_or_null(door)
	if d:
		d.set("locked", false)
		d.call("toggle")
	for p in reveal:
		var n := get_node_or_null(p) as Node3D
		if n:
			n.visible = true
	var story: Node = get_tree().get_first_node_in_group("story")
	if story:
		story.call("event", "safe_open")
