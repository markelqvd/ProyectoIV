class_name Player
extends CharacterBody3D

const INVENTORY_CAPACITY: int = 3
const GRAVITY: float = 9.8
const LOOK_LIMIT_DEGREES: float = 85.0
const MIN_PLACE_DISTANCE: float = 0.75
const LINE_OF_SIGHT_TOLERANCE: float = 0.45

@export_group("Movimiento")
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var acceleration: float = 20.0
@export var deceleration: float = 30.0
@export var mouse_sensitivity: float = 0.01
@export var step_interval: float = 0.48
@export_group("Agacharse")
@export var crouch_height: float = 1.1
@export var crouch_head_y: float = 0.95
@export var crouch_speed_multiplier: float = 0.45
@export var crouch_transition_speed: float = 8.0

var inventory: Array[String] = []
var selected_slot: int = 0

var _crouch_amount: float = 0.0
var _stand_height: float = 1.8
var _stand_head_y: float = 1.6
var _capsule: CapsuleShape3D
var _step_timer: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var place_ray: RayCast3D = $Head/Camera3D/PlaceRay
@onready var held_item: MeshInstance3D = $Head/Camera3D/HeldItem
@onready var hand: HandGrip = $Head/Camera3D/HandViewmodel
@onready var hotbar: Hotbar = $Hotbar
@onready var crosshair: Crosshair = $Overlay/Crosshair
@onready var body_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	Game.player = self
	_add_crouch_action()
	_capsule = body_shape.shape.duplicate() as CapsuleShape3D
	body_shape.shape = _capsule
	_stand_height = _capsule.height
	_stand_head_y = head.position.y
	_refresh_inventory()


func _exit_tree() -> void:
	if Game.player == self:
		Game.player = null


