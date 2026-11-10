extends CanvasLayer
## Interfaz de la historia: notas que se leen, diario (Tab), subtítulos, fundidos y pantalla final.
## Se dibuja en la ventana principal (fuera del filtro de píxeles) para que el texto se lea bien.

signal note_closed

const PAPER := Color(0.91, 0.87, 0.77)
const INK := Color(0.18, 0.12, 0.08)

var notes: Array[Dictionary] = []

var _open: bool = false
var _journal_mode: bool = false
var _journal_index: int = 0
var _block_until: int = 0
var _ending: bool = false
var _sub_tween: Tween

var _dim: ColorRect
var _paper: PanelContainer
var _title: Label
var _body: Label
var _footer: Label
var _subtitle: Label
var _fade: ColorRect
var _end_title: Label
var _end_small: Label

# Teclado numérico (caja fuerte)
var _kp_open: bool = false
var _kp_code: String = ""
var _kp_len: int = 3
var _kp_callback: Callable
var _kp_panel: PanelContainer
var _kp_title: Label
var _kp_display: Label
var _kp_hint: Label
var _kp_buttons: Array[Button] = []
var _kp_locked_input: bool = false


func _ready() -> void:
	layer = 120
	add_to_group("game_ui")
	_ensure_journal_action()

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)

	_paper = PanelContainer.new()
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color(0.55, 0.45, 0.32)
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	_paper.add_theme_stylebox_override("panel", style)
	_paper.visible = false
	add_child(_paper)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(col)
	_title = _make_label(INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_body = _make_label(INK)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)
	_footer = _make_label(Color(0.4, 0.32, 0.22))
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_footer)

	_subtitle = _make_label(Color(1, 0.95, 0.85))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.modulate.a = 0.0
	add_child(_subtitle)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_end_title = _make_label(Color(1, 0.92, 0.75))
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_title.modulate.a = 0.0
	add_child(_end_title)
	_end_small = _make_label(Color(0.7, 0.7, 0.7))
	_end_small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_small.modulate.a = 0.0
	add_child(_end_small)

	_build_keypad()

	# Capturar el ratón al empezar. En una build la ventana puede tardar en tener el foco,
	# así que se intenta varias veces.
	_capture_mouse.call_deferred()
	get_tree().create_timer(0.3).timeout.connect(_capture_mouse)
	get_tree().create_timer(1.0).timeout.connect(_capture_mouse)

	get_viewport().size_changed.connect(_layout)
	_layout()


func _make_label(color: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _layout() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	var unit: float = s.y / 100.0
	var w: float = minf(s.x * 0.6, unit * 95.0)
	var h: float = unit * 68.0
	# Tamaños y posiciones calculados a mano (sin anclas) para que funcione en cualquier ventana.
	_dim.position = Vector2.ZERO
	_dim.size = s
	_fade.position = Vector2.ZERO
	_fade.size = s
	_end_title.position = Vector2.ZERO
	_end_title.size = s
	_end_small.position = Vector2(0.0, s.y * 0.62)
	_end_small.size = Vector2(s.x, s.y * 0.08)
	_subtitle.position = Vector2(s.x * 0.15, s.y * 0.78)
	_subtitle.size = Vector2(s.x * 0.7, s.y * 0.14)
	_paper.position = (s - Vector2(w, h)) / 2.0
	_paper.size = Vector2(w, h)
	_layout_keypad(s, unit)
	var style := _paper.get_theme_stylebox("panel") as StyleBoxFlat
	style.set_content_margin_all(unit * 5.0)
	_title.add_theme_font_size_override("font_size", int(unit * 4.2))
	_body.add_theme_font_size_override("font_size", int(unit * 3.4))
	_footer.add_theme_font_size_override("font_size", int(unit * 2.4))
	_subtitle.add_theme_font_size_override("font_size", int(unit * 3.6))
	_subtitle.add_theme_constant_override("outline_size", int(unit * 0.8))
	_end_title.add_theme_font_size_override("font_size", int(unit * 6.0))
	_end_small.add_theme_font_size_override("font_size", int(unit * 2.6))


func _ensure_journal_action() -> void:
	if not InputMap.has_action("journal"):
		InputMap.add_action("journal")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_TAB
		InputMap.action_add_event("journal", ev)


# ---------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------

## true mientras hay una nota abierta (o justo después de cerrarla, o en el final).
func is_busy() -> bool:
	return _open or _kp_open or _ending or Time.get_ticks_msec() < _block_until


## Muestra una nota en pantalla y la guarda en el diario.
func show_note(title: String, body: String, save: bool = true) -> void:
	if save:
		var found: bool = false
		for n in notes:
			if n["title"] == title:
				found = true
		if not found:
			notes.append({"title": title, "body": body})
	_journal_mode = false
	_show_page(title, body, "Clic para cerrar  ·  Tab: diario")


## Añade una nota al diario sin abrirla.
func add_note(title: String, body: String) -> void:
	for n in notes:
		if n["title"] == title:
			return
	notes.append({"title": title, "body": body})


func subtitle(text: String, seconds: float = 3.5) -> void:
	_subtitle.text = text
	if _sub_tween:
		_sub_tween.kill()
	_sub_tween = create_tween()
	_sub_tween.tween_property(_subtitle, "modulate:a", 1.0, 0.3)
	_sub_tween.tween_interval(seconds)
	_sub_tween.tween_property(_subtitle, "modulate:a", 0.0, 0.8)


func fade_in(seconds: float) -> void:
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, seconds)


