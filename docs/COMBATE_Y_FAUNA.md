# Combate y fauna — primera versión de lógica (6 de octubre de 2026)

Implementación para revisar con Claude. Yago pidió figuras provisionales, cinco enemigos,
fauna con rutinas y botín, y pérdida del inventario al morir: una mochila recuperable en el
lugar de la muerte. **Las criaturas nuevas aparecen solamente en el mapa de pruebas**.
El juego de la isla conserva los cangrejos, gaviotas y peces anteriores.

## Probar

- Doble clic en `Pruebas de combate.bat`, o abrir `scenes/combat_arena.tscn` en Godot y pulsar F6.
- WASD, ratón, salto, cámaras y herramientas usan el jugador real del proyecto.
- Clic izquierdo apuntando a una criatura: atacar. Si apuntas a terreno, conserva su interacción.
- 1–9 / rueda: equipo. E: inventario. F2 / Esc: panel de pruebas, con la simulación pausada.
- En E, almacenamiento y barra están separados. Clic o arrastre mueve objetos a los huecos
  y a la barra inferior; Mayús + clic los envía a la otra sección. Con un montón cogido,
  clic izquierdo fuera tira todo, derecho tira uno; arrastrar fuera tira el montón.
  Se conserva el desgaste, también al tirar con Q. No se recoge automáticamente con E abierto.
- El panel permite añadir especies, reponer la población, dar equipo, cambiar día/noche y
  provocar una muerte para comprobar la mochila. El límite de creación manual es 40 criaturas.
- Clic derecho apuntando a una mochila, a menos de 3 m: recuperarla. Si no cabe todo, sigue ahí.
- Enemigos al norte, animales al sur. Hay una pared para probar visión y proyectiles y un escalón.
- El naranja anuncia un ataque. Las etiquetas muestran especie, vida y estado de IA; la zona
  naranja del guardián indica dónde caerá el golpe. Los modelos son esferas/cápsulas de colores.

## Enemigos (valores provisionales)

| Tipo | Vida | Daño base | Conducta |
|---|---:|---:|---|
| Rastreador | 45 | 9 | Patrulla, detecta, persigue, golpe rápido, recuperación |
| Soldado | 85 | 15 | Golpe lento, armadura que reduce 20% del daño, alerta cercana |
| Capitán | 140 | 18 | Combo de dos golpes anunciados; avisa a aliados cercanos |
| Mago | 60 | 14 | Guarda distancia, retrocede si te acercas, lanza proyectiles esquivables |
| Guardián | 400 | 28 | Golpe de área anunciado; bajo 50% de vida alterna con proyectiles,
  acelera el aviso y hace más daño |

No hacen daño durante el aviso. Los ataques cuerpo a cuerpo comprueban alcance, dirección y
línea de visión al impactar. El golpe de área queda fijado al empezar: salir de la zona lo evita.
El mago dispara hacia la posición observada, sin proyectiles que persigan al jugador. El barrido
del segmento de vuelo impide atravesar paredes. Hay límites de persecución y retorno al origen.

## Animales

| Especie | Conducta principal | Botín posible |
|---|---|---|
| Cerdo | Deambula, se alimenta, huye | Carne, piel |
| Vaca | Tranquila; se defiende si recibe daño | Carne, piel, hueso |
| Jabalí | Territorial; anuncia una carga | Carne, piel, colmillo |
| Serpiente | Territorial a corta distancia; mordedura y veneno | Glándula, carne |
| Lobo | Caza presas, alerta a lobos próximos; descanso diurno | Carne, piel, hueso |
| Gato | Tímido; descanso diurno y actividad nocturna | Piel, hueso |
| Ciervo | Deambula, come, huye | Carne, piel, hueso |
| Conejo | Pequeño y huidizo | Carne, piel |
| Gallina | Deambula, come, huye | Carne de ave, plumas |
| Gaviota | Vuela, baja a comer o descansar, huye | Carne de ave, plumas |
| Cuervo | Vuela, baja a comer o descansar, evita proximidad | Carne de ave, plumas |
| Águila | Vuela y caza presas pequeñas | Carne de ave, plumas |

