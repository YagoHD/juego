extends SceneTree
## Prueba de la historia: descubrimientos y deducciones (Discoveries + LoreDB), pistas del mundo
## (Clue) y charla que reacciona (SmallTalk).

var _fails := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok: ", what)
	else:
		_fails += 1
		print("FALLO: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var d := Discoveries.new()
	root.add_child(d)
	var deduced: Array = []
	d.deduced.connect(func(id: String, _t: String) -> void: deduced.append(id))
	# 1. Una pista sola no basta; dos encajan.
	d.learn("naufragio_mar_morado", "diálogo")
	_check(not d.knows("ded_naufragio"), "una pista sola no da la deducción")
	d.learn("quilla_violeta", "pista")
	_check(d.knows("ded_naufragio") and deduced.has("ded_naufragio"), "dos pistas dan la deducción del naufragio")
	_check(not d.learn("quilla_violeta"), "aprender dos veces lo mismo no cuenta")
	# 2. Deducciones en cadena.
	d.learn("ataque_brillo_morado")
	d.learn("mina_brillo_morado")
	_check(d.knows("ded_joyas_umbrita"), "joyas = piedra de la mina")
	d.learn("escudo_valdes")
	_check(d.knows("ded_valdes_mina"), "deducción que usa otra deducción")
	d.learn("torre_brillo")
	_check(d.knows("ded_torre_umbrita"), "la torre necesita la piedra")
	_check(d.entries("ataque").size() >= 3, "entradas del cuaderno por tema")
	# 3. Guardar y cargar.
	var data := d.to_data()
	var d2 := Discoveries.new()
	root.add_child(d2)
	d2.from_data(JSON.parse_string(JSON.stringify(data)))
	_check(d2.knows("ded_torre_umbrita") and d2.known.size() == d.known.size(), "se guarda y se carga")
	d2.queue_free()

	# 4. Pista del mundo: mirándola de cerca se examina y enseña su descubrimiento.
	var clue := Clue.new()
	clue.fact = "joyero_vacio"
	root.add_child(clue)
	clue.global_position = Vector3(0, 1, -2)
	var seen := Clue.looked_at(self, Vector3(0, 1.2, 0), Vector3(0, 0, -1))
	_check(seen == clue, "la pista que se mira")
	_check(Clue.looked_at(self, Vector3(0, 1.2, 0), Vector3(0, 0, 1)) == null, "de espaldas no se ve")
	_check(Clue.looked_at(self, Vector3(0, 1.2, 9), Vector3(0, 0, -1)) == null, "de lejos no se alcanza")
	var said := clue.examine()
	_check(d.knows("joyero_vacio") and said != "", "examinarla apunta el descubrimiento")

	# 5. Charla que reacciona y no repite.
	var village := Village.new()
	root.add_child(village)
	village.hour = 23.0
	village.day = 3
	var farmer := Villager.new()
	farmer.villager_name = "Prueba"
	farmer.job = "farmer"
	var tags := SmallTalk.context(farmer, village)
	_check(tags.has("noche") and tags.has("torre3") and tags.has("sabe:ded_naufragio"), "etiquetas: hora, torre y lo que sabes")
	tags["lluvia"] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var first := SmallTalk.pick(farmer, tags, 3, rng)
	_check(first.to_lower().contains("lluvia") or first.contains("torre") or first.contains("gallinas"),
		"lo más concreto primero (%s)" % first)
	var lines := {first: true}
	var repeated := false
	var finished := false
	for i in 40:
		var text := SmallTalk.pick(farmer, tags, 3, rng)
		if SmallTalk.NOTHING_NEW.has(text):
			finished = true
			break
		if lines.has(text):
			repeated = true
		lines[text] = true
	_check(not repeated and finished, "no repite en el día y al final dice que no hay más (%d frases)" % lines.size())
	_check(not SmallTalk.NOTHING_NEW.has(SmallTalk.pick(farmer, tags, 4, rng)), "al día siguiente vuelve a tener cosas que decir")
	var guard := Villager.new()
	guard.villager_name = "Guardia"
	guard.job = "guard_day"
	var law_tags := {"asesino": true, "manana": true}
	var accused := SmallTalk.pick(guard, law_tags, 1, rng)
	_check(accused.contains("Vete") or accused.contains("Sé lo que"), "si eres un asesino, te lo echan en cara (%s)" % accused)
	farmer.free()
	guard.free()
	print("OK" if _fails == 0 else "FALLOS: %d" % _fails)
	quit()
