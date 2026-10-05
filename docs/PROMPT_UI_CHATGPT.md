# Prompts para ChatGPT (web): diseño de inventarios e interfaz

Para ChatGPT en la web, que **no conoce el juego**: todo lo que necesita va en los prompts.

Cómo usarlos:
1. Abre una conversación nueva en ChatGPT y **sube dos imágenes de referencia del estilo**:
   `docs/concept/hoja2_bloques.png` y `docs/concept/hoja7_herramientas.png`.
2. Pega el **prompt 0** (contexto). Luego, uno a uno, los prompts de las hojas (UI-1 a UI-8).
3. Guarda cada imagen en `docs/concept/` con el nombre que se indica (ui1_piezas.png...).
4. Si alguna sale mal: "Redo it. Same layout, plain beige background, no shadows, no extra
   elements, text exactly as written."

Las hojas UI-1 y UI-2 son **piezas sueltas** que se recortan y se usan directamente en el juego (lo
más importante). Las demás son **pantallas completas de ejemplo**: sirven de modelo para colocar
las piezas.

---

## 0. Contexto (pegar primero, con las dos imágenes subidas)

```
I am making a PC voxel game (Godot engine). The two images I uploaded are the OFFICIAL ART STYLE
of the game: chunky voxel art made of small cubes, hand-painted pixel shading, warm colors, soft
light from the top-left.

The game: first-person survival and crafting in a world of small cubes. It starts with a short
tutorial on a tropical island after a shipwreck, but the REAL game is a big MEDIEVAL fantasy
world (villages, castles, forests, mountains, mines). So the user interface must feel
HANDCRAFTED and MEDIEVAL-RUSTIC: dark wood, worn leather, parchment, rope, iron rivets, sail
cloth. Not sci-fi, not glossy, not modern. Warm amber/gold accent ONLY for things that are
active, selected or can be done. Readable and clean.

Rules for every image I ask you:
- Same pixel/voxel art style as my uploaded images, crisp pixels, no blur.
- Texts in SPANISH, exactly as I write them. No other text, no logos.
- When I ask for a SHEET OF PIECES: plain light beige background (#F0EBE0), every piece
  separated from the others with empty space, no shadows on the background, front view, flat
  (no perspective), numbered under each piece.
- When I ask for a SCREEN MOCKUP: 16:9, like a 1920x1080 screenshot of the game.
Reply "OK" and wait for my next message.
```

## UI-1. Piezas de la interfaz (marcos, huecos, botones, barras) → `ui1_piezas.png`

```
SHEET OF PIECES (interface kit). A clean grid, numbered 1-16 under each piece, plain beige
background, generous empty space around each piece. All pieces flat, front view, pixel art,
made so they can be stretched (plain center, decorated borders and corners):
1 big empty window panel: dark wood frame with iron corner rivets, slightly translucent dark
  parchment center (empty)
2 the same panel but light: old parchment paper with burnt edges (for books and notes)
3 inventory slot, empty: small square sunk into leather, stitched border
4 inventory slot, SELECTED: same square with a glowing warm amber border
5 inventory slot, mouse over: same square slightly lighter
6 inventory slot, LOCKED / not available: same square darker, with a small padlock
7 wide button, normal: wooden plank with rope wrapped at both ends (empty, no text)
8 the same button, mouse over: lighter wood, amber glow
9 the same button, pressed: darker, pushed in
10 small round button with an X (close)
11 horizontal bar frame, empty (leather strap with metal ends) for health/hunger/thirst
12 bar fill, red (health)
13 bar fill, orange-brown (hunger)
14 bar fill, blue (thirst)
15 small tooltip box: dark parchment with thin gold border (empty)
16 vertical scroll bar: wooden rail with a small metal handle
```

## UI-2. Iconos pequeños de la interfaz → `ui2_iconos.png`

```
SHEET OF PIECES (small interface icons). A clean 6x3 grid, numbered 1-18 under each icon, plain
beige background. Each icon simple and readable at small size, pixel art, front view:
1 grey silhouette of a shirt (empty clothing slot)
2 grey silhouette of trousers (empty slot)
3 grey silhouette of a belt (empty slot)
4 grey silhouette of a backpack (empty slot)
5 grey silhouette of a hat / helmet (empty slot)
6 grey silhouette of boots (empty slot)
7 red heart (health)
8 drumstick / bread (hunger)
9 water drop (thirst)
10 small sun (daytime clock)
11 small moon (night clock)
12 open book (recipe book)
13 hammer and saw crossed (crafting)
14 small chest (storage)
15 gear / cog made of wood (options)
16 exclamation mark on a parchment (new objective)
17 hand (grab / pick up)
18 small padlock (locked)
```

