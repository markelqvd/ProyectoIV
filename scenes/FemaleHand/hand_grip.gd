# Echo con IA
class_name HandGrip
extends Node3D

enum State { IDLE, POSING, WAITING, GRIPPING, HOLDING }

const GRIP_LAYER: int = 1 << 19
const FINGERS: Array[String] = ["Thumb", "Index", "Middle", "Ring", "Pinky"]
const SETTLE_FRAMES: int = 2

@export var grip_speed_degrees: float = 260.0
@export var release_speed: float = 10.0
@export var finger_radius: float = 0.75
@export var palm_gap: float = 0.4
@export var finger_max_degrees: Vector3 = Vector3(85.0, 100.0, 75.0)
@export var thumb_max_degrees: Vector3 = Vector3(35.0, 60.0, 70.0)
@export var finger_idle_degrees: Vector3 = Vector3(10.0, 15.0, 10.0)
@export var thumb_idle_degrees: Vector3 = Vector3(0.0, 10.0, 10.0)
@export_group("Pinza")
@export var pinch_index_degrees: Vector3 = Vector3(75.0, 90.0, 55.0)
@export var pinch_fist_degrees: Vector3 = Vector3(85.0, 100.0, 75.0)
@export_range(0.0, 1.0) var pinch_along: float = 0.45
@export var pinch_min_half_thickness: float = 0.006
@export var pose_speed: float = 12.0
@export_group("Apoyado")
@export var cradle_finger_max_degrees: Vector3 = Vector3(45.0, 60.0, 45.0)
@export var cradle_thumb_max_degrees: Vector3 = Vector3(25.0, 40.0, 45.0)

var state: State = State.IDLE
var held: MeshInstance3D

var _skeleton: Skeleton3D
var _style: String = "wrap"
var _bones: Dictionary = {}
var _angles: Dictionary = {}
var _locked: Dictionary = {}
var _rest: Dictionary = {}
var _targets: Dictionary = {}
var _wait_frames: int = 0
var _sphere := SphereShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	var found: Array[Node] = find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_error("HandGrip: no hay Skeleton3D en la mano.")
		set_physics_process(false)
		return
	_skeleton = found[0] as Skeleton3D

	for finger in FINGERS:
		var ids: Array[int] = []
		for i in 3:
			var id: int = _skeleton.find_bone("%s_%d" % [finger, i + 1])
			if id < 0:
				push_error("HandGrip: falta el hueso %s_%d." % [finger, i + 1])
				set_physics_process(false)
				return
			ids.append(id)
			_rest[id] = _skeleton.get_bone_rest(id).basis.get_rotation_quaternion()
		_bones[finger] = ids
		_angles[finger] = _idle_angles(finger)
		_locked[finger] = [false, false, false]
		_apply(finger)

	_query.shape = _sphere
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	_query.collision_mask = GRIP_LAYER


func grab(item: MeshInstance3D) -> void:
	if _skeleton == null or item == null or item.mesh == null:
		release()
		return
	held = item
	_style = str(item.get_meta("grip_style", "wrap"))
	_build_grip_collider(item)

	if _style == "pinch":
		_start_pinch(item)
		return

	if _style == "cradle":
		item.global_basis = _cradle_basis()
	else:
		item.basis = Basis.IDENTITY
	_place_in_palm(item)
	for finger in FINGERS:
		_angles[finger] = _idle_angles(finger)
		_locked[finger] = [false, false, false]
		_apply(finger)
	_wait()


func release() -> void:
	if held:
		var collider: Node = held.get_node_or_null("GripCollider")
		if collider:
			collider.queue_free()
	held = null
	_style = "wrap"
	state = State.IDLE


func _physics_process(delta: float) -> void:
	if (state == State.POSING or state == State.GRIPPING) and (not is_instance_valid(held) or not held.visible):
		release()
		return
	match state:
		State.IDLE:
			_relax(delta)
		State.POSING:
			if _pose_step(delta):
				for finger in FINGERS:
					var fixed: bool = finger != "Thumb"
					_locked[finger] = [fixed, fixed, fixed]
				_wait()
		State.WAITING:
			_wait_frames -= 1
			if _wait_frames <= 0:
				state = State.GRIPPING
		State.GRIPPING:
			if _close_step(deg_to_rad(grip_speed_degrees) * delta):
				state = State.HOLDING


func _wait() -> void:
	_wait_frames = SETTLE_FRAMES
	state = State.WAITING


func _close_step(step: float) -> bool:
	var done: bool = true
	for finger in FINGERS:
		var locks: Array = _locked[finger]
		if locks[0] and locks[1] and locks[2]:
			continue
		done = false
		var previous: Vector3 = _angles[finger]
		var limits: Vector3 = _max_angles(finger)
		var next: Vector3 = previous
		for i in 3:
			if not locks[i]:
				next[i] = minf(previous[i] + step, limits[i])
		_angles[finger] = next
		_apply(finger)

		var hit: int = _first_touching_segment(finger)
		if hit >= 0:
			_angles[finger] = previous
			_apply(finger)
			for i in hit + 1:
				locks[i] = true
		for i in 3:
			if _angles[finger][i] >= limits[i] - 0.0001:
				locks[i] = true
	return done


func _relax(delta: float) -> void:
	var t: float = clampf(release_speed * delta, 0.0, 1.0)
	for finger in FINGERS:
		_angles[finger] = (_angles[finger] as Vector3).lerp(_idle_angles(finger), t)
		_apply(finger)


