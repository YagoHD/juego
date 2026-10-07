extends RefCounted
class_name SmallTalk
## Charla que reacciona: lo que dicen los vecinos al pasar o al preguntarles "¿Qué tal el día?"
## depende de la hora, el tiempo, cómo vas vestido, lo que llevas en la mano, si estás herido, tus
## cuentas con la ley, lo que ya has descubierto de la historia y los días que lleva creciendo la
## torre. Cada vecino recuerda lo que ya te ha dicho (no repite en bucle) y lo olvida al día siguiente.
##
## Cada frase: {"text", "jobs": oficios (vacío = cualquiera), "all": etiquetas que deben darse,
## "none": etiquetas que no deben darse, "weight": cuánto apetece (1 por defecto)}. Se prefieren
## las frases más concretas (con más etiquetas exigidas). Las etiquetas las hace context().

const LINES := [
	# --- La hora y el tiempo.
	{"text": "Buenos días. Madrugas, ¿eh? Como yo.", "all": ["manana"]},
	{"text": "Ya cae la tarde. Hoy no me ha cundido nada.", "all": ["tarde"]},
	{"text": "Es muy tarde para andar por ahí. ¿No duermes?", "all": ["noche"], "weight": 2.0},
	{"text": "Con esta lluvia no hay quien trabaje.", "all": ["lluvia"], "weight": 2.0},
	{"text": "Llueve sobre mojado... y nunca mejor dicho.", "all": ["lluvia"]},
	{"text": "Bendita lluvia. Los campos la necesitaban.", "all": ["lluvia"], "jobs": ["farmer", "herbalist"], "weight": 3.0},
	{"text": "Con lluvia, los peces suben. Hoy es buen día para pescar.", "all": ["lluvia"], "jobs": ["fisher"], "weight": 3.0},
	{"text": "Qué sol tan bueno hace hoy.", "all": ["manana"], "none": ["lluvia"]},
	# --- Cómo vas vestido o equipado.
	{"text": "¿Vas medio desnudo por el pueblo? ¡Tápate, hombre!", "all": ["sin_camisa"], "weight": 3.0},
	{"text": "Con esos harapos se te nota que vienes del naufragio.", "all": ["harapos"], "weight": 2.0},
	{"text": "Buen cuero el de tu ropa. ¿Lo curtiste tú?", "all": ["cuero"], "weight": 2.5},
	{"text": "Ese cuero está bien cosido. Se nota que no es la primera vez.", "all": ["cuero"], "jobs": ["hunter", "merchant"], "weight": 3.0},
	{"text": "Esa armadura... brilla como las piedras de las ruinas. ¿De dónde la has sacado?", "all": ["antiguo"], "weight": 4.0},
	{"text": "¡Por todos los santos! Esas runas... los antiguos llevaban eso. Mi abuela me lo contaba.", "all": ["antiguo"], "jobs": ["elder", "priest"], "weight": 5.0},
	{"text": "Cuánto metal llevas encima. ¿No pesa?", "all": ["pesado"], "weight": 2.0},
	{"text": "Guarda esa arma, que asustas a los niños.", "all": ["armado"], "weight": 2.0},
	{"text": "Con un arma en la mano, aquí te miran mal. Te lo digo por tu bien.", "all": ["armado"], "jobs": ["guard_day", "guard_night"], "weight": 4.0},
	{"text": "Buena hoja. Si la quieres afilar, ya sabes dónde estoy.", "all": ["armado"], "jobs": ["blacksmith"], "weight": 4.0},
	{"text": "¿Una antorcha a plena luz? Tú sabrás.", "all": ["antorcha", "manana"]},
	{"text": "Esa mochila parece de marinero. ¿Era del barco?", "all": ["mochila"], "weight": 1.5},
	# --- Cómo estás.
	{"text": "Estás herido. Ve a ver a la herbolaria antes de que se infecte.", "all": ["herido"], "weight": 4.0},
	{"text": "Ven, siéntate. Esa herida no tiene buena pinta.", "all": ["herido"], "jobs": ["herbalist", "priest"], "weight": 5.0},
	{"text": "Hueles a hoguera y a sal. Bienvenido al pueblo.", "all": ["primera_vez"]},
	# --- La ley.
	{"text": "Me han dicho que has estado rompiendo cosas por aquí. Cuidadito.", "all": ["avisos"], "weight": 3.0},
	{"text": "Debes dinero a la guardia. Págalo antes de que vengan a por ti.", "all": ["multa"], "weight": 4.0},
	{"text": "No te acerques a mí. Sé lo que hiciste.", "all": ["asesino"], "weight": 6.0},
	{"text": "Tú... Tú eres el que mató a uno de los nuestros. Vete.", "all": ["asesino"], "weight": 6.0},
	# --- La torre (días desde el naufragio).
	{"text": "¿Has visto el norte? Algo asoma entre las rocas.", "all": ["torre1"]},
	{"text": "Dicen que la roca del norte ha crecido esta noche. Las rocas no crecen, ¿verdad?", "all": ["torre2"], "weight": 2.0},
	{"text": "Hoy se ve humo de hogueras en el norte. Campamentos. No me gusta.", "all": ["torre3"], "weight": 3.0},
	{"text": "Esa torre ya está entera. Cada noche brilla más.", "all": ["torre4"], "weight": 3.0},
	{"text": "Doblamos las rondas desde que creció la torre.", "all": ["torre3"], "jobs": ["guard_day", "guard_night"], "weight": 4.0},
	{"text": "Desde que apareció esa torre, las gallinas no ponen.", "all": ["torre2"], "jobs": ["farmer"], "weight": 3.0},
	# --- Lo que has descubierto (el pueblo comenta según lo que sabes).
	{"text": "¿Has hablado con Bermudo? A mí la mina me da escalofríos.", "all": ["sabe:mina_brillo_morado"], "weight": 2.0},
	{"text": "¿Umbrita? Mi abuelo también la llamaba así. Decía que traía mala suerte.", "all": ["sabe:nombre_umbrita"], "jobs": ["elder", "old_miner", "blacksmith"], "weight": 4.0},
	{"text": "Así que lo del naufragio no fue el mar... Qué cosas dices.", "all": ["sabe:ded_naufragio"], "weight": 3.0},
	{"text": "¿Los mismos del campamento arrasaron el pueblo pesquero? Entonces vendrán aquí...", "all": ["sabe:ded_invasores_pesquero"], "weight": 4.0},
	{"text": "Si de verdad buscan esa piedra, la mina es lo que quieren. Habrá que avisar.", "all": ["sabe:ded_torre_umbrita"], "jobs": ["guard_day", "guard_night", "old_miner"], "weight": 5.0},
	{"text": "Los Valdés eran buena gente, aunque orgullosos. No merecían eso.", "all": ["sabe:escudo_valdes"], "jobs": ["refugee", "elder", "fisher"], "weight": 4.0},
	{"text": "Gracias por preguntar por nuestra gente. Nadie más lo hace.", "all": ["sabe:ataque_familia_muerta"], "jobs": ["refugee"], "weight": 4.0},
	{"text": "Si los antiguos protegían el lago... ¿de quién lo protegían?", "all": ["sabe:ded_antiguos_guardianes"], "weight": 3.0},
	# --- De su oficio, para cualquier momento.
	{"text": "El trigo no se siega solo.", "jobs": ["farmer"]},
	{"text": "Los cuervos me roban la siembra. Malditos.", "jobs": ["farmer"]},
	{"text": "El mar está raro esta semana. Las redes salen vacías.", "jobs": ["fisher"]},
	{"text": "Mi padre decía: el que no remienda la red, no come.", "jobs": ["fisher"]},
	{"text": "Si tienes algo que vender, te lo miro.", "jobs": ["merchant"]},
	{"text": "El último carro de fuera no llegó. Hay poco género.", "jobs": ["merchant"]},
	{"text": "Me falta hierro. Si subes a la montaña, mira si encuentras mineral.", "jobs": ["blacksmith"]},
	{"text": "Una herradura bien hecha dura diez años.", "jobs": ["blacksmith"]},
	{"text": "Hoy he hecho pan de centeno. Mañana, de trigo, si hay.", "jobs": ["baker"]},
	{"text": "Anoche hubo pelea en la taberna. Lo de siempre.", "jobs": ["innkeeper"]},
	{"text": "El oro de la mina se acabó y con él los buenos tiempos.", "jobs": ["banker"]},
	{"text": "Hay robles que no corto: son más viejos que el pueblo.", "jobs": ["woodcutter"]},
	{"text": "Los ciervos ya no bajan al río. Algo los espanta.", "jobs": ["hunter"]},
	{"text": "La salvia del monte cura casi todo. Casi.", "jobs": ["herbalist"]},
	{"text": "Rezo cada noche por los del pueblo pesquero.", "jobs": ["priest"]},
	{"text": "En mis tiempos esto era más alegre, te lo aseguro.", "jobs": ["elder"]},
	{"text": "Treinta años en la mina y mira cómo tengo las manos.", "jobs": ["old_miner"]},
	{"text": "Estoy con el tejado de la capilla. Si llueve, ya verás.", "jobs": ["carpenter"]},
	{"text": "Aún sueño con el humo.", "jobs": ["refugee"]},
	{"text": "Aquí nos tratan bien, pero no es nuestra casa.", "jobs": ["refugee"]},
	{"text": "Todo en orden. De momento.", "jobs": ["guard_day", "guard_night"]},
]

