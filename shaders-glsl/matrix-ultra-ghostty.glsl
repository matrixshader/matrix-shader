// MATRIX ULTRA - GPU stress test / showcase shader (Ghostty / Shadertoy API)
// Ported from MatrixUltra.hlsl for Ghostty
// 10 parallax depth layers, volumetric fog, bloom, reflections,
// depth of field, god rays, and CRT scanlines.

#define RAIN_SPEED      3.0
#define GLOW_STRENGTH   1.2
#define CHAR_WIDTH      10.0
#define FONT_SCALE      1.0
#define TRAIL_POWER     7.0
#define RAIN_DENSITY    0.35
#define NUM_LAYERS      10
#define FOG_DENSITY     0.04
#define BLOOM_RADIUS    0.003
#define BLOOM_STRENGTH  0.5
#define REFLECTION_Y    0.92
#define REFLECTION_STR  0.35
#define SCANLINE_STR    0.06
#define GODRAY_STR      0.08
#define DOF_FAR         0.4
#define CHAR_CYCLE_SPEED 5.0

// Bit-packed Katakana glyphs (5x7 pixels each, 16 glyphs)
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

float random(vec2 uv) { return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123); }

float hash11(float p)
{
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = random(i);
    float b = random(i + vec2(1, 0));
    float c = random(i + vec2(0, 1));
    float d = random(i + vec2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float getGlyphPixel(int glyph_idx, vec2 local_uv) {
    glyph_idx = glyph_idx & 15;
    int px = clamp(int(local_uv.x * 5.0), 0, 4);
    int py = clamp(int(local_uv.y * 7.0), 0, 6);
    int bit_idx = py * 5 + px;
    return float((GLYPHS[glyph_idx] >> uint(bit_idx)) & 1u);
}

// --- Single rain layer with full features ---
// Returns vec4: rgb = colored rain, a = raw brightness (for bloom)
vec4 DrawLayerUltra(vec2 uv, float layerIdx, float totalLayers)
{
    float depthNorm = layerIdx / (totalLayers - 1.0);
    float depth = mix(0.7, 2.2, depthNorm);
    float speed_mult = mix(1.2, 0.4, depthNorm);
    float brightness = mix(1.0, 0.15, depthNorm * depthNorm);
    float sizeScale = mix(1.3, 0.6, depthNorm);
    float density = mix(RAIN_DENSITY * 0.8, RAIN_DENSITY * 1.5, depthNorm);
    float seed_shift = layerIdx * 127.0 + 100.0;

    vec2 layer_uv = (uv * depth) + vec2(seed_shift * 0.01, seed_shift * 0.007);
    vec2 baseCharSize = vec2(CHAR_WIDTH, 14.0) * max(0.001, FONT_SCALE) * sizeScale;
    vec2 grid_dims = iResolution.xy / baseCharSize;
    vec2 grid_uv = layer_uv * grid_dims;
    vec2 cell_id = floor(grid_uv);
    vec2 local_uv = fract(grid_uv);

    float cycleSpeed = mix(CHAR_CYCLE_SPEED, CHAR_CYCLE_SPEED * 0.5, depthNorm);
    float char_seed = random(cell_id + floor(iTime * cycleSpeed) + depth);
    int glyph_idx = int(char_seed * 16.0);

    vec2 padded_uv = (local_uv - 0.1) / 0.8;
    padded_uv = clamp(padded_uv, 0.0, 1.0);
    float glyph = getGlyphPixel(glyph_idx, padded_uv);
    float border = step(0.1, local_uv.x) * step(local_uv.x, 0.9)
                 * step(0.05, local_uv.y) * step(local_uv.y, 0.95);
    float shape = glyph * border;

    float col_rnd = random(vec2(cell_id.x, seed_shift));
    if (col_rnd > density)
        return vec4(0, 0, 0, 0);

    float col_hash = fract(sin(cell_id.x * 127.1 + seed_shift * 311.7) * 43758.5453);
    float phase_offset = col_hash * grid_dims.y * 2.5;

    float final_speed = ((col_rnd * 0.5 + 0.2) * 10.0 * RAIN_SPEED * speed_mult) / depth;
    float rain_pos = cell_id.y - (iTime * final_speed) + phase_offset;
    float cycle = fract(rain_pos / grid_dims.y * 1.5);
    float trail = pow(cycle, float(TRAIL_POWER));
    float is_head = step(0.97, cycle);

    vec3 nearColor = vec3(0.0, 1.0, 0.3);
    vec3 farColor = vec3(0.0, 0.5, 0.4);
    vec3 baseColor = mix(nearColor, farColor, depthNorm);
    vec3 whiteHead = vec3(0.85, 1.0, 0.9);

    vec3 rainColor = mix(baseColor, whiteHead, is_head) * trail * shape * brightness;

    float headGlow = is_head * trail * brightness * 0.5;
    float headDist = length(local_uv - 0.5) * 2.0;
    float halo = exp(-headDist * headDist * 3.0) * headGlow;
    rainColor += vec3(0.3, 1.0, 0.5) * halo;

    float rawBrightness = trail * shape * brightness + halo;

    return vec4(rainColor, rawBrightness);
}

// --- Main shader ---
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 rawTex = fragCoord / iResolution.xy;
    vec2 tex = vec2(rawTex.x, 1.0 - rawTex.y);  // Flip Y for effect (HLSL y=0 at top)
    vec2 uv = tex;
    float t = iTime;

    // Subtle camera sway
    float swayX = sin(t * 0.15) * 0.003;
    float swayY = cos(t * 0.11) * 0.002;
    uv += vec2(swayX, swayY);

    // Accumulate all layers
    vec3 totalRain = vec3(0, 0, 0);
    float totalBrightness = 0.0;
    float totalFog = 0.0;

    for (int i = 0; i < NUM_LAYERS; i++)
    {
        float layerIdx = float(i);
        float depthNorm = layerIdx / float(NUM_LAYERS - 1);

        vec4 layer = DrawLayerUltra(uv, layerIdx, float(NUM_LAYERS));

        // Depth of field: blur far layers by sampling neighbors
        if (depthNorm > 0.5)
        {
            float blur = (depthNorm - 0.5) * DOF_FAR;
            vec4 l2 = DrawLayerUltra(uv + vec2(blur, 0), layerIdx, float(NUM_LAYERS));
            vec4 l3 = DrawLayerUltra(uv + vec2(-blur, 0), layerIdx, float(NUM_LAYERS));
            vec4 l4 = DrawLayerUltra(uv + vec2(0, blur * 0.7), layerIdx, float(NUM_LAYERS));
            layer = (layer + l2 + l3 + l4) * 0.25;
        }

        totalRain += layer.rgb;
        totalBrightness += layer.a;

        totalFog += FOG_DENSITY * depthNorm;
    }

    // Volumetric green fog between layers
    vec3 fogColor = vec3(0.0, 0.08, 0.03);
    totalRain += fogColor * totalFog;

    // --- Bloom: bright spots bleed ---
    vec3 bloom = vec3(0, 0, 0);
    float bloomSamples = 0.0;
    for (int bx = -2; bx <= 2; bx++)
    {
        for (int by = -2; by <= 2; by++)
        {
            if (bx == 0 && by == 0) continue;
            vec2 offset = vec2(float(bx), float(by)) * BLOOM_RADIUS;
            for (int bl = 7; bl < NUM_LAYERS; bl++)
            {
                vec4 bs = DrawLayerUltra(uv + offset, float(bl), float(NUM_LAYERS));
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
        vec2 grUV = vec2(uv.x, sampleY);
        vec4 grSample = DrawLayerUltra(grUV, float(NUM_LAYERS - 1), float(NUM_LAYERS));
        godray += grSample.a * exp(-grF * 0.5);
    }
    totalRain += vec3(0.0, 0.15, 0.05) * godray * GODRAY_STR;

    // --- Wet floor reflection ---
    if (uv.y > REFLECTION_Y)
    {
        float reflDist = (uv.y - REFLECTION_Y) / (1.0 - REFLECTION_Y);
        vec2 reflUV = vec2(uv.x, REFLECTION_Y - (uv.y - REFLECTION_Y));
        float ripple = noise(vec2(uv.x * 30.0, t * 2.0 + reflDist * 10.0));
        reflUV.x += (ripple - 0.5) * 0.01 * reflDist;

        vec3 reflRain = vec3(0, 0, 0);
        for (int ri = 6; ri < NUM_LAYERS; ri++)
        {
            vec4 rl = DrawLayerUltra(reflUV, float(ri), float(NUM_LAYERS));
            reflRain += rl.rgb;
        }
        float reflFade = (1.0 - reflDist) * REFLECTION_STR;
        totalRain += reflRain * reflFade * vec3(0.6, 1.0, 0.7);

        totalRain += vec3(0.0, 0.015, 0.008) * (1.0 - reflDist);
    }

    // --- CRT scanlines ---
    float scanline = sin(uv.y * iResolution.y * 1.0) * 0.5 + 0.5;
    scanline = 1.0 - scanline * SCANLINE_STR;

    // --- Vignette ---
    vec2 vig = uv * (1.0 - uv);
    float vigMask = clamp(pow(vig.x * vig.y * 12.0, 0.3), 0.0, 1.0);

    // --- Combine with terminal text ---
    vec4 text = texture(iChannel0, rawTex);  // Terminal texture uses original coords
    vec3 rainFinal = totalRain * GLOW_STRENGTH * scanline * vigMask;

    // Global subtle pulse
    float pulse = sin(t * 0.3) * 0.03 + 1.0;
    rainFinal *= pulse;

    // Alpha = rain brightness so empty areas are transparent
    float rainAlpha = clamp(dot(rainFinal, vec3(0.299, 0.587, 0.114)) * 3.0, 0.0, 1.0);
    float alpha = max(text.a, rainAlpha);

    vec3 finalColor = text.rgb + rainFinal;
    fragColor = vec4(finalColor, alpha);
}
