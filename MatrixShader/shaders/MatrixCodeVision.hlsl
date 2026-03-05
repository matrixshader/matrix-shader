// MatrixCodeVision.hlsl - Digital code city flythrough
// 3D buildings with depth: front faces, alley side walls, rooftops, back walls.
// Flying through streets of a neon city where every surface is scrolling code.

Texture2D shaderTexture;
SamplerState samplerState;
cbuffer PixelShaderSettings { float Time; float Scale; float2 Resolution; float4 Background; };

#define HALF_STREET  3.5
#define CAM_H        1.5
#define BLOCK_SIZE   10.0
#define BLDG_FRAC    0.72
#define BLDG_DEPTH   4.5
#define MIN_BH       5.0
#define MAX_BH       16.0
#define CAM_SPEED    3.0
#define STRAIGHT_LEN 22.0
#define TURN_LEN     2.5
#define SEG_LEN      (STRAIGHT_LEN + TURN_LEN)
#define CODE_SPEED   7.0
#define FOG_DENSITY  0.015
#define MAX_DIST     80.0
#define FOV          1.5
#define PAD          0.18
#define PI           3.14159265

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

float hash(float2 p) { return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }
float hash1(float n) { return frac(sin(n * 73.19) * 43758.5453); }

float getGlyph(int idx, float2 uv) {
    idx = idx & 15;
    int px = clamp(int(uv.x * 5.0), 0, 4);
    int py = clamp(int(uv.y * 7.0), 0, 6);
    return float((GLYPHS[idx] >> (py * 5 + px)) & 1u);
}

// NOTE: cid.y + Time (not minus) so code falls DOWN on walls where uv.y = 0 at floor
float3 codeLayer(float2 uv, float cols, float rows, float spd, float brt, float dens,
                 float seed, float3 tint) {
    float2 grid = uv * float2(cols, rows);
    float2 cid = floor(grid);
    float2 luv = frac(grid);
    float cr = hash(float2(cid.x + seed, seed));
    if (cr > dens) return float3(0, 0, 0);
    float colH = frac(sin(cid.x * 127.1 + seed * 311.7) * 43758.5453);
    float sp = (cr * 0.5 + 0.3) * CODE_SPEED * spd;
    float rp = cid.y + Time * sp + colH * rows * 2.5;
    float cyc = 1.0 - frac(rp / rows * 1.5);
    float trail = pow(cyc, 7.0);
    float cs = hash(cid + floor(Time * 3.5) + seed);
    float2 pd = (luv - PAD) / (1.0 - 2.0 * PAD);
    pd = clamp(pd, 0.0, 1.0);
    float g = getGlyph(int(cs * 16.0), pd);
    float brd = step(PAD, luv.x) * step(luv.x, 1.0 - PAD) * step(PAD * 0.5, luv.y) * step(luv.y, 1.0 - PAD * 0.5);
    float head = step(0.95, cyc);
    return lerp(tint, float3(0.9, 1.0, 0.9), head) * trail * g * brd * brt;
}

float3 getPreset(int idx, int layer) {
    int p = idx % 6;
    float3 f1, m1, n1;
    // Order matches ColorPresets.cs: Green, Blue, Red, Purple, Gold, Teal
    if (p == 0)      { f1 = float3(0.05, 0.4, 0.15);  m1 = float3(0.0, 1.0, 0.3);   n1 = float3(0.1, 1.0, 0.4);   } // Green
    else if (p == 1) { f1 = float3(0.05, 0.25, 0.5);  m1 = float3(0.0, 0.6, 1.0);   n1 = float3(0.3, 0.7, 1.0);   } // Blue
    else if (p == 2) { f1 = float3(0.5, 0.08, 0.08);  m1 = float3(1.0, 0.1, 0.1);   n1 = float3(1.0, 0.3, 0.2);   } // Red
    else if (p == 3) { f1 = float3(0.3, 0.05, 0.5);   m1 = float3(0.7, 0.0, 1.0);   n1 = float3(0.8, 0.3, 1.0);   } // Purple
    else if (p == 4) { f1 = float3(0.5, 0.3, 0.05);   m1 = float3(1.0, 0.7, 0.0);   n1 = float3(1.0, 0.8, 0.15);  } // Gold
    else             { f1 = float3(0.05, 0.4, 0.4);   m1 = float3(0.0, 0.9, 0.9);   n1 = float3(0.15, 1.0, 1.0);  } // Teal
    if (layer == 0) return f1;
    if (layer == 1) return m1;
    return n1;
}

