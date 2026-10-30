
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

const PICKUP_SCENES: Dictionary = {
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


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Mostrar el inventario inicial y ocultar la mano vacía.
	refresh_inventory_ui()


func _unhandled_input(event: InputEvent) -> void:
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
	# Seleccionar los huecos mediante las teclas numéricas.
	if Input.is_action_just_pressed("hotbar_1"):
		select_slot(0)

	if Input.is_action_just_pressed("hotbar_2"):
		select_slot(1)

	if Input.is_action_just_pressed("hotbar_3"):
		select_slot(2)

	# Recoger el objeto al pulsar E.
	if Input.is_action_just_pressed("interact"):
		try_pick_up()

	# Aplicar gravedad.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Saltar.
	if Input.is_action_just_pressed("jump") and is_on_floor():
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
	var target_velocity_x: float = direction.x * speed
	var target_velocity_z: float = direction.z * speed

	var current_rate: float = acceleration

	if direction.length() == 0.0:
		current_rate = deceleration

	velocity.x = move_toward(velocity.x, target_velocity_x, current_rate * delta)

	velocity.z = move_toward(velocity.z, target_velocity_z, current_rate * delta)

	# Mover al jugador respetando las colisiones.
	move_and_slide()


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
		return

	var item_id: String = str(inventory[selected_slot].get("id", ""))

	var held_mesh: Mesh = null
	var item_color: Color = Color.WHITE

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

		_:
			held_item.mesh = null
			held_item.visible = false
			return

	# Asignar la malla y su color.
	held_item.mesh = held_mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = item_color
	held_item.material_override = material

	held_item.visible = true


func try_pick_up() -> void:
	# Actualizar el rayo antes de consultar su resultado.
	interact_ray.force_raycast_update()

	if not interact_ray.is_colliding():
		print("No hay ningún objeto a tu alcance.")
		return

	var target: Node = interact_ray.get_collider() as Node

	if target == null:
		return

	# Comprobar que el objeto pertenezca al grupo correcto.
	if not target.is_in_group("pickups"):
		print("Eso no es un objeto recogible.")
		return

	# Comprobar si quedan huecos.
	if inventory.size() >= INVENTORY_CAPACITY:
		print("Inventario lleno: 3/3.")
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

	placed_item.global_position = Vector3(
		surface_point.x,
		surface_point.y + height_offset,
		surface_point.z
	)

	# Retirar el objeto del inventario y actualizar la interfaz.
	inventory.remove_at(selected_slot)
	refresh_inventory_ui()

	print("Objeto colocado: ", item_data.get("name", item_id))
