extends CanvasLayer
## Inventario: tres huecos en vertical, en el lateral derecho de la pantalla.
## Se adapta al tamaño de la pantalla (también con el filtro de píxeles).

const SLOT_COUNT: int = 3
## Tamaño de cada hueco en proporción a la altura de la pantalla.
const SLOT_FRACTION: float = 0.11
## Separación del borde derecho, en proporción a la altura.
const MARGIN_FRACTION: float = 0.03

var slot_panels: Array[PanelContainer] = []
var slot_icons: Array[TextureRect] = []
var slot_numbers: Array[Label] = []
var _bar: PanelContainer
var _row: VBoxContainer
var _items: Array = []
var _selected: int = 0


func _ready() -> void:
	# Anular el desplazamiento y la escala que tenía el nodo en la escena.
	offset = Vector2.ZERO
	scale = Vector2.ONE
	rotation = 0.0
	# Por encima del filtro de píxeles, para que se vea nítido.
	layer = 90

	_bar = PanelContainer.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	bar_style.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("panel", bar_style)
	add_child(_bar)

	_row = VBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_row)

	for i in range(SLOT_COUNT):
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var slot_content := Control.new()
		slot_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(slot_content)

		var icon_rect := TextureRect.new()
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_content.add_child(icon_rect)

		var number_label := Label.new()
		number_label.text = str(i + 1)
		number_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		number_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_content.add_child(number_label)

		_row.add_child(panel)
		slot_panels.append(panel)
		slot_icons.append(icon_rect)
		slot_numbers.append(number_label)

	get_viewport().size_changed.connect(_layout)
	_layout()
	update_hotbar([], 0)


## Coloca y dimensiona la barra según el tamaño actual de la pantalla.
func _layout() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var slot: float = roundf(clampf(screen.y * SLOT_FRACTION, 18.0, 140.0))
	var sep: float = maxf(2.0, roundf(slot * 0.12))
	var pad: float = maxf(2.0, roundf(slot * 0.08))
	var margin: float = roundf(screen.y * MARGIN_FRACTION)

	_row.add_theme_constant_override("separation", int(sep))
	for i in range(SLOT_COUNT):
		slot_panels[i].custom_minimum_size = Vector2(slot, slot)
		var content: Control = slot_panels[i].get_child(0) as Control
		content.custom_minimum_size = Vector2(slot, slot)
		var inset: float = roundf(slot * 0.12)
		slot_icons[i].offset_left = inset
		slot_icons[i].offset_top = inset
		slot_icons[i].offset_right = -inset
		slot_icons[i].offset_bottom = -inset
		var font_size: int = int(maxf(6.0, roundf(slot * 0.3)))
		slot_numbers[i].add_theme_font_size_override("font_size", font_size)
		slot_numbers[i].add_theme_constant_override("outline_size", maxi(1, font_size / 4))
		slot_numbers[i].position = Vector2(roundf(slot * 0.06), 0.0)

	var width: float = slot + pad * 2.0
	var height: float = slot * SLOT_COUNT + sep * (SLOT_COUNT - 1) + pad * 2.0
	var bar_style := _bar.get_theme_stylebox("panel") as StyleBoxFlat
	if bar_style:
		bar_style.set_content_margin_all(pad)
	_bar.size = Vector2(width, height)
	_bar.position = Vector2(screen.x - width - margin, roundf((screen.y - height) / 2.0))
	update_hotbar(_items, _selected)


func update_hotbar(items: Array, selected: int) -> void:
	_items = items
	_selected = selected
	if slot_panels.is_empty():
		return
	var border: int = maxi(1, int(roundf(slot_panels[0].custom_minimum_size.x * 0.05)))
	for i in range(SLOT_COUNT):
		slot_icons[i].texture = null

		if i < items.size():
			var item_id: String = str(items[i].get("id", ""))
			slot_icons[i].texture = make_icon(item_id)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.07, 0.08, 0.85)
		if i == selected:
			style.border_color = Color(1.0, 0.78, 0.2, 1.0)
			style.set_border_width_all(border + 1)
		else:
			style.border_color = Color(0.65, 0.65, 0.65, 0.7)
			style.set_border_width_all(border)
		style.set_corner_radius_all(border * 2)
		slot_panels[i].add_theme_stylebox_override("panel", style)


