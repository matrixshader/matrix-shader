// WHITE ROOM - CRT TV color picker (Ghostty / Shadertoy API)
// Ported from Windows WhiteRoom.hlsl

// State machine defines (rewritten by construct_service.py via #define injection)
#define STATE        1
#define STATE_TIME   0.0
#define SELECTED     0
#define ZOOM         0.0
#define POWER_OFF    0.0

// --- Utility functions ---

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(41.256, 63.891))) * 29847.1923);
}

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// --- Rich wood grain: layered procedural texture ---
vec3 cabinetSurface(vec2 uv) {
    // Base warm wood color
    vec3 base = vec3(0.50, 0.37, 0.18);

    // Primary grain: long vertical bands
    float grain1 = sin(uv.y * 80.0 + hash(vec2(floor(uv.x * 20.0), 0.0)) * 5.0) * 0.035;

    // Secondary grain: finer, offset waves
    float grain2 = sin(uv.y * 160.0 + uv.x * 8.0 + hash(vec2(floor(uv.x * 40.0), 1.0)) * 3.0) * 0.018;

    // Knot pattern: occasional darker swirl
    vec2 knotP = uv * 12.0;
    float knotD = length(fract(knotP) - 0.5);
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
vec3 cabinetSide(vec2 uv) {
    vec3 wood = cabinetSurface(uv);
    return wood * 0.48;
}

// Darker top-panel variant (catches overhead light)
vec3 cabinetTop(vec2 uv) {
    vec3 wood = cabinetSurface(uv);
    return wood * 0.58;
}

float tvStatic(vec2 uv, float time) {
    float base = hash(uv * iResolution.xy + time * 1000.0) * 0.5 + 0.25;
    // Horizontal band flicker
    float band = sin(uv.y * 200.0 + time * 30.0) * 0.05;
    // Occasional vertical roll artifact
    float roll = sin(uv.y * 4.0 - time * 2.5) * 0.03;
    return base + band + roll;
}

const vec3 COLORS[6] = vec3[6](
    vec3(0.0, 0.78, 0.18),   // Green
    vec3(0.05, 0.15, 1.0),   // Blue
    vec3(1.0, 0.0, 0.0),     // Red
    vec3(0.82, 0.0, 0.78),   // Purple/Magenta
    vec3(0.85, 0.68, 0.0),   // Gold
    vec3(0.0, 0.75, 0.80)    // Teal
);

// Picker state read from #defines (rewritten by construct_service.py)
// SELECTED = swatch index 0-5
// ZOOM = 0.0 (far) to 1.0 (close)
// POWER_OFF = 0.0 (normal) to 1.0 (fully black)

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 tex = fragCoord / iResolution.xy;
    tex.y = 1.0 - tex.y;  // Flip Y: HLSL y=0 at top, OpenGL y=0 at bottom

    vec2 uv = tex - 0.5;
    float aspect = iResolution.x / iResolution.y;
    uv.x *= aspect;

    float elapsed = iTime - float(STATE_TIME);

    // Read picker state from #defines (rewritten by construct_service.py)
    int selected = SELECTED;
    float zoom = ZOOM;
    float powerOff = POWER_OFF;

    // Apply zoom: everything shrinks when zoom < 1
    vec2 zuv = uv / max(zoom, 0.01);

    // --- CRT power-off squeeze/contract UV distortion ---
    if (powerOff > 0.0) {
        // Phase 1 (powerOff 0.0 - 0.5): Vertical squeeze to horizontal line
        float squeezeT = clamp(powerOff / 0.5, 0.0, 1.0);
        float squeezeEased = squeezeT * squeezeT; // ease-in: accelerating squish
        float vScale = mix(1.0, 0.008, squeezeEased);
        zuv.y = zuv.y / max(vScale, 0.001);

        // Phase 2 (powerOff 0.5 - 0.8): Horizontal contract to center dot
        float contractT = clamp((powerOff - 0.5) / 0.3, 0.0, 1.0);
        float contractEased = contractT * contractT;
        float hScale = mix(1.0, 0.015, contractEased);
        zuv.x = zuv.x / max(hScale, 0.001);

        // Clip: anything outside the original viewport bounds is black
        float clipX = aspect * 0.55;  // generous clip bounds
        float clipY = 0.55;
        if (abs(zuv.x) > clipX || abs(zuv.y) > clipY) {
            fragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }
    }

    // --- White void with subtle gradient ---
    float voidGrad = smoothstep(0.0, 0.6, length(uv));
    vec3 color = mix(vec3(1.0, 1.0, 1.0), vec3(0.92, 0.92, 0.93), voidGrad);

    // ==========================================================
    // TV LAYOUT CONSTANTS
    // ==========================================================

    vec2 cabSize = vec2(0.35, 0.38);
    float cabR = 0.012;

    vec2 bezSize = vec2(0.30, 0.24);
    float bezR = 0.010;
    vec2 bezC = vec2(0.0, -0.055);

    vec2 scrSize = vec2(0.26, 0.20);
    float scrR = 0.012;
    vec2 scrC = bezC;

    vec2 panelSize = vec2(0.30, 0.050);
    vec2 panelC = vec2(0.0, 0.285);

    float speakerR = 0.028;
    vec2 spkL = vec2(-0.23, 0.285);
    vec2 spkR = vec2(0.23, 0.285);

    vec2 handleSize = vec2(0.12, 0.005);

    // Legs: splayed outward
    vec2 legTL = vec2(-0.18, 0.38);
    vec2 legBL = vec2(-0.24, 0.50);
    vec2 legTR = vec2(0.18, 0.38);
    vec2 legBR = vec2(0.24, 0.50);
    float legThick = 0.010;

    // Antenna positions (V-shaped rabbit ears)
    vec2 antBase = vec2(0.0, -cabSize.y - 0.005);
    vec2 antTipL = vec2(-0.14, -cabSize.y - 0.20);
    vec2 antTipR = vec2(0.14, -cabSize.y - 0.20);
    float antThick = 0.004;

    // Knob positions on control panel
    vec2 knob1C = vec2(-0.18, 0.285);
    vec2 knob2C = vec2(-0.10, 0.285);
    float knobR = 0.018;

    // Power LED
    vec2 ledC = vec2(0.20, 0.285);
    float ledR = 0.005;

    // ==========================================================
    // 3D BOX EXTRUSION - more pronounced depth
    // Camera slightly below-right -> top and right panels visible
    // ==========================================================

    float cabDepth = 0.045;
    vec2 backOffset = vec2(-0.014, -0.018);
    vec2 backCabSize = cabSize + cabDepth * 0.30;
    float backR = cabR + 0.005;

    // ==========================================================
    // RENDER LAYERS (back to front)
    // ==========================================================

    // --- Layer 0: Floor contact shadow ---
    vec2 shadowC = vec2(0.008, 0.50);
    vec2 shadowSize = vec2(cabSize.x + 0.08, 0.04);
    float dFloorShad = sdRoundBox(zuv - shadowC, shadowSize, 0.03);
    if (dFloorShad < 0.06) {
        float sf = smoothstep(0.06, -0.02, dFloorShad) * 0.12;
        color -= sf;
    }

    // --- Layer 0.5: Drop shadow behind cabinet ---
    float dShad = sdRoundBox(zuv - vec2(0.008, 0.015), cabSize + 0.018, cabR);
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
        vec3 antCol = vec3(0.55, 0.55, 0.58);
        // Metallic sheen: varies along length
        float yf = (zuv.y - antBase.y) / (antTipL.y - antBase.y);
        antCol += vec3(0.08, 0.08, 0.10) * sin(yf * 12.0);
        // Specular highlight on left edge
        float spec = exp(-abs(dAntL) * 400.0) * 0.3;
        antCol += spec;
        color = mix(color, antCol, t);
    }
    if (dAntR < antThick + 0.003) {
        float t = 1.0 - smoothstep(antThick * 0.3, antThick + 0.003, dAntR);
        vec3 antCol = vec3(0.55, 0.55, 0.58);
        float yf = (zuv.y - antBase.y) / (antTipR.y - antBase.y);
        antCol += vec3(0.08, 0.08, 0.10) * sin(yf * 12.0);
        float spec = exp(-abs(dAntR) * 400.0) * 0.3;
        antCol += spec;
        color = mix(color, antCol, t);
    }
    // Antenna tip balls
    if (dAntTipL < 0.003) {
        float t = smoothstep(0.003, -0.001, dAntTipL);
        vec3 tipCol = vec3(0.60, 0.60, 0.65);
        tipCol += exp(-dAntTipL * 200.0) * 0.2;
        color = mix(color, tipCol, t);
    }
    if (dAntTipR < 0.003) {
        float t = smoothstep(0.003, -0.001, dAntTipR);
        vec3 tipCol = vec3(0.60, 0.60, 0.65);
        tipCol += exp(-dAntTipR * 200.0) * 0.2;
        color = mix(color, tipCol, t);
    }

    // --- Layer 1: Legs with tapered thickness ---
    float dLL = sdSegment(zuv, legTL, legBL);
    float dLR = sdSegment(zuv, legTR, legBR);

    if (dLL < legThick) {
        float t = 1.0 - smoothstep(legThick * 0.4, legThick, dLL);
        vec3 lc = vec3(0.32, 0.22, 0.10);
        float yf = (zuv.y - legTL.y) / (legBL.y - legTL.y);
        lc *= 1.0 - 0.20 * yf; // darker toward floor
        // Wood grain on legs
        lc += sin(yf * 40.0) * 0.02;
        // Inner highlight
        lc += exp(-dLL * 200.0) * 0.06;
        color = mix(color, lc, t);
    }
    if (dLR < legThick) {
        float t = 1.0 - smoothstep(legThick * 0.4, legThick, dLR);
        vec3 lc = vec3(0.32, 0.22, 0.10);
        float yf = (zuv.y - legTR.y) / (legBR.y - legTR.y);
        lc *= 1.0 - 0.20 * yf;
        lc += sin(yf * 40.0) * 0.02;
        lc += exp(-dLR * 200.0) * 0.06;
        color = mix(color, lc, t);
    }

    // Leg-to-cabinet joint: small dark circles
    float dJointL = sdCircle(zuv - legTL, 0.008);
    float dJointR = sdCircle(zuv - legTR, 0.008);
    if (dJointL < 0.003) {
        color = mix(color, vec3(0.22, 0.15, 0.08), smoothstep(0.003, -0.002, dJointL));
    }
    if (dJointR < 0.003) {
        color = mix(color, vec3(0.22, 0.15, 0.08), smoothstep(0.003, -0.002, dJointR));
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

        vec3 sideCol;
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
        color = mix(color, sideCol, ef * frontMask);
    }

    // Back face edge highlight (rim where back meets side)
    if (dBack > -0.010 && dBack < 0.005 && dCab > 0.0) {
        float rimA = smoothstep(0.005, 0.001, dBack) * smoothstep(-0.010, -0.005, dBack);
        vec3 rimCol = vec3(0.30, 0.22, 0.08);
        color = mix(color, rimCol, rimA * 0.55);
    }

    // --- Layer 2: Cabinet front face ---
    if (dCab < 0.004) {
        float ef = smoothstep(0.004, -0.007, dCab);
        vec3 cab = cabinetSurface(zuv * 3.0);

        // Edge darkening (front face bevel)
        float ed = smoothstep(-0.007, -0.035, dCab);
        cab *= 0.80 + 0.20 * ed;

        // Top highlight (overhead light)
        cab += smoothstep(0.15, -0.30, zuv.y) * 0.07;

        // Subtle left-to-right light gradient
        cab += zuv.x * 0.03;

        color = mix(color, cab, ef);
    }

    // Brass trim ring around cabinet edge
    if (dCab > -0.012 && dCab < 0.005) {
        float trimA = smoothstep(0.005, 0.001, dCab) * smoothstep(-0.012, -0.007, dCab);
        vec3 brass = vec3(0.70, 0.55, 0.22);
        // Specular along top edge
        brass += smoothstep(0.001, -0.004, dCab) * 0.10;
        // Brighter on top
        brass += smoothstep(0.0, -0.3, zuv.y) * 0.08;
        color = mix(color, brass, trimA * 0.78);
    }

    // --- Layer 3: Screen bezel (deep recess) ---
    float dBez = sdRoundBox(zuv - bezC, bezSize, bezR);
    if (dBez < 0.004) {
        float ef = smoothstep(0.004, -0.005, dBez);
        vec3 bc = vec3(0.07, 0.06, 0.05);

        // Inner bevel: lighter on top edge (overhead light), darker on bottom
        float bev = smoothstep(-0.005, -0.018, dBez) * 0.07;
        bc += bev * ((zuv.y - bezC.y < 0.0) ? 1.3 : 0.15);

        // Depth shadow at the edges of the recess
        float depthShad = smoothstep(-0.030, -0.010, dBez) * 0.05;
        bc -= depthShad;

        // Bezel screws (4 corners)
        vec2 bezCorners[4] = vec2[4](
            bezC + vec2(-bezSize.x + 0.015, -bezSize.y + 0.015),
            bezC + vec2( bezSize.x - 0.015, -bezSize.y + 0.015),
            bezC + vec2(-bezSize.x + 0.015,  bezSize.y - 0.015),
            bezC + vec2( bezSize.x - 0.015,  bezSize.y - 0.015)
        );
        for (int si = 0; si < 4; si++) {
            float dScrew = sdCircle(zuv - bezCorners[si], 0.004);
            if (dScrew < 0.002) {
                float sf = smoothstep(0.002, -0.001, dScrew);
                vec3 screwCol = vec3(0.30, 0.28, 0.25);
                // Slot line
                screwCol -= smoothstep(0.001, 0.0, abs(zuv.x - bezCorners[si].x)) * 0.08;
                bc = mix(bc, screwCol, sf);
            }
        }

        color = mix(color, bc, ef);
    }

    // --- Layer 4: TV Screen (CRT with static + swatches) ---
    float dScr = sdRoundBox(zuv - scrC, scrSize, scrR);
    if (dScr < 0.003) {
        float ef = smoothstep(0.003, -0.005, dScr);

        // Screen-local coordinates
        vec2 sL = (zuv - scrC);
        vec2 sN = sL / scrSize;

        // CRT barrel distortion: screen content curves outward
        vec2 crt = sN;
        float r2 = dot(crt, crt);
        crt *= 1.0 + 0.06 * r2 + 0.02 * r2 * r2;

        // TV static background with CRT-applied distortion
        vec2 staticUV = crt * scrSize + scrC;
        vec3 sc = vec3(1.0, 1.0, 1.0) * tvStatic(staticUV, iTime);

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
                vec2 sp = crt - vec2(cx, cy);
                vec2 sb = vec2(swW * 0.5, swH * 0.5);

                float dSw = sdRoundBox(sp, sb, 0.04);
                float sScale = min(scrSize.x, scrSize.y);
                float dPx = dSw * sScale;

                // Drop shadow behind each swatch
                float shad = smoothstep(0.008, 0.0, dPx - 0.006) * 0.30;
                sc = mix(sc, vec3(0.0, 0.0, 0.0), shad);

                if (dPx < 0.003) {
                    float ff = smoothstep(0.003, -0.004, dPx);
                    vec3 swatchCol = COLORS[idx];
                    // Slight CRT phosphor variation within swatch
                    swatchCol *= 0.95 + 0.05 * sin(crt.y * scrSize.y * 600.0);
                    sc = mix(sc, swatchCol, ff);
                }

                // Selection indicator
                if (idx == selected) {
                    // Steady white border (no pulsing)
                    float band = smoothstep(0.012, 0.006, abs(dPx));
                    sc = mix(sc, vec3(1.0, 1.0, 1.0), band);
                    // Color-matched glow outside the border
                    float glow = exp(-abs(dPx) * 55.0) * 0.45;
                    sc += COLORS[idx] * glow;
                } else {
                    // Subtle thin border on unselected
                    float brd = exp(-abs(dPx) * 300.0) * 0.12;
                    sc += vec3(0.15, 0.15, 0.15) * brd;
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
        sc += vec3(0.12, 0.12, 0.14) * refl;

        // Second subtle reflection (smaller, offset)
        float refl2 = smoothstep(0.015, 0.0, abs(sN.x + sN.y * 0.8 - 0.35));
        refl2 *= smoothstep(1.0, 0.5, length(sN));
        sc += vec3(0.04, 0.04, 0.05) * refl2;

        color = mix(color, sc, ef);
    }

    // --- Layer 4.5: Screen glow bleeding onto bezel ---
    if (dScr > 0.0 && dScr < 0.025) {
        vec3 selCol = COLORS[selected];
        float glowStr = exp(-dScr * 80.0) * 0.08;
        color += selCol * glowStr;
    }

    // --- Layer 5: Control panel ---
    float dPanel = sdRoundBox(zuv - panelC, panelSize, 0.008);
    if (dPanel < 0.003) {
        float ef = smoothstep(0.003, -0.005, dPanel);
        vec3 pc = vec3(0.12, 0.10, 0.09);

        vec2 pl = zuv - panelC;
        // Brushed metal texture
        float lines = sin(pl.y * 500.0) * 0.5 + 0.5;
        lines *= smoothstep(panelSize.x * 0.85, panelSize.x * 0.25, abs(pl.x));
        pc += vec3(0.035, 0.030, 0.022) * lines;

        // Slight reflection gradient
        pc += smoothstep(panelSize.x, 0.0, abs(pl.x)) * 0.015;

        // Handle bar
        float dH = sdRoundBox(pl, handleSize, 0.004);
        if (dH < 0.003) {
            float hf = smoothstep(0.003, -0.002, dH);
            vec3 handleCol = vec3(0.44, 0.37, 0.23);
            // Highlight along top edge of handle
            handleCol += smoothstep(0.002, -0.001, dH) * 0.08;
            pc = mix(pc, handleCol, hf);
        }

        color = mix(color, pc, ef);
    }

    // --- Layer 5.5: Control knobs (channel/volume) ---
    // Knob 1 (channel selector)
    float dK1 = sdCircle(zuv - knob1C, knobR);
    if (dK1 < 0.005) {
        float ef = smoothstep(0.005, -0.003, dK1);
        vec3 kc = vec3(0.25, 0.22, 0.18);

        // Knurled edge (ridged grip)
        float angle1 = atan(zuv.y - knob1C.y, zuv.x - knob1C.x);
        float ridges = sin(angle1 * 24.0) * 0.5 + 0.5;
        float ridgeMask = smoothstep(-0.003, 0.001, dK1); // only on outer ring
        kc += vec3(0.06, 0.05, 0.04) * ridges * ridgeMask;

        // Center cap
        float dKCap1 = sdCircle(zuv - knob1C, knobR * 0.5);
        if (dKCap1 < 0.002) {
            kc = mix(kc, vec3(0.35, 0.30, 0.22), smoothstep(0.002, -0.001, dKCap1));
        }

        // Position indicator line
        float indLine = sdSegment(zuv, knob1C, knob1C + vec2(0.0, -knobR * 0.85));
        if (indLine < 0.002) {
            kc = mix(kc, vec3(0.9, 0.9, 0.9), smoothstep(0.002, 0.0, indLine) * 0.7);
        }

        // Specular highlight
        kc += exp(-dK1 * 100.0) * 0.12;

        color = mix(color, kc, ef);
    }

    // Knob 2 (volume)
    float dK2 = sdCircle(zuv - knob2C, knobR);
    if (dK2 < 0.005) {
        float ef = smoothstep(0.005, -0.003, dK2);
        vec3 kc = vec3(0.25, 0.22, 0.18);

        float angle2 = atan(zuv.y - knob2C.y, zuv.x - knob2C.x);
        float ridges = sin(angle2 * 24.0) * 0.5 + 0.5;
        float ridgeMask = smoothstep(-0.003, 0.001, dK2);
        kc += vec3(0.06, 0.05, 0.04) * ridges * ridgeMask;

        float dKCap2 = sdCircle(zuv - knob2C, knobR * 0.5);
        if (dKCap2 < 0.002) {
            kc = mix(kc, vec3(0.35, 0.30, 0.22), smoothstep(0.002, -0.001, dKCap2));
        }

        // Volume indicator: rotated ~45 degrees
        vec2 volDir = vec2(0.707, -0.707);
        float indLine2 = sdSegment(zuv, knob2C, knob2C + volDir * knobR * 0.85);
        if (indLine2 < 0.002) {
            kc = mix(kc, vec3(0.9, 0.9, 0.9), smoothstep(0.002, 0.0, indLine2) * 0.7);
        }

        kc += exp(-dK2 * 100.0) * 0.12;
        color = mix(color, kc, ef);
    }

    // --- Layer 5.6: Power LED ---
    float dLed = sdCircle(zuv - ledC, ledR);
    if (dLed < 0.006) {
        float ef = smoothstep(0.006, -0.001, dLed);
        vec3 ledCol = vec3(0.1, 0.9, 0.1); // green LED
        // Glow halo
        float ledGlow = exp(-abs(dLed) * 300.0) * 0.5;
        vec3 ledFinal = mix(vec3(0.03, 0.03, 0.02), ledCol, smoothstep(0.003, 0.0, dLed));
        ledFinal += ledCol * ledGlow;
        color = mix(color, ledFinal, ef);
    }

    // --- Layer 6: Speaker grilles ---
    float dSL = sdCircle(zuv - spkL, speakerR);
    float dSR2 = sdCircle(zuv - spkR, speakerR);

    if (dSL < 0.004) {
        float ef = smoothstep(0.004, -0.003, dSL);
        vec3 sc = vec3(0.16, 0.13, 0.10);

        // Concentric speaker rings
        float ringDist = length(zuv - spkL);
        float rings = sin(ringDist * 500.0) * 0.5 + 0.5;
        sc += vec3(0.04, 0.035, 0.025) * rings;

        // Speaker cone: darker center
        float cone = smoothstep(speakerR * 0.6, speakerR * 0.2, ringDist);
        sc *= 1.0 - 0.25 * cone;

        // Dust cap (tiny center bump)
        float dustCap = smoothstep(speakerR * 0.15, 0.0, ringDist);
        sc += vec3(0.06, 0.05, 0.04) * dustCap;

        // Metallic rim highlight
        sc += exp(-abs(dSL) * 350.0) * 0.18;

        color = mix(color, sc, ef);
    }
    if (dSR2 < 0.004) {
        float ef = smoothstep(0.004, -0.003, dSR2);
        vec3 sc = vec3(0.16, 0.13, 0.10);

        float ringDist = length(zuv - spkR);
        float rings = sin(ringDist * 500.0) * 0.5 + 0.5;
        sc += vec3(0.04, 0.035, 0.025) * rings;

        float cone = smoothstep(speakerR * 0.6, speakerR * 0.2, ringDist);
        sc *= 1.0 - 0.25 * cone;

        float dustCap = smoothstep(speakerR * 0.15, 0.0, ringDist);
        sc += vec3(0.06, 0.05, 0.04) * dustCap;

        sc += exp(-abs(dSR2) * 350.0) * 0.18;

        color = mix(color, sc, ef);
    }

    // --- Cabinet rim highlight (catches ambient light) ---
    if (dCab > -0.025 && dCab < 0.012) {
        float rim = exp(-abs(dCab) * 160.0) * 0.12;
        // Brighter on top and right edges
        float topBias = smoothstep(0.2, -0.3, zuv.y) * 0.6 + 0.4;
        float rightBias = smoothstep(-0.2, 0.3, zuv.x) * 0.3 + 0.7;
        color += vec3(0.28, 0.20, 0.08) * rim * topBias * rightBias;
    }

    // --- Phase 3 (powerOff 0.8 - 1.0): Phosphor dot fade to black ---
    if (powerOff > 0.8) {
        float fadeT = clamp((powerOff - 0.8) / 0.2, 0.0, 1.0);
        // Scene fades out
        color *= (1.0 - fadeT);
        // Phosphor persistence: bright center dot that lingers briefly
        float centerDist = length(uv);  // use original uv, not zuv
        float phosphorGlow = exp(-centerDist * 25.0) * (1.0 - fadeT * fadeT) * 0.6;
        color += vec3(1.0, 1.0, 1.0) * phosphorGlow;
    }

    // Full black at end of animation
    if (powerOff > 0.99) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