func _unhandled_input(event: InputEvent) -> void:
	if UI.is_busy():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-LOOK_LIMIT_DEGREES), deg_to_rad(LOOK_LIMIT_DEGREES))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				select_slot(selected_slot - 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				select_slot(selected_slot + 1)
			MOUSE_BUTTON_RIGHT:
				try_place_item()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if UI.is_busy():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	for i in INVENTORY_CAPACITY:
		if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
			select_slot(i)

	crosshair.set_active(_aimed_interaction() != null or _any_openable_targeted())
	if Input.is_action_just_pressed("interact"):
		interact()

	if Input.is_action_just_pressed("jump") and is_on_floor() and _crouch_amount < 0.1:
		velocity.y = jump_velocity

	_update_crouch(delta)
	_move(delta)
	_update_steps(delta)


func select_slot(index: int) -> void:
	selected_slot = wrapi(index, 0, INVENTORY_CAPACITY)
	_refresh_inventory()


func get_selected_item_id() -> String:
	return inventory[selected_slot] if selected_slot < inventory.size() else ""


func remove_item(item_id: String) -> void:
	var index: int = selected_slot if get_selected_item_id() == item_id else inventory.find(item_id)
	if index >= 0:
		inventory.remove_at(index)
		_refresh_inventory()


func interact() -> void:
	var target: Node = _aimed_interaction()
	if target == null:
		return
	if target.is_in_group("readables"):
		target.call("read")
	elif target is Pickup:
		_pick_up(target)
	elif target.is_in_group("receptors"):
		target.call("try_accept", self)


func try_place_item() -> void:
	var item_id: String = get_selected_item_id()
	if item_id == "":
		return
	place_ray.force_raycast_update()
	if not place_ray.is_colliding() or place_ray.get_collision_normal().dot(Vector3.UP) < 0.7:
		return
	var point: Vector3 = place_ray.get_collision_point()
	if Vector2(point.x - global_position.x, point.z - global_position.z).length() < MIN_PLACE_DISTANCE:
		return
	var pickup := Pickup.new()
	pickup.item_id = item_id
	get_parent().add_child(pickup)
	pickup.global_position = point + Vector3.UP * Items.find(item_id).place_height
	remove_item(item_id)


func _pick_up(pickup: Pickup) -> void:
	if inventory.size() >= INVENTORY_CAPACITY:
		UI.subtitle(Texts.SUBTITLES["inventario_lleno"], 2.5)
		return
	inventory.append(pickup.item_id)
	pickup.queue_free()
	_refresh_inventory()
	Sfx.play("pickup")
	Game.event("pick_" + pickup.item_id)


func _refresh_inventory() -> void:
	hotbar.update_hotbar(inventory, selected_slot)
	var item: ItemData = Items.find(get_selected_item_id())
	if item == null:
		held_item.mesh = null
		held_item.visible = false
		hand.release()
		return
	held_item.mesh = item.build_mesh(item.held_scale)
	held_item.material_override = item.make_material()
	held_item.set_meta("grip_style", item.grip_style)
	held_item.visible = true
	hand.grab(held_item)


func _aimed_interaction() -> Node:
	var readable: Node3D = _find_on_aim("readables", 0.15, true)
	if readable:
		return readable
	var pickup: Node3D = _find_on_aim("pickups", 0.15, true)
	if pickup:
		return pickup
	var receptor: Node3D = _find_on_aim("receptors", 0.6, false)
	if receptor and not receptor.get("filled"):
		return receptor
	return null


func _any_openable_targeted() -> bool:
	for openable in get_tree().get_nodes_in_group("openables"):
		if openable.prompt.visible:
			return true
	return false


func _find_on_aim(group: String, radius: float, needs_sight: bool) -> Node3D:
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_basis.z
	var reach: float = interact_ray.target_position.length()
	var best: Node3D = null
	var best_distance: float = INF
	for node in get_tree().get_nodes_in_group(group):
		var target := node as Node3D
		if target == null or not target.is_visible_in_tree():
			continue
		var to_target: Vector3 = target.global_position - origin
		var along: float = to_target.dot(direction)
		if along < 0.0 or along > reach or along >= best_distance:
			continue
		if (to_target - direction * along).length() > radius:
			continue
		if needs_sight and not _can_see(target):
			continue
		best = target
		best_distance = along
	return best


func _can_see(target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, target.global_position)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == target \
		or (hit["position"] as Vector3).distance_to(target.global_position) < LINE_OF_SIGHT_TOLERANCE


func _move(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var move_speed: float = speed * lerpf(1.0, crouch_speed_multiplier, _crouch_amount)
	var rate: float = acceleration if direction != Vector3.ZERO else deceleration
	velocity.x = move_toward(velocity.x, direction.x * move_speed, rate * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, rate * delta)
	move_and_slide()


func _update_steps(delta: float) -> void:
	if not is_on_floor() or Vector2(velocity.x, velocity.z).length() < 1.0:
		_step_timer = 0.1
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = step_interval
		Sfx.play("step", Vector3.INF, randf_range(0.85, 1.1), -8.0)


func _update_crouch(delta: float) -> void:
	var wants_crouch: bool = Input.is_action_pressed("crouch")
	if not wants_crouch and _crouch_amount > 0.0:
		var missing: float = _stand_height - _capsule.height
		if missing > 0.01 and test_move(global_transform, Vector3(0.0, missing, 0.0)):
			wants_crouch = true
	var target: float = 1.0 if wants_crouch else 0.0
	var amount: float = move_toward(_crouch_amount, target, crouch_transition_speed * delta)
	if is_equal_approx(amount, _crouch_amount):
		return
	_crouch_amount = amount
	_capsule.height = lerpf(_stand_height, crouch_height, amount)
	body_shape.position.y = _capsule.height / 2.0
	head.position.y = lerpf(_stand_head_y, crouch_head_y, amount)


func _add_crouch_action() -> void:
	if InputMap.has_action("crouch"):
		return
	InputMap.add_action("crouch")
	var shift := InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	InputMap.action_add_event("crouch", shift)
