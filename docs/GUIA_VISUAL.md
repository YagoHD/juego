# Guía visual: prompts para ChatGPT (antes de rehacer nada)

> Decidido con Yago (2026-10-07): primero una **guía de referencia** completa hecha con ChatGPT
> en el estilo elegido (`docs/estilo/escena_elegida.webp`: sencillo tipo Minecraft, bloques
> grandes, luz de cine). Después, Claude rehace el juego guiándose por ella.

## Cómo usarlo

1. Conversación **nueva** de ChatGPT. Sube `docs/estilo/escena_elegida.webp` y
   `docs/estilo/biblia.webp` y pega el **prompt 0**. Usa esa misma conversación para todo lo demás
   (así no se le olvida el estilo). Si se empieza a desviar, vuelve a subir las dos imágenes.
2. Pide **una imagen por mensaje**, en el orden de abajo.
3. Guarda cada imagen en `docs/estilo/` con el nombre que pone (`guia_01_bosque.png`...) y súbelas.
4. Si una sale mal: *"Redo it: same style as the reference images, simpler, bigger blocks, no tiny cubes."*

---

## 0. Ancla de estilo (pegar primero)

```
These two images are the art style reference for my game. From now on, every image you make
must use EXACTLY this style: the look of Minecraft Dungeons, but for a game played in first and
third person: a simple blocky world with BIG clean blocks (half a meter each), chunky characters
with slightly big heads, rich hand-painted pixel textures, and warm cinematic lighting (golden
light, soft shadows, light haze, glowing particles, clear turquoise water). Never fill things with tiny
cubes: keep shapes big and simple, like the first image. Same color palette as the style sheet.
Reply "OK" and wait for my requests.
```

## 1. Escenas de referencia del mundo (una por mensaje)

| Archivo | Prompt |
|---|---|
| `guia_01_bosque.png` | Wide shot, 16:9: a forest with oak and pine trees next to a small river with a waterfall, daytime, deer in the distance, berry bushes and tall grass, a fallen log. |
| `guia_02_pueblo.png` | 16:9: the main street of a medieval fishing and farming village: houses of stone and timber, a market with stalls, a tavern with a sign, a forge with smoke, villagers walking, a guard, the bell tower at the end. |
| `guia_03_mina.png` | 16:9: a snowy mountain slope with the boarded-up entrance of an old abandoned mine, rails and a broken cart, a pine tree split by lightning, a faint violet glow inside. |
| `guia_04_ruinas.png` | 16:9: ancient ruins of a forgotten people in an old forest: mossy stone walls with strange carved runes, broken columns, a sealed doorway, roots everywhere. |
| `guia_05_corrupcion.png` | 16:9: the corrupted zone: dark violet cracked ground, dead trees, violet ash falling, and the dark tower rising in the middle with enemy tents around it. |
| `guia_06_noche.png` | 16:9: night inside a small player-built wooden shelter: a bed, a chest, a campfire, a torch on the wall, moonlight through the door. |
| `guia_07_jugando.png` | 16:9: first-person gameplay screenshot: the player's blocky arm holding a stone pickaxe, mining a stone wall, a simple wooden hotbar at the bottom, small hunger and thirst bars. |

## 2. Texturas de los bloques (lo primero que se rehace)

Para que Claude pueda recortarlas, cada hoja debe ser **plana y ordenada**:

```
Make a texture sheet for my game's blocks, in the same style. Rules: a grid of 4 columns x 4
rows of SQUARE textures, each one seen perfectly flat from the front (no perspective, no
3D, no lighting or shadows on them), seamless and tileable, pixel art with 32x32 pixels per
texture shown with hard pixel edges, a thin plain gap between them and the name written under
each. Textures:
```

Hoja `guia_10_bloques_suelo.png` (pegar a continuación):

```
1 grass (top)  2 grass (side, with dirt below)  3 grass with tiny flowers (top)  4 dirt
5 sand  6 wet sand  7 gravel  8 clay  9 mud  10 snow (top)  11 snow (side, with dirt below)
12 stone  13 mossy stone  14 green ore in stone  15 gold ore in stone  16 corrupted violet soil
```

Hoja `guia_11_bloques_madera.png`:

```
1 oak log bark  2 oak log cut end (rings)  3 dead tree bark  4 dead tree cut end
5 driftwood  6 wooden planks  7 oak leaves  8 pine needles leaves  9 chest front
10 chest side  11 chest top  12 workbench top  13 workbench side  14 sail cloth
15 straw/wheat bale  16 rope coil (top)
```

Hoja `guia_12_bloques_construccion.png`:

