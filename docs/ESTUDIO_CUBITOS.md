# Estudio: mundo de cubitos pequeños, construcción y destrucción

Para decidir con Yago antes de tocar nada grande. Fecha: 2026-10-05.

## 1. ¿Todo el mundo de cubitos pequeños?

Hoy hay dos tamaños:
- **Terreno**: bloques de 0,5 m (la mitad que Minecraft). Se cava y se construye bloque a bloque.
- **Objetos de cubitos**: palmeras, rocas, setas y ahora el barco de prueba, con cubitos de 6-10 cm.

| Opción | Cómo se vería | Coste | Mundo grande procedural |
|---|---|---|---|
| A. Terreno de 0,5 m + todo lo demás de cubitos (como la prueba) | Suelo de bloques con texturas naturales y lleno de detalles pequeños (piedrecitas, ramas, conchas); árboles, rocas, construcciones y objetos de cubitos | Bajo: es lo que ya hay | Sí, sin problema |
| B. Terreno de 0,25 m | Laderas y orillas con escalones la mitad de grandes | 8 veces más datos y unas 4 veces más caras que dibujar; cavar va más lento (cada bloque es más pequeño) | Difícil: hay que reducir mucho la distancia de vista |
| C. Terreno de cubitos de 6 cm | Como en las imágenes de cerca | Unas 500 veces más datos | No es viable |
| D. Terreno suave (sin escalones) + objetos de cubitos | Colinas y arena lisas, como Valheim/Enshrouded | Rehacer el terreno, el cavado y las texturas | Sí (el motor lo admite) |

Mirando las imágenes "posible", el suelo (arena, hierba) se ve casi liso con piedrecitas; las rocas y
acantilados son **bloques de piedra grandes e irregulares**; todo lo hecho por personas (barco, cajas,
cuerdas) es de cubitos pequeños.

**Recomendación**: A ahora (ya funciona) y estudiar después si la arena y la hierba deberían ser lisas
(D solo para la capa de arriba) o con bloques de 0,25 m solo en la playa de la Beta.

## 2. Construir y destruir: piezas en vez de bloques

En el barco de la imagen casi no hay bloques: hay **tablas, vigas, postes, cuerdas y telas**. Propuesta:

- **El terreno sigue siendo de bloques**: tierra, arena, piedra... se cava y se coloca como ahora.
- **Lo construido es de piezas**: cada pieza es un objeto de cubitos con forma propia:
  tabla (2 m × 25 cm × 6 cm), viga, poste, cuaderna curva, cuerda, tela, clavija...
  - Se colocan **libres en el mundo**, con imán a una rejilla fina (6 cm) y giros de 15° o 90°.
  - Es la misma idea que la fabricación en el suelo que ya existe (objetos sueltos donde los sueltas,
    apilados, girados con la rueda). Construir sería esa misma fabricación a lo grande.
  - Cada pieza tiene material y aguante. Al golpearla se agrieta (se le quitan cubitos para que se
    vea dañada) y al romperse **devuelve el material** (la tabla, o astillas si se rompe a lo bruto).
  - Opcional: que las piezas necesiten apoyo (suelo u otra pieza); si se quita el apoyo, caen.
- **Las estructuras ya hechas (el barco, casas, castillos) se generan con esas mismas piezas**. El
  barco no sería un bulto de cubitos: sería una lista de tablas, cuadernas y cuerdas colocadas. Así se
  puede **desmontar tabla a tabla** para conseguir material (lo bonito del naufragio).

### Catálogo inicial de piezas
| Pieza | De qué sale | Para qué |
|---|---|---|
| Tabla | Tronco + hacha / desmontar | Suelos, paredes, cascos |
| Viga / poste | Tronco | Estructura |
| Cuaderna (curva) | Solo del barco | Desmontar el barco |
| Cuerda | Fibra | Atar piezas, colgar |
| Tela de vela | Barco | Tejados, velas, mochila |
| Piedra labrada | Piedra + herramienta | Muros (mundo medieval) |

### Qué cambia en el código
- Nuevo tipo de objeto colocado "pieza de construcción" (como PlacedItem, pero con choque, aguante
  y apoyo), guardado en la partida.
- El generador del barco devolvería piezas en vez de cubitos sueltos.
- Romper/colocar bloques del terreno no cambia.

## Preguntas para Yago
1. ¿Te gusta la idea de "terreno de bloques + construcciones de piezas"?
2. ¿Las piezas se caen si les quitas el apoyo, o eso para más adelante?
3. ¿La arena y la hierba lisas (sin escalones) o con escalones pequeños?
