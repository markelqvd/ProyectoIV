extends Node3D
## Mano en primera persona con agarre adaptativo.
##
## Al llamar a grab(objeto), la mano coloca el objeto sobre la palma y
## cierra cada dedo, falange a falange, hasta que toca la superficie del
## objeto. Funciona con cualquier MeshInstance3D: se genera una forma de
## colisión convexa a partir de su malla para detectar el contacto.

# Capa de física que solo usan los colisionadores de agarre (capa 20).
const GRIP_LAYER: int = 1 << 19

const FINGERS: Array[String] = ["Thumb", "Index", "Middle", "Ring", "Pinky"]

## Velocidad de cierre de los dedos (grados por segundo).
@export var grip_speed_deg: float = 260.0
## Velocidad con la que la mano vuelve a la pose relajada.
@export var release_speed: float = 10.0
## Radio de los dedos en unidades del modelo (antes de escalar).
@export var finger_radius: float = 0.75
## Separación entre la palma y el objeto, en unidades del modelo.
@export var palm_gap: float = 0.4
## Ángulos máximos (grados) de las tres falanges de los dedos.
@export var finger_max_deg: Vector3 = Vector3(85.0, 100.0, 75.0)
## Ángulos máximos (grados) de las tres falanges del pulgar.
@export var thumb_max_deg: Vector3 = Vector3(35.0, 60.0, 70.0)
## Pose relajada de los dedos cuando la mano está vacía.
@export var finger_idle_deg: Vector3 = Vector3(10.0, 15.0, 10.0)
## Pose relajada del pulgar cuando la mano está vacía.
@export var thumb_idle_deg: Vector3 = Vector3(0.0, 10.0, 10.0)

@export_group("Agarre en pinza (llaves y objetos planos)")
## Pose del índice: la llave se apoya en el lateral de su falange media.
@export var pinch_index_deg: Vector3 = Vector3(75.0, 90.0, 55.0)
## Pose del resto de dedos (puño cerrado).
@export var pinch_fist_deg: Vector3 = Vector3(85.0, 100.0, 75.0)
## Punto de apoyo a lo largo de la falange media del índice (0 = nudillo, 1 = siguiente articulación).
@export_range(0.0, 1.0) var pinch_along: float = 0.45
## Medio grosor del objeto pinzado, en metros.
@export var pinch_half_thickness: float = 0.006
## Velocidad con la que los dedos adoptan la pose de pinza.
@export var pose_speed: float = 12.0

@export_group("Agarre apoyado (concha)")
## Cierre máximo de los dedos y del pulgar cuando el objeto descansa en la palma.
@export var cradle_finger_max_deg: Vector3 = Vector3(45.0, 60.0, 45.0)
@export var cradle_thumb_max_deg: Vector3 = Vector3(25.0, 40.0, 45.0)

enum State { IDLE, POSING, WAITING, GRIPPING, HOLDING }

var _style: String = "wrap"

var state: State = State.IDLE
var skeleton: Skeleton3D
var held: MeshInstance3D

# Por dedo: índices de hueso, ángulos actuales (rad) y falanges bloqueadas.
var bone_ids: Dictionary = {}
var angles: Dictionary = {}
var locked: Dictionary = {}
var rest_rot: Dictionary = {}

var _wait_frames: int = 0
var _sphere := SphereShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	var found: Array[Node] = find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_error("HandGrip: no se ha encontrado ningún Skeleton3D en la mano.")
		set_physics_process(false)
		return

	skeleton = found[0] as Skeleton3D

	for finger in FINGERS:
		var ids: Array[int] = []
		for i in 3:
			var id: int = skeleton.find_bone("%s_%d" % [finger, i + 1])
			if id < 0:
				push_error("HandGrip: falta el hueso %s_%d." % [finger, i + 1])
				set_physics_process(false)
				return
			ids.append(id)
			rest_rot[id] = skeleton.get_bone_rest(id).basis.get_rotation_quaternion()
		bone_ids[finger] = ids
		angles[finger] = _idle_angles(finger)
		locked[finger] = [false, false, false]
		_apply_finger(finger)

	_query.shape = _sphere
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	_query.collision_mask = GRIP_LAYER


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

