class_name Crosshair
extends Control

var active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(queue_redraw)


func set_active(value: bool) -> void:
	if value != active:
		active = value
		queue_redraw()


func _draw() -> void:
	var center: Vector2 = (get_viewport_rect().size / 2.0).floor()
	var arm: float = 3.0 if active else 2.0
	var color: Color = Color(1.0, 0.82, 0.35) if active else Color(1.0, 1.0, 1.0, 0.85)
	var horizontal := Rect2(center.x - arm, center.y, arm * 2.0 + 1.0, 1.0)
	var vertical := Rect2(center.x, center.y - arm, 1.0, arm * 2.0 + 1.0)
	for rect in [horizontal, vertical]:
		draw_rect(rect.grow(1.0), Color(0.0, 0.0, 0.0, 0.6))
	for rect in [horizontal, vertical]:
		draw_rect(rect, color)
