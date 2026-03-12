// REDPILL-NEO-GHOSTTY.GLSL - 3D Box Corridor with MATRIX SHADER logo
// Ported from Redpill-Neo.hlsl for Ghostty

#define RAIN_SPEED       0.7
#define GLOW_STRENGTH    1.0
#define GRID_LINES       0.008
#define WALL_COLUMNS     30.0
#define FLOOR_ROWS       20.0
#define DENSITY          0.6
#define TEXT_HEIGHT      0.08
#define TEXT_THICKNESS   0.012
#define TEXT_DEPTH       0.012

// Back wall rectangle dimensions (in UV space, centered at origin)
#define BACK_WALL_WIDTH  0.12
#define BACK_WALL_HEIGHT 0.22


const uint GLYPHS[16] = uint[16](
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
);

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

float getGlyphPixel(int glyph_idx, vec2 local_uv) {
    glyph_idx = glyph_idx & 15;
    int px = clamp(int(local_uv.x * 5.0), 0, 4);
    int py = clamp(int(local_uv.y * 7.0), 0, 6);
    int bit_idx = py * 5 + px;
    return float((GLYPHS[glyph_idx] >> uint(bit_idx)) & 1u);
}

// SDF for a box
float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// SDF for individual letters using line segments
float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Letter M
float sdLetterM(vec2 p, float h) {
    float w = h * 0.7;
    float d = 1e10;
    d = min(d, sdSegment(p, vec2(-w, -h), vec2(-w, h)));
    d = min(d, sdSegment(p, vec2(w, -h), vec2(w, h)));
    d = min(d, sdSegment(p, vec2(-w, h), vec2(0, 0)));
    d = min(d, sdSegment(p, vec2(w, h), vec2(0, 0)));
    return d;
}

// Letter A
float sdLetterA(vec2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, vec2(-w, -h), vec2(0, h)));
    d = min(d, sdSegment(p, vec2(w, -h), vec2(0, h)));
    d = min(d, sdSegment(p, vec2(-w*0.5, 0), vec2(w*0.5, 0)));
    return d;
}

// Letter T
float sdLetterT(vec2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, vec2(0, -h), vec2(0, h)));
    d = min(d, sdSegment(p, vec2(-w, h), vec2(w, h)));
    return d;
}

// Letter R
float sdLetterR(vec2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, vec2(-w, -h), vec2(-w, h)));
    d = min(d, sdSegment(p, vec2(-w, h), vec2(w*0.7, h)));
    d = min(d, sdSegment(p, vec2(w*0.7, h), vec2(w*0.7, h*0.2)));
    d = min(d, sdSegment(p, vec2(w*0.7, h*0.2), vec2(-w, h*0.2)));
    d = min(d, sdSegment(p, vec2(-w, h*0.2), vec2(w, -h)));
    return d;
}

// Letter I
float sdLetterI(vec2 p, float h) {
    float w = h * 0.3;
    float d = 1e10;
    d = min(d, sdSegment(p, vec2(0, -h), vec2(0, h)));
    d = min(d, sdSegment(p, vec2(-w, h), vec2(w, h)));
    d = min(d, sdSegment(p, vec2(-w, -h), vec2(w, -h)));
    return d;
}

// Letter X
float sdLetterX(vec2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, vec2(-w, -h), vec2(w, h)));
    d = min(d, sdSegment(p, vec2(w, -h), vec2(-w, h)));
    return d;
}

// Letter S
float sdLetterS(vec2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, vec2(w, h), vec2(-w*0.5, h)));
    d = min(d, sdSegment(p, vec2(-w*0.5, h), vec2(-w, h*0.5)));
    d = min(d, sdSegment(p, vec2(-w, h*0.5), vec2(w, 0)));
    d = min(d, sdSegment(p, vec2(w, 0), vec2(w, -h*0.5)));
    d = min(d, sdSegment(p, vec2(w, -h*0.5), vec2(-w, -h)));
    return d;
}

// Letter H
float sdLetterH(vec2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, vec2(-w, -h), vec2(-w, h)));
    d = min(d, sdSegment(p, vec2(w, -h), vec2(w, h)));
    d = min(d, sdSegment(p, vec2(-w, 0), vec2(w, 0)));
    return d;
}

// Letter D
float sdLetterD(vec2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, vec2(-w, -h), vec2(-w, h)));
    d = min(d, sdSegment(p, vec2(-w, h), vec2(w*0.3, h)));
    d = min(d, sdSegment(p, vec2(w*0.3, h), vec2(w, 0)));
    d = min(d, sdSegment(p, vec2(w, 0), vec2(w*0.3, -h)));
    d = min(d, sdSegment(p, vec2(w*0.3, -h), vec2(-w, -h)));
    return d;
}

