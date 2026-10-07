# Diálogos de los vecinos (BORRADOR para que Yago lo corrija)

> Todo el texto está en `scripts/village/dialogue_db.gd`. Basado en `HISTORIA_INICIO_BETA.md` y
> `DESIGN.md`. Los vecinos cuentan **lo que vieron u oyeron**, no la verdad: el jugador deduce.
> Nombres (de personas, de la familia rica, del material morado) provisionales.

## Cómo funciona

- **Clic derecho** a un vecino tranquilo: ventana de diálogo con respuestas a escoger (clic o 1-9).
- Todos saludan según su oficio y cuentan su **día a día** ("¿Qué tal el día?").
- Algunos tienen **historia propia** ("Cuéntame..."), con varias ramas.
- Al pasar cerca, a veces dicen una **frase suelta** sobre la cabeza.
- Lo que se descubre queda **apuntado** (para el futuro cuaderno de detective).
- Desde el diálogo: el guardia cobra la multa, la banquera cambia oro y el herrero enseña el horno.

## Historias y lo que se apunta

| Quién | Historia | Pistas que se apuntan |
|---|---|---|
| Viejo Bermudo (minero retirado) | La **mina abandonada**: al fondo la roca brillaba morada y zumbaba; los mineros soñaban con una torre en el mar; un derrumbe mató a seis y la tapiaron. Hay una galería de ventilación junto a un pino partido por un rayo; dejó dentro su pico. | mina_brillo_morado, mina_suenos_torre, mina_derrumbe, mina_galeria |
| Abuela Urraca (anciana) | Las **ruinas** de "los antiguos": escribían con marcas que nadie entiende (están en piedras del pueblo); vigilaban algo bajo la montaña; "el lago de arriba es un corazón, y el corazón no se toca"; armas que no se oxidan en lo más hondo. | ruinas_antiguos, ruinas_lago_corazon, ruinas_armas |
| Fray Tello (sacerdote) | El **ataque al pueblo pesquero**: soldados por mar, algunos enmascarados, casa por casa; la familia rica de la casa grande junto al faro tenía joyas de un color raro y se negó; no sobrevivió nadie. | ataque_joyas, ataque_familia_muerta |
| Ximena (refugiada) | Lo vio desde la barca: los enmascarados mandaban con gestos; sacaron un cofre que brilló morado y quemaron la casa con la familia dentro. | ataque_mascaras, ataque_brillo_morado |
| Yáñez (refugiado) | Días antes llegó un barco extranjero preguntando por "las piedras"; la noche de la tormenta el mar brilló morado... la noche del naufragio del jugador. | ataque_barco_extranjero, naufragio_mar_morado |
| Ramiro (cazador) | Los ciervos ya no suben por la ladera de la mina; huellas de botas de soldado subiendo hacia ella. | mina_soldados_suben |
| Nuño (tabernero) | Rumores: manda a hablar con Bermudo (mina), con la abuela y la herbolaria (ruinas), y cuenta lo que se dice de la torre. | rumor_torre |

Otros detalles sueltos en el día a día: el mar brilla algunas noches (pescadores), marcas de hacha
y luces en el camino de la mina (leñador, guardia de noche), plantas raras junto a las ruinas
(herbolaria), la campana fundida con bronce de las ruinas (sacerdote).

## Pendiente de decidir con Yago

- ¿Te gusta la mina abandonada con brillo morado? ¿Es el mismo material que buscaban los invasores?
- Nombre de la familia rica, del material morado y de "los antiguos".
- Qué hay dentro de la mina (el pico de Bermudo como recompensa, enemigos, la veta) y de las ruinas.
- Más vecinos con historia propia.
