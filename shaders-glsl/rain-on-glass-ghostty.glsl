// RAIN ON GLASS - Atmospheric rain shader (Ghostty / Shadertoy API)
// Ported from RainOnGlass.hlsl for Ghostty
// Simulates raindrops on a window with refraction and background rainfall.

#define DROP_DENSITY    0.25
#define DROP_SPEED      0.15
#define REFRACTION      0.012
#define TRAIL_FADE      0.65
#define GLASS_TINT_R    0.12
#define GLASS_TINT_G    0.15
#define GLASS_TINT_B    0.22
#define GLASS_OPACITY   0.10
#define LIGHTNING_FREQ  0.025
#define DROPLET_GLOW    0.5
#define BG_RAIN_DENSITY 0.4
#define BG_RAIN_SPEED   1.2
#define BG_RAIN_ALPHA   0.18

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

// --- Single raindrop evaluated at a point ---
vec3 evalDrop(vec2 cellId, vec2 cellFrac, float layerSeed, float t, float cellScale)
{
    vec3 result = vec3(0, 0, 0);

    float dropRand = hash21(cellId + layerSeed * 31.0);
    if (dropRand > DROP_DENSITY)
        return result;

    vec2 dropProps = hash22(cellId + layerSeed * 43.0);
    float dropSize = 0.08 + dropProps.x * 0.14;
    float dropSpeedVar = 0.6 + dropProps.y * 0.8;

    float dropTime = t * DROP_SPEED * dropSpeedVar + hash11(cellId.x + cellId.y * 7.0 + layerSeed) * 100.0;
    float dropY = fract(dropTime);
    float wobble = sin(dropTime * 2.5 + cellId.x * 4.0) * 0.06;

    float lifeFade = smoothstep(0.0, 0.08, dropY) * smoothstep(1.0, 0.88, dropY);

    vec2 dropCenter = vec2(0.2 + wobble + dropProps.x * 0.6, dropY);

    vec2 diff = cellFrac - dropCenter;
    diff.y *= 0.45;
    float dist = length(diff);

    if (dist < dropSize)
    {
        float dropMask = smoothstep(dropSize, dropSize * 0.15, dist) * lifeFade;
        vec2 normal = diff / max(dist, 0.001);
        float refrStrength = dropMask * REFRACTION * (1.0 - dist / dropSize);

        result.x = dropMask;
        result.yz = normal * refrStrength;
    }

    float trailDist = abs(cellFrac.x - dropCenter.x);
    float trailWidth = dropSize * 0.3;
    float trailMask = smoothstep(trailWidth, trailWidth * 0.1, trailDist);
    float aboveDrop = smoothstep(dropCenter.y, dropCenter.y + 0.5, cellFrac.y);
    float trailFade_ = aboveDrop * (1.0 - aboveDrop * TRAIL_FADE);
    float trail = trailMask * trailFade_ * 0.2;

    if (trail > result.x)
    {
        float trailRefr = trail * REFRACTION * 0.25;
        vec2 trailNormal = vec2(cellFrac.x - dropCenter.x, 0.15);
        trailNormal = normalize(trailNormal);
        result.x = max(result.x, trail);
        result.yz += trailNormal * trailRefr;
    }

    return result;
}

// --- Rain layer with neighbor blending ---
vec3 rainLayer(vec2 uv, float layerSeed, float t)
{
    vec3 result = vec3(0, 0, 0);

    float cellScale = 8.0 + layerSeed * 5.0;
    vec2 cellUV = uv * vec2(cellScale, cellScale * 3.0);

    float colId = floor(cellUV.x);
    cellUV.y += hash11(colId + layerSeed * 17.0) * 100.0;

    vec2 cellId = floor(cellUV);
    vec2 cellFrac = fract(cellUV);

    for (int dx = -1; dx <= 1; dx++)
    {
        for (int dy = -1; dy <= 1; dy++)
        {
            vec2 neighborId = cellId + vec2(float(dx), float(dy));
            vec2 neighborFrac = cellFrac - vec2(float(dx), float(dy));

            vec3 drop = evalDrop(neighborId, neighborFrac, layerSeed, t, cellScale);

            if (drop.x > result.x)
            {
                result = drop;
            }
            else if (drop.x > 0.01)
            {
                result.yz += drop.yz * 0.3;
            }
        }
    }

    return result;
}

// --- Tiny static mist droplets on glass ---
float mist(vec2 uv)
{
    float m = 0.0;
    vec2 mistUV = uv * 60.0;
    vec2 cellId = floor(mistUV);
    vec2 cellFrac = fract(mistUV);

    float r = hash21(cellId * 1.731);
    if (r < 0.06)
    {
        vec2 pos = hash22(cellId * 2.371);
        float dist = length(cellFrac - pos);
        float size = 0.03 + r * 0.08;
        m = smoothstep(size, size * 0.1, dist) * 0.1;
    }
    return m;
}