## Coloca el objeto en la palma y empieza a cerrar la mano a su alrededor.
func grab(item: MeshInstance3D) -> void:
	if skeleton == null or item == null or item.mesh == null:
		release()
		return

	held = item
	_build_grip_collider(item)

	# Estilo de agarre: "wrap" (rodear, por defecto), "pinch" (pinza pulgar-índice)
	# o "cradle" (apoyado en la palma con los dedos ahuecados, para la concha).
	_style = str(item.get_meta("grip_style", "wrap"))
	if _style == "pinch":
		_start_pinch(item)
		return

	if _style == "cradle":
		# La concha se apoya plana en la palma, con la parte abombada hacia fuera
		# y el abanico abriéndose hacia los dedos.
		item.global_basis = _cradle_basis()
	else:
		item.basis = Basis.IDENTITY
	_place_item_in_palm(item)

	# Abrir la mano antes de cerrar, para que cada objeto se agarre desde cero.
	for finger in FINGERS:
		angles[finger] = _idle_angles(finger)
		locked[finger] = [false, false, false]
		_apply_finger(finger)

	# Esperar un par de frames de física para que el colisionador esté registrado.
	_wait_frames = 2
	state = State.WAITING


## Suelta el objeto y relaja la mano.
func release() -> void:
	if held != null:
		var old: Node = held.get_node_or_null("GripCollider")
		if old != null:
			old.queue_free()
	held = null
	_style = "wrap"
	state = State.IDLE


# ---------------------------------------------------------------------------
# Bucle
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			_relax(delta)
		State.POSING:
			if not is_instance_valid(held) or not held.visible:
				release()
				return
			if _pose_step(delta):
				# Índice y puño quietos; solo el pulgar se cierra hasta tocar el objeto.
				for finger in FINGERS:
					var fixed: bool = finger != "Thumb"
					locked[finger] = [fixed, fixed, fixed]
				_wait_frames = 2
				state = State.WAITING
		State.WAITING:
			_wait_frames -= 1
			if _wait_frames <= 0:
				state = State.GRIPPING
		State.GRIPPING:
			if not is_instance_valid(held) or not held.visible:
				release()
				return
			if _close_step(deg_to_rad(grip_speed_deg) * delta):
				state = State.HOLDING
		State.HOLDING:
			pass


## Cierra un paso todos los dedos. Devuelve true cuando ya no se mueve ninguno.
func _close_step(step: float) -> bool:
	var all_done: bool = true

	for finger in FINGERS:
		var lock: Array = locked[finger]
		if lock[0] and lock[1] and lock[2]:
			continue
		all_done = false

		var prev: Vector3 = angles[finger]
		var next: Vector3 = prev
		var max_a: Vector3 = _max_angles(finger)

		for i in 3:
			if not lock[i]:
				next[i] = minf(prev[i] + step, max_a[i])

		angles[finger] = next
		_apply_finger(finger)

		# Comprobar de la base a la punta qué falange toca el objeto.
		var hit: int = _first_colliding_segment(finger)
		if hit >= 0:
			# Deshacer el paso y bloquear esa falange y las anteriores.
			angles[finger] = prev
			_apply_finger(finger)
			for i in hit + 1:
				lock[i] = true

		# Las falanges que llegan a su tope también se bloquean.
		for i in 3:
			if angles[finger][i] >= max_a[i] - 0.0001:
				lock[i] = true

	return all_done


func _relax(delta: float) -> void:
	var t: float = clampf(release_speed * delta, 0.0, 1.0)
	for finger in FINGERS:
		var target: Vector3 = _idle_angles(finger)
		angles[finger] = (angles[finger] as Vector3).lerp(target, t)
		_apply_finger(finger)


