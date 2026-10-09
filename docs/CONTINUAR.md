# Dónde seguir (relevo de la sesión de la nube al Claude del PC)

> Escrito por Claude en la nube el 2026-10-09. Léelo después de `CLAUDE.md`, `docs/STATUS.md` y
> `docs/mapa_isla/MIGRACION_BETA.md`. Habla con Yago en español, sin tecnicismos.

## 0. Antes de nada: traer el trabajo de la nube

Todo el trabajo de la nube ya está en **`master`** de GitHub (YagoHD/juego). En el PC: `git pull`
(si Yago tiene cambios sin guardar, commit primero). Después deja que Godot reimporte (abrir el
editor, o `godot --headless --path . --import`). Si los mapas de `assets/island/` dieran guerra, se
pueden volver a hornear con `python tools/hornear_isla.py` (necesita numpy, Pillow y scipy).

**Ojo**: los mapas y las estructuras han cambiado, así que al jugar se crea un **mundo nuevo**. El
anterior no se borra: queda en `user://world/` con su huella antigua.

## 1. Encargo nuevo de Yago (el siguiente trabajo): el personaje y el brazo de "personaje beta"

Yago ha creado en su PC una carpeta **`personaje beta`** con el modelo 3D del personaje y el del
brazo. Lo que pide, con sus palabras: *"implementalos para la beta, sin cambiar texturas ni
tamaños, lo que sí hay que ajustar es el esqueleto de la mano para los bloques y herramientas"*.

- No cambiar texturas, colores ni tamaños/proporciones de los modelos. Nada de reducir detalle.
  Si hace falta escalar para que encaje en el juego, solo escala **uniforme** y avísale antes.
- Sí ajustar los huesos de la mano (dedos, muñeca, punto de agarre) para que agarre bien los
  bloques (mano abierta) y las herramientas (puño cerrado sobre el mango, pinza para lo pequeño).
- Primero mira qué formato trae la carpeta (glb, gltf, fbx, vox, json de cajas...) y si viene con
  esqueleto. Si viene sin huesos en la mano, propón a Yago cómo trocearla antes de hacerlo.
- Nota: en CLAUDE.md pone que Meshy no se usa (decisión del 7 de octubre) y que el estilo es de
  cajas tipo Minecraft Dungeons. Si estos modelos son de otro estilo, pregúntale si cambia esa
  decisión antes de quitar el personaje de cajas actual (no lo borres: déjalo seleccionable).

Dónde está hoy el personaje en el código:
- `scripts/player/player_avatar.gd`: cuerpo de tercera persona; `build()` pide las piezas a
  `SkinModel.make_part` (cabeza, torso, brazos con `lower` en el codo y la mano, piernas). Las
  animaciones (andar, correr, agacharse, respirar, acciones) mueven esas piezas.
- `scripts/player/box_model.gd`: el personaje de cajas actual, descrito en
  `assets/models/cajas/naufrago.json` (+ `naufrago.png`), con huesos y `pose_hand()` para los
  agarres; trae `lower/wrist`, `lower/grip` (punto de agarre) y `lower/foot`.
- Primera persona: `scripts/player/held_block.gd` (`USE_BOX_ARM`), con `box_arm_view.gd` (brazo
  de cajas) y `real_arm_view.gd` (brazo de Meshy con huesos, dobla hombro/codo/muñeca para que la
  mano llegue al agarre; puede servir de base para un brazo con esqueleto).
- Agarres y tamaños de los objetos en la mano: `scripts/player/first_person_items.gd`,
  `voxel_hand.gd`/`model_hand.gd` (posturas: puño, pinza, abierta, relajada).
- Herramientas para revisar: `tools/preview_grips.gd` (capturas de los agarres) y
  `tools/test_first_person_grip.gd`. En el PC las capturas van bien (hay GPU):
  `powershell -File tools/capture.ps1 -Out foto.png -Showroom`.

## 2. Lo que se hizo en la nube (9 de octubre)

