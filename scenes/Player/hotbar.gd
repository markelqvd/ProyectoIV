class_name Hotbar
extends CanvasLayer

const SLOT_COUNT: int = 3
const SLOT_FRACTION: float = 0.11
const MARGIN_FRACTION: float = 0.03

var _panels: Array[PanelContainer] = []
var _icons: Array[TextureRect] = []
var _numbers: Array[Label] = []
var _icon_cache: Dictionary = {}
var _bar: PanelContainer
var _column: VBoxContainer
var _items: Array[String] = []
var _selected: int = 0


func _ready() -> void:
	_bar = PanelContainer.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	style.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("panel", style)
	add_child(_bar)

	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_column)

	for i in SLOT_COUNT:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var content := Control.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(content)

		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)

		var number := Label.new()
		number.text = str(i + 1)
		number.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		number.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(number)

		_column.add_child(panel)
		_panels.append(panel)
		_icons.append(icon)
		_numbers.append(number)

	get_viewport().size_changed.connect(_layout)
	_layout()


func update_hotbar(items: Array[String], selected: int) -> void:
	_items = items
	_selected = selected
	if _panels.is_empty():
		return
	var border: int = maxi(1, int(roundf(_panels[0].custom_minimum_size.x * 0.05)))
	for i in SLOT_COUNT:
		_icons[i].texture = _icon_for(items[i]) if i < items.size() else null
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.07, 0.08, 0.85)
		style.border_color = Color(1.0, 0.78, 0.2) if i == selected else Color(0.65, 0.65, 0.65, 0.7)
		style.set_border_width_all(border + 1 if i == selected else border)
		style.set_corner_radius_all(border * 2)
		_panels[i].add_theme_stylebox_override("panel", style)


func _icon_for(item_id: String) -> Texture2D:
	if not _icon_cache.has(item_id):
		var item: ItemData = Items.find(item_id)
		_icon_cache[item_id] = item.make_icon() if item else null
	return _icon_cache[item_id]


func _layout() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var slot: float = roundf(clampf(screen.y * SLOT_FRACTION, 18.0, 140.0))
	var separation: float = maxf(2.0, roundf(slot * 0.12))
	var padding: float = maxf(2.0, roundf(slot * 0.08))
	var margin: float = roundf(screen.y * MARGIN_FRACTION)
	var inset: float = roundf(slot * 0.12)
	var font_size: int = int(maxf(6.0, roundf(slot * 0.3)))

	_column.add_theme_constant_override("separation", int(separation))
	for i in SLOT_COUNT:
		_panels[i].custom_minimum_size = Vector2(slot, slot)
		(_panels[i].get_child(0) as Control).custom_minimum_size = Vector2(slot, slot)
		_icons[i].offset_left = inset
		_icons[i].offset_top = inset
		_icons[i].offset_right = -inset
		_icons[i].offset_bottom = -inset
		_numbers[i].add_theme_font_size_override("font_size", font_size)
		_numbers[i].add_theme_constant_override("outline_size", maxi(1, font_size / 4))
		_numbers[i].position = Vector2(roundf(slot * 0.06), 0.0)

	var size := Vector2(slot + padding * 2.0, slot * SLOT_COUNT + separation * (SLOT_COUNT - 1) + padding * 2.0)
	(_bar.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(padding)
	_bar.size = size
	_bar.position = Vector2(screen.x - size.x - margin, roundf((screen.y - size.y) / 2.0))
	update_hotbar(_items, _selected)
