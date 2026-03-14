// WhiteRoom.hlsl - CRT TV color picker in white void
//
// SELECTION & ZOOM via shaderTexture (no file watcher dependency):
//   R channel = (selected+1)*40/255  → swatch index 0-5
//   G channel = zoom level 0-255     → 0.15 (far) to 1.0 (close)
//
// 3D TECHNIQUE: Cabinet rendered as extruded box using Redpill-style
// front-face / back-face offset. Side/top panels are the visible strip
// between the two faces.
//
// UV COORDINATE SYSTEM: uv = tex - 0.5
//   uv.y < 0 = TOP of screen
//   uv.y > 0 = BOTTOM of screen

#define STATE        1
#define STATE_TIME   0.0

Texture2D shaderTexture;
SamplerState samplerState;
cbuffer PixelShaderSettings {
    float Time;
    float Scale;
    float2 Resolution;
    float4 Background;
};

// --- Utility functions ---

float hash(float2 p) {
    return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

float hash2(float2 p) {
    return frac(sin(dot(p, float2(41.256, 63.891))) * 29847.1923);
}

float sdRoundBox(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sdCircle(float2 p, float r) {
    return length(p) - r;
}

float sdSegment(float2 p, float2 a, float2 b) {
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// --- Rich wood grain: layered procedural texture ---
float3 cabinetSurface(float2 uv) {
    // Base warm wood color
    float3 base = float3(0.50, 0.37, 0.18);

    // Primary grain: long vertical bands
    float grain1 = sin(uv.y * 80.0 + hash(float2(floor(uv.x * 20.0), 0.0)) * 5.0) * 0.035;

    // Secondary grain: finer, offset waves
    float grain2 = sin(uv.y * 160.0 + uv.x * 8.0 + hash(float2(floor(uv.x * 40.0), 1.0)) * 3.0) * 0.018;

    // Knot pattern: occasional darker swirl
    float2 knotP = uv * 12.0;
    float knotD = length(frac(knotP) - 0.5);
    float knot = smoothstep(0.22, 0.15, knotD) * hash(floor(knotP)) * 0.08;

    // Micro noise (pore texture)
    float fine = hash(uv * 300.0) * 0.015;

    // Color variation along grain
    float colorShift = sin(uv.y * 40.0 + uv.x * 3.0) * 0.02;
    base.r += colorShift;
    base.g += colorShift * 0.6;

    return base + grain1 + grain2 - knot + fine;
}

// Darker side-panel variant
float3 cabinetSide(float2 uv) {
    float3 wood = cabinetSurface(uv);
    return wood * 0.48;
}

// Darker top-panel variant (catches overhead light)
float3 cabinetTop(float2 uv) {
    float3 wood = cabinetSurface(uv);
    return wood * 0.58;
}

float tvStatic(float2 uv, float time) {
    float base = hash(uv * Resolution.xy + time * 1000.0) * 0.5 + 0.25;
    // Horizontal band flicker
    float band = sin(uv.y * 200.0 + time * 30.0) * 0.05;
    // Occasional vertical roll artifact
    float roll = sin(uv.y * 4.0 - time * 2.5) * 0.03;
    return base + band + roll;
}

static const float3 COLORS[6] = {
    float3(0.0, 0.78, 0.18),   // Green
    float3(0.05, 0.15, 1.0),   // Blue
    float3(1.0, 0.0, 0.0),     // Red
    float3(0.82, 0.0, 0.78),   // Purple/Magenta
    float3(0.85, 0.68, 0.0),   // Gold
    float3(0.0, 0.75, 0.80)    // Teal
};

// Read selection, zoom, AND power-off from terminal text buffer
// R = selection, G = zoom, B = power-off level (255 = full black)
void readPickerState(out int selected, out float zoom, out float powerOff) {
    float r = 0.0, g = 0.0, b = 0.0;
    [unroll] for (int i = 0; i < 3; i++) {
        float2 samplePos = float2(0.01 + 0.01 * float(i), 0.005);
        float4 s = shaderTexture.Sample(samplerState, samplePos);
        r += s.r;
        g += s.g;
        b += s.b;
    }
    r /= 3.0;
    g /= 3.0;
    b /= 3.0;
    selected = clamp((int)(r * 255.0 / 40.0 + 0.5) - 1, 0, 5);
    zoom = clamp(g, 0.0, 1.0);  // 0 = far, 1 = close
    zoom = lerp(0.02, 1.0, zoom); // map to actual zoom range (0.02 = tiny dot)
    powerOff = clamp(b, 0.0, 1.0); // 0 = normal, 1 = fully off
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET {
    // Stay BLACK until C# writes picker state via ANSI bg color (R > 0).
    // Empty terminal buffer = all zeros in shaderTexture = invisible startup.
    // This prevents the CRT TV from being visible during window creation.
    float rawR = shaderTexture.Sample(samplerState, float2(0.01, 0.005)).r;
    if (rawR < 0.05) return float4(0, 0, 0, 1);

    float2 uv = tex - 0.5;
    float aspect = Resolution.x / Resolution.y;
    uv.x *= aspect;

    float elapsed = Time - (float)STATE_TIME;

    // Read picker state from terminal buffer
    int selected;
    float zoom;
    float powerOff;
    readPickerState(selected, zoom, powerOff);

    // --- Power-off via shaderTexture B channel ---
    // C# animates: zoom shrinks (G→0), powerOff fades (B→255)
    // 3-phase CRT effect replaces linear fade

    // Apply zoom: everything shrinks when zoom < 1
    float2 zuv = uv / max(zoom, 0.01);

    // --- CRT power-off squeeze/contract UV distortion ---
    if (powerOff > 0.0) {
        // Phase 1 (powerOff 0.0 - 0.5): Vertical squeeze to horizontal line
        float squeezeT = saturate(powerOff / 0.5);
        float squeezeEased = squeezeT * squeezeT; // ease-in: accelerating squish
        float vScale = lerp(1.0, 0.008, squeezeEased);
        zuv.y = zuv.y / max(vScale, 0.001);

        // Phase 2 (powerOff 0.5 - 0.8): Horizontal contract to center dot
        float contractT = saturate((powerOff - 0.5) / 0.3);
        float contractEased = contractT * contractT;
        float hScale = lerp(1.0, 0.015, contractEased);
        zuv.x = zuv.x / max(hScale, 0.001);

        // Clip: anything outside the original viewport bounds is black
        float clipX = aspect * 0.55;  // generous clip bounds
        float clipY = 0.55;
        if (abs(zuv.x) > clipX || abs(zuv.y) > clipY) {
            return float4(0, 0, 0, 1);
        }
    }

    // --- White void with subtle gradient ---
    float voidGrad = smoothstep(0.0, 0.6, length(uv));
    float3 color = lerp(float3(1.0, 1.0, 1.0), float3(0.92, 0.92, 0.93), voidGrad);

    // ==========================================================
    // TV LAYOUT CONSTANTS
    // ==========================================================

    float2 cabSize = float2(0.35, 0.38);
    float cabR = 0.012;

    float2 bezSize = float2(0.30, 0.24);
    float bezR = 0.010;
    float2 bezC = float2(0.0, -0.055);

    float2 scrSize = float2(0.26, 0.20);
    float scrR = 0.012;
    float2 scrC = bezC;

    float2 panelSize = float2(0.30, 0.050);
    float2 panelC = float2(0.0, 0.285);

    float speakerR = 0.028;
    float2 spkL = float2(-0.23, 0.285);
    float2 spkR = float2(0.23, 0.285);

    float2 handleSize = float2(0.12, 0.005);

    // Legs: splayed outward
    float2 legTL = float2(-0.18, 0.38);
    float2 legBL = float2(-0.24, 0.50);
    float2 legTR = float2(0.18, 0.38);
    float2 legBR = float2(0.24, 0.50);
    float legThick = 0.010;

    // Antenna positions (V-shaped rabbit ears)
    float2 antBase = float2(0.0, -cabSize.y - 0.005);
    float2 antTipL = float2(-0.14, -cabSize.y - 0.20);
    float2 antTipR = float2(0.14, -cabSize.y - 0.20);
    float antThick = 0.004;

    // Knob positions on control panel
    float2 knob1C = float2(-0.18, 0.285);
    float2 knob2C = float2(-0.10, 0.285);
    float knobR = 0.018;

    // Power LED
    float2 ledC = float2(0.20, 0.285);
    float ledR = 0.005;

    // ==========================================================
    // 3D BOX EXTRUSION - more pronounced depth
    // Camera slightly below-right → top and right panels visible
    // ==========================================================

    float cabDepth = 0.045;
    float2 backOffset = float2(-0.014, -0.018);
    float2 backCabSize = cabSize + cabDepth * 0.30;
    float backR = cabR + 0.005;

    // ==========================================================
    // RENDER LAYERS (back to front)
    // ==========================================================

    // --- Layer 0: Floor contact shadow ---
    float2 shadowC = float2(0.008, 0.50);
    float2 shadowSize = float2(cabSize.x + 0.08, 0.04);
    float dFloorShad = sdRoundBox(zuv - shadowC, shadowSize, 0.03);
    if (dFloorShad < 0.06) {
        float sf = smoothstep(0.06, -0.02, dFloorShad) * 0.12;
        color -= sf;
    }

    // --- Layer 0.5: Drop shadow behind cabinet ---
    float dShad = sdRoundBox(zuv - float2(0.008, 0.015), cabSize + 0.018, cabR);
    if (dShad < 0.03) {
        float sf = smoothstep(0.03, -0.015, dShad) * 0.10;
        color -= sf;
    }

    // --- Layer 0.7: Antenna (behind cabinet) ---
    float dAntL = sdSegment(zuv, antBase, antTipL);
    float dAntR = sdSegment(zuv, antBase, antTipR);

    // Antenna tips: small spheres
    float dAntTipL = sdCircle(zuv - antTipL, 0.006);
    float dAntTipR = sdCircle(zuv - antTipR, 0.006);

    if (dAntL < antThick + 0.003) {
        float t = 1.0 - smoothstep(antThick * 0.3, antThick + 0.003, dAntL);
        float3 antCol = float3(0.55, 0.55, 0.58);
        // Metallic sheen: varies along length
        float yf = (zuv.y - antBase.y) / (antTipL.y - antBase.y);
        antCol += float3(0.08, 0.08, 0.10) * sin(yf * 12.0);
        // Specular highlight on left edge
        float spec = exp(-abs(dAntL) * 400.0) * 0.3;
        antCol += spec;
        color = lerp(color, antCol, t);
    }
    if (dAntR < antThick + 0.003) {
        float t = 1.0 - smoothstep(antThick * 0.3, antThick + 0.003, dAntR);
        float3 antCol = float3(0.55, 0.55, 0.58);
        float yf = (zuv.y - antBase.y) / (antTipR.y - antBase.y);
        antCol += float3(0.08, 0.08, 0.10) * sin(yf * 12.0);
        float spec = exp(-abs(dAntR) * 400.0) * 0.3;
        antCol += spec;
        color = lerp(color, antCol, t);
    }
    // Antenna tip balls
    if (dAntTipL < 0.003) {
        float t = smoothstep(0.003, -0.001, dAntTipL);
        float3 tipCol = float3(0.60, 0.60, 0.65);
        tipCol += exp(-dAntTipL * 200.0) * 0.2;
        color = lerp(color, tipCol, t);
    }
    if (dAntTipR < 0.003) {
        float t = smoothstep(0.003, -0.001, dAntTipR);
        float3 tipCol = float3(0.60, 0.60, 0.65);
        tipCol += exp(-dAntTipR * 200.0) * 0.2;
        color = lerp(color, tipCol, t);
    }

    // --- Layer 1: Legs with tapered thickness ---
    float dLL = sdSegment(zuv, legTL, legBL);
    float dLR = sdSegment(zuv, legTR, legBR);

    if (dLL < legThick) {
        float t = 1.0 - smoothstep(legThick * 0.4, legThick, dLL);
        float3 lc = float3(0.32, 0.22, 0.10);
        float yf = (zuv.y - legTL.y) / (legBL.y - legTL.y);
        lc *= 1.0 - 0.20 * yf; // darker toward floor
        // Wood grain on legs
        lc += sin(yf * 40.0) * 0.02;
        // Inner highlight
        lc += exp(-dLL * 200.0) * 0.06;
        color = lerp(color, lc, t);
    }
    if (dLR < legThick) {
        float t = 1.0 - smoothstep(legThick * 0.4, legThick, dLR);
        float3 lc = float3(0.32, 0.22, 0.10);
        float yf = (zuv.y - legTR.y) / (legBR.y - legTR.y);
        lc *= 1.0 - 0.20 * yf;
        lc += sin(yf * 40.0) * 0.02;
        lc += exp(-dLR * 200.0) * 0.06;
        color = lerp(color, lc, t);
    }

    // Leg-to-cabinet joint: small dark circles
    float dJointL = sdCircle(zuv - legTL, 0.008);
    float dJointR = sdCircle(zuv - legTR, 0.008);
    if (dJointL < 0.003) {
        color = lerp(color, float3(0.22, 0.15, 0.08), smoothstep(0.003, -0.002, dJointL));
    }
    if (dJointR < 0.003) {
        color = lerp(color, float3(0.22, 0.15, 0.08), smoothstep(0.003, -0.002, dJointR));
    }

    // --- Layer 1.5: Back face + side panels (3D box depth) ---
    float dBack = sdRoundBox(zuv - backOffset, backCabSize, backR);
    float dCab = sdRoundBox(zuv, cabSize, cabR);

    // Side/top panels: inside back face, outside front face
    if (dBack < 0.004 && dCab > -0.006) {
        float ef = smoothstep(0.004, -0.005, dBack);

        // Determine which panel (top vs sides)
        float isTop = smoothstep(0.0, -0.08, zuv.y - (-cabSize.y));
        float isRight = smoothstep(cabSize.x - 0.02, cabSize.x + 0.02, zuv.x);
        float isLeft = smoothstep(-cabSize.x + 0.02, -cabSize.x - 0.02, zuv.x);

        float3 sideCol;
        if (isTop > 0.5) {
            sideCol = cabinetTop(zuv * 3.0);
        } else {
            sideCol = cabinetSide(zuv * 3.0);
            // Right panel catches more light
            sideCol *= 1.0 + isRight * 0.15;
            // Left panel is darker (shadowed)
            sideCol *= 1.0 - isLeft * 0.10;
        }

        // Depth gradient: darker closer to back
        float depthT = smoothstep(0.004, -0.020, dBack);
        sideCol *= 0.85 + 0.15 * depthT;

        // Fade out where front face covers
        float frontMask = smoothstep(-0.006, 0.006, dCab);
        color = lerp(color, sideCol, ef * frontMask);
    }

    // Back face edge highlight (rim where back meets side)
    if (dBack > -0.010 && dBack < 0.005 && dCab > 0.0) {
        float rimA = smoothstep(0.005, 0.001, dBack) * smoothstep(-0.010, -0.005, dBack);
        float3 rimCol = float3(0.30, 0.22, 0.08);
        color = lerp(color, rimCol, rimA * 0.55);
    }

    // --- Layer 2: Cabinet front face ---
    if (dCab < 0.004) {
        float ef = smoothstep(0.004, -0.007, dCab);
        float3 cab = cabinetSurface(zuv * 3.0);

        // Edge darkening (front face bevel)
        float ed = smoothstep(-0.007, -0.035, dCab);
        cab *= 0.80 + 0.20 * ed;

        // Top highlight (overhead light)
        cab += smoothstep(0.15, -0.30, zuv.y) * 0.07;

        // Subtle left-to-right light gradient
        cab += zuv.x * 0.03;

        color = lerp(color, cab, ef);
    }

    // Brass trim ring around cabinet edge
    if (dCab > -0.012 && dCab < 0.005) {
        float trimA = smoothstep(0.005, 0.001, dCab) * smoothstep(-0.012, -0.007, dCab);
        float3 brass = float3(0.70, 0.55, 0.22);
        // Specular along top edge
        brass += smoothstep(0.001, -0.004, dCab) * 0.10;
        // Brighter on top
        brass += smoothstep(0.0, -0.3, zuv.y) * 0.08;
        color = lerp(color, brass, trimA * 0.78);
    }

    // --- Layer 3: Screen bezel (deep recess) ---
    float dBez = sdRoundBox(zuv - bezC, bezSize, bezR);
    if (dBez < 0.004) {
        float ef = smoothstep(0.004, -0.005, dBez);
        float3 bc = float3(0.07, 0.06, 0.05);

        // Inner bevel: lighter on top edge (overhead light), darker on bottom
        float bev = smoothstep(-0.005, -0.018, dBez) * 0.07;
        bc += bev * (zuv.y - bezC.y < 0.0 ? 1.3 : 0.15);

        // Depth shadow at the edges of the recess
        float depthShad = smoothstep(-0.030, -0.010, dBez) * 0.05;
        bc -= depthShad;

        // Bezel screws (4 corners)
        float2 bezCorners[4] = {
            bezC + float2(-bezSize.x + 0.015, -bezSize.y + 0.015),
            bezC + float2( bezSize.x - 0.015, -bezSize.y + 0.015),
            bezC + float2(-bezSize.x + 0.015,  bezSize.y - 0.015),
            bezC + float2( bezSize.x - 0.015,  bezSize.y - 0.015)
        };
        [unroll] for (int si = 0; si < 4; si++) {
            float dScrew = sdCircle(zuv - bezCorners[si], 0.004);
            if (dScrew < 0.002) {
                float sf = smoothstep(0.002, -0.001, dScrew);
                float3 screwCol = float3(0.30, 0.28, 0.25);
                // Slot line
                screwCol -= smoothstep(0.001, 0.0, abs(zuv.x - bezCorners[si].x)) * 0.08;
                bc = lerp(bc, screwCol, sf);
            }
        }

        color = lerp(color, bc, ef);
    }

    // --- Layer 4: TV Screen (CRT with static + swatches) ---
    float dScr = sdRoundBox(zuv - scrC, scrSize, scrR);
    if (dScr < 0.003) {
        float ef = smoothstep(0.003, -0.005, dScr);

        // Screen-local coordinates
        float2 sL = (zuv - scrC);
        float2 sN = sL / scrSize;

        // CRT barrel distortion: screen content curves outward
        float2 crt = sN;
        float r2 = dot(crt, crt);
        crt *= 1.0 + 0.06 * r2 + 0.02 * r2 * r2;

        // TV static background with CRT-applied distortion
        float2 staticUV = crt * scrSize + scrC;
        float3 sc = float3(1, 1, 1) * tvStatic(staticUV, Time);

        // --- Color swatches ---
        float swW = 0.54;
        float swH = 0.76;
        float gX = 0.06;
        float gY = 0.08;

        for (int row = 0; row < 2; row++) {
            for (int col = 0; col < 3; col++) {
                int idx = row * 3 + col;

                float cx = (float(col) - 1.0) * (swW + gX);
                float cy = (float(row) - 0.5) * (swH + gY);

                // Apply CRT distortion to swatch positions
                float2 sp = crt - float2(cx, cy);
                float2 sb = float2(swW * 0.5, swH * 0.5);

                float dSw = sdRoundBox(sp, sb, 0.04);
                float sScale = min(scrSize.x, scrSize.y);
                float dPx = dSw * sScale;

                // Drop shadow behind each swatch
                float shad = smoothstep(0.008, 0.0, dPx - 0.006) * 0.30;
                sc = lerp(sc, float3(0, 0, 0), shad);

                if (dPx < 0.003) {
                    float ff = smoothstep(0.003, -0.004, dPx);
                    float3 swatchCol = COLORS[idx];
                    // Slight CRT phosphor variation within swatch
                    swatchCol *= 0.95 + 0.05 * sin(crt.y * scrSize.y * 600.0);
                    sc = lerp(sc, swatchCol, ff);
                }

                // Selection indicator
                if (idx == selected) {
                    // Steady white border (no pulsing)
                    float band = smoothstep(0.012, 0.006, abs(dPx));
                    sc = lerp(sc, float3(1.0, 1.0, 1.0), band);
                    // Color-matched glow outside the border
                    float glow = exp(-abs(dPx) * 55.0) * 0.45;
                    sc += COLORS[idx] * glow;
                } else {
                    // Subtle thin border on unselected
                    float brd = exp(-abs(dPx) * 300.0) * 0.12;
                    sc += float3(0.15, 0.15, 0.15) * brd;
                }
            }
        }

        // CRT scanlines
        float scanline = sin(sN.y * scrSize.y * 800.0) * 0.5 + 0.5;
        sc *= 0.92 + 0.08 * scanline;

        // CRT vignette: darken screen edges
        float vig = 1.0 - 0.35 * r2;
        sc *= vig;

        // CRT color fringing at edges
        float fringe = smoothstep(0.6, 1.0, length(sN));
        sc.r *= 1.0 + fringe * 0.04;
        sc.b *= 1.0 - fringe * 0.04;

        // Glass reflection: diagonal highlight across screen
        float refl = smoothstep(0.02, 0.0, abs(sN.x + sN.y * 0.8 - 0.15));
        refl *= smoothstep(1.0, 0.3, length(sN));
        sc += float3(0.12, 0.12, 0.14) * refl;

        // Second subtle reflection (smaller, offset)
        float refl2 = smoothstep(0.015, 0.0, abs(sN.x + sN.y * 0.8 - 0.35));
        refl2 *= smoothstep(1.0, 0.5, length(sN));
        sc += float3(0.04, 0.04, 0.05) * refl2;

        color = lerp(color, sc, ef);
    }

    // --- Layer 4.5: Screen glow bleeding onto bezel ---
    if (dScr > 0.0 && dScr < 0.025) {
        float3 selCol = COLORS[selected];
        float glowStr = exp(-dScr * 80.0) * 0.08;
        color += selCol * glowStr;
    }

    // --- Layer 5: Control panel ---
    float dPanel = sdRoundBox(zuv - panelC, panelSize, 0.008);
    if (dPanel < 0.003) {
        float ef = smoothstep(0.003, -0.005, dPanel);
        float3 pc = float3(0.12, 0.10, 0.09);

        float2 pl = zuv - panelC;
        // Brushed metal texture
        float lines = sin(pl.y * 500.0) * 0.5 + 0.5;
        lines *= smoothstep(panelSize.x * 0.85, panelSize.x * 0.25, abs(pl.x));
        pc += float3(0.035, 0.030, 0.022) * lines;

        // Slight reflection gradient
        pc += smoothstep(panelSize.x, 0.0, abs(pl.x)) * 0.015;

        // Handle bar
        float dH = sdRoundBox(pl, handleSize, 0.004);
        if (dH < 0.003) {
            float hf = smoothstep(0.003, -0.002, dH);
            float3 handleCol = float3(0.44, 0.37, 0.23);
            // Highlight along top edge of handle
            handleCol += smoothstep(0.002, -0.001, dH) * 0.08;
            pc = lerp(pc, handleCol, hf);
        }

        color = lerp(color, pc, ef);
    }

    // --- Layer 5.5: Control knobs (channel/volume) ---
    // Knob 1 (channel selector)
    float dK1 = sdCircle(zuv - knob1C, knobR);
    if (dK1 < 0.005) {
        float ef = smoothstep(0.005, -0.003, dK1);
        float3 kc = float3(0.25, 0.22, 0.18);

        // Knurled edge (ridged grip)
        float angle1 = atan2(zuv.y - knob1C.y, zuv.x - knob1C.x);
        float ridges = sin(angle1 * 24.0) * 0.5 + 0.5;
        float ridgeMask = smoothstep(-0.003, 0.001, dK1); // only on outer ring
        kc += float3(0.06, 0.05, 0.04) * ridges * ridgeMask;

        // Center cap
        float dKCap1 = sdCircle(zuv - knob1C, knobR * 0.5);
        if (dKCap1 < 0.002) {
            kc = lerp(kc, float3(0.35, 0.30, 0.22), smoothstep(0.002, -0.001, dKCap1));
        }

        // Position indicator line
        float indLine = sdSegment(zuv, knob1C, knob1C + float2(0.0, -knobR * 0.85));
        if (indLine < 0.002) {
            kc = lerp(kc, float3(0.9, 0.9, 0.9), smoothstep(0.002, 0.0, indLine) * 0.7);
        }

        // Specular highlight
        kc += exp(-dK1 * 100.0) * 0.12;

        color = lerp(color, kc, ef);
    }

    // Knob 2 (volume)
    float dK2 = sdCircle(zuv - knob2C, knobR);
    if (dK2 < 0.005) {
        float ef = smoothstep(0.005, -0.003, dK2);
        float3 kc = float3(0.25, 0.22, 0.18);

        float angle2 = atan2(zuv.y - knob2C.y, zuv.x - knob2C.x);
        float ridges = sin(angle2 * 24.0) * 0.5 + 0.5;
        float ridgeMask = smoothstep(-0.003, 0.001, dK2);
        kc += float3(0.06, 0.05, 0.04) * ridges * ridgeMask;

        float dKCap2 = sdCircle(zuv - knob2C, knobR * 0.5);
        if (dKCap2 < 0.002) {
            kc = lerp(kc, float3(0.35, 0.30, 0.22), smoothstep(0.002, -0.001, dKCap2));
        }

        // Volume indicator: rotated ~45 degrees
        float2 volDir = float2(0.707, -0.707);
        float indLine2 = sdSegment(zuv, knob2C, knob2C + volDir * knobR * 0.85);
        if (indLine2 < 0.002) {
            kc = lerp(kc, float3(0.9, 0.9, 0.9), smoothstep(0.002, 0.0, indLine2) * 0.7);
        }

        kc += exp(-dK2 * 100.0) * 0.12;
        color = lerp(color, kc, ef);
    }

    // --- Layer 5.6: Power LED ---
    float dLed = sdCircle(zuv - ledC, ledR);
    if (dLed < 0.006) {
        float ef = smoothstep(0.006, -0.001, dLed);
        float3 ledCol = float3(0.1, 0.9, 0.1); // green LED
        // Glow halo
        float ledGlow = exp(-abs(dLed) * 300.0) * 0.5;
        float3 ledFinal = lerp(float3(0.03, 0.03, 0.02), ledCol, smoothstep(0.003, 0.0, dLed));
        ledFinal += ledCol * ledGlow;
        color = lerp(color, ledFinal, ef);
    }

    // --- Layer 6: Speaker grilles ---
    float dSL = sdCircle(zuv - spkL, speakerR);
    float dSR2 = sdCircle(zuv - spkR, speakerR);

    if (dSL < 0.004) {
        float ef = smoothstep(0.004, -0.003, dSL);
        float3 sc = float3(0.16, 0.13, 0.10);

        // Concentric speaker rings
        float ringDist = length(zuv - spkL);
        float rings = sin(ringDist * 500.0) * 0.5 + 0.5;
        sc += float3(0.04, 0.035, 0.025) * rings;

        // Speaker cone: darker center
        float cone = smoothstep(speakerR * 0.6, speakerR * 0.2, ringDist);
        sc *= 1.0 - 0.25 * cone;

        // Dust cap (tiny center bump)
        float dustCap = smoothstep(speakerR * 0.15, 0.0, ringDist);
        sc += float3(0.06, 0.05, 0.04) * dustCap;

        // Metallic rim highlight
        sc += exp(-abs(dSL) * 350.0) * 0.18;

        color = lerp(color, sc, ef);
    }
    if (dSR2 < 0.004) {
        float ef = smoothstep(0.004, -0.003, dSR2);
        float3 sc = float3(0.16, 0.13, 0.10);

        float ringDist = length(zuv - spkR);
        float rings = sin(ringDist * 500.0) * 0.5 + 0.5;
        sc += float3(0.04, 0.035, 0.025) * rings;

        float cone = smoothstep(speakerR * 0.6, speakerR * 0.2, ringDist);
        sc *= 1.0 - 0.25 * cone;

        float dustCap = smoothstep(speakerR * 0.15, 0.0, ringDist);
        sc += float3(0.06, 0.05, 0.04) * dustCap;

        sc += exp(-abs(dSR2) * 350.0) * 0.18;

        color = lerp(color, sc, ef);
    }

    // --- Cabinet rim highlight (catches ambient light) ---
    if (dCab > -0.025 && dCab < 0.012) {
        float rim = exp(-abs(dCab) * 160.0) * 0.12;
        // Brighter on top and right edges
        float topBias = smoothstep(0.2, -0.3, zuv.y) * 0.6 + 0.4;
        float rightBias = smoothstep(-0.2, 0.3, zuv.x) * 0.3 + 0.7;
        color += float3(0.28, 0.20, 0.08) * rim * topBias * rightBias;
    }

    // --- Phase 3 (powerOff 0.8 - 1.0): Phosphor dot fade to black ---
    if (powerOff > 0.8) {
        float fadeT = saturate((powerOff - 0.8) / 0.2);
        // Scene fades out
        color *= (1.0 - fadeT);
        // Phosphor persistence: bright center dot that lingers briefly
        float centerDist = length(uv);  // use original uv, not zuv
        float phosphorGlow = exp(-centerDist * 25.0) * (1.0 - fadeT * fadeT) * 0.6;
        color += float3(1, 1, 1) * phosphorGlow;
    }

    // Full black at end of animation
    if (powerOff > 0.99) return float4(0, 0, 0, 1);

    return float4(saturate(color), 1.0);
}
