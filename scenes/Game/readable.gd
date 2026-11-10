extends Area3D
## Objeto que se puede leer (carta, nota, foto). Se lee con el botón de interactuar.

@export var title: String = "Nota"
@export_multiline var text: String = ""
## Evento que se manda a la historia al leerlo.
@export var story_event: String = ""
## Si está activo, el objeto desaparece al leerlo (por ejemplo, la carta del suelo).
@export var hide_on_read: bool = false


func _ready() -> void:
	add_to_group("readables")


func read() -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui:
		ui.call("show_note", title, text)
	var sfx: Node = get_tree().get_first_node_in_group("sfx")
	if sfx:
		sfx.call("play", "paper")
	var story: Node = get_tree().get_first_node_in_group("story")
	if story and story_event != "":
		story.call("event", story_event)
	if hide_on_read:
		visible = false
		set_deferred("collision_layer", 0)
