# Texturas y arte del juego: qué está hecho y qué falta

**Regla:** cada vez que se añade al juego un bloque, objeto, animal, efecto o pantalla que
necesite textura o modelo, se apunta aquí. Si no tiene arte de ChatGPT, se añade también a un
prompt de la sección "Prompts pendientes". Así los prompts se van generando a medida que el juego crece.

Estados:
- ✅ **En el juego**: hecho por ChatGPT y ya integrado.
- 🟡 **Dibujado, falta integrar**: ChatGPT ya lo hizo (está en `docs/concept/`), pero el juego aún usa el dibujo antiguo.
- ❌ **Sin arte**: dibujado por código, modelo de Kenney o nada. Va en un prompt pendiente.

Hojas hechas (`docs/concept/`):

| Hoja | Contenido |
|---|---|
| hoja1 | bloques del suelo y de madera |
| hoja2 | bloques del suelo |
| hoja3 | árboles |
| hoja4 | palmeras, rocas y plantas |
| hoja5 | bloques de árbol y animales |
| hoja6 | objetos de recolección |
| hoja7 | herramientas y equipo |
| hoja8 | comida |
| hoja9 | objetos que se colocan |
| hoja10 | decoración, bloques pequeños y objetos sueltos |
| hoja11 | efectos y cielo |
| hoja12 | diario y logo |
| personaje_a / personaje_b | el náufrago (cuerpo) y su ropa en piezas |
| personaje_mujer | la náufraga y su ropa (para cuando haya elección de cuerpo) |

---

## Bloques

| Bloque | Estado | Hoja |
|---|---|---|
| Hierba (y con flores) | ✅ | 1-2 |
| Tierra | ✅ | 1-2 |
| Arena | ✅ | 1-2 |
| Arena mojada | ✅ | 2 |
| Piedra | ✅ | 1-2 |
| Piedra con musgo | ✅ | 1-2 |
| Nieve | ✅ | 1-2 |
| Tierra corrupta | ✅ | 1-2 |
| Mineral verde | ✅ | 1-2 |
| Grava | ✅ | 2 |
| Arcilla | ✅ | 2 |
| Barro | ✅ | 2 |
| Tronco (de pie y tumbado) | ✅ | 1 |
| Tablones (y losas) | ✅ | 1 |
| Madera de deriva | ✅ | 1 |
| Tela / vela | ✅ | 1 |
| Cofre | ✅ | 1 (el modelo 3D se hizo a partir de él) |
| Mesa de trabajo | ✅ | 1 (modelo 3D) |
| Bloque de hojas | ✅ | 5 (nº 1) |
| Bloque de agujas de pino | ✅ | 5 (nº 2) |
| Tronco seco | ✅ | 5 (nº 4) |
| Cultivo de trigo (bloque de tierra con trigo) | 🟡 | 5 (nº 6) |
| Tronco de palmera | 🟡 | 5 (nº 5); aún no existe como bloque |
| Agua (quieta, corriente, cascada) | ❌ | se pinta con un shader animado; sin prompt (no hace falta imagen) |
| Cuerda colgando | 🟡 | 10 (nº 4) |
| Tocón pequeño (el que queda al talar) | 🟡 | 10 (nº 3) |

## Árboles, plantas, rocas y decoración del suelo

| Cosa | Estado | Hoja |
|---|---|---|
| Robles, roble inclinado, árbol gigante, pinos (3), árbol seco, arbustos, arbusto de bayas | ✅ | 3 |
| Palmeras (3), tocón viejo, tronco caído, rocas (3), setas (2), trigo (2) | ✅ | 4 |
| Hierba alta, flor roja, flor amarilla (decoración) | ✅ | 1 |
| Hierba alta de la hoja 4 (nº 11) | 🟡 | 4: aún no está en la isla |
| Piedrecitas del suelo | 🟡 | 10 (nº 1) |
| Palitos del suelo | 🟡 | 10 (nº 2) |
| Brotes de trigo, vela colgando | 🟡 | 10 (nº 5-6) |
| Concha del suelo | 🟡 | 6 (nº 10, el icono sirve de modelo) |

