extends MeshInstance3D
## Muestra la malla de un objeto del registro (concha, llave del portal...).

const Items = preload("res://scenes/Items/items.gd")

@export var item_id: String = "concha"
@export var item_scale: float = 0.8
## Brillo propio para que el objeto llame la atención (0 = sin brillo).
@export var glow: float = 0.0
## Si está activo, el brillo late suavemente.
@export var pulse: bool = false

var _mat: StandardMaterial3D
var _t: float = 0.0


func _ready() -> void:
	mesh = Items.build_mesh(item_id, item_scale)
	var m := Items.make_material(item_id)
	if glow > 0.0 and m is StandardMaterial3D:
		_mat = m as StandardMaterial3D
		_mat.emission_enabled = true
		_mat.emission = _mat.albedo_color
		_mat.emission_energy_multiplier = glow
	material_override = m
	set_process(pulse and _mat != null)


func _process(delta: float) -> void:
	_t += delta
	_mat.emission_energy_multiplier = glow * (0.6 + 0.4 * sin(_t * 3.0))
