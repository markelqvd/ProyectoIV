extends MeshInstance3D
## Muestra la malla de la llave (para el objeto recogible del mundo).

const KeyMesh = preload("res://scenes/Key/key_mesh.gd")

## Escala de la llave en el mundo (1.0 = tamaño en la mano).
@export var key_scale: float = 0.6


func _ready() -> void:
	mesh = KeyMesh.build(key_scale)
	material_override = KeyMesh.make_material()
