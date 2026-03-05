// RAIN ON GLASS - Atmospheric rain shader for Windows Terminal
// Simulates raindrops on a window with refraction and background rainfall.
// Terminal text shows through the glass, distorted by water.

#define DROP_DENSITY    0.25    // How many drops (0.05 = sparse, 0.5 = downpour)
#define DROP_SPEED      0.15    // Fall speed of drops on glass
#define REFRACTION      0.012   // How much drops bend the text behind them
#define TRAIL_FADE      0.65    // How fast wet trails dry (0 = instant, 1 = slow)
#define GLASS_TINT_R    0.12    // Glass color tint
#define GLASS_TINT_G    0.15
#define GLASS_TINT_B    0.22
#define GLASS_OPACITY   0.10    // How tinted the glass is (0 = clear, 0.3 = heavy)
#define LIGHTNING_FREQ  0.025   // Chance of lightning per cycle (lower = rarer)
#define DROPLET_GLOW    0.5     // Brightness of light catching drops
#define BG_RAIN_DENSITY 0.4     // Background rain density
#define BG_RAIN_SPEED   1.2     // Background rain fall speed (faster than surface drops)
#define BG_RAIN_ALPHA   0.18    // How visible background rain is

Texture2D shaderTexture;
SamplerState samplerState;
cbuffer PixelShaderSettings { float Time; float Scale; float2 Resolution; float4 Background; };

// --- Hash functions (sine-free for GPU portability) ---

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

// --- Smooth noise ---
float noise(float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0); // quintic smoothstep

    return lerp(lerp(hash21(i + float2(0, 0)), hash21(i + float2(1, 0)), u.x),
                lerp(hash21(i + float2(0, 1)), hash21(i + float2(1, 1)), u.x), u.y);
}

