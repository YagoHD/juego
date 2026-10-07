extends RefCounted
class_name DialogueDB
## Lo que dicen los vecinos. BORRADOR para que Yago lo corrija (ver docs/DIALOGOS.md): nombres,
## historias y pistas son provisionales y se basan en HISTORIA_INICIO_BETA.md y DESIGN.md. Los
## vecinos cuentan lo que vieron u oyeron, no la verdad del lore: el jugador deduce.
##
## Formato de cada nodo: {"text": lo que dice, "choices": [[respuesta, siguiente, extra], ...]}.
## "siguiente" es otro nodo de la misma historia ("" cierra). "extra" (opcional): "set" apunta un
## descubrimiento (para el futuro cuaderno), "requires" lo exige para mostrar la respuesta, y
## "action" hace algo: "bank" (banco), "pay" (multa), "teach_furnace" (aprender el horno).

## Frases sueltas al pasar a su lado (sobre la cabeza), por oficio.
const BARKS := {
	"farmer": ["¡Buenos días, forastero!", "Este año la cebada viene flaca...", "Uf, la espalda.", "Si llueve esta semana, nos salvamos."],
	"fisher": ["Hoy pican poco.", "¿Has visto qué mar tan raro esta semana?", "Estas redes no se remiendan solas."],
	"merchant": ["¡Género fresco, buen precio!", "Pasa, pasa, mira sin compromiso.", "Desde que cerró la mina, nadie paga en oro."],
	"blacksmith": ["¡Cuidado con las chispas!", "El hierro no espera.", "Si encuentras mineral, tráemelo."],
	"baker": ["¡Pan recién hecho!", "Huele bien, ¿eh?", "Me levanto antes que el gallo."],
	"innkeeper": ["Esta noche hay guiso.", "En mi taberna se oye de todo.", "¿Una jarra, forastero?"],
	"banker": ["El oro no huele.", "Cuentas claras, amistades largas.", "Mal año para los negocios."],
	"woodcutter": ["¡Árbol va!", "Este roble tiene más años que mi abuelo.", "La leña no se corta sola."],
	"hunter": ["Shh... que espantas la caza.", "Algo asusta a los ciervos últimamente.", "Hay huellas que no son de animal."],
	"herbalist": ["Esta hierba cura la tos.", "No toques esa, que pica.", "La montaña da buenas plantas... casi siempre."],
	"priest": ["Que la paz te acompañe.", "Reza por los del pueblo pesquero.", "La campana llama a todos."],
	"elder": ["Ay, en mis tiempos...", "Siéntate, joven, que te cuento.", "Esas ruinas ya eran viejas cuando yo era niña."],
	"old_miner": ["La montaña respira, te lo digo yo.", "Allí arriba no se me ha perdido nada... ya.", "Otra jarra, Nuño."],
	"carpenter": ["Tabla a tabla se hace una casa.", "¿Necesitas algo de madera?", "Esa carreta no se arregla sola."],
	"refugee": ["Gracias por no mirarnos mal.", "Lo perdimos todo.", "Aún huele a humo cuando cierro los ojos."],
	"guard_day": ["Circula, forastero.", "Aquí no queremos problemas.", "Te estoy vigilando."],
	"guard_night": ["Es tarde para pasear.", "De noche, mejor dentro de casa.", "¿Qué haces tú despierto?"],
}

## Cómo saluda cada oficio al hablarle (primera frase del diálogo).
const GREETINGS := {
	"farmer": "¿Qué se te ofrece? Tengo el campo esperando.",
	"fisher": "Hola. Si vienes a por pescado, hoy hay poco.",
	"merchant": "¡Bienvenido! Aquí se compra y se vende de todo... cuando hay con qué pagar.",
	"blacksmith": "¿Sí? Habla rápido, que se enfría el hierro.",
	"baker": "¡Hola, hola! Si tienes hambre, aún queda alguna hogaza.",
	"innkeeper": "Bienvenido a mi taberna. Aquí se bebe, se come y se escucha.",
	"banker": "Buenas. Si traes oro, hablamos de negocios.",
	"woodcutter": "¿Eh? Perdona, con el hacha no te oía.",
	"hunter": "Habla bajo. ¿Qué quieres?",
	"herbalist": "Hola, querido. ¿Te duele algo?",
	"priest": "Que la paz sea contigo, forastero. ¿En qué puedo ayudarte?",
	"elder": "Acércate, acércate, que ya no oigo como antes.",
	"old_miner": "¿Tú también vienes a reírte del viejo Bermudo?",
	"carpenter": "Buenas. Si es por un encargo, tengo cola.",
	"refugee": "¿Sí? Perdona, no estoy acostumbrada a que nos hablen.",
	"guard_day": "Forastero. ¿Algún problema?",
	"guard_night": "¿Qué haces despierto a estas horas?",
}

