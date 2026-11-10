extends RefCounted
## Registro de objetos nuevos: malla, material, forma de agarrarlos y nombre.

const KeyMesh = preload("res://scenes/Key/key_mesh.gd")


static func build_mesh(id: String, s: float = 1.0) -> Mesh:
	match id:
		"key":
			return KeyMesh.build(s)
		"llave_portal":
			return KeyMesh.build(s * 1.25)
		"concha":
			return _shell(s)
	return null


static func make_material(id: String) -> Material:
	if id == "key":
		return KeyMesh.make_material()
	var m := StandardMaterial3D.new()
	match id:
		"llave_portal":
			m.albedo_color = Color(0.45, 0.43, 0.42)
			m.metallic = 0.85
			m.roughness = 0.55
		"concha":
			m.albedo_color = Color(0.62, 0.30, 0.88)
			m.roughness = 0.35
			m.metallic = 0.15
		_:
			m.albedo_color = Color.WHITE
	return m


## "pinch" = entre pulgar e índice (llaves); "cradle" = apoyado en la palma (concha);
## "wrap" = rodeando el objeto.
static func grip_style(id: String) -> String:
	if id == "key" or id == "llave_portal":
		return "pinch"
	if id == "concha":
		return "cradle"
	return "wrap"


## Escala del objeto cuando está en la mano.
static func held_scale(id: String) -> float:
	if id == "concha":
		return 1.5
	return 1.0


static func has_item(id: String) -> bool:
	return id in ["key", "llave_portal", "concha"]


## Concha en abanico: media esfera aplastada con costillas.
static func _shell(s: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := SphereMesh.new()
	body.radius = 0.07
	body.height = 0.14
	body.is_hemisphere = true
	body.radial_segments = 16
	body.rings = 6
	st.append_from(body, 0, Transform3D(Basis().scaled(Vector3(1.0, 0.45, 0.85) * s), Vector3.ZERO))
	var hinge := Vector3(0.0, 0.0, -0.055) * s
	for i in 7:
		var a: float = lerpf(-1.0, 1.0, float(i) / 6.0)
		var rib := BoxMesh.new()
		rib.size = Vector3(0.008, 0.012, 0.075) * s
		var b := Basis(Vector3.UP, a)
		var center: Vector3 = hinge + b * (Vector3(0.0, 0.0, 0.045) * s) + Vector3(0.0, 0.024, 0.0) * s
		st.append_from(rib, 0, Transform3D(b, center))
	var ear := BoxMesh.new()
	ear.size = Vector3(0.05, 0.012, 0.022) * s
	st.append_from(ear, 0, Transform3D(Basis.IDENTITY, hinge + Vector3(0.0, 0.006, -0.004) * s))
	return st.commit()
