class_name WreckModel
## El barco naufragado hecho de cubitos pequeños (MicroVoxels, 1/16 de metro), como en el arte
## conceptual: un casco roto y medio hundido al que le quedan pocas tablas, con las cuadernas
## (costillas) al aire y alguna partida, baos de la cubierta sueltos, dos palos inclinados con sus
## vergas, tiras de vela rota colgando, cuerdas y rocas alrededor.
##
## Cada parte es un modelo aparte con su propia colocación (así los palos pueden ir inclinados):
## parts() devuelve [[cubitos, posición en cubitos, giro en grados (x, y, z)], ...].
## Coordenadas en cubitos: x de popa (0) a proa (LENGTH), y desde la quilla, z de babor a estribor.

const LENGTH := 250
const HALF_BEAM := 38.0
const HEIGHT := 52
const PLANK := 5
const RIB_STEP := 15

const WOOD := Color(0.45, 0.30, 0.18)
const WOOD_LIGHT := Color(0.56, 0.40, 0.25)
const WOOD_DARK := Color(0.28, 0.19, 0.12)
const WET := Color(0.24, 0.24, 0.19)      # madera mojada y con verdín
const MAST := Color(0.40, 0.27, 0.16)
const SAIL := Color(0.86, 0.80, 0.66)
const ROPE := Color(0.60, 0.49, 0.32)
const STONE := Color(0.50, 0.46, 0.40)


func parts() -> Array:
	var out := []
	out.append([_hull(), Vector3.ZERO, Vector3.ZERO])
	# Palo mayor: inclinado hacia popa y un poco hacia babor, con la verga torcida y la vela hecha tiras.
	out.append([_mast(185, true, 7), Vector3(LENGTH * 0.46, HEIGHT - 8, 0), Vector3(6, 0, 14)])
	# Trinquete: muy inclinado hacia proa, más corto y sin vela (solo restos de cuerda).
	out.append([_mast(165, false, 5), Vector3(LENGTH * 0.8, HEIGHT - 14, 4), Vector3(-4, 0, -24)])
	# Rocas donde encalló, sobre todo en la popa.
	out.append([_rocks(), Vector3(-30, -10, -40), Vector3.ZERO])
	return out


## Media manga del casco a la altura y y en la posición x: más estrecho abajo y en proa.
func half_width(x: int, y: float) -> float:
	var t := float(x) / LENGTH
	var along := 1.0
	if t < 0.12:
		along = 0.8 + 0.2 * t / 0.12
	elif t > 0.62:
		along = pow(cos((t - 0.62) / 0.38 * PI * 0.5), 0.75)
	var s := clampf(y / HEIGHT, 0.0, 1.0)
	return HALF_BEAM * along * (0.3 + 0.7 * sqrt(s))


func top(x: int) -> int:
	var t := float(x) / LENGTH * 2.0 - 1.0
	return HEIGHT + int(12.0 * t * t * (1.3 if t > 0.0 else 1.0))


