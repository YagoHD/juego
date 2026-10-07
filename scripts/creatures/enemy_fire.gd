extends Node3D
class_name EnemyFire
## Hoguera de un campamento enemigo (sinergia 10). De noche, los que están junto al fuego ven peor
## lo que queda a oscuras (fuera de LIGHT_RADIUS). El jugador puede apagarla (clic derecho mirándola
## de cerca): todo el campamento se despierta y busca alrededor. Vuelve a arder al día siguiente.

const LIGHT_RADIUS := 7.0
const REACH := 3.0

var camp_id := ""
var lit := true
var out_day := -1
var _flame: MeshInstance3D

signal extinguished(fire: EnemyFire)


func _ready() -> void:
	add_to_group("enemy_fires")
	_flame = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.4, 0.45)
	_flame.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.55, 0.15)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.45, 0.1)
	_flame.material_override = material
	_flame.position = Vector3(0, 0.45, 0)
	add_child(_flame)
	_flame.visible = lit


## La hoguera que mira el jugador desde 'eye' hacia 'forward' (o null).
static func looked_at(tree: SceneTree, eye: Vector3, forward: Vector3) -> EnemyFire:
	for node in tree.get_nodes_in_group("enemy_fires"):
		var fire := node as EnemyFire
		if fire == null or not fire.lit:
			continue
		var to := fire.global_position + Vector3.UP * 0.4 - eye
		if to.length() <= REACH and forward.angle_to(to) < deg_to_rad(25.0):
			return fire
	return null


func put_out(day: int) -> void:
	if not lit:
		return
	lit = false
	out_day = day
	_flame.visible = false
	extinguished.emit(self)


## Al cambiar de día vuelve a arder.
func relight_if(day: int) -> void:
	if not lit and day > out_day:
		lit = true
		_flame.visible = true


## ¿Está 'point' a oscuras para quien mira desde el fuego? (Solo de noche y con la hoguera encendida.)
func in_dark(point: Vector3) -> bool:
	return lit and Vector2(point.x - global_position.x, point.z - global_position.z).length() > LIGHT_RADIUS
