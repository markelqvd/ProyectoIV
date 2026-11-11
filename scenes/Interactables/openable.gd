class_name Openable
extends Node3D

signal opened
signal closed

@export var open_offset: Vector3 = Vector3(0, 0, 0.4)
@export var open_rotation_degrees: Vector3 = Vector3.ZERO
@export var open_scale: Vector3 = Vector3.ONE
@export var duration: float = 0.4
@export_range(0.0, 1.0) var min_look_dot: float = 0.85
@export_enum("auto", "door", "drawer", "click", "curtain", "none") var sound_style: String = "auto"
@export_group("Cerradura")
@export var required_item: String = ""
@export var consume_item: bool = true
@export var locked: bool = false
@export var keypad_target: NodePath
@export var locked_message: String = Texts.LOCKED

var is_open: bool = false
var player_near: bool = false
var unlocked: bool = false
var _tween: Tween
var _label: Label3D

@onready var moving: Node3D = $Moving
@onready var handle: Marker3D = $Moving/Handle
@onready var prompt: Sprite3D = $Moving/Handle/Prompt
@onready var contents: Node3D = $Moving/Contents
@onready var _area: Area3D = $InteractArea


func _ready() -> void:
	add_to_group("openables")
	prompt.visible = false
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	prompt.visible = player_near and is_best_target()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not player_near or not is_best_target() or UI.is_busy():
		return
	if not is_open and locked:
		var keypad: Node = get_node_or_null(keypad_target)
		if keypad and keypad.has_method("open_keypad"):
			keypad.call("open_keypad")
		else:
			_reject()
		return
	if not is_open and required_item != "" and not unlocked:
		if Game.held_item_id() != required_item:
			_reject()
			return
		unlocked = true
		_show_message(Texts.UNLOCKED)
		_play("clack")
		if consume_item:
			Game.player.remove_item(required_item)
	toggle()


func toggle() -> void:
	is_open = not is_open
	_play_toggle_sound()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(moving, "position", open_offset if is_open else Vector3.ZERO, duration)
	_tween.tween_property(moving, "rotation_degrees", open_rotation_degrees if is_open else Vector3.ZERO, duration)
	if open_scale != Vector3.ONE:
		_tween.tween_property(moving, "scale", open_scale if is_open else Vector3.ONE, duration)
	if is_open:
		opened.emit()
	else:
		closed.emit()


func look_score() -> float:
	return _score_of(handle.global_position)


func is_best_target() -> bool:
	var score: float = look_score()
	if score < min_look_dot:
		return false
	if is_open:
		for item in contents.get_children():
			if item is Node3D and item.visible and _score_of(item.global_position) > score:
				return false
	for other in get_tree().get_nodes_in_group("openables"):
		if other != self and other.player_near and other.look_score() > score:
			return false
	return true


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		player_near = true


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		player_near = false
		prompt.visible = false


func _score_of(point: Vector3) -> float:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return -1.0
	return (point - camera.global_position).normalized().dot(-camera.global_basis.z)


func _reject() -> void:
	_play("rattle")
	_show_message(locked_message)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var shake: Vector3 = open_offset.normalized() * 0.012 if open_offset != Vector3.ZERO else Vector3(0, 0, 0.012)
	for i in 3:
		_tween.tween_property(moving, "position", shake, 0.04)
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
		_label.position = Vector3(0, 0.08, 0)
		handle.add_child(_label)
	_label.text = text
	_label.modulate.a = 1.0
	_label.visible = true
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_label.hide)


func _play(sound: String) -> void:
	Sfx.play(sound, handle.global_position)


func _play_toggle_sound() -> void:
	var style: String = sound_style
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
		"none":
			pass
		"door":
			_play("door_open" if is_open else "door_close")
		"drawer":
			_play("drawer_open" if is_open else "drawer_close")
		_:
			_play(style)
