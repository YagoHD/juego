# Documento de diseño — Beta (Isla del Naufragio)

> Memoria viva del proyecto. Se actualiza cuando cambia el diseño.
> El `.docx` original está en la raíz del repo. Si algo difiere, **prevalece este archivo**.

## Reparto de roles
El usuario (Yago) aporta las ideas y la visión; **no programa**. Claude escribe todo el código
y ayuda a generar ideas y a definir el diseño. Se trabaja en **español**.

## Motor y tecnología
- **Godot 4** con mundo **3D**. Proyecto serio, grande, desarrollado poco a poco.
- Voxels **pequeños** (estilo Cube World): más detalle que Minecraft (columnas, arcos, muebles).
- Se apoya en el módulo **godot_voxel** (Zylann) vía GDExtension (chunks, multihilo, LOD).
- **El rendimiento es el gran reto.** Confirmar con un test antes de comprometerse.
- Se descartó el prototipo web (Three.js).

## Forma de trabajar
- Este documento es la memoria entre sesiones.
- **Git desde el día 1.**
- Sistemas pequeños y separados: combate, construcción, habilidades, mundo, idioma, sueños.
- Arquitectura primero; pasos pequeños y verificables (mundo plano → ruido → chunks → romper bloques).
- Para bugs visuales: capturas de pantalla + mensajes de consola.

---

## Visión general
Mundo de voxels pequeños con libertad de colocar/romper bloques, estilo Cube World, con más
profundidad en construcción, combate y progresión. Empieza por una **Beta** que es tutorial,
enganche y primer hito.

### Pilares de diseño
- **Voxels pequeños:** más detalle que Minecraft.
- **Construcción con profundidad:** materiales con propiedades (la madera arde, la piedra aguanta
  peso), integridad estructural y beneficios jugables (torre = vigilancia, forja = mejor equipo).
- **Combate con profundidad:** stamina, esquivar, bloquear, parry; enemigos con señales visibles;
  armas con estilos distintos; los enemigos también pueden destruir bloques.
- **Progresión por uso:** pelear sube espada, construir sube arquitectura, leer sube Lenguaje.
  Sin repartir puntos.
- **Historia que se cuenta sola:** nadie explica nada; ruinas, restos, textos y sueños cuentan el
  pasado, y los sistemas empujan al jugador hacia la amenaza.
- **Curiosidad premiada:** observar abre puertas; no hacerlo cierra algunas, pero nunca bloquea.

### Estructura general
- **Beta:** isla remota con supervivencia, torre que emerge, campamento enemigo y portal.
- **Mundo grande (el juego de verdad):** tras el portal, un mundo **medieval**, grande y a poder ser
  **generado proceduralmente**, con biomas variados y una guerra de fondo. La isla y el naufragio son
  solo la Beta: lo que se programe debe servir sobre todo para el mundo grande (sistemas generales,
  no cosas solo de playa).
- Este documento cubre **solo la Beta**. Todos los nombres son provisionales.

### Cómo se cuenta la historia sola (3 trucos)
1. Una amenaza visible desde el principio (la torre en el horizonte).
2. El mundo cuenta el pasado (ruinas, restos, textos, sueños).
3. Los sistemas empujan al jugador hacia la amenaza (corrupción, campamento, recursos cerca).

### Tono
La isla es bonita y amable ("family friendly"), horizonte hermoso; el contraste con la torre y su
corrupción despierta la curiosidad. El mundo grande tendrá biomas variados (bonitos, feos, áridos,
desérticos, fríos, calientes, montañosos, rocosos, ríos, mares y lagos).

---

## La Beta

