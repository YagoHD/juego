# Sigilo y alertas

Mantener Ctrl agacha al jugador, baja su cámara y colisión, reduce el paso al 45% y hace los pasos más silenciosos. No permite correr. Bajo un techo bajo no puede levantarse hasta tener espacio. El modelo definitivo necesita su animación de agacharse; la lógica y la cámara ya funcionan.

Los cinco enemigos miran hacia la nariz del cuerpo provisional: cono frontal de 120 grados, ampliado a 160 cuando están alerta. Las paredes bloquean la detección. Agacharse reduce el alcance visual al 45%; por detrás no te detectan así. De pie pueden detectarte cerca por ruido, hasta 3 metros caminando o 6 corriendo.

Ver al jugador avisa a enemigos a 10 metros. Los compañeros reciben el último lugar conocido y lo investigan; no reciben una posición actual detrás de paredes. Al perder contacto, buscan durante 12 segundos en torno al último lugar conocido, después regresan. Durante 60 segundos desde la última detección/aviso tienen alcance visual aumentado un 35%; este tiempo corre durante el juego. La alerta restante se guarda en la arena. Las alertas se emiten como máximo cada 10 segundos por observador y no se retransmiten automáticamente.

Con cuchillo, hacha, pico o lanza, agachado y dentro del sector trasero de 120 grados de un enemigo desprevenido, el golpe es crítico. Rastreador y mago mueren al instante. Soldado, capitán y guardián reciben el mayor entre triple daño del arma y 35% de vida máxima, aplicando después armadura. Aturdimiento: 2,5 segundos; guardián: 1,5 segundos. Estar alerta impide nuevos críticos, evitando encadenar aturdimientos. Recibir daño también provoca reacción y aviso si sobrevive.

Estados visibles traducidos encima del enemigo: buscando, regresando, aturdido, patrullando; aparece «Alerta» mientras dura la vigilancia. Conserva los patrones de ataque anteriores. Fauna sin cambios. Movimiento usa el rodeo local existente, no navegación completa alrededor de obstáculos largos.

Validación: `tools/test_stealth.gd` y regresión `tools/test_creatures.gd`. Ajustes en `creature_actor.gd`, velocidad y entrada en `player.gd`, aplicación del crítico en `player_combat.gd`.
