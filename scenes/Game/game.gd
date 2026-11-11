extends Node

var player: Player
var story: Story


func event(event_name: String) -> void:
	if story:
		story.event(event_name)


func held_item_id() -> String:
	return player.get_selected_item_id() if player else ""