// Letter E
float sdLetterE(vec2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, vec2(-w, -h), vec2(-w, h)));
    d = min(d, sdSegment(p, vec2(-w, h), vec2(w, h)));
    d = min(d, sdSegment(p, vec2(-w, 0), vec2(w*0.7, 0)));
    d = min(d, sdSegment(p, vec2(-w, -h), vec2(w, -h)));
    return d;
}

// Get distance to MATRIX text
float sdMATRIX(vec2 p, float h, float spacing) {
    float d = 1e10;
    float w = h * 0.7;
    float offset = -2.5 * (w + spacing);

    d = min(d, sdLetterM(p - vec2(offset + 0.0*(w+spacing), 0), h));
    d = min(d, sdLetterA(p - vec2(offset + 1.0*(w+spacing), 0), h));
    d = min(d, sdLetterT(p - vec2(offset + 2.0*(w+spacing), 0), h));
    d = min(d, sdLetterR(p - vec2(offset + 3.0*(w+spacing), 0), h));
    d = min(d, sdLetterI(p - vec2(offset + 4.0*(w+spacing), 0), h));
    d = min(d, sdLetterX(p - vec2(offset + 5.0*(w+spacing), 0), h));
    return d;
}

// Get distance to SHADER text
float sdSHADER(vec2 p, float h, float spacing) {
    float d = 1e10;
    float w = h * 0.7;
    float offset = -2.5 * (w + spacing);

    d = min(d, sdLetterS(p - vec2(offset + 0.0*(w+spacing), 0), h));
    d = min(d, sdLetterH(p - vec2(offset + 1.0*(w+spacing), 0), h));
    d = min(d, sdLetterA(p - vec2(offset + 2.0*(w+spacing), 0), h));
    d = min(d, sdLetterD(p - vec2(offset + 3.0*(w+spacing), 0), h));
    d = min(d, sdLetterE(p - vec2(offset + 4.0*(w+spacing), 0), h));
    d = min(d, sdLetterR(p - vec2(offset + 5.0*(w+spacing), 0), h));
    return d;
}

// Draw 3D outline text
vec3 DrawLogoText(vec2 uv) {
    // Flip Y to correct orientation (shader Y increases downward)
    uv.y = -uv.y;

    float h = TEXT_HEIGHT;
    float spacing = h * 0.5;

    // MATRIX above center, SHADER below
    vec2 matrixPos = vec2(0.0, 0.12);
    vec2 shaderPos = vec2(0.0, -0.12);

    float dMatrix = sdMATRIX(uv - matrixPos, h, spacing);
    float dShader = sdSHADER(uv - shaderPos, h, spacing);

    // 3D depth effect - draw offset copies behind (outlines only)
    vec3 color = vec3(0, 0, 0);

    // Back shadow/depth layers - just outlines
    for (int i = 4; i >= 1; i--) {
        vec2 depthOffset = vec2(1, -1) * TEXT_DEPTH * float(i);
        float dMatrixBack = sdMATRIX(uv - matrixPos - depthOffset, h, spacing);
        float dShaderBack = sdSHADER(uv - shaderPos - depthOffset, h, spacing);

        // Outline only - peak at the edge, transparent inside and outside
        float backEdge = exp(-abs(dMatrixBack - TEXT_THICKNESS) * 150.0);
        backEdge = max(backEdge, exp(-abs(dShaderBack - TEXT_THICKNESS) * 150.0));

        float depth = float(i) / 5.0;
        color += vec3(0.0, 0.2 * (1.0 - depth), 0.06) * backEdge * 0.45;
    }

    // Front edge glow - bright at the stroke edge, transparent middle
    float edgeMatrix = exp(-abs(dMatrix - TEXT_THICKNESS * 0.5) * 200.0);
    float edgeShader = exp(-abs(dShader - TEXT_THICKNESS * 0.5) * 200.0);
    float edge = max(edgeMatrix, edgeShader);
    color += vec3(0.36, 0.9, 0.45) * edge;

    // Outer glow - fades outward from edge
    float outerGlow = exp(-max(dMatrix - TEXT_THICKNESS, 0.0) * 60.0);
    outerGlow = max(outerGlow, exp(-max(dShader - TEXT_THICKNESS, 0.0) * 60.0));
    color += vec3(0.0, 0.36, 0.09) * outerGlow * 0.54;

    return color;
}

