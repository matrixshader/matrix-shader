// AURORA RAIN - Northern lights through a rain-streaked window
// Rain on glass with aurora-colored light catching the drops,
// background rain glowing green/teal/purple, lightning flashes.

#define DROP_DENSITY    0.25
#define DROP_SPEED      0.15
#define REFRACTION      0.012
#define TRAIL_FADE      0.65
#define GLASS_OPACITY   0.06
#define DROPLET_GLOW    0.6
#define BG_RAIN_DENSITY 0.4
#define BG_RAIN_SPEED   1.2
#define BG_RAIN_ALPHA   0.18
#define LIGHTNING_FREQ  0.025
#define AURORA_SPEED    0.08
#define AURORA_INTENSITY 0.3
#define CURTAIN_SCALE   2.5
#define WAVE_HEIGHT     0.5
#define STAR_DENSITY    0.025
#define COLOR_SHIFT     0.15

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
float3 auroraColor(float x, float t)
{
    float shift = x * 0.5 + t * COLOR_SHIFT;
    float3 green  = float3(0.1, 0.9, 0.3);
    float3 teal   = float3(0.1, 0.7, 0.7);
    float3 purple = float3(0.5, 0.15, 0.8);
    float3 pink   = float3(0.8, 0.2, 0.5);

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

// --- Aurora curtain ---
float auroraCurtain(float2 uv, float t, float seed)
{
    float x = uv.x * CURTAIN_SCALE + seed * 3.0;
    float fold = fbm(float2(x + t * AURORA_SPEED * 0.7, t * AURORA_SPEED * 0.3 + seed)) * 0.6
               + fbm(float2(x * 2.0 - t * AURORA_SPEED * 0.5, t * AURORA_SPEED * 0.2 + seed * 5.0)) * 0.3;

    float baseHeight = WAVE_HEIGHT + fold * 0.25;
    float verticalMask = smoothstep(baseHeight, 0.0, uv.y);

    float rayNoise = noise(float2(x * 4.0 + t * AURORA_SPEED * 0.4, seed * 11.0));
    float rays = smoothstep(0.4, 0.7, rayNoise) * 0.6;
    float shimmer = noise(float2(x * 8.0, t * 1.5 + seed * 7.0)) * 0.3 + 0.7;

    return verticalMask * (0.5 + rays) * shimmer;
}

// --- Combined aurora light at a point ---
float3 getAuroraLight(float2 uv, float t)
{
    float c1 = auroraCurtain(uv, t, 0.0);
    float c2 = auroraCurtain(uv, t * 0.9, 1.7);
    float3 col1 = auroraColor(uv.x, t) * c1;
    float3 col2 = auroraColor(uv.x + 0.5, t + 2.0) * c2;
    return (col1 + col2 * 0.6) * AURORA_INTENSITY;
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
        float twinkle = sin(t * 3.0 + hash11(cellId.x + cellId.y * 17.0) * 6.28) * 0.5 + 0.5;
        star = brightness * (0.3 + twinkle * 0.7);
    }
    return star;
}

