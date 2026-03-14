// FIREPLACE - Crackling fire shader (Ghostty / Shadertoy API)
// Ported from Fireplace.hlsl for Ghostty
// Flames dance at the bottom, sparks fly upward, embers float,
// and heat haze distorts the text above the fire.

#define FLAME_HEIGHT     0.38
#define FLAME_INTENSITY  0.9
#define FLAME_SPEED      1.4
#define SPARK_DENSITY    0.15
#define SPARK_SPEED      0.7
#define EMBER_DENSITY    0.10
#define EMBER_SPEED      0.18
#define HEAT_HAZE        0.003
#define GLOW_STRENGTH    0.12

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

vec2 hash22(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float noise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(mix(hash21(i + vec2(0, 0)), hash21(i + vec2(1, 0)), u.x),
               mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), u.x), u.y);
}

// --- Turbulent noise ---
float turbulence(vec2 p)
{
    float value = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < 6; i++)
    {
        value += amp * abs(noise(p * freq) * 2.0 - 1.0);
        freq *= 2.2;
        amp *= 0.45;
    }
    return value;
}

// Smooth fbm for domain warping only
float fbm(vec2 p)
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
vec3 fireColor(float temp)
{
    vec3 col;
    col.r = smoothstep(0.05, 0.3, temp);
    col.g = smoothstep(0.2, 0.7, temp) * 0.8;
    col.b = smoothstep(0.6, 0.95, temp) * 0.35;

    float midBoost = smoothstep(0.25, 0.5, temp) * smoothstep(0.8, 0.5, temp);
    col.r += midBoost * 0.15;
    col.g += midBoost * 0.1;

    return col;
}

// --- Flame field ---
float flameField(vec2 uv, float t)
{
    float y = 1.0 - uv.y;

    if (y > FLAME_HEIGHT + 0.15)
        return 0.0;

    float vertFalloff = smoothstep(FLAME_HEIGHT + 0.1, 0.0, y);
    vertFalloff = pow(vertFalloff, 1.1);

    float warpX = noise(vec2(uv.x * 6.0, y * 3.0 - t * FLAME_SPEED * 0.5)) - 0.5;
    float warpY = noise(vec2(uv.x * 5.0 + 5.0, y * 2.5 - t * FLAME_SPEED * 0.4)) - 0.5;

    vec2 fireUV = vec2(
        uv.x * 4.5 + warpX * 0.5,
        y * 3.5 - t * FLAME_SPEED + warpY * 0.25
    );

    float smooth_ = fbm(fireUV);
    float sharp = turbulence(fireUV);
    float flame = mix(smooth_, sharp, 0.45);

    flame += mix(fbm(fireUV * 1.6 + vec2(3.3, t * 0.3)),
                 turbulence(fireUV * 1.6 + vec2(3.3, t * 0.3)), 0.3) * 0.3;

    flame = smoothstep(0.2, 0.85, flame);

    float topTaper = mix(1.0, smoothstep(1.0, 0.5, abs(uv.x - 0.5) * 2.0), clamp(y / FLAME_HEIGHT - 0.6, 0.0, 1.0));
    float widthMask = topTaper;

    float temperature = flame * vertFalloff * widthMask;

    float coreX = 1.0;
    float coreY = smoothstep(0.10, 0.0, y);
    temperature = max(temperature, coreX * coreY * 0.85);

    return clamp(temperature * FLAME_INTENSITY, 0.0, 1.0);
}

// --- Sparks ---
vec3 sparks(vec2 uv, float t)
{
    vec3 result = vec3(0, 0, 0);

    for (int layer = 0; layer < 2; layer++)
    {
        float layerF = float(layer);
        float flippedY = 1.0 - uv.y;

        vec2 cellUV = vec2(uv.x * (30.0 + layerF * 12.0), flippedY * 10.0);

        float col = floor(cellUV.x);
        cellUV.y += hash11(col * 3.7 + layerF * 11.0) * 50.0;

        vec2 cellId = floor(cellUV);
        vec2 cellFrac = fract(cellUV);

        float r = hash21(cellId + layerF * 23.0);
        if (r > SPARK_DENSITY)
            continue;

        vec2 props = hash22(cellId + layerF * 37.0);

        float sparkTime = t * SPARK_SPEED * (0.5 + props.y * 1.0)
                        + hash11(cellId.x + cellId.y * 5.0 + layerF) * 100.0;
        float sparkProgress = fract(sparkTime);

        float wobble = sin(sparkTime * 4.0 + props.x * 12.0) * 0.12;
        float sparkX = 0.3 + props.x * 0.4 + wobble;

        float life = smoothstep(0.0, 0.03, sparkProgress) * smoothstep(1.0, 0.5, sparkProgress);

        float originY = sparkProgress;
        if (originY < 0.0)
            continue;

        vec2 diff = cellFrac - vec2(sparkX, sparkProgress);
        float dist = length(diff);

        float size = 0.015 + props.x * 0.02;
        float spark = smoothstep(size, 0.0, dist) * life;

        if (spark > 0.01)
        {
            vec3 sparkCol = mix(vec3(1.0, 0.6, 0.1), vec3(1.0, 1.0, 0.8), spark);
            result += spark * sparkCol;
        }
    }

    return result;
}

