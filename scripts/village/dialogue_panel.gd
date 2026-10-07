extends PanelContainer
class_name DialoguePanel
## Ventana de diálogo de estilo RPG: lo que dice el vecino y varias respuestas a escoger (clic o
## teclas 1-9). El contenido está en DialogueDB. Lo que se descubre se apunta en 'knowledge'
## (para el futuro cuaderno). Las acciones (banco, multa, horno) las atiende quien la abre.

signal action_chosen(action: String, villager: Villager)
signal learned(flag: String)
signal closed

var knowledge := {}           # descubrimientos: nombre -> true
var _villager: Villager
var _village: Village
var _name: Label
var _text: Label
var _choices: VBoxContainer
var _current: Array = []      # respuestas que se ven ahora


func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", UiTheme.panel(0.96, 18.0))
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	custom_minimum_size = Vector2(720, 0)
	offset_left = -360
	offset_right = 360
	offset_top = -330
	offset_bottom = -110
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 18)
	_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	column.add_child(_name)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 15)
	column.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	column.add_child(_choices)


func is_open() -> bool:
	return visible


func open(villager: Villager, village: Village) -> void:
	_villager = villager
	_village = village
	_name.text = "%s (%s)" % [villager.villager_name, Village.JOB_NAMES.get(villager.job, villager.job)]
	visible = true
	_show(_root())


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## El saludo: según el oficio y lo que esté haciendo, con las respuestas posibles.
func _root() -> Dictionary:
	var job := _villager.job
	var text: String = DialogueDB.GREETINGS.get(job, "¿Sí?")
	if _villager.activity.begins_with("Durmiendo"):
		text = "¿Eh...? ¿Qué pasa? ¿No ves que es hora de dormir? Bueno, dime."
	var choices: Array = DialogueDB.job_choices(_villager, _village)
	var story: Dictionary = DialogueDB.STORIES.get(_villager.villager_name, {})
	if not story.is_empty():
		choices.append([story["title"], "story:start"])
	choices.append(["¿Qué tal el día?", "daily"])
	choices.append(["Adiós.", ""])
	return {"text": text, "choices": choices}


func _node(id: String) -> Dictionary:
	if id == "root":
		return _root()
	if id == "daily":
		# Charla que reacciona al momento y a ti (SmallTalk); no repite lo ya dicho hoy.
		var text := SmallTalk.pick(_villager, SmallTalk.context(_villager, _village), _village.day)
		return {"text": text, "choices": [["¿Algo más?", "daily"], ["Cuéntame otra cosa.", "root"], ["Adiós.", ""]]}
	if id.begins_with("story:"):
		var story: Dictionary = DialogueDB.STORIES.get(_villager.villager_name, {})
		var node: Dictionary = story.get(id.trim_prefix("story:"), {})
		if node.is_empty():
			return _root()
		# Las respuestas de la historia apuntan a nodos de la misma historia.
		var choices: Array = []
		for choice in node["choices"]:
			var copy: Array = choice.duplicate()
			if str(copy[1]) != "":
				copy[1] = "story:" + str(copy[1])
			choices.append(copy)
		return {"text": node["text"], "choices": choices}
	return {}


func _show(node: Dictionary) -> void:
	if node.is_empty():
		close()
		return
	_text.text = node["text"]
	for child in _choices.get_children():
		child.queue_free()
	_current.clear()
	for choice in node["choices"]:
		var extra: Dictionary = choice[2] if choice.size() > 2 else {}
		if extra.has("requires") and not knowledge.has(extra["requires"]):
			continue
		_current.append(choice)
		var button := Button.new()
		button.text = "%d. %s" % [_current.size(), choice[0]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_choose.bind(_current.size() - 1))
		_choices.add_child(button)


func _choose(index: int) -> void:
	if index < 0 or index >= _current.size():
		return
	var choice: Array = _current[index]
	var extra: Dictionary = choice[2] if choice.size() > 2 else {}
	if extra.has("set") and not knowledge.has(extra["set"]):
		knowledge[extra["set"]] = true
		learned.emit(extra["set"])
	if extra.has("action"):
		var villager := _villager
		close()
		action_chosen.emit(extra["action"], villager)
		return
	var next := str(choice[1])
	if next == "":
		close()
		return
	_show(_node(next))


## Elegir respuesta con las teclas 1-9.
func choose_number(number: int) -> void:
	_choose(number - 1)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if key >= KEY_1 and key <= KEY_9:
		choose_number(key - KEY_0)
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