// Vertical falling rain (for walls)
vec3 DrawWallRain(vec2 wall_uv, float depth, float seed) {
    vec2 grid = wall_uv * vec2(WALL_COLUMNS, 50.0);
    vec2 cell_id = floor(grid);
    vec2 local_uv = fract(grid);

    float col_rnd = random(vec2(cell_id.x + seed, seed));
    if (col_rnd > DENSITY) return vec3(0, 0, 0);

    float speed = (col_rnd * 0.5 + 0.5) * RAIN_SPEED * 10.0;
    float rain_pos = cell_id.y - iTime * speed + col_rnd * 100.0;
    float cycle = fract(rain_pos * 0.025);
    float trail = pow(cycle, 5.0);

    float char_seed = random(cell_id + floor(iTime * 3.5) + seed);
    int glyph_idx = int(char_seed * 16.0);

    vec2 padded = (local_uv - 0.1) / 0.8;
    padded = clamp(padded, 0.0, 1.0);
    float glyph = getGlyphPixel(glyph_idx, padded);
    float border = step(0.1, local_uv.x) * step(local_uv.x, 0.9) * step(0.05, local_uv.y) * step(local_uv.y, 0.95);
    float shape = glyph * border;

    float is_head = step(0.93, cycle);
    vec3 color = mix(vec3(0.0, 0.8, 0.2), vec3(0.9, 1.0, 0.9), is_head);

    float depth_fade = exp(-depth * 0.8);
    return color * shape * trail * depth_fade;
}

