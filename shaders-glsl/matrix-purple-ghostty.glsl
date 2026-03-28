// MATRIX SHADER - Purple (Ghostty / Shadertoy API)
// Ported from HLSL Windows Terminal version

#define RAIN_R         0.7
#define RAIN_G         0.0
#define RAIN_B         1.0
#define RAIN_SPEED     0.8
#define GLOW_STRENGTH  0.8
#define FONT_SCALE     1.0
#define CHAR_WIDTH     10.0
#define TRAIL_POWER    8.0
#define RAIN_DENSITY     0.2
#define SHOW_L1        1.0
#define SHOW_L2        1.0
#define SHOW_L3        1.0
// Per-pixel transparency: background-opacity=0 + alpha from content

// Ghostty provides Shadertoy-compatible uniforms:
// iTime, iResolution, iChannel0 (terminal texture)

// Bit-packed 5x7 Katakana glyphs
const uint GLYPHS[16] = uint[16](
    ((10u<<30)|(4u<<25)|(4u<<20)|(10u<<15)|(17u<<10)|(17u<<5)|14u),
    ((16u<<30)|(8u<<25)|(4u<<20)|(2u<<15)|(1u<<10)|(4u<<5)|4u),
    ((14u<<30)|(17u<<25)|(17u<<20)|(16u<<15)|(16u<<10)|(16u<<5)|31u),
    ((31u<<30)|(4u<<25)|(4u<<20)|(4u<<15)|(4u<<10)|(4u<<5)|31u),
    ((4u<<30)|(31u<<25)|(4u<<20)|(5u<<15)|(5u<<10)|(9u<<5)|17u),
    ((12u<<30)|(18u<<25)|(2u<<20)|(4u<<15)|(8u<<10)|(16u<<5)|31u),
    ((4u<<30)|(31u<<25)|(4u<<20)|(31u<<15)|(4u<<10)|(4u<<5)|4u),
    ((14u<<30)|(17u<<25)|(1u<<20)|(2u<<15)|(4u<<10)|(8u<<5)|16u),
    ((1u<<30)|(2u<<25)|(31u<<20)|(4u<<15)|(8u<<10)|(16u<<5)|16u),
    ((31u<<30)|(1u<<25)|(1u<<20)|(1u<<15)|(1u<<10)|(1u<<5)|31u),
    ((10u<<30)|(10u<<25)|(31u<<20)|(10u<<15)|(2u<<10)|(4u<<5)|8u),
    ((16u<<30)|(4u<<25)|(1u<<20)|(0u<<15)|(17u<<10)|(10u<<5)|4u),
    ((31u<<30)|(1u<<25)|(2u<<20)|(4u<<15)|(8u<<10)|(8u<<5)|8u),
    ((4u<<30)|(4u<<25)|(31u<<20)|(4u<<15)|(31u<<10)|(4u<<5)|4u),
    ((4u<<30)|(4u<<25)|(10u<<20)|(10u<<15)|(17u<<10)|(17u<<5)|17u),
    ((31u<<30)|(1u<<25)|(31u<<20)|(1u<<15)|(31u<<10)|(1u<<5)|31u)
);

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

float getGlyphPixel(int glyph_idx, vec2 local_uv) {
    glyph_idx = glyph_idx & 15;
    int px = clamp(int(local_uv.x * 5.0), 0, 4);
    int py = clamp(int(local_uv.y * 7.0), 0, 6);
    int bit_idx = py * 5 + px;
    return float((GLYPHS[glyph_idx] >> bit_idx) & 1u);
}

vec3 DrawLayer(vec2 uv, float depth, float speed_mult, float brightness, float seed_shift) {
    vec2 layer_uv = (uv * depth) + vec2(seed_shift, seed_shift);
    vec2 baseCharSize = vec2(CHAR_WIDTH, 14.0) * max(0.001, FONT_SCALE);
    vec2 grid_dims = iResolution.xy / baseCharSize;
    vec2 grid_uv = layer_uv * grid_dims;
    vec2 cell_id = floor(grid_uv);
    vec2 local_uv = fract(grid_uv);
    float char_seed = random(cell_id + floor(mod(iTime, 1000.0) * 4.0) + depth);
    int glyph_idx = int(char_seed * 16.0);
    vec2 padded_uv = (local_uv - 0.1) / 0.8;
    padded_uv = clamp(padded_uv, 0.0, 1.0);
    float glyph = getGlyphPixel(glyph_idx, padded_uv);
    float border = step(0.1, local_uv.x) * step(local_uv.x, 0.9) * step(0.05, local_uv.y) * step(local_uv.y, 0.95);
    float shape = glyph * border;
    float col_rnd = fract(sin(cell_id.x * 78.233 + seed_shift * 45.164) * 43758.5453);
    if (col_rnd > RAIN_DENSITY) return vec3(0, 0, 0);

    // HIGH VARIATION: unique phase per column prevents breathing sync
    float col_hash = fract(sin(cell_id.x * 127.1 + seed_shift * 311.7) * 43758.5453);
    float speed_hash = fract(sin(cell_id.x * 269.5 + seed_shift * 183.3) * 28461.7231);
    float phase_offset = col_hash * grid_dims.y * 4.0;

    float height_scale = iResolution.y / 1080.0;
    float final_speed = ((speed_hash * 0.7 + 0.15) * 10.0 * RAIN_SPEED * speed_mult * height_scale) / depth;
    float rain_pos = cell_id.y - (iTime * final_speed) + phase_offset;
    float cycle = fract(rain_pos / grid_dims.y * 1.5);
    float trail = pow(cycle, TRAIL_POWER);
    float is_head = step(0.97, cycle);
    vec3 userColor = vec3(RAIN_R, RAIN_G, RAIN_B);
    vec3 whiteHead = vec3(0.9, 1.0, 0.9);
    return mix(userColor, whiteHead, is_head) * trail * shape * brightness;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 tex = fragCoord.xy / iResolution.xy;
    vec2 rainTex = vec2(tex.x, 1.0 - tex.y);

    vec3 totalRain = vec3(0, 0, 0);
    if (SHOW_L1 > 0.5) totalRain += DrawLayer(rainTex, 1.5, 0.8, 0.3, 100.0);
    if (SHOW_L2 > 0.5) totalRain += DrawLayer(rainTex, 1.2, 0.9, 0.6, 200.0);
    if (SHOW_L3 > 0.5) totalRain += DrawLayer(rainTex, 0.9, 1.0, 1.0, 300.0);

    vec4 text = texture(iChannel0, tex);
    vec3 rain = totalRain * GLOW_STRENGTH;
    vec3 color = text.rgb + rain;

    // Per-pixel alpha: rain is always opaque, background uses background-opacity
    float rainAlpha = clamp(max(rain.r, max(rain.g, rain.b)) * 4.0, 0.0, 1.0);
    float alpha = max(text.a, rainAlpha);
    fragColor = vec4(color * alpha, alpha);
}
