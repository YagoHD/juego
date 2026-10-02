# Isla del Naufragio (Beta)

Juego de **voxels pequeños** (estilo Cube World) con colocar/romper bloques (estilo Minecraft),
más profundidad en combate, construcción y progresión, y una historia que se cuenta sola.
Hecho en **Godot 4** apoyándose en el módulo **godot_voxel** (de Zylann) vía GDExtension.

El diseño completo está en [`docs/DESIGN.md`](docs/DESIGN.md) — es la memoria viva del proyecto.
El estado actual y los próximos pasos están en [`docs/STATUS.md`](docs/STATUS.md).

---

## Puesta en marcha (una sola vez)

### 1. Descargar el Godot de Zylann (con el módulo voxel ya integrado)
La forma más simple: usar la build oficial de Zylann, que es un Godot 4.7.2 con el módulo
voxel compilado dentro. **No hay que instalar extensiones ni copiar nada en `addons/`.**

- Ve a https://github.com/Zylann/godot_voxel/releases (release v1.7).
- En Assets, descarga **`godot.windows.editor.x86_64.exe.zip`** (~85 MB).
  - ❌ NO los `...double...`, `...tracy...`, `...template_release...` ni "Source code".
- Descomprímelo. El `.exe` de dentro **es tu Godot** para este proyecto.

> Alternativa (no usada ahora): existe una release GDExtension aparte que se añadiría a
> `addons/zylann.voxel/` sobre un Godot estándar. La build integrada es más simple para empezar.
- Abre el proyecto en Godot. La extensión se carga sola; verás nodos nuevos como
  `VoxelTerrain`, `VoxelLodTerrain`, `VoxelGeneratorNoise`, etc.

> Si al abrir el proyecto Godot avisa de que faltan clases `Voxel...`, es que la extensión
> no está en `addons/` o no coincide la versión de Godot. Avísame con el mensaje exacto.

### 3. Abrir el proyecto
- Abre Godot → **Import** → selecciona el `project.godot` de esta carpeta.
- Pulsa Play (F5). La escena principal es el **test de voxels** (`tests/voxel_test/`).

---

## Flujo de trabajo

- **Git desde el día 1.** Cada avance verificado es un commit.
- **Sistemas pequeños y separados** (mundo, jugador, combate, construcción, idioma, sueños).
- **Pasos pequeños y verificables.** Para bugs visuales: captura de pantalla + consola de Godot.

## Dónde está cada cosa

| Carpeta | Contenido |
|---|---|
| `docs/` | Diseño (`DESIGN.md`) y estado del proyecto (`STATUS.md`) |
| `addons/` | GDExtension de godot_voxel (lo instalas tú, ver arriba) |
| `tests/voxel_test/` | Fase 1: test técnico de rendimiento de voxels |
| `scripts/world/` | Generación de terreno, chunks, bloques |
| `scripts/player/` | Movimiento, cámara, interacción |
| `scripts/systems/` | Combate, construcción, habilidades, idioma, sueños |
| `scenes/` | Escenas del juego |
| `assets/` | Modelos, texturas, sonido |