func make_icon(item_id: String) -> Texture2D:
	# Generar una imagen sencilla del objeto sin archivos externos.
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	match item_id:
		"cube":
			draw_icon_rect(image, 13, 15, 38, 38, Color(0.72, 0.43, 0.20))
		"sphere":
			draw_icon_circle(image, 32, 32, 19, Color(0.85, 0.20, 0.22))
		"cylinder":
			draw_icon_cylinder(image)
		"key":
			draw_icon_key(image, Color(0.95, 0.72, 0.22), Color(0.55, 0.38, 0.08))
		"llave_portal":
			draw_icon_key(image, Color(0.62, 0.62, 0.64), Color(0.28, 0.28, 0.30))
		"concha":
			draw_icon_shell(image)
		_:
			return null

	return ImageTexture.create_from_image(image)


func draw_icon_rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for px in range(x, x + width):
		for py in range(y, y + height):
			image.set_pixel(px, py, color)


func draw_icon_circle(image: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for x in range(cx - radius, cx + radius + 1):
		for y in range(cy - radius, cy + radius + 1):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= radius * radius:
				image.set_pixel(x, y, color)


func draw_icon_cylinder(image: Image) -> void:
	var body_color := Color(0.20, 0.45, 0.90)
	var top_color := Color(0.42, 0.64, 1.0)
	for x in range(16, 48):
		for y in range(20, 45):
			image.set_pixel(x, y, body_color)
	for x in range(16, 48):
		for y in range(13, 27):
			var dx: float = (float(x) - 32.0) / 16.0
			var dy: float = (float(y) - 20.0) / 7.0
			if dx * dx + dy * dy <= 1.0:
				image.set_pixel(x, y, top_color)


func draw_icon_key(image: Image, gold: Color, dark: Color) -> void:
	# Llave en diagonal: anillo arriba a la izquierda, dientes abajo a la derecha.
	# Anillo
	for x in range(4, 30):
		for y in range(4, 30):
			var d: float = Vector2(x - 16.5, y - 16.5).length()
			if d <= 12.0 and d >= 6.0:
				image.set_pixel(x, y, gold if d < 10.5 else dark)
	# Caña en diagonal y dientes: se calcula cada píxel respecto al eje de la llave.
	var axis := Vector2(1, 1).normalized()
	var perp := Vector2(1, -1).normalized()
	var base := Vector2(22, 22)
	for x in range(64):
		for y in range(64):
			var p := Vector2(x, y) - base
			var along: float = p.dot(axis)
			var side: float = p.dot(perp)
			# caña
			if along >= 0.0 and along <= 46.0 and absf(side) <= 3.5:
				image.set_pixel(x, y, gold)
			# dientes
			for tooth in [[30.0, 10.0], [39.0, 8.0]]:
				if along >= tooth[0] and along <= tooth[0] + 5.0 and side >= 3.0 and side <= 3.0 + tooth[1]:
					image.set_pixel(x, y, dark if side > 1.5 + tooth[1] else gold)



func draw_icon_shell(image: Image) -> void:
	# Concha en abanico, vista desde arriba.
	var base := Color(0.66, 0.36, 0.88)
	var rib := Color(0.40, 0.18, 0.58)
	var hinge := Vector2(32, 52)
	for x in range(64):
		for y in range(64):
			var p := Vector2(x, y) - hinge
			var d: float = p.length()
			var ang: float = atan2(p.x, -p.y)
			if d < 40.0 and absf(ang) < 1.15 and p.y < 0.0:
				var on_rib: bool = absf(fmod(ang + 1.15, 0.33) - 0.165) < 0.035
				image.set_pixel(x, y, rib if on_rib or d > 37.0 else base)
	draw_icon_rect(image, 24, 50, 16, 6, rib)
