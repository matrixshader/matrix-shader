// AURORA BOREALIS - Northern lights shader for Windows Terminal
// Flowing curtains of green, teal, and purple light rippling
// across your terminal. Text glows through the aurora.

#define AURORA_SPEED     0.08    // How fast the curtains drift
#define AURORA_INTENSITY 0.35    // Overall brightness (0.1 = subtle, 0.6 = vivid)
#define CURTAIN_SCALE    2.5     // Width of curtain folds (lower = more folds)
#define WAVE_HEIGHT      0.45    // How far down the aurora reaches (0.3 = top only, 0.7 = half screen)
#define STAR_DENSITY     0.03    // How many stars (0 = none, 0.1 = many)
#define STAR_TWINKLE     3.0     // How fast stars twinkle
#define COLOR_SHIFT      0.15    // How much color varies over time

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

// --- Smooth noise ---
float noise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    return lerp(lerp(hash21(i + float2(0, 0)), hash21(i + float2(1, 0)), u.x),
                lerp(hash21(i + float2(0, 1)), hash21(i + float2(1, 1)), u.x), u.y);
}

// --- Fractal noise (layered octaves for organic shapes) ---
float fbm(float2 p)
{
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < 5; i++)
    {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// --- Aurora color palette ---
// Blends between green, teal, and purple based on position and time
float3 auroraColor(float x, float t)
{
    float shift = x * 0.5 + t * COLOR_SHIFT;

    // Base colors: green → teal → purple → pink cycle
    float3 green  = float3(0.1, 0.9, 0.3);
    float3 teal   = float3(0.1, 0.7, 0.7);
    float3 purple = float3(0.5, 0.15, 0.8);
    float3 pink   = float3(0.8, 0.2, 0.5);

    // Smooth cycling through the palette
    float phase = frac(shift * 0.3);
    float3 col;

    if (phase < 0.25)
        col = lerp(green, teal, phase * 4.0);
    else if (phase < 0.5)
        col = lerp(teal, purple, (phase - 0.25) * 4.0);
    else if (phase < 0.75)
        col = lerp(purple, pink, (phase - 0.5) * 4.0);
    else
        col = lerp(pink, green, (phase - 0.75) * 4.0);

    return col;
}

// --- Aurora curtain layer ---
float auroraCurtain(float2 uv, float t, float seed)
{
    // Horizontal position with slow drift
    float x = uv.x * CURTAIN_SCALE + seed * 3.0;

    // Curtain fold shape — layered noise for organic ripple
    float fold = fbm(float2(x + t * AURORA_SPEED * 0.7, t * AURORA_SPEED * 0.3 + seed)) * 0.6
               + fbm(float2(x * 2.0 - t * AURORA_SPEED * 0.5, t * AURORA_SPEED * 0.2 + seed * 5.0)) * 0.3;

    // Vertical envelope — aurora is strongest near the top
    float baseHeight = WAVE_HEIGHT + fold * 0.25;
    float verticalMask = smoothstep(baseHeight, 0.0, uv.y);

    // Add vertical rays — thin bright columns within the curtain
    float rayNoise = noise(float2(x * 4.0 + t * AURORA_SPEED * 0.4, seed * 11.0));
    float rays = smoothstep(0.4, 0.7, rayNoise) * 0.6;

    // Shimmer — fast subtle brightness variation
    float shimmer = noise(float2(x * 8.0, t * 1.5 + seed * 7.0)) * 0.3 + 0.7;

    return verticalMask * (0.5 + rays) * shimmer;
}

// --- Stars ---
float stars(float2 uv, float t)
{
    float star = 0.0;
    float2 cellUV = uv * 100.0;
    float2 cellId = floor(cellUV);
    float2 cellFrac = frac(cellUV);

    float r = hash21(cellId * 1.93);
    if (r < STAR_DENSITY)
    {
        float2 pos = float2(hash21(cellId * 2.71), hash21(cellId * 3.41));
        float dist = length(cellFrac - pos);
        float size = 0.02 + r * 0.04;
        float brightness = smoothstep(size, 0.0, dist);

        // Twinkle
        float twinkle = sin(t * STAR_TWINKLE + hash11(cellId.x + cellId.y * 17.0) * 6.28) * 0.5 + 0.5;
        twinkle = 0.3 + twinkle * 0.7;

        star = brightness * twinkle;
    }
    return star;
}

// --- Main shader ---
float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float2 uv = tex;
    float t = Time;

    // Sample terminal texture
    float4 color = shaderTexture.Sample(samplerState, uv);

    // --- Stars (behind everything, only visible in darker areas) ---
    float starMask = stars(uv, t);
    float darkness = 1.0 - saturate(dot(color.rgb, float3(0.3, 0.6, 0.1)));
    color.rgb += starMask * float3(0.8, 0.85, 1.0) * 0.4 * darkness;

    // --- Aurora layers (two curtains at different depths) ---
    float curtain1 = auroraCurtain(uv, t, 0.0);
    float curtain2 = auroraCurtain(uv, t * 0.9, 1.7);

    float3 color1 = auroraColor(uv.x, t) * curtain1;
    float3 color2 = auroraColor(uv.x + 0.5, t + 2.0) * curtain2;

    float3 aurora = (color1 + color2 * 0.6) * AURORA_INTENSITY;

    // Aurora is additive — it glows on top of the terminal text
    color.rgb += aurora;

    // --- Subtle vertical gradient — darker at bottom (night sky feel) ---
    float skyGrad = smoothstep(1.0, 0.2, uv.y) * 0.08;
    color.rgb = lerp(color.rgb, float3(0.02, 0.02, 0.06), skyGrad);

    // --- Very subtle edge darkening ---
    float2 vig = uv * (1.0 - uv);
    float vigMask = saturate(pow(vig.x * vig.y * 20.0, 0.4));
    color.rgb *= 0.85 + vigMask * 0.15;

    color.a = 1.0;
    return color;
}
