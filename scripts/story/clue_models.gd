extends RefCounted
class_name ClueModels
## Dibujos provisionales de las pistas del mundo (Clue), hechos de cajas: un joyero abierto, un
## escudo tallado, un ojo pintado en una puerta, una grieta que brilla... Cuando haya arte de la
## guía visual se cambian por sus modelos de cajas (docs/TEXTURAS.md).

const PURPLE := Color(0.7, 0.3, 1.0)


## Crea una pista lista para añadir a la escena, en 'at' (metros), con su dibujo.
static func make(fact: String, kind: String, at: Vector3, text: String) -> Clue:
	var clue := Clue.new()
	clue.fact = fact
	clue.look_text = text
	clue.position = at
	clue.name = "Pista_" + fact
	var model := build(kind)
	if model != null:
		clue.add_child(model)
	return clue


static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"jewel_box":  # joyero abierto con polvo morado
			_box(root, Vector3(0, 0.06, 0), Vector3(0.3, 0.12, 0.2), Color(0.45, 0.25, 0.12))
			_box(root, Vector3(0, 0.2, -0.1), Vector3(0.3, 0.18, 0.03), Color(0.5, 0.3, 0.15))  # tapa levantada
			_box(root, Vector3(0, 0.125, 0), Vector3(0.24, 0.01, 0.14), PURPLE, 1.5)
		"shield":  # escudo de madera con un barco y una V
			_box(root, Vector3.ZERO, Vector3(0.6, 0.7, 0.06), Color(0.4, 0.25, 0.12))
			_box(root, Vector3(0, -0.05, 0.035), Vector3(0.36, 0.1, 0.02), Color(0.85, 0.75, 0.4))
			_box(root, Vector3(0, 0.15, 0.035), Vector3(0.05, 0.25, 0.02), Color(0.85, 0.75, 0.4))
		"eye_door":  # ojo cerrado pintado
			_box(root, Vector3.ZERO, Vector3(0.5, 0.05, 0.02), Color(0.05, 0.05, 0.05))
			for i in 5:
				_box(root, Vector3(-0.2 + i * 0.1, -0.07, 0), Vector3(0.025, 0.1, 0.02), Color(0.05, 0.05, 0.05))
		"glow_crack":  # grieta que brilla violeta (la quilla del barco, la base de la torre)
			for i in 6:
				_box(root, Vector3(i * 0.12 - 0.3, sin(i * 1.7) * 0.06, 0), Vector3(0.14, 0.04, 0.04), PURPLE, 2.5)
		"tent_eye":  # el ojo cerrado bordado en una lona
			_box(root, Vector3.ZERO, Vector3(0.7, 0.7, 0.02), Color(0.55, 0.15, 0.12))
			_box(root, Vector3(0, 0, 0.015), Vector3(0.4, 0.04, 0.02), Color(0.9, 0.85, 0.7))
		_:
			return null
	return root


static func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, glow := 0.0) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	mesh.material_override = mat
	parent.add_child(mesh)
