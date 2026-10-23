extends Area3D

# Identificador interno del objeto.
@export var item_id: String = "cube"

# Nombre que mostraremos al jugador.
@export var display_name: String = "Cubo"


func _ready() -> void:
	# Registramos este nodo como objeto recogible.
	add_to_group("pickups")