### Flujo
1. **Naufragio:** llega a la playa entre restos del barco.
2. **Supervivencia:** recoge materiales, base pequeña + cama, mejora equipo.
3. **La torre emerge:** durante 4 días crece desde una roca; se puede observar e investigar.
4. **El enemigo se instala:** enemigos en la zona + campamento.
5. **Preparación:** sube nivel minando, combatiendo, pescando, leyendo textos.
6. **La torre:** elige camino (magia, minería, pirotecnia, sigilo, frontal…) y derrota/desactiva el ancla.
7. **El portal:** la purificación abre un portal, aparece Kaelen y pide ayuda.
8. **Entrada al mundo grande:** fin de la Beta.

### Objetivos
- Enseñar sin carteles (minar, pelear, pescar, construir suben nivel).
- Probar los sistemas base (construcción, combate, habilidades, idioma, cuaderno).
- Rejugabilidad: no se puede ver todo en una partida.

### La isla
Grande pero remota, delimitada por el mar. Diseñada **a mano o con semilla fija** (lo procedural
masivo queda para tras el portal).
- Montaña nevada con lago en la cima; río que baja hasta el mar.
- Biomas de playa, bosque, pradera; montaña nevada con minas y minerales.
- Todo lo necesario para el tutorial: madera, piedra, minerales, agua, pesca, cuevas.

**Capas de dificultad:** Costa/playa (básico) → Bosque/pradera (recursos, pesca, primeros enemigos)
→ Montaña/minas (herramientas, minería) → Zona de la torre (desafío final).

**Legibilidad:** la torre se ve desde casi toda la isla (punto elevado/central); el horizonte es
bonito desde el día 1; el borde de la zona corrompida marca visualmente dónde empieza el peligro.

### Supervivencia y sueño
Naufraga, construye base pequeña, mejora equipo, duerme en cama cada noche. Dormir es supervivencia,
ritmo del tutorial y fuente de sueños narrativos.

- **Sueño (fatiga):** si no duerme, se acumula. Se evita con cafeína (escasa). Quien no duerme en
  cama se levanta con poca vida, mareado y cansado un rato.
- **Calidad de cama:** sin techo → descansa peor, más mareado; con refugio y puertas → descansa bien,
  sueños nítidos; a la intemperie sin cama → poca vida, mareo, cansancio, sueños fragmentados.
- **Cafeína:** recurso escaso con decisión detrás. La da el **grano de alba**, que crece cerca de
  zonas con energía (incluida la cercanía de la torre) → motivo para acercarse.

### La torre
Emerge del suelo con el **paso del tiempo** (NO por noches dormidas); completa al día 4. Es un reloj
visual, no una amenaza: no persigue a nadie. El jugador decide cuándo enfrentarse.

**Crecimiento:**
- Días 1-2: roca extraña, veta de color raro, hierba marchita, animales que evitan la zona.
- Días 2-3: la roca se agrieta, una veta de energía pulsa, surgen raíces.
- Días 3-4: estructura casi completa, material inestable en la base.
- Día 4: torre completa, empiezan a rondar enemigos.
- Día 5: campamento montado, crece por fases.

**Corrupción:**
- Aérea: ceniza violácea que cae despacio (señal visual, no amenaza).
- En el suelo: hierba apagada, tierra agrietada, venas oscuras lentas. **Estática:** no avanza, pero
  arruina el paisaje. El borde funciona como frontera natural (sin carteles ni muros).

**Observación:** acercarse pronto está permitido (el jugador asume consecuencias; los enemigos
fuertes se ven claramente demasiado duros). Cada fase revela algo que luego desaparece.

**Motivos para acercarse:** un recurso valioso solo existe cerca (cafeína o mineral raro); criaturas
y restos llegan a la isla; el campamento crece visiblemente.

### Enemigos y zonas
Humanos invasores, **solo** en la zona de la torre y el campamento. Dificultad crece hacia dentro.

| Zona | Enemigo | Papel |
|---|---|---|
| Borde | Rastreadores | Patrullas débiles, equipo básico |
| Campamento | Soldados | Más fuertes y organizados |
| Campamento | El Capitán | Lidera y guarda los documentos clave |
| Torre | Guardián de la torre | Jefe final de la Beta |

