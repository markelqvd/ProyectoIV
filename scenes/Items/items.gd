class_name Items
extends RefCounted

const ALL: Dictionary = {
	"key": preload("res://scenes/Items/data/key.tres"),
	"llave_portal": preload("res://scenes/Items/data/llave_portal.tres"),
	"concha": preload("res://scenes/Items/data/concha.tres"),
}


static func find(id: String) -> ItemData:
	return ALL.get(id) as ItemData
