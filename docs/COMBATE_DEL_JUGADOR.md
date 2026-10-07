# Combate del jugador

Lógica disponible en la isla y en el mapa de pruebas. En la arena, F2 → Dar equipo de pruebas entrega arco, 32 flechas y escudo, además de las armas anteriores. E abre el inventario con el hueco de escudo: arrastrarlo ahí permite bloquear sin cambiar el arma principal. También bloquea si lo llevas seleccionado en la barra. Las recetas de arco/flechas/escudo están en el diario.

## Controles provisionales

| Acción | Control | Comportamiento |
|---|---|---|
| Ligero | Clic izquierdo corto | Impacto al soltar antes de 0,55 s; mantiene el picado al apuntar al mundo. |
| Pesado | Mantener clic izquierdo y soltar | Listo tras 0,55 s, daño ×2, coste ×1,8, recuperación ×1,7. No lanza un ligero previo; impacta al soltar sin sumar otra preparación. Daño, guardia, esquiva o cambiar arma cancelan la carga. |
| Guardia | Mantener clic derecho | Cubre sector frontal de 120°. Reduce daño un 65%; cuesta 0,7 de resistencia por punto de daño original. No protege espalda. |
| Bloqueo perfecto | Pulsar clic derecho justo antes del impacto | Ventana de 0,22 s. Sin daño, veneno ni gasto de resistencia. Aturde 1,5 s al atacante cercano (máximo 4 m); un proyectil lejano se detiene sin aturdir remotamente al tirador. |
| Escudo | Equiparlo + mantener clic derecho | Sin daño si hay resistencia suficiente; cuesta 1,5 de resistencia por punto de daño original. Sin resistencia, se rompe la guardia, recibes el golpe completo y quedas un segundo sin acciones ofensivas/defensivas. |
| Ataque aéreo | Saltar con Espacio y atacar | Ligero y pesado ganan ×1,25 de daño si se inician en el aire. El vuelo de pruebas no cuenta como salto. |
| Esquiva corta | Alt | Hacia atrás; A+Alt izquierda, D+Alt derecha. 12 de resistencia; dura 0,22 s a 4,5 m/s. Evita golpes alejándote; no da inmunidad garantizada. |
| Voltereta | Segundo Alt antes de 0,4 s | 32 adicionales de resistencia (44 contando primera esquiva), 0,65 s a 7,5 m/s, inmunidad durante la voltereta. Sin atravesar paredes. |
| Arco | Seleccionarlo, mantener clic izquierdo, soltar | Consume una flecha al disparar y un uso de arco. |

Volver a pulsar guardia continuamente no renueva la ventana perfecta: requiere 0,7 segundos para volver a armarla. Guardia, tensión y preparación pesada ralentizan el movimiento y no permiten correr. La resistencia no se regenera durante guardia, tensión o esquiva; tras gastar resistencia espera 0,7 s y recupera 18/s. El daño ambiental no se bloquea. La inmunidad de la voltereta sí evita daño durante su duración.

## Combos

Cámara libre: mantener botón central; Alt queda reservado para esquivar. El clic derecho conserva interacciones cuando llevas objetos de construcción/uso y recupera la mochila al apuntarla. Con un arma, arco, manos vacías o escudo equipado activa guardia. Mayús + clic derecho permite usar/colocar objetos incluso llevando escudo. Las teclas X/G/Z ya no activan combate.

La ventana entre ataques es de 1,5 s después de la recuperación. H indica pesado; L, ligero. Cadenas actuales:

- L-H-L: daño del remate ×1,5, aturdimiento de 0,6 s.
- L-L-H: daño del remate ×1,65, aturdimiento de 1 s.
- H-L-L: daño del remate ×1,4, aturdimiento de 0,5 s.

Los multiplicadores se aplican al daño correspondiente al tipo de ataque, y se combinan con salto. El remate necesita alcanzar al enemigo para dañarlo y aturdirlo. Recibir daño, esquivar, abrir interfaz o cambiar de arma corta la cadena. Se conserva el crítico por la espalda de un enemigo desprevenido.

## Arco

Daño base entre 5,5 y 22 según tensión; alcanza máxima potencia a 1,5 segundos. Velocidad entre 14 y 30 m/s. Mantenerlo más no aumenta indefinidamente el daño: después de 2,5 s aumenta la dispersión del disparo y el consumo de resistencia pasa de 3/s a 18/s. Disparar cuesta otros 6 puntos. Al agotarte cancela la tensión sin gastar flecha. Abrir interfaz/cambiar arma cancela la tensión.

Daño al impacto = daño de tensión × distancia × ventaja de altura × sigilo, después se aplica armadura/protección de la víctima:

- Distancia desde el lanzamiento hasta el impacto: +2% por metro, máximo +60%.
- Altura de lanzamiento respecto a ojos del objetivo: +6% por metro de ventaja, máximo +50%; no penaliza disparar desde abajo.
- Disparar agachado contra objetivo desprevenido: ×1,5. Una víctima ya alerta no recibe ese bonus.

Se guarda posición de lanzamiento y condición de agachado al soltar; moverte después no altera la bonificación. Las flechas tienen barrido de colisión y duran cuatro segundos. Su trayectoria actual es recta: caída balística y recuperación de flechas del suelo pendientes.

## Visuales y validación

HUD muestra resistencia, combo, guardia y tensión/fatiga del arco. Poses provisionales de guardia/tensión/pesado y voltereta en el avatar; escudo provisional en el brazo izquierdo en tercera persona. Animaciones definitivas, acciones de las manos en primera persona y efectos finales pendientes de los modelos/rigs.

Pruebas: `tools/test_player_combat.gd` valida eventos de entrada, daño, preparación/interrupción, combos, parry, costes de guardia, inmunidad/movimiento, ataques aéreos y flechas reales. Regresiones: criaturas, sigilo, patrullas, equipo, inventario y fabricación.

Valores en `player_combat.gd`; flechas y multiplicadores en `player_arrow.gd`; entrada/movimiento en `player.gd`. Estado de vida/resistencia, arco con desgaste, flechas y escudo se guardan por los sistemas actuales; acciones transitorias no continúan al cargar.