// Floor/ceiling code
vec3 DrawFloorCode(vec2 floor_uv, float depth, float seed, float brightness) {
    float perspective_scale = 1.0 / (depth + 0.1);
    vec2 grid = floor_uv * vec2(WALL_COLUMNS * perspective_scale, FLOOR_ROWS);
    vec2 cell_id = floor(grid);
    vec2 local_uv = fract(grid);

    float col_rnd = random(vec2(cell_id.x + seed, cell_id.y + seed * 3.0));
    if (col_rnd > DENSITY) return vec3(0, 0, 0);

    float char_seed = random(cell_id + floor(iTime * 2.0) + seed);
    int glyph_idx = int(char_seed * 16.0);

    vec2 padded = (local_uv - 0.15) / 0.7;
    padded = clamp(padded, 0.0, 1.0);
    float glyph = getGlyphPixel(glyph_idx, padded);
    float border = step(0.15, local_uv.x) * step(local_uv.x, 0.85) * step(0.1, local_uv.y) * step(local_uv.y, 0.9);
    float shape = glyph * border;

    float depth_fade = exp(-depth * 1.2) * brightness;
    float flicker = 0.8 + 0.2 * sin(iTime * 2.0 + cell_id.x * 0.5);

    return vec3(0.0, 0.75, 0.2) * shape * depth_fade * flicker;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec3 totalColor = vec3(0, 0, 0);

    vec2 uv = fragCoord / iResolution.xy - 0.5;
    // Flip Y to match HLSL coordinate system (HLSL tex Y=0 at top, GL Y=0 at bottom)
    uv.y = -uv.y;
    float aspect = iResolution.x / iResolution.y;
    uv.x *= aspect;

    // Back wall rectangle bounds (aspect-corrected)
    float backW = BACK_WALL_WIDTH * aspect;
    float backH = BACK_WALL_HEIGHT;

    vec3 surfaceColor = vec3(0, 0, 0);
    float wireframe = 0.0;

    // Check if we're inside the back wall rectangle
    bool inBackWall = (abs(uv.x) < backW) && (abs(uv.y) < backH);

    if (inBackWall) {
        // Back wall - static grid with subtle code
        vec2 back_uv = (uv + vec2(backW, backH)) / vec2(backW * 2.0, backH * 2.0);
        surfaceColor = DrawFloorCode(back_uv, 0.0, 500.0, 0.3);

        // Grid on back wall
        float grid_x = fract(back_uv.x * 8.0);
        float grid_y = fract(back_uv.y * 12.0);
        wireframe = (step(grid_x, GRID_LINES * 2.0) + step(1.0 - GRID_LINES * 2.0, grid_x)) * 0.2;
        wireframe += (step(grid_y, GRID_LINES * 2.0) + step(1.0 - GRID_LINES * 2.0, grid_y)) * 0.2;
    } else {
        // Determine which surface we're on using ratio comparison
        float screenW = 0.5 * aspect;
        float screenH = 0.5;

        // Ratio determines wall vs floor/ceiling boundary
        float ratioX = abs(uv.x) / backW;
        float ratioY = abs(uv.y) / backH;

        float depth;

        if (ratioX > ratioY) {
            // Left or right wall
            float wall_x = (uv.x > 0.0) ? 1.0 : 0.0;

            // Depth: from back wall (x = backW) to screen edge (x = screenW)
            depth = (abs(uv.x) - backW) / (screenW - backW);
            depth = clamp(depth, 0.0, 1.0);

            // V coordinate: interpolate y from back wall height to screen height
            float edgeY = backH + (screenH - backH) * depth;
            float wall_v = (uv.y + edgeY) / (edgeY * 2.0);

            vec2 wall_uv = vec2(depth * 5.0, wall_v * 8.0);
            surfaceColor = DrawWallRain(wall_uv, 1.0 - depth, wall_x * 100.0 + 50.0);

            // Wireframe
            float grid_x = fract(wall_uv.x * 3.0);
            wireframe = (step(grid_x, GRID_LINES) + step(1.0 - GRID_LINES, grid_x)) * 0.3;
            float persp_line = fract(depth * 15.0);
            wireframe += (step(persp_line, GRID_LINES * 2.0)) * 0.2 * (1.0 - depth);
        } else {
            // Floor or ceiling
            float is_floor = (uv.y < 0.0) ? 1.0 : 0.0;

            // Depth: from back wall (y = backH) to screen edge (y = screenH)
            depth = (abs(uv.y) - backH) / (screenH - backH);
            depth = clamp(depth, 0.0, 1.0);

            // H coordinate: interpolate x from back wall width to screen width
            float edgeX = backW + (screenW - backW) * depth;
            float floor_h = (uv.x + edgeX) / (edgeX * 2.0);

            vec2 floor_uv = vec2(floor_h, depth * 4.0);
            float brightness = is_floor > 0.5 ? 0.7 : 0.5;
            surfaceColor = DrawFloorCode(floor_uv, 1.0 - depth, is_floor * 200.0 + 300.0, brightness);

            // Wireframe
            float grid_y = fract(depth * 12.0);
            wireframe = (step(grid_y, GRID_LINES * 2.0)) * 0.25 * (1.0 - depth);
            float grid_x = fract(floor_h * 8.0);
            wireframe += (step(grid_x, GRID_LINES) + step(1.0 - GRID_LINES, grid_x)) * 0.15;
        }
    }

    totalColor = surfaceColor + vec3(0.0, 0.4, 0.1) * wireframe;

    // Draw the 4 perspective edge lines along ratio boundary (ratioX == ratioY)
    float screenW = 0.5 * aspect;
    float screenH = 0.5;
    float slope = backH / backW;

    // Top-right line
    vec2 trBack = vec2(backW, backH);
    vec2 trEnd = vec2(screenW, backH + (screenW - backW) * slope);
    if (trEnd.y > screenH) trEnd = vec2(backW + (screenH - backH) / slope, screenH);
    float distTR = sdSegment(uv, trBack, trEnd);

    // Top-left line
    vec2 tlBack = vec2(-backW, backH);
    vec2 tlEnd = vec2(-screenW, backH + (screenW - backW) * slope);
    if (tlEnd.y > screenH) tlEnd = vec2(-backW - (screenH - backH) / slope, screenH);
    float distTL = sdSegment(uv, tlBack, tlEnd);

    // Bottom-right line
    vec2 brBack = vec2(backW, -backH);
    vec2 brEnd = vec2(screenW, -backH - (screenW - backW) * slope);
    if (brEnd.y < -screenH) brEnd = vec2(backW + (screenH - backH) / slope, -screenH);
    float distBR = sdSegment(uv, brBack, brEnd);

    // Bottom-left line
    vec2 blBack = vec2(-backW, -backH);
    vec2 blEnd = vec2(-screenW, -backH - (screenW - backW) * slope);
    if (blEnd.y < -screenH) blEnd = vec2(-backW - (screenH - backH) / slope, -screenH);
    float distBL = sdSegment(uv, blBack, blEnd);

    float minEdgeDist = min(min(distTL, distTR), min(distBL, distBR));
    float edge_line = exp(-minEdgeDist * 150.0) * 0.6;
    totalColor += vec3(0.0, 0.6, 0.2) * edge_line;

    // Back wall rectangle outline
    float backOutline = sdBox(uv, vec2(backW, backH));
    float backEdge = exp(-abs(backOutline) * 200.0) * 0.4;
    totalColor += vec3(0.0, 0.5, 0.15) * backEdge;

    // Center glow (behind text)
    float dist = length(uv);
    float center_glow = exp(-dist * 6.0) * 0.4;
    totalColor += vec3(0.1, 0.3, 0.12) * center_glow;

    // MATRIX SHADER logo text (on top)
    vec3 logoText = DrawLogoText(uv);
    totalColor += logoText;

    // Depth fog
    float fog = exp(-dist * 2.0) * 0.1;
    totalColor += vec3(0.03, 0.12, 0.05) * fog;

    totalColor *= GLOW_STRENGTH;

    // Use original GL coordinates for texture (not flipped UV)
    vec2 tex_uv = fragCoord / iResolution.xy;
    vec4 text = texture(iChannel0, tex_uv);
    fragColor = text + vec4(totalColor, 0.0);
}
