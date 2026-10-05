# Novedades (sesión del 2-3 de octubre de 2026)

Todo está guardado en git, un commit por mejora. Pasan todas las pruebas automáticas.
Para probar: abre Godot (el .exe del Escritorio), el proyecto `juego` y pulsa **F5**.
La isla se vuelve a crear (cambiaron las estructuras); tu mundo anterior no se borra.

## Cómo se juega ahora (lo nuevo)

| Tecla | Qué hace |
|---|---|
| Clic izquierdo **mantenido** | Romper: cada bloque tarda lo suyo (hojas 0,3 s, tierra 0,6 s, tronco 2,4 s, piedra 3 s). Salen grietas. |
| G | Dejar el objeto de la mano en el suelo, donde apuntas, sin anclarse. **Sobre la cara de arriba de otro objeto: se apila encima** (fabricar en vertical). |
| R (mantener) | Fabricar lo que brilla (el personaje se agacha a trabajar) o **desmontar** un objeto que esté solo. |
| Mayús + clic izquierdo | Recoger de una vez todo un montón del suelo. |
| Q / Ctrl + Q | Tirar uno / el montón entero. |
| J | **Diario del capitán** (A / D o flechas para pasar página). |
| Esc | **Menú de pausa**: continuar, opciones, controles, guardar y salir. |
| F1 / F3 | Ver todos los controles / ver los FPS. |

## Lo que hay nuevo

1. **Fabricar en vertical**: el cofre es un cubo de 2x2x2 tablones; el cuchillo y el hacha llevan
   la piedra encima del palito. Cualquier forma vale girada o reflejada.
2. **Piezas que faltan en transparente**: si una forma está a medias, el juego dice qué falta
   ("Mochila improvisada: falta 1 Cuerda") y la dibuja en transparente en su sitio.
3. **Herramientas que no se gastan**: el cuchillo, puesto al lado, talla troncos (tablones) y
   tablones (palitos).
4. **Desmontar para aprender**: deja un objeto solo en el suelo y mantén R; devuelve sus
   materiales y aprendes a hacerlo (cofre, cuchillo, hacha, mochila de marinero).
5. **Diario del capitán**: está en la arena, delante de donde apareces (brilla un poco).
   Es un libro empapado: páginas manchadas, texto borroso (la página del mineral), una carta de la
   isla con el naufragio, las ruinas y dónde estás tú, y las recetas básicas. Lo que aprendes
   después se apunta al final, "a lápiz", en "Mis notas".
6. **Mesa de trabajo** (tu idea): 2 troncos con 2 tablones encima. Encima de la mesa se colocan
   objetos igual que en el suelo, y hay recetas que **solo salen sobre la mesa**: la mochila de
   marinero (+18 huecos) y el pico de piedra (rompe piedra 3 veces más rápido).
7. **Cofre en las ruinas del noroeste**: la mochila de marinero (desmóntala para aprenderla), la
   nota del pico y materiales. Mira el mapa del diario.
8. **Objetivos del tutorial** arriba a la derecha (8 pasos: diario, leerlo, cofres, ropa, cuerda,
   mochila, desmontar el cofre, ruinas).
9. **Romper lleva tiempo**, con grietas; **hacha** x4 en madera, **cuchillo** x3 en hojas y tela,
   **pico** x3 en piedra. En modo creativo se rompe al momento.
10. **Sonido** (todo generado por código): pasos según el suelo, romper, colocar, recoger,
    trabajar, fabricar, páginas, cofre; de fondo, olas cerca del mar, pájaros de día y grillos
    de noche. El volumen está en Opciones.
11. **Menú de pausa** con opciones guardadas (sensibilidad, campo de visión, volumen, invertir
    ratón, FPS) y **pantalla de título** con la carta de la isla y consejos mientras carga.
12. Pantalla limpia: arriba solo el reloj; los controles con F1.
13. Al pasar el ratón por el inventario se ve el nombre del objeto.
14. Con un objeto (no bloque) en la mano, al apuntar al suelo se ve en transparente dónde quedará.
15. Los objetos planos (cuerda, ropa...) ya no salen descoloridos.
16. **Antorchas**: palito con tela encima (Atar, salen 2; en el diario). Con G se clavan de pie y
    dan luz cálida que parpadea; en la mano también alumbran. Ideales para la noche.

