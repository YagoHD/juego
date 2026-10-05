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

## Consejos para Meshy

- Si sale el objeto con suelo o con una base que no tiene, vuelve a generar la imagen sin sombra.
- Las cosas muy finas (cuerdas sueltas, sedal) salen mal: mejor que estén enrolladas o pegadas.
- Para la antorcha y la hoguera, sin fuego: el fuego lo pone el juego (con luz y animación).
