extends RefCounted
## Genera la malla de una llave grande y algo caricaturesca.
## Origen en el centro del anillo (la parte que se pinza), cuerpo hacia +Y y grosor en X.
## s = 1.0 es el tamaño para la mano en primera persona; usa valores menores en el mundo.


static func build(s: float = 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Anillo grueso: el toro está en el plano XZ; lo giramos para que su eje sea X.
	var bow := TorusMesh.new()
	bow.inner_radius = 0.024 * s
	bow.outer_radius = 0.052 * s
	bow.rings = 16
	bow.ring_segments = 8
	st.append_from(bow, 0, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3.ZERO))

	# Cuello con dos anillas decorativas.
	_add_box(st, Vector3(0.026, 0.02, 0.05) * s, Vector3(0.0, 0.058, 0.0) * s)
	_add_box(st, Vector3(0.03, 0.012, 0.042) * s, Vector3(0.0, 0.078, 0.0) * s)
	# Caña gruesa.
	_add_box(st, Vector3(0.022, 0.15, 0.026) * s, Vector3(0.0, 0.155, 0.0) * s)
	# Paletón con dientes grandes y cuadrados.
	_add_box(st, Vector3(0.022, 0.07, 0.03) * s, Vector3(0.0, 0.195, 0.026) * s)
	_add_box(st, Vector3(0.022, 0.02, 0.028) * s, Vector3(0.0, 0.17, 0.052) * s)
	_add_box(st, Vector3(0.022, 0.02, 0.02) * s, Vector3(0.0, 0.215, 0.048) * s)
	# Punta redondeada.
	var tip := SphereMesh.new()
	tip.radius = 0.016 * s
	tip.height = 0.032 * s
	tip.radial_segments = 8
	tip.rings = 4
	st.append_from(tip, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.232, 0.0) * s))

	return st.commit()


static func _add_box(st: SurfaceTool, size: Vector3, pos: Vector3) -> void:
	var b := BoxMesh.new()
	b.size = size
	st.append_from(b, 0, Transform3D(Basis.IDENTITY, pos))


static func make_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.72, 0.22)
	m.metallic = 0.6
	m.roughness = 0.4
	return m