// --- Raindrop on glass ---
float3 evalDrop(float2 cellId, float2 cellFrac, float layerSeed, float t)
{
    float3 result = float3(0, 0, 0);

    float dropRand = hash21(cellId + layerSeed * 31.0);
    if (dropRand > DROP_DENSITY)
        return result;

    float2 dropProps = hash22(cellId + layerSeed * 43.0);
    float dropSize = 0.08 + dropProps.x * 0.14;
    float dropSpeedVar = 0.6 + dropProps.y * 0.8;

    float dropTime = t * DROP_SPEED * dropSpeedVar + hash11(cellId.x + cellId.y * 7.0 + layerSeed) * 100.0;
    float dropY = frac(dropTime);
    float wobble = sin(dropTime * 2.5 + cellId.x * 4.0) * 0.06;

    float lifeFade = smoothstep(0.0, 0.08, dropY) * smoothstep(1.0, 0.88, dropY);

    float2 dropCenter = float2(0.2 + wobble + dropProps.x * 0.6, dropY);
    float2 diff = cellFrac - dropCenter;
    diff.y *= 0.45;
    float dist = length(diff);

    if (dist < dropSize)
    {
        float dropMask = smoothstep(dropSize, dropSize * 0.15, dist) * lifeFade;
        float2 normal = diff / max(dist, 0.001);
        float refrStrength = dropMask * REFRACTION * (1.0 - dist / dropSize);
        result.x = dropMask;
        result.yz = normal * refrStrength;
    }

    float trailDist = abs(cellFrac.x - dropCenter.x);
    float trailWidth = dropSize * 0.3;
    float trailMask = smoothstep(trailWidth, trailWidth * 0.1, trailDist);
    float aboveDrop = smoothstep(dropCenter.y, dropCenter.y + 0.5, cellFrac.y);
    float trailFade = aboveDrop * (1.0 - aboveDrop * TRAIL_FADE);
    float trail = trailMask * trailFade * 0.2;

    if (trail > result.x)
    {
        float trailRefr = trail * REFRACTION * 0.25;
        float2 trailNormal = float2(cellFrac.x - dropCenter.x, 0.15);
        trailNormal = normalize(trailNormal);
        result.x = max(result.x, trail);
        result.yz += trailNormal * trailRefr;
    }

    return result;
}

// --- Rain layer with neighbor blending ---
float3 rainLayer(float2 uv, float layerSeed, float t)
{
    float3 result = float3(0, 0, 0);
    float cellScale = 8.0 + layerSeed * 5.0;
    float2 cellUV = uv * float2(cellScale, cellScale * 3.0);

    float colId = floor(cellUV.x);
    cellUV.y += hash11(colId + layerSeed * 17.0) * 100.0;

    float2 cellId = floor(cellUV);
    float2 cellFrac = frac(cellUV);

    for (int dx = -1; dx <= 1; dx++)
    {
        for (int dy = -1; dy <= 1; dy++)
        {
            float2 neighborId = cellId + float2(dx, dy);
            float2 neighborFrac = cellFrac - float2(dx, dy);
            float3 drop = evalDrop(neighborId, neighborFrac, layerSeed, t);

            if (drop.x > result.x)
                result = drop;
            else if (drop.x > 0.01)
                result.yz += drop.yz * 0.3;
        }
    }
    return result;
}

// --- Mist ---
float mist(float2 uv)
{
    float2 mistUV = uv * 60.0;
    float2 cellId = floor(mistUV);
    float2 cellFrac = frac(mistUV);
    float r = hash21(cellId * 1.731);
    if (r < 0.06)
    {
        float2 pos = hash22(cellId * 2.371);
        float dist = length(cellFrac - pos);
        float size = 0.03 + r * 0.08;
        return smoothstep(size, size * 0.1, dist) * 0.1;
    }
    return 0.0;
}

// --- Background rain (aurora-colored) ---
float backgroundRain(float2 uv, float t)
{
    float rain = 0.0;

    for (int layer = 0; layer < 3; layer++)
    {
        float layerF = float(layer);
        float speed = BG_RAIN_SPEED * (0.7 + layerF * 0.4);
        float scale = 60.0 + layerF * 35.0;
        float alpha = BG_RAIN_ALPHA * (1.0 - layerF * 0.2);

        float windAngle = 0.12 + layerF * 0.06;
        float2 rainUV = float2(
            uv.x * scale + uv.y * windAngle * scale,
            uv.y * (8.0 + layerF * 4.0) - t * speed
        );

        rainUV.x += layerF * 37.7;
        rainUV.y += hash11(layerF * 5.5) * 200.0;

        float col = floor(rainUV.x);
        rainUV.y += hash11(col * 3.17 + layerF * 11.0) * 1.0;

        float2 cellId = floor(rainUV);
        float2 cellFrac = frac(rainUV);

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
    return saturate(rain);
}

// --- Lightning ---
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
            float localT = frac(t * rate);
            float f1 = exp(-localT * 22.0);
            float f2 = exp(-(localT - 0.08) * 35.0) * 0.4;
            flash = max(flash, saturate(f1 + f2));
        }
    }
    return flash;
}