## Animales

| Animal | Estado | Hoja |
|---|---|---|
| Cangrejo | 🟡 | 5 (nº 7); en el juego, modelo hecho por código |
| Gaviota volando / posada | 🟡 | 5 (nº 8-9) |
| Pez tropical pequeño | 🟡 | 5 (nº 10); en el juego, modelo de Kenney |
| Pez grande azul | 🟡 | 5 (nº 11) |
| Escarabajo (insecto) | 🟡 | 5 (nº 12) |
| Cerdo, vaca, jabalí, serpiente, lobo, gato, ciervo, conejo, gallina, cuervo, águila | ❌ | modelos 3D en `PROMPTS_MESHY.md` (animales); ahora son bolas de color |

## Enemigos y personas

| Quién | Estado | Hoja / prompt |
|---|---|---|
| Rastreador, arquero, soldado, capitán, mago (invasores; algunos enmascarados) | ❌ | `PROMPTS_MESHY.md` (enemigos); ahora son bolas de color |
| Guardián de la torre (jefe de piedra) | ❌ | `PROMPTS_MESHY.md` (enemigos) |
| Vecinos (granjero, pescador, mercader) y guardias del pueblo | ❌ | `PROMPTS_MESHY.md` (gente del pueblo); ahora son bolas de color |
| Brazo en primera persona | ✅ | modelo de Meshy (`docs/mano/brazo final hombre`) |

## Objetos (iconos del inventario)

| Objeto | Estado | Hoja / prompt |
|---|---|---|
| Fibra | ✅ | 6 (nº 1) |
| Cuerda | ✅ | 6 (nº 2) |
| Palo | ✅ | 6 (nº 3) |
| Piedra | ✅ | 6 (nº 4) |
| Pedernal | ✅ | 6 (nº 5) |
| Piedra afilada | ✅ | 6 (nº 6) |
| Resina | ✅ | 6 (nº 7) |
| Semillas | ✅ | 6 (nº 8) |
| Insecto | ✅ | 6 (nº 9) |
| Concha | ✅ | 6 (nº 10) |
| Seta | ✅ | 6 (nº 11) |
| Bayas silvestres | ✅ | 6 (nº 12) |
| Cuchillo, hacha y pico de piedra | ✅ | 7 (nº 1-3); en la mano, el dibujo con grosor (ya no el modelo de Kenney) |
| Lanza | ✅ | 7 (nº 4) |
| Antorcha | ✅ | 7 (nº 5) |
| Tabla | ✅ | 7 (nº 6) |
| Camiseta, pantalón, cinturón (icono) | ✅ | 7 (nº 7-9) |
| Mochila improvisada, mochila de marinero (icono) | ✅ | 7 (nº 10-11) |
| Diario del capitán (icono) | ✅ | 7 (nº 12) |
| Pescado crudo y asado | ✅ | 8 (nº 1-2) |
| Cangrejo crudo y asado | ✅ | 8 (nº 3-4) |
| Insecto asado, bayas asadas, semillas tostadas, seta asada | ✅ | 8 (nº 5-8) |
| Torta de pan, manojo de trigo | ✅ | 8 (nº 9-10) |
| Mineral verde (trozo) | ✅ | 8 (nº 11) |
| Notas (cinturón, mochila, pico) | ✅ | 8 (nº 12, la misma para las tres) |
| Hoguera, saco de dormir, balsa (icono) | ✅ | 9 (nº 1, 4, 5) |
| Hoguera, saco de dormir y balsa colocados en el mundo (modelo 3D) | 🟡 | 9 (nº 1-5); ahora son modelos hechos por código |
| Antorcha clavada en el suelo | 🟡 | 9 (nº 6) |
| Hoja, agujas de pino, corteza | 🟡 | 10 (nº 7-9) |
| Flor roja, flor amarilla (recogidas) | 🟡 | 10 (nº 10-11) |
| Coco (aún no es un objeto del juego) | 🟡 | 10 (nº 12) |
| Bloques en la mano (tierra, piedra, tablones...) | ✅ | se dibujan con la textura del bloque |
| Carne cruda y asada, carne de ave cruda y asada | ❌ | hoja 13 (nº 1-4) |
| Piel, hueso, colmillo, pluma, glándula de veneno | ❌ | hoja 13 (nº 5-9) |
| Fragmentos de hierro, polvo arcano, órdenes del capitán, fragmento del ancla | ❌ | hoja 13 (nº 10-12) y hoja 14 (nº 1) |
| Arco, flecha, escudo de madera | ❌ (icono) | hoja 14 (nº 2-4); arco y flecha ya tienen modelo de Meshy |
| Grano de alba (cafeína) | ❌ | hoja 14 (nº 5); la planta en el mundo, modelo en `PROMPTS_MESHY.md` |
| Mochila perdida al morir (en el suelo) | ❌ | modelo en `PROMPTS_MESHY.md`; ahora es una caja marrón |
| Barra de sueño (icono de la luna) | ❌ | hoja 14 (nº 6); ahora sale la palabra "Sueño" |
| Pepita de oro, moneda de oro | ❌ | hoja 15 (nº 1-2) |
| Armaduras y accesorios (iconos): conjunto de piel, capa, colgante, anillo, amuleto, armadura de los antiguos | ❌ | hoja 16; ahora, formas provisionales del color de su rareza |
| Horno de piedra (icono y en el mundo) | ❌ | hoja 15 (nº 3); en el mundo, modelo en `PROMPTS_MESHY.md`; ahora es un bloque gris |

