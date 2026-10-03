extends CanvasLayer
class_name TitleScreen
## Pantalla de título y de carga: el nombre del juego sobre la carta de la isla, consejos que
## van cambiando mientras se prepara el mundo y, cuando está listo, los botones Jugar y Salir
## (también Intro o Espacio para jugar).

signal play_pressed
signal quit_pressed

const TIPS := [
	"El diario del capitán está en la arena, cerca del barco.",
	"Abre el inventario (E) y pulsa Fabricar: arrastra los objetos al suelo con la forma de la receta.",
	"En el recetario de Fabricar, elige una receta y verás su forma dibujada en el suelo.",
	"Junto a una mesa de trabajo, el personaje fabrica sobre ella: hay recetas que solo salen ahí.",
	"Si una forma está a medias, verás en transparente lo que falta.",
	"Lo que no sepas hacer, desmóntalo: así se aprende cómo está hecho.",
	"Camiseta, pantalón y cinturón tienen bolsillos: más huecos en la barra.",
	"Con el hacha, los troncos se cortan cuatro veces más rápido.",
	"Mayúsculas + clic recoge de una vez todo un montón del suelo.",
	"Pulsa T para que pase el tiempo más deprisa.",
	"Esc abre el menú de pausa; F1 muestra todos los controles.",
	"Q tira el objeto de la mano; Ctrl + Q, el montón entero.",
]

var _status: Label
var _tip: Label
var _buttons: HBoxContainer
var _tip_index := 0
var _tip_timer := 0.0
var _time := 0.0
var _ready_to_play := false


func _ready() -> void:
	layer = 100  # por encima de todo
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# La carta de la isla de fondo, grande y apagada.
	var map := TextureRect.new()
	map.texture = Journal.sepia_map()
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.modulate = Color(1, 1, 1, 0.22)
	add_child(map)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := PauseMenu.title_label("ISLA DEL NAUFRAGIO", 64)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)
	var subtitle := PauseMenu.title_label("Beta · la isla del tutorial", 18)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.7, 0.55))
	box.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	box.add_child(gap)

	_status = PauseMenu.title_label("", 20)
	box.add_child(_status)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 16)
	_buttons.visible = false
	box.add_child(_buttons)
	var play := PauseMenu.menu_button("Jugar")
	play.custom_minimum_size = Vector2(220, 50)
	play.pressed.connect(func() -> void: play_pressed.emit())
	_buttons.add_child(play)
	var quit := PauseMenu.menu_button("Salir")
	quit.custom_minimum_size = Vector2(160, 50)
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	_buttons.add_child(quit)

	_tip = Label.new()
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tip.offset_left = -420
	_tip.offset_right = 420
	_tip.offset_top = -90
	_tip.offset_bottom = -30
	_tip.add_theme_font_size_override("font_size", 16)
	_tip.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	add_child(_tip)
	_tip_index = randi() % TIPS.size()
	_show_tip()


func set_status(text: String) -> void:
	_status.text = text


## El mundo está listo: aparecen los botones.
func set_ready() -> void:
	_ready_to_play = true
	_status.text = "La isla está lista."
	_buttons.visible = true


func _process(delta: float) -> void:
	_time += delta
	_tip_timer += delta
	if _tip_timer > 5.0:
		_tip_timer = 0.0
		_tip_index = (_tip_index + 1) % TIPS.size()
		_show_tip()
	_tip.modulate.a = clampf(minf(_tip_timer, 5.0 - _tip_timer) * 2.0, 0.0, 1.0)


func _show_tip() -> void:
	_tip.text = "Consejo: " + String(TIPS[_tip_index])


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if _ready_to_play and key != null and key.pressed and not key.echo and key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		play_pressed.emit()
		get_viewport().set_input_as_handled()