## Cambios de ChatGPT

Se conservaron (texturas nuevas, piedra musgosa, madera de deriva, trigo, palitos, cuchillo,
bayas, ruinas y restos del barco), menos la isla compactada: dejaba la zona de inicio bajo el
nivel del mar y aparecías "buceando" con la pantalla azul. Se volvió al mapa anterior.

## Recetas (para probar rápido)

- Cuerda: 3 hojas en línea (Retorcer). — en el diario
- Tablones x4: tronco + cuchillo al lado (Tallar). — en el diario
- Palitos x4: tablón + cuchillo al lado (Tallar). — en el diario
- Mesa de trabajo: 2 troncos en línea, 2 tablones encima (Montar). — en el diario
- Cinturón: 3 cuerdas en línea (Atar). — nota en el cofre de la playa
- Mochila improvisada (+9): `C.C` / `TTT` / `TTT` (C cuerda, T tela) (Coser). — nota en el cofre del barco
- Cofre: cubo 2x2x2 de tablones (Montar). — desmontando el cofre de la playa
- Cuchillo: palito con piedra encima y cuerda al lado (Atar). — desmontando el cuchillo del barco
- Hacha: 2 palitos y cuerda en línea, piedra encima de la cuerda (Atar). — desmontando el hacha del cofre de la playa
- Antorcha x2: palito con tela encima (Atar). — en el diario
- Sobre la mesa: mochila de marinero y pico de piedra. — ruinas

## Supervivencia de verdad (3 de octubre)

- **Árboles**: de muchas formas (arbustos, robles, inclinados, gigantes 2x2, pinos, muertos) y
  **caen con física** al talarlos: crujen, vuelcan, la copa se rompe y el tronco queda tumbado.
  Los pinos dan **resina**.
- **Cosas del suelo que no son cubos**, se recogen con la mano: **hierba alta** (fibra, a veces
  semillas o un insecto), **flores**, **piedrecitas** (piedra, a veces pedernal), **palos** y
  **conchas**.
- **Progresión**: fibra → cuerda; piedra + piedra → **piedra afilada**; palo + piedra afilada +
  cuerda → cuchillo / hacha; tronco + hacha → **tablas** (largas y finas); 2 troncos + 2 tablas →
  **mesa de trabajo**; palo + resina → antorcha; anillo de 8 piedras + palo + fibra encima →
  **hoguera**. Todo eso está en el diario.
- **Hoguera**: clic derecho para ponerla; con **pedernal** se intenta encender (puede fallar);
  con palos o troncos se le echa leña; con insectos, bayas o semillas, se asan.
- **Nada regalado**: los cofres del barco casi no traen nada; **cada mañana el mar trae cajas a
  la orilla** con restos al azar.
- El cofre tiene la cerradura solo delante.

## Con los recursos descargados (3 de octubre, tarde)

Todo lo de Kenney y OpenGameArt es CC0 (créditos en `assets/third_party/*/` y
`assets/third_party_raw/LEEME.md`).

- **Palmeras, rocas, arbustos, tocones, setas, troncos caídos y árboles nuevos** de Kenney,
  pasados a cubitos y **troceados en bloques**: se rompen pieza a pieza (madera, piedras o
  pedernal, bayas, setas) y los troncos se talan con física como los demás árboles. Colores
  pasados a la paleta de la isla. Herramientas: `tools/bake_prefabs.gd`, `tools/voxelize_model.gd`.
- **Sonidos grabados** de Kenney (pasos por suelo, golpes, páginas, crujidos, clics) y **música**
  (3 piezas CC0 que suenan de vez en cuando; volumen en Opciones).
- **Interfaz de madera** (Kenney UI Pack RPG): paneles, huecos de pergamino, botones, cursor.
- **Texturas 16x16** opcionales (Opciones > Texturas 16x16; al volver a entrar).
- **Hacha y pico en cubitos** en la mano; **hoguera** con su anillo de piedras.
- **Saco de dormir** (lona + cuerda): de noche, clic derecho para dormir hasta el amanecer; marca
  dónde reapareces.