func show_ending(title: String, small: String) -> void:
	_ending = true
	_close_page()
	_end_title.text = title
	_end_small.text = small
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 2.5)
	t.tween_interval(0.8)
	t.tween_property(_end_title, "modulate:a", 1.0, 2.0)
	t.tween_interval(1.0)
	t.tween_property(_end_small, "modulate:a", 1.0, 1.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ---------------------------------------------------------------------------
# Páginas
# ---------------------------------------------------------------------------

func _show_page(title: String, body: String, footer: String) -> void:
	_title.text = title
	_body.text = body
	_footer.text = footer
	_open = true
	_dim.visible = true
	_paper.visible = true


func _close_page() -> void:
	if not _open:
		return
	_open = false
	_dim.visible = false
	_paper.visible = false
	_block_until = Time.get_ticks_msec() + 250
	note_closed.emit()


func _show_journal_page() -> void:
	_journal_index = clampi(_journal_index, 0, notes.size() - 1)
	var n: Dictionary = notes[_journal_index]
	_journal_mode = true
	_show_page(n["title"], n["body"],
		"Diario %d/%d  ·  ← → para pasar  ·  Tab o clic para cerrar" % [_journal_index + 1, notes.size()])


func _notification(what: int) -> void:
	# Al volver a la ventana del juego (alt-tab, clic en la barra...), recuperar el ratón.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_capture_mouse()


func _capture_mouse() -> void:
	if _kp_open or _ending:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	# Si el ratón está libre (por ejemplo, tras pulsar Esc), un clic lo vuelve a capturar
	# sin que ese clic cuente como interacción.
	if not _kp_open and not _ending and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton and event.pressed:
			_capture_mouse()
			_block_until = Time.get_ticks_msec() + 150
			get_viewport().set_input_as_handled()
			return
	if _kp_open:
		_keypad_input(event)
		return
	if _ending:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			get_tree().quit()
		get_viewport().set_input_as_handled()
		return

	if _open:
		var handled: bool = false
		if _journal_mode and event is InputEventKey and event.pressed:
			if event.keycode == KEY_LEFT or event.keycode == KEY_A:
				_journal_index -= 1
				_show_journal_page()
				handled = true
			elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
				_journal_index += 1
				_show_journal_page()
				handled = true
		if not handled and (event.is_action_pressed("interact") or event.is_action_pressed("journal")
				or event.is_action_pressed("ui_cancel")
				or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)):
			_close_page()
			handled = true
		if handled or event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("journal"):
		if notes.is_empty():
			subtitle("Todavía no has leído nada.", 2.0)
		else:
			_journal_index = notes.size() - 1
			_show_journal_page()
		get_viewport().set_input_as_handled()



# ---------------------------------------------------------------------------
# Teclado numérico
# ---------------------------------------------------------------------------

