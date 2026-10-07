// Cielo del ciclo día/noche: degradado (los colores los fija DayNight según la hora), sol
// cuadrado con halo (luz 0), luna cuadrada con manchas (luz 1) y estrellas por la noche.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.22, 0.48, 0.88);
uniform vec3 horizon_color : source_color = vec3(0.68, 0.82, 0.95);
uniform vec3 ground_color : source_color = vec3(0.20, 0.35, 0.55);
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float sun_glow = 0.35;
uniform float stars = 0.0;  // 0 de día, 1 en plena noche

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Coordenadas de 'dir' en el plano del astro (ejes derecha y arriba de su dirección).
vec2 square_coords(vec3 dir, vec3 light) {
	vec3 right = normalize(cross(light, abs(light.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 up = cross(right, light);
	float d = max(dot(dir, light), 0.0001);
	return vec2(dot(dir, right), dot(dir, up)) / d;
}

void sky() {
	vec3 dir = EYEDIR;
	float up = dir.y;
	vec3 col;
	if (up >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(up, 0.0, 1.0), 0.55));
	} else {
		col = mix(horizon_color, ground_color, clamp(-up * 4.0, 0.0, 1.0));
	}

	// Sol y luna CUADRADOS (estilo de la guía visual): se mide la dirección en los ejes del astro
	// y es astro si cae dentro de un cuadrado. El sol lleva un halo cuadrado suave; la luna, manchas.
	if (LIGHT0_ENABLED) {
		float d = dot(dir, LIGHT0_DIRECTION);
		vec2 q = square_coords(dir, LIGHT0_DIRECTION);
		float edge = max(abs(q.x), abs(q.y));
		if (d > 0.0) {
			col += LIGHT0_COLOR * (1.0 - step(0.045, edge)) * 5.0;
			col += LIGHT0_COLOR * smoothstep(0.16, 0.045, edge) * 0.35;  // halo cuadrado
		}
		col += sun_glow_color * pow(max(d, 0.0), 10.0) * sun_glow;
	}
	if (LIGHT1_ENABLED) {
		float d = dot(dir, LIGHT1_DIRECTION);
		vec2 q = square_coords(dir, LIGHT1_DIRECTION);
		float edge = max(abs(q.x), abs(q.y));
		if (d > 0.0 && edge < 0.04) {
			// Manchas de la luna: una cuadrícula de 8x8 "píxeles" con algunos más oscuros.
			vec2 cell = floor((q + 0.04) / 0.08 * 8.0);
			float spot = step(0.7, hash(vec3(cell, 3.0)));
			col += vec3(0.88, 0.92, 1.0) * (1.6 - 0.5 * spot);
		}
		col += vec3(0.35, 0.40, 0.65) * pow(max(d, 0.0), 30.0) * 0.35;
	}
	// Estrellas: puntos en una cuadrícula de direcciones, solo por encima del horizonte.
	if (stars > 0.0 && up > 0.0) {
		vec3 p = dir * 220.0;
		vec3 cell = floor(p);
		float h = hash(cell);
		if (h > 0.9965) {
			float dist = length(fract(p) - 0.5);
			float twinkle = 0.7 + 0.3 * sin(TIME * (1.5 + h * 4.0) + h * 40.0);
			col += vec3(1.0, 0.97, 0.9) * smoothstep(0.35, 0.0, dist) * stars * twinkle
				* smoothstep(0.0, 0.25, up);
		}
	}
	COLOR = col;
}
