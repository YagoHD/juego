extends Node3D
class_name Weather
## El tiempo: a ratos llueve. La lluvia oscurece el cielo, cae alrededor del jugador, suena,
## apaga las hogueras que estén al raso y se puede beber mirando hacia arriba (mano vacía).

var player: Player
var day_night: DayNight
var rain := 0.0                  # 0..1, cuánto llueve ahora
var _target := 0.0
var _timer := 400.0              # segundos hasta el próximo cambio (empieza despejado)
var _rng := RandomNumberGenerator.new()
var _drops: CPUParticles3D
var _fire_check := 0.0
var _drop_material: StandardMaterial3D


func _ready() -> void:
	_rng.randomize()
	_drops = CPUParticles3D.new()
	var streak := QuadMesh.new()
	streak.size = Vector2(0.025, 0.45)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.75, 0.82, 0.95, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	streak.material = material
	_drop_material = material
	_drops.mesh = streak
	_drops.amount = 1600
	_drops.lifetime = 1.1
	_drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_drops.emission_box_extents = Vector3(14, 0.5, 14)
	_drops.direction = Vector3.DOWN
	_drops.spread = 3.0
	_drops.gravity = Vector3(0, -9.0, 0)
	_drops.initial_velocity_min = 11.0
	_drops.initial_velocity_max = 14.0
	_drops.local_coords = false
	_drops.emitting = false
	add_child(_drops)


func is_raining() -> bool:
	return rain > 0.3


## Solo pruebas o capturas: llover ya (o dejar de llover).
func force(on: bool) -> void:
	_target = 1.0 if on else 0.0
	rain = _target
	_timer = 300.0


func _process(delta: float) -> void:
	if player == null or get_tree().paused:
		return
	_timer -= delta
	if _timer <= 0.0:
		if _target > 0.5:
			_target = 0.0
			_timer = _rng.randf_range(360.0, 900.0)   # despejado de 6 a 15 minutos
		else:
			_target = 1.0
			_timer = _rng.randf_range(120.0, 300.0)   # lluvia de 2 a 5 minutos
	rain = move_toward(rain, _target, delta / 20.0)   # empieza y para poco a poco
	if day_night != null:
		day_night.overcast = rain
	Sfx.set_rain(rain)
	_drops.global_position = player.global_position + Vector3.UP * 9.0
	_drops.emitting = rain > 0.05
	_drop_material.albedo_color.a = 0.45 * clampf(rain, 0.0, 1.0)  # lluvia floja: gotas más tenues
	if is_raining():
		_fire_check -= delta
		if _fire_check <= 0.0:
			_fire_check = 4.0
			get_tree().call_group("campfires", "rained_on")
