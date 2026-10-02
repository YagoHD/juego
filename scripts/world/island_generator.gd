extends VoxelGeneratorScript
class_name IslandGenerator
## Genera la isla a partir de los mapas horneados por tools/island_baker:
##   height.png (altura, 16 bits), water.png (nivel de ríos/lagos), biome.png (biomas por color).
## La superficie se decide por bioma + pendiente: roca solo en paredes empinadas, pinos en las
## laderas, nieve solo en las cimas. Coordenadas de voxel centradas en (0,0).

# IDs de bloque (el índice debe coincidir con la librería en main.gd).
const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const SNOW := 5
const WOOD := 6
const LEAVES := 7
const WATER := 8
const PINE_LEAVES := 9
const CORRUPT_SOIL := 10
const DEAD_WOOD := 11
const WHEAT := 12

# Biomas (deben coincidir con IslandBaker.cs).
const B_OCEAN := 0
const B_BEACH := 1
const B_MEADOW := 2
const B_FOREST := 3
const B_PINE := 4
const B_ALPINE := 5
const B_CORRUPT := 6
const B_VILLAGE := 7
const B_FARM := 8
const B_WATER := 9
var _palette: Array[Color] = [
	Color8(20, 60, 140), Color8(230, 210, 150), Color8(140, 200, 90), Color8(40, 120, 50),
	Color8(30, 80, 60), Color8(150, 150, 150), Color8(90, 50, 110), Color8(200, 160, 110),
	Color8(230, 200, 60), Color8(60, 170, 220),
]

const MAP_DIR := "res://assets/island/"
const MAP_HALF := 1024.0      # los mapas cubren [-MAP_HALF, MAP_HALF] voxels en X y Z
const OCEAN_FLOOR := 4.0
const SEA_LEVEL := 24         # coincide con el plano de mar en main.gd y con el horneador
const SNOW_LINE := 175.0
const TREE_LINE := 150.0
const DIRT_DEPTH := 3
const STEEP_SLOPE := 1.1      # voxels de subida por voxel de avance para considerar "pared"
const TREE_MARGIN := 4        # columnas extra alrededor del chunk para no cortar copas
const MAX_TREE_HEIGHT := 16

var _n := 0
var _h := PackedFloat32Array()
var _w := PackedFloat32Array()
var _b := PackedByteArray()
var _voxels_per_px := 2.0
var _snow_noise := FastNoiseLite.new()


func _init() -> void:
	_snow_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_snow_noise.frequency = 0.03
	_h = _load_16bit(MAP_DIR + "height.png")
	_w = _load_16bit(MAP_DIR + "water.png")
	_b = _load_biomes(MAP_DIR + "biome.png")
	if _n > 1:
		_voxels_per_px = 2.0 * MAP_HALF / float(_n - 1)


func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE


# ------------------------------------------------------------------ carga de mapas

func _load_image(path: String) -> Image:
	var img: Image = Image.load_from_file(path)
	if img == null:
		push_error("No se pudo cargar el mapa: " + path)
		return null
	img.convert(Image.FORMAT_RGB8)
	if _n == 0:
		_n = img.get_width()
	return img


