// Mar: se ve el fondo a través del agua (deformado por las olas), turquesa en la orilla y azul
// profundo mar adentro, con espuma donde rompe el agua contra la arena y destellos del sol.
// La profundidad se calcula comparando la superficie con el fondo (buffer de profundidad) y el
// fondo se toma de la imagen ya dibujada (screen texture).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec3 shallow_color : source_color = vec3(0.20, 0.82, 0.80);
uniform vec3 deep_color : source_color = vec3(0.02, 0.22, 0.45);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 0.97);
uniform float depth_to_deep = 9.0;    // metros hasta el color profundo
uniform float clear_depth = 1.4;      // metros en los que aún se ve bien el fondo
uniform float foam_width = 0.8;       // metros de espuma junto a la orilla
uniform float refraction = 0.025;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);  // suave: sin facetas en las ondas
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Altura de las olas pequeñas: dos capas que se cruzan.
float waves(vec2 p) {
	return noise(p * 0.9 + vec2(TIME * 0.35, TIME * 0.12)) * 0.6
		+ noise(p * 2.1 - vec2(TIME * 0.18, -TIME * 0.4)) * 0.4;
}

void fragment() {
	vec2 p = world_pos.xz;
	// Normal de las olas a partir de la pendiente de la altura.
	float e = 0.08;
	float h = waves(p);
	vec2 slope = vec2(waves(p + vec2(e, 0.0)) - h, waves(p + vec2(0.0, e)) - h) / e;
	// A lo lejos las olas se suavizan (si no, se ven como ruido de televisión).
	float calm = clamp(1.0 - length(VERTEX) / 70.0, 0.08, 1.0);
	slope *= calm;
	vec3 n = normalize(vec3(-slope.x * 0.1, 1.0, -slope.y * 0.1));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// Profundidad del agua en este punto (distancia de la superficie al fondo, en la vista).
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	behind.xyz /= behind.w;
	float depth = max(VERTEX.z - behind.z, 0.0);

	// Fondo deformado por las olas (menos en la orilla, donde casi no hay agua).
	vec2 offset = slope * refraction * clamp(depth, 0.0, 1.0);
	vec2 uv = SCREEN_UV + offset;
	float raw2 = texture(depth_texture, uv).r;
	vec4 behind2 = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, raw2, 1.0);
	behind2.xyz /= behind2.w;
	if (behind2.z > VERTEX.z) {
		uv = SCREEN_UV;  // lo que hay delante del agua no se mete dentro
	}
	vec3 bottom = textureLod(screen_texture, uv, 0.0).rgb;

	// El agua tiñe el fondo: turquesa claro en lo poco profundo, azul y opaco en lo profundo.
	float deep = clamp(depth / depth_to_deep, 0.0, 1.0);
	vec3 water = mix(shallow_color, deep_color, deep);
	float murk = clamp(depth / clear_depth, 0.0, 1.0);
	// El fondo ya viene iluminado: va como emisión; el color del agua sí recibe la luz del sol.
	// Mirando de lado el agua refleja el cielo (Fresnel): de lejos casi no se ve el fondo.
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float m = clamp(murk * 0.85 + deep * 0.15 + fresnel * 0.75, 0.0, 1.0);
	vec3 seen_bottom = bottom * mix(vec3(1.0), shallow_color, 0.65) * (1.0 - m);

	// Espuma: una franja junto a la arena que va y viene, rota por el ruido, en escalones.
	float shore = 1.0 - clamp(depth / foam_width, 0.0, 1.0);
	float surge = 0.5 + 0.5 * sin(TIME * 1.3 - depth * 7.0);
	float broken = noise(p * 3.0 + vec2(TIME * 0.2, 0.0));
	float foam = step(0.55, shore * (0.65 + 0.5 * surge) + broken * 0.35);
	foam = max(foam, step(0.93, shore));
	float f = foam * 0.85;
	vec3 sky_tint = mix(water, vec3(0.62, 0.78, 0.9), fresnel * 0.6);
	ALBEDO = mix(sky_tint * m, foam_color, f);
	EMISSION = seen_bottom * (1.0 - f);
	ALPHA = 1.0;
	ROUGHNESS = mix(0.2, 0.6, foam);  // algo rugosa: el reflejo de las nubes de bloques se difumina
	SPECULAR = 0.55;
}