- **Humanos con rostro:** personas, algunas con la cara tapada. Hablan/escriben un dialecto
  incomprensible al principio. **Máscaras con significado:** los enmascarados son la casta que sirve
  al ancla; los de cara descubierta, soldados corrientes. Al derrotar a un enmascarado se ve que
  debajo hay una persona normal → el enemigo se humaniza sin texto.
- **Brotes:** criaturas nacidas de la corrupción; algunas se alejan de la zona como recordatorio.
- **Guardián:** ser de piedra muda, núcleo débil que cambia según el camino (magia lo desestabiliza,
  minería le corta la energía, pirotecnia lo agrieta).
- **PENDIENTE:** ¿pueden los enemigos romper construcciones del jugador?

### Caminos para resolver la torre
Varios caminos que se sienten distintos; cada uno con 3 estados. **Siempre** hay un camino base
abierto (combate frontal), nadie queda bloqueado.

| Camino | Cómo se juega | Pista en el mundo |
|---|---|---|
| Magia | Hechizo de purificación, canaliza energía en el núcleo | Veta de energía pulsante |
| Minería | Excava hasta el cristal que alimenta el ancla y lo extrae | Raíces que se hunden |
| Pirotecnia | Construye una carga y vuela el núcleo | Material inestable en la base |
| Alquimia | Prepara disolvente/antídoto y lo vierte en el origen | Espinar velado y cuarzo |
| Ingeniería | Estructura (pararrayos, canalización, presa) que absorbe/desvía | Flujo de la corrupción |
| Naturaleza | Planta flora que resiste y "come" la corrupción | Lirio de albor junto al lago |
| Sigilo | Infiltrarse, cortar suministro, sabotear el núcleo | Turnos de guardia en textos |
| Frontal | Derrota al Guardián peleando | Siempre disponible |

**Ventanas de observación:** cada fase revela algo que desaparece: roca agrietada (magia), raíces
(minería), estructura casi completa (pirotecnia). Con la torre completa no hay pistas nuevas.

**Tres estados de cada camino:**
- Descubierto a tiempo: se abre limpio, con pista y recompensa.
- Perdido pero recuperable: se abre más tarde con coste (misión con historia, no solo más enemigos).
- Cerrado por lore: no vuelve; el mundo explica por qué.

**Recuperar un camino perdido:** Magia → catalizador que ahora guarda el campamento; Minería →
raíces endurecidas, túnel nuevo con enemigos; Pirotecnia → robar el material del campamento.

**Cerrados por lore:** solo caminos secundarios (1-2), nunca los que sostienen el juego; siempre
quedan frontal + al menos dos alternativas. Causa visible (p.ej. el lirio de albor se seca para
siempre al completarse la torre). **Regla de oro:** lo que se cierra son atajos, no requisitos.

### Lore: el ancla, flora y minerales
La torre es un **ancla**: un bando de una guerra en otro mundo clava un punto de apoyo en un lugar
con mucha energía natural para abrir un paso. La isla es perfecta: el lago de la montaña es un pozo
de energía limpia.
- La **corrupción** es la energía del ancla envenenando el entorno. Estática porque el ancla aún no
  está activa del todo: solo gotea.
- El **naufragio** es el primer síntoma: al clavarse el ancla alteró el mar y provocó la tormenta.
- Los **enemigos** son una avanzadilla que cruza por las grietas del ancla para protegerla.

**Flora**
| Planta | Dónde | Función | Lore |
|---|---|---|---|
| Lirio de albor | Orilla del lago/río | Camino de naturaleza | Brota donde la energía es pura; se seca al completarse la torre |
| Grano de alba | Raro, cerca de energía | Cafeína (escasa) | Concentra energía vital, por eso quita el sueño |
| Luzmusgo | Cuevas y minas | Luz y pista | Brilla más cerca de energía: brújula hacia el cristal |
| Espinar velado | Zona corrompida | Ambiente y alquimia | Maleza muerta; útil para venenos/disolventes |

