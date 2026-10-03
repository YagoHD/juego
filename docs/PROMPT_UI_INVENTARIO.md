# Prompt para ChatGPT: imágenes de referencia de la interfaz de inventario y fabricación

Copia todo lo de abajo (desde "Hola") y pégalo en ChatGPT.

---

Hola. Estoy haciendo un videojuego llamado **Isla del Naufragio** en Godot 4.7 con godot_voxel.
Tienes acceso al código del proyecto. Quiero que lo leas, entiendas cómo funcionan el
inventario y la fabricación, y me escribas **un prompt en inglés para una IA de imágenes**
(Midjourney / DALL·E / Imagen) que genere **imágenes de referencia de UI/UX**. Las usaré como
inspiración para rediseñar estas pantallas. No quiero que cambies código: solo el prompt.

## El juego en una frase

Supervivencia y exploración en primera persona, en un mundo de cubos (bloques de 0,5 m, texturas
pixel art de 16×16, estilo parecido a Minecraft pero más cálido y artesanal). El jugador naufraga
en una isla tutorial hecha a mano: playa, barco roto, bosque, ruinas al noroeste y montañas al
este. Tono: náufrago, objetos rescatados del mar, tela de vela, cuerda, madera, diario del capitán
empapado. Nada de ciencia ficción ni de interfaz "gamer" brillante.

## Archivos que debes leer

- `scripts/crafting/craft_session.gd`: el flujo completo de inventario de rodillas y vista de
  fabricar (lo más importante).
- `scripts/ui/inventory_screen.gd`: la pantalla de inventario (huecos, arrastrar, modos
  "normal", "kneel" y "craft").
- `scripts/ui/equipment_panel.gd`: huecos de equipo (camiseta, pantalón, cinturón, mochila).
- `scripts/crafting/ground_recipes.gd`: las recetas como FORMAS en capas (cuadrícula invisible
  de 0,25 m, valen giradas o reflejadas; capas de abajo arriba).
- `scripts/crafting/ground_crafting.gd`: detección de formas, brillo, piezas que faltan en
  transparente, plantillas, desmontar.
- `scripts/ui/hotbar.gd`: la barra inferior.
- `scripts/ui/journal.gd`: el diario del capitán (libro de dos páginas, papel manchado).
- `scripts/ui/pause_menu.gd` y `scripts/ui/title_screen.gd`: el estilo actual de paneles y
  botones (madera oscura con borde cálido).
- `docs/NOVEDADES.md` y `docs/STATUS.md`: resumen de todo.

## Cómo funciona ahora (para que lo entiendas antes de leer el código)

1. **Inventario que crece con la ropa.** Sin ropa: 3 huecos en la barra inferior y 9 de
   inventario. Camiseta, pantalón y cinturón dan +2 huecos de barra cada uno ("bolsillos"). La
   mochila improvisada da +9 y la de marinero +18. La ropa se ve puesta en el personaje y la
   mochila es un modelo 3D en su espalda.
2. **Al abrir el inventario (E)** la cámara sale suavemente a tercera persona. El personaje se
   arrodilla y deja la mochila abierta en el suelo a su lado. El inventario aparece
   semitransparente a la izquierda, con el equipo, y el personaje se ve a la derecha.
3. **Botón "Fabricar".** La cámara se acerca, casi desde arriba, a la zona de trabajo: el suelo
   delante del personaje, o el tablero de una mesa de trabajo si hay una cerca. El inventario
   se estrecha a la izquierda y a la derecha aparece un **recetario** con las recetas conocidas.
4. **Se fabrica arrastrando objetos del inventario al mundo.** Cada objeto queda exactamente
   donde se suelta, sin encajar en casillas (hay una cuadrícula invisible que solo lee la
   forma). Soltado encima de otro objeto, se apila. Mientras se arrastra se ve una vista previa
   transparente y la rueda gira el objeto.
5. **Cuando la forma es una receta conocida, los objetos brillan** y abajo aparece un botón
   ("Coser · Mochila improvisada", "Atar · Cuchillo de piedra", "Desmontar · Cofre"). Al
   pulsarlo, el personaje trabaja con las manos unos segundos y el resultado va al inventario.
6. **Si la forma está a medias**, se dibujan en transparente las piezas que faltan y un texto
   dice "Mochila improvisada: falta 1 Cuerda". Al elegir una receta del recetario, su forma
   completa se dibuja en transparente en el suelo como plantilla.
7. **Las recetas no se ven hasta aprenderlas**: diario del capitán, notas, o desmontar objetos
   encontrados. La mesa de trabajo tiene recetas que solo salen encima de ella.
8. **Al cerrar**, lo que no se usó vuelve al inventario, el personaje recoge la mochila, se
   levanta y la cámara vuelve a primera persona.

## Qué quiero que pida tu prompt (varias imágenes)

1. **Inventario de rodillas**: personaje en tercera persona arrodillado en la playa al
   atardecer, mochila de lona abierta en la arena; a la izquierda, panel de inventario
   semitransparente con aspecto de tela de vela/madera/cuero, huecos de barra pocos (3-9) y de
   mochila; huecos de equipo (camiseta, pantalón, cinturón, mochila) con siluetas cuando están
   vacíos; botón grande "Fabricar".
2. **Vista de fabricar en el suelo**: cámara casi cenital sobre la arena; objetos pixel-art
   tumbados en el suelo formando una figura (cuerdas y telas); algunos brillan suavemente;
   piezas que faltan en transparente; recetario a la derecha como páginas de cuaderno; botón
   abajo "Coser · Mochila improvisada"; el inventario estrecho a la izquierda.
3. **Vista de fabricar en la mesa de trabajo**: lo mismo, sobre un banco de madera tosco con
   piezas apiladas en vertical (piedra encima de un palito atada con cuerda).
4. **Arrastrar un objeto del inventario al mundo**: el momento del arrastre, con la vista
   previa transparente del objeto sobre el suelo.
5. **Barra inferior** en el juego normal (primera persona): pocos huecos, aspecto de bolsillos
   de tela cosidos o cinturón de cuero, con números y cantidades.

## Restricciones de estilo para el prompt

- Mundo de cubos, texturas pixel art 16×16, iluminación cálida y suave; isla tropical; tonos
  arena, madera, lona, cuerda, verde selva y mar turquesa.
- Interfaz diegética o semidiegética, artesanal: tela de vela remendada, madera de barco,
  cuerda, cuero, papel envejecido; legible y limpia; iconos pixel art; pocos colores fuertes,
  acento dorado/ámbar para lo que se puede hacer.
- La interfaz no debe tapar al personaje ni la zona de trabajo: paneles a los lados,
  semitransparentes.
- Formato 16:9, como capturas de un juego de PC, 1920×1080. Sin texto ilegible ni logotipos
  reales. Textos de la interfaz en español.
- Que se note la sensación de **"construir con las manos, en el mundo"**, no la de una tabla de
  fabricación en casillas.

## Lo que necesito de ti

1. Un resumen breve (5-8 líneas) de cómo has entendido el sistema leyendo el código, para que
   yo compruebe que lo has entendido bien.
2. Un prompt maestro en inglés con el estilo común.
3. Cinco prompts en inglés, uno por imagen de la lista, que reutilicen ese estilo.
4. Si la IA de imágenes lo admite, parámetros recomendados (relación de aspecto, estilo...).
5. Ideas tuyas de UX que crees que mejorarían este sistema (máximo 5, cortas).
