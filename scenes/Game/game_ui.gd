extends CanvasLayer

const PAPER := Color(0.91, 0.87, 0.77)
const INK := Color(0.18, 0.12, 0.08)
const CLOSE_BLOCK_MS: int = 250

var notes: Array[Dictionary] = []

var _note_open: bool = false
var _journal_mode: bool = false
var _journal_index: int = 0
var _block_until: int = 0
var _ending: bool = false
var _subtitle_tween: Tween

var _dim: ColorRect
var _paper: PanelContainer
var _title: Label
var _body: Label
var _footer: Label
var _subtitle: Label
var _fade: ColorRect
var _end_title: Label
var _end_hint: Label

var _keypad_open: bool = false
var _keypad_code: String = ""
var _keypad_length: int = 3
var _keypad_callback: Callable
var _keypad_waiting: bool = false
var _keypad: PanelContainer
var _keypad_title: Label
var _keypad_display: Label
var _keypad_help: Label
var _keypad_grid: GridContainer


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_journal_action()
	_build_note()
	_build_overlay()
	_build_keypad()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_capture_mouse.call_deferred()
	get_tree().create_timer(0.3).timeout.connect(_capture_mouse)
	get_tree().create_timer(1.0).timeout.connect(_capture_mouse)


func is_busy() -> bool:
	return _note_open or _keypad_open or _ending or Time.get_ticks_msec() < _block_until


func show_note(title: String, body: String) -> void:
	add_note(title, body)
	_journal_mode = false
	_open_page(title, body, Texts.NOTE_HELP)


func add_note(title: String, body: String) -> void:
	for note in notes:
		if note["title"] == title:
			return
	notes.append({"title": title, "body": body})


func subtitle(text: String, seconds: float = 3.5) -> void:
	_subtitle.text = text
	if _subtitle_tween:
		_subtitle_tween.kill()
	_subtitle_tween = create_tween()
	_subtitle_tween.tween_property(_subtitle, "modulate:a", 1.0, 0.3)
	_subtitle_tween.tween_interval(seconds)
	_subtitle_tween.tween_property(_subtitle, "modulate:a", 0.0, 0.8)


func fade_in(seconds: float) -> void:
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, seconds)


func show_ending(title: String, hint: String) -> void:
	_ending = true
	_close_page()
	_end_title.text = title
	_end_hint.text = hint
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 2.5)
	tween.tween_interval(0.8)
	tween.tween_property(_end_title, "modulate:a", 1.0, 2.0)
	tween.tween_interval(1.0)
	tween.tween_property(_end_hint, "modulate:a", 1.0, 1.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_keypad(title: String, length: int, callback: Callable) -> void:
	_keypad_title.text = title
	_keypad_length = length
	_keypad_callback = callback
	_keypad_code = ""
	_keypad_waiting = false
	_refresh_keypad()
	_keypad_open = true
	_dim.visible = true
	_keypad.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_capture_mouse()


func _input(event: InputEvent) -> void:
	if _ending:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			get_tree().quit()
		get_viewport().set_input_as_handled()
		return

	if _keypad_open:
		_keypad_input(event)
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and event is InputEventMouseButton and event.pressed:
		_capture_mouse()
		_block_until = Time.get_ticks_msec() + 150
		get_viewport().set_input_as_handled()
		return

	if _note_open:
		_note_input(event)
		return

	if event.is_action_pressed("journal"):
		if notes.is_empty():
			subtitle(Texts.SUBTITLES["diario_vacio"], 2.0)
		else:
			_journal_index = notes.size() - 1
			_show_journal_page()
		get_viewport().set_input_as_handled()


func _note_input(event: InputEvent) -> void:
	if _journal_mode and event is InputEventKey and event.pressed:
		if event.keycode in [KEY_LEFT, KEY_A]:
			_journal_index -= 1
			_show_journal_page()
		elif event.keycode in [KEY_RIGHT, KEY_D]:
			_journal_index += 1
			_show_journal_page()
	var close: bool = event.is_action_pressed("interact") or event.is_action_pressed("journal") \
		or event.is_action_pressed("ui_cancel") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if close:
		_close_page()
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _keypad_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	if key == KEY_ESCAPE:
		_close_keypad()
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		_on_keypad_button("OK")
	elif key == KEY_BACKSPACE:
		_on_keypad_button("<")
	elif key >= KEY_0 and key <= KEY_9:
		_on_keypad_button(str(key - KEY_0))
	elif key >= KEY_KP_0 and key <= KEY_KP_9:
		_on_keypad_button(str(key - KEY_KP_0))
	get_viewport().set_input_as_handled()


func _capture_mouse() -> void:
	if not _keypad_open and not _ending:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_page(title: String, body: String, footer: String) -> void:
	_title.text = title
	_body.text = body
	_footer.text = footer
	_note_open = true
	_dim.visible = true
	_paper.visible = true


func _close_page() -> void:
	if not _note_open:
		return
	_note_open = false
	_dim.visible = false
	_paper.visible = false
	_block_until = Time.get_ticks_msec() + CLOSE_BLOCK_MS


func _show_journal_page() -> void:
	_journal_index = clampi(_journal_index, 0, notes.size() - 1)
	var note: Dictionary = notes[_journal_index]
	_journal_mode = true
	_open_page(note["title"], note["body"],
		Texts.JOURNAL_HELP % [_journal_index + 1, notes.size()])


func _close_keypad() -> void:
	_keypad_open = false
	_keypad.visible = false
	_dim.visible = false
	_block_until = Time.get_ticks_msec() + CLOSE_BLOCK_MS
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_keypad_button(label: String) -> void:
	if _keypad_waiting:
		return
	match label:
		"<":
			_keypad_code = _keypad_code.left(-1)
		"OK":
			_submit_keypad()
			return
		_:
			if _keypad_code.length() < _keypad_length:
				_keypad_code += label
	Sfx.play("tick")
	_refresh_keypad()


func _submit_keypad() -> void:
	if _keypad_code.length() < _keypad_length:
		return
	_keypad_waiting = true
	var correct: bool = bool(_keypad_callback.call(_keypad_code))
	_keypad_display.text = "ABIERTO" if correct else "ERROR"
	_keypad_display.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if correct else Color(1.0, 0.35, 0.3))
	await get_tree().create_timer(0.8 if correct else 0.7).timeout
	if correct:
		_close_keypad()
	else:
		_keypad_code = ""
		_keypad_waiting = false
		_refresh_keypad()


