# Prompts 2: árboles, plantas, animales y objetos (para ChatGPT)

Objetivo: que todo lo que se ve en el juego salga del estilo de las hojas 1 y 2, sin depender
de los modelos de Kenney ni de los dibujos antiguos hechos por código.

Cómo usarlos:
- En la **misma conversación** donde se hicieron las hojas de bloques (así copia el estilo). Si
  es una conversación nueva, sube primero `docs/concept/hoja2_bloques.png` y pega el prompt 0.
- Una hoja cada vez. Guardarlas en `docs/concept/` con el número de hoja (hoja3_arboles.png...).
- **Sin sombras en el suelo y fondo liso**: así se recortan bien.
- Si sale mal: "Redo it. Exactly N items in the grid, one per cell, numbered, no shadows,
  plain background, same style as the block sheets."

---

## 0. Estilo (solo si es una conversación nueva; subir antes la hoja de bloques)

```
This image is the official art style of my voxel survival game (a tropical island after a
shipwreck). From now on, every sheet you make must match it exactly: chunky voxel art built
from small cubes, hand-painted pixel shading, warm saturated colors, soft light from the
top-left, details carved INTO the surface (dark grooves, cracks) and details that stick OUT
(grass tufts, moss, crystals). Isometric 3/4 view, plain light beige background (#F0EBE0),
NO drop shadows on the ground, no text except the numbers I ask for. Reply "OK".
```

## 3. Árboles

```
Same style as the block sheets. A clean 3x3 grid of 9 trees, one per cell, numbered 1-9 under
each, isometric 3/4 view, plain beige background, no ground shadows. Trees are built from
chunky voxel cubes: round puffy canopies made of many small leaf cubes with painted
highlights and darker inner shadows, trunks with carved bark grooves and visible roots.
1 leafy oak tree
2 tall leaning oak tree (trunk bends to one side)
3 giant old tree with a very thick trunk, big roots and two side branches
4 tall pine tree with layered cone-shaped foliage
5 small young pine tree
6 pine tree with separated tiers of branches
7 dead dry tree, grey bark, bare twisted branches
8 small round leafy bush
9 large wide bush with berries
```

## 4. Palmeras, rocas y plantas

```
Same style as the block sheets. A clean 4x3 grid of 12 items, one per cell, numbered 1-12
under each, isometric 3/4 view, plain beige background, no ground shadows:
1 tall straight palm tree with coconuts
2 bent palm tree leaning to the side
3 short bushy palm tree
4 old tree stump with roots
5 fallen hollow log
6 large rounded boulder
7 tall standing rock
8 pile of rocks with moss
9 cluster of red mushrooms with white dots
10 cluster of brown mushrooms
11 young green wheat plant
12 ripe golden wheat plant
```

## 5. Bloques de árbol y animales

```
Same style as the block sheets. A clean 4x3 grid, one item per cell, numbered 1-12 under each,
isometric 3/4 view, plain beige background, no ground shadows:
1 leaves block (cube of dense green leaves, leaf shapes sticking out of the surface)
2 pine needles block (dark blue-green)
3 palm leaves block (long light-green fronds)
4 dead wood log block (grey dry bark on the sides, cracked rings on top)
5 palm wood log block (ringed bark)
6 wheat crop block (golden stalks on dark farmland)
7 small red crab
8 white seagull flying, wings open
9 white seagull standing
10 small colorful tropical fish
11 large blue fish
12 small beetle (insect)
```

## 6. Objetos de recolección (iconos)

```
Same style as the block sheets, but these are INVENTORY ICONS: each object seen from the
front, slightly tilted, floating and centered in its cell, filling most of the cell, plain beige
background, no shadow. A clean 4x3 grid, numbered 1-12 under each:
1 bundle of green plant fiber
2 coil of brown fiber rope
3 wooden stick
4 round grey stone
5 dark flint stone with a shiny chipped face
6 sharpened stone flake
7 drop of golden amber resin
8 handful of small seeds
9 green beetle insect
10 seashell
11 single brown mushroom
12 bunch of red wild berries
```

## 7. Herramientas y equipo (iconos)

```
Same style, INVENTORY ICONS (front view, slightly tilted, centered, plain beige background, no
shadow). Everything handmade from what is found on the island, tied with fiber rope. A clean
4x3 grid, numbered 1-12 under each:
1 stone knife (sharp stone blade tied to a short handle)
2 stone axe
3 stone pickaxe
4 spear (long wooden board with a sharp stone tied to the tip)
5 torch (stick with burning resin on top)
6 long thin wooden board
7 torn castaway shirt
8 worn patched trousers
9 rope belt
10 makeshift cloth backpack tied with rope
11 canvas sailor backpack with leather straps
12 captain's journal: old soaked leather book with a strap
```

## 8. Comida (iconos)

```
Same style, INVENTORY ICONS (front view, slightly tilted, centered, plain beige background, no
shadow). A clean 4x3 grid, numbered 1-12 under each:
1 raw fish
2 grilled fish with dark grill marks
3 raw red crab
4 cooked crab (bright orange)
5 roasted insect on a small stick
6 roasted berries (darker, shiny)
7 toasted seeds
8 roasted mushroom
9 round flatbread
10 bundle of golden wheat
11 chunk of glowing green ore
12 crumpled paper note with a drawing
```

## 9. Objetos que se colocan

```
Same style as the block sheets. Isometric 3/4 view, plain beige background, no ground
shadows. A clean 3x2 grid, numbered 1-6 under each:
1 campfire unlit (ring of stones with crossed logs)
2 campfire burning (same, with chunky voxel flames and a little smoke)
3 sleeping bag laid out flat on the ground
4 sleeping bag rolled up and tied
5 small raft made of wooden boards tied with rope
6 torch stuck in the ground, burning
```