- **Hambre y sed** suaves (barras abajo a la izquierda): comer con clic derecho (asado alimenta
  más), beber con la mano vacía mirando agua de río o lago. Sin ellas no se corre.
- **Pesca**: lanza (tabla + cuerda + piedra afilada); peces en el mar cerca de la orilla; clic
  izquierdo con la lanza. Pescado asado = la mejor comida.
- **Agricultura**: semillas en hierba o tierra (clic derecho); el trigo madura en unos minutos;
  trigo asado = torta de pan.
- Pendiente: la librería de animaciones de Quaternius se descarga a mano desde itch.io (para
  cuando toque el "personaje vivo").

## Más vida y supervivencia (3 de octubre, noche)

- **Objetivos del tutorial**: ahora 12 pasos (también piedra afilada, encender hoguera, comer algo
  asado y dormir una noche).
- **Lluvia**: a ratos llueve (cielo gris, gotas, sonido); apaga las hogueras al raso; se puede
  beber mirando al cielo con la mano vacía.
- **Las herramientas se gastan** (hacha y pico 80 usos, cuchillo 60, lanza 40): barrita de
  desgaste en el hueco; al acabarse se rompen.
- **El mapa del diario se completa al explorar**: lo que no has pisado sale en blanco.
- **Mineral verde** en la roca de las montañas: brilla un poco, se saca con el pico. Para la forja
  (por diseñar).
- **Cangrejos** en la arena (se cogen con la mano vacía, clic izquierdo; asados son comida) y
  **gaviotas** volando sobre la costa.
- **Balsa** (receta en el diario): 4 tablas en cuadrado y 2 cuerdas encima. Con ella en la mano,
  clic derecho al mar para echarla; clic derecho sobre ella para subir; W/S remar, A/D girar,
  Espacio bajar (a tierra si hay cerca). No entra en tierra. Clic izquierdo la recoge. Se guarda.

## Árboles de un solo estilo y agua que corre (3 de octubre, noche)

- **Rocas y árboles Kenney macizos**: al picarlos ya no se ve hueco por dentro.
- **Todos los árboles del mismo estilo**: nuestros robles, pinos, gigantes y muertos se hacen
  ahora con piezas como las de Kenney (colores lisos, copa con bordes redondeados, tronco fino;
  los gigantes, tronco gordo). Las hojas se atraviesan, como las de las palmeras.
- **Rendimiento**: vuelve a ir a ~60 FPS (las piezas juntan sus caras).
- **Agua que corre (como Minecraft)**: el agua de ríos y lagos es "fuente". Si le abres hueco se
  derrama: cae por los agujeros y se extiende a los lados perdiendo nivel (hasta 7 bloques),
  buscando por dónde bajar. Si quitas la fuente, se retira. Dos fuentes juntas crean otra.
- **Los ríos corren**: la superficie tiene ondas que bajan con la corriente y la corriente te
  arrastra al nadar. El agua que corre también empuja.
- Nota: el mundo se ha vuelto a generar (los cambios de árboles y agua lo necesitan).

## Estilo del arte conceptual (4 de octubre)

- **Texturas de la hoja de ChatGPT**: hierba, tierra, arena, piedra, piedra musgosa, nieve,
  tierra corrupta, mineral, tronco, tablones, madera de deriva, tela y cofre, sacadas del dibujo
  (32 px). La hierba alta y las flores también son los dibujos.
- **Mesa de trabajo** de cubitos como la del concepto (tablones, patas, martillo, nota, trapo).
- **Piedrecitas, palitos y concha** con forma de cubitos, no cajitas. Agua de ríos turquesa.
- **El recuadro de selección sigue la forma** de lo que apuntas (trozos de árbol y roca, la
  mesa, la alfombra, las plantas...), y las grietas al romper también.
- **Las plantas y hojas solo se apuntan si apuntas a ellas**, no al hueco de su cubo.
- **Relieve en los bloques** (de cerca): las juntas, grietas y vetas se hunden, la hierba, la
  nieve y el musgo sobresalen, los bordes están biselados. El mineral verde y la tierra corrupta
  brillan y laten. **Flores en 3D** de cubitos y hierba alta en estrella. Espuma pixelada.
