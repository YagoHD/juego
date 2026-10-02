# Estado del proyecto

> Qué está hecho, qué toca ahora. Se actualiza cada sesión.

## Hardware del usuario
- GPU: **NVIDIA RTX 4070** (potente → podemos ser ambiciosos con el tamaño de voxel).
- OS: Windows 11.

## Hecho
- [x] Estructura de carpetas del proyecto.
- [x] `project.godot` (Godot 4.3, Forward+).
- [x] `.gitignore` de Godot.
- [x] Diseño volcado a `docs/DESIGN.md` (memoria viva).
- [x] `README.md` con pasos de instalación de Godot + godot_voxel.
- [x] Repositorio Git inicializado.

## Fase 1 — SUPERADA ✅
- Se usa el Godot de Zylann (build con módulo voxel integrado), versión 4.7.2.
- `tests/voxel_test/` genera terreno suave (Transvoxel) por ruido con cámara libre y FPS.
- Resultado: **59 FPS** (limitado por V-Sync a 60 Hz) → rendimiento sobrado. VOXEL_SIZE=0.5.

## Fase 2 — SUPERADA ✅
- Terreno **blocky** (cubos) con `VoxelTerrain` + `VoxelMesherBlocky` + `VoxelBlockyLibrary`.
- Generador por ruido con hierba/tierra/piedra (`scripts/world/blocky_terrain_generator.gd`).
- Voxels pequeños estilo Cube World: `VOXEL_SIZE = 0.5` (terreno escalado), personaje ~4 cubos.
- Jugador FPS con física, salto, mirar con ratón (`scripts/player/player.gd`).
- **Romper/colocar** con raycast de física (apunta al cubo correcto aun con voxels escalados).
  Clic izq. romper · clic der. colocar · teclas 1/2/3 eligen bloque.
- HUD con FPS, bloque actual y controles; punto de mira que no roba clics.

## Toca ahora (elegir siguiente sistema)
Candidatos según el diseño (ver DESIGN.md):
1. **Más tipos de bloque + inventario/selección** (ampliar la paleta y cómo se eligen).
2. **La isla**: dar forma al terreno a mano/semilla (playa, bosque, montaña, lago, río, mar).
3. **Supervivencia**: recoger recursos, construir, cama, ciclo día/noche, sueño/fatiga.
4. **Pulido del jugador**: velocidad, alcance, animaciones, sonido de pasos/romper.

## Siguiente (según el diseño)
- Supervivencia (recursos, base, cama, sueño/fatiga).
- La torre (crecimiento por tiempo, corrupción estática, fases).
- Enemigos y campamento.
- Idioma y cuaderno detective.
- Sueños.

## Notas
- El esqueleto de la escena de test ya existe en `tests/voxel_test/`, pero **requiere la extensión
  godot_voxel instalada** para funcionar. Hasta entonces, Godot avisará de clases `Voxel...` faltantes.
