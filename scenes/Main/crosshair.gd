extends Control
## Cruz en el centro de la pantalla. Se ilumina cuando apuntas a algo con lo que interactuar.

var active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()


func set_active(value: bool) -> void:
	if value != active:
		active = value
		queue_redraw()


func _draw() -> void:
	# Centro de la pantalla (del viewport donde se dibuja), no del tamaño del Control.
	var c: Vector2 = (get_viewport_rect().size / 2.0).floor()
	var arm: float = 3.0 if active else 2.0
	var color: Color = Color(1.0, 0.82, 0.35) if active else Color(1.0, 1.0, 1.0, 0.85)
	var h := Rect2(c.x - arm, c.y, arm * 2.0 + 1.0, 1.0)
	var v := Rect2(c.x, c.y - arm, 1.0, arm * 2.0 + 1.0)
	var shadow := Color(0.0, 0.0, 0.0, 0.6)
	draw_rect(h.grow(1.0), shadow)
	draw_rect(v.grow(1.0), shadow)
	draw_rect(h, color)
	draw_rect(v, color)