func _refresh_keypad() -> void:
	var digits: PackedStringArray = []
	for i in _keypad_length:
		digits.append(_keypad_code[i] if i < _keypad_code.length() else "_")
	_keypad_display.text = " ".join(digits)
	_keypad_display.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55))


func _add_journal_action() -> void:
	if InputMap.has_action("journal"):
		return
	InputMap.add_action("journal")
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	InputMap.action_add_event("journal", tab)


func _label(color: Color) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_note() -> void:
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

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(column)
	_title = _label(INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_body = _label(INK)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)
	_footer = _label(Color(0.4, 0.32, 0.22))
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_footer)


func _build_overlay() -> void:
	_subtitle = _label(Color(1, 0.95, 0.85))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	_subtitle.modulate.a = 0.0
	add_child(_subtitle)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_end_title = _label(Color(1, 0.92, 0.75))
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_title.modulate.a = 0.0
	add_child(_end_title)

	_end_hint = _label(Color(0.7, 0.7, 0.7))
	_end_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_hint.modulate.a = 0.0
	add_child(_end_hint)


func _build_keypad() -> void:
	_keypad = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.16)
	style.border_color = Color(0.45, 0.46, 0.5)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 14
	_keypad.add_theme_stylebox_override("panel", style)
	_keypad.visible = false
	add_child(_keypad)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_keypad.add_child(column)

	_keypad_title = _label(Color(0.8, 0.8, 0.82))
	_keypad_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_keypad_title)

	var screen := PanelContainer.new()
	var screen_style := StyleBoxFlat.new()
	screen_style.bg_color = Color(0.05, 0.09, 0.06)
	screen_style.set_corner_radius_all(3)
	screen.add_theme_stylebox_override("panel", screen_style)
	column.add_child(screen)
	_keypad_display = _label(Color(0.5, 1.0, 0.55))
	_keypad_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(_keypad_display)

	_keypad_grid = GridContainer.new()
	_keypad_grid.columns = 3
	column.add_child(_keypad_grid)
	for label in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "OK"]:
		var button := Button.new()
		button.text = label
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_keypad_button.bind(label))
		_keypad_grid.add_child(button)

	_keypad_help = _label(Color(0.6, 0.6, 0.62))
	_keypad_help.text = Texts.KEYPAD_HELP
	_keypad_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keypad_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_keypad_help)


func _layout() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var unit: float = screen.y / 100.0

	for full in [_dim, _fade, _end_title]:
		full.position = Vector2.ZERO
		full.size = screen
	_end_hint.position = Vector2(0.0, screen.y * 0.62)
	_end_hint.size = Vector2(screen.x, screen.y * 0.08)
	_subtitle.position = Vector2(screen.x * 0.15, screen.y * 0.78)
	_subtitle.size = Vector2(screen.x * 0.7, screen.y * 0.14)

	var paper_size := Vector2(minf(screen.x * 0.6, unit * 95.0), unit * 68.0)
	_paper.position = (screen - paper_size) / 2.0
	_paper.size = paper_size
	(_paper.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(unit * 5.0)

	var keypad_size := Vector2(unit * 46.0, unit * 70.0)
	_keypad.position = (screen - keypad_size) / 2.0
	_keypad.size = keypad_size
	(_keypad.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(unit * 3.0)
	(_keypad.get_child(0) as VBoxContainer).add_theme_constant_override("separation", int(unit * 1.5))
	_keypad_grid.add_theme_constant_override("h_separation", int(unit * 1.2))
	_keypad_grid.add_theme_constant_override("v_separation", int(unit * 1.2))
	for button in _keypad_grid.get_children():
		button.custom_minimum_size = Vector2(0, unit * 8.0)
		button.add_theme_font_size_override("font_size", int(unit * 4.0))

	var font_sizes: Dictionary = {
		_title: 4.2, _body: 3.4, _footer: 2.4, _subtitle: 3.6, _end_title: 6.0, _end_hint: 2.6,
		_keypad_title: 3.5, _keypad_display: 8.0, _keypad_help: 2.0,
	}
	for label in font_sizes:
		label.add_theme_font_size_override("font_size", int(unit * font_sizes[label]))
	_subtitle.add_theme_constant_override("outline_size", int(unit * 0.8))
