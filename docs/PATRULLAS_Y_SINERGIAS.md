# Patrullas y sinergias

En la arena, F2 permite crear patrullas aleatorias y generar al arquero por separado. Reponer criaturas incluye una patrulla nueva. Las partidas antiguas siguen cargando; usar el botón para probar los grupos nuevos. No se añaden enemigos a la isla principal.

## Arquero

50 de vida, 11 de daño, alcance de ataque 16 metros, detección 17 metros, aviso de un segundo y recuperación entre ataques de 2,1 segundos. Flechas a 16 metros por segundo: apuntan al lugar donde estabas al preparar el disparo y chocan con paredes y cuerpos. Mantiene distancia y retrocede cuando te acercas durante su recuperación. Es vulnerable al crítico sigiloso como mago/rastreador. Botín: tela y cuerda; modelo y arco definitivos pendientes.

## Grupo

Cada patrulla lleva capitán, soldado, mago y arquero, y puede incluir rastreador. Su composición varía por ese quinto miembro. Se generan rutas de 2–4 puntos y descansos de 3–7 segundos. Recorrido A B C D C B A B…; descansan en cada punto. Los miembros ocupan posiciones próximas distintas y esperan al grupo. Combate y búsqueda interrumpen la marcha; después vuelven al punto pendiente. Se guardan ruta, dirección, punto, descanso y pertenencia de cada enemigo.

Sinergias actuales, entre miembros de la misma patrulla:

- Capitán: aumenta un 20% el daño de compañeros a menos de 8 metros y con visión mutua. Matarlo o aturdirlo retira la inspiración.
- Soldado: reduce un 20% el daño que reciben mago y arquero a menos de 3 metros, con visión. No acumula protección por varios soldados. Matarlo o aturdirlo retira la protección.
- Mago + arquero: el mago carga una flecha encantada cada 8 segundos si están a menos de 8 metros con visión y el arquero combate. Multiplica por 1,8 el daño de una flecha. Una carga almacenada permanece hasta dispararse; no es curación ni resurrección. Se combina con la inspiración. Es la primera fusión de ataques; no transforma dos cuerpos en una criatura nueva.
- Rastreador/soldado/capitán: se aproximan por lados alternos en vez de seguir todos la misma línea.
- Todos: separan el inicio de ataques al menos 0,65 segundos y limitan a dos los ataques que se están preparando o cargando. Los combos mantienen sus avisos originales. Las alertas y búsquedas conservan el sistema de sigilo anterior; no rastrean al jugador detrás de paredes.

Las etiquetas muestran Inspirado, Protegido o Flecha encantada. Los proyectiles propios chocan contra aliados sin dañarlos: se puede cortar una línea de tiro. Los beneficios se actualizan cada 0,25 segundos.

## Límites y revisión

La protección es una reducción de daño provisional, no una animación física de escudo. Las rutas usan puntos en el suelo plano de pruebas y el rodeo local existente; un obstáculo largo puede impedir alcanzar un punto y mantener al grupo esperando. No hay navegación global, fusión de cuerpos, animaciones finales ni despliegue aleatorio en la isla. Ajustar equilibrio tras pruebas de juego.

Implementación: `enemy_squad.gd` coordina rutas/órdenes/apoyos; `creature_actor.gd` ejecuta movimientos y ataques; `creature_projectile.gd` mueve flechas; `combat_arena.gd` genera y guarda grupos. Pruebas: `tools/test_squads.gd`, `tools/test_stealth.gd`, `tools/test_creatures.gd`.