func _hull() -> Dictionary:
	var cells := {}
	for x in LENGTH:
		var segment := x / 31
		for y in top(x):
			var w := half_width(x, float(y))
			if w < 1.0:
				continue
			var strake := y / PLANK
			for side: int in [-1, 1]:
				# Tablas que quedan: casi todas abajo (lo que está bajo el agua y la arena), pocas
				# arriba, y a estribor un gran boquete.
				var keep := 0.97 if y < 16 else (0.75 if y < 30 else 0.45)
				if side > 0:
					keep *= 0.75
				if MicroVoxels.hash01(Vector3i(segment, strake, side)) > keep:
					continue
				for k in 3:
					var p := Vector3i(x, y, side * int(round(w - k)))
					var c := WOOD_LIGHT if (strake + segment) % 3 == 0 else WOOD
					c = c.lerp(WOOD_DARK, MicroVoxels.hash01(Vector3i(strake, segment, side + 5)) * 0.4)
					if y % PLANK == 0 or (x + strake * 13) % 31 == 0:
						c = WOOD_DARK
					if y < 20:
						c = c.lerp(WET, 0.5)
					cells[p] = MicroVoxels.jitter(c, p, 0.08)
			if y < 3:  # quilla y fondo
				for z in range(-int(w), int(w) + 1):
					cells[Vector3i(x, y, z)] = MicroVoxels.jitter(WET, Vector3i(x, y, z), 0.05)
		# Cuadernas: costillas curvas cada RIB_STEP, algunas partidas a media altura y otras que
		# asoman por encima de la borda.
		if x % RIB_STEP == 0:
			for side: int in [-1, 1]:
				var h := MicroVoxels.hash01(Vector3i(x, 3, side))
				var rib_top := top(x) + int((h - 0.3) * 30.0)
				if h < 0.2:
					rib_top = int(HEIGHT * (0.35 + h))  # partida
				for y in range(1, rib_top):
					var w := half_width(x, float(mini(y, HEIGHT)))
					var lean := maxi(y - HEIGHT, 0) / 3  # lo que asoma se abre un poco hacia fuera
					for t in 3:
						for dx in 3:
							var p := Vector3i(x + dx, y, side * (int(round(w)) - t + lean))
							var c := WOOD_DARK.lightened(0.12) if y > 20 else WET.lightened(0.05)
							cells[p] = MicroVoxels.jitter(c, p, 0.06)
			# Bao (viga de lado a lado bajo la cubierta), si no se ha caído.
			if MicroVoxels.hash01(Vector3i(x, 9, 9)) > 0.3:
				var y := HEIGHT - 8
				var w := half_width(x, float(y))
				for z in range(-int(w), int(w) + 1):
					for dy in 3:
						for dx in 3:
							var p := Vector3i(x + dx, y + dy, z)
							cells[p] = MicroVoxels.jitter(WOOD_DARK.lightened(0.05), p, 0.06)
	# Algún trozo de cubierta que aguanta (en la popa y cerca de la proa).
	for x in range(6, LENGTH - 10):
		var t := float(x) / LENGTH
		if not (t < 0.22 or (t > 0.66 and t < 0.78)):
			continue
		var y := HEIGHT - 5
		var w := half_width(x, float(y)) - 2.0
		for z in range(-int(w), int(w) + 1):
			if MicroVoxels.hash01(Vector3i(x / 6, 1, (z + 40) / 5)) > 0.75:
				continue  # tablas que faltan
			var p := Vector3i(x, y, z)
			var c := WOOD_LIGHT if (z + 40) / 5 % 2 == 0 else WOOD
			if (z + 40) % 5 == 0:
				c = WOOD_DARK
			cells[p] = MicroVoxels.jitter(c, p, 0.08)
	return cells


## Palo con su verga (palo atravesado), un tope arriba y cuerdas que bajan; with_sail: tiras de
## vela rota colgando de la verga.
func _mast(height: int, with_sail: bool, radius: int) -> Dictionary:
	var cells := {}
	for y in height:
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if dx * dx + dz * dz <= radius * radius - 2:
					var p := Vector3i(dx, y, dz)
					var c := MAST
					if y % 40 < 3:
						c = ROPE.darkened(0.2)  # ataduras
					cells[p] = MicroVoxels.jitter(c, p, 0.09)
	# Tope y travesaño.
	for dx in range(-radius - 3, radius + 4):
		for dz in range(-radius - 3, radius + 4):
			for dy in 4:
				var p := Vector3i(dx, height - 20 + dy, dz)
				cells[p] = MicroVoxels.jitter(WOOD_DARK, p, 0.06)
	# Verga, un poco torcida.
	var yard_y := height - 46
	for z in range(-62, 63):
		var sag := int(abs(z) * 0.08)
		for dy in 4:
			for dx in 4:
				var p := Vector3i(-radius - 4 + dx, yard_y + dy - sag + z / 12, z)
				cells[p] = MicroVoxels.jitter(MAST.darkened(0.08), p, 0.07)
	if with_sail:
		# Tiras de vela de distinto largo, con huecos entre ellas y el borde deshilachado.
		var z := -58
		while z < 58:
			var width := 5 + int(MicroVoxels.hash01(Vector3i(z, 2, 0)) * 9.0)
			var drop := 26 + int(MicroVoxels.hash01(Vector3i(z, 4, 0)) * 70.0)
			if MicroVoxels.hash01(Vector3i(z, 5, 0)) > 0.25:
				for dz in width:
					var zz := z + dz
					var my_drop := drop - int(MicroVoxels.hash01(Vector3i(zz, 6, 0)) * 10.0)
					for dy in range(1, my_drop):
						var swing := int(3.0 * sin(float(dy) / 14.0 + float(z) * 0.3))
						var p := Vector3i(-radius - 6 - swing, yard_y - dy - abs(zz) / 12, zz)
						var c := SAIL
						if MicroVoxels.hash01(Vector3i(zz / 3, dy / 3, 7)) > 0.8:
							c = SAIL.darkened(0.2)
						cells[p] = MicroVoxels.jitter(c, p, 0.05)
			z += width + 2 + int(MicroVoxels.hash01(Vector3i(z, 8, 0)) * 6.0)
	# Cuerdas: de lo alto a los lados, con comba (unas tensas, otras sueltas colgando).
	var mast_top := Vector3(0, height - 18, 0)
	for target: Vector3 in [Vector3(-40, 0, 36), Vector3(-40, 0, -36), Vector3(30, 0, 34),
			Vector3(34, 0, -30), Vector3(-90, 10, 0)]:
		_line(cells, mast_top, target, 8.0)
	for z: int in [-60, 60]:
		_line(cells, Vector3(-radius - 3, yard_y, z), Vector3(-radius - 3 + 6, yard_y - 60, z * 0.8), 2.0)
	return cells