```
1 cobblestone  2 stone bricks  3 cracked stone bricks  4 ancient ruin stone with runes
5 timber frame wall (plaster)  6 roof tiles (red)  7 thatched roof  8 window with wooden frame
9 wooden door (top half)  10 wooden door (bottom half)  11 iron block  12 gold block
13 glass  14 wool (white)  15 dark tower stone  16 violet glowing crystal
```

## 3. Plantas y cosas pequeñas del suelo

`guia_13_plantas.png`:

```
In the same style, a sheet of 16 small plants and ground details, each drawn flat from the
front like a Minecraft "cross" sprite, pixel art 32x32 pixels each, on a plain magenta (#FF00FF)
background so I can cut them out, in a 4x4 grid with names: tall grass, red flower, yellow
flower, pebbles, dry twigs, seashell, wheat sprout, wheat half grown, ripe wheat, red mushrooms,
brown mushrooms, berry bush, small bush, fern, sapling, dawn grain plant (glowing amber beans).
```

## 4. Árboles

`guia_14_arboles.png`:

```
In the same style, 6 trees side by side seen from the side, made of big blocks: an oak, a big
oak, a pine, a palm tree, a dead tree, a corrupted violet dead tree. Plain light background.
```

## 5. El personaje (para hacerlo de cubos)

`guia_20_naufrago_vistas.png`:

```
Character turnaround of the castaway in the same blocky style: strictly orthographic FRONT,
LEFT SIDE, BACK and RIGHT SIDE views side by side, standing straight with arms down, same
size, plain light background, no perspective. Simple big blocky shapes (head, torso, two arms,
two legs), like Minecraft but with a slightly bigger head. Curly brown hair, light torn shirt,
crossed strap, brown trousers, boots.
```

`guia_21_cuerpo_base.png`:

```
Same character turnaround (front, side, back), but as a BASE body for customization: bald,
neutral face, simple light underwear, no accessories. Then the same for a woman.
```

`guia_22_caras_pelos.png`:

```
A sheet of 12 different faces (front view, same blocky head shape) and 12 hairstyles (front and
side), men and women, young and old, different skin tones, beards, in the same style.
```

## 6. El brazo en primera persona

`guia_23_brazo.png`:

```
4 first-person views in the same style: the player's blocky right arm with a torn shirt sleeve,
(1) empty hand relaxed, (2) holding a stone pickaxe, (3) holding a grass block, (4) holding a
torch. Bottom right of the screen, like Minecraft but with nicer lighting.
```

## 7. El naufragio

`guia_30_naufragio.png`:

```
In the same style, the wrecked sailing ship on the beach seen from 3 angles (front, side,
three-quarter), made of BIG blocks (no tiny cubes): broken hull, tilted masts, torn sails,
planks, crates, barrels and a chest scattered on the sand.
```

## 8. El pueblo

`guia_31_edificios.png`:

```
In the same style, a sheet of village buildings, each seen from the front at three-quarter
view: a small house, a big house, a tavern, a forge, a bakery, a chapel with a bell tower, a
wooden pier, a guard barracks, a market stall, a refugee camp tent.
```

## 9. Iconos de objetos

`guia_40_iconos_1.png` (y siguientes, de 16 en 16):

```
A sheet of 16 inventory icons in the same style, each a small blocky 3D object seen slightly
from above, plain light background, 4x4 grid with names: rope, fiber, sticks, stone, flint,
sharp rock, resin, seeds, stone knife, stone axe, stone pickaxe, spear, torch, plank, raw
fish, cooked fish.
```

(La lista completa de objetos está en `docs/TEXTURAS.md`; Claude preparará las hojas que falten.)

## 10. Criaturas y enemigos

`guia_50_animales.png`:

```
In the same style, a sheet of animals made of big blocks, side view: pig, cow, boar, wolf,
deer, rabbit, hen, cat, snake, seagull, crow, eagle.
```

`guia_51_enemigos.png`:

```
In the same style, the invaders, front view: a hooded scout, an archer, a soldier in iron
armor, a captain with a cape, a masked mage in violet robes with a smooth mask, and a huge
stone golem with a glowing violet crystal core.
```

## 11. Interfaz

`guia_60_interfaz.png`:

```
In the same style, a mockup of the game's inventory screen: wooden panel with metal corners,
leather slots, an equipment column with a character preview, a 3D item preview on the right,
hunger, thirst and sleep bars. Clean and readable.
```

---

**Orden recomendado:** 0 → 1 (escenas) → 2 (bloques) → 5 y 6 (personaje y brazo) → 7 (barco)
→ el resto. Con las escenas y los bloques Claude ya puede empezar a rehacer el mundo.
