
extends CanvasLayer

const SLOT_COUNT: int = 3
const SLOT_SIZE: float = 68.0

var slot_panels: Array[PanelContainer] = []
var slot_icons: Array[TextureRect] = []


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)

	# Mira en el centro de la pantalla.
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -10.0
	crosshair.offset_right = 10.0
	crosshair.offset_top = -14.0
	crosshair.offset_bottom = 14.0
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 20)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(crosshair)

	# Barra vertical en la zona central derecha.
	var bar := PanelContainer.new()
	bar.anchor_left = 1.0
	bar.anchor_right = 1.0
	bar.anchor_top = 0.5
	bar.anchor_bottom = 0.5

	bar.offset_left = -SLOT_SIZE - 18.0
	bar.offset_right = -18.0
	bar.offset_top = -120.0
	bar.offset_bottom = 120.0

	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(bar)

	# Colocar los tres huecos en vertical.
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(column)

	for i in range(SLOT_COUNT):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# El número se muestra en una esquina del hueco.
		var slot_content := Control.new()
		slot_content.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(slot_content)

		var icon_rect := TextureRect.new()
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 8.0
		icon_rect.offset_top = 8.0
		icon_rect.offset_right = -8.0
		icon_rect.offset_bottom = -8.0
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_content.add_child(icon_rect)

		var number_label := Label.new()
		number_label.text = str(i + 1)
		number_label.position = Vector2(4, 1)
		number_label.add_theme_font_size_override("font_size", 12)
		number_label.add_theme_color_override(
			"font_color",
			Color(1.0, 1.0, 1.0, 0.9)
		)
		number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_content.add_child(number_label)

		column.add_child(panel)

		slot_panels.append(panel)
		slot_icons.append(icon_rect)

	update_hotbar([], 0)


func update_hotbar(items: Array, selected: int) -> void:
	for i in range(SLOT_COUNT):
		# Por defecto, el hueco está vacío.
		slot_icons[i].texture = null

		if i < items.size():
			var item_id: String = str(items[i].get("id", ""))

			# Utilizar el mismo tipo de icono que el objeto.
			match item_id:
				"cube":
					slot_icons[i].texture = make_icon("cube")
				"sphere":
					slot_icons[i].texture = make_icon("sphere")
				"cylinder":
					slot_icons[i].texture = make_icon("cylinder")

		# Resaltar el hueco seleccionado.
		var style := StyleBoxFlat.new()

		style.bg_color = Color(0.06, 0.07, 0.08, 0.92)

		if i == selected:
			style.border_color = Color(1.0, 0.78, 0.2, 1.0)
			style.set_border_width_all(3)
		else:
			style.border_color = Color(0.65, 0.65, 0.65, 0.8)
			style.set_border_width_all(1)

		style.set_corner_radius_all(5)

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

	return ImageTexture.create_from_image(image)


func draw_icon_rect(
	image: Image,
	x: int,
	y: int,
	width: int,
	height: int,
	color: Color
) -> void:
	for px in range(x, x + width):
		for py in range(y, y + height):
			image.set_pixel(px, py, color)


func draw_icon_circle(
	image: Image,
	cx: int,
	cy: int,
	radius: int,
	color: Color
) -> void:
	for x in range(cx - radius, cx + radius + 1):
		for y in range(cy - radius, cy + radius + 1):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= radius * radius:
				image.set_pixel(x, y, color)


func draw_icon_cylinder(image: Image) -> void:
	var body_color := Color(0.20, 0.45, 0.90)
	var top_color := Color(0.42, 0.64, 1.0)

	# Cuerpo rectangular.
	for x in range(16, 48):
		for y in range(20, 45):
			image.set_pixel(x, y, body_color)

	# Parte superior elíptica.
	for x in range(16, 48):
		for y in range(13, 27):
			var dx: float = (float(x) - 32.0) / 16.0
			var dy: float = (float(y) - 20.0) / 7.0

			if dx * dx + dy * dy <= 1.0:
				image.set_pixel(x, y, top_color)
