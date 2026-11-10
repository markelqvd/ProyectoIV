
extends CharacterBody3D

# Configuración del movimiento.
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var acceleration: float = 20.0
@export var deceleration: float = 30.0
@export var mouse_sensitivity: float = 0.01

# Gravedad.
var gravity: float = 9.8

# Capacidad del inventario.
const INVENTORY_CAPACITY: int = 3

const KeyMesh = preload("res://scenes/Key/key_mesh.gd")
const Items = preload("res://scenes/Items/items.gd")
const GameUI = preload("res://scenes/Game/game_ui.gd")

## Agacharse (Shift): altura de la cápsula y de la cabeza, y velocidad.
@export var crouch_height: float = 1.1
@export var crouch_head_y: float = 0.95
@export var crouch_speed_multiplier: float = 0.45
@export var crouch_transition_speed: float = 8.0
var _crouch_t: float = 0.0
var _stand_height: float = 1.8
var _stand_head_y: float = 1.6
var _capsule: CapsuleShape3D
@onready var _body_shape: CollisionShape3D = $CollisionShape3D

## Segundos entre pasos al caminar.
@export var step_interval: float = 0.48
var _step_timer: float = 0.0

const PICKUP_SCENES: Dictionary = {
	"key": preload("res://scenes/Key/pickup_key.tscn"),
	"concha": preload("res://scenes/Items/pickup_concha.tscn"),
	"llave_portal": preload("res://scenes/Items/pickup_llave_portal.tscn"),
	"cube": preload("res://scenes/Pickup/pickup_cube.tscn"),
	"sphere": preload("res://scenes/Pickup/pickup_sphere.tscn"),
	"cylinder": preload("res://scenes/Pickup/pickup_cylinder.tscn")
}

# Cada objeto ocupa su propio hueco.
var inventory: Array[Dictionary] = []

# Índice del hueco seleccionado: 0, 1 o 2.
var selected_slot: int = 0

# Referencias a los nodos de la escena.
@onready var head: Node3D = $Head
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var place_ray: RayCast3D = $Head/Camera3D/PlaceRay
@onready var held_item: MeshInstance3D = $Head/Camera3D/HeldItem
@onready var hotbar: CanvasLayer = $Hotbar
@onready var hand: Node3D = $Head/Camera3D/HandViewmodel

const Crosshair = preload("res://scenes/Main/crosshair.gd")
var _crosshair: Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Mostrar el inventario inicial y ocultar la mano vacía.
	refresh_inventory_ui()
	add_to_group("player")

	# Cruz en el centro de la pantalla, por encima del filtro de píxeles.
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_crosshair = Crosshair.new()
	layer.add_child(_crosshair)

	# Agacharse: copia propia de la cápsula para poder cambiar su altura.
	_ensure_crouch_action()
	_capsule = (_body_shape.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	_body_shape.shape = _capsule
	_stand_height = _capsule.height
	_stand_head_y = head.position.y

	# Interfaz de notas y subtítulos (se crea una sola vez por escena).
	_ensure_game_ui.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	# Mientras lees una nota no se mira ni se usa el inventario.
	if _ui_busy():
		return

	# Mirar alrededor con el ratón.
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)
			head.rotate_x(-event.relative.y * mouse_sensitivity)

			head.rotation.x = clamp(
				head.rotation.x,
				deg_to_rad(-85.0),
				deg_to_rad(85.0)
			)

	# ESC libera el ratón.
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Detectar el uso de la rueda del ratón.
	elif event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				select_slot(selected_slot - 1)

			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				select_slot(selected_slot + 1)

			# Un clic izquierdo vuelve a capturar el ratón.
			elif event.button_index == MOUSE_BUTTON_LEFT:
				if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

			elif event.button_index == MOUSE_BUTTON_RIGHT:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					try_place_item()