// --- Single raindrop evaluated at a point ---
// Checks one cell and returns: x = drop intensity, yz = refraction offset
float3 evalDrop(float2 cellId, float2 cellFrac, float layerSeed, float t, float cellScale)
{
    float3 result = float3(0, 0, 0);

    // Per-cell random: does this cell have a drop?
    float dropRand = hash21(cellId + layerSeed * 31.0);
    if (dropRand > DROP_DENSITY)
        return result;

    // Drop properties
    float2 dropProps = hash22(cellId + layerSeed * 43.0);
    float dropSize = 0.08 + dropProps.x * 0.14;   // Much smaller drops
    float dropSpeedVar = 0.6 + dropProps.y * 0.8;

    // Drop position: wobbles as it falls
    float dropTime = t * DROP_SPEED * dropSpeedVar + hash11(cellId.x + cellId.y * 7.0 + layerSeed) * 100.0;
    float dropY = frac(dropTime);
    float wobble = sin(dropTime * 2.5 + cellId.x * 4.0) * 0.06;

    // Fade drop in/out at cell boundaries so the cycle reset is invisible
    float lifeFade = smoothstep(0.0, 0.08, dropY) * smoothstep(1.0, 0.88, dropY);

    float2 dropCenter = float2(0.2 + wobble + dropProps.x * 0.6, dropY);

    // Distance from pixel to drop center
    float2 diff = cellFrac - dropCenter;
    diff.y *= 0.45; // Elongate vertically (teardrop shape)
    float dist = length(diff);

    // Main drop body — smooth falloff, no hard edges
    if (dist < dropSize)
    {
        float dropMask = smoothstep(dropSize, dropSize * 0.15, dist) * lifeFade;
        float2 normal = diff / max(dist, 0.001);
        float refrStrength = dropMask * REFRACTION * (1.0 - dist / dropSize);

        result.x = dropMask;
        result.yz = normal * refrStrength;
    }

    // Wet trail above the drop
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

// --- Rain layer with neighbor blending (eliminates grid artifacts) ---
float3 rainLayer(float2 uv, float layerSeed, float t)
{
    float3 result = float3(0, 0, 0);

    float cellScale = 8.0 + layerSeed * 5.0; // More cells = smaller drops
    float2 cellUV = uv * float2(cellScale, cellScale * 3.0);

    // Stagger columns for organic feel
    float colId = floor(cellUV.x);
    cellUV.y += hash11(colId + layerSeed * 17.0) * 100.0;

    float2 cellId = floor(cellUV);
    float2 cellFrac = frac(cellUV);

    // Sample current cell AND all 8 neighbors to eliminate grid seams
    for (int dx = -1; dx <= 1; dx++)
    {
        for (int dy = -1; dy <= 1; dy++)
        {
            float2 neighborId = cellId + float2(dx, dy);
            float2 neighborFrac = cellFrac - float2(dx, dy);

            float3 drop = evalDrop(neighborId, neighborFrac, layerSeed, t, cellScale);

            // Accumulate: take the strongest drop presence, blend refractions
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
float mist(float2 uv)
{
    float m = 0.0;
    float2 mistUV = uv * 60.0;
    float2 cellId = floor(mistUV);
    float2 cellFrac = frac(mistUV);

    float r = hash21(cellId * 1.731);
    if (r < 0.06)
    {
        float2 pos = hash22(cellId * 2.371);
        float dist = length(cellFrac - pos);
        float size = 0.03 + r * 0.08;
        m = smoothstep(size, size * 0.1, dist) * 0.1;
    }
    return m;
}

// --- Background rain (falling behind the glass, not on it) ---
float backgroundRain(float2 uv, float t)
{
    float rain = 0.0;

    // Multiple layers at different speeds/scales for depth
    for (int layer = 0; layer < 3; layer++)
    {
        float layerF = float(layer);
        float speed = BG_RAIN_SPEED * (0.7 + layerF * 0.4);
        float scale = 60.0 + layerF * 35.0;
        float alpha = BG_RAIN_ALPHA * (1.0 - layerF * 0.2);

        // Wind angle — each layer drifts slightly differently
        float windAngle = 0.12 + layerF * 0.06; // slight diagonal, not straight down

        // Shear UV to create angled rain
        float2 rainUV = float2(
            uv.x * scale + uv.y * windAngle * scale,
            uv.y * (8.0 + layerF * 4.0) - t * speed
        );

        // Offset each layer differently
        rainUV.x += layerF * 37.7;
        rainUV.y += hash11(layerF * 5.5) * 200.0;

        // Stagger each column's Y so cell boundaries don't align horizontally
        float col = floor(rainUV.x);
        rainUV.y += hash11(col * 3.17 + layerF * 11.0) * 1.0;

        float2 cellId = floor(rainUV);
        float2 cellFrac = frac(rainUV);

        // Each cell may have a rain streak
        float r = hash21(cellId + layerF * 19.0);
        if (r < BG_RAIN_DENSITY)
        {
            // Horizontal position within cell — randomized per streak
            float xPos = hash11(cellId.x + cellId.y * 3.1 + layerF * 7.0);
            float xDist = abs(cellFrac.x - xPos);

            // Varying thickness per streak (some thin, some thicker)
            float streakRand = hash11(cellId.x * 7.7 + cellId.y * 3.3 + layerF);
            float thickness = 0.01 + streakRand * 0.06;
            float streak = smoothstep(thickness, thickness * 0.15, xDist);

            // Varying length — some short splashes, some long streaks
            float lengthVar = 0.3 + hash11(cellId.x * 11.0 + cellId.y * 2.0) * 0.7;
            float yStart = (1.0 - lengthVar) * 0.5; // center the streak in its cell
            float yEnd = yStart + lengthVar;
            float yFade = smoothstep(yStart, yStart + 0.08, cellFrac.y)
                        * smoothstep(yEnd, yEnd - 0.08, cellFrac.y);

            // Brightness variation (some faint, some bright)
            float brightness = 0.4 + streakRand * 0.6;

            rain += streak * yFade * alpha * brightness;
        }
    }

    return saturate(rain);
}

// --- Lightning flash (rare, unpredictable) ---
float lightning(float t)
{
    // Multiple overlapping time windows with different hash seeds
    // This makes flashes feel random rather than periodic
    float flash = 0.0;

    // Check several "channels" — each fires independently
    for (int ch = 0; ch < 3; ch++)
    {
        float chF = float(ch);
        float rate = 0.3 + chF * 0.17;  // Each channel ticks at different rate
        float sec = floor(t * rate);
        float chance = hash11(sec * (13.37 + chF * 7.13));

        if (chance < LIGHTNING_FREQ)
        {
            float localT = frac(t * rate);
            // Quick bright flash + dimmer afterflash
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

    // --- Background rain (behind the glass) ---
    float bgRain = backgroundRain(uv, t);

    // --- Surface rain (on the glass) ---
    float3 rain1 = rainLayer(uv, 0.0, t);
    float3 rain2 = rainLayer(uv, 1.0, t * 0.85);
    float3 rain3 = rainLayer(uv, 2.5, t * 1.15);

    // Combine surface layers
    float dropMask = saturate(rain1.x + rain2.x * 0.6 + rain3.x * 0.4);
    float2 refrOffset = rain1.yz + rain2.yz * 0.6 + rain3.yz * 0.4;

    // Add mist
    float mistMask = mist(uv);
    dropMask = saturate(dropMask + mistMask);

    // --- Sample terminal texture ---
    float2 refrUV = clamp(uv + refrOffset, 0.0, 1.0);
    float4 terminalColor = shaderTexture.Sample(samplerState, refrUV);
    float4 clearColor = shaderTexture.Sample(samplerState, uv);

    // Blend: refracted where drops are, clear elsewhere
    float4 color = lerp(clearColor, terminalColor, saturate(dropMask * 3.0));

    // --- Glass tint ---
    float3 glassTint = float3(GLASS_TINT_R, GLASS_TINT_G, GLASS_TINT_B);
    color.rgb = lerp(color.rgb, glassTint, GLASS_OPACITY);

    // --- Background rain visible through glass ---
    float3 bgRainColor = float3(0.5, 0.6, 0.75); // Pale blue-grey streaks
    color.rgb += bgRain * bgRainColor;

    // --- Drop highlights (light catching water beads) ---
    float highlight = dropMask * DROPLET_GLOW;
    float lightAngle = dot(normalize(refrOffset + 0.001), normalize(float2(-0.5, -0.8)));
    lightAngle = saturate(lightAngle);
    float specular = pow(lightAngle, 10.0) * highlight * 0.7;
    color.rgb += specular * float3(0.7, 0.8, 1.0);

    // Fresnel-like edge glow on drops
    float edgeGlow = dropMask * (1.0 - dropMask) * 4.0;
    color.rgb += edgeGlow * float3(0.15, 0.2, 0.3) * 0.25;

    // --- Lightning ---
    float flash = lightning(t);
    if (flash > 0.01)
    {
        color.rgb = lerp(color.rgb, float3(0.85, 0.88, 1.0), flash * 0.6);
        color.rgb += dropMask * flash * float3(0.4, 0.45, 0.6) * 0.35;
        // Background rain also catches the flash
        color.rgb += bgRain * flash * float3(0.5, 0.55, 0.7) * 0.5;
    }

    // --- Subtle vignette (window frame feel) ---
    float2 vig = uv * (1.0 - uv);
    float vigMask = saturate(pow(vig.x * vig.y * 15.0, 0.3));
    color.rgb *= vigMask;

    // --- Gutter water at bottom ---
    float gutterY = 1.0 - uv.y;
    if (gutterY < 0.006)
    {
        float gutterWave = sin(uv.x * 50.0 + t * 1.5) * 0.5 + 0.5;
        float gutterMask = smoothstep(0.006, 0.0, gutterY) * 0.25;
        color.rgb += gutterMask * gutterWave * float3(0.15, 0.2, 0.3);
    }

    color.a = 1.0;
    return color;
}
