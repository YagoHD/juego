extends Node
class_name DayNight
## Ciclo de día y noche. Un día completo dura CYCLE_MINUTES minutos reales:
##   - de día (SUNRISE..SUNSET) el sol cruza el cielo de este a oeste;
##   - de noche sale la luna (luz azulada y tenue) y aparecen las estrellas.
## Cielo, luz, luz ambiental, niebla y nubes cambian de tono según la hora, interpolando entre
## los "momentos" de KEYS (amanecer, día, atardecer, crepúsculo, noche...).
## Lleva la cuenta de los días (la torre del diseño crece con ellos).

const CYCLE_MINUTES := 24.0   # día ≈ 14 min, noche ≈ 10 min
const SUNRISE := 6.0
const SUNSET := 20.0
const START_HOUR := 8.0       # se empieza por la mañana
const PATH_TILT := 0.436  # 25°: el sol no pasa justo por encima, va inclinado hacia un lado
const FAST_FORWARD := 60.0    # mantener T: el tiempo va 60 veces más rápido

## Momentos del día (hora) y sus colores. Entre dos momentos se interpola.
const KEYS := [
	{"h": 0.0, "top": Color(0.02, 0.03, 0.08), "horizon": Color(0.05, 0.07, 0.14), "fog": Color(0.05, 0.07, 0.12),
		"sun": Color(1.0, 0.5, 0.3), "glow": Color(0.3, 0.2, 0.3), "cloud": Color(0.13, 0.14, 0.19),
		"ambient": Color(0.11, 0.14, 0.24), "sky_ambient": 0.25, "stars": 1.0},
	{"h": 5.0, "top": Color(0.05, 0.06, 0.16), "horizon": Color(0.26, 0.21, 0.33), "fog": Color(0.2, 0.18, 0.25),
		"sun": Color(1.0, 0.5, 0.3), "glow": Color(0.6, 0.3, 0.3), "cloud": Color(0.3, 0.27, 0.36),
		"ambient": Color(0.16, 0.16, 0.26), "sky_ambient": 0.4, "stars": 0.6},
	{"h": 6.3, "top": Color(0.26, 0.40, 0.70), "horizon": Color(0.98, 0.60, 0.36), "fog": Color(0.85, 0.66, 0.52),
		"sun": Color(1.0, 0.62, 0.38), "glow": Color(1.0, 0.55, 0.3), "cloud": Color(1.0, 0.74, 0.58),
		"ambient": Color(0.5, 0.45, 0.45), "sky_ambient": 0.5, "stars": 0.0},
	{"h": 8.0, "top": Color(0.22, 0.48, 0.88), "horizon": Color(0.68, 0.82, 0.95), "fog": Color(0.86, 0.89, 0.93),
		"sun": Color(1.0, 0.96, 0.88), "glow": Color(1.0, 0.92, 0.75), "cloud": Color(1.0, 1.0, 1.0),
		"ambient": Color(0.62, 0.62, 0.64), "sky_ambient": 0.45, "stars": 0.0},
	{"h": 17.5, "top": Color(0.22, 0.46, 0.86), "horizon": Color(0.74, 0.80, 0.90), "fog": Color(0.86, 0.86, 0.88),
		"sun": Color(1.0, 0.93, 0.80), "glow": Color(1.0, 0.85, 0.65), "cloud": Color(1.0, 0.98, 0.95),
		"ambient": Color(0.62, 0.61, 0.62), "sky_ambient": 0.45, "stars": 0.0},
	{"h": 19.4, "top": Color(0.20, 0.30, 0.60), "horizon": Color(1.0, 0.55, 0.34), "fog": Color(0.80, 0.62, 0.55),
		"sun": Color(1.0, 0.6, 0.38), "glow": Color(1.0, 0.45, 0.25), "cloud": Color(1.0, 0.66, 0.5),
		"ambient": Color(0.5, 0.46, 0.47), "sky_ambient": 0.5, "stars": 0.0},
	{"h": 20.3, "top": Color(0.06, 0.07, 0.20), "horizon": Color(0.36, 0.21, 0.36), "fog": Color(0.26, 0.19, 0.29),
		"sun": Color(1.0, 0.5, 0.3), "glow": Color(0.5, 0.25, 0.35), "cloud": Color(0.36, 0.26, 0.38),
		"ambient": Color(0.2, 0.17, 0.27), "sky_ambient": 0.45, "stars": 0.4},
	{"h": 21.5, "top": Color(0.02, 0.03, 0.08), "horizon": Color(0.05, 0.07, 0.14), "fog": Color(0.05, 0.07, 0.12),
		"sun": Color(1.0, 0.5, 0.3), "glow": Color(0.3, 0.2, 0.3), "cloud": Color(0.13, 0.14, 0.19),
		"ambient": Color(0.11, 0.14, 0.24), "sky_ambient": 0.25, "stars": 1.0},
]

const SUN_ENERGY := 1.15
const MOON_ENERGY := 0.28
const MOON_COLOR := Color(0.62, 0.72, 1.0)

## Hora actual (0..24) y número de día (empieza en 1).
var hour := START_HOUR
var day := 1

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment
var _sky_material: ShaderMaterial
var _clouds: Clouds


