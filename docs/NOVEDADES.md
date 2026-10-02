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
- Sobre la mesa: mochila de marinero y pico de piedra. — ruinas
