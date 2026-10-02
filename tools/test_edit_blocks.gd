extends SceneTree
## Prueba de romper/colocar sobre la isla real, sin ventana.
## Uso: godot --headless --path . --script res://tools/test_edit_blocks.gd
## Mirando al suelo justo bajo los pies:
##   1. colocar NO debe funcionar (el hueco lo ocupa el propio jugador);
##   2. romper debe quitar el bloque del suelo y soltar partículas.
## Luego, mirando al frente a un bloque cercano, colocar SÍ debe funcionar.

var _main: Node
var _step := 0
var _wait := 0


func _init() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	var player: Player = _main.get("_player")
	if player == null or _main.get("_loading") or not player.is_on_ground_ready():
		return false
	_wait += 1
	if _wait < 30:
		return false  # deja que se asienten la física y la cámara
	var terrain: VoxelTerrain = _main.get("_terrain")
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE

	match _step:
		0:
			player.debug_pose(false, -1.55, 0.0, 0.0)  # mirar al suelo
			_step = 1
		1:
			var target: Dictionary = player._target()
			if target.is_empty():
				print("FALLO: no apunta a ningún bloque mirando al suelo")
				return true
			var ground: Vector3i = target["voxel"]
			var above: Vector3i = target["place"]
			var ground_id := tool.get_voxel(ground)
			player._edit_block(true)
			var placed_inside := tool.get_voxel(above) != IslandGenerator.AIR
			print("Colocar dentro de uno mismo: %s" % ("FALLO, se colocó" if placed_inside else "OK, no se coloca"))
			var particles_before := _count_particles()
			player._edit_block(false)
			var removed := tool.get_voxel(ground) == IslandGenerator.AIR
			print("Romper el suelo (bloque %d): %s" % [ground_id, "OK, quitado" if removed else "FALLO, sigue ahí"])
			print("Partículas al romper: %s" % ("OK" if _count_particles() > particles_before else "FALLO, no hay"))
			_step = 2
			_wait = 0
		2:
			# Mirar al frente y un poco abajo, a un bloque a unos metros: colocar sí debe funcionar.
			player.debug_pose(false, -0.45, 0.0, 0.0)
			_step = 3
		3:
			var target: Dictionary = player._target()
			if target.is_empty():
				print("AVISO: al frente no hay bloque al alcance (prueba de colocar omitida)")
				return true
			var cell: Vector3i = target["place"]
			player._edit_block(true)
			var id := tool.get_voxel(cell)
			print("Colocar al frente: %s" % ("OK, colocado bloque %d" % id if id == player.get_current_block() else "FALLO"))
			return true
	return false


func _count_particles() -> int:
	var n := 0
	for child in _main.get_children():
		if child is CPUParticles3D:
			n += 1
	return n