// --- Main shader ---
float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float2 uv = tex;
    float t = Time;

    // Aurora light field (used to color everything)
    float3 aurora = getAuroraLight(uv, t);

    // Background rain
    float bgRain = backgroundRain(uv, t);

    // Surface rain
    float3 rain1 = rainLayer(uv, 0.0, t);
    float3 rain2 = rainLayer(uv, 1.0, t * 0.85);
    float3 rain3 = rainLayer(uv, 2.5, t * 1.15);

    float dropMask = saturate(rain1.x + rain2.x * 0.6 + rain3.x * 0.4);
    float2 refrOffset = rain1.yz + rain2.yz * 0.6 + rain3.yz * 0.4;

    float mistMask = mist(uv);
    dropMask = saturate(dropMask + mistMask);

    // Sample terminal texture
    float2 refrUV = clamp(uv + refrOffset, 0.0, 1.0);
    float4 terminalColor = shaderTexture.Sample(samplerState, refrUV);
    float4 clearColor = shaderTexture.Sample(samplerState, uv);

    float4 color = lerp(clearColor, terminalColor, saturate(dropMask * 3.0));

    // Glass tint — very subtle dark blue
    color.rgb = lerp(color.rgb, float3(0.05, 0.06, 0.12), GLASS_OPACITY);

    // Stars through the glass (faint, in dark areas)
    float starMask = stars(uv, t);
    float darkness = 1.0 - saturate(dot(color.rgb, float3(0.3, 0.6, 0.1)));
    color.rgb += starMask * float3(0.7, 0.75, 0.9) * 0.25 * darkness;

    // Aurora glow through the glass — the main atmosphere
    color.rgb += aurora;

    // Background rain colored by aurora
    float3 bgRainColor = lerp(float3(0.4, 0.5, 0.6), aurora * 2.0 + float3(0.3, 0.4, 0.5), 0.6);
    color.rgb += bgRain * bgRainColor;

    // Drop highlights — aurora light catching the water beads
    float highlight = dropMask * DROPLET_GLOW;
    float lightAngle = dot(normalize(refrOffset + 0.001), normalize(float2(-0.5, -0.8)));
    lightAngle = saturate(lightAngle);
    float specular = pow(lightAngle, 10.0) * highlight * 0.8;
    // Drops reflect aurora color, not just white
    float3 specColor = lerp(float3(0.7, 0.8, 1.0), aurora * 3.0 + float3(0.5, 0.5, 0.5), 0.5);
    color.rgb += specular * specColor;

    // Fresnel edge glow — tinted by aurora
    float edgeGlow = dropMask * (1.0 - dropMask) * 4.0;
    color.rgb += edgeGlow * (aurora * 0.5 + float3(0.1, 0.15, 0.2)) * 0.3;

    // Lightning
    float flash = lightning(t);
    if (flash > 0.01)
    {
        color.rgb = lerp(color.rgb, float3(0.85, 0.88, 1.0), flash * 0.5);
        color.rgb += dropMask * flash * float3(0.4, 0.45, 0.6) * 0.3;
        color.rgb += bgRain * flash * float3(0.5, 0.55, 0.7) * 0.4;
    }

    // Vignette
    float2 vig = uv * (1.0 - uv);
    float vigMask = saturate(pow(vig.x * vig.y * 15.0, 0.3));
    color.rgb *= vigMask;

    // Gutter
    float gutterY = 1.0 - uv.y;
    if (gutterY < 0.006)
    {
        float gutterWave = sin(uv.x * 50.0 + t * 1.5) * 0.5 + 0.5;
        float gutterMask = smoothstep(0.006, 0.0, gutterY) * 0.25;
        color.rgb += gutterMask * gutterWave * (aurora * 0.5 + float3(0.1, 0.12, 0.18));
    }

    color.a = 1.0;
    return color;
}
