# Estado del proyecto

> Qué está hecho, cómo funciona por dentro y qué toca ahora. Se actualiza cada sesión.
> Última actualización: 2026-10-02.

## Entorno
- PC del usuario: Windows 11, **RTX 4070**, CPU de 16 hilos.
- Motor: **Godot 4.7.2 de Zylann con godot_voxel 1.7 integrado**
  (`C:\Users\yagor\Desktop\godot.windows.editor.x86_64.exe`). El Godot normal no sirve.
- Sin .NET: todo el juego es GDScript. Las herramientas externas (horneador) son C# compilado
  por Windows PowerShell 5.1 (C# 5: nada de `$""`, `out var`, etc.).

## Hecho
- **Mundo de voxels pequeños**: voxel de 0,5 m (`VOXEL_SIZE`), mallas de 32³, colocar y romper.
- **La isla de la Beta** replicada de la imagen de referencia: macizo nevado al este con lago en
  una meseta, río hasta la costa sur, bosque central, pueblo y campos en la bahía del suroeste,
  colina de las ruinas al noroeste, zona corrupta con agujas al norte (meseta de la torre),
  playas de anchura variable, acantilados, islotes, mar turquesa en la orilla.
- **Jugador**: 1,4 m (2,8 bloques), sube solo escalones de 1 bloque (cámara suavizada), salto de
  2 bloques, vuelo (F), primera/tercera persona (V) con muñeco provisional de bloques animado,
  bloque en la mano animado, recuadro del bloque apuntado, no se puede colocar dentro de uno mismo.
- **Barra de bloques** (1–9 / rueda) con 9 bloques: hierba, tierra, piedra, arena, nieve, madera,
  hoja, agua, trigo. Existen además (solo en el mundo): hoja de pino, tierra corrupta, madera muerta.
- **Dibujado**: voxels con detalle en ~160 m alrededor, la isla entera como malla simplificada
  lejana, niebla por distancia (limpia hasta 450 m, bruma suave hasta 1600 m).
- **Carga ~6 s** (11 s la primera vez). El mundo se guarda en disco: autoguardado cada 60 s y al cerrar.

## Cómo funciona por dentro (decisiones técnicas)
- **Isla diseñada, no aleatoria** (decisión del usuario: el tutorial es "hecho a mano"; lo
  procedural es para el mundo tras el portal). `tools/island_baker/IslandBaker.cs` la describe y
  genera `assets/island/height.png` (altura ×64 en 16 bits: R alto, G bajo), `water.png` (nivel de
  ríos/lagos, misma codificación), `surface.png` (R bloque superficie, G subsuelo, B árbol =
  tipo·64 + densidad en milésimas), y `biome.png`/`preview.png` solo como referencia.
  Los PNG se importan como **Image** (sin compresión) para que funcionen al exportar.
- **El generador GDScript se ejecuta en un solo hilo** (limitación de VoxelGeneratorScript):
  por eso todo lo caro se precalcula en el horneador y el generador solo consulta mapas, descarta
  bloques de aire/roca maciza al instante y rellena por tramos (`fill_area`, máximo exclusivo).
- **Mundo guardado** en `user://world/isla_<huella>.sqlite` (VoxelStreamSQLite con
  `save_generator_output`). La huella es el MD5 de los mapas y de `island_generator.gd`:
  si cambian, se crea un mundo nuevo y se borra el viejo (¡se pierde lo construido!).
- **Observadores**: el jugador tiene uno visual de 320 voxels (sin colisiones) y otro de colisión
  de 48. La isla lejana (`FarTerrain`) se recorta con `discard` dentro de 145 m de la cámara.
- **Jugador**: espera a que haya suelo con colisión bajo él antes de aplicar gravedad.
- **Capas visuales**: el muñeco está en la capa 2; la cámara en primera persona no la dibuja
  pero su sombra sí se ve.
- `project.godot`: el módulo voxel usa el 85 % de los hilos y 16 ms por frame en el hilo principal.

## Hecho en la sesión del 2026-10-02 (tarde)
- **Cuerpo con skin formato Minecraft** (64x64, 2 capas, codos y rodillas), compositor de skins
  (base del editor de personaje), guía en `docs/SKINS.md`.
- **Animaciones**: andar/correr con inercia, respirar, parpadear, acciones tras 15 s quieto.
- **Cámaras**: V (1ª, detrás, de frente), mantener V + ratón = distancia, Alt = girar alrededor.
- **Correr** con doble W. **Texturas** de 16x16 en todos los bloques (atlas, repintables).
- **Ciclo de día y noche** de 24 min (sol, luna, estrellas, nubes 3D, niebla y luz por hora).
- **Inventario**: objetos al romper, recogida automática, pantalla (E), modo creativo (C).
  Empieza pequeño: 3 huecos de barra + 9 de inventario. Camiseta, pantalón y cinturón dan
  +2 de barra cada uno (bolsillos); la mochila +18 de inventario. Se ponen en el panel
  "Equipo" del inventario y se ven en el personaje (skin pintada + mochila 3D). De momento la
  ropa y la mochila están en los cofres del naufragio. Objetos no-bloque (cuerda, ropa) se ven
  con grosor en la mano y en el suelo (`scripts/items/item_mesh.gd`).
- **Cofres** (clic derecho) y **naufragio** en la playa con botín (`scripts/world/structures.gd`).
- **Fabricar en el suelo** (`scripts/crafting/`): G deja un objeto en el punto exacto donde se
  apunta (sin anclarse); G sobre la cara de arriba de otro lo apila (hasta 4). Una cuadrícula
  invisible de 0,25 m lee la FORMA en 3D (vale girada o reflejada); si es una receta conocida
  brilla y "Mantén R" la trabaja (animación agachado). Si es un trozo de una receta conocida,
  dice qué falta y lo muestra en transparente. Herramientas (cuchillo) no se gastan. Un objeto
  "desmontable" dejado solo se desmonta con R: devuelve materiales y enseña la receta.
  Mayús + clic recoge el montón entero. Recetas en `GroundRecipes.RECIPES`: cuerda, tablones,
  palitos (las tres en el diario), cinturón y mochila improvisada (notas en los cofres), cofre
  (cubo 2x2x2 de tablones), cuchillo y hacha de piedra (se aprenden desmontando).
- **Diario del capitán** (`scripts/ui/journal.gd`, tecla J): aparece en la playa al empezar;
  libro de dos páginas, papel con manchas de agua, texto corrido (la página del mineral),
  mapa sepia con naufragio, ruinas y "tú", recetas del capitán y "Mis notas" a lápiz con lo
  aprendido después.
- **Q** tira objetos (Ctrl+Q el montón).
- **Romper lleva tiempo** (supervivencia): `Blocks.HARDNESS` (hojas 0,3 s ... piedra 3 s), grietas en
  6 etapas (`scripts/player/block_cracks.gd`); `ItemDB.tool_speed`: hacha x4 en madera, cuchillo
  x3 en hojas/tela/trigo. En creativo, al momento.
- **Sonido** (`scripts/systems/sfx.gd`): todo generado por código (sin archivos): pasos según el
  suelo, romper por material, colocar, recoger, tirar, trabajar, fabricado, aprender, páginas,
  cofre, clics; ambiente: olas cerca del mar, pájaros de día, grillos de noche.
  `tools/test_sounds.gd` comprueba que se generan sin saturar.
- **Pantalla de título** (`scripts/ui/title_screen.gd`): título sobre la carta de la isla, consejos
  mientras carga y botones Jugar / Salir (Intro o Espacio). Pruebas y capturas entran solas.
- **Objetivos del tutorial** (`scripts/systems/objectives.gd`): arriba a la derecha, 8 pasos en orden
  (diario, leerlo, cofres, ropa, cuerda, mochila, desmontar el cofre, ruinas); se guardan.
- **Menú de pausa** (Esc, `scripts/ui/pause_menu.gd`): pausa el juego; opciones guardadas en
  `user://ajustes.cfg` (`scripts/systems/settings.gd`). Pantalla limpia: arriba solo el reloj;
  F1 muestra los controles, F3 los FPS.

## Variante del mapa y naufragio (2026-10-02)
- Se compactaron ligeramente los campos de pradera y bosque al oeste y sur; la montaña, la
  meseta corrupta, las ruinas y el pueblo mantienen sus coordenadas de diseño.
- El naufragio ahora tiene cuadernas rotas sobre la cubierta, un palo partido que cae sobre la
  proa, una vela rasgada con forma irregular y restos de madera agrupados en la playa.
- Antes de modificarlo se guardaron los mapas, el horneador y las estructuras originales en
  `docs/mapa-original.zip`.
- Los cambios de huella crean un archivo de mundo nuevo y ya no borran los guardados anteriores;
  los datos del mapa anterior siguen en `user://world/` y se cargan si se restaura su versión.
- Se renovaron las texturas procedurales de hierba, tierra, piedra, arena, nieve, madera, hojas,
  corrupción y tablones. El atlas ampliado está en `assets/textures/blocks_atlas_x8.png` y la
  versión anterior quedó guardada en `docs/texturas-originales.zip`.
- Segunda variante más compacta: la tierra ocupa un 57,4 % del mapa horneado, frente al 64,0 %
  de la versión anterior a la compactación; se mantienen el pico, el lago y el pinar de montaña.
  (DESHECHA: dejaba la zona de inicio bajo el nivel del mar y el jugador aparecía "buceando";
  se volvió al mapa anterior, conservando texturas, objetos, ruinas y detalles del barco.)
- Bloques nuevos: piedra musgosa (usada en los restos de las ruinas del noroeste) y madera de
  deriva (usada entre los restos del naufragio). Ambos se pueden recoger y colocar.
- Objetos nuevos: manojo de trigo, manojo de palitos, cuchillo de piedra y bayas silvestres.
  El trigo cosechado es un objeto 3D, mientras que el trigo plantado sigue siendo un bloque.
  Los objetos no bloque tienen más grosor al sostenerse y al caer.
- `tools/export_items.gd` genera una hoja de vista previa de iconos en `assets/textures/`.
  El estado previo a esta segunda variante está en `docs/variante-previa-nuevos-items.zip`.

## Siguiente (propuestas, a decidir con el usuario)
1. **Más contenido fabricado a mano**: (el naufragio ya existe)
   casas y muelles del pueblo, ruinas, puentes del río, la roca de la torre. Opciones: estructuras
   definidas en datos que el generador "estampa", o construirlas en el juego y guardarlas.
2. **Cama y sueño** (el ciclo de día y noche ya existe): dormir salta la noche, fatiga, sueños.
3. **Agua jugable**: nadar, cascadas, que el agua colocada fluya.
4. **Fabricación**: más recetas y la mesa de trabajo (mismo sistema, encima de la mesa, formas
   más grandes). Ideas: desmontar objetos para aprender cómo se hacen, fuego, forja por etapas.
5. Pulido: sonidos de pasos/romper/colocar, texturas en los bloques, partículas al romper.

## Herramientas
- `tools/capture.ps1`: arranca el juego, coloca la cámara y guarda una captura (`-Pitch -Yaw -Up -ThirdPerson`).
- `tools/test_step_up.gd`: prueba de física de escalones. `tools/bench_generator.gd`: coste del generador.
- Medir carga: `godot --headless --path . -- --quit-after-load`.
- Si se crea un `class_name` nuevo, ejecutar `godot --headless --path . --import` antes de
  probar sin editor (registra la clase).