## "¿Qué tal el día?": de qué hablan según su oficio.
const DAILY := {
	"farmer": ["La cosecha va justa. Desde que vinieron esos soldados al pueblo pesquero, nadie trae sal ni pescado, y sin eso el invierno se hace largo.",
		"Me levanto con el sol, trabajo hasta que se pone, y a la taberna un rato. Así un día y otro."],
	"fisher": ["Antes vendíamos al pueblo pesquero lo que nos sobraba. Ahora ya no hay pueblo al que vender.",
		"El mar está raro. Algunas noches brilla un poco, como si tuviera algo dentro. Mi padre decía que eso trae desgracias."],
	"merchant": ["Poco movimiento. La gente guarda lo que tiene por si vuelven los soldados.",
		"Si consigues pieles o carne, te las cambio. Las monedas escasean, pero algo hay."],
	"blacksmith": ["Herraduras, clavos, alguna hoz. Nada de espadas, gracias a Dios... aunque con lo que pasa, a lo mejor debería empezar.",
		"Me falta mineral. Desde que cerraron la mina de la montaña, el hierro viene de fuera, y caro."],
	"baker": ["Me levanto de madrugada, amaso, horneo y vendo. Lo mejor del día es cuando huele a pan todo el pueblo.",
		"Ahora hago más hogazas: los refugiados también tienen que comer. Fray Tello me paga como puede."],
	"innkeeper": ["Por aquí pasa todo el pueblo, y con la cerveza se sueltan las lenguas. Si quieres saber algo, pregunta.",
		"Últimamente solo se habla de dos cosas: de los soldados y de la torre esa que dicen que ha salido en la isla."],
	"banker": ["Guardo lo que la gente me confía y cambio el oro por moneda. Desde que cerró la mina, entra poco oro.",
		"Si encuentras pepitas, puedo cambiártelas. Te daré un poco menos de lo que valen fundidas, claro: de algo hay que vivir."],
	"woodcutter": ["Corto la leña del pueblo. Del bosque de abajo, eso sí: por la ladera de la montaña ya nadie sube.",
		"Hay árboles en el camino de la mina con marcas de hacha que no son mías. Alguien ha estado subiendo."],
	"hunter": ["Pongo trampas al amanecer y cazo por la tarde. Lo que sobra, lo vendo en el mercado.",
		"Los ciervos ya no suben a la montaña. Algo los asusta allí arriba."],
	"herbalist": ["Recojo hierbas, preparo remedios y escucho quejas. A veces lo segundo cura más que lo primero.",
		"Cerca de las ruinas crecen plantas que no se ven en otro sitio. Mi maestra decía que la tierra allí 'recuerda'."],
	"priest": ["Rezo, toco la campana y ayudo a los refugiados del pueblo pesquero. No da para más un viejo como yo.",
		"La campana de la capilla se fundió con un bronce muy antiguo, sacado de las ruinas. Dicen que por eso suena tan grave."],
	"elder": ["Ya no trabajo, hijo. Me siento en la plaza y miro a la gente. Se aprende mucho mirando.",
		"Este pueblo lo fundaron mis bisabuelos con piedras de las ruinas. Aún se ven marcas raras en algunas paredes."],
	"old_miner": ["Bebo, miro la montaña y vuelvo a beber. Un día de trabajo, para un viejo como yo.",
		"Treinta años picando en esa montaña. Y ahora, ni una pala me dejan tocar."],
	"carpenter": ["Arreglo carretas, tejados y puertas. Desde lo del pueblo pesquero, todos quieren puertas más gruesas.",
		"Las vigas buenas salen del bosque viejo, el que está junto a las ruinas. Pero allí nadie quiere ir a cortar."],
	"refugee": ["Ayudo en el campo a cambio de comida. No es mucho, pero es algo.",
		"Por las noches nos sentamos junto al fuego y contamos a los que faltan. Cada noche, la cuenta es la misma."],
	"guard_day": ["Patrullar, vigilar y aguantar a los borrachos de la taberna. Lo de siempre.",
		"Desde lo del pueblo pesquero, doblamos las rondas. Por si acaso."],
	"guard_night": ["De noche se oyen cosas. Casi siempre es el viento. Casi siempre.",
		"Hace unas noches vi luces subiendo por el camino de la montaña. Cuando llegué, ya no había nadie."],
}

