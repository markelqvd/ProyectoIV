extends Area3D

@export var note_id: String = ""
@export var story_event: String = ""
@export var hide_on_read: bool = false


func _ready() -> void:
	add_to_group("readables")


func read() -> void:
	var note: Dictionary = Texts.NOTES.get(note_id, {"title": "", "body": ""})
	UI.show_note(note["title"], note["body"])
	Sfx.play("paper")
	if story_event != "":
		Game.event(story_event)
	if hide_on_read:
		visible = false
		set_deferred("collision_layer", 0)