# ---------------------------------------------------------------------------
# Huesos
# ---------------------------------------------------------------------------

func _apply_finger(finger: String) -> void:
	var ids: Array = bone_ids[finger]
	var a: Vector3 = angles[finger]
	for i in 3:
		var id: int = ids[i]
		# Los huesos están orientados para que girar en +X cierre hacia la palma.
		var q: Quaternion = rest_rot[id] * Quaternion(Vector3.RIGHT, a[i])
		skeleton.set_bone_pose_rotation(id, q)


func _idle_angles(finger: String) -> Vector3:
	var deg: Vector3 = thumb_idle_deg if finger == "Thumb" else finger_idle_deg
	return Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z))


func _max_angles(finger: String) -> Vector3:
	var deg: Vector3 = thumb_max_deg if finger == "Thumb" else finger_max_deg
	if _style == "cradle":
		deg = cradle_thumb_max_deg if finger == "Thumb" else cradle_finger_max_deg
	return Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z))


func _bone_world(id: int) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(id)


func _model_scale() -> float:
	return skeleton.global_basis.get_scale().x


# ---------------------------------------------------------------------------
# Colisión
# ---------------------------------------------------------------------------

## Devuelve el índice (0, 1, 2) de la primera falange que toca el objeto, o -1.
func _first_colliding_segment(finger: String) -> int:
	var ids: Array = bone_ids[finger]
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var radius: float = finger_radius * _model_scale()
	_sphere.radius = radius

	for i in 3:
		var a: Vector3 = _bone_world(ids[i]).origin
		var b: Vector3
		if i < 2:
			b = _bone_world(ids[i + 1]).origin
		else:
			# La última falange no tiene hijo: se prolonga a lo largo de su eje Y.
			var prev_len: float = a.distance_to(_bone_world(ids[1]).origin)
			b = a + _bone_world(ids[2]).basis.y.normalized() * prev_len * 0.9

		for k in 3:
			var p: Vector3 = a.lerp(b, (k + 1) / 3.0)
			_query.transform = Transform3D(Basis(), p)
			if not space.intersect_shape(_query, 1).is_empty():
				return i
	return -1


func _build_grip_collider(item: MeshInstance3D) -> void:
	var old: Node = item.get_node_or_null("GripCollider")
	if old != null:
		old.name = "GripColliderOld"
		old.queue_free()

	var area := Area3D.new()
	area.name = "GripCollider"
	area.collision_layer = GRIP_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true

	var shape := CollisionShape3D.new()
	shape.shape = item.mesh.create_convex_shape(true, false)
	area.add_child(shape)
	item.add_child(area)


# ---------------------------------------------------------------------------
# Palma
# ---------------------------------------------------------------------------

## Centro de la palma (en coordenadas globales) y su normal hacia fuera.
func get_palm() -> Array:
	var hand_id: int = skeleton.find_bone("Hand")
	var hand: Transform3D = _bone_world(hand_id)
	var index_base: Vector3 = _bone_world((bone_ids["Index"] as Array)[0]).origin
	var pinky_base: Vector3 = _bone_world((bone_ids["Pinky"] as Array)[0]).origin

	# Punto entre la muñeca y los nudillos, más cerca de los nudillos.
	var knuckles: Vector3 = (index_base + pinky_base) * 0.5
	var center: Vector3 = hand.origin.lerp(knuckles, 0.75)
	# El eje Z de los huesos apunta hacia el lado de la palma.
	var normal: Vector3 = hand.basis.z.normalized()
	# Llevar el centro a la superficie de la palma (no al centro del hueso).
	center += normal * 1.2 * _model_scale()
	return [center, normal]


