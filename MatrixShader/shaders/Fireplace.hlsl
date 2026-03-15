// FIREPLACE - Crackling fire shader for Windows Terminal
// Flames dance at the bottom, sparks fly upward, embers float,
// and heat haze distorts the text above the fire.

#define FLAME_HEIGHT     0.38   // How far up the flames reach
#define FLAME_INTENSITY  0.9    // Brightness of the fire
#define FLAME_SPEED      1.4    // How fast flames dance
#define SPARK_DENSITY    0.15   // How many sparks
#define SPARK_SPEED      0.7    // How fast sparks rise
#define EMBER_DENSITY    0.10   // Floating ash/ember density
#define EMBER_SPEED      0.18   // How fast embers drift up
#define HEAT_HAZE        0.003  // Text distortion from heat
#define GLOW_STRENGTH    0.12   // Ambient warm glow on the whole screen

Texture2D shaderTexture;
SamplerState samplerState;
cbuffer PixelShaderSettings { float Time; float Scale; float2 Resolution; float4 Background; };

// --- Hash functions ---
float hash11(float p)
{
    p = frac(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

float hash21(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

float2 hash22(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.xx + p3.yz) * p3.zy);
}

float noise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return lerp(lerp(hash21(i + float2(0, 0)), hash21(i + float2(1, 0)), u.x),
                lerp(hash21(i + float2(0, 1)), hash21(i + float2(1, 1)), u.x), u.y);
}

// --- Turbulent noise (absolute value creates sharp creases like real fire) ---
float turbulence(float2 p)
{
    float value = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < 6; i++)
    {
        // abs() creates hard edges and creases — key for fire look
        value += amp * abs(noise(p * freq) * 2.0 - 1.0);
        freq *= 2.2;
        amp *= 0.45;
    }
    return value;
}

// Smooth fbm for domain warping only
float fbm(float2 p)
{
    float value = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < 4; i++)
    {
        value += amp * noise(p * freq);
        freq *= 2.0;
        amp *= 0.5;
    }
    return value;
}

// --- Fire color ramp ---
float3 fireColor(float temp)
{
    // Sharper color transitions for more defined fire
    float3 col;
    col.r = smoothstep(0.05, 0.3, temp);
    col.g = smoothstep(0.2, 0.7, temp) * 0.8;
    col.b = smoothstep(0.6, 0.95, temp) * 0.35;

    // Bright orange-yellow in the mid range
    float midBoost = smoothstep(0.25, 0.5, temp) * smoothstep(0.8, 0.5, temp);
    col.r += midBoost * 0.15;
    col.g += midBoost * 0.1;

    return col;
}

// --- Flame field ---
float flameField(float2 uv, float t)
{
    // Flip Y: y=0 at bottom of screen, y=1 at top
    float y = 1.0 - uv.y;

    if (y > FLAME_HEIGHT + 0.15)
        return 0.0;

    // Vertical falloff — gentler curve, more fire at the bottom
    float vertFalloff = smoothstep(FLAME_HEIGHT + 0.1, 0.0, y);
    vertFalloff = pow(vertFalloff, 1.1); // Less aggressive = more fire visible

    // Medium domain warp — enough curl to look organic, not so tight it chunks
    float warpX = noise(float2(uv.x * 6.0, y * 3.0 - t * FLAME_SPEED * 0.5)) - 0.5;
    float warpY = noise(float2(uv.x * 5.0 + 5.0, y * 2.5 - t * FLAME_SPEED * 0.4)) - 0.5;

    float2 fireUV = float2(
        uv.x * 4.5 + warpX * 0.5,
        y * 3.5 - t * FLAME_SPEED + warpY * 0.25
    );

    // Blend smooth and turbulent noise — defined but not chunky
    float smooth = fbm(fireUV);
    float sharp = turbulence(fireUV);
    float flame = lerp(smooth, sharp, 0.45); // 45% sharp edges, 55% smooth body

    // Second layer for detail (lighter)
    flame += lerp(fbm(fireUV * 1.6 + float2(3.3, t * 0.3)),
                  turbulence(fireUV * 1.6 + float2(3.3, t * 0.3)), 0.3) * 0.3;

    // Gentler contrast remap — lower threshold = more fire visible
    flame = smoothstep(0.2, 0.85, flame);

    // No width mask at bottom — fire spans beyond the window like viewing a larger fire
    // Only taper the very tips of the tallest flames slightly
    float topTaper = lerp(1.0, smoothstep(1.0, 0.5, abs(uv.x - 0.5) * 2.0), saturate(y / FLAME_HEIGHT - 0.6));
    float widthMask = topTaper;

    float temperature = flame * vertFalloff * widthMask;

    // Hot core across entire bottom — no horizontal falloff
    float coreX = 1.0;
    float coreY = smoothstep(0.10, 0.0, y);
    temperature = max(temperature, coreX * coreY * 0.85);

    return saturate(temperature * FLAME_INTENSITY);
}

