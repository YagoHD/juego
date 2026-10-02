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
- **Cofres** (clic derecho) y **naufragio** en la playa con botín (`scripts/world/structures.gd`).

## Siguiente (propuestas, a decidir con el usuario)
1. **Más contenido fabricado a mano**: (el naufragio ya existe)
   casas y muelles del pueblo, ruinas, puentes del río, la roca de la torre. Opciones: estructuras
   definidas en datos que el generador "estampa", o construirlas en el juego y guardarlas.
2. **Cama y sueño** (el ciclo de día y noche ya existe): dormir salta la noche, fatiga, sueños.
3. **Agua jugable**: nadar, cascadas, que el agua colocada fluya.
4. **Fabricación** (troncos -> tablones, tablones -> cofre...) y objetos que no son bloques
   (cuerda, comida). El inventario y los objetos ya existen.
5. Pulido: sonidos de pasos/romper/colocar, texturas en los bloques, partículas al romper.

## Herramientas
- `tools/capture.ps1`: arranca el juego, coloca la cámara y guarda una captura (`-Pitch -Yaw -Up -ThirdPerson`).
- `tools/test_step_up.gd`: prueba de física de escalones. `tools/bench_generator.gd`: coste del generador.
- Medir carga: `godot --headless --path . -- --quit-after-load`.
- Si se crea un `class_name` nuevo, ejecutar `godot --headless --path . --import` antes de
  probar sin editor (registra la clase).
