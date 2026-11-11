class_name ItemIcons
extends RefCounted

const SIZE: int = 64


static func make(item: ItemData) -> Texture2D:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	match item.shape:
		ItemData.Shape.SHELL:
			_shell(image, item.color, item.icon_shadow)
		_:
			_key(image, item.color, item.icon_shadow)
	return ImageTexture.create_from_image(image)


static func _key(image: Image, main: Color, shadow: Color) -> void:
	for x in range(4, 30):
		for y in range(4, 30):
			var d: float = Vector2(x - 16.5, y - 16.5).length()
			if d >= 6.0 and d <= 12.0:
				image.set_pixel(x, y, main if d < 10.5 else shadow)

	var axis := Vector2(1, 1).normalized()
	var perp := Vector2(1, -1).normalized()
	for x in SIZE:
		for y in SIZE:
			var p := Vector2(x, y) - Vector2(22, 22)
			var along: float = p.dot(axis)
			var side: float = p.dot(perp)
			if along >= 0.0 and along <= 46.0 and absf(side) <= 3.5:
				image.set_pixel(x, y, main)
			for tooth in [Vector2(30.0, 10.0), Vector2(39.0, 8.0)]:
				if along >= tooth.x and along <= tooth.x + 5.0 and side >= 3.0 and side <= 3.0 + tooth.y:
					image.set_pixel(x, y, shadow if side > 1.5 + tooth.y else main)


static func _shell(image: Image, main: Color, shadow: Color) -> void:
	var hinge := Vector2(32, 52)
	for x in SIZE:
		for y in SIZE:
			var p := Vector2(x, y) - hinge
			var d: float = p.length()
			var angle: float = atan2(p.x, -p.y)
			if d < 40.0 and absf(angle) < 1.15 and p.y < 0.0:
				var on_rib: bool = absf(fmod(angle + 1.15, 0.33) - 0.165) < 0.035
				image.set_pixel(x, y, shadow if on_rib or d > 37.0 else main)
	for x in range(24, 40):
		for y in range(50, 56):
			image.set_pixel(x, y, shadow)