func _physics_process(delta: float) -> void:
	# Con una nota abierta (o en el final), el personaje se queda quieto.
	if _ui_busy():
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	# Seleccionar los huecos mediante las teclas numéricas.
	if Input.is_action_just_pressed("hotbar_1"):
		select_slot(0)

	if Input.is_action_just_pressed("hotbar_2"):
		select_slot(1)

	if Input.is_action_just_pressed("hotbar_3"):
		select_slot(2)

	_update_crosshair()

	# Recoger el objeto al pulsar E.
	if Input.is_action_just_pressed("interact"):
		try_interact()

	# Aplicar gravedad.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Saltar.
	if Input.is_action_just_pressed("jump") and is_on_floor() and _crouch_t < 0.1:
		velocity.y = jump_velocity

	# Leer las teclas de movimiento.
	var input_dir: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
        "move_back"
	)

	# Convertir la entrada en una dirección 3D.
	var direction: Vector3 = (
		transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	).normalized()

	# Aplicar el movimiento horizontal.
	_update_crouch(delta)
	var move_speed: float = speed * lerpf(1.0, crouch_speed_multiplier, _crouch_t)
	var target_velocity_x: float = direction.x * move_speed
	var target_velocity_z: float = direction.z * move_speed

	var current_rate: float = acceleration

	if direction.length() == 0.0:
		current_rate = deceleration

	velocity.x = move_toward(velocity.x, target_velocity_x, current_rate * delta)

	velocity.z = move_toward(velocity.z, target_velocity_z, current_rate * delta)

	# Mover al jugador respetando las colisiones.
	move_and_slide()

	# Pasos.
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 1.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = step_interval
			_sfx("step", Vector3.INF, randf_range(0.85, 1.1))
	else:
		_step_timer = 0.1


func select_slot(slot_index: int) -> void:
	# Mantener la selección dentro de los tres huecos.
	selected_slot = wrapi(slot_index, 0, INVENTORY_CAPACITY)

	# Actualizar la interfaz y el objeto que llevamos en la mano.
	refresh_inventory_ui()


func refresh_inventory_ui() -> void:
	# Llamar al método update_hotbar() del script de la interfaz.
	hotbar.call("update_hotbar", inventory, selected_slot)

	# Actualizar el modelo 3D que aparece delante de la cámara.
	update_held_item()


func update_held_item() -> void:
	# Si el hueco seleccionado está vacío, ocultar el modelo.
	if selected_slot >= inventory.size():
		held_item.mesh = null
		held_item.material_override = null
		held_item.visible = false
		hand.call("release")
		return

	var item_id: String = str(inventory[selected_slot].get("id", ""))

	var held_mesh: Mesh = null
	var item_color: Color = Color.WHITE

	# Cómo la agarra la mano: "wrap" rodea el objeto, "pinch" lo pinza.
	held_item.set_meta("grip_style", "wrap")

	# Crear la malla adecuada para el objeto seleccionado.
	match item_id:
		"cube":
			var box_mesh := BoxMesh.new()
			box_mesh.size = Vector3(0.28, 0.28, 0.28)
			held_mesh = box_mesh
			item_color = Color(0.72, 0.43, 0.20)

		"sphere":
			var sphere_mesh := SphereMesh.new()
			sphere_mesh.radius = 0.17
			sphere_mesh.height = 0.34
			held_mesh = sphere_mesh
			item_color = Color(0.85, 0.20, 0.22)

		"cylinder":
			var cylinder_mesh := CylinderMesh.new()
			cylinder_mesh.top_radius = 0.14
			cylinder_mesh.bottom_radius = 0.14
			cylinder_mesh.height = 0.34
			held_mesh = cylinder_mesh
			item_color = Color(0.20, 0.45, 0.90)

		"key", "llave_portal", "concha":
			held_mesh = Items.build_mesh(item_id, Items.held_scale(item_id))
			held_item.set_meta("grip_style", Items.grip_style(item_id))

		_:
			held_item.mesh = null
			held_item.visible = false
			hand.call("release")
			return

	# Asignar la malla y su color.
	held_item.mesh = held_mesh

	var material: Material
	if Items.has_item(item_id):
		material = Items.make_material(item_id)
	else:
		var basic := StandardMaterial3D.new()
		basic.albedo_color = item_color
		material = basic
	held_item.material_override = material

	held_item.visible = true

	# La mano coloca el objeto en la palma y cierra los dedos a su alrededor.
	hand.call("grab", held_item)