- **Hoja 2**: texturas de los bloques del suelo a más resolución y 4 bloques nuevos:
  **arena mojada** (orilla del mar), **grava** y **arcilla** (fondo de ríos y lagos) y **barro**
  (donde el agua toca la hierba). El mundo se vuelve a generar.
- **Sala de muestras** para revisar el aspecto rápido: `tools/capture.ps1 -Showroom` (o
  `godot --path . -- --showroom`): un suelo plano con todos los bloques en fila.

## Tala nueva (4 de octubre, tarde)

- **El árbol revienta al caer**: se tala por la base, cae con física y, al golpear el suelo ya
  tumbado, salta en astillas y la madera queda en el suelo como objetos para recoger (también
  las hojas y, en los pinos, resina). Ya no quedan troncos tumbados en el mundo.
- **Tocón**: donde estaba el árbol queda un tocón (de cubitos). Si no lo quitas, a los 10 minutos
  de juego el árbol **vuelve a crecer** igual que era. Si lo rompes, da madera y ahí ya no crece.
- **Árboles nuevos de la hoja 3 del concepto** (adiós a los de Kenney y a los de bloques):
  robles, robles inclinados, árbol gigante, pinos (grandes, pequeños y por pisos), árboles secos,
  arbustos y arbustos de bayas, varias versiones de cada uno. Tronco que se ensancha con raíces,
  corteza con surcos, copa de cubos de hojas con luz pintada.
- **Talar a lo ancho**: el tronco es grueso (3x3 bloques; el gigante, más). El árbol cae cuando
  cortas todo el ancho del tronco a una altura. El tocón queda en el centro y rebrota igual.
- Los arbustos de bayas dan bayas; los pinos, agujas y resina; los árboles secos, madera seca.
- **Picar troncos**: ahora se rompe justo el trozo que apuntas (antes a veces el de detrás y
  quedaban huecos). Los objetos que salen disparados ya no atraviesan el suelo.
- **Troncos caídos, arbustos y tocones de adorno** nuestros (adiós a los de Kenney).
- **Hojas sueltas y agujas de pino** como objetos (no bloques de hoja: esos, con herramienta más
  adelante). **Corteza**: los trozos de fuera del tronco dan corteza; los de dentro, madera.
- **Sonido de la caída** nuevo: crujido, susurro de hojas y golpe sordo.
- **Los objetos flotan** en el agua (ríos, lagos y mar) y la corriente de los ríos los arrastra.

## Construcción con detalle (5 de octubre)

- **Arreglo importante**: la arena mojada, la grava, la arcilla, el barro y el tocón eran
  invisibles (se dibujaban como agua de altura cero). Ya se ven.
- **Medias losas de tablones** ("plank_slab"): un tablón cortado con el hacha da 2 (receta en el
  diario). Al colocarla: encima de algo, abajo; debajo de algo, arriba; en un lateral, de pie
  pegada a esa cara.
- **Cuerda colgante**: con cuerda en la mano, clic derecho en la cara de abajo de un bloque (o
  en una cuerda que ya cuelga, para alargarla). Al romperla devuelve la cuerda.
- **Vela**: la tela en un lateral se coloca de pie, como una vela; en el suelo, tendida.
- **Cofre de cubitos** como el del concepto (tablones, bandas de hierro, cerradura). **Al abrirlo
  la tapa se levanta** y dentro se ve un montoncito con lo que guarda; al cerrar, baja.
- **El barco del naufragio, entero** (encallado en la orilla de la bahía): casco curvo de
  tablones suavizado con medias losas, quilla de tronco, borda, cubierta, camarote en la popa
  (puerta y ventanas) con cubierta alta encima, castillo de proa, palo mayor con verga y vela de
  pie, mesana con vela pequeña, trinquete partido (su punta es el mástil caído de la playa, con
  la vela tendida en la arena). **Cuerda colgando** de la verga del palo mayor (se recoge).
  **Bodega** con escalera de medias losas desde una escotilla y el cofre dentro. Roturas: vía de
  agua en el costado, algún hueco en la borda y tablas sueltas en la cubierta.
- El mundo se rehace también si cambia la forma de un árbol o del barco.

## Código reorganizado