// --- Background rain ---
float backgroundRain(vec2 uv, float t)
{
    float rain = 0.0;

    for (int layer = 0; layer < 3; layer++)
    {
        float layerF = float(layer);
        float speed = BG_RAIN_SPEED * (0.7 + layerF * 0.4);
        float scale = 60.0 + layerF * 35.0;
        float alpha = BG_RAIN_ALPHA * (1.0 - layerF * 0.2);

        float windAngle = 0.12 + layerF * 0.06;

        vec2 rainUV = vec2(
            uv.x * scale + uv.y * windAngle * scale,
            uv.y * (8.0 + layerF * 4.0) - t * speed
        );

        rainUV.x += layerF * 37.7;
        rainUV.y += hash11(layerF * 5.5) * 200.0;

        float col = floor(rainUV.x);
        rainUV.y += hash11(col * 3.17 + layerF * 11.0) * 1.0;

        vec2 cellId = floor(rainUV);
        vec2 cellFrac = fract(rainUV);

        float r = hash21(cellId + layerF * 19.0);
        if (r < BG_RAIN_DENSITY)
        {
            float xPos = hash11(cellId.x + cellId.y * 3.1 + layerF * 7.0);
            float xDist = abs(cellFrac.x - xPos);

            float streakRand = hash11(cellId.x * 7.7 + cellId.y * 3.3 + layerF);
            float thickness = 0.01 + streakRand * 0.06;
            float streak = smoothstep(thickness, thickness * 0.15, xDist);

            float lengthVar = 0.3 + hash11(cellId.x * 11.0 + cellId.y * 2.0) * 0.7;
            float yStart = (1.0 - lengthVar) * 0.5;
            float yEnd = yStart + lengthVar;
            float yFade = smoothstep(yStart, yStart + 0.08, cellFrac.y)
                        * smoothstep(yEnd, yEnd - 0.08, cellFrac.y);

            float brightness = 0.4 + streakRand * 0.6;

            rain += streak * yFade * alpha * brightness;
        }
    }

    return clamp(rain, 0.0, 1.0);
}

// --- Lightning flash ---
float lightning(float t)
{
    float flash = 0.0;

    for (int ch = 0; ch < 3; ch++)
    {
        float chF = float(ch);
        float rate = 0.3 + chF * 0.17;
        float sec = floor(t * rate);
        float chance = hash11(sec * (13.37 + chF * 7.13));

        if (chance < LIGHTNING_FREQ)
        {
            float localT = fract(t * rate);
            float f1 = exp(-localT * 22.0);
            float f2 = exp(-(localT - 0.08) * 35.0) * 0.4;
            flash = max(flash, clamp(f1 + f2, 0.0, 1.0));
        }
    }

    return flash;
}

// --- Main shader ---
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    uv.y = 1.0 - uv.y;  // Flip Y: HLSL y=0 at top, OpenGL y=0 at bottom
    float t = iTime;

    // Background rain
    float bgRain = backgroundRain(uv, t);

    // Surface rain
    vec3 rain1 = rainLayer(uv, 0.0, t);
    vec3 rain2 = rainLayer(uv, 1.0, t * 0.85);
    vec3 rain3 = rainLayer(uv, 2.5, t * 1.15);

    float dropMask = clamp(rain1.x + rain2.x * 0.6 + rain3.x * 0.4, 0.0, 1.0);
    vec2 refrOffset = rain1.yz + rain2.yz * 0.6 + rain3.yz * 0.4;

    float mistMask = mist(uv);
    dropMask = clamp(dropMask + mistMask, 0.0, 1.0);

    // Sample terminal texture
    vec2 refrUV = clamp(uv + refrOffset, 0.0, 1.0);
    vec4 terminalColor = texture(iChannel0, refrUV);
    vec4 clearColor = texture(iChannel0, uv);

    vec4 color = mix(clearColor, terminalColor, clamp(dropMask * 3.0, 0.0, 1.0));

    // Glass tint
    vec3 glassTint = vec3(GLASS_TINT_R, GLASS_TINT_G, GLASS_TINT_B);
    color.rgb = mix(color.rgb, glassTint, GLASS_OPACITY);

    // Background rain visible through glass
    vec3 bgRainColor = vec3(0.5, 0.6, 0.75);
    color.rgb += bgRain * bgRainColor;

    // Drop highlights
    float highlight = dropMask * DROPLET_GLOW;
    float lightAngle = dot(normalize(refrOffset + 0.001), normalize(vec2(-0.5, -0.8)));
    lightAngle = clamp(lightAngle, 0.0, 1.0);
    float specular = pow(lightAngle, 10.0) * highlight * 0.7;
    color.rgb += specular * vec3(0.7, 0.8, 1.0);

    // Fresnel-like edge glow on drops
    float edgeGlow = dropMask * (1.0 - dropMask) * 4.0;
    color.rgb += edgeGlow * vec3(0.15, 0.2, 0.3) * 0.25;

    // Lightning
    float flash = lightning(t);
    if (flash > 0.01)
    {
        color.rgb = mix(color.rgb, vec3(0.85, 0.88, 1.0), flash * 0.6);
        color.rgb += dropMask * flash * vec3(0.4, 0.45, 0.6) * 0.35;
        color.rgb += bgRain * flash * vec3(0.5, 0.55, 0.7) * 0.5;
    }

    // Subtle vignette
    vec2 vig = uv * (1.0 - uv);
    float vigMask = clamp(pow(vig.x * vig.y * 15.0, 0.3), 0.0, 1.0);
    color.rgb *= vigMask;

    // Gutter water at bottom
    float gutterY = 1.0 - uv.y;
    if (gutterY < 0.006)
    {
        float gutterWave = sin(uv.x * 50.0 + t * 1.5) * 0.5 + 0.5;
        float gutterMask = smoothstep(0.006, 0.0, gutterY) * 0.25;
        color.rgb += gutterMask * gutterWave * vec3(0.15, 0.2, 0.3);
    }

    fragColor = vec4(color.rgb, 1.0);
}