**Minerales**
| Mineral | Dónde | Camino | Lore |
|---|---|---|---|
| Cuarzo vivo | Montaña y cerca del lago | Magia | Almacena energía natural; catalizador |
| Corazón de ceniza | Bajo la torre | Minería | Alimenta el ancla; al extraerlo la torre pierde fuerza |
| Salitre | Cuevas de la costa | Pirotecnia | Base de la pólvora (guano mineralizado cerca de la playa) |
| Hierro, carbón, estaño | Minas de la montaña | Equipo | Progresión normal de herramientas/armas |
| Piedra muda | La torre | Ambientación | Material del ancla; sin eco al golpearla, absorbe magia |

### Kaelen y el portal
Al purificar el ancla se abre un portal y aparece **Kaelen**, anciano guardián atrapado entre mundos.
Guardián de un faro fronterizo; cerró el paso desde el otro lado y quedó atrapado. Cansado, no héroe
cliché. Habla una versión antigua del idioma invasor (sugiere que invasores y defensores fueron un
solo pueblo). **Enseña el idioma completo** → el jugador puede releer todos los textos del campamento.
Su petición no es "sálvanos" sino "ven a ver lo que pasa y decide tú". Fin de la Beta.

### Idioma y cuaderno (modo detective)
Se aprende de dos formas a la vez: pasiva (leer/escuchar) y activa (cuaderno). Leer/escuchar sube
la habilidad de **Lenguaje**.

**Tres estados por palabra:** Desconocida (símbolos) → Intuida (traducción dudosa, la propone el
juego o la escribes tú) → Confirmada (texto normal; por prueba clara o por Kaelen).

- **Pasivo:** cada palabra junto a una pista (dibujo, acción, repetición) suma evidencia. La voz es
  un idioma inventado sin doblaje; lo no entendido aparece como símbolos. Los sueños suman palabras.
- **Cuaderno:** se rellena solo con lo visto (y dónde). Puedes escribir tu traducción y comparar dos
  textos. Si aciertas, pasa a intuida y se confirma antes. Si fallas, el texto sale mal traducido
  (consecuencia natural, sin castigo). Recompensa: XP de Lenguaje y pistas que el pasivo no ve.
- **Reglas:** nunca obligatorio (todo se entiende por contexto visual); nunca dice "está mal"; no
  bloquea caminos, da ventajas. Vocabulario pequeño: ~100-150 palabras con reglas fijas.

**Documentos del enemigo:** los textos del campamento explican cómo defienden la torre y cómo
destruirla → descifrarlos abre caminos (4º modo de descubrir un camino).
| Camino | Qué dice | Qué abre |
|---|---|---|
| Magia | Notas de la veta y el catalizador | Dónde está y cómo canalizarlo |
| Minería | Plano/diario de excavación | Ruta exacta al Corazón de ceniza |
| Pirotecnia | Inventario del salitre | Dónde está y por qué es inestable |
| Sigilo | Turnos de guardia y contraseñas | Rutas de infiltración y frases |
| Frontal | Informes sobre el Guardián | Su punto débil |

- El **sigilo solo existe gracias al idioma** (solo lo abre quien lee).
- **Desbloqueo por partes:** cada texto se divide en fragmentos con palabras clave + un conocimiento
  ("el túnel empieza en la costa norte"). Desconocidas → símbolos; intuidas → conocimiento dudoso;
  confirmadas → firme. Un conocimiento dudoso puede ser falso (si intuiste "norte" por "sur",
  pierdes tiempo, no la partida). Los caminos se arman con piezas de varios documentos.
- **Reglas:** leer es atajo, no llave; el texto da conocimiento (dónde/cuándo/cómo), no objetos;
  fragmentos repartidos (rastreadores, campamento, Capitán); el cuaderno muestra huecos sin decir
  qué palabra buscar; los textos se pueden perder (si atacas antes de entenderlos, los queman).

