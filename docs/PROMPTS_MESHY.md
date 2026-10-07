> **EN PAUSA (2026-10-07):** con el estilo elegido (Minecraft Dungeons en primera/tercera
> persona, ver `docs/ESTILO_GRAFICO.md`) casi todo se hace con imágenes de ChatGPT
> (`docs/TEXTURAS.md`). Esta lista queda para alguna pieza especial, y habría que pedirla en el
> estilo nuevo.

# Prompts: objetos para ChatGPT → Meshy

Cómo se hace cada objeto:
1. En ChatGPT, pega primero el **prompt de estilo** (una vez por conversación) y luego el del objeto.
2. Revisa la imagen: un solo objeto, entero, sin cortar, fondo liso. Si no: "Redo it: only ONE
   object, fully visible, centered, plain light grey background, no shadow, no text."
3. Pasa la imagen a Meshy (Image to 3D), con textura. Descarga **GLB para videojuegos**.
4. Guárdalo en `assets/models/items/` con el nombre de la tabla (p. ej. `stone_knife.glb`).

Yo lo paso a cubitos con sus colores (como el barco y los restos), le pongo el punto por donde
se agarra y lo uso en la mano, en el suelo y al fabricar.

---

## Prompt de estilo (pegar primero)

```
I am making 3D models for my voxel survival game with an image-to-3D tool, so every image must
be easy to convert into a 3D model. Rules for every object I ask:
- ONE single object, alone, fully visible and centered, filling about 70% of the image.
- Three-quarter view from slightly above (like a product shot), so its front, side and top
  are visible.
- Plain light grey background, NO shadow on the ground, no text, no hands, no other objects.
- Style: chunky voxel art made of small cubes, hand-painted, warm natural colors, soft even
  light, matte (no shiny reflections). Handmade by a castaway from what he found on a
  tropical island: wood, stone, fiber rope, sail cloth.
- Realistic proportions (a knife is small, an axe handle is long).
Reply "OK" and wait.
```

---

## Herramientas y armas (lo primero: van en la mano)

| Archivo | Prompt para ChatGPT |
|---|---|
| `stone_knife.glb` | A stone knife: a sharp flaked flint blade tied with fiber rope to a short wooden handle. |
| `stone_axe.glb` | A stone axe: a long wooden handle with a chipped grey stone head lashed on top with fiber rope. |
| `stone_pick.glb` | A stone pickaxe: a long wooden handle with a pointed stone head on one side and a smaller point on the other, tied with rope. |
| `spear.glb` | A spear: a long straight wooden pole with a sharp flint point tied at the tip with fiber rope. |
| `torch.glb` | A torch: a wooden stick with a bundle of cloth soaked in resin tied at the top (unlit). |
| `sharp_rock.glb` | A sharp rock: a fist-sized grey stone with one chipped sharp edge. |
| `fishing_rod.glb` | A simple fishing rod: a thin bent wooden branch with a fiber line and a bone hook. |
| `hammer.glb` | A stone hammer: a short wooden handle with a round stone head tied with rope. |

## Materiales (en la mano y en el suelo)

| Archivo | Prompt para ChatGPT |
|---|---|
| `rope.glb` | A coil of thick fiber rope, loosely wound. |
| `sticks.glb` | A small bundle of three dry wooden sticks tied in the middle. |
| `board.glb` | A single rough wooden plank, slightly worn, with a broken end. |
| `planks.glb` | A short stack of three rough wooden planks. |
| `rock.glb` | A fist-sized rounded grey stone. |
| `flint.glb` | A dark grey flint stone with glassy chipped faces. |
| `cloth.glb` | A folded piece of old torn sail cloth, cream colored with stains. |
| `fiber.glb` | A bundle of dry plant fibers tied with a knot. |
| `log.glb` | A short log of wood with bark and visible rings on the ends. |
| `resin.glb` | A small lump of sticky amber tree resin. |

## Comida

