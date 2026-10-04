class_name Relief
## Relieve de las texturas de los bloques (como en el arte conceptual): cada píxel tiene una
## altura, guardada en el canal alfa del atlas, y el material de los bloques (blocks.gdshader) la
## usa para hundir lo oscuro (juntas de tablones, grietas, vetas de la corteza, el cemento entre
## piedras) y levantar lo que sobresale (la hierba sobre la tierra, la nieve, el musgo, los
## cristales del mineral). Los bordes de cada cara se bajan un poco: bloques biselados.

## Lo que sobresale en cada textura: [condición de color, cuánto sube].
const RAISE := {
	"grass_side": "green", "grass_top": "none", "snow_side": "white", "mossy_stone": "green",
	"mossy_side": "green", "ore": "glow", "ore_side": "glow", "corrupt_top": "purple",
	"corrupt_side": "purple", "chest_top": "metal", "chest_side": "metal", "chest_back": "metal",
}


static func bake_height(img: Image, name: String) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var lum := PackedFloat32Array()
	lum.resize(w * h)
	var mean := 0.0
	for y in h:
		for x in w:
			var l := img.get_pixel(x, y).get_luminance()
			lum[y * w + x] = l
			mean += l
	mean /= w * h
	# Media local (5x5): lo más oscuro que su alrededor es una hendidura.
	var blur := PackedFloat32Array()
	blur.resize(w * h)
	for y in h:
		for x in w:
			var s := 0.0
			var n := 0
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var xx := clampi(x + dx, 0, w - 1)
					var yy := clampi(y + dy, 0, h - 1)
					s += lum[yy * w + xx]
					n += 1
			blur[y * w + x] = s / n
	var rule: String = RAISE.get(name, "")
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var l := lum[y * w + x]
			var height := 0.62 + (l - blur[y * w + x]) * 2.6 + (l - mean) * 0.5
			match rule:
				"green":
					if c.g > c.r * 1.15 and c.g > c.b * 1.1:
						height += 0.3
					else:
						height -= 0.1
				"white":
					if c.b > 0.6 and c.r > 0.55:
						height += 0.3
					else:
						height -= 0.1
				"glow":
					if c.g > 0.5 and c.g > c.r * 1.6:
						height += 0.25
				"purple":
					if c.b > c.g * 1.3 and c.r > c.g * 1.2:
						height += 0.2
				"metal":
					var grey := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) < 0.08
					if grey:
						height += 0.25
			# Bisel: el borde de la cara baja.
			var edge := mini(mini(x, w - 1 - x), mini(y, h - 1 - y))
			if edge < 1:
				height -= 0.1
			c.a = clampf(height, 0.0, 1.0)
			img.set_pixel(x, y, c)
