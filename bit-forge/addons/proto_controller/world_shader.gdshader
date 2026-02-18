shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform int pixel_size = 4;
uniform float edge_darkness = 0.5;
uniform float edge_threshold = 0.05;

void fragment() {

    // --- Pixelation ---
    vec2 pixelated_uv = floor(FRAGCOORD.xy / float(pixel_size))
                        * float(pixel_size)
                        / VIEWPORT_SIZE;

    vec4 center_sample = texture(SCREEN_TEXTURE, pixelated_uv);
    vec3 color = center_sample.rgb;
    float alpha = center_sample.a;

    // --- Edge detection ---
    vec2 texel = 1.0 / VIEWPORT_SIZE;
    float step_size = float(pixel_size);

    vec3 up = texture(SCREEN_TEXTURE, pixelated_uv + vec2(0.0, texel.y * step_size)).rgb;
    vec3 down = texture(SCREEN_TEXTURE, pixelated_uv - vec2(0.0, texel.y * step_size)).rgb;
    vec3 right = texture(SCREEN_TEXTURE, pixelated_uv + vec2(texel.x * step_size, 0.0)).rgb;
    vec3 left = texture(SCREEN_TEXTURE, pixelated_uv - vec2(texel.x * step_size, 0.0)).rgb;

    float max_diff = max(
        max(length(color - up), length(color - down)),
        max(length(color - left), length(color - right))
    );

    float edge = step(edge_threshold, max_diff);

    // --- Darken edges ---
    color *= mix(1.0, 1.0 - edge_darkness, edge);

    // --- Preserve fire / glow ---
    ALBEDO = color;
    EMISSION = color;     // preserves glow-based fire
    ALPHA = alpha;        // preserves transparency
}