## Personaje

| Cosa | Estado | Prompt |
|---|---|---|
| Cuerpo base (cara, pelo, ropa interior) | ✅ | personaje_a; skin al doble de resolución (tools/extract_skin.gd) |
| Ropa puesta: camisa, pantalón y cinturón | ✅ | personaje_b (capas que se ponen al vestirse) |
| Pañuelo rojo de la cabeza | 🟡 | personaje_b (nº 4); aún no es un objeto del juego |
| Mochilas puestas (modelo 3D a la espalda) | 🟡 | personaje_b (nº 5-6); ahora son cajas de colores |
| Cuerpo de mujer y su ropa | 🟡 | personaje_mujer |
| Armaduras (futuro: corteza...) | ❌ | se añadirán cuando existan |

## Efectos, cielo e interfaz

| Cosa | Estado | Prompt |
|---|---|---|
| Fuego de la hoguera y antorcha, humo | 🟡 | 11 (nº 1-3) |
| Grietas al picar (5 fases) | 🟡 | 11 (nº 6) |
| Trocitos al romper, salpicadura de agua, espuma | 🟡 | 11 (nº 4, 5, 12) |
| Nubes, sol, luna, estrellas, lluvia | 🟡 | 11 (nº 7-11) |
| Paneles, huecos, botones, barras e iconos de la interfaz | ✅ | ui1_piezas, ui2_iconos (tools/extract_ui.gd); pantallas de ejemplo ui3, ui5-ui8; falta ui4 (fabricar) |
| Inventario, fabricación, barra rápida, menús, cofre, HUD, título | 🟡 | prompts para ChatGPT web: `docs/PROMPT_UI_CHATGPT.md` (UI-1 a UI-8) |
| Páginas del diario, logo | 🟡 | 12 |

---

# Prompts pendientes

Cómo usarlos (como siempre):
- Úsalos en la misma conversación de ChatGPT de las hojas anteriores. Si es una conversación nueva, sube antes `docs/concept/hoja2_bloques.png` y pega el prompt 0 de `docs/PROMPT_CONCEPT_ART_2.md`.
- Una hoja cada vez, y guárdala en `docs/concept/` con su número (hoja7_herramientas.png...).
- Las hojas 7, 8 y 9 ya están hechas.

