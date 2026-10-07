# Migrar la isla al mapa de ChatGPT (`beta1.png` mapa, `beta2.png` concepto)

> Plan de Claude (2026-10-07). El mapa usa la misma cuadrícula que nuestra isla: 512 × 512 m,
> columnas A–H y filas 1–8 de 64 m, norte = −Z, este = +X. Las coordenadas de abajo están medidas
> sobre `beta1.png` (2,016 px por metro; margen del mapa: x 43, y 75). Son aproximadas (±5 m).

## Lo que ya coincide con nuestra isla (no hay que tocarlo)

| Lugar | Mapa | Nuestra isla |
|---|---|---|
| 1 Naufragio | B7 (−147, 169) | igual |
| 2 Ruinas del noroeste | B2 (−132, −152) | igual (algo más al sur en el mapa) |
| 3 Torre y zona corrupta | E-F 1-2 (125, −206) | la torre se coloca sola en el centro de la corrupción |
| 4 Lago de montaña | F3 (127, −82) | igual (centro algo más al este) |
| 5 Montaña nevada | G4 (172, −6) | igual |
| 7 Campos | C6 (−82, 92) | igual |
| Río | del lago (80, −75) a la costa sureste (94, 179) | ya hay río del lago al mar |

## Lo nuevo del mapa

| Letra | Lugar | Casilla | X, Z (m) | Qué es para la historia |
|---|---|---|---|---|
| A | Pueblo marítimo con muelle | A6 | (−214, 86) | **El pueblo pesquero destruido** (el humo que se ve desde el naufragio): casas quemadas, muelle roto, barco hundido, la casa grande de los Valdés con sus pistas |
| B | Pueblo principal (valle) | B4 | (−127, −16) | **El pueblo habitado** con su campanario, vecinos, guardias, banco, herrero y el campamento de refugiados. *Hoy está reservado en B7: se mueve aquí* |
| C | Minas de la montaña | G5 | (158, 40) | **La mina de Bermudo**: galería derrumbada con umbrita, huellas de soldados subiendo |
| — | Otras minas | E3 (17, −128), H3 (207, −85), F6 (138, 108), E7 (46, 189) | | Minas pequeñas de mineral (hierro, oro, mineral verde) |
| D | Ruinas del noreste | H3 (198, −106) | | Ruinas pequeñas de los antiguos (lore) |
| E | Ruinas centrales | E5 (10, 19) | | Templo de los antiguos en el bosque |
| — | Ruina junto a la playa | D7 (−57, 154) | | Restos con una pista del naufragio |
| F | Puentes del río | E3 (40, −85), F4 (92, −50), E5 (37, 42), E6 (21, 119), F7 (63, 155) | | Cruzar el río por los caminos |
| G | Cascada y garganta | F3 (79, −75) | | Bajada del lago con cristal morado (pista de umbrita) |
| H | Bosque denso | D4 (−29, −43) | | Caza, madera, peligro de lobos |
| J | Atalaya del oeste | D3 (−34, −85) | | Mirador sobre la torre y el pueblo |
| K | Atalaya del este | E6 (72, 96) | | Mirador del río y la montaña |
| L | Campamentos enemigos | alrededor de la torre: (48, −159), (77, −203), (159, −149) | | Ya existe la guarnición por puestos (`garrison.gd`): se colocarán en estos sitios |
| M | Acantilados y faro | A5 (−213, 10) y faro norte A3 (−178, −107) | | Faros del oeste |
| N | Isla pequeña con cueva y faro | A8 (−213, 206) | | Cueva costera con algo escondido |
| — | Zona de animales | E4 (32, −40), G6 (147, 70) | | Ciervos y caza (ya hay fauna) |
| — | Caminos | toda la isla | | Red de caminos de tierra que une todo (ver el mapa); las patrullas del día 4 los recorrerán |

## Cómo migrar (por pasos, cada uno probado)

1. **Caminos y puentes**: dibujar en el terreno los caminos de tierra del mapa (una lista de puntos
   por camino) y poner puentes de madera donde cruzan el río. Registrar los caminos del norte en la
   torre para que las patrullas los recorran (ya está preparado: `TowerDirector.register_road`).
2. **Pueblo principal en B4**: llevar el pueblo de la aldea de pruebas (vecinos, horarios, guardias,
   banco, diálogos, refugiados) a la isla, con casas de bloques y campanario.
3. **Pueblo pesquero destruido en A6**: casas quemadas, muelle roto, humo, la casa de los Valdés con
   las pistas (joyero vacío, escudo, ojo cerrado pintado).
4. **Mina de Bermudo y minas pequeñas**: entradas con vigas, galerías y la veta de umbrita.
5. **Ruinas, atalayas, faros, isla de la cueva** y colocar los campamentos de la torre en sus sitios.

**Ojo con la partida guardada**: si hay que cambiar el relieve (no solo poner cosas encima), el mundo
guardado no se regenera solo. Para lo que va encima (caminos, casas, minas), Claude lo "estampará"
sin borrar lo que hayas construido. Antes de tocar el relieve, se pregunta a Yago.
