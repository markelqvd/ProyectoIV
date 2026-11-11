class_name Story
extends Node

@export var letter: NodePath
@export var doorbell: NodePath
@export var mirror_label: NodePath
@export var mirror_fog: NodePath
@export var tv_label: NodePath
@export var tv_light: NodePath
@export var pillow: NodePath

var stage: int = 0
var hint_index: int = 0
var finished: bool = false
var _fridge_seen: bool = false

@onready var _letter: Node3D = get_node(letter)
@onready var _doorbell: Node3D = get_node(doorbell)
@onready var _mirror_label: Label3D = get_node(mirror_label)
@onready var _mirror_fog: MeshInstance3D = get_node(mirror_fog)
@onready var _tv_label: Label3D = get_node(tv_label)
@onready var _tv_light: Light3D = get_node(tv_light)
@onready var _pillow: Openable = get_node(pillow)


func _ready() -> void:
	Game.story = self
	_intro.call_deferred()


func _exit_tree() -> void:
	if Game.story == self:
		Game.story = null


func _process(_delta: float) -> void:
	_tv_label.visible = _tv_light.visible


func event(event_name: String) -> void:
	match event_name:
		"carta":
			_set_stage(1)
			UI.subtitle(Texts.SUBTITLES["diario"], 4.0)
		"pick_concha":
			_set_stage(2)
			UI.subtitle(Texts.SUBTITLES["concha"], 4.0)
		"concha_placed":
			_set_stage(3)
			_reveal_mirror()
		"safe_open":
			_set_stage(4)
		"pick_key":
			_set_stage(5)
		"foto":
			UI.subtitle(Texts.SUBTITLES["foto"], 4.0)
		"nota_comoda":
			_set_stage(6)
			_pillow.locked = false
		"pick_llave_portal":
			_set_stage(7)
			UI.subtitle(Texts.SUBTITLES["llave_portal"], 3.0)


func on_fridge_opened() -> void:
	if _fridge_seen or stage > 1:
		return
	_fridge_seen = true
	UI.subtitle(Texts.SUBTITLES["nevera"], 3.5)


func next_hint() -> void:
	if not _tv_light.visible:
		UI.subtitle(Texts.SUBTITLES["tele_apagada"], 2.0)
		return
	var hints: Array = Texts.HINTS.get(stage, ["..."])
	_tv_label.text = hints[mini(hint_index, hints.size() - 1)]
	hint_index += 1
	Sfx.play("static", _tv_label.global_position)


func finish() -> void:
	if finished:
		return
	finished = true
	Sfx.play("ending")
	UI.show_ending(Texts.ENDING_TITLE, Texts.ENDING_HINT)


func _intro() -> void:
	_letter.visible = false
	_tv_label.text = Texts.TV_IDLE
	UI.fade_in(3.0)
	await get_tree().create_timer(2.0).timeout
	UI.subtitle(Texts.SUBTITLES["intro_silencio"], 1.5)
	await get_tree().create_timer(2.5).timeout
	Sfx.play("doorbell", _doorbell.global_position)
	_letter.visible = true
	UI.subtitle(Texts.SUBTITLES["timbre"], 3.5)


func _set_stage(new_stage: int) -> void:
	if new_stage > stage:
		stage = new_stage
		hint_index = 0


func _reveal_mirror() -> void:
	Sfx.play("drip", _mirror_fog.global_position)
	await get_tree().create_timer(1.0).timeout
	Sfx.play("reveal", _mirror_fog.global_position)
	var fog_material := _mirror_fog.material_override as StandardMaterial3D
	create_tween().tween_property(fog_material, "albedo_color:a", 0.6, 2.5)
	_mirror_label.text = Texts.MIRROR
	_mirror_label.visible = true
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_mirror_label, "modulate:a", 0.85, 2.5)
	await get_tree().create_timer(3.5).timeout
	UI.add_note(Texts.NOTES["espejo"]["title"], Texts.NOTES["espejo"]["body"])
	UI.subtitle(Texts.SUBTITLES["espejo"], 3.5)
