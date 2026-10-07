extends RefCounted
class_name SleepSpot
## Cómo de bien se duerme en un sitio. Con techo y entre paredes se descansa del todo; con techo,
## casi; a la intemperie, a medias y con mareo al despertar; desmayado en el suelo, mal: poca vida,
## mareo y modorra. Mira solo el terreno y lo construido (capa 1), no criaturas ni objetos.

const ROOF_HEIGHT := 8.0    # metros hacia arriba buscando techo
const WALL_REACH := 4.0     # metros a los lados buscando paredes
const WALLS_NEEDED := 5     # de 8 direcciones, para contar como refugio cerrado

## Lo que deja cada forma de dormir: cansancio que queda, segundos de mareo y de modorra, vida
## que se recupera y vida máxima con la que se despierta.
const REST := {
	"good": {"fatigue": 0.0, "dizzy": 0.0, "groggy": 0.0, "heal": 30.0, "cap": 100.0,
		"text": "Has dormido bien, a cubierto."},
	"roof": {"fatigue": 10.0, "dizzy": 4.0, "groggy": 0.0, "heal": 20.0, "cap": 100.0,
		"text": "Has dormido bajo techo, aunque entraba el aire."},
	"outdoors": {"fatigue": 25.0, "dizzy": 20.0, "groggy": 0.0, "heal": 10.0, "cap": 100.0,
		"text": "Has dormido a la intemperie: te despiertas destemplado y algo mareado."},
	"ground": {"fatigue": 40.0, "dizzy": 45.0, "groggy": 90.0, "heal": 0.0, "cap": 35.0,
		"text": "Te has desmayado de cansancio: te levantas dolorido, mareado y sin fuerzas."},
}


## 'bed' es false si se duerme sin cama (desmayo en el suelo).
static func evaluate(space: PhysicsDirectSpaceState3D, at: Vector3, exclude: Array[RID], bed := true) -> String:
	if not bed:
		return "ground"
	var roof := not _ray(space, at + Vector3.UP * 0.5, at + Vector3.UP * ROOF_HEIGHT, exclude).is_empty()
	if not roof:
		return "outdoors"
	return "good" if walls_around(space, at, exclude) >= WALLS_NEEDED else "roof"


## Cuántas de las 8 direcciones tienen pared cerca, a media altura.
static func walls_around(space: PhysicsDirectSpaceState3D, at: Vector3, exclude: Array[RID]) -> int:
	var count := 0
	var from := at + Vector3.UP * 0.6
	for i in 8:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 8.0)
		if not _ray(space, from, from + direction * WALL_REACH, exclude).is_empty():
			count += 1
	return count


static func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = exclude
	return space.intersect_ray(query)