## Cuando ya te ha dicho todo lo que tenía hoy.
const NOTHING_NEW := ["Hoy ya te lo he contado todo, forastero.", "No hay mucho más que contar hoy.",
	"Lo de siempre. Vuelve mañana, a ver si hay novedades.", "¿Otra vez? Que tengo cosas que hacer."]

## Lo que cada vecino ha dicho hoy: nombre -> {"day": día, "said": {texto: true}}.
static var _memory := {}


## Las etiquetas del momento para un vecino: la hora, el tiempo, el jugador y lo que sabe.
static func context(villager: Villager, village: Village) -> Dictionary:
	var tags := {}
	var hour := village.hour
	if hour >= 6.0 and hour < 12.0:
		tags["manana"] = true
	elif hour >= 17.0 and hour < 21.0:
		tags["tarde"] = true
	elif hour >= 21.0 or hour < 6.0:
		tags["noche"] = true
	var weather := village.get_tree().get_first_node_in_group("weather") if village.is_inside_tree() else null
	if weather != null and bool(weather.get("raining")):
		tags["lluvia"] = true
	tags["torre%d" % clampi(village.day, 1, 4)] = true
	var player := village.player
	if player != null:
		_player_tags(player, tags)
	var law := village.law
	if law.murderer:
		tags["asesino"] = true
	if law.fine > 0.0:
		tags["multa"] = true
	if law.warnings > 0:
		tags["avisos"] = true
	var discoveries := village.get_tree().get_first_node_in_group("discoveries") as Discoveries \
		if village.is_inside_tree() else null
	if discoveries != null:
		for id: String in discoveries.known:
			tags["sabe:" + id] = true
	if not _memory.has(villager.villager_name):
		tags["primera_vez"] = true
	return tags


