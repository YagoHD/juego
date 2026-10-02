extends Node
class_name Sfx
## Sonidos del juego, generados por código (ruido filtrado y tonos): no hace falta ningún
## archivo de audio. Uso desde cualquier sitio:  Sfx.play("romper_piedra", posicion)
## Sin posición suena "en la cabeza" (interfaz). Además lleva el ambiente de fondo: olas cerca
## del mar, pájaros de día y grillos de noche.

const RATE := 22050

static var _instance: Sfx
static var _streams := {}

var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _waves: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _chirp_timer := 3.0
## Qué tan cerca está el mar (0..1) y si es de día (0..1): los pone main.gd cada fotograma.
var sea_amount := 0.0
var daylight := 1.0


func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 4.0
		p.max_distance = 40.0
		add_child(p)
		_pool3d.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool2d.append(p)
	_waves = AudioStreamPlayer.new()
	_waves.stream = _stream("olas")
	_waves.volume_db = -80.0
	add_child(_waves)
	_waves.play()


## Suena un efecto. pos = null: sin posición (interfaz o el propio jugador).
static func play(sound: String, pos: Variant = null, volume_db := 0.0, pitch_spread := 0.08) -> void:
	if _instance == null:
		return
	_instance._play(sound, pos, volume_db, pitch_spread)


## Nombre del sonido de pasos / golpes según el bloque.
static func material_of(block_id: int) -> String:
	match block_id:
		IslandGenerator.SAND, IslandGenerator.SNOW:
			return "arena"
		IslandGenerator.STONE, IslandGenerator.MOSSY_STONE:
			return "piedra"
		IslandGenerator.WOOD, IslandGenerator.PLANKS, IslandGenerator.CHEST, IslandGenerator.DEAD_WOOD, IslandGenerator.DRIFTWOOD, IslandGenerator.WORKBENCH:
			return "madera"
		IslandGenerator.CLOTH:
			return "tela"
		IslandGenerator.WATER:
			return "agua"
	return "hierba"


func _play(sound: String, pos: Variant, volume_db: float, pitch_spread: float) -> void:
	var stream := _stream(sound)
	if stream == null:
		return
	var pitch := 1.0 + _rng.randf_range(-pitch_spread, pitch_spread)
	if pos is Vector3:
		var p := _free(_pool3d) as AudioStreamPlayer3D
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.global_position = pos
		p.play()
	else:
		var p := _free(_pool2d) as AudioStreamPlayer
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.play()


func _free(pool: Array) -> Node:
	for p in pool:
		if not p.playing:
			return p
	return pool[0]  # todos ocupados: se corta el más antiguo


func _process(delta: float) -> void:
	if get_tree().paused:
		_waves.volume_db = -80.0
		return
	# Olas: más fuertes cuanto más cerca del mar.
	var target := lerpf(-50.0, -9.0, clampf(sea_amount, 0.0, 1.0))
	_waves.volume_db = lerpf(_waves.volume_db, target, 1.0 - exp(-2.0 * delta))
	# Pájaros de día, grillos de noche, de vez en cuando.
	_chirp_timer -= delta
	if _chirp_timer <= 0.0:
		_chirp_timer = _rng.randf_range(2.0, 7.0)
		if daylight > 0.5:
			_play("pajaro", null, -14.0 - sea_amount * 6.0, 0.25)
		else:
			_play("grillos", null, -16.0, 0.1)


# ------------------------------------------------------------------ síntesis

static func _stream(sound: String) -> AudioStreamWAV:
	if _streams.has(sound):
		return _streams[sound]
	var data := _synth(sound)
	if data.is_empty():
		return null
	data = _limit(data)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	wav.data = bytes
	if sound == "olas":
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = data.size()
	_streams[sound] = wav
	return wav


## Si algún punto pasa de 0,9, baja todo el sonido para que no sature.
static func _limit(data: PackedFloat32Array) -> PackedFloat32Array:
	var peak := 0.0
	for v in data:
		peak = maxf(peak, absf(v))
	if peak > 0.9:
		var k := 0.9 / peak
		for i in data.size():
			data[i] *= k
	return data


