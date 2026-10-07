# Arte del juego: lo que hay que pedir a ChatGPT (estilo nuevo)

> Rehecho el 2026-10-07 con el **estilo elegido**: Minecraft Dungeons en primera y tercera persona
> (`docs/estilo/escena_elegida.webp`, `docs/estilo/biblia.webp`, `docs/ESTILO_GRAFICO.md`).
> Todo el arte anterior (`docs/concept/`, hojas 1-16) era de otro estilo: **se rehace todo**.
> Los modelos de Meshy quedan en pausa (`PROMPTS_MESHY.md`): con este estilo casi todo se hace
> con imágenes de ChatGPT, y Meshy solo para alguna cosa especial.

## Cómo pedir cada imagen

1. Conversación **nueva** de ChatGPT. Sube `escena_elegida.webp` y `biblia.webp` y pega el
   **prompt 0**. Pide todo lo demás **en esa misma conversación**, una imagen por mensaje.
2. Si se desvía del estilo, vuelve a subir las dos imágenes y escribe: *"Same style as the
   reference images: simpler, bigger blocks, no tiny cubes."*
3. Guarda cada imagen en `docs/estilo/` con el nombre de la lista y súbela (o pégala en el chat).
4. Marca aquí ✅ lo que ya esté pedido y bien.

## Lista (en este orden)

| # | Archivo | Qué es | Estado |
|---|---|---|---|
| 1 | `guia_01` a `guia_07` | Escenas de referencia del mundo | ⬜ |
| 2 | `tex_suelo.png` | Bloques del suelo (16) | ⬜ |
| 3 | `tex_madera.png` | Bloques de madera, hojas, cofre, mesa (16) | ⬜ |
| 4 | `tex_construccion.png` | Bloques de construcción (16) | ⬜ |
| 5 | `plantas.png` | Plantas y cosas pequeñas del suelo (16) | ⬜ |
| 6 | `arboles.png` | Árboles (6) | ⬜ |
| 7 | `personaje_vistas.png` | El náufrago de frente, lado y espalda | ⬜ |
| 8 | `personaje_base.png` | Cuerpo base hombre y mujer (para vestirlos) | ⬜ |
| 9 | `caras_pelos.png` | Caras y peinados (para vecinos distintos) | ⬜ |
| 10 | `brazo.png` | Brazo en primera persona | ⬜ |
| 11 | `iconos_materiales.png` | Iconos: materiales (16) | ⬜ |
| 12 | `iconos_herramientas.png` | Iconos: herramientas, armas y objetos que se colocan (16) | ⬜ |
| 13 | `iconos_comida.png` | Iconos: comida (16) | ⬜ |
| 14 | `iconos_botin.png` | Iconos: caza, botín y ropa (16) | ⬜ |
| 15 | `iconos_equipo.png` | Iconos: armaduras y accesorios (14) | ⬜ |
| 16 | `equipo_puesto.png` | Las armaduras puestas en el personaje | ⬜ |
| 17 | `objetos_mundo.png` | Hoguera, cofre, mesa, horno, saco, balsa... en el mundo | ⬜ |
| 18 | `naufragio.png` | El barco naufragado y sus restos | ⬜ |
| 19 | `edificios.png` | Edificios del pueblo | ⬜ |
| 20 | `animales.png` | Animales (12) | ⬜ |
| 21 | `enemigos.png` | Invasores y jefe (6) | ⬜ |
| 22 | `vecinos.png` | Gente del pueblo por oficios | ⬜ |
| 23 | `efectos_cielo.png` | Cielo, fuego, humo, chispas, agua, corrupción | ⬜ |
| 24 | `interfaz.png` | Pantalla de inventario y barra de abajo | ⬜ |

Con 1 a 4 Claude ya puede empezar a rehacer el mundo; con 7 y 10, el personaje y el brazo.

---

## 0. Ancla de estilo (pegar primero, con las dos imágenes)

```
These two images are the art style reference for my game. From now on, every image you make
must use EXACTLY this style: the look of Minecraft Dungeons, but for a game played in first and
third person: a simple blocky world with BIG clean blocks (half a meter each), chunky characters
with slightly big heads, rich hand-painted pixel textures, and warm cinematic lighting (golden
light, soft shadows, light haze, glowing particles, clear turquoise water). Never fill things
with tiny cubes: keep shapes big and simple, like the first image. Same color palette as the
style sheet. Reply "OK" and wait for my requests.
```

## 1. Escenas de referencia (una por mensaje, 16:9)

