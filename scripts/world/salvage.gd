extends Node
class_name Salvage
## Restos que se desmontan a golpes (tablas, cajas, barriles, troncos, telas del naufragio):
## modelos de cubitos (MicroVoxels) con choque. Cada golpe con clic izquierdo los sacude; al último
## se deshacen y sueltan su material. Los que ya se han desmontado se guardan para no volver a salir.

const REACH := 3.2

## Tipos: [golpes, material que dan [[id, cantidad]...], sonido].
const KINDS := {
	"plank": [2, [["planks", 1]], "romper_madera"],
	"planks": [3, [["planks", 3]], "romper_madera"],
	"crate": [4, [["planks", 2], ["sticks", 2]], "romper_madera"],
	"barrel": [4, [["planks", 2], ["sticks", 1]], "romper_madera"],
	"log": [5, [["driftwood", 1], ["bark", 2]], "romper_madera"],
	"cloth": [1, [["cloth", 2]], "romper_tela"],
}

var player: Player
var _pieces := {}        # StaticBody3D -> {"id", "kind", "node", "hits"}
var _removed := {}       # id -> true
var _save_path := ""


func load_from(path: String) -> void:
	_save_path = path
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Array:
		for id: Variant in data:
			_removed[str(id)] = true


func save() -> void:
	if _save_path == "":
		return
	var f := FileAccess.open(_save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_removed.keys()))


## Coloca un resto (si no se desmontó ya). id: nombre único y fijo.
func add(id: String, kind: String, cells: Dictionary, pos: Vector3, yaw: float) -> void:
	if _removed.has(id):
		return
	var size := Main.VOXEL_SIZE / MicroVoxels.RES
	var node := MicroVoxels.make_node(cells, size)
	node.position = pos
	node.rotation.y = yaw
	add_child(node)
	for child in node.get_children():
		if child is StaticBody3D:
			_pieces[child] = {"id": id, "kind": kind, "node": node, "hits": 0}


## Clic izquierdo: golpea el resto que hay delante. Devuelve true si había uno.
func hit(from: Vector3, dir: Vector3) -> bool:
	var space := get_viewport().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * REACH)
	if player != null:
		query.exclude = [player.get_rid()]
	var res := space.intersect_ray(query)
	if res.is_empty() or not _pieces.has(res["collider"]):
		return false
	var piece: Dictionary = _pieces[res["collider"]]
	var info: Array = KINDS[piece["kind"]]
	var power := 2 if player != null and player.held_item() in ["stone_axe", "stone_knife"] else 1
	piece["hits"] = int(piece["hits"]) + power
	Sfx.play(info[2], res["position"])
	var node: Node3D = piece["node"]
	if int(piece["hits"]) < int(info[0]):
		var t := create_tween()
		var base := node.position
		t.tween_property(node, "position", base + dir.slide(Vector3.UP).normalized() * 0.05, 0.05)
		t.tween_property(node, "position", base, 0.08)
		return true
	for drop: Array in info[1]:
		ItemDrop.spawn(get_parent(), node.global_position + Vector3.UP * 0.4, drop[0], drop[1])
	_removed[piece["id"]] = true
	_pieces.erase(res["collider"])
	node.queue_free()
	save()
	return true
