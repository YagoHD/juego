extends SceneTree
## Prueba de las habilidades (progresión por uso), sin ventana y sin cargar la isla.
## Uso: godot --headless --path . --script res://tools/test_skills.gd

func _check(text: String, ok: bool) -> void:
	print("%s: %s" % [text, "OK" if ok else "FALLO"])


func _init() -> void:
	var skills := Skills.new()
	var ups: Array = []
	skills.leveled_up.connect(func(skill: String, level: int) -> void: ups.append([skill, level]))
	_check("Empieza en nivel 0", skills.level("mining") == 0 and skills.bonus("mining", 0.06) == 1.0)
	skills.gain("mining", 14.0)
	_check("Con poca práctica sigue en 0", skills.level("mining") == 0 and ups.is_empty())
	skills.gain("mining", 1.0)
	_check("Sube a nivel 1 y avisa", skills.level("mining") == 1 and ups == [["mining", 1]])
	skills.gain("mining", 100000.0)
	_check("No pasa del máximo", skills.level("mining") == Skills.MAX_LEVEL and is_equal_approx(skills.bonus("mining", 0.06), 1.6))
	_check("Cada nivel cuesta más", Skills.xp_for(2) - Skills.xp_for(1) < Skills.xp_for(3) - Skills.xp_for(2))
	skills.gain("inventada", 50.0)
	_check("Ignora habilidades que no existen", not skills.xp.has("inventada"))
	var other := Skills.new()
	other.from_data(skills.to_data())
	_check("Se guarda y se carga", other.level("mining") == Skills.MAX_LEVEL)
	_check("Picar piedra practica minería", Skills.block_skill(IslandGenerator.STONE) == "mining")
	_check("Cortar madera practica tala", Skills.block_skill(IslandGenerator.WOOD) == "woodcutting")
	_check("Cavar arena no practica nada", Skills.block_skill(IslandGenerator.SAND) == "")
	quit()
