shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D palette : filter_nearest;
uniform int palette_size = 16;                          // nº de colores de tu paleta
uniform float dither_strength : hint_range(0.0, 0.5) = 0.15;
uniform float vignette : hint_range(0.0, 1.5) = 0.6;

const float bayer[16] = float[16](
    0.0, 8.0, 2.0, 10.0,
    12.0, 4.0, 14.0, 6.0,
    3.0, 11.0, 1.0, 9.0,
    15.0, 7.0, 13.0, 5.0
);

void fragment() {
    vec3 col = texture(screen_texture, SCREEN_UV).rgb;

    // Viñeta suave
    float d = distance(SCREEN_UV, vec2(0.5));
    col *= 1.0 - smoothstep(0.3, 0.9, d) * vignette;

    // Dithering ordenado (a nivel del píxel de baja resolución)
    ivec2 p = ivec2(FRAGCOORD.xy);
    float t = bayer[(p.x % 4) + (p.y % 4) * 4] / 16.0 - 0.5;
    col += t * dither_strength;

    // Buscar el color de la paleta más cercano
    vec3 best = texelFetch(palette, ivec2(0, 0), 0).rgb;
    float best_dist = 1e9;
    for (int i = 0; i < palette_size; i++) {
        vec3 c = texelFetch(palette, ivec2(i, 0), 0).rgb;
        vec3 diff = col - c;
        float dd = dot(diff, diff);
        if (dd < best_dist) {
            best_dist = dd;
            best = c;
        }
    }
    COLOR = vec4(best, 1.0);
}