### El naufragio
Tutorial de recursos + primer lore + primera pista de que el naufragio no fue casualidad.
| Elemento | Dónde | Función | Qué cuenta |
|---|---|---|---|
| Maderos/tablones | Playa | Primer material, cama | Algunos quemados por dentro |
| Cuerda | Rocas y restos | Herramientas, trampas, red | Alguna cortada con limpieza |
| Cajas | Flotando/encalladas | Primer botín: comida, cuchillo, tela, lámpara | Cada caja tiene dueño (rótulos, cartas) |
| El casco | Playa/arrecifes | Exploración de riesgo bajo | Grieta violácea en la quilla (energía de la torre) |
| Mapa dañado | Camarote/caja sellada | Pista de la torre | Símbolo que se reconoce en la piedra muda |
| Diario del capitán | Camarote | Lore | Últimos días del barco, en el idioma del jugador |

- **Reglas del botín:** lo imprescindible (madera, cuerda) está a la vista; lo curioso está escondido
  con pistas; el barco se deshace con las mareas (cada día algo nuevo/algo desaparece → premia volver).
- **Compañero ausente:** iba alguien más y no aparece. Huella de ausencia (litera con ropa, taza a
  medias, nota sin terminar), no cadáver. Gancho para el mundo grande.
- **Diario del capitán:** primera pieza de lore, sin idioma extraño. Mar raro, brújulas que giraban
  a un punto fijo, resplandor bajo el agua → desde el día 1 se sabe que la isla no es normal.

### Los sueños
Narrador silencioso: animaciones de ~10-15s al dormir, sin texto, como pesadillas suaves.
| Tipo | Qué muestra |
|---|---|
| De la torre | La roca late, la grieta se abre, algo mira; cambia según la fase |
| De podredumbre | El paisaje se marchita desde los bordes (lo que traerá la corrupción) |
| Del otro mundo | Guerra, un faro, una figura anciana cerrando una puerta (siembran a Kaelen) |
| De progreso | Reflejan lo descubierto (si investigó las raíces, sueña con ellas; si no, borroso) |

- **Conexiones:** cama con refugio → nítidos; intemperie → fragmentados. Pueden dar conocimiento
  dudoso y palabras del idioma. Quien evita dormir se pierde pistas, nada se bloquea.
- **Miedo sin castigo:** cortos, saltables en repetidas; miedo por lo que insinúan, no por sustos;
  no quitan vida/cansancio; más intensos según avanza la torre (día 4 el más claro e inquietante).
- **Técnica:** se hacen con cámara, luz y movimiento de los modelos de la isla, sin arte nuevo.

---

## Estructuras de datos previstas
| Sistema | Estructura |
|---|---|
| Caminos de la torre | Lista de marcas de estado ("investigó la veta", "siguió las raíces", "flora muerta") que cada camino lee para decidir cómo aparece |
| Idioma | Diccionario con estado de cada palabra (desconocida/intuida/confirmada) y su evidencia |
| Documentos | Fragmentos con palabras_clave y conocimiento; el cuaderno activa el conocimiento firme o dudoso |
| Naufragio | Objetos con posición, día de aparición y desaparición; cajas con contenido y texto |
| Sueños | Registros con condiciones (fase de torre, tipo de cama, descubrimientos), animación y palabras/conocimientos que suman; al dormir se elige el primero cuyas condiciones se cumplan |

## Decisiones abiertas
- [ ] ¿Pueden los enemigos romper las construcciones del jugador?
- [ ] Cuántos caminos se cierran por lore (propuesta: 1-2, empezando por naturaleza).
- [ ] Cantidad exacta de palabras del idioma (propuesta: 100-150).
- [ ] Nombres definitivos (todos los actuales son provisionales).
- [ ] Detalles del mundo grande: la guerra, el compañero del barco, el pasado compartido.