## UI-3. Pantalla del inventario → `ui3_inventario.png`

```
SCREEN MOCKUP, 16:9. Third-person view: a blocky voxel adventurer (simple clothes, rope belt)
KNEELING on grass at the edge of a forest at sunset, an open canvas backpack on the ground next
to him. On the LEFT third of the screen, a semi-transparent dark wood + leather panel:
- top-left: title "Equipo" and 4 clothing slots in a 2x2 grid with grey silhouettes (shirt,
  trousers, belt, backpack) and tiny labels "Camiseta", "Pantalón", "Cinturón", "Mochila"
- to their right: title "Inventario" and a grid of 9 slots (3 rows of 3) with a few pixel-art
  items inside (stone, rope, wooden stick, berries) and small white numbers for amounts
- below: title "Barra" and a row of 3 slots
At the bottom right, a big wooden button with the text "Fabricar". The character stays clearly
visible in the center-right, the panel does not cover him.
```

## UI-4. Vista de fabricar con el recetario → `ui4_fabricar.png`

```
SCREEN MOCKUP, 16:9. Camera looking almost straight DOWN at a patch of ground in front of the
kneeling character. On the ground, real voxel objects lying freely (not in a grid): two rope
coils and a piece of canvas cloth arranged in a shape; they GLOW softly in amber because they
form a known recipe; one missing piece is shown as a transparent ghost. LEFT: a narrow
semi-transparent inventory panel (one column of slots with items). RIGHT: a recipe book that
looks like a leather notebook with parchment pages, title "Recetas", a list of recipe names
("Cuerda", "Tablones", "Mochila improvisada", "Cuchillo de piedra") with small icons, the
selected one highlighted, and a small drawing of its shape. BOTTOM CENTER: a wide wooden button
"Coser · Mochila improvisada". Small text above it: "Mantén R para trabajar".
```

## UI-5. Cofre abierto → `ui5_cofre.png`

```
SCREEN MOCKUP, 16:9. First-person view of an open wooden chest in front of the player. Two
panels side by side in the center: LEFT "Cofre" with a grid of 3 rows of 9 slots (some items
inside), RIGHT "Inventario" with the player's slots. Between them, small arrow buttons to move
everything. Same wood/leather/parchment style. The world behind is visible and darkened a bit.
```

## UI-6. Pantalla de juego (HUD) → `ui6_hud.png`

```
SCREEN MOCKUP, 16:9. First-person gameplay view in a green medieval countryside with a small
village far away. The player's blocky arm holds a stone axe at the bottom right. The interface
is MINIMAL:
- bottom center: hotbar of 9 slots that look like leather pockets sewn on a belt, the first one
  selected (amber border), small item icons and amounts; above it the name of the selected item
  "Hacha de piedra" in small text
- bottom left: three thin bars with small icons: heart (health), bread (hunger), drop (thirst)
- top center: a small clock: sun icon and "Día 3 · 14:20"
- top right: a small parchment note "Objetivo" with one line "Busca el pueblo del valle"
- a tiny crosshair in the center
```

## UI-7. Menú de pausa y opciones → `ui7_menu.png`

```
SCREEN MOCKUP, 16:9. The game world behind is blurred and darkened. In the center, a tall
wooden panel with iron rivets, title "Pausa", and vertical wooden buttons: "Continuar",
"Opciones", "Gráficos", "Controles", "Salir al título". To its right, a second parchment panel
showing the options page: title "Opciones", checkboxes made of small wooden squares with a
check mark ("Invertir el ratón", "Mostrar FPS"), a slider made of a rope with a wooden knob
("Sensibilidad del ratón"), and a dropdown "Calidad: Alta".
```

## UI-8. Pantalla de título → `ui8_titulo.png`

```
SCREEN MOCKUP, 16:9. Title screen of the game: a wide voxel landscape at dawn, medieval valley
with a castle on a hill, a river and forests; on the horizon the sea with a small island. Big
game logo in chunky voxel letters made of weathered wood and iron (leave the title as
"TÍTULO DEL JUEGO", I will change it later). Below the logo, three wooden buttons stacked:
"Jugar", "Opciones", "Salir". Small text at the bottom: "Cargando el mundo..." with a thin
progress bar made of rope.
```

---

Cuando estén, avísame: las piezas (UI-1 y UI-2) las recorto y sustituyen a los paneles y botones
actuales; las pantallas me sirven de modelo para colocarlo todo.
