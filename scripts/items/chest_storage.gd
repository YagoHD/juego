extends RefCounted
class_name ChestStorage
## Contenido de todos los cofres del mundo, por posición (en voxels). Un cofre que nunca se ha
## abierto no tiene entrada: al abrirlo por primera vez se crea vacío o, si es un cofre de una
## estructura (el naufragio...), con su botín. Se guarda en un archivo JSON junto al mundo.

const SIZE := 27  # huecos de un cofre (3 filas de 9)

var _chests := {}  # "x,y,z" -> Inventory


static func key_of(cell: Vector3i) -> String:
	return "%d,%d,%d" % [cell.x, cell.y, cell.z]


## Inventario del cofre en 'cell' (lo crea si no existe, con el botín inicial si lo hay).
func get_or_create(cell: Vector3i) -> Inventory:
	var key := key_of(cell)
	if not _chests.has(key):
		var inv := Inventory.new(SIZE)
		for stack in Structures.loot_for_chest(cell):
			inv.add(stack["id"], int(stack["count"]))
		_chests[key] = inv
	return _chests[key]


## Quita el cofre (al romperlo) y devuelve su contenido para soltarlo al suelo.
func remove(cell: Vector3i) -> Inventory:
	var inv := get_or_create(cell)  # aunque no se abriera nunca, suelta su botín
	_chests.erase(key_of(cell))
	return inv


func save_to(path: String) -> void:
	var data := {}
	for key in _chests:
		data[key] = (_chests[key] as Inventory).to_data()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


func load_from(path: String) -> void:
	_chests.clear()
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return
	for key in data:
		var inv := Inventory.new(SIZE)
		if data[key] is Array:
			inv.from_data(data[key])
		_chests[key] = inv
