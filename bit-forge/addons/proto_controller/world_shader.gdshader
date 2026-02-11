shader_type spatial;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform int pixel_size = 4;           // Size of the pixelation blocks
uniform float edge_darkness = 0.5;    // How dark the outlines are

void fragment() {
    // --- Pixelation ---
    float px = float(int(FRAGCOORD.x) % pixel_size);
    float py = float(int(FRAGCOORD.y) % pixel_size);
    float x = FRAGCOORD.x + floor(float(pixel_size) / 2.0) - px;
    float y = FRAGCOORD.y + floor(float(pixel_size) / 2.0) - py;
    vec2 uv = vec2(x, y) / VIEWPORT_SIZE;
    
    // --- Sample center color ---
    vec3 color = texture(SCREEN_TEXTURE, uv).rgb;
    
    // --- Simple edge detection ---
    vec2 texel = 1.0 / VIEWPORT_SIZE;
    float edge = 0.0;
    
    // Sample 4 neighbors
    vec3 up = texture(SCREEN_TEXTURE, uv + vec2(0.0, texel.y * float(pixel_size))).rgb;
    vec3 down = texture(SCREEN_TEXTURE, uv - vec2(0.0, texel.y * float(pixel_size))).rgb;
    vec3 right = texture(SCREEN_TEXTURE, uv + vec2(texel.x * float(pixel_size), 0.0)).rgb;
    vec3 left = texture(SCREEN_TEXTURE, uv - vec2(texel.x * float(pixel_size), 0.0)).rgb;
    
    // If neighbor differs from center, mark as edge
    float diff_up = length(color - up);
    float diff_down = length(color - down);
    float diff_left = length(color - left);
    float diff_right = length(color - right);
    
    float max_diff = max(max(diff_up, diff_down), max(diff_left, diff_right));
    
    if (max_diff > 0.05) {  // Threshold for edge detection
        edge = 1.0;
    }
    
    // --- Darken edges ---
    color *= mix(1.0, 1.0 - edge_darkness, edge);
    
    ALBEDO = color;
}