| Archivo | Prompt |
|---|---|
| `guia_01_bosque.png` | A forest with oak and pine trees next to a small river with a waterfall, daytime, deer in the distance, berry bushes, tall grass and a fallen log. |
| `guia_02_pueblo.png` | The main street of a medieval fishing and farming village: houses of stone and timber, a market with stalls, a tavern with a sign, a forge with smoke, villagers walking, a guard, the bell tower at the end. |
| `guia_03_mina.png` | A snowy mountain slope with the boarded-up entrance of an old abandoned mine, rails and a broken cart, a pine tree split by lightning, a faint violet glow inside. |
| `guia_04_ruinas.png` | Ancient ruins of a forgotten people in an old forest: mossy stone walls with strange carved runes, broken columns, a sealed doorway, roots everywhere. |
| `guia_05_corrupcion.png` | The corrupted zone: dark violet cracked ground, dead trees, violet ash falling, the dark tower rising in the middle with enemy tents around it. |
| `guia_06_noche.png` | Night inside a small player-built wooden shelter: a bed, a chest, a campfire, a torch on the wall, moonlight through the door. |
| `guia_07_jugando.png` | First-person gameplay screenshot: the player's blocky arm holding a stone pickaxe, mining a stone wall, a simple wooden hotbar at the bottom, small hunger, thirst and sleep bars. |

## 2-4. Texturas de los bloques

Pegar **primero este texto** y, justo detrás, la lista de la hoja:

```
Make a texture sheet for my game's blocks, in the same style. Rules: a grid of 4 columns x 4
rows of SQUARE textures, each seen perfectly flat from the front (no perspective, no 3D, no
lighting or shadows on them), seamless and tileable, pixel art with 32x32 pixels per texture
shown with hard pixel edges, a thin plain gap between them and the name written under each.
Textures:
```

`tex_suelo.png`:
```
1 grass (top)  2 grass (side, dirt below)  3 grass with tiny flowers (top)  4 dirt  5 sand
6 wet sand  7 gravel  8 clay  9 mud  10 snow (top)  11 snow (side, dirt below)  12 stone
13 mossy stone  14 green ore in stone  15 gold ore in stone  16 corrupted violet soil
```

`tex_madera.png`:
```
1 oak log bark  2 oak log cut end with rings  3 dead tree bark  4 dead tree cut end  5 driftwood
6 wooden planks  7 oak leaves  8 pine needles  9 chest front  10 chest side  11 chest top
12 workbench top  13 workbench side  14 sail cloth  15 straw bale  16 wooden plank slab (side)
```

`tex_construccion.png`:
```
1 cobblestone  2 stone bricks  3 cracked stone bricks  4 ancient ruin stone with runes
5 timber frame wall with plaster  6 red roof tiles  7 thatched roof  8 window with wooden frame
9 wooden door top half  10 wooden door bottom half  11 iron block  12 gold block  13 glass
14 white wool  15 dark tower stone  16 violet glowing crystal
```

## 5. Plantas y cosas pequeñas del suelo — `plantas.png`

```
In the same style, a sheet of 16 small plants and ground details, each drawn flat from the
front like a Minecraft "cross" sprite, pixel art 32x32 pixels each, on a plain magenta (#FF00FF)
background so I can cut them out, 4x4 grid with names: tall grass, red flower, yellow flower,
pebbles, dry twigs, seashell, wheat sprout, half-grown wheat, ripe wheat, red mushrooms, brown
mushrooms, berry bush, small bush, fern, sapling, dawn grain plant (glowing amber beans).
```

## 6. Árboles — `arboles.png`

```
In the same style, 6 trees side by side seen from the side, made of big blocks: an oak, a big
oak, a pine, a palm tree, a dead tree, a corrupted violet dead tree. Plain light background.
```

## 7-9. Personajes

`personaje_vistas.png`:
```
Character turnaround of the castaway in the same blocky style: strictly orthographic FRONT,
LEFT SIDE, BACK and RIGHT SIDE views side by side, standing straight with arms down, same size,
plain light background, no perspective. Simple big blocky shapes (head, torso, two arms, two
legs), like Minecraft Dungeons with a slightly bigger head. Curly brown hair, light torn shirt,
crossed strap, brown trousers, boots.
```

`personaje_base.png`:
```
The same kind of turnaround (front, side, back) but as a BASE body for customization: bald,
neutral face, simple light underwear, no accessories. First a man, then a woman, same proportions.
```

`caras_pelos.png`:
```
A sheet of 12 different faces (front view, same blocky head) and 12 hairstyles (front and
side): men and women, young and old, different skin tones, some with beards. Same style.
```

