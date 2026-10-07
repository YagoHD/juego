# Ataques del mago

Mago disponible en F2 de la arena y en sus patrullas. Alterna bola eléctrica → descarga vertical → rayo continuo y repite; conserva el encantamiento de flechas del arquero y los beneficios del capitán/soldado.

- Bola eléctrica azul: 14 de daño base, velocidad 8 m/s, aviso de 1,15 s. Apunta a la posición inicial, se puede esquivar y choca con paredes/cuerpos.
- Descarga vertical: marca un círculo azul de 2 metros de radio en el lugar donde estaba el jugador. Espera 2 s y cae ahí, sin perseguirlo. Hace 24 de daño base a quien siga dentro; salir, usar voltereta o una cubierta evita el daño. No se bloquea con la guardia porque cae desde arriba. Un golpe que interrumpe al mago cancela el círculo y la descarga pendiente.
- Rayo continuo: aviso de 1,15 s y canalización de hasta 3 s, alcance 13 m, giro máximo de 0,75 rad/s. Hay que mantener contacto físico con el cuerpo del jugador. Obstáculos o un movimiento lateral que saque al jugador de la línea rompen el enlace. Daño cada 0,65 s: `min(14, 4 + 3 × segundos enlazados)`; inspiración puede aumentarlo. El daño escala solo mientras mantiene contacto y se reinicia al perderlo.

Si el rayo hace daño, el jugador se mueve al 55% de su velocidad durante 0,8 s; nuevos impactos renuevan el efecto. Romper el enlace deja que expire. Un escudo que absorba todo el impacto evita también la ralentización, pero pierde resistencia. El bloqueo perfecto evita el impacto y puede aturdir al mago si está cerca. La voltereta evita el daño. Golpear/aturdir/matar al mago interrumpe su canalización.

Las patrullas cuentan la canalización como ataque activo y no vuelven a caminar mientras está canalizando. Los modelos/partículas definitivos están pendientes: ahora se usan círculo, destello y haz básicos, suficientes para leer las zonas y probar la lógica. Los efectos transitorios no se guardan como ataques pendientes.

Pruebas: `tools/test_mage.gd`, incluyendo el retraso en física, salida del círculo, daño progresivo, ralentización/recuperación, paredes, techo, interrupción y escudo. Regresiones: criaturas, combate del jugador y patrullas.
