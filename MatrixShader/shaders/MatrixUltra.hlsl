// MATRIX ULTRA - GPU stress test / showcase shader
// 10 parallax depth layers, volumetric fog, bloom, reflections,
// depth of field, god rays, and CRT scanlines.
// This shader is INTENTIONALLY expensive. It exists to look insane.

#define RAIN_SPEED      3.0
#define GLOW_STRENGTH   1.2
#define CHAR_WIDTH      10.0
#define FONT_SCALE      1.0
#define TRAIL_POWER     7.0
#define RAIN_DENSITY    0.35
#define NUM_LAYERS      10
#define FOG_DENSITY     0.04    // Green atmospheric haze between layers
#define BLOOM_RADIUS    0.003   // How far glow bleeds from bright chars
#define BLOOM_STRENGTH  0.5
#define REFLECTION_Y    0.92    // Where the wet floor starts (0-1)
#define REFLECTION_STR  0.35    // Reflection brightness
#define SCANLINE_STR    0.06    // CRT scanline intensity
#define GODRAY_STR      0.08   // Volumetric light shaft intensity
#define DOF_FAR         0.4     // Depth of field blur on far layers
#define CHAR_CYCLE_SPEED 5.0    // How fast characters morph

Texture2D shaderTexture;
SamplerState samplerState;
cbuffer PixelShaderSettings { float Time; float Scale; float2 Resolution; float4 Background; };

// Bit-packed Katakana glyphs (5x7 pixels each, 16 glyphs)
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

