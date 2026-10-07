# Equipo: armaduras, accesorios y armas

> Decidido con Yago (2026-10-07). Código: `scripts/items/gear_db.gd` (catálogo),
> `scripts/ui/item_inspector.gd` (visor 3D). Valores provisionales.

## Idea

El juego final tendrá **cientos** de armaduras, armas y herramientas: fabricables, de facción, de
misión, de mazmorra y de enemigos. Por eso cada pieza es una **ficha** del catálogo; añadir una es
rellenar su ficha (y su arte), no programarla.

## Huecos

Ropa y mochila (ya existían) + escudo + **cabeza, torso, piernas, pies, manos, capa, anillo,
colgante y amuleto**.

## Ficha de cada pieza

| Dato | Qué es |
|---|---|
| Rareza | Común, buena, rara, épica, legendaria (color del nombre y valor en monedas) |
| Origen | Fabricable, de facción, de misión, de mazmorra, de enemigos, de los antiguos |
| Nivel | Guardado en cada pieza **pero aún sin uso**: para un posible sistema de niveles (Yago lo está pensando) |
| Protección | Resta daño: daño × 50 / (50 + protección). 51 de protección = la mitad de daño |
| Peso | Hasta 8 kg no se nota; más, **más lento** (hasta -25%) y **más cansado** (hasta +50% de esfuerzo, recupera menos) |
| Desgaste | Golpes que aguanta; rota, no protege (se repara en una fragua: pendiente). 0 = no se rompe |
| Conjunto | Varias piezas del mismo conjunto dan un extra |
| Efectos | Recuperar resistencia, daño cuerpo a cuerpo, menos visible agachado, resistencia a la corrupción |

Las **armas** también son fichas (daño, alcance, velocidad, esfuerzo, estilo, rareza, origen).

## Piezas de la Beta

- **Conjunto de piel** (fabricable con piel y cuerda): gorro, chaleco, perneras, botas, guantes.
  Con 3 piezas, +4 de protección.
- Accesorios: capa de vela (menos visible), colgante de hueso y amuleto de concha (aliento),
  anillo de colmillo (más daño).
- **Armadura de los antiguos** (legendaria, en el cofre de las ruinas): yelmo, coraza, grebas,
  botas y guanteletes. Mucha protección, poco peso, no se rompe nunca. Con 3 piezas, resistencia a
  la corrupción; con las 5, el doble y más aliento. La coraza tiene un hueco vacío del tamaño de una
  joya (pista para la historia, por decidir).

## Visor 3D (como en Skyrim)

En el inventario, a la derecha: el objeto bajo el ratón en 3D, girando solo; se arrastra para
girarlo y con la rueda se acerca. Debajo, nombre del color de su rareza y todos sus datos.
Con los modelos de Meshy se verá con todo su detalle; mientras, con su icono en relieve.

## Pendiente

- Modelos de Meshy de cada pieza (para verlas puestas en el personaje y en el visor).
- Reparar en la fragua. Sistema de niveles (si se decide). Más conjuntos y armas.
- Que la corrupción de la torre haga daño (para que su resistencia sirva).