1. **Prueba de talar** (`tools/test_tree_fall.gd`) arreglada: buscaba un árbol en cuesta.
2. **Horneador de la isla** (`tools/hornear_isla.py`):
   - Caminos: se sacan del color del dibujo, se adelgazan a su línea central (`thin`), se quitan
     ramitas y se unen los cortes; se pintan de 2,5 m de ancho. Ya no confunde la orilla con caminos.
   - Playa del naufragio: vale cualquier mancha de arena que toque la orilla (era hierba).
   - Escribe `assets/island/lugares.json`: **rutas del norte** para las patrullas de la torre
     (`ROUTES`, buscadas sobre la red de caminos) y **puentes** (`BRIDGES`, en el punto del río más
     cercano a los del mapa).
3. **Puentes de madera** (`Structures._build_bridges`): tablero, barandilla, pilares, relleno y
   escalones. Sin árboles ni rocas alrededor (`Structures.is_clear`). Prueba: `test_bridges`.
4. **Rutas de la torre**: `main.gd` registra las rutas de `lugares.json` con
   `TowerDirector.register_road` (el día 4 algunas tienen patrulla: un 40 % por ruta, decisión de
   ChatGPT que no se ha tocado).
5. **Lugares del mapa** (estampados por `Structures.build`):
   - `scripts/world/village_builder.gd`: pueblo principal en B4 (13 casas con tejado a dos aguas,
     taberna, fragua, horno, banco, carpintería, cuartel, capilla de piedra con campanario, tiendas
     de refugiados). El plano está en `scripts/village/village_layout.gd` (lo usa también la aldea
     de pruebas, que ya no repite los datos).
   - `scripts/village/island_village.gd`: los 31 vecinos en la isla con la hora del día, la ley,
     diálogos, banco y multas; se guarda con la partida (`"village"` en el json del jugador).
   - `scripts/world/fishing_village_builder.gd`: pueblo pesquero quemado (A6), muelle roto, casa
     de los Valdés y 3 pistas (joyero vacío, escudo, ojo cerrado pintado).
   - `scripts/world/places_builder.gd`: 3 faros (luz de noche en `main.gd`), 2 atalayas, 3 ruinas
     (templo del bosque con altar, noreste, playa) y 5 minas (la de Bermudo acaba en un derrumbe).
   - Pistas (`scripts/story/clue_models.gd`, dibujos provisionales de cajas): las del pueblo
     pesquero, la grieta violeta de la quilla, la base de la torre y el ojo de las tiendas enemigas.
   - `scripts/world/garrison.gd`: los 3 primeros campamentos de la torre van a los sitios del mapa.
   - Pruebas: `test_places` (edificios levantados; se sube a faros y atalayas con un personaje de 3
     bloques de alto) y `test_island_village` (vecinos en la isla, diálogo, guardado).
6. `docs/TEXTURAS.md`, punto 11: arte pendiente para todo esto (tejas, pared encalada, madera
   quemada, umbrita, campana; vistas del joyero, escudo, ojo y máscara).

Estado de las pruebas: las 33 pasan en la nube (`bash tools/run_tests.sh`).
**No lances dos pruebas a la vez.** En el PC, con el Godot del escritorio, tardan menos.

## 3. Pendiente después del personaje (lista de Yago, en orden)

1. Revisar en el PC con capturas la isla nueva, los puentes, el pueblo y los lugares (en la nube
   no hay GPU). Retocar lo que no se parezca a `docs/mapa_isla/beta1.png` / `beta2.png`. En beta2 la
   montaña nevada es más grande que la nuestra.
2. Migración (`MIGRACION_BETA.md`) que falta: la cascada y garganta (F3) con cristal morado, la
   cueva de la isla pequeña (A8), zonas de animales, el pozo viejo de la mina de Bermudo y un
   **bloque de umbrita** (no existe: hay que añadirlo como el mineral verde `ORE` en
   `island_generator.gd`/`blocks.gd`, morado y brillante) para la veta tras el derrumbe.
3. Pistas que faltan de `scripts/story/lore_db.gd`: `mascara_lisa` (al derrotar a un enmascarado),
   `runas_brillan` (con la armadura antigua puesta cerca de la umbrita o la corrupción).
4. Paso 4 del estilo: interfaz nueva según `docs/estilo/guia_interfaz.png`.
5. Más objetos de cubitos con `tools/objetos_desde_vistas.py` cuando Yago suba hojas de vistas.

Decisiones abiertas con Yago: qué hacer con los sueños narrativos y con el grano de alba.