## Crea las luces, el entorno y las nubes. fog_* son los ajustes de niebla de main.gd.
func setup(parent: Node3D, fog_begin: float, fog_end: float, fog_max: float) -> void:
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 250.0
	parent.add_child(_sun)  # primera luz direccional = LIGHT0 del cielo (sol)

	_moon = DirectionalLight3D.new()
	_moon.light_color = MOON_COLOR
	_moon.shadow_enabled = true
	_moon.directional_shadow_max_distance = 150.0
	parent.add_child(_moon)  # segunda = LIGHT1 (luna)

	_sky_material = ShaderMaterial.new()
	_sky_material.shader = load("res://assets/shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Niebla por distancia: nada hasta fog_begin y luego una bruma del color del horizonte.
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_depth_begin = fog_begin
	_env.fog_depth_end = fog_end
	_env.fog_depth_curve = 1.2
	_env.fog_density = fog_max
	_env.fog_sky_affect = 0.6
	_env.fog_aerial_perspective = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	parent.add_child(world_env)

	_clouds = Clouds.new()
	parent.add_child(_clouds)
	_apply()


func _process(delta: float) -> void:
	var speed := FAST_FORWARD if Input.is_key_pressed(KEY_T) else 1.0
	advance(delta * speed * 24.0 / (CYCLE_MINUTES * 60.0))
	_apply()


## Avanza el reloj 'hours' horas de juego.
func advance(hours: float) -> void:
	hour += hours
	while hour >= 24.0:
		hour -= 24.0
		day += 1


func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	_apply()


func is_night() -> bool:
	return hour < SUNRISE or hour >= SUNSET


func get_clock_text() -> String:
	var minutes := int(hour * 60.0)
	return "Día %d · %02d:%02d" % [day, minutes / 60, minutes % 60]


# ------------------------------------------------------------------ aplicar la hora

func _apply() -> void:
	var k := _sample(hour)

	# Sol: recorre medio círculo entre el amanecer y el atardecer.
	var sun_t := (hour - SUNRISE) / (SUNSET - SUNRISE)
	var sun_dir := _arc(sun_t)
	_place_light(_sun, sun_dir)
	var sun_up := smoothstep(-0.04, 0.12, sun_dir.y)
	_sun.visible = sun_dir.y > -0.05
	_sun.light_energy = SUN_ENERGY * sun_up
	_sun.light_color = k["sun"]
	_sun.shadow_enabled = sun_dir.y > 0.02

	# Luna: recorre el otro medio círculo durante la noche.
	var night_len := 24.0 - (SUNSET - SUNRISE)
	var moon_t := fposmod(hour - SUNSET, 24.0) / night_len
	var moon_dir := _arc(moon_t)
	_place_light(_moon, moon_dir)
	var moon_up := smoothstep(-0.04, 0.15, moon_dir.y)
	_moon.visible = moon_dir.y > -0.05
	_moon.light_energy = MOON_ENERGY * moon_up
	_moon.shadow_enabled = moon_dir.y > 0.05 and not _sun.shadow_enabled

	_sky_material.set_shader_parameter("top_color", k["top"])
	_sky_material.set_shader_parameter("horizon_color", k["horizon"])
	_sky_material.set_shader_parameter("ground_color", (k["horizon"] as Color).darkened(0.55))
	_sky_material.set_shader_parameter("sun_glow_color", k["glow"])
	_sky_material.set_shader_parameter("stars", k["stars"])

	_env.ambient_light_color = k["ambient"]
	_env.ambient_light_sky_contribution = k["sky_ambient"]
	_env.fog_light_color = k["fog"]
	if _clouds != null:
		_clouds.set_color(k["cloud"])


## Dirección hacia el astro para t = 0 (sale por el este) .. 1 (se pone por el oeste).
## Fuera de 0..1 está bajo el horizonte.
func _arc(t: float) -> Vector3:
	var a := t * PI
	return Vector3(cos(a), sin(a) * cos(PATH_TILT), sin(a) * sin(PATH_TILT)).normalized()


func _place_light(light: DirectionalLight3D, toward: Vector3) -> void:
	# La luz direccional alumbra hacia su -Z: que apunte desde el astro hacia el suelo.
	light.basis = Basis.looking_at(-toward, Vector3.UP if absf(toward.y) < 0.99 else Vector3.FORWARD)


## Colores de la hora h, interpolando entre los dos momentos de KEYS que la rodean.
func _sample(h: float) -> Dictionary:
	var count := KEYS.size()
	for i in count:
		var a: Dictionary = KEYS[i]
		var b: Dictionary = KEYS[(i + 1) % count]
		var ha: float = a["h"]
		var hb: float = b["h"] if i + 1 < count else 24.0 + float(b["h"])
		if h >= ha and h < hb:
			var t := smoothstep(0.0, 1.0, (h - ha) / (hb - ha))
			var out := {}
			for key in a:
				if key == "h":
					continue
				var va: Variant = a[key]
				if va is Color:
					out[key] = (va as Color).lerp(b[key], t)
				else:
					out[key] = lerpf(float(va), float(b[key]), t)
			return out
	return KEYS[0]
