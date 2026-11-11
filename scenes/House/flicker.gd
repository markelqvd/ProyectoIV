extends Light3D

enum Mode { FLUORESCENT, BULB, TELEVISION }

@export var mode: Mode = Mode.FLUORESCENT
@export var emissive_mesh: NodePath

var _emissive: GeometryInstance3D
var _base_energy: float = 1.0
var _base_color: Color
var _time: float = 0.0
var _next: float = 0.0
var _burst: float = 0.0


func _ready() -> void:
	_emissive = get_node_or_null(emissive_mesh) as GeometryInstance3D
	_base_energy = light_energy
	_base_color = light_color
	_next = randf_range(1.0, 4.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	match mode:
		Mode.FLUORESCENT:
			_fluorescent(delta)
		Mode.BULB:
			_bulb(delta)
		Mode.TELEVISION:
			_television()


func _set_level(amount: float) -> void:
	light_energy = _base_energy * amount
	if _emissive:
		_emissive.visible = amount > 0.3


func _fluorescent(delta: float) -> void:
	if _burst > 0.0:
		_burst -= delta
		if _time > _next:
			_next = _time + randf_range(0.03, 0.12)
			_set_level(1.0 if randf() > 0.5 else 0.05)
		if _burst <= 0.0:
			_set_level(1.0)
			_next = _time + randf_range(2.0, 9.0)
	elif _time > _next:
		_burst = randf_range(0.2, 1.0)
	else:
		_set_level(0.95 + 0.05 * sin(_time * 120.0))


func _bulb(delta: float) -> void:
	var level: float = 0.88 + 0.12 * sin(_time * 7.3) * sin(_time * 2.1 + 1.0)
	if _time > _next:
		_next = _time + randf_range(3.0, 10.0)
		_burst = 0.15
	if _burst > 0.0:
		_burst -= delta
		level *= 0.25
	_set_level(level)


func _television() -> void:
	if _time > _next:
		_next = _time + randf_range(0.06, 0.45)
		light_energy = _base_energy * randf_range(0.5, 1.2)
		light_color = _base_color.lerp(Color(randf(), randf(), randf()), 0.25)
