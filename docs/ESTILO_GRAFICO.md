# Estilo gráfico único

> Problema (2026-10-07): ahora conviven cuatro estilos que no encajan: bloques con texturas de
> píxeles grandes, barco y restos de cubitos pequeños, herramientas de Meshy con aspecto de
> cubitos gruesos, y brazo y personajes de Meshy lisos casi realistas. Hay que elegir **uno** y
> rehacer el arte con él poco a poco. Decide Yago.

## Las tres direcciones posibles

| | A. Todo de cubitos (micro-vóxel) | B. Pintado a mano estilizado | C. Realista pintado |
|---|---|---|---|
| Se parece a | Cube World, Teardown | Valheim, Sea of Thieves, Fortnite | Enshrouded, Vintage Story |
| Mundo | Bloques con textura detallada hecha de cubitos | Bloques con textura pintada, bordes suaves | Bloques con textura casi real, más resolución |
| Personajes, armas, armaduras | Hechos de cubitos pequeños | Lisos, formas algo exageradas, colores vivos | Lisos, proporciones reales, materiales creíbles |
| Lo bueno | Encaja perfecto con un mundo de bloques; muy reconocible | Encaja con Meshy (modelos lisos); envejece bien; lee bien de lejos | Lo que más se parece al brazo y a los personajes de Meshy de ahora; épico para un mundo medieval |
| Lo malo | Los modelos de Meshy habría que pedirlos "de cubitos" (el brazo y los personajes actuales no valdrían) | Hay que repintar los bloques | Los bloques cuadrados cantan más junto a cosas realistas; necesita texturas de más resolución |

**Recomendación de Claude:** B o C. Yago quiere los modelos de Meshy con todo su detalle, y Meshy
da lo mejor con modelos lisos. Entre las dos, **B** es más fácil de mantener coherente con cientos
de piezas y con un mundo de bloques; **C** es más impresionante, pero exige más a cada textura.

## Paso 1: la misma escena en los tres estilos (para comparar)

Pegar en ChatGPT, en **tres conversaciones nuevas** (una por estilo), primero el texto común y
luego el de su estilo. Guardar las imágenes en `docs/estilo/` como `estilo_A.png`, `estilo_B.png`
y `estilo_C.png`.

Texto común (escena):

```
Concept art for a survival game set in a big medieval world built from blocks (like a voxel
world, but each block is half a meter and the terrain is made of them). Wide shot, 16:9.
Scene: a castaway stands on a beach at golden hour next to a wrecked wooden sailing ship. He
holds a stone pickaxe. Behind him, the beach becomes grassland and a forest, a small fishing
village with a bell tower on a hill, and far away a snowy mountain with a dark tower rising
from a violet, corrupted area. In the foreground on the sand: a campfire made of stones, a small
wooden chest, a stone axe, a bundle of rope. The terrain, cliffs and village walls must clearly
be made of blocks, with readable block edges. Same lighting and style for everything: terrain,
character, tools and buildings must look like they belong to the same game.
```

Estilo A:

```
Style: micro-voxel art. EVERYTHING (character, tools, ship, plants, buildings, terrain detail)
is built from small cubes about 6 cm wide, like Cube World or Teardown. Soft global light,
warm natural colors, no outlines.
```

Estilo B:

```
Style: stylized hand-painted 3D, like Valheim's warmth mixed with Sea of Thieves' shapes.
Smooth models with slightly exaggerated proportions (big hands, chunky tools), painted textures
with visible brush strokes, rich saturated but natural colors, soft rim light. The blocks of the
terrain have painted textures and slightly rounded edges.
```

Estilo C:

```
Style: painterly realism, like Enshrouded or a medieval fantasy concept painting. Realistic
human proportions, believable materials (worn wood, wet sand, rough stone, leather, iron),
detailed high-resolution textures on the terrain blocks, atmospheric haze, cinematic lighting.
```

## Paso 2: la biblia de estilo (cuando Yago elija)

Con el estilo elegido, en la misma conversación de ChatGPT:

```
Using exactly the same style as that image, make a STYLE SHEET for the game, 16:9, plain light
background, labeled in Spanish: (1) the castaway, front, side and back views; (2) a village
woman and a village guard; (3) six terrain blocks side by side: grass, sand, dirt, stone, wood
planks, snow; (4) four tools: stone knife, stone axe, stone pickaxe, wooden spear; (5) a leather
armor set and a legendary ancient armor of pale silvery metal with runes; (6) a color palette of
12 swatches with names; (7) one first-person view of the castaway's right arm holding the
pickaxe. Everything must share the same style, lighting and level of detail.
```

Guardar como `docs/estilo/biblia.png`. A partir de ahí:

- **Cada prompt nuevo** (hojas de iconos, texturas, modelos de Meshy) empieza **subiendo
  `biblia.png`** y con la frase: *"Same art style, colors, lighting and level of detail as the
  attached style sheet."* Claude actualizará los prompts de `TEXTURAS.md` y `PROMPTS_MESHY.md`
  con la versión elegida.
- En Meshy, usar la imagen generada con esa biblia como referencia, y pedir siempre el mismo tipo
  de textura.

## Paso 3: qué hay que rehacer (poco a poco)

1. Texturas de los bloques (lo que más se ve). Claude ajusta el tamaño de textura si hace falta.
2. Brazo en primera persona y personajes (hombre y mujer).
3. Herramientas y armas.
4. Barco y restos del naufragio.
5. Lo nuevo (armaduras, animales, enemigos, vecinos) ya sale directamente en el estilo bueno.
6. La interfaz (marcos de madera, iconos) se revisa al final para que acompañe.

## Más adelante: personas por piezas (tipo puzle)

Idea de Yago (2026-10-07), **aplazada** hasta tener el estilo elegido y personajes base bonitos
(los actuales no sirven de base). Como en Skyrim, Mount & Blade o Valheim:

- Un **cuerpo base** (hombre y mujer) con huesos, en el estilo elegido, **calvo y con ropa
  interior neutra**, en pose de T.
- **Piezas sueltas que encajan en ese cuerpo:** caras, pelos, barbas, cascos, corazas, ropa,
  botas, guantes, capas. Pedirlas a Meshy **sobre el mismo maniquí** o trocear personajes
  completos por las articulaciones (`tools/split_character.gd`) y ajustarlos al cuerpo base
  (colocar y escalar; sin quitar detalle: avisar a Yago antes).
- Colores por código: tono de piel, pelo, canas, colores de la ropa y de cada facción.
- Cada vecino o enemigo guarda su **receta** (qué piezas y colores): siempre igual, nunca dos iguales.
