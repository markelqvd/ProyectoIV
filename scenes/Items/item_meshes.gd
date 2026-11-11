class_name ItemMeshes
extends RefCounted


static func build(shape: ItemData.Shape, s: float) -> ArrayMesh:
	match shape:
		ItemData.Shape.SHELL:
			return _shell(s)
		_:
			return _key(s)


static func _key(s: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var bow := TorusMesh.new()
	bow.inner_radius = 0.024 * s
	bow.outer_radius = 0.052 * s
	bow.rings = 16
	bow.ring_segments = 8
	st.append_from(bow, 0, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3.ZERO))

	_add_box(st, Vector3(0.026, 0.02, 0.05) * s, Vector3(0.0, 0.058, 0.0) * s)
	_add_box(st, Vector3(0.03, 0.012, 0.042) * s, Vector3(0.0, 0.078, 0.0) * s)
	_add_box(st, Vector3(0.022, 0.15, 0.026) * s, Vector3(0.0, 0.155, 0.0) * s)
	_add_box(st, Vector3(0.022, 0.07, 0.03) * s, Vector3(0.0, 0.195, 0.026) * s)
	_add_box(st, Vector3(0.022, 0.02, 0.028) * s, Vector3(0.0, 0.17, 0.052) * s)
	_add_box(st, Vector3(0.022, 0.02, 0.02) * s, Vector3(0.0, 0.215, 0.048) * s)

	var tip := SphereMesh.new()
	tip.radius = 0.016 * s
	tip.height = 0.032 * s
	tip.radial_segments = 8
	tip.rings = 4
	st.append_from(tip, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.232, 0.0) * s))

	return st.commit()


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
		var angle: float = lerpf(-1.0, 1.0, float(i) / 6.0)
		var basis := Basis(Vector3.UP, angle)
		var center: Vector3 = hinge + basis * (Vector3(0.0, 0.0, 0.045) * s) + Vector3(0.0, 0.024, 0.0) * s
		_add_box(st, Vector3(0.008, 0.012, 0.075) * s, center, basis)

	_add_box(st, Vector3(0.05, 0.012, 0.022) * s, hinge + Vector3(0.0, 0.006, -0.004) * s)
	return st.commit()


static func _add_box(st: SurfaceTool, size: Vector3, pos: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var box := BoxMesh.new()
	box.size = size
	st.append_from(box, 0, Transform3D(basis, pos))
