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

## Sinergias nuevas (2026-10-07, aprobadas por Yago: "me gustan todas")

Cada una tiene su forma de contrarrestarla. Prueba: `tools/test_synergies.gd`.

| # | Sinergia | Qué hace | Cómo contrarrestarla |
|---|---|---|---|
| 1 | Marca del rastreador | Si un rastreador te ve, quedas marcado 8 s: los arqueros te ven desde 1,5 veces más lejos y apuntan adonde estás al disparar (no adonde estabas) | Matar primero al rastreador; esconderte hasta que pase |
| 2 | Muro de escudos | Dos soldados peleando a menos de 2,5 m forman muro: de frente reciben solo el 30 % | Rodearlos o rodar a su espalda |
| 3 | El mago cura al capitán | Con el capitán por debajo de la mitad, un mago a menos de 10 m lo cura (6/s) quieto | Pegar al mago (interrumpe) o cortar su línea de visión |
| 4 | Último grito del capitán | Al morir: si quedan 2 o menos, huyen (el rastreador se rinde); si quedan más, furia (+30 % daño, reciben +20 %) | Matarlo el último o el primero según cuántos queden |
| 5 | Venganza | Quien ve morir a un compañero se enfurece 15 s (ataca sin esperar turno) y busca al culpable | Matar sin testigos (sigilo) |
| 6 | Cuerno de alarma | El arquero de una torre de vigía que te ve toca el cuerno: todos a 45 m despiertan y buscan | Matar al vigía sin que te vea |
| 7 | Relevo de guardia | De 6:00 a 6:30 y de 20:00 a 20:30 el vigía baja y la torre queda vacía | Observar y aprovecharlo |
| 8 | El ritual protege al jefe | El guardián recibe menos daño según los magos del ritual vivos (hasta −75 %) | Limpiar el ritual antes del jefe |
| 9 | Cadena de mando | Si cae una patrulla entera, el campamento está en guardia un día (no duermen, los puestos ven un 30 % más) | Atacar lejos de su ruta (más adelante: esconder cuerpos) |
| 10 | Hoguera | De noche, los del campamento ven un 45 % menos lo que está fuera de la luz (7 m). Se puede apagar (clic derecho): despiertan y buscan; vuelve a arder al día siguiente | Colarse por la sombra, o apagarla para provocar el caos |
| 11 | Runas | Con alguna pieza de la armadura antigua, los magos te ven un 60 % más lejos y te sienten a 10 m aunque estés a su espalda | Quitarte la armadura antigua para colarte |
| 12 | Moral | Si un grupo sin capitán pierde la mitad, los rastreadores (gente corriente) se rinden y soldados/arqueros huyen; los enmascarados nunca. Si atacas a un rendido, huye | Rendidos no atacan: perdonarlos o no es decisión tuya |