float3 renderCode(float2 uv, float seed, int preset) {
    float3 c = codeLayer(uv, 55, 80, 0.5, 0.28, 0.65, seed,        getPreset(preset, 0));
    c +=       codeLayer(uv, 42, 60, 1.0, 0.65, 0.55, seed + 7.0,  getPreset(preset, 1));
    c +=       codeLayer(uv, 30, 42, 1.6, 1.10, 0.42, seed + 17.0, getPreset(preset, 2));
    return c;
}

// Background rain streaks (screen-space, like RainOnGlass)
float bgRain(float2 uv, float t) {
    float rain = 0.0;
    for (int layer = 0; layer < 3; layer++) {
        float lf = float(layer);
        float speed = 1.0 + lf * 0.5;
        float scale = 50.0 + lf * 30.0;
        float windAngle = 0.1 + lf * 0.05;
        float2 ruv = float2(uv.x * scale + uv.y * windAngle * scale,
                            uv.y * (7.0 + lf * 3.0) - t * speed);
        ruv.x += lf * 37.7;
        ruv.y += hash1(lf * 5.5) * 200.0;
        float col = floor(ruv.x);
        ruv.y += hash1(col * 3.17 + lf * 11.0);
        float2 cid = floor(ruv);
        float2 cf = frac(ruv);
        float r = hash(cid + lf * 19.0);
        if (r < 0.35) {
            float xPos = hash1(cid.x + cid.y * 3.1 + lf * 7.0);
            float xDist = abs(cf.x - xPos);
            float thick = 0.01 + hash1(cid.x * 7.7 + cid.y * 3.3 + lf) * 0.04;
            float streak = smoothstep(thick, thick * 0.15, xDist);
            float lenVar = 0.3 + hash1(cid.x * 11.0 + cid.y * 2.0) * 0.7;
            float ys = (1.0 - lenVar) * 0.5;
            float ye = ys + lenVar;
            float yFade = smoothstep(ys, ys + 0.08, cf.y) * smoothstep(ye, ye - 0.08, cf.y);
            float brt = 0.4 + hash1(cid.x * 2.2 + cid.y) * 0.6;
            rain += streak * yFade * brt * (0.15 - lf * 0.03);
        }
    }
    return saturate(rain);
}

float getBH(float wz, float side) {
    float bi = floor(wz / BLOCK_SIZE);
    return MIN_BH + hash(float2(bi + side * 97.0, side + 37.0)) * (MAX_BH - MIN_BH);
}

bool inAlley(float wz) {
    float phase = frac(wz / BLOCK_SIZE);
    if (phase < 0.0) phase += 1.0;
    return phase > BLDG_FRAC;
}