## 10. Brazo en primera persona — `brazo.png`

```
4 first-person views in the same style: the player's blocky right arm with a torn shirt sleeve,
bottom right of the screen: (1) empty hand relaxed, (2) holding a stone pickaxe, (3) holding a
grass block, (4) holding a torch.
```

## 11-15. Iconos del inventario

Pegar **primero este texto** y luego la lista:

```
A sheet of 16 inventory icons in the same style: each a small chunky blocky object seen slightly
from above, centered, plain light background, 4x4 grid with the name under each:
```

`iconos_materiales.png`:
```
plant fiber, rope coil, sticks, stone, flint, sharp rock, amber resin, seeds, seashell, leaf,
pine needles, bark, wooden plank, green ore chunk, gold nugget, gold coins
```

`iconos_herramientas.png`:
```
stone knife, stone axe, stone pickaxe, spear, torch, wooden bow, arrow, round wooden shield,
campfire, bedroll, raft, stone furnace, old leather journal, folded note, makeshift backpack,
sailor backpack
```

`iconos_comida.png`:
```
wild berries, roasted berries, mushroom, roasted mushroom, beetle, roasted beetle, toasted
seeds, raw fish, grilled fish, raw crab, cooked crab, wheat bundle, flatbread, raw meat,
roasted meat, raw bird leg
```

`iconos_botin.png`:
```
roasted bird leg, animal hide, bone, boar tusk, feather, venom gland, rusty iron scraps, violet
arcane dust, sealed parchment orders, dark shard with violet veins, dawn grain beans, red flower,
yellow flower, torn shirt, trousers, leather belt
```

`iconos_equipo.png`:
```
leather cap, leather vest, leather leg guards, leather boots, leather gloves, sail cloth cloak,
bone pendant, boar tusk ring, seashell amulet, ancient helm, ancient cuirass, ancient greaves,
ancient boots, ancient gauntlets (the ancient set: pale silvery metal with glowing runes)
```

## 16. Equipo puesto — `equipo_puesto.png`

```
The castaway (front and back) wearing, in this order: (1) his normal clothes, (2) the full
leather armor set, (3) the full ancient legendary armor of pale silvery metal with glowing
runes. Same style and proportions, plain light background.
```

## 17. Objetos en el mundo — `objetos_mundo.png`

```
In the same style, a sheet of objects placed in the world, three-quarter view, plain light
background, with names: campfire (lit), stone furnace (lit), wooden chest (closed and open),
workbench, bedroll on the ground, torch stuck in the ground, log raft, barrel, crate, broken
crate, rope hanging, wall torch.
```

## 18. Naufragio — `naufragio.png`

```
The wrecked sailing ship on the beach in the same style, from 3 angles (front, side,
three-quarter), made of BIG blocks (no tiny cubes): broken hull, tilted masts, torn sails,
planks, crates, barrels and a chest scattered on the sand.
```

## 19. Edificios — `edificios.png`

```
In the same style, village buildings at three-quarter view: small house, big house, tavern,
forge, bakery, chapel with bell tower, wooden pier, guard barracks, market stall, refugee tent.
```

## 20-22. Criaturas y gente

`animales.png`:
```
In the same style, animals made of big blocks, side view: pig, cow, boar, wolf, deer, rabbit,
hen, cat, snake, seagull, crow, eagle.
```

`enemigos.png`:
```
In the same style, the invaders, front view: hooded scout, archer, soldier in iron armor,
captain with a cape, masked mage in violet robes with a smooth mask, and a huge stone golem
with a glowing violet crystal core.
```

`vecinos.png`:
```
In the same style, villagers front view: farmer, fisherman, merchant, blacksmith, baker,
innkeeper, banker, woodcutter, hunter, herbalist woman, old priest, old woman, old miner,
carpenter, refugee woman, village guard.
```

## 23. Efectos y cielo — `efectos_cielo.png`

```
In the same style, a sheet of effects with names: day sky gradient, sunset sky gradient, night
sky with stars, blocky clouds, square sun, square moon, flames (3 frames), smoke puffs, sparks,
water splash, falling leaves, violet corruption ash, rain drops, block breaking cracks (4 stages).
```

## 24. Interfaz — `interfaz.png`

```
In the same style, a mockup of the game's inventory screen: wooden panel with metal corners,
leather item slots, an equipment column with a character preview, a 3D item preview on the
right, and the bottom hotbar with hunger, thirst and sleep icons. Clean and readable.
```
