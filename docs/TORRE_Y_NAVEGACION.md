# Torre por días y navegación

La isla normal crea `TowerDirector` al entrar. Se ubica en el centro de la región de suelo corrupto del mapa actual (aproximadamente x=96, y=38,6, z=-176 metros). El día de primera aparición es configurable con `first_day`; por defecto día 1. Reloj, dormir y adelantar el tiempo con T activan las fases. En una partida antigua ya avanzada se aplica su día actual.

| Día de aparición | Fase y población acumulada máxima, antes de bajas |
|---|---|
| 1 | Torre emergente provisional; 4 exploradores/rastreadores. |
| 2 | Mini campamento con 2 refugios; 4 exploradores + 2 arqueros. |
| 3 | Campamento completo con 6 refugios; 18 enemigos normales incluyendo soldados, capitanes, magos y arqueros. |
| 4 y siguientes | Torre completa con interior y entrada, mega campamento con 12 refugios, 33 enemigos normales y un guardián dentro. Patrullas de la zona afectada y patrullas ocasionales por caminos registrados. |

Las fases añaden refuerzos, sin resucitar bajas. El jefe no reaparece al guardar/cargar ni se añade otra vez al día siguiente. Los estados de fase, vida, bajas, alerta, rutas y punto pendiente de las patrullas se guardan junto al jugador. Matar al jefe emite `boss_defeated`; el portal y la resolución narrativa del ancla siguen pendientes.

Las escuadras de fases 3/4 mezclan roles para conservar protección, inspiración y flechas encantadas. Sus rutas tienen 2 puntos al principio y 4 después, con descanso y retorno inverso. El radio de patrulla se amplía por fases y los puntos se ajustan a la región corrupta. Los cuerpos se crean cerca del jugador y solo simulan cuando hay colisiones de suelo cargadas; se congelan lejos para no caer en terreno descargado. No se cambia la población de fauna de la isla.

## Caminos futuros

`register_road(id, Array[Vector3])` recibe el recorrido real de un camino cuando exista. En fase 4, aproximadamente el 40% de las rutas registradas recibe una patrulla de explorador, arquero y soldado. La elección depende del identificador y es estable entre partidas/cargas. Si no hay caminos registrados, no se inventan caminos ni patrullas de carretera. Se puede registrar después de alcanzar fase 4.

## Navegación

`creature_navigation.gd` usa A* sobre suelo y obstáculos físicos actuales, sin una malla horneada que quede desactualizada al editar voxels. Busca celdas con espacio para el cuerpo, evita suelo ausente/pendientes bruscas, comprueba los segmentos contra paredes y rodea obstáculos. Detecta bloqueos o cambios de destino y recalcula; no atraviesa los bloques nuevos.

Es una búsqueda local de hasta 20 metros por eje, 700 expansiones, máximo dos peticiones por paso de física y reintentos espaciados. Destinos largos se abordan por tramos. Mantiene el movimiento/collision original y su pequeño rodeo para separarse de otros cuerpos. No garantiza resolver laberintos de varios pisos, grandes acantilados ni un camino completamente encerrado. No teletransporta al enemigo para resolver un atasco.

## Provisional y validación

Torre/refugios son geometría básica con colisión, reemplazable por los modelos definitivos. No son bloques destructibles ni incluyen todavía mobiliario, cofres o misiones. Los caminos, su arte y conexiones entre estructuras siguen pendientes. Las fases sí están integradas al reloj y guardado de la isla; las pruebas habituales de otros sistemas no despliegan la torre.

`tools/test_navigation_tower.gd`: rodeo físico de pared larga, cambio de ruta al construir, suelo ausente, fases 1–4, no duplicación, persistencia de bajas, jefe y registro de caminos. Incluye comprobación sobre los mapas reales de la isla. `tools/run_tests.sh` incluye esta prueba.

`tools/test_tower_island.gd`: carga la isla completa, adelanta su reloj y comprueba las fases, los refuerzos y el guardado real de las bajas. Ejecutar con APPDATA y LOCALAPPDATA apuntando a una carpeta de pruebas independiente. Ambas pruebas terminaron con 0 fallos.