// Hit types: 0=left front, 1=right front, 2=left side, 3=right side,
//            4=floor, 5=left top, 6=right top, 7=left back, 8=right back
bool castCity(float3 ro, float3 rd, float scrollZ, out float tHit, out int face, out float3 hp) {
    tHit = MAX_DIST; face = -1; hp = float3(0, 0, 0);
    float tt; float3 p;

    // Floor
    if (rd.y < -1e-4) {
        tt = (-CAM_H - ro.y) / rd.y;
        if (tt > 0.001 && tt < tHit) { tHit = tt; face = 4; hp = ro + rd * tt; }
    }

    // === LEFT SIDE ===
    // Front face (x = -HALF_STREET)
    if (rd.x < -1e-4) {
        tt = (-HALF_STREET - ro.x) / rd.x;
        if (tt > 0.001 && tt < tHit) {
            p = ro + rd * tt;
            float wz = p.z + scrollZ;
            if (!inAlley(wz) && p.y > -CAM_H && p.y < getBH(wz, 0.0) - CAM_H)
            { tHit = tt; face = 0; hp = p; }
        }
        // Back face (x = -(HALF_STREET + BLDG_DEPTH)) — visible through alleys
        tt = (-(HALF_STREET + BLDG_DEPTH) - ro.x) / rd.x;
        if (tt > 0.001 && tt < tHit) {
            p = ro + rd * tt;
            float wz = p.z + scrollZ;
            if (!inAlley(wz) && p.y > -CAM_H && p.y < getBH(wz, 0.0) - CAM_H)
            { tHit = tt; face = 7; hp = p; }
        }
    }

    // === RIGHT SIDE ===
    if (rd.x > 1e-4) {
        tt = (HALF_STREET - ro.x) / rd.x;
        if (tt > 0.001 && tt < tHit) {
            p = ro + rd * tt;
            float wz = p.z + scrollZ;
            if (!inAlley(wz) && p.y > -CAM_H && p.y < getBH(wz, 1.0) - CAM_H)
            { tHit = tt; face = 1; hp = p; }
        }
        tt = ((HALF_STREET + BLDG_DEPTH) - ro.x) / rd.x;
        if (tt > 0.001 && tt < tHit) {
            p = ro + rd * tt;
            float wz = p.z + scrollZ;
            if (!inAlley(wz) && p.y > -CAM_H && p.y < getBH(wz, 1.0) - CAM_H)
            { tHit = tt; face = 8; hp = p; }
        }
    }

    // === ALLEY SIDE WALLS (Z-planes at block boundaries) ===
    float camWZ = scrollZ;
    float firstBI = floor(camWZ / BLOCK_SIZE);
    [loop] for (int ab = -1; ab < 6; ab++) {
        float blockWZ = (firstBI + float(ab)) * BLOCK_SIZE;
        float bldgEndWZ = blockWZ + BLDG_FRAC * BLOCK_SIZE;
        float nextStartWZ = blockWZ + BLOCK_SIZE;

        // Building end face (entering alley)
        float ez = bldgEndWZ - scrollZ;
        if (abs(rd.z) > 1e-4) {
            tt = (ez - ro.z) / rd.z;
            if (tt > 0.001 && tt < tHit) {
                p = ro + rd * tt;
                float bh = getBH(bldgEndWZ - 0.1, 0.0);
                if (p.x < -HALF_STREET && p.x > -(HALF_STREET + BLDG_DEPTH) && p.y > -CAM_H && p.y < bh - CAM_H)
                { tHit = tt; face = 2; hp = p; }
                bh = getBH(bldgEndWZ - 0.1, 1.0);
                if (p.x > HALF_STREET && p.x < (HALF_STREET + BLDG_DEPTH) && p.y > -CAM_H && p.y < bh - CAM_H)
                { tHit = tt; face = 3; hp = p; }
            }
            // Next building start face (exiting alley)
            float sz = nextStartWZ - scrollZ;
            tt = (sz - ro.z) / rd.z;
            if (tt > 0.001 && tt < tHit) {
                p = ro + rd * tt;
                float bh = getBH(nextStartWZ + 0.1, 0.0);
                if (p.x < -HALF_STREET && p.x > -(HALF_STREET + BLDG_DEPTH) && p.y > -CAM_H && p.y < bh - CAM_H)
                { tHit = tt; face = 2; hp = p; }
                bh = getBH(nextStartWZ + 0.1, 1.0);
                if (p.x > HALF_STREET && p.x < (HALF_STREET + BLDG_DEPTH) && p.y > -CAM_H && p.y < bh - CAM_H)
                { tHit = tt; face = 3; hp = p; }
            }
        }
    }

    // === BUILDING TOPS (y-planes at building height) ===
    if (rd.y > 1e-4) {
        [loop] for (int bt = 0; bt < 5; bt++) {
            float blockWZ = (firstBI + float(bt)) * BLOCK_SIZE + 0.5;
            if (inAlley(blockWZ)) continue;
            // Left building top
            float bhL = getBH(blockWZ, 0.0);
            tt = (bhL - CAM_H - ro.y) / rd.y;
            if (tt > 0.001 && tt < tHit) {
                p = ro + rd * tt;
                float wz = p.z + scrollZ;
                if (!inAlley(wz) && p.x < -HALF_STREET && p.x > -(HALF_STREET + BLDG_DEPTH) && abs(getBH(wz, 0.0) - bhL) < 0.5)
                { tHit = tt; face = 5; hp = p; }
            }
            // Right building top
            float bhR = getBH(blockWZ, 1.0);
            tt = (bhR - CAM_H - ro.y) / rd.y;
            if (tt > 0.001 && tt < tHit) {
                p = ro + rd * tt;
                float wz = p.z + scrollZ;
                if (!inAlley(wz) && p.x > HALF_STREET && p.x < (HALF_STREET + BLDG_DEPTH) && abs(getBH(wz, 1.0) - bhR) < 0.5)
                { tHit = tt; face = 6; hp = p; }
            }
        }
    }

    return face >= 0;
}

