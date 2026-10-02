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

## Toca ahora (Fase 2)
- Cambiar de meshing **suave (Transvoxel)** a **blocky (cubos)** con `VoxelTerrain` +
  `VoxelMesherBlocky` + una `VoxelBlockyLibrary` de tipos de bloque.
- Jugador en primera persona con colisión y raycast.
- **Colocar y romper bloques** (clic izq. romper, clic der. colocar).

## Siguiente (según el diseño)
- Supervivencia (recursos, base, cama, sueño/fatiga).
- La torre (crecimiento por tiempo, corrupción estática, fases).
- Enemigos y campamento.
- Idioma y cuaderno detective.
- Sueños.

## Notas
- El esqueleto de la escena de test ya existe en `tests/voxel_test/`, pero **requiere la extensión
  godot_voxel instalada** para funcionar. Hasta entonces, Godot avisará de clases `Voxel...` faltantes.
