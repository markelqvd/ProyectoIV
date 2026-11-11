class_name ItemData
extends Resource

enum Shape { KEY, SHELL }

@export var id: String = ""
@export var display_name: String = ""
@export var shape: Shape = Shape.KEY
@export var size: float = 1.0
@export_group("Aspecto")
@export var color: Color = Color.WHITE
@export var icon_shadow: Color = Color.BLACK
@export_range(0.0, 1.0) var metallic: float = 0.0
@export_range(0.0, 1.0) var roughness: float = 0.5
@export var glow: float = 0.0
@export_group("Escala y colocación")
@export var world_scale: float = 0.6
@export var world_rotation_degrees: Vector3 = Vector3.ZERO
@export var held_scale: float = 1.0
@export var place_height: float = 0.02
@export_group("Mano")
@export_enum("wrap", "pinch", "cradle") var grip_style: String = "wrap"


func build_mesh(scale: float) -> Mesh:
	return ItemMeshes.build(shape, size * scale)


func make_material(with_glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if with_glow and glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


func make_icon() -> Texture2D:
	return ItemIcons.make(self)
