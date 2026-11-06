@tool
extends EditorPlugin
# Al activar el plugin crea la acción "interact" (tecla E) si no existe.

const ACTION := "input/interact"


func _enter_tree() -> void:
	if not ProjectSettings.has_setting(ACTION):
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		ProjectSettings.set_setting(ACTION, {"deadzone": 0.5, "events": [ev]})
		ProjectSettings.save()