func _pose_step(delta: float) -> bool:
	var t: float = clampf(pose_speed * delta, 0.0, 1.0)
	var done: bool = true
	for finger in FINGERS:
		var target: Vector3 = _targets[finger]
		var current: Vector3 = (_angles[finger] as Vector3).lerp(target, t)
		if current.distance_to(target) < 0.01:
			current = target
		else:
			done = false
		_angles[finger] = current
		_apply(finger)
	return done


func _apply(finger: String) -> void:
	var ids: Array = _bones[finger]
	var a: Vector3 = _angles[finger]
	for i in 3:
		_skeleton.set_bone_pose_rotation(ids[i], _rest[ids[i]] * Quaternion(Vector3.RIGHT, a[i]))


func _idle_angles(finger: String) -> Vector3:
	return _to_radians(thumb_idle_degrees if finger == "Thumb" else finger_idle_degrees)


func _max_angles(finger: String) -> Vector3:
	if _style == "cradle":
		return _to_radians(cradle_thumb_max_degrees if finger == "Thumb" else cradle_finger_max_degrees)
	return _to_radians(thumb_max_degrees if finger == "Thumb" else finger_max_degrees)


func _to_radians(degrees: Vector3) -> Vector3:
	return Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))


func _bone(id: int) -> Transform3D:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(id)


func _scale() -> float:
	return _skeleton.global_basis.get_scale().x


func _first_touching_segment(finger: String) -> int:
	var ids: Array = _bones[finger]
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	_sphere.radius = finger_radius * _scale()
	for i in 3:
		var start: Vector3 = _bone(ids[i]).origin
		var end: Vector3
		if i < 2:
			end = _bone(ids[i + 1]).origin
		else:
			var length: float = start.distance_to(_bone(ids[1]).origin)
			end = start + _bone(ids[2]).basis.y.normalized() * length * 0.9
		for k in 3:
			_query.transform = Transform3D(Basis(), start.lerp(end, (k + 1) / 3.0))
			if not space.intersect_shape(_query, 1).is_empty():
				return i
	return -1


func _build_grip_collider(item: MeshInstance3D) -> void:
	var old: Node = item.get_node_or_null("GripCollider")
	if old:
		old.name = "GripColliderOld"
		old.queue_free()
	var area := Area3D.new()
	area.name = "GripCollider"
	area.collision_layer = GRIP_LAYER
	area.collision_mask = 0
	area.monitoring = false
	var shape := CollisionShape3D.new()
	shape.shape = item.mesh.create_convex_shape(true, false)
	area.add_child(shape)
	item.add_child(area)


func _palm() -> Array:
	var hand: Transform3D = _bone(_skeleton.find_bone("Hand"))
	var knuckles: Vector3 = (_bone(_bones["Index"][0]).origin + _bone(_bones["Pinky"][0]).origin) * 0.5
	var normal: Vector3 = hand.basis.z.normalized()
	var center: Vector3 = hand.origin.lerp(knuckles, 0.75) + normal * 1.2 * _scale()
	return [center, normal]


func _place_in_palm(item: MeshInstance3D) -> void:
	var palm: Array = _palm()
	var normal: Vector3 = palm[1]
	var bounds: AABB = item.get_aabb()
	var half: Vector3 = bounds.size * 0.5
	var b: Basis = item.global_basis
	var extent: float = absf(normal.dot(b.x)) * half.x + absf(normal.dot(b.y)) * half.y + absf(normal.dot(b.z)) * half.z
	item.global_position = palm[0] + normal * (extent + palm_gap * _scale()) - b * bounds.get_center()


func _start_pinch(item: MeshInstance3D) -> void:
	for finger in FINGERS:
		var degrees: Vector3 = thumb_idle_degrees
		if finger == "Index":
			degrees = pinch_index_degrees
		elif finger != "Thumb":
			degrees = pinch_fist_degrees
		_targets[finger] = _to_radians(degrees)

	var current: Dictionary = _angles.duplicate()
	for finger in FINGERS:
		_angles[finger] = _targets[finger]
		_apply(finger)
	item.global_transform = _pinch_transform()
	for finger in FINGERS:
		_angles[finger] = current[finger]
		_locked[finger] = [true, true, true]
		_apply(finger)
	state = State.POSING


func _pinch_transform() -> Transform3D:
	var middle: Transform3D = _bone(_bones["Index"][1])
	var tip: Vector3 = _bone(_bones["Index"][2]).origin
	var x_axis: Vector3 = middle.basis.x.normalized()
	var forward: Vector3 = _bone(_skeleton.find_bone("Hand")).basis.y.normalized()
	var y_axis: Vector3 = (forward - x_axis * forward.dot(x_axis)).normalized()
	var half_thickness: float = maxf(pinch_min_half_thickness, held.get_aabb().size.x * 0.5)
	var origin: Vector3 = middle.origin.lerp(tip, pinch_along) + x_axis * (finger_radius * _scale() + half_thickness)
	return Transform3D(Basis(x_axis, y_axis, x_axis.cross(y_axis)), origin)


func _cradle_basis() -> Basis:
	var hand: Transform3D = _bone(_skeleton.find_bone("Hand"))
	var normal: Vector3 = hand.basis.z.normalized()
	var forward: Vector3 = hand.basis.y.normalized()
	var z_axis: Vector3 = (forward - normal * forward.dot(normal)).normalized()
	return Basis(normal.cross(z_axis), normal, z_axis)
