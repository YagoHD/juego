// Material de los bloques del mundo con relieve (como en el arte conceptual): el atlas lleva en
// el alfa la altura de cada píxel (Relief.bake_height). De cerca, cada píxel se hunde o se
// levanta según el ángulo de la cámara (parallax) y se ilumina según su inclinación: las juntas de
// los tablones y las grietas se ven hacia dentro, la hierba sobresale de la tierra, los bordes
// de los bloques están biselados. De lejos se ve plano (más barato). El mineral y la tierra
// corrupta brillan.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D atlas : source_color, filter_nearest_mipmap;
uniform vec2 grid = vec2(8.0, 4.0);          // tiles del atlas (columnas, filas)
uniform float tile_px = 32.0;                // píxeles por tile
uniform float depth = 0.1;                   // profundidad del relieve (en lados de bloque)
uniform float bump = 3.0;                    // fuerza de la luz del relieve
uniform float relief_distance = 14.0;        // metros: más lejos, plano
uniform vec2 glow_tiles[6];                  // tiles que brillan (mineral, tierra corrupta)
uniform int glow_count = 0;

uniform float block_size = 0.5;                // metros por bloque
uniform vec2 rotate_tiles[8];                // tiles que se giran al azar en la cara de arriba
uniform int rotate_count = 0;
uniform int tint_count = 0;                  // los primeros tint_count de esos, además, cambian de tono

float cell_hash(vec2 c) {
	return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
}

float height_at(vec2 uv, vec2 dx, vec2 dy) {
	return textureGrad(atlas, uv, dx, dy).a;
}

void fragment() {
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	vec2 tile_size = 1.0 / grid;
	vec2 tile_origin = floor(UV * grid) / grid;
	vec2 tile_id = floor(UV * grid);
	// Variedad: en la cara de arriba de la hierba, la tierra, la arena... la textura se gira al azar
	// en cada bloque (0, 90, 180 o 270 grados) y la hierba cambia un pelín de tono. Así un prado de
	// cientos de bloques no se ve como un patrón repetido.
	vec2 base_uv = UV;
	float tint = 1.0;
	vec3 world_n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	if (world_n.y > 0.5) {
		vec3 world_p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec2 cell = floor(world_p.xz / block_size + 0.0001);
		for (int i = 0; i < 8; i++) {
			if (i >= rotate_count) break;
			if (all(equal(tile_id, rotate_tiles[i]))) {
				int k = int(cell_hash(cell) * 4.0) % 4;
				vec2 local = (UV - tile_origin) * grid;
				mat2 r = k == 1 ? mat2(vec2(0.0, 1.0), vec2(-1.0, 0.0)) : (k == 2 ? mat2(vec2(-1.0, 0.0), vec2(0.0, -1.0)) : (k == 3 ? mat2(vec2(0.0, -1.0), vec2(1.0, 0.0)) : mat2(1.0)));
				local = r * (local - 0.5) + 0.5;
				base_uv = tile_origin + clamp(local, 0.001, 0.999) / grid;
				dx = r * dx;
				dy = r * dy;
				if (i < tint_count) {
					tint = 1.0 + (cell_hash(cell + vec2(17.0, 31.0)) - 0.5) * 0.1;
				}
			}
		}
	}
	vec2 uv = base_uv;
	float dist = length(VERTEX);
	float near = 1.0 - smoothstep(relief_distance * 0.6, relief_distance, dist);

	// Marco de la cara (tangente, bitangente) a partir de las derivadas: la malla no trae tangentes.
	vec3 p_dx = dFdx(VERTEX);
	vec3 p_dy = dFdy(VERTEX);
	vec3 n = normalize(NORMAL);
	vec3 dp2perp = cross(p_dy, n);
	vec3 dp1perp = cross(n, p_dx);
	vec3 t = dp2perp * dx.x + dp1perp * dy.x;
	vec3 b = dp2perp * dx.y + dp1perp * dy.y;
	float invmax = inversesqrt(max(dot(t, t), dot(b, b)));
	mat3 tbn = mat3(t * invmax, b * invmax, n);

	if (near > 0.0) {
		// Parallax con pasos: se avanza por el rayo de la vista hasta chocar con el relieve.
		vec3 view_ts = normalize(transpose(tbn) * normalize(-VERTEX));
		float steps = mix(6.0, 18.0, abs(view_ts.z) < 0.5 ? 1.0 : 0.5);
		float layer = 1.0 / steps;
		vec2 shift = view_ts.xy / max(view_ts.z, 0.25) * depth * tile_size * near;
		vec2 delta = shift * layer;
		float cur_depth = 0.0;
		vec2 cur_uv = base_uv;
		float h = 1.0 - height_at(cur_uv, dx, dy);
		for (int i = 0; i < 18; i++) {
			if (cur_depth >= h) break;
			cur_uv -= delta;
			cur_uv = clamp(cur_uv, tile_origin + 0.5 / (grid * tile_px), tile_origin + tile_size - 0.5 / (grid * tile_px));
			h = 1.0 - height_at(cur_uv, dx, dy);
			cur_depth += layer;
		}
		uv = cur_uv;
	}

	// Medio píxel dentro de su textura: el filtrado no debe leer la vecina del atlas (rayas en el suelo).
	vec2 half_texel = 0.5 / (grid * tile_px);
	uv = clamp(uv, tile_origin + half_texel, tile_origin + tile_size - half_texel);
	vec4 tex = textureGrad(atlas, uv, dx, dy);
	ALBEDO = tex.rgb * tint;

	// Luz del relieve: la inclinación sale de la diferencia de altura con los píxeles vecinos.
	vec2 texel = 1.0 / (grid * tile_px);
	float hl = height_at(clamp(uv - vec2(texel.x, 0.0), tile_origin, tile_origin + tile_size - texel), dx, dy);
	float hr = height_at(clamp(uv + vec2(texel.x, 0.0), tile_origin, tile_origin + tile_size - texel), dx, dy);
	float hd = height_at(clamp(uv - vec2(0.0, texel.y), tile_origin, tile_origin + tile_size - texel), dx, dy);
	float hu = height_at(clamp(uv + vec2(0.0, texel.y), tile_origin, tile_origin + tile_size - texel), dx, dy);
	vec3 n_ts = normalize(vec3((hl - hr) * bump * near, (hd - hu) * bump * near, 1.0));
	NORMAL = normalize(tbn * n_ts);
	// Las hendiduras, algo más oscuras (oclusión).
	AO = mix(1.0, clamp(0.45 + tex.a * 0.8, 0.0, 1.0), near);
	AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;

	// Brillo del mineral y de la tierra corrupta (solo sus píxeles vivos, latiendo despacio).
	for (int i = 0; i < 6; i++) {
		if (i >= glow_count) break;
		if (all(equal(tile_id, glow_tiles[i]))) {
			float vivid = max(tex.g - max(tex.r, tex.b) * 1.3, tex.r * tex.b * 2.0 - tex.g * 1.5);
			float pulse = 0.75 + 0.25 * sin(TIME * 2.0 + UV.x * 40.0);
			EMISSION = tex.rgb * smoothstep(0.05, 0.25, vivid) * 2.5 * pulse;
		}
	}
}