## Abre el teclado. `callback(code: String) -> bool` devuelve true si el código es correcto.
func show_keypad(title: String, length: int, callback: Callable) -> void:
	_kp_title.text = title
	_kp_len = length
	_kp_callback = callback
	_kp_code = ""
	_kp_locked_input = false
	_kp_hint.text = "Haz clic en los números o escríbelos · Enter: abrir · Esc: salir"
	_kp_refresh()
	_kp_open = true
	_dim.visible = true
	_kp_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_keypad() -> void:
	_kp_open = false
	_kp_panel.visible = false
	_dim.visible = false
	_block_until = Time.get_ticks_msec() + 250
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_keypad() -> void:
	_kp_panel = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.13, 0.14, 0.16)
	st.border_color = Color(0.45, 0.46, 0.5)
	st.set_border_width_all(3)
	st.set_corner_radius_all(6)
	st.shadow_color = Color(0, 0, 0, 0.6)
	st.shadow_size = 14
	_kp_panel.add_theme_stylebox_override("panel", st)
	_kp_panel.visible = false
	add_child(_kp_panel)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_kp_panel.add_child(col)
	_kp_title = _make_label(Color(0.8, 0.8, 0.82))
	_kp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_kp_title)

	var screen := PanelContainer.new()
	var scr := StyleBoxFlat.new()
	scr.bg_color = Color(0.05, 0.09, 0.06)
	scr.set_corner_radius_all(3)
	screen.add_theme_stylebox_override("panel", scr)
	col.add_child(screen)
	_kp_display = _make_label(Color(0.5, 1.0, 0.55))
	_kp_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(_kp_display)

	var grid := GridContainer.new()
	grid.columns = 3
	col.add_child(grid)
	for label in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "OK"]:
		var b := Button.new()
		b.text = label
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_kp_button.bind(label))
		grid.add_child(b)
		_kp_buttons.append(b)

	_kp_hint = _make_label(Color(0.6, 0.6, 0.62))
	_kp_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kp_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_kp_hint)


func _layout_keypad(s: Vector2, unit: float) -> void:
	var w: float = unit * 46.0
	var h: float = unit * 70.0
	_kp_panel.position = (s - Vector2(w, h)) / 2.0
	_kp_panel.size = Vector2(w, h)
	var st := _kp_panel.get_theme_stylebox("panel") as StyleBoxFlat
	st.set_content_margin_all(unit * 3.0)
	(_kp_panel.get_child(0) as VBoxContainer).add_theme_constant_override("separation", int(unit * 1.5))
	_kp_title.add_theme_font_size_override("font_size", int(unit * 3.5))
	_kp_display.add_theme_font_size_override("font_size", int(unit * 8.0))
	_kp_hint.add_theme_font_size_override("font_size", int(unit * 2.0))
	var grid := _kp_buttons[0].get_parent() as GridContainer
	grid.add_theme_constant_override("h_separation", int(unit * 1.2))
	grid.add_theme_constant_override("v_separation", int(unit * 1.2))
	for b in _kp_buttons:
		b.custom_minimum_size = Vector2(0, unit * 8.0)
		b.add_theme_font_size_override("font_size", int(unit * 4.0))


func _kp_refresh() -> void:
	var t: String = ""
	for i in _kp_len:
		t += (_kp_code[i] if i < _kp_code.length() else "_") + (" " if i < _kp_len - 1 else "")
	_kp_display.text = t
	_kp_display.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55))


func _kp_button(label: String) -> void:
	if _kp_locked_input:
		return
	match label:
		"<":
			if _kp_code.length() > 0:
				_kp_code = _kp_code.substr(0, _kp_code.length() - 1)
			_kp_beep()
		"OK":
			_kp_submit()
			return
		_:
			if _kp_code.length() < _kp_len:
				_kp_code += label
			_kp_beep()
	_kp_refresh()


func _kp_beep() -> void:
	var sfx: Node = get_tree().get_first_node_in_group("sfx")
	if sfx:
		sfx.call("play", "tick")


func _kp_submit() -> void:
	if _kp_code.length() < _kp_len:
		return
	_kp_locked_input = true
	var ok: bool = bool(_kp_callback.call(_kp_code))
	if ok:
		_kp_display.text = "ABIERTO"
		_kp_display.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		await get_tree().create_timer(0.8).timeout
		_close_keypad()
	else:
		_kp_display.text = "ERROR"
		_kp_display.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		await get_tree().create_timer(0.7).timeout
		_kp_code = ""
		_kp_locked_input = false
		_kp_refresh()


func _keypad_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k == KEY_ESCAPE:
			_close_keypad()
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			_kp_button("OK")
		elif k == KEY_BACKSPACE:
			_kp_button("<")
		elif k >= KEY_0 and k <= KEY_9:
			_kp_button(str(k - KEY_0))
		elif k >= KEY_KP_0 and k <= KEY_KP_9:
			_kp_button(str(k - KEY_KP_0))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		pass