| Archivo | Prompt para ChatGPT |
|---|---|
| `raw_fish.glb` | A raw tropical fish, blue and silver. |
| `cooked_fish.glb` | A grilled fish with dark grill marks, golden brown. |
| `raw_crab.glb` | A raw red crab. |
| `cooked_crab.glb` | A cooked bright orange crab. |
| `coconut.glb` | A coconut with brown husk, one half cracked open showing the white inside. |
| `berries.glb` | A small cluster of red wild berries with two green leaves. |
| `mushroom.glb` | A brown wild mushroom with a thick stem. |
| `flatbread.glb` | A round rustic flatbread with toasted spots. |

## Equipo y objetos que se colocan

| Archivo | Prompt para ChatGPT |
|---|---|
| `rough_backpack.glb` | A makeshift backpack made of sail cloth tied with fiber rope, with two rope straps. |
| `backpack.glb` | A canvas sailor backpack with leather straps and a buckle. |
| `captain_journal.glb` | An old closed leather journal, water-stained, tied with a leather strap. |
| `chest.glb` | A small wooden chest made of planks with iron corners and a simple latch, closed. |
| `workbench.glb` | A rough wooden workbench: thick plank top on four log legs, a few tools marks on top. |
| `campfire.glb` | A campfire: a ring of stones with crossed logs in the middle (unlit, no fire). |
| `bedroll.glb` | A sleeping bag made of sail cloth, rolled and tied with rope. |
| `raft.glb` | A small raft made of logs tied together with rope, seen from above at an angle. |
| `barrel.glb` | An old wooden barrel with iron hoops. |
| `crate.glb` | A wooden cargo crate made of planks with darker corner boards. |
| `lantern.glb` | An old ship lantern made of iron and glass (unlit). |

## Combate, caza y sueño (añadidos con el combate)

| Archivo | Prompt para ChatGPT |
|---|---|
| `wooden_shield.glb` | A round wooden shield made of rough planks, a rope-wrapped rim and a leather strap on the back. |
| `raw_meat.glb` | A raw red piece of meat with a bit of white fat. |
| `cooked_meat.glb` | A roasted piece of meat, golden brown with dark grill marks. |
| `raw_poultry.glb` | A raw bird leg, pale pink. |
| `cooked_poultry.glb` | A roasted bird leg, golden brown. |
| `hide.glb` | A folded brown animal hide with fur on one side. |
| `bone.glb` | A white animal bone. |
| `tusk.glb` | A curved ivory boar tusk. |
| `feather.glb` | A single grey-white bird feather. |
| `iron_scrap.glb` | A handful of rusty iron scraps and bent nails. |
| `anchor_shard.glb` | A jagged shard of dark stone with glowing violet veins. |
| `dawn_bean_plant.glb` | A small wild plant: a thin green stem with narrow leaves and a cluster of amber glowing beans at the top. |
| `furnace.glb` | A small stone furnace made of stacked grey rocks and clay, with a dark arched mouth in front and a short chimney (unlit, no fire). |
| `gold_coin.glb` | A single medieval gold coin with a simple stamped cross, seen at an angle. |
| `death_backpack.glb` | A dropped makeshift backpack made of sail cloth and rope, lying on the ground, slightly open. |

## Armaduras y accesorios (para verlas puestas y en el visor 3D)

Pedir cada pieza **sola, sin cuerpo dentro**, de frente y ligeramente desde arriba. Luego habrá
que ajustarla al cuerpo del personaje (avisaré antes de tocar nada del modelo).

| Archivo | Prompt para ChatGPT |
|---|---|
| `hide_cap.glb` | A rough leather cap sewn with fiber rope. |
| `hide_vest.glb` | A thick sleeveless leather vest made of two layers of hide, laced with rope. |
| `hide_trousers.glb` | A pair of leather leg guards tied with straps. |
| `hide_boots.glb` | A pair of soft leather boots with a double sole. |
| `hide_gloves.glb` | A pair of leather gloves. |
| `sail_cloak.glb` | A hooded cloak made of old cream sail cloth, slightly torn at the bottom. |
| `bone_necklace.glb` | A carved bone pendant on a simple cord. |
| `tusk_ring.glb` | A ring carved from a boar tusk. |
| `shell_amulet.glb` | A seashell amulet on a cord. |
| `ancient_helm.glb` | An ancient helm of pale silvery metal that never rusts, engraved with strange runes. |
| `ancient_cuirass.glb` | An ancient cuirass of pale silvery metal with strange runes and an empty jewel socket in the chest. |
| `ancient_greaves.glb` | Ancient greaves of pale silvery metal with strange runes. |
| `ancient_boots.glb` | Ancient armored boots of pale silvery metal with strange runes. |
| `ancient_gauntlets.glb` | Ancient gauntlets of pale silvery metal with strange runes. |