func try_pick_up() -> void:
	# Actualizar el rayo antes de consultar su resultado.
	interact_ray.force_raycast_update()

	var target: Node = null
	if interact_ray.is_colliding():
		target = interact_ray.get_collider() as Node

	# Si el rayo choca con otra cosa (un mueble, una silla...), buscar un objeto
	# recogible justo en la línea de mira, por si está pegado o metido en un cajón.
	if target == null or not target.is_in_group("pickups") or not (target as Node3D).is_visible_in_tree():
		target = _find_pickup_on_aim()

	if target == null:
		return

	# Comprobar si quedan huecos.
	if inventory.size() >= INVENTORY_CAPACITY:
		_subtitle("No puedes llevar más cosas. Deja algo con el botón derecho.")
		return

	# Leer los datos del objeto recogido.
	var item_id: String = str(target.get("item_id"))
	var display_name: String = str(target.get("display_name"))

	# Añadir una entrada independiente al inventario.
	inventory.append({
		"id": item_id,
		"name": display_name
	})

	print("Recogido: ", display_name)
	print("Inventario: ", inventory)
	print("Huecos ocupados: ", inventory.size(), "/", INVENTORY_CAPACITY)

	# Actualizar la barra y la mano.
	refresh_inventory_ui()

	# Eliminar el objeto original del escenario.
	target.queue_free()
	_sfx("pickup")
	var story: Node = get_tree().get_first_node_in_group("story")
	if story:
		story.call("event", "pick_" + item_id)

func try_place_item() -> void:
	# Comprobar que tenemos objetos en el inventario.
	if inventory.is_empty():
		print("No tienes objetos para colocar.")
		return

	# Comprobar que el hueco seleccionado contiene un objeto.
	if selected_slot >= inventory.size():
		print("El hueco seleccionado está vacío.")
		return

	# Actualizar el rayo y comprobar si detecta una superficie.
	place_ray.force_raycast_update()

	if not place_ray.is_colliding():
		print("Apunta a una superficie para colocar el objeto.")
		return

	# Obtener el punto y la orientación de la superficie detectada.
	var surface_point: Vector3 = place_ray.get_collision_point()
	var surface_normal: Vector3 = place_ray.get_collision_normal()

	# En esta primera versión colocaremos objetos sobre superficies
	# aproximadamente horizontales, como el suelo.
	if surface_normal.dot(Vector3.UP) < 0.7:
		print("Apunta a una superficie horizontal.")
		return

	# Evitar colocar el objeto demasiado cerca del jugador.
	var horizontal_distance: float = Vector2(
		surface_point.x - global_position.x,
		surface_point.z - global_position.z
	).length()

	if horizontal_distance < 0.75:
		print("Apunta un poco más lejos de tu personaje.")
		return

	# Consultar qué objeto tenemos seleccionado.
	var item_data: Dictionary = inventory[selected_slot]
	var item_id: String = str(item_data.get("id", ""))

	# Obtener la escena correspondiente.
	var pickup_scene: PackedScene = PICKUP_SCENES.get(item_id) as PackedScene

	if pickup_scene == null:
		print("No se ha encontrado la escena del objeto.")
		return

	# Crear una instancia del objeto.
	var placed_item: Node3D = pickup_scene.instantiate() as Node3D

	if placed_item == null:
		print("No se ha podido crear el objeto.")
		return

	# Añadirlo al escenario.
	get_parent().add_child(placed_item)

	# Ajustar la altura para que repose sobre el suelo.
	var height_offset: float = 0.3

	match item_id:
		"cube":
			height_offset = 0.25
		"sphere":
			height_offset = 0.3
		"cylinder":
			height_offset = 0.3
		"key", "llave_portal":
			height_offset = 0.02
		"concha":
			height_offset = 0.01

	placed_item.global_position = Vector3(
		surface_point.x,
		surface_point.y + height_offset,
		surface_point.z
	)

	# Retirar el objeto del inventario y actualizar la interfaz.
	inventory.remove_at(selected_slot)
	refresh_inventory_ui()

	print("Objeto colocado: ", item_data.get("name", item_id))


## Devuelve el id del objeto que hay en la mano ("" si está vacía).
func get_selected_item_id() -> String:
	if selected_slot >= inventory.size():
		return ""
	return str(inventory[selected_slot].get("id", ""))



## La cruz se ilumina si apuntas a un objeto recogible o a algo que se puede abrir/encender.
func _update_crosshair() -> void:
	if _crosshair == null:
		return
	var targeting: bool = false
	if interact_ray.is_colliding():
		var target: Node = interact_ray.get_collider() as Node
		targeting = target != null and target.is_in_group("pickups")
	if not targeting:
		targeting = _find_pickup_on_aim() != null
	if not targeting:
		targeting = _find_on_aim("readables", 0.15) != null or _find_on_aim("receptors", 0.3) != null
	if not targeting:
		for d in get_tree().get_nodes_in_group("drawers"):
			var p: Node3D = d.get("prompt") as Node3D
			if p != null and p.visible:
				targeting = true
				break
	_crosshair.call("set_active", targeting)