static func _player_tags(player: Player, tags: Dictionary) -> void:
	var eq: Dictionary = player.equipment
	if eq.get("shirt", "") == "" and eq.get("chest", "") == "":
		tags["sin_camisa"] = true
	elif eq.get("chest", "") == "" and eq.get("pants", "") == "":
		tags["harapos"] = true
	var hide := 0
	var heavy := 0
	for slot: String in eq:
		var id: String = eq[slot]
		if id.begins_with("ancient_"):
			tags["antiguo"] = true
			heavy += 1
		elif id.begins_with("hide_"):
			hide += 1
	if hide >= 2:
		tags["cuero"] = true
	if heavy >= 3:
		tags["pesado"] = true
	if eq.get("backpack", "") == "backpack":
		tags["mochila"] = true
	var held := player.held_item()
	if GearDB.WEAPONS.has(held):
		tags["armado"] = true
	elif held == "torch":
		tags["antorcha"] = true
	if player.combat != null and player.combat.health < PlayerCombat.MAX_HEALTH * 0.4:
		tags["herido"] = true


## Elige qué dice ahora 'villager' (y lo apunta para no repetirlo hoy). 'bark' = frase corta al pasar.
static func pick(villager: Villager, tags: Dictionary, day: int, rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var memory: Dictionary = _memory.get(villager.villager_name, {})
	if memory.is_empty() or int(memory.get("day", 0)) != day:
		memory = {"day": day, "said": {}}
		_memory[villager.villager_name] = memory
	var said: Dictionary = memory["said"]
	var best: Array = []
	var best_score := 0.0
	for line: Dictionary in LINES:
		var text: String = line["text"]
		if said.has(text) or not _fits(line, villager.job, tags):
			continue
		var required: Array = line.get("all", [])
		# Más concreta (más etiquetas exigidas y de su oficio) = más prioridad; algo de azar.
		var score := float(line.get("weight", 1.0)) * (1.0 + required.size()) \
			* (1.5 if line.has("jobs") else 1.0) * rng.randf_range(0.6, 1.0)
		if score > best_score:
			best_score = score
			best = [text]
	if best.is_empty():
		return NOTHING_NEW[rng.randi() % NOTHING_NEW.size()]
	said[best[0]] = true
	return best[0]


static func _fits(line: Dictionary, job: String, tags: Dictionary) -> bool:
	var jobs: Array = line.get("jobs", [])
	if not jobs.is_empty() and not jobs.has(job):
		return false
	for tag: String in line.get("all", []):
		if not tags.has(tag):
			return false
	for tag: String in line.get("none", []):
		if tags.has(tag):
			return false
	return true


## Para pruebas y al cargar partida: olvidar lo dicho.
static func forget() -> void:
	_memory.clear()
