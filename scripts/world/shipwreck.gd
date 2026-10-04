extends RefCounted
class_name Shipwreck
## El barco del naufragio, entero pero encallado: casco curvo de tablones (el borde suavizado con
## medias losas) y quilla de tronco, borda, cubierta, camarote en la popa con cubierta alta encima,
## castillo de proa, palo mayor con su verga, vela de pie y una cuerda colgando (para recogerla),
## mesana sobre el camarote, trinquete partido (su punta es el mástil caído de la playa), bodega
## con escalera de medias losas y un cofre. Roturas: una vía de agua en el costado, huecos en la
## borda y alguna tabla de la cubierta.
##
## Se construye en coordenadas propias del barco (x: de popa a proa, 0..LENGTH; y: desde la quilla;
## z: de babor a estribor, centrado) y Structures lo coloca en la orilla.

const LENGTH := 40
const HALF := 6.0           # media manga (bloques)
const DECK := 8             # altura de la cubierta (bloque de tablones del suelo)
const MAIN_MAST := 20       # posición del palo mayor (x)
const FORE_MAST := 30
const MIZZEN := 4
const CABIN_END := 9        # el camarote va de la popa hasta aquí
const FORECASTLE := 33      # desde aquí, castillo de proa (un bloque más alto)
const STAIRS_X := 9         # la escalera de la bodega empieza aquí...
const STAIRS_Z := [-1, -2]  # ...en estos carriles (babor: la vía de agua está a estribor)

var cells := {}             # Vector3i (coordenadas del barco) -> id de bloque, o "slab:<lado>"
var hold_chest := Vector3i.ZERO


func build() -> void:
	_hull()
	_deck()
	_cabin()
	_forecastle()
	_masts()
	_stairs()
	_damage()
	hold_chest = Vector3i(14, 2, 2)
	cells[hold_chest] = IslandGenerator.CHEST


## Media manga del casco a lo largo (popa algo estrecha, proa en punta) y a una altura.
func half_width(x: float, y: float) -> float:
	var t := x / LENGTH
	var along := 1.0
	if t < 0.1:
		along = 0.82 + 0.18 * t / 0.1
	elif t > 0.62:
		along = pow(maxf((1.0 - t) / 0.38, 0.0), 0.65)
	var up := 0.32 + 0.68 * sqrt(clampf(y / DECK, 0.0, 1.0))
	return HALF * along * up


func _hull() -> void:
	for x in LENGTH:
		for y in range(0, DECK):
			var w := half_width(x + 0.5, y + 0.5)
			var n := int(ceilf(w))
			for z in range(-n, n + 1):
				var a := absf(z)
				var p := Vector3i(x, y, z)
				if a + 0.5 <= w:
					var shell := a + 1.5 > w or x == 0 or y <= 1
					if shell:
						cells[p] = IslandGenerator.WOOD if (y == 0 and z == 0) else IslandGenerator.PLANKS
					else:
						cells[p] = IslandGenerator.AIR  # bodega
				elif a < w:
					# El borde curvo: media losa pegada hacia el centro (suaviza el casco).
					cells[p] = "slab:" + ("-z" if z > 0 else "+z")
	# Proa: el tajamar, un tronco que sube por delante.
	for y in range(1, DECK + 3):
		cells[Vector3i(LENGTH, y, 0)] = IslandGenerator.WOOD


func _deck() -> void:
	for x in LENGTH:
		var w := half_width(x + 0.5, DECK)
		var n := int(floorf(w - 0.5))
		for z in range(-n, n + 1):
			cells[Vector3i(x, DECK, z)] = IslandGenerator.PLANKS
		# Borda: un tablón alto en el borde, con una media losa encima.
		for side in [-1, 1]:
			cells[Vector3i(x, DECK + 1, n * side)] = IslandGenerator.PLANKS
			cells[Vector3i(x, DECK + 2, n * side)] = "slab:-y"


func _cabin() -> void:
	var n := int(floorf(half_width(CABIN_END, DECK) - 0.5)) - 1
	for x in range(1, CABIN_END):
		for z in range(-n, n + 1):
			var wall := x == 1 or x == CABIN_END - 1 or absf(z) == n
			for y in range(DECK + 1, DECK + 4):
				var p := Vector3i(x, y, z)
				if not wall:
					cells[p] = IslandGenerator.AIR
				elif x == CABIN_END - 1 and z == 0 and y < DECK + 3:
					cells[p] = IslandGenerator.AIR  # puerta
				elif y == DECK + 2 and absf(z) == n and x % 3 == 1:
					cells[p] = IslandGenerator.AIR  # ventanas
				else:
					cells[p] = IslandGenerator.PLANKS
			# Techo (la cubierta alta) con una borda baja de medias losas.
			cells[Vector3i(x, DECK + 4, z)] = IslandGenerator.PLANKS
			if absf(z) == n or x == 1:
				cells[Vector3i(x, DECK + 5, z)] = "slab:-y"


