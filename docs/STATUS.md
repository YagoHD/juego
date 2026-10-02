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

## Toca ahora (Fase 0 → Fase 1)
1. **(Usuario)** Instalar Godot 4.3 y la extensión `godot_voxel` en `addons/` (ver `README.md`).
2. **(Claude)** Fase 1: escena de **test técnico de voxels** en `tests/voxel_test/` —
   terreno por ruido con `VoxelLodTerrain`, cámara libre, contador de FPS. Objetivo: confirmar que
   los voxels pequeños rinden bien antes de comprometerse.
3. **(Claude)** Fase 2: colocar y romper bloques en un terreno pequeño.

## Siguiente (según el diseño)
- Supervivencia (recursos, base, cama, sueño/fatiga).
- La torre (crecimiento por tiempo, corrupción estática, fases).
- Enemigos y campamento.
- Idioma y cuaderno detective.
- Sueños.

## Notas
- El esqueleto de la escena de test ya existe en `tests/voxel_test/`, pero **requiere la extensión
  godot_voxel instalada** para funcionar. Hasta entonces, Godot avisará de clases `Voxel...` faltantes.