// --- Floating embers/ash ---
vec3 embers(vec2 uv, float t)
{
    vec3 result = vec3(0, 0, 0);
    float flippedY = 1.0 - uv.y;

    vec2 cellUV = vec2(uv.x * 12.0, flippedY * 6.0);

    float col = floor(cellUV.x);
    cellUV.y += hash11(col * 5.3) * 30.0;

    vec2 cellId = floor(cellUV);
    vec2 cellFrac = fract(cellUV);

    float r = hash21(cellId * 1.53);
    if (r > EMBER_DENSITY)
        return result;

    vec2 props = hash22(cellId * 2.17);

    float emberTime = t * EMBER_SPEED * (0.4 + props.y * 0.8)
                    + hash11(cellId.x * 3.0 + cellId.y * 7.0) * 100.0;
    float emberProgress = fract(emberTime);

    float drift = sin(emberTime * 0.8 + props.x * 6.0) * 0.35
                + cos(emberTime * 0.5 + props.y * 4.0) * 0.2;
    float emberX = 0.15 + props.x * 0.7 + drift;

    float life = smoothstep(0.0, 0.15, emberProgress) * smoothstep(1.0, 0.6, emberProgress);

    vec2 diff = cellFrac - vec2(emberX, emberProgress);
    float dist = length(diff);

    float size = 0.03 + props.x * 0.04;
    float ember = smoothstep(size, size * 0.3, dist) * life;

    if (ember > 0.01)
    {
        float pulse = sin(t * 2.5 + props.y * 8.0) * 0.4 + 0.6;
        vec3 emberCol = vec3(0.8, 0.25, 0.03) * pulse;
        emberCol = mix(emberCol, vec3(0.9, 0.4, 0.05), props.x);
        result = ember * emberCol * 0.5;
    }

    return result;
}

// --- Heat haze ---
vec2 heatHaze(vec2 uv, float t)
{
    float y = 1.0 - uv.y;
    float hazeMask = smoothstep(FLAME_HEIGHT + 0.25, 0.02, y);

    vec2 haze;
    haze.x = noise(vec2(uv.x * 12.0, uv.y * 5.0 - t * 2.5)) - 0.5;
    haze.y = noise(vec2(uv.x * 10.0 + 3.0, uv.y * 6.0 - t * 3.0)) - 0.5;

    return haze * HEAT_HAZE * hazeMask;
}

// --- Main shader ---
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    uv.y = 1.0 - uv.y;  // Flip Y: HLSL y=0 at top, OpenGL y=0 at bottom
    float t = iTime;

    // Heat distortion
    vec2 hazeOffset = heatHaze(uv, t);
    vec2 hazedUV = clamp(uv + hazeOffset, 0.0, 1.0);
    vec4 color = texture(iChannel0, hazedUV);

    // Ambient warm glow from below
    float glowY = 1.0 - uv.y;
    float glow = pow(glowY, 2.5) * GLOW_STRENGTH;
    color.rgb += vec3(1.0, 0.45, 0.1) * glow;

    // Flames
    float temp = flameField(uv, t);
    if (temp > 0.01)
    {
        vec3 flameCol = fireColor(temp);
        color.rgb = mix(color.rgb, flameCol, temp * 0.92);
        color.rgb += flameCol * temp * 0.25;
    }

    // Sparks
    color.rgb += sparks(uv, t);

    // Embers
    color.rgb += embers(uv, t);

    // Global firelight flicker
    float flicker = noise(vec2(t * 9.0, 0.5)) * 0.07 + 0.96;
    color.rgb *= flicker;

    // Subtle vignette
    vec2 vig = uv * (1.0 - uv);
    float vigMask = clamp(pow(vig.x * vig.y * 15.0, 0.35), 0.0, 1.0);
    color.rgb *= 0.9 + vigMask * 0.1;

    fragColor = vec4(color.rgb, 1.0);
}