## Quita un objeto del inventario (primero el de la mano, si coincide) y actualiza la mano.
func remove_item(item_id: String) -> void:
	var index: int = -1
	if get_selected_item_id() == item_id:
		index = selected_slot
	else:
		for i in inventory.size():
			if str(inventory[i].get("id", "")) == item_id:
				index = i
				break
	if index < 0:
		return
	inventory.remove_at(index)
	refresh_inventory_ui()



## Busca el objeto recogible más cercano a la línea de mira (a menos de 15 cm de ella).
func _find_pickup_on_aim() -> Node:
	var cam: Camera3D = interact_ray.get_parent() as Camera3D
	var origin: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_basis.z.normalized()
	var max_dist: float = interact_ray.target_position.length()
	var best: Node = null
	var best_along: float = INF
	for p in get_tree().get_nodes_in_group("pickups"):
		var n := p as Node3D
		if n == null or not n.is_visible_in_tree():
			continue
		var to_p: Vector3 = n.global_position - origin
		var along: float = to_p.dot(dir)
		if along < 0.0 or along > max_dist:
			continue
		var off: float = (to_p - dir * along).length()
		if off < 0.15 and along < best_along:
			best = n
			best_along = along
	return best



# ---------------------------------------------------------------------------
# Interacción con la historia: leer notas, dejar objetos, recoger
# ---------------------------------------------------------------------------

func try_interact() -> void:
	# 1) Notas, cartas y fotos.
	var readable: Node = _find_on_aim("readables", 0.15)
	if readable:
		readable.call("read")
		return
	# 2) Objetos para recoger (si hay alguno en la mira, tiene prioridad).
	if _find_pickup_on_aim() != null:
		try_pick_up()
		return
	# 3) Lugares donde dejar un objeto (la concha en la bañera).
	var receptor: Node = _find_on_aim("receptors", 0.6)
	if receptor and not bool(receptor.get("filled")):
		receptor.call("try_accept", self)
		return
	try_pick_up()


## Busca el nodo visible de un grupo más cercano a la línea de mira (a menos de `radius` metros).
func _find_on_aim(group: String, radius: float) -> Node:
	var cam: Camera3D = interact_ray.get_parent() as Camera3D
	var origin: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_basis.z.normalized()
	var max_dist: float = interact_ray.target_position.length()
	var best: Node = null
	var best_along: float = INF
	for p in get_tree().get_nodes_in_group(group):
		var n := p as Node3D
		if n == null or not n.is_visible_in_tree():
			continue
		var to_p: Vector3 = n.global_position - origin
		var along: float = to_p.dot(dir)
		if along < 0.0 or along > max_dist:
			continue
		if (to_p - dir * along).length() < radius and along < best_along:
			best = n
			best_along = along
	return best


func _ensure_game_ui() -> void:
	if get_tree().get_first_node_in_group("game_ui") == null:
		get_tree().current_scene.add_child(GameUI.new())


func _ui_busy() -> bool:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	return ui != null and bool(ui.call("is_busy"))


func _subtitle(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui:
		ui.call("subtitle", text, 2.5)
	else:
		print(text)


func _sfx(sound: String, pos: Vector3 = Vector3.INF, pitch: float = 1.0) -> void:
	var s: Node = get_tree().get_first_node_in_group("sfx")
	if s:
		s.call("play", sound, pos, pitch, -8.0 if sound == "step" else 0.0)



# ---------------------------------------------------------------------------
# Agacharse
# ---------------------------------------------------------------------------

func _ensure_crouch_action() -> void:
	if not InputMap.has_action("crouch"):
		InputMap.add_action("crouch")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("crouch", ev)


func _update_crouch(delta: float) -> void:
	var want: bool = Input.is_action_pressed("crouch")
	# No levantarse si hay algo encima (por ejemplo, debajo de una mesa).
	if not want and _crouch_t > 0.0:
		var current_h: float = _capsule.height
		var grow: float = _stand_height - current_h
		if grow > 0.01 and test_move(global_transform, Vector3(0.0, grow, 0.0)):
			want = true
	var target: float = 1.0 if want else 0.0
	var new_t: float = move_toward(_crouch_t, target, crouch_transition_speed * delta)
	if is_equal_approx(new_t, _crouch_t):
		return
	_crouch_t = new_t
	var h: float = lerpf(_stand_height, crouch_height, _crouch_t)
	_capsule.height = h
	_body_shape.position.y = h / 2.0
	head.position.y = lerpf(_stand_head_y, crouch_head_y, _crouch_t)
