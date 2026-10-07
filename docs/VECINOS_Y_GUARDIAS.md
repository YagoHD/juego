# Vecinos, guardias y delitos

> Primera versión programada (2026-10-07) en una aldea de pruebas (`scenes/village_test.tscn`,
> `Pruebas de aldea.bat`), sin tocar el mapa. Valores provisionales: se ajustan en el código
> (`scripts/village/`). Reglas de delitos: las confirmadas en `HISTORIA_INICIO_BETA.md`.

## Qué hacen otros juegos (resumen)

- **Skyrim / Oblivion (Radiant AI):** cada vecino tiene una lista de "paquetes" por horas
  (dormir en su cama, trabajar en su puesto, comer en la taberna) y, dentro de cada uno, se mueve
  libremente por varios puntos ("sandbox") para no estar clavado en un sitio. Es lo que más vida da
  con menos coste.
- **Kingdom Come: Deliverance:** cada vecino tiene rutina diaria y reacciona a lo que hace el
  jugador; los **testigos** denuncian a los guardias y recuerdan lo que vieron; multa o cárcel.
  Para miles de personajes usan **niveles de detalle de la IA**: solo los cercanos piensan a tope.
- **Stardew Valley:** horarios fijos por día y lugar, sencillos y fáciles de leer para el jugador.
- **Juegos con muchos personajes en general:** los lejanos se simulan baratos (saltan al sitio que
  les toca según la hora) y los que no se ven no gastan nada.

## Cómo lo hacemos nosotros

- **Horario por oficio**: granjero, pescador, mercader, herrero, panadero, tabernero, banquero,
  leñador, cazador, herbolaria, sacerdote, anciana, viejo minero, carpintero, refugiado, guardia de
  día y de noche (31 en la aldea de pruebas). A cada hora le toca un lugar (casa, campo, muelle,
  mercado, fragua, horno, taberna, banco, bosque, capilla, campamento de refugiados...) y una actividad. Dentro del
  lugar pasean entre puntos al azar, como el "sandbox" de Skyrim.
- **Niveles de detalle:** cerca del jugador (menos de 30 m), IA completa con física; más lejos,
  sin física: van al sitio que les toca a paso de persona, pegados al suelo; muy lejos (más de 90 m) desaparecen y
  solo queda su ficha (dónde deberían estar). Objetivo: 20-30 vecinos sin que se note.
- **Cada vecino tiene ficha persistente:** identificador, nombre, oficio, casa, vida y si está vivo.
  **La muerte es permanente** y se guarda: cargar no resucita a nadie.
- **Reacciones:** los civiles huyen si les atacan o si ven violencia cerca; los guardias defienden.

## Delitos (reglas confirmadas, detalles provisionales)

Solo cuentan si **algún vecino o guardia lo ve** (tiene línea de visión a menos de 18 m). Si lo
ve un guardia, cuenta al momento. Si solo lo ven vecinos, **corren a avisar al guardia más cercano**
y no cuenta hasta que llega alguno: si mueren antes (o no queda ningún guardia), se olvida.
Solo multas, sin cárcel (decidido con Yago).

| Qué haces | Qué pasa |
|---|---|
| Romper o colocar bloques en el pueblo | Aviso (1 a 5). Al quinto, delito leve: multa pequeña; un guardia viene a cobrarla. |
| Golpear a un vecino | Delito medio: multa; un guardia viene a cobrarla. Si te vas sin pagar o vuelves a pegar, los guardias te atacan. |
| Golpear a un guardia | Resistencia: multa mayor y los guardias te atacan. |
| Matar a alguien | Delito máximo: los guardias te atacan nada más verte en el pueblo. **No se perdona pagando.** |

- **Pagar (como en Kingdom Come):** junto al guardia, tecla **R** o clic derecho sobre él: se abre
  una pantalla con "Lo que entregas", donde se arrastran monedas de oro u objetos; se ve cuánto
  vale lo ofrecido y, si llega, se paga. Si se da de más, devuelve el cambio en monedas. Lo no
  entregado vuelve al inventario. Precios provisionales (`VillageLaw.VALUES`, en monedas).
- **Dinero:** monedas de oro. Se consiguen fundiendo pepitas de oro en un horno de piedra (cada
  pepita, 2 monedas: todo su valor) o cambiándolas en el banco (1,5 monedas: con pérdida). Las
  pepitas salen a veces al picar piedra y más en el mineral (provisional: vetas propias más adelante).
- Si mueres mientras te persiguen por una multa, dejan de atacarte (la multa sigue). Un asesino
  sigue siéndolo.
- Los guardias persiguen **fuera del pueblo, pero no mucho** (25 m); hasta 60 m solo si te tienen
  muy cerca (a menos de 6 m).
- Los guardias que no te ven van a **buscarte al último sitio donde alguien te vio**; no saben
  dónde estás a través de las paredes. Con una multa o un delito pendiente, los guardias piensan
  aunque estén lejos.

## Coste medido

En la nube (ordenador lento, sin gráfica): unos 3 ms por paso de física sin vecinos y 4-7 ms con
los 20. En el PC de Yago debería ser bastante menos; lo enseña la aldea de pruebas arriba a la
izquierda. Los vecinos quietos (durmiendo, trabajando, charlando) apenas gastan.

## Pendiente de decidir con Yago

- Cuánto vale cada objeto (va con el comercio y las monedas de oro).
- Diálogos de cada vecino (sistema 4) y vendedores (sistema 5).
