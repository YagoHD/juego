extends VBoxContainer
class_name OfferPanel
## Panel lateral de la pantalla de pago (como en Kingdom Come): se arrastran objetos o monedas a
## "Lo que entregas", se ve cuánto vale lo ofrecido y se paga. Dos usos:
##   "fine": pagar una multa a un guardia (si se ofrece de más, devuelve el cambio en monedas);
##   "bank": cambiar pepitas de oro por monedas, con algo de pérdida (el horno da el 100%).
## Lo que quede en la oferta al cerrar vuelve al inventario (lo hace quien abre la pantalla).

const BANK_RATE := 1.5         # monedas por pepita en el banco (fundida en el horno da 2)

var offer := Inventory.new(9)  # lo que se entrega
var mode := "fine"
var _player: Player
var _screen: InventoryScreen
var _village: Village
var _info: Label
var _button: Button


func _init(player: Player, screen: InventoryScreen, village: Village, kind: String, who: String) -> void:
	_player = player
	_screen = screen
	_village = village
	mode = kind
	add_theme_constant_override("separation", 8)
	custom_minimum_size = Vector2(220, 0)
	var title := Label.new()
	title.text = ("Pagar la multa a %s" % who) if mode == "fine" else ("Banco de %s" % who)
	title.add_theme_font_size_override("font_size", 18)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(title)
	var help := Label.new()
	help.text = "Arrastra a «Lo que entregas» los objetos o monedas con los que pagas." if mode == "fine" \
		else "Arrastra pepitas de oro a «Lo que entregas»: el banco las cambia a %.1f monedas cada una (fundidas en un horno valen 2)." % BANK_RATE
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72))
	add_child(help)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 14)
	add_child(_info)
	_button = Button.new()
	_button.text = "Pagar" if mode == "fine" else "Cambiar"
	_button.pressed.connect(_on_pressed)
	add_child(_button)
	offer.changed.connect(_update)
	_update()


## Las secciones de la pantalla: la oferta encima y el inventario del jugador debajo.
func sections() -> Array[Dictionary]:
	var inv := _player.active_inventory()
	return [
		{"title": "Lo que entregas", "inventory": offer, "columns": 9, "slots": range(offer.size())},
		{"title": "Inventario", "inventory": inv, "columns": 9, "slots": range(Hotbar.SLOTS, Hotbar.SLOTS + _player.storage_size())},
		{"title": "Barra rápida", "inventory": inv, "columns": 9, "slots": range(0, _player.hotbar_size())},
	]


func offered_value() -> float:
	var total := 0.0
	for i in offer.size():
		var stack := offer.get_slot(i)
		if not stack.is_empty():
			total += VillageLaw.value_of(stack["id"]) * int(stack["count"])
	return total


func _update() -> void:
	if mode == "fine":
		var owed := _village.law.fine
		_info.text = "Debes: %d monedas\nOfreces: %.1f" % [ceili(owed), offered_value()]
		_button.disabled = offered_value() < owed or owed <= 0.0
	else:
		var nuggets := offer.count_of("gold_nugget")
		_info.text = "Pepitas: %d\nRecibes: %d monedas" % [nuggets, floori(nuggets * BANK_RATE)]
		_button.disabled = nuggets == 0


func _on_pressed() -> void:
	if mode == "fine":
		var change := _village.law.pay_offer(offered_value())
		if change < 0.0:
			return
		offer.clear()
		_give("gold_coin", floori(change))
	else:
		var nuggets := offer.count_of("gold_nugget")
		for i in offer.size():
			if not offer.is_empty_slot(i) and offer.get_slot(i)["id"] == "gold_nugget":
				offer.set_slot(i, {})
		_give("gold_coin", floori(nuggets * BANK_RATE))
		_player.notice.emit("El banco te da %d monedas por %d pepitas." % [floori(nuggets * BANK_RATE), nuggets])
	_screen.close()


## Da al jugador lo que reciba (cambio o monedas del banco); lo que no quepa, al suelo.
func _give(id: String, count: int) -> void:
	if count <= 0:
		return
	var left := _player.pick_up(id, count)
	if left > 0:
		ItemDrop.spawn(_player.get_parent(), _player.global_position + Vector3.UP, id, left)


## Devuelve al inventario lo que quedó en la oferta (al cerrar sin pagar, o lo no aceptado).
func return_offer() -> void:
	for i in offer.size():
		var stack := offer.get_slot(i)
		if stack.is_empty():
			continue
		var left := _player.inventory.add_stack(stack, _player.unlocked_slots())
		if left > 0:
			var rest := stack.duplicate(true)
			rest["count"] = left
			ItemDrop.throw_stack(_player.get_parent(), _player.eye_position(), -_player.global_basis.z, rest)
		offer.set_slot(i, {})