## Animales (modelos con huesos para animarlos)

En Meshy, después del modelo, usar **Rigging/animación** si lo ofrece para cuadrúpedos. Mismo
prompt de estilo; pedir el animal **de perfil, de pie, con las patas separadas**.

| Archivo | Prompt para ChatGPT |
|---|---|
| `pig.glb` | A pink farm pig standing, side view. |
| `cow.glb` | A cream and brown cow standing, side view. |
| `boar.glb` | A dark brown wild boar with small tusks, standing, side view. |
| `snake.glb` | A green snake lying in a loose S shape, seen from slightly above. |
| `wolf.glb` | A grey wolf standing, side view. |
| `cat.glb` | An orange cat standing, side view. |
| `deer.glb` | A brown deer with small antlers, standing, side view. |
| `rabbit.glb` | A grey-brown rabbit sitting, side view. |
| `hen.glb` | A light brown hen standing, side view. |
| `gull.glb` | A white seagull with open wings, as if flying. |
| `crow.glb` | A black crow with open wings, as if flying. |
| `eagle.glb` | A brown eagle with open wings, as if flying. |

## Enemigos (personas con huesos, en pose de T)

Pedir el personaje **entero, de frente, en pose de T (brazos en cruz)**, para que Meshy le ponga
huesos. Los enmascarados sirven al ancla; los de cara descubierta son soldados corrientes.

| Archivo | Prompt para ChatGPT |
|---|---|
| `tracker.glb` | A light scout in worn leather and a hood, face uncovered, T-pose, full body, front view. |
| `archer.glb` | An archer in a green padded tunic with a quiver on the back, face uncovered, T-pose, full body, front view. |
| `soldier.glb` | A soldier in dented iron armor with a simple helmet, face uncovered, T-pose, full body, front view. |
| `captain.glb` | A captain in red and dark iron armor with a short cape, T-pose, full body, front view. |
| `mage.glb` | A masked mage in a violet robe with glowing violet runes, face hidden by a smooth mask, T-pose, full body, front view. |
| `tower_guardian.glb` | A huge mute stone golem with a glowing violet crystal core in the chest, T-pose, full body, front view. |

## Gente del pueblo (personas con huesos, en pose de T)

Mismo método que los enemigos: **entero, de frente, en pose de T**. Ropa medieval sencilla de
pueblo pesquero y agrícola; caras descubiertas y amables.

| Archivo | Prompt para ChatGPT |
|---|---|
| `villager_farmer.glb` | A medieval peasant farmer in a brown linen tunic, straw hat and leather boots, T-pose, full body, front view. |
| `villager_fisher.glb` | A medieval fisherman in a patched blue tunic, rolled-up trousers and a knitted cap, T-pose, full body, front view. |
| `villager_merchant.glb` | A medieval merchant in a green wool coat with a leather belt pouch, T-pose, full body, front view. |
| `villager_woman.glb` | A medieval village woman in a simple dress with an apron and a head scarf, T-pose, full body, front view. |
| `guard.glb` | A village guard in a padded gambeson, a simple iron kettle helmet and a spear, face uncovered, T-pose, full body, front view. |

## Consejos para Meshy

- Si sale el objeto con suelo o con una base que no tiene, vuelve a generar la imagen sin sombra.
- Las cosas muy finas (cuerdas sueltas, sedal) salen mal: mejor que estén enrolladas o pegadas.
- Para la antorcha y la hoguera, sin fuego: el fuego lo pone el juego (con luz y animación).