## Hoja 10: lo que faltaba (decoración, bloques pequeños y objetos sueltos)

```
Same style as the block sheets. A clean 4x3 grid of 12 items, one per cell, numbered 1-12 under
each, plain beige background, no ground shadows. Items 1-6 in isometric 3/4 view (they sit in
the world); items 7-12 are INVENTORY ICONS (front view, slightly tilted, centered, filling most
of the cell):
1 small cluster of pebbles lying on the ground
2 a few dry twigs lying crossed on the ground
3 small freshly cut tree stump, flat top with growth rings, short roots
4 thick fiber rope hanging down vertically from above, with a knot at the bottom end
5 young green wheat sprouts (small, just planted)
6 a large piece of sail cloth hanging straight, slightly torn at the edges
7 single green tree leaf
8 small bundle of dark green pine needles
9 curved strip of brown tree bark
10 picked red flower with a short stem
11 picked yellow flower with a short stem
12 coconut, half brown husk
```

## Hoja 13: caza y botín de enemigos (iconos)

```
Same style as the item sheets. A clean 4x3 grid of 12 INVENTORY ICONS, one per cell, numbered
1-12 under each, plain beige background, front view slightly tilted, centered, filling most of
the cell, no ground shadows:
1 a raw red piece of meat with a bit of fat
2 the same piece of meat roasted, golden brown with grill marks
3 a raw bird leg (pale pink)
4 the same bird leg roasted, golden brown
5 a folded brown animal hide
6 a white animal bone
7 a curved ivory boar tusk
8 a single grey-white bird feather
9 a small green venom gland, slightly glossy
10 a handful of rusty iron scraps
11 a small pile of glowing violet arcane dust
12 a rolled parchment with a red wax seal (enemy orders)
```

## Hoja 14: combate y sueño (iconos)

```
Same style as the item sheets. A clean 3x2 grid of 6 INVENTORY ICONS, one per cell, numbered
1-6 under each, plain beige background, front view slightly tilted, centered, no ground shadows:
1 a jagged shard of dark stone with glowing violet veins (anchor shard)
2 a simple wooden bow with a fiber string
3 a wooden arrow with a flint tip and grey feathers
4 a round wooden shield made of planks with a rope-wrapped rim
5 a small cluster of amber glowing coffee-like beans on a green sprig (dawn grain)
6 a small crescent moon icon for a sleep bar, soft violet
```

## Hoja 15: oro y horno (iconos)

```
Same style as the item sheets. A clean 3x1 grid of 3 INVENTORY ICONS, numbered 1-3 under each,
plain beige background, front view slightly tilted, centered, no ground shadows:
1 a small raw gold nugget, rough and shiny
2 a stack of three medieval gold coins with a simple stamped cross
3 a small stone furnace made of stacked rocks and clay, with a dark mouth and a short chimney
```

## Hoja 16: armaduras y accesorios (iconos)

```
Same style as the item sheets. A clean 5x3 grid of 15 INVENTORY ICONS, numbered 1-15 under each,
plain beige background, front view slightly tilted, centered, no ground shadows:
1 a rough leather cap   2 a thick leather vest   3 leather leg guards   4 soft leather boots
5 leather gloves   6 a cloak made of old sail cloth   7 a carved bone pendant on a cord
8 a ring carved from a boar tusk   9 a seashell amulet on a cord
10-14 an ancient legendary armor set made of a pale silvery metal that never rusts, engraved with
strange runes: 10 helm, 11 cuirass with an empty jewel socket in the chest, 12 greaves,
13 boots, 14 gauntlets
15 (leave empty)
```

## Hoja 11: efectos y cielo