func _rocks() -> Dictionary:
	var cells := {}
	var lumps := [[Vector3i(0, 0, 0), 26], [Vector3i(30, 0, -14), 20], [Vector3i(-14, 0, 30), 18],
		[Vector3i(18, 0, 26), 14], [Vector3i(56, 0, -22), 16], [Vector3i(-26, 0, -6), 12],
		[Vector3i(40, 0, 70), 15], [Vector3i(200, 0, -30), 18], [Vector3i(230, 0, 10), 13]]
	for lump: Array in lumps:
		var center: Vector3i = lump[0]
		var r: int = lump[1]
		for x in range(-r, r + 1):
			for z in range(-r, r + 1):
				for y in range(0, r * 2):
					# Bloques de piedra irregulares: más anchos abajo, con escalones.
					var q := Vector3i(x / 6, y / 6, z / 6)
					var shrink := float(y) / (r * 2) * r * 0.8 + MicroVoxels.hash01(q) * 6.0
					if x * x + z * z > (r - shrink) * (r - shrink):
						continue
					var p := center + Vector3i(x, y, z)
					var c := STONE.lerp(WET, 0.5 if y < 14 else 0.0)
					c = c.darkened(MicroVoxels.hash01(q + Vector3i(3, 3, 3)) * 0.25)
					if y > r and MicroVoxels.hash01(q + Vector3i(9, 9, 9)) > 0.8:
						c = Color(0.36, 0.48, 0.24)  # musgo
					cells[p] = MicroVoxels.jitter(c, p, 0.08)
	return cells


func _line(cells: Dictionary, a: Vector3, b: Vector3, sag: float) -> void:
	var steps := int(a.distance_to(b) * 1.5)
	for i in steps + 1:
		var t := float(i) / steps
		var p := a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
		var q := Vector3i(roundi(p.x), roundi(p.y), roundi(p.z))
		cells[q] = MicroVoxels.jitter(ROPE, q, 0.06)


## Nodo con todas las partes ya colocadas (el origen es la quilla en la popa). heel: escora en grados.
static func make_node(heel := -12.0) -> Node3D:
	var size := Main.VOXEL_SIZE / MicroVoxels.RES
	var root := Node3D.new()
	root.name = "BarcoDeCubitos"
	var tilted := Node3D.new()
	tilted.rotation_degrees = Vector3(heel, 0, 2.0)
	root.add_child(tilted)
	for part: Array in WreckModel.new().parts():
		var node := MicroVoxels.make_node(part[0], size)
		node.position = (part[1] as Vector3) * size
		node.rotation_degrees = part[2]
		tilted.add_child(node)
	return root
