// MATRIX SHADER - SLOT 7
#define RAIN_R         0.5
#define RAIN_G         1.0
#define RAIN_B         0.3
#define RAIN_SPEED     1.3
#define GLOW_STRENGTH  2.0
#define FONT_SCALE     1.0
#define CHAR_WIDTH     8.0
#define TRAIL_POWER    8.0
#define RAIN_DENSITY   1.0
#define SHOW_L1        1.0
#define SHOW_L2        0.0
#define SHOW_L3        1.0

Texture2D shaderTexture;
SamplerState samplerState;
cbuffer PixelShaderSettings { float Time; float Scale; float2 Resolution; float4 Background; };

static const uint GLYPHS[16] = {
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
};

float random(float2 uv) { return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453123); }

float getGlyphPixel(int glyph_idx, float2 local_uv) {
    glyph_idx = glyph_idx & 15;
    int px = clamp(int(local_uv.x * 5.0), 0, 4);
    int py = clamp(int(local_uv.y * 7.0), 0, 6);
    int bit_idx = py * 5 + px;
    return float((GLYPHS[glyph_idx] >> bit_idx) & 1u);
}

float3 DrawLayer(float2 uv, float depth, float speed_mult, float brightness, float seed_shift) {
    float2 layer_uv = (uv * depth) + float2(seed_shift, seed_shift);
    float2 baseCharSize = float2(CHAR_WIDTH, 14.0) * max(0.001, FONT_SCALE);
    float2 grid_dims = Resolution / baseCharSize;
    float2 grid_uv = layer_uv * grid_dims;
    float2 cell_id = floor(grid_uv);
    float2 local_uv = frac(grid_uv);
    float char_seed = random(cell_id + floor(Time * 4.0) + depth);
    int glyph_idx = int(char_seed * 16.0);
    float2 padded_uv = (local_uv - 0.1) / 0.8;
    padded_uv = clamp(padded_uv, 0.0, 1.0);
    float glyph = getGlyphPixel(glyph_idx, padded_uv);
    float border = step(0.1, local_uv.x) * step(local_uv.x, 0.9) * step(0.05, local_uv.y) * step(local_uv.y, 0.95);
    float shape = glyph * border;
    float col_rnd = random(float2(cell_id.x, seed_shift));
    if (col_rnd > RAIN_DENSITY) return float3(0,0,0);
    float final_speed = ((col_rnd * 0.5 + 0.2) * 10.0 * RAIN_SPEED * speed_mult) / depth;
    float rain_pos = cell_id.y - (Time * final_speed) + (col_rnd * 1000.0);
    float cycle = frac(rain_pos / grid_dims.y * 1.5);
    float trail = pow(cycle, TRAIL_POWER);
    float is_head = step(0.97, cycle);
    float3 userColor = float3(RAIN_R, RAIN_G, RAIN_B);
    float3 whiteHead = float3(0.9, 1.0, 0.9);
    return lerp(userColor, whiteHead, is_head) * trail * shape * brightness;
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET {
    float3 totalRain = float3(0,0,0);
    if (SHOW_L1 > 0.5) totalRain += DrawLayer(tex, 1.5, 0.8, 0.3, 100.0);
    if (SHOW_L2 > 0.5) totalRain += DrawLayer(tex, 1.2, 0.9, 0.6, 200.0);
    if (SHOW_L3 > 0.5) totalRain += DrawLayer(tex, 0.9, 1.0, 1.0, 300.0);
    float4 text = shaderTexture.Sample(samplerState, tex);
    return text + float4(totalRain * GLOW_STRENGTH, 0.0);
}