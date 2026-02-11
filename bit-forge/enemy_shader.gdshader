shader_type spatial;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture;

uniform float outline_threshold_near = 0.015; // Outline threshold for near objects
uniform float outline_threshold_far = 0.102;  // Outline threshold for far objects
uniform float outline_thickness = 8.0; // Thicker outline
uniform vec3 outline_color = vec3(0.0, 0.0, 0.0); // Black outline

uniform float pixelation_amount = 400.0; // Higher for smoother image, less pixelated

uniform vec3 camera_position; // Camera position (in world space)

void fragment() {
    vec2 uv = FRAGCOORD.xy / VIEWPORT_SIZE;

    // --- Reduced Pixelation Step --- (higher pixelation amount)
    vec2 pixelated_uv = floor(uv * pixelation_amount) / pixelation_amount;

    // --- Base Color --- (apply pixelation to base color)
    vec3 color = texture(SCREEN_TEXTURE, pixelated_uv).rgb;

    // --- Depth-based Outline --- (adjust outline detection)
    vec2 texel = (1.0 / VIEWPORT_SIZE) * outline_thickness;
    float center = texture(DEPTH_TEXTURE, uv).r;
    float up     = texture(DEPTH_TEXTURE, uv + vec2(0.0, texel.y)).r;
    float down   = texture(DEPTH_TEXTURE, uv - vec2(0.0, texel.y)).r;
    float left   = texture(DEPTH_TEXTURE, uv - vec2(texel.x, 0.0)).r;
    float right  = texture(DEPTH_TEXTURE, uv + vec2(texel.x, 0.0)).r;

    float depth_diff = max(
        max(abs(center - up), abs(center - down)),
        max(abs(center - left), abs(center - right))
    );

    // --- Dynamic Outline Threshold Based on Distance ---
    float depth_in_world = texture(DEPTH_TEXTURE, uv).r; // Get depth in world space (assumed linear depth)
    float distance = length(camera_position - vec3(uv * VIEWPORT_SIZE, depth_in_world)); // Calculate the distance to the camera

    // Smoothly interpolate between near and far outline threshold based on distance
    float outline_threshold = mix(outline_threshold_near, outline_threshold_far, distance / 100.0); // 100.0 is an arbitrary scaling factor, adjust as needed

    // Outline detection based on depth difference
    float outline = step(outline_threshold, depth_diff);

    // --- Combine Outline with Pixelated Base --- (apply thicker outline)
    ALBEDO = mix(color, outline_color, outline);
}