func _place_item_in_palm(item: MeshInstance3D) -> void:
	var palm: Array = get_palm()
	var center: Vector3 = palm[0]
	var normal: Vector3 = palm[1]

	# Cuánto sobresale el objeto en la dirección de la normal (según su AABB).
	var aabb: AABB = item.get_aabb()
	var half: Vector3 = aabb.size * 0.5
	var b: Basis = item.global_basis
	var extent: float = (
		absf(normal.dot(b.x)) * half.x
		+ absf(normal.dot(b.y)) * half.y
		+ absf(normal.dot(b.z)) * half.z
	)
	var aabb_center_world: Vector3 = b * aabb.get_center()

	item.global_position = (
		center + normal * (extent + palm_gap * _model_scale()) - aabb_center_world
	)


# ---------------------------------------------------------------------------
# Agarre en pinza
# ---------------------------------------------------------------------------

var _pose_targets: Dictionary = {}


func _start_pinch(item: MeshInstance3D) -> void:
	_pose_targets.clear()
	for finger in FINGERS:
		var deg: Vector3
		if finger == "Thumb":
			deg = thumb_idle_deg
		elif finger == "Index":
			deg = pinch_index_deg
		else:
			deg = pinch_fist_deg
		_pose_targets[finger] = Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z))

	# Calcular dónde va el objeto con la pose final ya aplicada,
	# y después volver a la pose actual para animar la transición.
	var current: Dictionary = angles.duplicate()
	for finger in FINGERS:
		angles[finger] = _pose_targets[finger]
		_apply_finger(finger)
	item.global_transform = _pinch_transform()
	for finger in FINGERS:
		angles[finger] = current[finger]
		locked[finger] = [true, true, true]
		_apply_finger(finger)

	state = State.POSING


## Transformación del objeto: apoyado en el lateral de la falange media del índice,
## con su eje Y apuntando hacia delante (como cuando vas a meter una llave).
func _pinch_transform() -> Transform3D:
	var idx: Array = bone_ids["Index"]
	var mid: Transform3D = _bone_world(idx[1])
	var a: Vector3 = mid.origin
	var b: Vector3 = _bone_world(idx[2]).origin
	# El eje X de los huesos del índice apunta hacia el pulgar.
	var x_axis: Vector3 = mid.basis.x.normalized()
	var hand_y: Vector3 = _bone_world(skeleton.find_bone("Hand")).basis.y.normalized()
	var y_axis: Vector3 = (hand_y - x_axis * hand_y.dot(x_axis)).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis)
	var origin: Vector3 = (
		a.lerp(b, pinch_along)
		+ x_axis * (finger_radius * _model_scale() + _pinch_half_thickness())
	)
	return Transform3D(Basis(x_axis, y_axis, z_axis), origin)


## Acerca los dedos a la pose objetivo. Devuelve true al llegar.
func _pose_step(delta: float) -> bool:
	var t: float = clampf(pose_speed * delta, 0.0, 1.0)
	var done: bool = true
	for finger in FINGERS:
		var target: Vector3 = _pose_targets[finger]
		var cur: Vector3 = (angles[finger] as Vector3).lerp(target, t)
		if cur.distance_to(target) < 0.01:
			cur = target
		else:
			done = false
		angles[finger] = cur
		_apply_finger(finger)
	return done


## Medio grosor del objeto pinzado (lo que mide en su eje X), con un mínimo.
func _pinch_half_thickness() -> float:
	if held != null and held.mesh != null:
		return maxf(pinch_half_thickness, held.get_aabb().size.x * 0.5)
	return pinch_half_thickness



## Orientación para apoyar un objeto plano en la palma (eje Y = normal de la palma, Z = hacia los dedos).
func _cradle_basis() -> Basis:
	var hand: Transform3D = _bone_world(skeleton.find_bone("Hand"))
	var n: Vector3 = hand.basis.z.normalized()
	var fwd: Vector3 = hand.basis.y.normalized()
	var z_axis: Vector3 = (fwd - n * fwd.dot(n)).normalized()
	var x_axis: Vector3 = n.cross(z_axis)
	return Basis(x_axis, n, z_axis)
