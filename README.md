# Isla del Naufragio (Beta)

Juego de **voxels pequeños** (estilo Cube World) con colocar/romper bloques (estilo Minecraft),
más profundidad en combate, construcción y progresión, y una historia que se cuenta sola.
Hecho en **Godot 4.7** con el módulo **godot_voxel** (de Zylann).

- Diseño completo: [`docs/DESIGN.md`](docs/DESIGN.md) — la memoria viva del proyecto.
- Estado actual, decisiones técnicas y próximos pasos: [`docs/STATUS.md`](docs/STATUS.md).

---

## Puesta en marcha

1. Usa el **Godot de Zylann con el módulo voxel integrado** (no el Godot normal):
   https://github.com/Zylann/godot_voxel/releases → release v1.7 →
   `godot.windows.editor.x86_64.exe.zip`. Descomprímelo **fuera** de esta carpeta
   (si el `.exe` está junto a `project.godot`, arranca el juego directamente en vez del editor).
2. Abre ese Godot → **Import** → `project.godot` de esta carpeta → **Import & Edit**.
3. **F5** para jugar.

## Controles

| Tecla | Acción |
|---|---|
| WASD / ratón | Moverse / mirar |
| W dos veces rápido (y mantener) | Correr |
| Espacio | Saltar (los escalones de 1 bloque se suben solos) |
| Clic izquierdo / derecho | Romper / colocar bloque |
| 1–9 o rueda del ratón | Elegir bloque |
| V | Cámara: primera persona → tercera por detrás → tercera de frente |
| Mantener V + ratón adelante/atrás (o rueda) | Acercar/alejar la cámara (como en Skyrim) |
| Alt o botón central (mantener) | Girar la cámara alrededor del personaje |
| F | Volar (Espacio sube, Ctrl baja, Shift rápido) |
| Esc | Soltar el ratón (un clic lo recupera) |

## Cómo se hace la isla

La isla de la Beta está **diseñada**, no es aleatoria:

1. [`tools/island_baker/IslandBaker.cs`](tools/island_baker/IslandBaker.cs) describe la isla
   (costa, montaña, lago, río, pueblo, zona corrupta, playas...) y la "hornea" en mapas:
   `assets/island/height.png`, `water.png`, `surface.png` (+ `biome.png` y `preview.png` de referencia).
   Se ejecuta con:
   ```
   powershell -ExecutionPolicy Bypass -File tools/island_baker/bake_island.ps1
   ```
2. El juego convierte esos mapas en bloques ([`island_generator.gd`](scripts/world/island_generator.gd))
   y guarda el mundo en `user://world/` (las cargas siguientes leen de ahí y conservan lo construido).
   Si los mapas o el generador cambian, se crea un mundo nuevo automáticamente.

## Dónde está cada cosa

| Carpeta | Contenido |
|---|---|
| `docs/` | Diseño (`DESIGN.md`) y estado del proyecto (`STATUS.md`) |
| `scenes/` | Escena principal |
| `scripts/main.gd` | Monta el mundo, la isla lejana, el ambiente, el HUD y la pantalla de carga |
| `scripts/world/` | Generador de la isla, isla lejana (malla simplificada), catálogo de bloques |
| `scripts/player/` | Jugador, bloque en la mano, muñeco provisional |
| `scripts/ui/` | Barra de bloques |
| `assets/` | Mapas de la isla y shaders (mar, isla lejana) |
| `tools/` | Horneador de la isla, banco de pruebas, prueba de física, capturas automáticas |

## Herramientas de prueba

- `tools/test_step_up.gd` — comprueba que el jugador sube 1 bloque solo y se para ante 2.
- `tools/bench_generator.gd` — mide cuánto tarda el generador por tipo de bloque.
- `tools/capture.ps1` — arranca el juego, coloca la cámara y guarda una captura (para revisar el aspecto).

## Texturas de los bloques

Cada bloque tiene texturas de 16×16 (arriba, lados y abajo) reunidas en un atlas
([`block_textures.gd`](scripts/world/block_textures.gd)). Se generan por código
([`block_painter.gd`](scripts/world/block_painter.gd)), pero cualquiera se puede **pintar a mano**:
guarda un PNG de 16×16 en `assets/textures/blocks/` con el nombre de la textura
(`grass_top.png`, `grass_side.png`, `dirt.png`, `stone.png`, `sand.png`, `snow.png`, `log_top.png`,
`log_side.png`, `leaves.png`, `pine_leaves.png`, `water.png`, `corrupt_top.png`,
`corrupt_side.png`, `dead_log_top.png`, `dead_log_side.png`, `wheat_top.png`, `wheat_side.png`)
y el juego la usará. Para ver el atlas actual: `assets/textures/blocks_atlas_x8.png`
(se regenera con `tools/export_textures.gd`).
