// Echo con IA
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 tint : source_color = vec4(0.55, 0.62, 0.70, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.12;
uniform float drop_alpha : hint_range(0.0, 1.0) = 0.35;
uniform float drop_scale = 9.0;
uniform float slide_speed = 0.25;
uniform float bump_strength = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 static_drops(vec2 uv) {
	vec2 cell = floor(uv);
	vec2 f = fract(uv) - 0.5;
	float h = hash12(cell);
	vec2 c = vec2(hash12(cell + 7.1), hash12(cell + 3.7)) - 0.5;
	c *= 0.6;
	float r = mix(0.06, 0.2, h * h);
	vec2 d = f - c;
	float m = smoothstep(r, r * 0.6, length(d)) * step(0.35, h);
	return vec3(d * m / r, m);
}

vec3 sliding_drops(vec2 uv, float t) {
	vec2 grid = vec2(4.0, 1.0);
	vec2 p = uv * grid;
	float col = floor(p.x);
	float h = hash12(vec2(col, 13.0));
	p.y += t * (0.6 + h) + h * 10.0;
	vec2 cell = vec2(col, floor(p.y));
	vec2 f = fract(p) - 0.5;
	float hx = hash12(cell) - 0.5;
	f.x -= hx * 0.5 + sin(p.y * 6.0 + h * 20.0) * 0.05;
	vec2 d = f / vec2(1.0, 4.0);
	float m = smoothstep(0.07, 0.04, length(d)) * step(0.5, hash12(cell + 1.3));
	float trail = smoothstep(0.04, 0.0, abs(f.x)) * smoothstep(-0.5, 0.2, f.y) * step(0.5, hash12(cell + 1.3));
	trail *= 0.5;
	return vec3(vec2(f.x * 6.0, 0.0) * (m + trail), max(m, trail));
}

void fragment() {
	vec2 uv = vec2(world_pos.x + world_pos.z, world_pos.y) * drop_scale;
	vec3 a = static_drops(uv);
	vec3 b = static_drops(uv * 1.7 + 4.3);
	vec3 c = sliding_drops(uv * 0.35, TIME * slide_speed * 3.0);
	vec2 off = (a.xy + b.xy * 0.6 + c.xy) * bump_strength;
	float mask = clamp(a.z + b.z * 0.7 + c.z, 0.0, 1.0);

	ALBEDO = tint.rgb * (0.6 + 0.4 * mask);
	ALPHA = clamp(base_alpha + mask * drop_alpha, 0.0, 1.0);
	ROUGHNESS = mix(0.15, 0.02, mask);
	SPECULAR = 0.8;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(off.x, off.y, 0.0, 0.0)).xyz * 0.8);
}