```
Same style as the block sheets: chunky voxel cubes, flat painted shading. A clean 4x3 grid,
numbered 1-12 under each, plain beige background, no shadows. These are game EFFECTS seen from
the front:
1 campfire flames made of chunky orange and yellow voxel cubes (no logs, just the fire)
2 small torch flame made of voxel cubes
3 puff of grey smoke made of soft round voxel clumps
4 small brown and grey debris cubes flying apart (a block breaking)
5 water splash made of white and turquoise voxel droplets
6 five stages of cracks on a plain grey square, from a tiny crack to almost shattered, in a row
7 big fluffy white cloud made of voxel cubes
8 blocky voxel sun, warm yellow, glowing
9 blocky voxel moon, pale blue-white, with craters
10 a few small blocky stars, twinkling
11 rain drops made of thin blue voxel streaks
12 white sea foam made of small voxel cubes, as seen from above
```

## Hoja 12: diario y título

```
Same style as before, warm hand-painted look with chunky pixel details. Two images side by side,
plain beige background:
1 an open old leather journal, two yellowed water-stained pages, empty space for text, a rope
  bookmark, seen from the front (it is the background of the in-game journal screen)
2 the game logo "ISLA DEL NAUFRAGIO" in chunky voxel letters made of weathered wooden planks,
  with a small palm tree and a broken ship mast behind it
```

---

## Personaje A: el náufrago base (cuerpo)

El juego usa skins como las de Minecraft (64x64), pero las proporciones las decide el juego: con
esta imagen se ajustan el cuerpo y la cara. El cuerpo base va **en ropa interior** porque la ropa
va en capas aparte, y lo que te pongas (una armadura, por ejemplo) sustituye a esa capa.

```
Same voxel style as the block sheets (chunky cubes, flat hand-painted shading, warm colors,
light from the top-left). Character model sheet of the BASE player character of my survival
game: a young adult man who survived a shipwreck on a tropical island. Blocky voxel body made of
boxes (head, torso, two arms, two legs, like Minecraft/Hytale/Cube World characters) but with
good, slightly heroic proportions: the head a bit big and cute (about 1/5 of the height), broad
shoulders, arms reaching mid-thigh, legs a bit longer than the torso.
Show him THREE times side by side, same size, standing straight with arms slightly away from the
body (T-pose relaxed): FRONT view, SIDE view, BACK view.
He wears ONLY plain dark short underwear (this is the base body; clothes will be separate
layers). Sun-tanned skin, a bit of stubble, messy dark brown hair, friendly brown eyes, a small
scar on one eyebrow. Bare feet.
Plain beige background, no shadows on the ground, no text.
```

## Personaje B: la ropa del náufrago (piezas sueltas)

```
Same character and same style. Now show his clothes as SEPARATE pieces, each one alone in its own
cell, front view, in a clean 3x2 grid numbered 1-6 under each, plain beige background, no shadows.
Each piece must fit exactly on the blocky body from the previous image:
1 torn white-blue sailor shirt, short ripped sleeves, salt stains
2 ragged brown canvas trousers cut below the knee, frayed edges, one patch
3 rope belt with a small knot and a little cloth pouch
4 red bandana tied around the head
5 makeshift backpack made of sail cloth tied with rope
6 canvas sailor backpack with leather straps
Then, below the grid, show the full character from the front wearing pieces 1, 2, 3 and 4.
```

Cuando lleguen las imágenes, ajusto el modelo del cuerpo a las proporciones nuevas. El cuerpo,
la ropa y las mochilas quedan como capas separadas que se cambian solas al vestirse. Más adelante
se podrán añadir la cara, el cuerpo de mujer y las armaduras como capas nuevas.

## Modelos 3D (Meshy)

Objetos en 3D hechos con ChatGPT (imagen) y Meshy (modelo): prompts en `docs/PROMPTS_MESHY.md`. Cada modelo va en `assets/models/items/<id>.glb` y el juego lo pasa a cubitos. Estado: todos pendientes.
