// WHITE ROOM - CRT Construct picker shader (Ghostty / Shadertoy API)
// Original GLSL shader for the construct command's color picker.
// Bright white room with CRT aesthetics: scanlines, screen curvature,
// phosphor glow, and power-on/off animations.

// State machine defines (rewritten by construct script)
#define STATE 1         // 0=power-on, 1=picking, 2=power-off
#define SELECTED 0      // 0-5 for which color swatch is highlighted
#define STATE_TIME 0.0  // Time since last state transition

// --- Hash function ---
float hash21(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// --- CRT screen curvature ---
vec2 crtCurve(vec2 uv)
{
    uv = uv * 2.0 - 1.0;
    float curvature = 0.03;
    uv *= 1.0 + curvature * dot(uv, uv);
    return uv * 0.5 + 0.5;
}

// --- Scanlines ---
float scanlines(vec2 uv, float intensity)
{
    float scan = sin(uv.y * iResolution.y * 3.14159) * 0.5 + 0.5;
    return 1.0 - scan * intensity;
}

// --- CRT phosphor dot pattern ---
float phosphorDots(vec2 uv)
{
    vec2 dotUV = uv * iResolution.xy;
    float dotX = sin(dotUV.x * 3.14159 * 0.33) * 0.5 + 0.5;
    float dotY = sin(dotUV.y * 3.14159 * 0.5) * 0.5 + 0.5;
    return 0.95 + 0.05 * dotX * dotY;
}

// --- Static noise (subtle CRT noise) ---
float staticNoise(vec2 uv, float t)
{
    float n = hash21(uv * 500.0 + vec2(t * 7.3, t * 11.7));
    return n * 0.03;
}

// --- Vignette (CRT edge darkening) ---
float crtVignette(vec2 uv)
{
    vec2 d = (uv - 0.5) * 2.0;
    float dist = dot(d, d);
    return 1.0 - dist * 0.15;
}

// --- Power-on animation ---
// CRT warm-up: horizontal bright line expands to fill screen
vec3 powerOnEffect(vec2 uv, float t)
{
    // Phase 1: bright horizontal line appears (0-0.3s)
    // Phase 2: line expands vertically (0.3-0.8s)
    // Phase 3: full screen brightness settles (0.8-1.5s)

    float linePhase = smoothstep(0.0, 0.2, t);
    float expandPhase = smoothstep(0.3, 0.8, t);
    float settlePhase = smoothstep(0.8, 1.5, t);

    // Horizontal line
    float lineY = abs(uv.y - 0.5);
    float lineWidth = mix(0.002, 0.5, expandPhase);
    float line = smoothstep(lineWidth, lineWidth * 0.8, lineY) * linePhase;

    // Horizontal expansion
    float lineX = abs(uv.x - 0.5);
    float lineXWidth = mix(0.0, 0.5, smoothstep(0.0, 0.15, t));
    float lineH = smoothstep(lineXWidth + 0.01, lineXWidth, lineX);

    // Brightness bloom during power-on
    float bloom = exp(-lineY * lineY * 50.0) * (1.0 - expandPhase) * linePhase * 0.5;

    float intensity = line * lineH + bloom;

    // Color: bright blue-white during warm-up, settling to white
    vec3 warmColor = mix(vec3(0.7, 0.8, 1.0), vec3(0.92, 0.92, 0.9), settlePhase);

    return warmColor * intensity;
}

// --- Power-off animation ---
// CRT shutdown: screen shrinks to center bright dot then fades
vec3 powerOffEffect(vec2 uv, float t)
{
    // Phase 1: screen compresses vertically (0-0.3s)
    // Phase 2: shrinks to horizontal line (0.3-0.5s)
    // Phase 3: line shrinks to dot (0.5-0.7s)
    // Phase 4: dot fades out (0.7-1.0s)

    float compressPhase = smoothstep(0.0, 0.3, t);
    float linePhase = smoothstep(0.3, 0.5, t);
    float dotPhase = smoothstep(0.5, 0.7, t);
    float fadePhase = smoothstep(0.7, 1.0, t);

    vec2 center = uv - 0.5;

    // Vertical compression
    float vertScale = mix(1.0, 0.003, compressPhase);
    float vertMask = smoothstep(vertScale, vertScale * 0.8, abs(center.y));

    // Horizontal compression to dot
    float horizScale = mix(1.0, 0.003, linePhase);
    float horizMask = smoothstep(horizScale, horizScale * 0.8, abs(center.x));

    // Final dot
    float dotDist = length(center);
    float dotSize = mix(0.01, 0.0, dotPhase);
    float dot_ = smoothstep(dotSize + 0.005, dotSize, dotDist);

    float intensity;
    if (t < 0.3)
        intensity = vertMask;
    else if (t < 0.5)
        intensity = vertMask * horizMask;
    else
        intensity = dot_;

    intensity *= (1.0 - fadePhase);

    // Bright phosphor afterglow
    float afterglow = dot_ * exp(-t * 3.0) * 0.3;
    intensity += afterglow;

    return vec3(0.9, 0.92, 0.88) * intensity;
}

// --- Main shader ---
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 rawUV = fragCoord / iResolution.xy;
    float t = float(STATE_TIME);
    int state = STATE;

    vec3 color = vec3(0.0);

    if (state == 0) {
        // POWER-ON
        vec2 uv = crtCurve(rawUV);

        // Check if UV is outside CRT bounds
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            fragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }

        color = powerOnEffect(uv, t);

        // Apply CRT effects during later part of power-on
        float effectBlend = smoothstep(0.8, 1.5, t);
        float scan = scanlines(uv, 0.04 * effectBlend);
        color *= scan;
        color *= phosphorDots(uv);
        color *= crtVignette(uv);

    } else if (state == 1) {
        // PICKING - main white room state
        vec2 uv = crtCurve(rawUV);

        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            fragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }

        // Base white room color: warm off-white
        color = vec3(0.92, 0.92, 0.9);

        // Subtle gradient - slightly brighter at top
        color += vec3(0.03) * (1.0 - rawUV.y);

        // Very subtle noise for CRT texture
        color += staticNoise(uv, iTime) - 0.015;

        // Scanlines
        color *= scanlines(uv, 0.04);

        // Phosphor dot pattern
        color *= phosphorDots(uv);

        // CRT vignette
        color *= crtVignette(uv);

        // Subtle warm-pulse (CRT power supply ripple)
        float pulse = sin(iTime * 60.0 * 3.14159) * 0.003 + 1.0;
        color *= pulse;

        // Very subtle horizontal banding (rolling interference)
        float band = sin((uv.y + iTime * 0.03) * 40.0) * 0.008;
        color += vec3(band);

    } else {
        // POWER-OFF
        vec2 uv = crtCurve(rawUV);

        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            fragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }

        color = powerOffEffect(uv, t);

        // CRT effects fade out quickly
        float effectFade = 1.0 - smoothstep(0.0, 0.3, t);
        float scan = scanlines(uv, 0.04 * effectFade);
        color *= scan;
    }

    fragColor = vec4(color, 1.0);
}
