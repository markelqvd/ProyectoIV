extends Light3D
## Luz con parpadeo: fluorescente que falla, bombilla inestable o brillo de televisión.

@export_enum("Fluorescente", "Bombilla", "Television") var mode: int = 0
## Malla emisiva que se apaga junto con la luz (opcional).
@export var emissive_mesh: GeometryInstance3D

var _base: float = 1.0
var _base_color: Color
var _t: float = 0.0
var _next: float = 0.0
var _burst: float = 0.0


func _ready() -> void:
	_base = light_energy
	_base_color = light_color
	_next = randf_range(1.0, 4.0)


func _process(delta: float) -> void:
	# Si un interruptor la ha apagado, no hace nada.
	if not visible:
		return
	_t += delta
	match mode:
		0:
			_fluorescent(delta)
		1:
			_bulb()
		2:
			_tv()


func _set_on(amount: float) -> void:
	light_energy = _base * amount
	if emissive_mesh:
		emissive_mesh.visible = amount > 0.3


func _fluorescent(delta: float) -> void:
	if _burst > 0.0:
		_burst -= delta
		if _t > _next:
			_next = _t + randf_range(0.03, 0.12)
			_set_on(1.0 if randf() > 0.5 else 0.05)
		if _burst <= 0.0:
			_set_on(1.0)
			_next = _t + randf_range(2.0, 9.0)
	elif _t > _next:
		_burst = randf_range(0.2, 1.0)
	else:
		_set_on(0.95 + 0.05 * sin(_t * 120.0))


func _bulb() -> void:
	var n: float = 0.88 + 0.12 * sin(_t * 7.3) * sin(_t * 2.1 + 1.0)
	if _t > _next:
		_next = _t + randf_range(3.0, 10.0)
		_burst = 0.15
	if _burst > 0.0:
		_burst -= get_process_delta_time()
		n *= 0.25
	_set_on(n)


func _tv() -> void:
	if _t > _next:
		_next = _t + randf_range(0.06, 0.45)
		light_energy = _base * randf_range(0.5, 1.2)
		light_color = _base_color.lerp(Color(randf(), randf(), randf()), 0.25)
