extends RefCounted
## Longitud visual y punto de agarre medidos sobre el modelo, desde su extremo inferior.
## Escala uniforme: nunca cambiar la proporción entre los ejes del objeto.
const PROFILES := {
	"stone_knife": {"length": 0.32, "grip": 0.17, "rotation": Vector3(-0.22, 0.0, -0.12), "pose": "handle"},
	"stone_pick": {"length": 0.42, "grip": 0.20, "rotation": Vector3(-0.28, 0.1, -0.15), "pose": "handle"},
	"stone_axe": {"length": 0.45, "grip": 0.2, "rotation": Vector3(-0.25, 0.0, -0.12), "pose": "handle"},
	"spear": {"length": 1.05, "grip": 0.45, "rotation": Vector3(-0.55, 0.0, -0.16), "pose": "handle"},
	"torch": {"length": 0.48, "grip": 0.20, "rotation": Vector3(-0.22, 0.0, -0.12), "pose": "handle"},
	"rock": {"length": 0.13, "grip": 0.50, "rotation": Vector3(0.1, 0.4, 0.0), "pose": "cup", "offset": Vector3(0, 0.030, -0.02)},
	"flint": {"length": 0.12, "grip": 0.30, "rotation": Vector3(-0.1, 0.4, -0.1), "pose": "pinch"},
	"hammer": {"length": 0.52, "grip": 0.20, "rotation": Vector3(-0.25, 0.0, -0.15), "pose": "handle"},
	"battle_axe": {"length": 0.60, "grip": 0.20, "rotation": Vector3(-0.3, 0.0, -0.15), "pose": "handle"},
	"bow": {"length": 0.70, "grip": 0.50, "rotation": Vector3(-0.1, 0.4, -0.12), "pose": "handle"},
	"arrow": {"length": 0.70, "grip": 0.45, "rotation": Vector3(-0.5, 0.0, -0.18), "pose": "pinch"},
}

static func get_profile(id: String) -> Dictionary:
	if PROFILES.has(id):
		return PROFILES[id]
	if ItemDB.block_of(id) >= 0:
		return {"length": 0.18, "grip": 0.5, "rotation": Vector3(-0.2, 0.35, 0), "offset": Vector3(-0.025, 0.045, -0.02), "pose": "open"}
	var length := 0.22
	var pose := "cup"
	if id in ["seeds", "insect", "roasted_insect", "resin", "shell"]:
		length = 0.09
		pose = "pinch"
	elif id in ["raw_fish", "cooked_fish", "board", "sticks", "fishing_rod"]:
		length = 0.36
	elif id in ["shirt", "pants", "belt", "bedroll", "backpack", "raft"]:
		length = 0.30
	return {"length": length, "grip": 0.5, "rotation": Vector3(-0.25, 0.35, -0.15), "offset": Vector3(0, 0.035, -0.02), "pose": pose}
