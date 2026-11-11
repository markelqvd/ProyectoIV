extends Openable


func toggle() -> void:
	_play("click")
	if Game.story:
		Game.story.next_hint()