// --- Sparks (bright particles rising UP from flames) ---
float3 sparks(float2 uv, float t)
{
    float3 result = float3(0, 0, 0);

    for (int layer = 0; layer < 2; layer++)
    {
        float layerF = float(layer);

        // Work in flipped Y so 0 = bottom screen
        float flippedY = 1.0 - uv.y;

        float2 cellUV = float2(uv.x * (30.0 + layerF * 12.0), flippedY * 10.0);

        float col = floor(cellUV.x);
        cellUV.y += hash11(col * 3.7 + layerF * 11.0) * 50.0;

        float2 cellId = floor(cellUV);
        float2 cellFrac = frac(cellUV);

        float r = hash21(cellId + layerF * 23.0);
        if (r > SPARK_DENSITY)
            continue;

        float2 props = hash22(cellId + layerF * 37.0);

        // Spark rises: frac goes 0→1, which in flipped Y = upward
        float sparkTime = t * SPARK_SPEED * (0.5 + props.y * 1.0)
                        + hash11(cellId.x + cellId.y * 5.0 + layerF) * 100.0;
        float sparkProgress = frac(sparkTime);

        // Horizontal wobble as it rises
        float wobble = sin(sparkTime * 4.0 + props.x * 12.0) * 0.12;
        float sparkX = 0.3 + props.x * 0.4 + wobble;

        // Fade: bright at start (near flames), fade as it rises
        float life = smoothstep(0.0, 0.03, sparkProgress) * smoothstep(1.0, 0.5, sparkProgress);

        // Restrict origin to flame zone (bottom portion)
        float originY = sparkProgress; // 0 = bottom (flame), 1 = top
        if (originY < 0.0)
            continue;

        float2 diff = cellFrac - float2(sparkX, sparkProgress);
        float dist = length(diff);

        // Tiny bright point
        float size = 0.015 + props.x * 0.02;
        float spark = smoothstep(size, 0.0, dist) * life;

        if (spark > 0.01)
        {
            // White-yellow hot core
            float3 sparkCol = lerp(float3(1.0, 0.6, 0.1), float3(1.0, 1.0, 0.8), spark);
            result += spark * sparkCol;
        }
    }

    return result;
}

// --- Floating embers/ash (large, dim, slow, wandering) ---
float3 embers(float2 uv, float t)
{
    float3 result = float3(0, 0, 0);

    // Work in flipped Y
    float flippedY = 1.0 - uv.y;

    // Fewer, larger cells than sparks
    float2 cellUV = float2(uv.x * 12.0, flippedY * 6.0);

    float col = floor(cellUV.x);
    cellUV.y += hash11(col * 5.3) * 30.0;

    float2 cellId = floor(cellUV);
    float2 cellFrac = frac(cellUV);

    float r = hash21(cellId * 1.53);
    if (r > EMBER_DENSITY)
        return result;

    float2 props = hash22(cellId * 2.17);

    // Embers rise very slowly with wide lazy drift
    float emberTime = t * EMBER_SPEED * (0.4 + props.y * 0.8)
                    + hash11(cellId.x * 3.0 + cellId.y * 7.0) * 100.0;
    float emberProgress = frac(emberTime);

    // Wide horizontal meander — lazy floating
    float drift = sin(emberTime * 0.8 + props.x * 6.0) * 0.35
                + cos(emberTime * 0.5 + props.y * 4.0) * 0.2;
    float emberX = 0.15 + props.x * 0.7 + drift;

    // Slow fade
    float life = smoothstep(0.0, 0.15, emberProgress) * smoothstep(1.0, 0.6, emberProgress);

    float2 diff = cellFrac - float2(emberX, emberProgress);
    float dist = length(diff);

    // Larger than sparks, softer edges
    float size = 0.03 + props.x * 0.04;
    float ember = smoothstep(size, size * 0.3, dist) * life;

    if (ember > 0.01)
    {
        // Dim pulsing red-orange glow — clearly different from bright sparks
        float pulse = sin(t * 2.5 + props.y * 8.0) * 0.4 + 0.6;
        float3 emberCol = float3(0.8, 0.25, 0.03) * pulse;
        // Some embers are more orange, some more red
        emberCol = lerp(emberCol, float3(0.9, 0.4, 0.05), props.x);
        result = ember * emberCol * 0.5;
    }

    return result;
}

// --- Heat haze ---
float2 heatHaze(float2 uv, float t)
{
    float y = 1.0 - uv.y;
    float hazeMask = smoothstep(FLAME_HEIGHT + 0.25, 0.02, y);

    float2 haze;
    haze.x = noise(float2(uv.x * 12.0, uv.y * 5.0 - t * 2.5)) - 0.5;
    haze.y = noise(float2(uv.x * 10.0 + 3.0, uv.y * 6.0 - t * 3.0)) - 0.5;

    return haze * HEAT_HAZE * hazeMask;
}

// --- Main shader ---
float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float2 uv = tex;
    float t = Time;

    // Heat distortion
    float2 hazeOffset = heatHaze(uv, t);
    float2 hazedUV = clamp(uv + hazeOffset, 0.0, 1.0);
    float4 color = shaderTexture.Sample(samplerState, hazedUV);

    // Ambient warm glow from below
    float glowY = 1.0 - uv.y;
    float glow = pow(glowY, 2.5) * GLOW_STRENGTH;
    color.rgb += float3(1.0, 0.45, 0.1) * glow;

    // Flames
    float temp = flameField(uv, t);
    if (temp > 0.01)
    {
        float3 flameCol = fireColor(temp);
        color.rgb = lerp(color.rgb, flameCol, temp * 0.92);
        color.rgb += flameCol * temp * 0.25;
    }

    // Sparks (bright, fast, tiny, rising from flames)
    color.rgb += sparks(uv, t);

    // Embers (dim, slow, large, floating)
    color.rgb += embers(uv, t);

    // Global firelight flicker
    float flicker = noise(float2(t * 9.0, 0.5)) * 0.07 + 0.96;
    color.rgb *= flicker;

    // Subtle vignette
    float2 vig = uv * (1.0 - uv);
    float vigMask = saturate(pow(vig.x * vig.y * 15.0, 0.35));
    color.rgb *= 0.9 + vigMask * 0.1;

    color.a = 1.0;
    return color;
}