float3 shadeCity(float3 hp, float dist, int face, float seed, float scrollZ, int preset) {
    float3 tint = getPreset(preset, 1);
    float3 col = float3(0, 0, 0);
    float wz = hp.z + scrollZ;

    if (face == 4) {
        // FLOOR: grid lines + bright code rain projected downward
        // Use denser UV and negate the z component so rain scrolls correctly
        float2 uv = float2(hp.x * 0.3, -wz * 0.2);
        col = renderCode(uv, seed + 200.0, preset) * 0.7;
        float gx = frac(hp.x * 0.5);
        float gz = frac(wz * 0.5);
        col += tint * 0.3 * saturate(step(0.97, gx) + step(gx, 0.03) + step(0.97, gz) + step(gz, 0.03));
    } else if (face == 5 || face == 6) {
        // BUILDING TOP: horizontal code pattern
        float2 uv = float2(hp.x * 0.15, wz * 0.12);
        col = renderCode(uv, seed + 300.0 + float(face) * 50.0, preset) * 0.4;
        // Edge glow at rooftop rim
        float edgeX = min(abs(hp.x) - HALF_STREET, (HALF_STREET + BLDG_DEPTH) - abs(hp.x));
        col += tint * 0.3 * exp(-edgeX * 2.0);
    } else {
        // VERTICAL WALLS (front, back, side): code rain falling down
        float side = (face == 0 || face == 2 || face == 5 || face == 7) ? 0.0 : 1.0;
        float bh = getBH(wz, side);
        float2 uv;
        if (face < 2 || face >= 7) {
            // Front/back walls: UV = (z, height)
            uv = float2(wz * 0.12, (hp.y + CAM_H) / max(bh, 0.1));
        } else {
            // Side walls: UV = (x_depth, height)
            float xOff = (abs(hp.x) - HALF_STREET) / BLDG_DEPTH;
            uv = float2(xOff, (hp.y + CAM_H) / max(bh, 0.1));
        }
        col = renderCode(uv, seed + float(face) * 100.0, preset);

        // Grid lines on walls
        float gU, gV;
        if (face < 2 || face >= 7) { gU = frac(wz * 0.4); gV = frac((hp.y + CAM_H) * 0.4); }
        else { gU = frac((abs(hp.x) - HALF_STREET) * 0.4); gV = frac((hp.y + CAM_H) * 0.4); }
        col += tint * 0.12 * saturate(step(0.97, gU) + step(gU, 0.03) + step(0.97, gV) + step(gV, 0.03));

        // Window lights: randomly lit rectangles
        float winU = frac(wz * 0.7);
        float winV = frac((hp.y + CAM_H) * 0.5);
        float winOn = hash(float2(floor(wz * 0.7), floor((hp.y + CAM_H) * 0.5))) > 0.45 ? 1.0 : 0.0;
        float winShape = step(0.12, winU) * step(winU, 0.72) * step(0.12, winV) * step(winV, 0.72);
        col += tint * 0.06 * winOn * winShape;

        // Rooftop edge glow
        float topDist = abs(hp.y - (bh - CAM_H));
        col += tint * 0.4 * exp(-topDist * 3.0);
    }

    // Back faces are dimmer
    if (face >= 7) col *= 0.5;

    col *= exp(-dist * FOG_DENSITY);
    return col;
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET {
    float aspect = Resolution.x / Resolution.y;
    float t = Time;

    // Walk segments (wraps every 42 — divisible by 6 presets = 7 full color cycles)
    float wrappedT = fmod(t, 42.0 * SEG_LEN);
    int timeLoops = int(t / (42.0 * SEG_LEN));
    float yawBefore = 0.0, segProg = 0.0, turnDir = 1.0;
    int curSeg = 0;
    float acc = 0.0;
    [loop] for (int i = 0; i < 42; i++) {
        float dir = (hash1(float(i)) < 0.45) ? -1.0 : 1.0;
        if (acc + SEG_LEN > wrappedT) {
            curSeg = i + timeLoops * 42;
            segProg = wrappedT - acc;
            turnDir = dir;
            break;
        }
        yawBefore += dir * PI * 0.5;
        acc += SEG_LEN;
        if (i == 41) { curSeg = 41 + timeLoops * 42; segProg = wrappedT - acc; turnDir = 1.0; }
    }

    float turnFrac = 0.0;
    if (segProg > STRAIGHT_LEN) {
        float tf = saturate((segProg - STRAIGHT_LEN) / TURN_LEN);
        turnFrac = tf * tf * (3.0 - 2.0 * tf);
    }
    float yawAfter = yawBefore + turnDir * PI * 0.5;
    float curYaw = lerp(yawBefore, yawAfter, turnFrac);

    float sy = sin(curYaw), cy = cos(curYaw);
    float3 fwd = float3(sy, 0.0, cy);
    float3 rgt = float3(cy, 0.0, -sy);
    float3 up  = float3(0.0, 1.0, 0.0);
    float bank = turnFrac * (1.0 - turnFrac) * 4.0 * turnDir * 0.06;
    float cB = cos(bank), sB = sin(bank);
    float3 upB = up * cB + rgt * sB;
    float3 rgB = rgt * cB - up * sB;

    float2 scr = (tex - 0.5) * float2(aspect, -1.0);
    float3 rdW = normalize(scr.x * rgB + scr.y * upB + FOV * fwd);
    float scrollZ = t * CAM_SPEED;

    float3 color = float3(0, 0, 0);

    // Corridor A
    float sA = sin(yawBefore), cA = cos(yawBefore);
    float3 rdA = float3(dot(rdW, float3(cA, 0, -sA)), rdW.y, dot(rdW, float3(sA, 0, cA)));
    float tA = MAX_DIST; int fA = -1; float3 hA = float3(0, 0, 0);
    bool hitA = castCity(float3(0, 0, 0), rdA, scrollZ, tA, fA, hA);

    // Corridor B
    float sB2 = sin(yawAfter), cB2 = cos(yawAfter);
    float3 rdB = float3(dot(rdW, float3(cB2, 0, -sB2)), rdW.y, dot(rdW, float3(sB2, 0, cB2)));
    float tB = MAX_DIST; int fB = -1; float3 hB = float3(0, 0, 0);
    bool hitB = castCity(float3(0, 0, 0), rdB, scrollZ, tB, fB, hB);

    float seedA = float(curSeg) * 31.0;
    float seedB = float(curSeg + 1) * 31.0 + 500.0;
    int presetA = curSeg;
    int presetB = curSeg + 1;

    if (turnFrac < 0.01) {
        if (hitA) color = shadeCity(hA, tA, fA, seedA, scrollZ, presetA);
    } else if (turnFrac > 0.99) {
        if (hitB) color = shadeCity(hB, tB, fB, seedB, scrollZ, presetB);
    } else {
        float3 colA = hitA ? shadeCity(hA, tA, fA, seedA, scrollZ, presetA) : float3(0, 0, 0);
        float3 colB = hitB ? shadeCity(hB, tB, fB, seedB, scrollZ, presetB) : float3(0, 0, 0);
        float blend = turnFrac;
        if (hitA && hitB) {
            float distBias = saturate((tA - tB) / (tA + tB + 0.1) * 2.0 + 0.5);
            blend = lerp(turnFrac * 0.5, 1.0 - (1.0 - turnFrac) * 0.5, distBias);
        }
        color = lerp(colA, colB, blend);
    }

    // Background rain streaks in current preset color
    float rainMask = bgRain(tex, t);
    float3 rainTint = getPreset(curSeg, 1);
    color += rainMask * rainTint * 0.8;

    // Scanlines + vignette
    color *= 0.94 + 0.06 * sin(tex.y * Resolution.y * PI);
    float2 vig = tex * (1.0 - tex);
    color *= saturate(pow(vig.x * vig.y * 14.0, 0.35));

    float4 text = shaderTexture.Sample(samplerState, tex);
    return float4(text.rgb + color, text.a);
}