static func _synth(sound: String) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound)
	match sound:
		"paso_hierba": return _noise(rng, 0.11, 60.0, 0.18, 0.5)
		"paso_arena": return _noise(rng, 0.13, 45.0, 0.45, 0.45)
		"paso_piedra": return _mix(_noise(rng, 0.07, 90.0, 0.35, 0.5), _tone(0.05, 380.0, 300.0, 70.0, 0.25))
		"paso_madera": return _mix(_noise(rng, 0.08, 70.0, 0.12, 0.35), _tone(0.09, 190.0, 150.0, 40.0, 0.5))
		"paso_tela": return _noise(rng, 0.1, 55.0, 0.08, 0.35)
		"paso_agua": return _splash(rng, 0.25)
		"romper_hierba": return _noise(rng, 0.22, 22.0, 0.2, 0.8)
		"romper_arena": return _noise(rng, 0.25, 18.0, 0.5, 0.7)
		"romper_piedra": return _mix(_noise(rng, 0.2, 25.0, 0.55, 0.8), _tone(0.12, 220.0, 120.0, 30.0, 0.4))
		"romper_madera": return _mix(_noise(rng, 0.18, 26.0, 0.18, 0.6), _tone(0.16, 160.0, 90.0, 22.0, 0.7))
		"romper_tela": return _noise(rng, 0.18, 25.0, 0.1, 0.6)
		"romper_agua": return _splash(rng, 0.4)
		"colocar": return _mix(_noise(rng, 0.08, 50.0, 0.12, 0.6), _tone(0.1, 140.0, 90.0, 35.0, 0.6))
		"golpe": return _mix(_noise(rng, 0.06, 70.0, 0.25, 0.5), _tone(0.06, 260.0, 200.0, 60.0, 0.35))
		"recoger": return _tone(0.12, 520.0, 980.0, 25.0, 0.35)
		"tirar": return _noise(rng, 0.2, 14.0, 0.06, 0.35, true)
		"fabricado": return _mix(_mix(_tone(0.5, 523.0, 523.0, 6.0, 0.3), _delay(_tone(0.45, 659.0, 659.0, 6.0, 0.3), 0.09)), _delay(_tone(0.4, 784.0, 784.0, 6.0, 0.3), 0.18))
		"aprender": return _mix(_tone(0.7, 392.0, 392.0, 4.0, 0.25), _delay(_tone(0.6, 587.0, 587.0, 4.0, 0.25), 0.15))
		"pagina": return _noise(rng, 0.3, 9.0, 0.3, 0.3, true)
		"cofre": return _creak(0.45)
		"clic": return _tone(0.04, 900.0, 700.0, 80.0, 0.25)
		"pajaro": return _bird(rng)
		"grillos": return _crickets(rng)
		"olas": return _waves_loop(rng)
	return PackedFloat32Array()


## Ruido con caída exponencial. brightness 0..1: lo agudo que suena (filtro paso bajo).
## swell: sube y baja (roce, hojas de papel) en vez de golpe seco.
static func _noise(rng: RandomNumberGenerator, length: float, decay: float, brightness: float, gain: float, swell := false) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var a := clampf(brightness, 0.02, 1.0)
	for i in n:
		var t := float(i) / RATE
		low += a * (rng.randf_range(-1.0, 1.0) - low)
		var env := sin(PI * t / length) if swell else exp(-t * decay)
		out[i] = low * env * gain * (2.0 - a)
	return out


## Tono que va de f0 a f1 Hz y se apaga.
static func _tone(length: float, f0: float, f1: float, decay: float, gain: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / length)
		phase += TAU * f / RATE
		var attack := minf(1.0, t * 400.0)
		out[i] = sin(phase) * exp(-t * decay) * attack * gain
	return out


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		out[i] += other[i]
	return out


static func _delay(a: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var pad := PackedFloat32Array()
	pad.resize(int(seconds * RATE))
	pad.append_array(a)
	return pad


static func _splash(rng: RandomNumberGenerator, length: float) -> PackedFloat32Array:
	var out := _noise(rng, length, 10.0, 0.35, 0.5, true)
	# Burbujitas: tonos cortos que suben.
	for k in 4:
		var start := int(rng.randf_range(0.0, length * 0.6) * RATE)
		var bubble := _tone(0.05, rng.randf_range(500, 900), rng.randf_range(1100, 1600), 50.0, 0.12)
		for i in bubble.size():
			if start + i < out.size():
				out[start + i] += bubble[i]
	return out


static func _creak(length: float) -> PackedFloat32Array:
	# Bisagra: tono grave que tiembla, con aspereza.
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 140.0 + 60.0 * t / length + 18.0 * sin(t * 70.0)
		phase += TAU * f / RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		out[i] = saw * 0.18 * sin(PI * t / length)
	return out


static func _bird(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var notes := rng.randi_range(2, 4)
	for k in notes:
		var f := rng.randf_range(2200.0, 3400.0)
		out.append_array(_tone(0.09, f, f * rng.randf_range(1.1, 1.4), 18.0, 0.2))
		var gap := PackedFloat32Array()
		gap.resize(int(0.05 * RATE))
		out.append_array(gap)
	return out


static func _crickets(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in 3:
		var chirp := _tone(0.12, 4300.0, 4300.0, 2.0, 0.08)
		for i in chirp.size():
			chirp[i] *= 0.5 + 0.5 * sin(float(i) / RATE * TAU * 45.0)  # trino
		out.append_array(chirp)
		var gap := PackedFloat32Array()
		gap.resize(int(rng.randf_range(0.08, 0.15) * RATE))
		out.append_array(gap)
	return out


static func _waves_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	# 8 s de rumor de olas: ruido grave que sube y baja (dos olas), que enlaza sin cortes.
	var length := 8.0
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var low2 := 0.0
	for i in n:
		var t := float(i) / RATE
		low += 0.06 * (rng.randf_range(-1.0, 1.0) - low)
		low2 += 0.25 * (rng.randf_range(-1.0, 1.0) - low2)
		var swell := 0.35 + 0.65 * pow(0.5 - 0.5 * cos(TAU * t / 4.0), 2.0)
		out[i] = (low * 1.6 + low2 * 0.25 * swell) * swell * 0.7
	# Fundido en los extremos para que el bucle no haga "clic".
	var fade := int(0.05 * RATE)
	for i in fade:
		var k := float(i) / fade
		out[i] *= k
		out[n - 1 - i] *= k
	return out