## Historias propias de algunos vecinos, por nombre. Se abren con "Cuéntame..." desde el saludo.
const STORIES := {
	"Viejo Bermudo": {
		"title": "¿Trabajaste en la mina de la montaña?",
		"start": {"text": "¿La mina? Ja. Treinta años allí dentro. Oro, algo de hierro... y otras cosas que mejor no nombrar.", "choices": [
			["¿Qué cosas?", "cosas"], ["¿Por qué la cerraron?", "cierre"], ["Mejor otro día.", ""]]},
		"cosas": {"text": "Allá al fondo, donde ya no llegaba el aire, la roca brillaba. Un brillo morado, como de noche sin luna. Y zumbaba. Los que picaban cerca soñaban cosas... raras.", "choices": [
			["¿Qué soñaban?", "suenos", {"set": "mina_brillo_morado"}], ["¿Por qué la cerraron?", "cierre"], ["Gracias, Bermudo.", ""]]},
		"suenos": {"text": "Una torre. Muy alta, en medio del mar. Todos la misma. Yo también la soñé, ¿sabes? Y ahora dicen que ha salido una así en la isla... No me mires así, no estoy loco.", "choices": [
			["Te creo. ¿Por qué la cerraron?", "cierre", {"set": "mina_suenos_torre"}], ["Adiós, Bermudo.", ""]]},
		"cierre": {"text": "Un derrumbe. Seis compañeros se quedaron dentro. El señor de entonces mandó tapiar la entrada y prohibió subir. Dijeron que fue la montaña, que se cansó de nosotros.", "choices": [
			["¿Se puede entrar todavía?", "entrar", {"set": "mina_derrumbe"}], ["Lo siento mucho.", ""]]},
		"entrar": {"text": "La entrada grande está tapiada. Pero había una galería de ventilación, más arriba, junto a un pino partido por un rayo. Si alguien quisiera entrar... que no seas tú, ¿eh? Allí dentro dejé mi pico, por cierto. El mejor que he tenido.", "choices": [
			["Lo tendré en cuenta.", "", {"set": "mina_galeria"}]]},
	},
	"Abuela Urraca": {
		"title": "¿Qué sabes de las ruinas?",
		"start": {"text": "¿Las ruinas? Eran viejas ya cuando mi abuela era niña. Una fortaleza, o un templo, de gente que vivió aquí mucho antes que nosotros. 'Los antiguos', los llamamos.", "choices": [
			["¿Quiénes eran los antiguos?", "antiguos"], ["¿Hay algo allí?", "tesoro"], ["Gracias, abuela.", ""]]},
		"antiguos": {"text": "Nadie lo sabe. Escribían con unas marcas que nadie entiende; aún se ven en las piedras de algunas casas. La leyenda dice que vigilaban algo bajo la montaña, algo que no debía despertar.", "choices": [
			["¿Qué vigilaban?", "vigilar", {"set": "ruinas_antiguos"}], ["¿Hay algo en las ruinas?", "tesoro"], ["Adiós, abuela.", ""]]},
		"vigilar": {"text": "Mi abuela decía que 'el lago de arriba es un corazón, y el corazón no se toca'. Nunca supe qué quería decir. Ahora, con esa torre, me acuerdo mucho de ella.", "choices": [
			["¿Hay algo en las ruinas?", "tesoro", {"set": "ruinas_lago_corazon"}], ["Gracias, abuela.", ""]]},
		"tesoro": {"text": "Los chiquillos siempre buscaban tesoros. Alguno volvió con una punta de lanza que no se oxidaba nunca. Dicen que en lo más hondo hay armas de los antiguos. Pero también dicen que no todos los que bajan vuelven.", "choices": [
			["Iré con cuidado.", "", {"set": "ruinas_armas"}]]},
	},
	"Fray Tello": {
		"title": "¿Qué les pasó a los del pueblo pesquero?",
		"start": {"text": "Una desgracia. Llegaron soldados por mar, con la cara tapada algunos. Buscaban algo. Casa por casa.", "choices": [
			["¿Qué buscaban?", "buscaban"], ["¿Cuántos se salvaron?", "salvados"], ["Que descansen en paz.", ""]]},
		"buscaban": {"text": "No lo sé con certeza. Los refugiados hablan de la familia más rica del pueblo, los de la casa grande junto al faro. Que tenían joyas, unas joyas de un color raro. Y que se negaron a entregarlas.", "choices": [
			["¿Qué pasó con esa familia?", "familia", {"set": "ataque_joyas"}], ["¿Cuántos se salvaron?", "salvados"], ["Gracias, padre.", ""]]},
		"familia": {"text": "No sobrevivió nadie de la casa grande. Que Dios los tenga. Pregunta a los del campamento si quieres saber más; yo solo sé lo que me cuentan.", "choices": [
			["Lo haré.", "", {"set": "ataque_familia_muerta"}]]},
		"salvados": {"text": "Unos pocos, los que estaban en el mar o corrieron al bosque. Están en el campamento, junto al pueblo. Les damos lo que podemos.", "choices": [
			["¿Qué buscaban los soldados?", "buscaban"], ["Gracias, padre.", ""]]},
	},
	"Ximena": {
		"title": "¿Viste el ataque?",
		"start": {"text": "Lo vi todo desde la barca. Era de noche, pero las casas ardían y se veía como de día.", "choices": [
			["¿Cómo eran los soldados?", "soldados"], ["Lo siento mucho.", ""]]},
		"soldados": {"text": "Unos llevaban máscaras lisas, sin cara. Otros no: gente normal, como tú y como yo. Los de las máscaras no gritaban. Mandaban con gestos, y los otros obedecían.", "choices": [
			["¿Qué se llevaron?", "llevaron", {"set": "ataque_mascaras"}], ["Gracias por contármelo.", ""]]},
		"llevaron": {"text": "De la casa grande sacaron un cofre. Cuando lo abrieron, brilló morado. El de la máscara lo levantó como si fuera sagrado. Luego... luego quemaron la casa con la familia dentro.", "choices": [
			["Lo siento, Ximena.", "", {"set": "ataque_brillo_morado"}]]},
	},
	"Yáñez": {
		"title": "¿Cómo acabaste aquí?",
		"start": {"text": "Era pescador. Tenía barca, casa y mujer. Ahora tengo esta manta y gracias.", "choices": [
			["¿Viste algo raro antes del ataque?", "raro"], ["Lo siento.", ""]]},
		"raro": {"text": "Unos días antes llegó un barco de fuera a la cala. Preguntaron por la familia de la casa grande, por las 'piedras'. Pagaron con monedas que nadie conocía. Y luego, la noche de la tormenta, el mar se puso a brillar... morado.", "choices": [
			["¿La noche de la tormenta?", "tormenta", {"set": "ataque_barco_extranjero"}], ["Gracias, Yáñez.", ""]]},
		"tormenta": {"text": "La misma noche que hubo un naufragio en la isla, dicen. ¿Era el tuyo? Pues tuviste suerte. O no, según se mire.", "choices": [
			["Según se mire.", "", {"set": "naufragio_mar_morado"}]]},
	},
	"Ramiro": {
		"title": "¿Qué asusta a los animales?",
		"start": {"text": "No lo sé, y eso es lo que me preocupa. Los ciervos ya no suben por la ladera de la mina. Y he visto huellas.", "choices": [
			["¿Qué huellas?", "huellas"], ["Ten cuidado.", ""]]},
		"huellas": {"text": "De botas. Muchas, en fila, subiendo hacia la mina vieja. Botas buenas, de soldado. Nadie del pueblo sube allí, eso te lo aseguro.", "choices": [
			["¿Hacia la mina?", "", {"set": "mina_soldados_suben"}]]},
	},
	"Nuño": {
		"title": "¿Qué rumores corren?",
		"start": {"text": "Uy, rumores hay para llenar barriles. ¿Qué quieres oír?", "choices": [
			["Algo de la mina.", "mina"], ["Algo de las ruinas.", "ruinas"], ["Algo de la torre.", "torre"], ["Nada, gracias.", ""]]},
		"mina": {"text": "El viejo Bermudo jura que la montaña respira. Está medio loco, pero cuando bebe cuenta cosas de la mina que ponen los pelos de punta. Pregúntale a él.", "choices": [
			["¿Y de las ruinas?", "ruinas"], ["Gracias, Nuño.", ""]]},
		"ruinas": {"text": "La abuela Urraca es la que más sabe. Y la herbolaria dice que allí crecen plantas raras. Yo no me acerco ni borracho.", "choices": [
			["¿Y de la torre?", "torre"], ["Gracias, Nuño.", ""]]},
		"torre": {"text": "Dicen que salió del suelo en la isla, de la noche a la mañana, y que cada día está más alta. Y que alrededor la hierba se muere. Yo no la he visto, pero los pescadores sí.", "choices": [
			["Gracias, Nuño.", "", {"set": "rumor_torre"}]]},
	},
}


## Respuestas propias del oficio en el saludo (banco, multa, enseñar el horno...).
static func job_choices(villager: Villager, village: Village) -> Array:
	var choices: Array = []
	if villager.species == "guard" and village.law.fine > 0.0 and not village.law.murderer:
		choices.append(["Vengo a pagar la multa.", "", {"action": "pay"}])
	if villager.job == "banker":
		choices.append(["Quiero cambiar oro por monedas.", "", {"action": "bank"}])
	if villager.job == "blacksmith":
		choices.append(["¿Cómo se funde el oro?", "", {"action": "teach_furnace"}])
	return choices
