extends Node3D
class_name ChestVisual
## Cofre abierto: mientras el jugador mira dentro, el bloque pasa a ser la caja sin tapa
## (CHEST_OPEN), la tapa se levanta girando sobre su bisagra de atrás y dentro se ve un montón
## con lo que guarda (un objeto pequeño por hueco ocupado, más alto cuanto más lleva). Al cerrar,
## la tapa baja y vuelve a ser el bloque de cofre.

const OPEN_ANGLE := 1.9    # radianes (unos 110 grados)
const TIME := 0.3          # segundos que tarda en abrirse o cerrarse
const LID_Y := 10.0 / 16.0 # altura de la bisagra (donde empieza la tapa)

var _terrain: VoxelTerrain
var _cell := Vector3i.ZERO
var _hinge: Node3D
var _closing := false


## Abre el cofre de 'cell' y enseña su contenido.
static func open_at(parent: Node, terrain: VoxelTerrain, cell: Vector3i, contents: Inventory) -> ChestVisual:
	var v := ChestVisual.new()
	v._terrain = terrain
	v._cell = cell
	parent.add_child(v)
	v._build(contents)
	return v


func _build(contents: Inventory) -> void:
	var vs := _terrain.scale.x
	global_position = _terrain.to_global(Vector3(_cell))
	var tool := WorldVoxels.tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	tool.set_voxel(_cell, IslandGenerator.CHEST_OPEN)
	# Tapa, con la bisagra atrás (+Z) arriba de la caja.
	_hinge = Node3D.new()
	_hinge.position = Vector3(0.5, LID_Y, 15.0 / 16.0) * vs
	add_child(_hinge)
	var lid := MeshInstance3D.new()
	lid.mesh = PrefabLibrary.centered_mesh(PrefabLibrary.first_id("chest_lid"), vs)
	lid.position = Vector3(0.5, 0.5, 0.5) * vs - _hinge.position
	_hinge.add_child(lid)
	create_tween().tween_property(_hinge, "rotation:x", OPEN_ANGLE, TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_build_pile(contents, vs)


## El montón de dentro: hasta 9 objetos en una cuadrícula de 3x3 sobre el fondo; cada uno, en
## capas según cuántos hay de él.
func _build_pile(contents: Inventory, vs: float) -> void:
	var shown := 0
	for i in contents.size():
		var stack := contents.get_slot(i)
		if stack.is_empty():
			continue
		var id: String = stack["id"]
		var layers := clampi(ceili(float(stack["count"]) / 16.0), 1, 3)
		var spot := Vector3(0.28 + (shown % 3) * 0.22, 0.12, 0.28 + (shown / 3) * 0.22) * vs
		for k in layers:
			var item := MeshInstance3D.new()
			item.mesh = ItemMesh.make(id, vs * 0.2)
			item.material_override = ItemMesh.make_material(id)
			item.position = spot + Vector3(0, k * vs * 0.09, 0)
			item.rotation = Vector3(-PI * 0.5 if ItemDB.block_of(id) < 0 else 0.0, randf() * TAU, 0)
			add_child(item)
		shown += 1
		if shown >= 9:
			break


## Se cierra: la tapa baja y vuelve a ser el bloque de cofre (si nadie lo ha roto).
func close() -> void:
	if _closing:
		return
	_closing = true
	var tween := create_tween()
	tween.tween_property(_hinge, "rotation:x", 0.0, TIME * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_finish)


func _finish() -> void:
	var tool := WorldVoxels.tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	if tool.get_voxel(_cell) == IslandGenerator.CHEST_OPEN:
		tool.set_voxel(_cell, IslandGenerator.CHEST)
	Sfx.play("colocar", global_position, -10.0, 0.1)
	queue_free()
