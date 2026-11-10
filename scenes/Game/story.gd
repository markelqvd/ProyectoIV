extends Node
## Historia de la demo: intro, etapas del puzle, pistas de la tele y final.
## Los demás scripts le avisan con story.event("nombre").

const GameUI = preload("res://scenes/Game/game_ui.gd")

## Carta que aparece tras el timbre.
@export var letter: NodePath
## Posición desde la que suena el timbre.
@export var door_marker: NodePath
## Texto y vaho del espejo del baño.
@export var mirror_label: NodePath
@export var mirror_fog: NodePath
## Texto en la pantalla de la tele y su luz (si la luz está apagada, la tele está apagada).
@export var tv_label: NodePath
@export var tv_light: NodePath
## Almohada: está bloqueada hasta leer la nota de la cómoda.
@export var pillow: NodePath

const MIRROR_TEXT := "Mi ciudad se enciende\ncuando yo vigilo.\nCuenta sus luces\nde la tarde a la mañana."

## Pistas por etapa, de más vaga a más concreta.
const HINTS := {
	0: ["Alguien ha llamado a la puerta.", "Mira en la entrada."],
	1: ["Donde siempre es invierno...", "Lo frío se guarda en la cocina.", "Abre la nevera."],
	2: ["Las conchas guardan el sonido del mar.", "¿Dónde hay agua quieta en esta casa?", "Deja la concha en la bañera."],
	3: ["Mira los cuadros del pasillo.", "Cuenta las ventanas encendidas de cada edificio.",
		"Fíjate en la hora de cada reloj y ordénalos de la tarde a la mañana: 18, 21 y 3."],
	4: ["Tres números... ¿y dónde se usan?", "Algo metálico entre tu ropa.", "La caja fuerte del armario: 4 - 7 - 2."],
	5: ["Una llave pequeña para un cajón pequeño.", "La cómoda del fondo del pasillo."],
	6: ["¿Dónde duerme una llave?", "Donde tú sueñas...", "Mira debajo de la almohada."],
	7: ["Ya puedes salir.", "La puerta de la entrada."],
}

var stage: int = 0
var hint_index: int = 0
var finished: bool = false
var _fridge_seen: bool = false
var _ui: CanvasLayer


func _ready() -> void:
	add_to_group("story")
	_intro.call_deferred()


func ui() -> CanvasLayer:
	if _ui == null or not is_instance_valid(_ui):
		_ui = get_tree().get_first_node_in_group("game_ui") as CanvasLayer
		if _ui == null:
			_ui = GameUI.new()
			get_tree().current_scene.add_child(_ui)
	return _ui


func sfx(sound: String, pos: Vector3 = Vector3.INF) -> void:
	var s: Node = get_tree().get_first_node_in_group("sfx")
	if s:
		s.call("play", sound, pos)


func _process(_delta: float) -> void:
	var label := get_node_or_null(tv_label) as Node3D
	var light := get_node_or_null(tv_light) as Node3D
	if label and light:
		label.visible = light.visible


# ---------------------------------------------------------------------------
# Intro
# ---------------------------------------------------------------------------

func _intro() -> void:
	var l := get_node_or_null(letter) as Node3D
	if l:
		l.visible = false
	ui().fade_in(3.0)
	await get_tree().create_timer(2.0).timeout
	ui().subtitle("...", 1.5)
	await get_tree().create_timer(2.5).timeout
	var door := get_node_or_null(door_marker) as Node3D
	sfx("doorbell", door.global_position if door else Vector3.INF)
	if l:
		l.visible = true
	ui().subtitle("Han llamado a la puerta.", 3.5)


# ---------------------------------------------------------------------------
# Eventos y etapas
# ---------------------------------------------------------------------------

func event(event_name: String) -> void:
	match event_name:
		"carta":
			_set_stage(1)
			ui().subtitle("Pulsa Tab para releer lo que has leído.", 4.0)
		"pick_concha":
			_set_stage(2)
			ui().subtitle("Si la acercas al oído, suena a mar.", 4.0)
		"concha_placed":
			_set_stage(3)
			_reveal_mirror()
		"safe_open":
			_set_stage(4)
		"pick_key":
			_set_stage(5)
		"foto":
			ui().subtitle("Elías... La carta iba firmada con una «E».", 4.0)
		"nota_comoda":
			_set_stage(6)
			var p: Node = get_node_or_null(pillow)
			if p:
				p.set("locked", false)
		"pick_llave_portal":
			_set_stage(7)
			ui().subtitle("La llave de casa.", 3.0)


## Al abrir la nevera por primera vez: llama la atención sobre la concha.
func on_fridge_opened() -> void:
	if _fridge_seen or stage > 1:
		return
	_fridge_seen = true
	ui().subtitle("¿Una concha... dentro de la nevera?", 3.5)


func _set_stage(n: int) -> void:
	if n > stage:
		stage = n
		hint_index = 0


func _reveal_mirror() -> void:
	var fog := get_node_or_null(mirror_fog) as MeshInstance3D
	var label := get_node_or_null(mirror_label) as Label3D
	if fog:
		sfx("drip", fog.global_position)
	await get_tree().create_timer(1.0).timeout
	if fog:
		sfx("reveal", fog.global_position)
		var mat := fog.material_override as StandardMaterial3D
		if mat:
			create_tween().tween_property(mat, "albedo_color:a", 0.6, 2.5)
	if label:
		label.text = MIRROR_TEXT
		label.visible = true
		var t := create_tween()
		t.tween_interval(1.5)
		t.tween_property(label, "modulate:a", 0.85, 2.5)
	await get_tree().create_timer(3.5).timeout
	ui().add_note("Mensaje en el espejo", MIRROR_TEXT.replace("\n", " "))
	ui().subtitle("Algo ha aparecido en el espejo del baño.", 3.5)


## La llama el mando de la tele.
func next_hint() -> void:
	var light := get_node_or_null(tv_light) as Node3D
	var label := get_node_or_null(tv_label) as Label3D
	if light and not light.visible:
		ui().subtitle("La tele está apagada.", 2.0)
		return
	var list: Array = HINTS.get(stage, ["..."])
	var text: String = list[mini(hint_index, list.size() - 1)]
	hint_index += 1
	if label:
		label.text = text
		sfx("static", label.global_position)


func finish() -> void:
	if finished:
		return
	finished = true
	sfx("ending")
	ui().show_ending("Gracias por jugar la demo", "Pulsa Esc para salir")
