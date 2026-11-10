extends Node3D
## Cajón/puerta interactuable. Solo reacciona el que estás mirando.

signal opened
signal closed

## Desplazamiento al abrir (ejes locales del nodo Drawer). Para puertas que giran, déjalo en 0.
@export var open_offset: Vector3 = Vector3(0, 0, 0.4)
## Giro al abrir en grados (para puertas con bisagra). Para cajones que se deslizan, déjalo en 0.
@export var open_rotation_degrees: Vector3 = Vector3.ZERO
## Escala al abrir (por ejemplo, una cortina que se recoge). Déjalo en (1, 1, 1) si no se usa.
@export var open_scale: Vector3 = Vector3.ONE
@export var duration: float = 0.4
@export var interact_action: StringName = &"interact"
@export var player_group: StringName = &"player"
## Si no está vacío, el cajón está cerrado con llave: solo se abre si el jugador
## tiene en la mano el objeto con este id (por ejemplo "key"). Después queda abierto.
@export var required_item: String = ""
## Si está activo, el objeto (la llave) desaparece del inventario al abrir la cerradura.
@export var consume_item: bool = true
## Cerrado por un mecanismo (por ejemplo, la puerta de la caja fuerte). Lo abre otro script.
@export var locked: bool = false
## Si está cerrado (locked) y esto apunta a un nodo con open_keypad(), al interactuar se abre el teclado.
@export var keypad_target: NodePath
## Sonido al abrir/cerrar: "auto" lo elige según el tipo (puerta, cajón, interruptor, cortina) o "none".
@export var sound_style: String = "auto"
## Mensaje que aparece al intentar abrirlo sin la llave.
@export var locked_message: String = "Está cerrado con llave"
## Cuán centrado debe estar el pomo en pantalla para poder interactuar.
## 1.0 = exactamente en el centro. Baja el valor si te cuesta apuntar.
@export_range(0.0, 1.0) var min_look_dot: float = 0.85

var is_open: bool = false
var player_near: bool = false
var unlocked: bool = false
var _tween: Tween
var _label: Label3D

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
		if _ui_busy():
			return
		if not is_open and locked:
			var kp: Node = get_node_or_null(keypad_target) if not keypad_target.is_empty() else null
			if kp and kp.has_method("open_keypad"):
				kp.call("open_keypad")
				return
			_rattle()
			_show_message(locked_message)
			return
		if not is_open and required_item != "" and not unlocked:
			if _player_holds(required_item):
				unlocked = true
				_show_message("Abierto")
				_sfx("clack")
				if consume_item:
					var player: Node = get_tree().get_first_node_in_group(player_group)
					if player and player.has_method("remove_item"):
						player.call("remove_item", required_item)
			else:
				_rattle()
				_show_message(locked_message)
				return
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
	_play_toggle_sound()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var target_pos: Vector3 = open_offset if is_open else Vector3.ZERO
	var target_rot: Vector3 = open_rotation_degrees if is_open else Vector3.ZERO
	_tween.tween_property(moving, "position", target_pos, duration)
	_tween.tween_property(moving, "rotation_degrees", target_rot, duration)
	if open_scale != Vector3.ONE:
		var target_scale: Vector3 = open_scale if is_open else Vector3.ONE
		_tween.tween_property(moving, "scale", target_scale, duration)
	if is_open:
		opened.emit()
	else:
		closed.emit()


# ---------------------------------------------------------------------------
# Cerradura
# ---------------------------------------------------------------------------

func _player_holds(item_id: String) -> bool:
	var player: Node = get_tree().get_first_node_in_group(player_group)
	if player == null or not player.has_method("get_selected_item_id"):
		return false
	return str(player.call("get_selected_item_id")) == item_id


## Pequeño traqueteo: el cajón intenta abrirse pero la cerradura lo frena.
func _rattle() -> void:
	_sfx("rattle")
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var dir: Vector3 = open_offset.normalized() * 0.012 if open_offset != Vector3.ZERO else Vector3(0, 0, 0.012)
	for i in 3:
		_tween.tween_property(moving, "position", dir, 0.04)
		_tween.tween_property(moving, "position", Vector3.ZERO, 0.05)


func _show_message(text: String) -> void:
	if _label == null:
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.fixed_size = true
		_label.pixel_size = 0.0008
		_label.font_size = 28
		_label.outline_size = 8
		_label.modulate = Color(1.0, 0.92, 0.75)
		handle.add_child(_label)
		_label.position = Vector3(0, 0.08, 0)
	_label.text = text
	_label.modulate.a = 1.0
	_label.visible = true
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property(_label, "modulate:a", 0.0, 0.5)
	t.tween_callback(func() -> void: _label.visible = false)



# ---------------------------------------------------------------------------
# Sonido y bloqueo de interfaz
# ---------------------------------------------------------------------------

func _sfx(sound: String) -> void:
	var s: Node = get_tree().get_first_node_in_group("sfx")
	if s:
		s.call("play", sound, handle.global_position)


func _play_toggle_sound() -> void:
	var style: String = sound_style
	if style == "none":
		return
	if style == "auto":
		if open_rotation_degrees != Vector3.ZERO:
			style = "door"
		elif open_scale != Vector3.ONE:
			style = "curtain"
		elif open_offset != Vector3.ZERO:
			style = "drawer"
		else:
			style = "click"
	match style:
		"door":
			_sfx("door_open" if is_open else "door_close")
		"drawer":
			_sfx("drawer_open" if is_open else "drawer_close")
		_:
			_sfx(style)


## true si hay una nota abierta en pantalla (para no abrir cajones mientras lees).
func _ui_busy() -> bool:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	return ui != null and bool(ui.call("is_busy"))