func _forecastle() -> void:
	for x in range(FORECASTLE, LENGTH):
		var w := half_width(x + 0.5, DECK)
		var n := int(floorf(w - 0.5))
		for z in range(-n, n + 1):
			cells[Vector3i(x, DECK + 1, z)] = "slab:-y" if x == FORECASTLE else IslandGenerator.PLANKS
		for side in [-1, 1]:
			if n > 0:
				cells[Vector3i(x, DECK + 2, n * side)] = "slab:-y"


func _masts() -> void:
	# Palo mayor, verga, vela de pie (rasgada en algún sitio) y la cuerda colgando de la verga.
	var top := DECK + 18
	for y in range(1, top):
		cells[Vector3i(MAIN_MAST, y, 0)] = IslandGenerator.WOOD
	var yard := DECK + 14
	for z in range(-6, 7):
		if z != 0:
			cells[Vector3i(MAIN_MAST, yard, z)] = IslandGenerator.LOG_Z
	for y in range(DECK + 5, yard):
		for z in range(-5, 6):
			var belly := 0.5 + absf(z) * 0.4  # el borde de abajo, curvado
			if y - (DECK + 5) < belly:
				continue
			if _hash(y, z, 5) < 0.07:
				continue  # rasgones
			cells[Vector3i(MAIN_MAST + 1, y, z)] = IslandGenerator.SAIL_X
	for y in range(DECK + 2, yard):
		cells[Vector3i(MAIN_MAST, y, 4)] = IslandGenerator.ROPE_HANGING
	# Mesana sobre el camarote, con una vela pequeña.
	for y in range(DECK + 5, DECK + 13):
		cells[Vector3i(MIZZEN, y, 0)] = IslandGenerator.WOOD
	for z in range(-3, 4):
		if z != 0:
			cells[Vector3i(MIZZEN, DECK + 12, z)] = IslandGenerator.LOG_Z
	for y in range(DECK + 7, DECK + 12):
		for z in range(-3, 4):
			if _hash(y, z, 9) > 0.08:
				cells[Vector3i(MIZZEN + 1, y, z)] = IslandGenerator.SAIL_X
	# Trinquete partido: un muñón con la punta astillada (lo demás está en la playa).
	for y in range(1, DECK + 7):
		cells[Vector3i(FORE_MAST, y, 0)] = IslandGenerator.WOOD
	cells[Vector3i(FORE_MAST, DECK + 7, 0)] = "slab:-y"


## Escalera de medias losas desde una escotilla de la cubierta hasta el fondo de la bodega.
func _stairs() -> void:
	var surface := DECK + 1.0     # se baja de la cubierta...
	var floor_top := 2.0          # ...al suelo de la bodega
	var x := STAIRS_X
	while surface > floor_top and x < LENGTH - 10:
		surface -= 0.5
		for z: int in STAIRS_Z:
			var y := int(floorf(surface))
			if surface - y > 0.25:
				cells[Vector3i(x, y, z)] = "slab:-y"       # escalón de media altura
			else:
				cells[Vector3i(x, y - 1, z)] = IslandGenerator.PLANKS
				cells[Vector3i(x, y, z)] = IslandGenerator.AIR
			for h in range(1, 4):  # sitio para la cabeza (abre la escotilla en la cubierta)
				cells[Vector3i(x, y + h, z)] = IslandGenerator.AIR
		x += 1


func _damage() -> void:
	# Vía de agua en el costado de estribor (+z), cerca de la línea de flotación.
	for x in range(24, 28):
		for y in range(2, 5):
			for z in range(1, 8):
				var p := Vector3i(x, y, z)
				if cells.has(p) and _hash(x, y, 3) < 0.85:
					cells[p] = IslandGenerator.AIR
	# Huecos en la borda y alguna tabla de la cubierta que falta.
	for p: Vector3i in cells.keys():
		if p.y == DECK + 1 and cells[p] is int and cells[p] == IslandGenerator.PLANKS and _hash(p.x, p.z, 13) < 0.04:
			cells[p] = IslandGenerator.AIR
			cells.erase(p + Vector3i.UP)
		elif p.y == DECK and _hash(p.x, p.z, 17) < 0.04 and absf(p.z) > 1 and not (p.x >= STAIRS_X and p.x < LENGTH - 10):
			cells[p] = IslandGenerator.AIR


static func _hash(x: int, z: int, salt: int) -> float:
	var h: int = (x * 73856093) ^ (z * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0