func _load_16bit(path: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var img := _load_image(path)
	if img == null:
		return out
	var data := img.get_data()
	var count := img.get_width() * img.get_height()
	out.resize(count)
	for i in count:
		out[i] = float(data[i * 3] * 256 + data[i * 3 + 1]) / 64.0
	return out


func _load_biomes(path: String) -> PackedByteArray:
	var out := PackedByteArray()
	var img := _load_image(path)
	if img == null:
		return out
	var data := img.get_data()
	var count := img.get_width() * img.get_height()
	out.resize(count)
	var lut := {}
	for i in count:
		var key: int = (data[i * 3] << 16) | (data[i * 3 + 1] << 8) | data[i * 3 + 2]
		if not lut.has(key):
			lut[key] = _nearest_biome(Color8(data[i * 3], data[i * 3 + 1], data[i * 3 + 2]))
		out[i] = lut[key]
	return out


func _nearest_biome(c: Color) -> int:
	# Por si el mapa se repinta a mano con colores no exactos.
	var best := 0
	var best_d := INF
	for i in _palette.size():
		var p: Color = _palette[i]
		var d: float = (p.r - c.r) ** 2 + (p.g - c.g) ** 2 + (p.b - c.b) ** 2
		if d < best_d:
			best_d = d
			best = i
	return best


# ------------------------------------------------------------------ muestreo

func _to_px(w: int) -> float:
	return (float(w) + MAP_HALF) / _voxels_per_px


func _index(wx: int, wz: int) -> int:
	# Índice del píxel más cercano, o -1 si está fuera del mapa.
	var px := int(roundf(_to_px(wx)))
	var pz := int(roundf(_to_px(wz)))
	if px < 0 or pz < 0 or px >= _n or pz >= _n:
		return -1
	return pz * _n + px


func _height_at(wx: int, wz: int) -> int:
	if _h.is_empty():
		return int(OCEAN_FLOOR)
	var fx := _to_px(wx)
	var fz := _to_px(wz)
	if fx < 0.0 or fz < 0.0 or fx > float(_n - 1) or fz > float(_n - 1):
		return int(OCEAN_FLOOR)
	var x0 := floori(fx)
	var z0 := floori(fz)
	var x1 := mini(x0 + 1, _n - 1)
	var z1 := mini(z0 + 1, _n - 1)
	var tx := fx - x0
	var tz := fz - z0
	var a := lerpf(_h[z0 * _n + x0], _h[z0 * _n + x1], tx)
	var b := lerpf(_h[z1 * _n + x0], _h[z1 * _n + x1], tx)
	return int(roundf(lerpf(a, b, tz)))


func _water_top_at(wx: int, wz: int) -> int:
	var i := _index(wx, wz)
	if i < 0 or _w.is_empty():
		return 0
	return int(roundf(_w[i]))


func _biome_at(wx: int, wz: int) -> int:
	var i := _index(wx, wz)
	if i < 0 or _b.is_empty():
		return B_OCEAN
	return _b[i]


func _slope_at(wx: int, wz: int) -> float:
	var i := _index(wx, wz)
	if i < 0 or _h.is_empty():
		return 0.0
	var px := i % _n
	@warning_ignore("integer_division")
	var pz := i / _n
	var xl := maxi(px - 1, 0)
	var xr := mini(px + 1, _n - 1)
	var zu := maxi(pz - 1, 0)
	var zd := mini(pz + 1, _n - 1)
	var sx: float = absf(_h[pz * _n + xr] - _h[pz * _n + xl])
	var sz: float = absf(_h[zd * _n + px] - _h[zu * _n + px])
	return maxf(sx, sz) / (2.0 * _voxels_per_px)


# ------------------------------------------------------------------ generación

func _generate_block(out_buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int) -> void:
	if lod != 0:
		return
	var size: Vector3i = out_buffer.get_size()
	var columns := size.x * size.z
	var heights := PackedInt32Array()
	var water_tops := PackedInt32Array()
	var tops := PackedInt32Array()
	var subs := PackedInt32Array()
	heights.resize(columns)
	water_tops.resize(columns)
	tops.resize(columns)
	subs.resize(columns)

	# --- 1. Datos por columna y salida rápida si el chunk es todo aire.
	var highest := -1000
	for x in size.x:
		for z in size.z:
			var wx: int = origin_in_voxels.x + x
			var wz: int = origin_in_voxels.z + z
			var c := x * size.z + z
			var height := _height_at(wx, wz)
			heights[c] = height
			water_tops[c] = _water_top_at(wx, wz)
			var surface := _surface_blocks(wx, wz, height)
			tops[c] = surface.x
			subs[c] = surface.y
			highest = maxi(highest, maxi(height, water_tops[c]))
	if origin_in_voxels.y > highest + MAX_TREE_HEIGHT + 8:
		return

	# --- 2. Terreno y agua.
	for x in size.x:
		for z in size.z:
			var c := x * size.z + z
			var height := heights[c]
			var water_top := water_tops[c]
			for y in size.y:
				var wy: int = origin_in_voxels.y + y
				var block_id := AIR
				if wy < height:
					if wy == height - 1:
						block_id = tops[c]
					elif wy >= height - 1 - DIRT_DEPTH:
						block_id = subs[c]
					else:
						block_id = STONE
				elif wy < water_top:
					block_id = WATER
				if block_id != AIR:
					out_buffer.set_voxel(block_id, x, y, z, VoxelBuffer.CHANNEL_TYPE)

	# --- 3. Árboles (con margen para no cortar copas entre chunks).
	for lx in range(-TREE_MARGIN, size.x + TREE_MARGIN):
		for lz in range(-TREE_MARGIN, size.z + TREE_MARGIN):
			var wx: int = origin_in_voxels.x + lx
			var wz: int = origin_in_voxels.z + lz
			var kind := _tree_kind(wx, wz)
			if kind != 0:
				_stamp_tree(out_buffer, origin_in_voxels, size, wx, wz, _height_at(wx, wz), kind)


func _surface_blocks(wx: int, wz: int, height: int) -> Vector2i:
	# Devuelve (bloque superior, bloque de subsuelo) según bioma y pendiente.
	var biome := _biome_at(wx, wz)
	var steep := _slope_at(wx, wz) > STEEP_SLOPE
	var snow_line := SNOW_LINE + _snow_noise.get_noise_2d(wx, wz) * 8.0
	match biome:
		B_OCEAN:
			return Vector2i(SAND if height > SEA_LEVEL - 12 else STONE, SAND)
		B_BEACH:
			return Vector2i(SAND, SAND)
		B_WATER:
			return Vector2i(SAND, DIRT)
		B_CORRUPT:
			return Vector2i(STONE, STONE) if steep else Vector2i(CORRUPT_SOIL, DIRT)
		B_FARM:
			# Surcos: hileras de trigo separadas por tierra.
			return Vector2i(WHEAT if (wx >> 2) & 1 == 0 else DIRT, DIRT)
		B_ALPINE:
			if height >= snow_line and not steep:
				return Vector2i(SNOW, STONE)
			return Vector2i(STONE, STONE)
		_:
			if height >= snow_line:
				return Vector2i(STONE if steep else SNOW, STONE)
			if steep:
				return Vector2i(STONE, STONE)
			return Vector2i(GRASS, DIRT)


# Tipos de árbol: 0 ninguno, 1 frondoso, 2 pino, 3 muerto.
func _tree_kind(wx: int, wz: int) -> int:
	var biome := _biome_at(wx, wz)
	var density := 0.0
	var kind := 1
	match biome:
		B_FOREST:
			density = 0.045
		B_MEADOW:
			density = 0.005
		B_VILLAGE:
			density = 0.002
		B_PINE:
			density = 0.035
			kind = 2
		B_ALPINE:
			density = 0.006
			kind = 2
		B_CORRUPT:
			density = 0.012
			kind = 3
		_:
			return 0
	if _hash01(wx, wz) >= density:
		return 0
	var height := _height_at(wx, wz)
	if height <= SEA_LEVEL + 1 or height >= TREE_LINE + 10:
		return 0
	if _water_top_at(wx, wz) > height or _slope_at(wx, wz) > 0.8:
		return 0
	return kind


func _stamp_tree(buffer: VoxelBuffer, origin: Vector3i, size: Vector3i, wx: int, wz: int, base: int, kind: int) -> void:
	var r := _hash01(wx * 7 + 1, wz * 7 + 3)
	match kind:
		1:  # Frondoso: tronco y copa redonda (a veces grande).
			var trunk_h := 4 + int(r * 3.0)
			for i in trunk_h:
				_set_if_air(buffer, origin, size, wx, base + i, wz, WOOD)
			var radius2 := 9 if r > 0.75 else 5
			var reach := 3 if radius2 > 5 else 2
			var cy := base + trunk_h
			for dx in range(-reach, reach + 1):
				for dy in range(-reach, reach + 1):
					for dz in range(-reach, reach + 1):
						if dx * dx + dy * dy + dz * dz <= radius2:
							_set_if_air(buffer, origin, size, wx + dx, cy + dy, wz + dz, LEAVES)
		2:  # Pino: tronco alto y copa cónica por pisos.
			var trunk_h := 7 + int(r * 4.0)
			for i in trunk_h:
				_set_if_air(buffer, origin, size, wx, base + i, wz, WOOD)
			var top := base + trunk_h + 1
			for y in range(base + 3, top + 1):
				var radius := int(roundf(float(top - y) * 0.42))
				radius = mini(radius, 3)
				for dx in range(-radius, radius + 1):
					for dz in range(-radius, radius + 1):
						if dx * dx + dz * dz <= radius * radius + 1:
							_set_if_air(buffer, origin, size, wx + dx, y, wz + dz, PINE_LEAVES)
		3:  # Muerto: tronco seco con un par de ramas.
			var trunk_h := 4 + int(r * 4.0)
			for i in trunk_h:
				_set_if_air(buffer, origin, size, wx, base + i, wz, DEAD_WOOD)
			_set_if_air(buffer, origin, size, wx + 1, base + trunk_h - 2, wz, DEAD_WOOD)
			_set_if_air(buffer, origin, size, wx - 1, base + trunk_h - 1, wz + 1, DEAD_WOOD)


func _set_if_air(buffer: VoxelBuffer, origin: Vector3i, size: Vector3i, wx: int, wy: int, wz: int, id: int) -> void:
	var lx: int = wx - origin.x
	var ly: int = wy - origin.y
	var lz: int = wz - origin.z
	if lx < 0 or ly < 0 or lz < 0 or lx >= size.x or ly >= size.y or lz >= size.z:
		return
	if buffer.get_voxel(lx, ly, lz, VoxelBuffer.CHANNEL_TYPE) == AIR:
		buffer.set_voxel(id, lx, ly, lz, VoxelBuffer.CHANNEL_TYPE)


func _hash01(x: int, z: int) -> float:
	var h: int = (x * 73856093) ^ (z * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0x7fffffff) / float(0x7fffffff)


## Altura del suelo en coordenadas de voxel (para colocar al jugador al aparecer).
func get_ground_height(wx: int, wz: int) -> int:
	return maxi(_height_at(wx, wz), _water_top_at(wx, wz))
