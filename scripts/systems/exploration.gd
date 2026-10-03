extends Node
class_name Exploration
## Qué partes de la isla ha pisado el jugador: una rejilla de GRID x GRID casillas sobre el mapa.
## El mapa del diario solo dibuja lo explorado (lo demás, papel en blanco). Se guarda.

const GRID := 64
const RADIUS := 3          # casillas alrededor del jugador que se dan por vistas

var player: Player
var _seen := PackedByteArray()
var _timer := 0.0


func _ready() -> void:
	_seen.resize(GRID * GRID)
	add_to_group("exploration")


func _process(delta: float) -> void:
	if player == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.0
	var c := cell_of(player.global_position)
	for dx in range(-RADIUS, RADIUS + 1):
		for dz in range(-RADIUS, RADIUS + 1):
			if dx * dx + dz * dz <= RADIUS * RADIUS + 1:
				mark(c + Vector2i(dx, dz))


## Casilla de la rejilla de un punto del mundo (metros).
static func cell_of(world: Vector3) -> Vector2i:
	var half := IslandGenerator.MAP_HALF
	var u := (world.x / 0.5 + half) / (half * 2.0)
	var v := (world.z / 0.5 + half) / (half * 2.0)
	return Vector2i(int(u * GRID), int(v * GRID))


func mark(c: Vector2i) -> void:
	if c.x >= 0 and c.y >= 0 and c.x < GRID and c.y < GRID:
		_seen[c.y * GRID + c.x] = 1


func seen(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID and c.y < GRID and _seen[c.y * GRID + c.x] == 1


## El mapa en sepia con solo lo explorado (lo demás, transparente: se ve el papel).
func explored_map(base: Texture2D) -> Texture2D:
	var img := base.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var c := Vector2i(x * GRID / w, y * GRID / h)
			if not seen(c):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func to_data() -> String:
	return Marshalls.raw_to_base64(_seen)


func from_data(text: String) -> void:
	var raw := Marshalls.base64_to_raw(text)
	if raw.size() == GRID * GRID:
		_seen = raw