- `player.gd` (1687 → 1038 líneas) en componentes: BlockAim (apuntar), BlockBreaker (romper),
  PlayerBuilder (colocar), PlayerSurvival (comer, beber, pescar...) y RaftRider (balsa).
- `main.gd` (1234 → ~940) con BlockModels (modelos de bloques) y CaptureMode (capturas).
- `tools/run_tests.sh` pasa todas las pruebas de una vez.

## Rendimiento y hierba (5 de octubre)

- **F3** enseña ahora el desglose: tiempo de la gráfica y del procesador, triángulos y llamadas
  de dibujo. **Opciones > Gráficos**: distancia de detalle (96/128/160 m), sombras (no, bajas,
  medias, altas), suavizado (no, FXAA, MSAA), relieve y árboles lejanos. Por defecto, más ligero
  que antes: detalle 128 m, sombras medias (100 m), FXAA.
- **Árboles sencillos a lo lejos**: más allá de la zona de detalle, cada árbol se dibuja con un
  modelo de pocas cajas en su sitio (antes, un manto verde).
- **Árboles más ligeros**: cubos de hoja más grandes, corteza en vetas y sin caras ocultas
  dentro de la copa. En la misma vista: de 70 a 119 FPS (68 → 35 millones de triángulos).
- **Hierba más natural**: lisa casi siempre y con florecitas 1 de cada 10; la cara de arriba de
  hierba, tierra, arena... se gira al azar en cada bloque y cambia un pelín de tono; sin las
  rayas en cuadrícula.
- **Árboles en un mundo aparte**: los árboles detallados se ven hasta 64 m (Opciones > Gráficos
  > Detalle de los árboles: 48, 64 o 96 m); más allá, los sencillos. Todo lo demás (picar,
  talar, tocones, rebrote, colocar...) funciona igual. En la vista del bosque desde lo alto:
  119 → 144 FPS, la gráfica de 7,7 a ~3 ms, de 35 a ~12 millones de triángulos.
- El mundo se vuelve a generar al entrar (los árboles van ahora en su propio archivo).
- **Sin tirones al andar por el bosque**: crear el choque exacto de los troncos al cargar trozos
  de bosque daba parones de 100 ms; ahora la madera choca con una caja (al chocar no se nota) y
  el mundo de los árboles se carga en trozos más pequeños. Prueba volando a toda velocidad: de
  36 tirones (peor 111 ms) a ninguno. El F3 cuenta los tirones y se apuntan en `tirones.txt`.
- **Árboles bien plantados**: el pie va a la altura del punto más bajo (sin raíces colgando en
  las cuestas), no nacen en cuestas muy empinadas, hay una distancia mínima entre troncos y los
  arbustos y rocas no nacen bajo la copa de un árbol.
- Arreglo: el guardado automático no guardaba los árboles talados (podían volver al recargar).

## Hoja 4: palmeras, rocas, setas y trigo (5 de octubre)

- Las **palmeras** (alta, curvada y baja), las **tres rocas con musgo**, el **tocón viejo grande**
  con raíces, las **setas** (rojas con puntos y marrones) y el **trigo** (verde y maduro) se han
  rehecho en cubitos como en `docs/concept/hoja4_palmeras_rocas.png`. Ya no queda nada de Kenney en la isla.
- Los árboles talados (si dejas el tocón) **rebrotan a los 2 días de juego**. El tiempo corre
  aunque te vayas lejos; crece cuando vuelves. Con T (adelantar el reloj) también va más deprisa.
- Arreglado: al juntarse montones iguales en el suelo a veces se perdían objetos (p. ej. madera al talar).

## Hojas de los árboles (5 de octubre)

- Las copas ya **no están huecas**: al picar un trozo de hojas se ven las hojas de dentro, no el paisaje de detrás.
- Se siguen **atravesando**, pero dentro de una copa vas a menos de la mitad de velocidad.
  Suena un roce de ramas, como al pasar por una zarza, y el personaje se pone las manos delante de la cara
  (la izquierda más alta, tapándose los ojos). Desde dentro de la copa se ven las hojas por todos lados,
  sin ver a través (las caras de dentro solo se dibujan en el árbol que tienes al lado: no cuesta FPS).