float hash11(float p)
{
    p = frac(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

float noise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = random(i);
    float b = random(i + float2(1, 0));
    float c = random(i + float2(0, 1));
    float d = random(i + float2(1, 1));
    return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
}

float getGlyphPixel(int glyph_idx, float2 local_uv) {
    glyph_idx = glyph_idx & 15;
    int px = clamp(int(local_uv.x * 5.0), 0, 4);
    int py = clamp(int(local_uv.y * 7.0), 0, 6);
    int bit_idx = py * 5 + px;
    return float((GLYPHS[glyph_idx] >> bit_idx) & 1u);
}

// --- Single rain layer with full features ---
// Returns float4: rgb = colored rain, a = raw brightness (for bloom)
float4 DrawLayerUltra(float2 uv, float layerIdx, float totalLayers)
{
    // Depth: 0 = nearest, 1 = farthest
    float depthNorm = layerIdx / (totalLayers - 1.0);

    // Parallax depth scaling: near layers zoom in, far layers zoom out
    float depth = lerp(0.7, 2.2, depthNorm);

    // Speed: near = fast, far = slow
    float speed_mult = lerp(1.2, 0.4, depthNorm);

    // Brightness: near = bright, far = dim
    float brightness = lerp(1.0, 0.15, depthNorm * depthNorm);

    // Character size: near = larger, far = smaller
    float sizeScale = lerp(1.3, 0.6, depthNorm);

    // Density: near layers sparser, far layers denser (more columns visible)
    float density = lerp(RAIN_DENSITY * 0.8, RAIN_DENSITY * 1.5, depthNorm);

    float seed_shift = layerIdx * 127.0 + 100.0;

    float2 layer_uv = (uv * depth) + float2(seed_shift * 0.01, seed_shift * 0.007);
    float2 baseCharSize = float2(CHAR_WIDTH, 14.0) * max(0.001, FONT_SCALE) * sizeScale;
    float2 grid_dims = Resolution / baseCharSize;
    float2 grid_uv = layer_uv * grid_dims;
    float2 cell_id = floor(grid_uv);
    float2 local_uv = frac(grid_uv);

    // Faster character cycling for near layers
    float cycleSpeed = lerp(CHAR_CYCLE_SPEED, CHAR_CYCLE_SPEED * 0.5, depthNorm);
    float char_seed = random(cell_id + floor(Time * cycleSpeed) + depth);
    int glyph_idx = int(char_seed * 16.0);

    float2 padded_uv = (local_uv - 0.1) / 0.8;
    padded_uv = clamp(padded_uv, 0.0, 1.0);
    float glyph = getGlyphPixel(glyph_idx, padded_uv);
    float border = step(0.1, local_uv.x) * step(local_uv.x, 0.9)
                 * step(0.05, local_uv.y) * step(local_uv.y, 0.95);
    float shape = glyph * border;

    float col_rnd = random(float2(cell_id.x, seed_shift));
    if (col_rnd > density)
        return float4(0, 0, 0, 0);

    // Unique phase per column — high variation prevents sync
    float col_hash = frac(sin(cell_id.x * 127.1 + seed_shift * 311.7) * 43758.5453);
    float phase_offset = col_hash * grid_dims.y * 2.5;

    float final_speed = ((col_rnd * 0.5 + 0.2) * 10.0 * RAIN_SPEED * speed_mult) / depth;
    float rain_pos = cell_id.y - (Time * final_speed) + phase_offset;
    float cycle = frac(rain_pos / grid_dims.y * 1.5);
    float trail = pow(cycle, TRAIL_POWER);
    float is_head = step(0.97, cycle);

    // Color shifts with depth: bright green near, blue-green far
    float3 nearColor = float3(0.0, 1.0, 0.3);
    float3 farColor = float3(0.0, 0.5, 0.4);
    float3 baseColor = lerp(nearColor, farColor, depthNorm);
    float3 whiteHead = float3(0.85, 1.0, 0.9);

    float3 rainColor = lerp(baseColor, whiteHead, is_head) * trail * shape * brightness;

    // Head character extra glow (halo effect)
    float headGlow = is_head * trail * brightness * 0.5;
    float headDist = length(local_uv - 0.5) * 2.0;
    float halo = exp(-headDist * headDist * 3.0) * headGlow;
    rainColor += float3(0.3, 1.0, 0.5) * halo;

    float rawBrightness = trail * shape * brightness + halo;

    return float4(rainColor, rawBrightness);
}

// --- Main shader ---
float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float2 uv = tex;
    float t = Time;

    // Subtle camera sway
    float swayX = sin(t * 0.15) * 0.003;
    float swayY = cos(t * 0.11) * 0.002;
    uv += float2(swayX, swayY);

    // Accumulate all layers
    float3 totalRain = float3(0, 0, 0);
    float totalBrightness = 0.0;
    float totalFog = 0.0;

    for (int i = 0; i < NUM_LAYERS; i++)
    {
        float layerIdx = float(i);
        float depthNorm = layerIdx / float(NUM_LAYERS - 1);

        float4 layer = DrawLayerUltra(uv, layerIdx, float(NUM_LAYERS));

        // Depth of field: blur far layers by sampling neighbors
        if (depthNorm > 0.5)
        {
            float blur = (depthNorm - 0.5) * DOF_FAR;
            float4 l2 = DrawLayerUltra(uv + float2(blur, 0), layerIdx, float(NUM_LAYERS));
            float4 l3 = DrawLayerUltra(uv + float2(-blur, 0), layerIdx, float(NUM_LAYERS));
            float4 l4 = DrawLayerUltra(uv + float2(0, blur * 0.7), layerIdx, float(NUM_LAYERS));
            layer = (layer + l2 + l3 + l4) * 0.25;
        }

        totalRain += layer.rgb;
        totalBrightness += layer.a;

        // Volumetric fog accumulates with depth
        totalFog += FOG_DENSITY * depthNorm;
    }

    // Volumetric green fog between layers
    float3 fogColor = float3(0.0, 0.08, 0.03);
    totalRain += fogColor * totalFog;

    // --- Bloom: bright spots bleed ---
    float3 bloom = float3(0, 0, 0);
    float bloomSamples = 0.0;
    for (int bx = -2; bx <= 2; bx++)
    {
        for (int by = -2; by <= 2; by++)
        {
            if (bx == 0 && by == 0) continue;
            float2 offset = float2(float(bx), float(by)) * BLOOM_RADIUS;
            // Sample the nearest 3 layers for bloom (most visible)
            for (int bl = 7; bl < NUM_LAYERS; bl++)
            {
                float4 bs = DrawLayerUltra(uv + offset, float(bl), float(NUM_LAYERS));
                bloom += bs.rgb * bs.a;
            }
            bloomSamples += 1.0;
        }
    }
    bloom = (bloom / max(bloomSamples, 1.0)) * BLOOM_STRENGTH;
    totalRain += bloom;

    // --- God rays: vertical light shafts from bright columns ---
    float godray = 0.0;
    for (int gr = 0; gr < 6; gr++)
    {
        float grF = float(gr);
        float sampleY = uv.y - (grF + 1.0) * 0.02;
        if (sampleY < 0.0) break;
        float2 grUV = float2(uv.x, sampleY);
        float4 grSample = DrawLayerUltra(grUV, float(NUM_LAYERS - 1), float(NUM_LAYERS));
        godray += grSample.a * exp(-grF * 0.5);
    }
    totalRain += float3(0.0, 0.15, 0.05) * godray * GODRAY_STR;

    // --- Wet floor reflection ---
    if (uv.y > REFLECTION_Y)
    {
        float reflDist = (uv.y - REFLECTION_Y) / (1.0 - REFLECTION_Y);
        float2 reflUV = float2(uv.x, REFLECTION_Y - (uv.y - REFLECTION_Y));
        // Ripple distortion on the reflection
        float ripple = noise(float2(uv.x * 30.0, t * 2.0 + reflDist * 10.0));
        reflUV.x += (ripple - 0.5) * 0.01 * reflDist;

        // Sample a few layers for the reflection
        float3 reflRain = float3(0, 0, 0);
        for (int ri = 6; ri < NUM_LAYERS; ri++)
        {
            float4 rl = DrawLayerUltra(reflUV, float(ri), float(NUM_LAYERS));
            reflRain += rl.rgb;
        }
        // Fade reflection with distance from reflection line
        float reflFade = (1.0 - reflDist) * REFLECTION_STR;
        totalRain += reflRain * reflFade * float3(0.6, 1.0, 0.7);

        // Glossy floor base color
        totalRain += float3(0.0, 0.015, 0.008) * (1.0 - reflDist);
    }

    // --- CRT scanlines ---
    float scanline = sin(uv.y * Resolution.y * 1.0) * 0.5 + 0.5;
    scanline = 1.0 - scanline * SCANLINE_STR;

    // --- Vignette ---
    float2 vig = uv * (1.0 - uv);
    float vigMask = saturate(pow(vig.x * vig.y * 12.0, 0.3));

    // --- Combine with terminal text ---
    float4 text = shaderTexture.Sample(samplerState, tex);
    float3 rainFinal = totalRain * GLOW_STRENGTH * scanline * vigMask;

    // Global subtle pulse — the Matrix breathes
    float pulse = sin(t * 0.3) * 0.03 + 1.0;
    rainFinal *= pulse;

    // Alpha = rain brightness so empty areas are transparent
    float rainAlpha = saturate(dot(rainFinal, float3(0.299, 0.587, 0.114)) * 3.0);
    float alpha = max(text.a, rainAlpha);

    float3 finalColor = text.rgb + rainFinal;
    return float4(finalColor, alpha);
}
