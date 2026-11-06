extends Node3D
## Cajón/puerta interactuable. Solo reacciona el que estás mirando.

signal opened
signal closed

## Desplazamiento al abrir (ejes locales del nodo Drawer). Para puertas que giran, déjalo en 0.
@export var open_offset: Vector3 = Vector3(0, 0, 0.4)
## Giro al abrir en grados (para puertas con bisagra). Para cajones que se deslizan, déjalo en 0.
@export var open_rotation_degrees: Vector3 = Vector3.ZERO
@export var duration: float = 0.4
@export var interact_action: StringName = &"interact"
@export var player_group: StringName = &"player"
## Cuán centrado debe estar el pomo en pantalla para poder interactuar.
## 1.0 = exactamente en el centro. Baja el valor si te cuesta apuntar.
@export_range(0.0, 1.0) var min_look_dot: float = 0.85

var is_open: bool = false
var player_near: bool = false
var _tween: Tween

@onready var moving: Node3D = $Moving
@onready var handle: Marker3D = $Moving/Handle
@onready var prompt: Sprite3D = $Moving/Handle/Prompt
@onready var area: Area3D = $InteractArea
@onready var contents: Node3D = $Moving/Contents


func _ready() -> void:
	add_to_group("drawers")
	prompt.visible = false
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(player_group):
		player_near = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(player_group):
		player_near = false
		prompt.visible = false


func _process(_delta: float) -> void:
	prompt.visible = player_near and _is_best_target()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(interact_action) and player_near and _is_best_target():
		toggle()


# Cuánto está un punto del mundo en el centro de la cámara (1.0 = justo en el centro).
func _score_of(point: Vector3) -> float:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return -1.0
	var to_point: Vector3 = (point - cam.global_position).normalized()
	return to_point.dot(-cam.global_transform.basis.z)


func _look_score() -> float:
	return _score_of(handle.global_position)


func _is_best_target() -> bool:
	var my_score: float = _look_score()
	if my_score < min_look_dot:
		return false

	# Si el cajón está abierto y miras más a un objeto del interior que al pomo,
	# la pulsación es para coger el objeto, no para cerrar el cajón.
	if is_open:
		for item in contents.get_children():
			if item is Node3D and _score_of(item.global_position) > my_score:
				return false

	# Si hay otros cajones cerca, solo actúa el que estás mirando más.
	for other in get_tree().get_nodes_in_group("drawers"):
		if other != self and other.player_near and other._look_score() > my_score:
			return false
	return true


func toggle() -> void:
	is_open = not is_open
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var target_pos: Vector3 = open_offset if is_open else Vector3.ZERO
	var target_rot: Vector3 = open_rotation_degrees if is_open else Vector3.ZERO
	_tween.tween_property(moving, "position", target_pos, duration)
	_tween.tween_property(moving, "rotation_degrees", target_rot, duration)
	if is_open:
		opened.emit()
	else:
		closed.emit()