El catálogo determina probabilidades y cantidades; no todos los drops son garantizados.
Las rutinas de alimentación son estados de comportamiento: todavía no consumen plantas/objetos.
La carne cruda y de ave se puede asar en la hoguera y comer con el sistema de hambre existente.
Pieles, huesos, colmillos, plumas, glándulas, hierro y polvo arcano quedan registrados como recursos;
sus recetas futuras están pendientes. Las órdenes del capitán y el fragmento del ancla son botín
provisional: aún no activan idioma, historia ni portal.

## Vida, golpes y muerte

- Vida 100 y energía 100. Puños 5 de daño; cuchillo 12; hacha 22; pico 16; lanza 18.
- Cada arma tiene alcance, coste de energía y tiempo entre golpes. El impacto gasta un uso.
- La energía se recupera con el tiempo. Buena hambre/sed permite recuperar vida lentamente.
- Un impacto da 0,55 s de inmunidad; la serpiente aplica veneno temporal. Creativo es inmune.
- La muerte cierra el inventario/fabricación y devuelve materiales antes de capturar el contenido.
- Cada muerte crea su propia mochila, sin borrar las anteriores, sin caducidad. Guarda inventario,
  ropa equipada y durabilidad. Diario, recetas y descubrimientos permanecen con el personaje.
- Al recuperar, vuelve a equipar las prendas cuyos huecos están vacíos y después transfiere los
  montones. No sustituye ropa nueva que se lleve puesta; conserva sobrantes en la mochila.
- Reaparece en el punto del saco/inicio, con vida y energía completas y 4 s de protección.
- Espera a que la colisión del suelo esté cargada; el punto del saco no se pierde al esperar suelo.

## Guardado

La arena usa `user://combat_arena_v1.json`, separado de `user://world/` y de los guardados de la isla.
Guarda inventario, equipo, necesidades, vida, veneno, mochilas, criaturas supervivientes con su vida,
posición y origen, y hora de pruebas. Autoguarda cada 15 s y al morir/recuperar/salir. Los enemigos
muertos no se reponen hasta pedirlo desde el panel. Los estados transitorios de IA y proyectiles
no se guardan; las criaturas retoman sus rutinas al cargar. Los objetos de botín en el suelo usan
el `ItemDrop` existente: caducan a los 300 s y no persisten al cerrar. Las mochilas sí persisten.

La isla incorpora vida y guardado de mochilas en su JSON existente, pero no genera esta nueva fauna
ni enemigos automáticamente. No se han cambiado mapas, generador ni modelos de mano.

## Código para Claude

- `scripts/creatures/creature_db.gd`: perfiles, probabilidades y valores de equilibrio.
- `scripts/creatures/creature_actor.gd`: máquina de estados, física, percepción, combate, rutinas,
  daño y botín. Sustituir el nodo `Visual` para incorporar arte. Señales `state_changed`,
  `attack_started`, `damaged` y `died` para animación, sonido y progresión.
- `scripts/creatures/creature_projectile.gd`: proyectiles barridos contra colisión real.
- `scripts/creatures/death_backpack.gd`: mochila, recuperación parcial y serialización.
- `scripts/player/player_combat.gd`: combate del jugador, vida/energía, veneno y muerte.
- `scripts/creatures/combat_arena.gd`: montaje de pruebas, panel, población y guardado independiente.

Percepción a 5 Hz y movimiento a frecuencia de física. La navegación es **local** (rodear paredes,
subir escalones de 0,55 m y evitar precipicios); no hay búsqueda de caminos de largo alcance.
Antes de desplegar en la isla falta resolver navegación en cuevas/puentes y carga de colisiones,
asignar hábitats y apariciones por fase de torre, balancear, y sustituir modelos/animaciones.
Domesticación, leche, reproducción, hambre individual, nidos, sigilo elaborado, bloqueo/parry,
destrucción de construcciones y purificación de la torre quedan fuera de esta primera versión.

## Validación

`tools/test_creatures.gd` cubre perfiles, percepción bloqueada por paredes, ataques anunciados,
persecución física, huida/defensa/caza, veneno, fase del jefe, proyectiles contra paredes, cooldown,
desgaste, botín único, muerte, guardado/carga de mochila, equipo y recuperación parcial.
Usa `user://combat_arena_test.json`, distinto del guardado de pruebas manuales.
Ejecutar con el Godot de Zylann y un APPDATA aislado para no modificar datos del usuario:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.godot\combat_test_runtime'
$env:LOCALAPPDATA = $env:APPDATA
.\godot.windows.editor.x86_64.exe --headless --path . --script res://tools/test_creatures.gd
```
