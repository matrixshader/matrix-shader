// AURORA BOREALIS - Northern lights shader (Ghostty / Shadertoy API)
// Ported from AuroraBorealis.hlsl for Ghostty
// Flowing curtains of green, teal, and purple light rippling
// across your terminal. Text glows through the aurora.

#define AURORA_SPEED     0.08
#define AURORA_INTENSITY 0.35
#define CURTAIN_SCALE    2.5
#define WAVE_HEIGHT      0.45
#define STAR_DENSITY     0.03
#define STAR_TWINKLE     3.0
#define COLOR_SHIFT      0.15

// --- Hash functions ---

float hash11(float p)
{
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash21(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// --- Smooth noise ---
float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    return mix(mix(hash21(i + vec2(0, 0)), hash21(i + vec2(1, 0)), u.x),
               mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), u.x), u.y);
}

// --- Fractal noise (layered octaves for organic shapes) ---
float fbm(vec2 p)
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
vec3 auroraColor(float x, float t)
{
    float shift = x * 0.5 + t * COLOR_SHIFT;

    vec3 green  = vec3(0.1, 0.9, 0.3);
    vec3 teal   = vec3(0.1, 0.7, 0.7);
    vec3 purple = vec3(0.5, 0.15, 0.8);
    vec3 pink   = vec3(0.8, 0.2, 0.5);

    float phase = fract(shift * 0.3);
    vec3 col;

    if (phase < 0.25)
        col = mix(green, teal, phase * 4.0);
    else if (phase < 0.5)
        col = mix(teal, purple, (phase - 0.25) * 4.0);
    else if (phase < 0.75)
        col = mix(purple, pink, (phase - 0.5) * 4.0);
    else
        col = mix(pink, green, (phase - 0.75) * 4.0);

    return col;
}

// --- Aurora curtain layer ---
float auroraCurtain(vec2 uv, float t, float seed)
{
    float x = uv.x * CURTAIN_SCALE + seed * 3.0;

    float fold = fbm(vec2(x + t * AURORA_SPEED * 0.7, t * AURORA_SPEED * 0.3 + seed)) * 0.6
               + fbm(vec2(x * 2.0 - t * AURORA_SPEED * 0.5, t * AURORA_SPEED * 0.2 + seed * 5.0)) * 0.3;

    float baseHeight = WAVE_HEIGHT + fold * 0.25;
    float verticalMask = smoothstep(baseHeight, 0.0, uv.y);

    float rayNoise = noise(vec2(x * 4.0 + t * AURORA_SPEED * 0.4, seed * 11.0));
    float rays = smoothstep(0.4, 0.7, rayNoise) * 0.6;

    float shimmer = noise(vec2(x * 8.0, t * 1.5 + seed * 7.0)) * 0.3 + 0.7;

    return verticalMask * (0.5 + rays) * shimmer;
}

// --- Stars ---
float stars(vec2 uv, float t)
{
    float star = 0.0;
    vec2 cellUV = uv * 100.0;
    vec2 cellId = floor(cellUV);
    vec2 cellFrac = fract(cellUV);

    float r = hash21(cellId * 1.93);
    if (r < STAR_DENSITY)
    {
        vec2 pos = vec2(hash21(cellId * 2.71), hash21(cellId * 3.41));
        float dist = length(cellFrac - pos);
        float size = 0.02 + r * 0.04;
        float brightness = smoothstep(size, 0.0, dist);

        float twinkle = sin(t * STAR_TWINKLE + hash11(cellId.x + cellId.y * 17.0) * 6.28) * 0.5 + 0.5;
        twinkle = 0.3 + twinkle * 0.7;

        star = brightness * twinkle;
    }
    return star;
}

// --- Main shader ---
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    uv.y = 1.0 - uv.y;  // Flip Y: HLSL y=0 at top, OpenGL y=0 at bottom
    float t = iTime;

    // Sample terminal texture
    vec4 color = texture(iChannel0, uv);

    // --- Stars (behind everything, only visible in darker areas) ---
    float starMask = stars(uv, t);
    float darkness = 1.0 - clamp(dot(color.rgb, vec3(0.3, 0.6, 0.1)), 0.0, 1.0);
    color.rgb += starMask * vec3(0.8, 0.85, 1.0) * 0.4 * darkness;

    // --- Aurora layers (two curtains at different depths) ---
    float curtain1 = auroraCurtain(uv, t, 0.0);
    float curtain2 = auroraCurtain(uv, t * 0.9, 1.7);

    vec3 color1 = auroraColor(uv.x, t) * curtain1;
    vec3 color2 = auroraColor(uv.x + 0.5, t + 2.0) * curtain2;

    vec3 aurora = (color1 + color2 * 0.6) * AURORA_INTENSITY;

    // Aurora is additive
    color.rgb += aurora;

    // --- Subtle vertical gradient ---
    float skyGrad = smoothstep(1.0, 0.2, uv.y) * 0.08;
    color.rgb = mix(color.rgb, vec3(0.02, 0.02, 0.06), skyGrad);

    // --- Very subtle edge darkening ---
    vec2 vig = uv * (1.0 - uv);
    float vigMask = clamp(pow(vig.x * vig.y * 20.0, 0.4), 0.0, 1.0);
    color.rgb *= 0.85 + vigMask * 0.15;

    fragColor = vec4(color.rgb, 1.0);
}
