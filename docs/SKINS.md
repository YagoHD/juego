# Skins del personaje

El cuerpo del jugador usa **el mismo formato de skin que Minecraft**: una imagen PNG de
**64×64 píxeles** con las 6 partes del cuerpo desplegadas en posiciones fijas.
Cualquier editor de skins de Minecraft (Blockbench, NovaSkin, etc.) sirve para pintarlas.

- Plantilla de ejemplo: [`assets/skins/default_skin.png`](../assets/skins/default_skin.png)
  (y ampliada ×8: `default_skin_x8.png`).
- Para usar una skin propia: guárdala como `user://skins/skin.png`
  (en Windows: `%APPDATA%\Godot\app_userdata\Isla del Naufragio\skins\skin.png`).
  Si no existe, el juego compone una con `SkinComposer` (piel, pelo, ropa...).

## Partes y capas

| Parte | Tamaño (an×al×fondo) | Capa base | Capa exterior |
|---|---|---|---|
| Cabeza | 8×8×8 | (0, 0) | (32, 0) — pelo con volumen, gorros |
| Torso | 8×12×4 | (16, 16) | (16, 32) — chaquetas |
| Brazo derecho | 4×12×4 (3 si es estrecho) | (40, 16) | (40, 32) |
| Brazo izquierdo | 4×12×4 | (32, 48) | (48, 48) |
| Pierna derecha | 4×12×4 | (0, 16) | (0, 32) |
| Pierna izquierda | 4×12×4 | (16, 48) | (0, 48) |

Cada parte se despliega así a partir de su esquina (u, v):
fila de arriba `[arriba][abajo]`, fila de abajo `[derecha][delante][izquierda][detrás]`.
La **capa exterior** es un poco más grande que la base y admite transparencia.

**Codos y rodillas:** brazos y piernas se doblan a mitad (6 px desde arriba). La mitad de
arriba de su textura es el brazo/muslo y la de abajo el antebrazo/espinilla; la imagen sigue
siendo una skin normal de Minecraft.

## Cómo funciona en el código

- [`SkinModel`](../scripts/player/skin_model.gd): construye las partes 3D a partir de la imagen
  (1 píxel de skin = 1,4 m / 32 ≈ 4,4 cm).
- [`SkinComposer`](../scripts/player/skin_composer.gd): pinta una skin a partir de opciones
  (tono de piel, pelo y peinado, ojos, camiseta y mangas, pantalón, zapatos, brazos estrechos).
  **Es la base del futuro editor de personaje**: el editor solo tiene que cambiar esas opciones
  (y en el futuro, añadir más capas: modelos de ropa, peinados, accesorios).
- [`PlayerAvatar`](../scripts/player/player_avatar.gd): el cuerpo animado (andar, respirar,
  balancearse, parpadear y, tras 15 s quieto, estirarse / sentadillas / salto / voltereta).
- `Player.apply_skin(textura, estrecho)` cambia la skin en caliente (cuerpo y brazo).
