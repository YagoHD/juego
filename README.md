# Isla del Naufragio (Beta)

Juego de **voxels pequeños** (estilo Cube World) con colocar/romper bloques (estilo Minecraft),
más profundidad en combate, construcción y progresión, y una historia que se cuenta sola.
Hecho en **Godot 4** apoyándose en el módulo **godot_voxel** (de Zylann) vía GDExtension.

El diseño completo está en [`docs/DESIGN.md`](docs/DESIGN.md) — es la memoria viva del proyecto.
El estado actual y los próximos pasos están en [`docs/STATUS.md`](docs/STATUS.md).

---

## Puesta en marcha (una sola vez)

### 1. Instalar Godot 4
- Descarga **Godot 4.3** (o superior) desde https://godotengine.org/download/windows/
- Sirve la versión **estándar** (no hace falta la .NET/C# para empezar).
- Es un `.exe` portable: lo descomprimes y lo ejecutas, no necesita instalación.

### 2. Instalar la extensión godot_voxel (sin compilar nada)
Antes se necesitaba compilar Godot entero. Ya **no**: Zylann publica binarios como GDExtension.

- Ve a https://github.com/Zylann/godot_voxel/releases
- Descarga el `.zip` de la versión que coincida con tu Godot (ej. `godot_voxel` para Godot 4.3, Windows).
- Dentro del zip hay una carpeta `addons/`. Copia su contenido dentro de la carpeta
  [`addons/`](addons/) de este proyecto (de modo que quede `addons/zylann.voxel/...`).
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
