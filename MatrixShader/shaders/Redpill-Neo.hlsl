// REDPILL-NEO.HLSL - 3D Box Corridor with MATRIX SHADER logo
// Proper hallway perspective with rectangular back wall

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

Texture2D shaderTexture;
SamplerState samplerState;
cbuffer PixelShaderSettings {
    float Time;
    float Scale;
    float2 Resolution;
    float4 Background;
};

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

float random(float2 uv) {
    return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453123);
}

float getGlyphPixel(int glyph_idx, float2 local_uv) {
    glyph_idx = glyph_idx & 15;
    int px = clamp(int(local_uv.x * 5.0), 0, 4);
    int py = clamp(int(local_uv.y * 7.0), 0, 6);
    int bit_idx = py * 5 + px;
    return float((GLYPHS[glyph_idx] >> bit_idx) & 1u);
}

// SDF for a box
float sdBox(float2 p, float2 b) {
    float2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// SDF for individual letters using line segments
float sdSegment(float2 p, float2 a, float2 b) {
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Letter M
float sdLetterM(float2 p, float h) {
    float w = h * 0.7;
    float d = 1e10;
    d = min(d, sdSegment(p, float2(-w, -h), float2(-w, h)));           // left vertical
    d = min(d, sdSegment(p, float2(w, -h), float2(w, h)));             // right vertical
    d = min(d, sdSegment(p, float2(-w, h), float2(0, 0)));             // left diagonal
    d = min(d, sdSegment(p, float2(w, h), float2(0, 0)));              // right diagonal
    return d;
}

// Letter A
float sdLetterA(float2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, float2(-w, -h), float2(0, h)));            // left diagonal
    d = min(d, sdSegment(p, float2(w, -h), float2(0, h)));             // right diagonal
    d = min(d, sdSegment(p, float2(-w*0.5, 0), float2(w*0.5, 0)));     // crossbar
    return d;
}

// Letter T
float sdLetterT(float2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, float2(0, -h), float2(0, h)));             // vertical
    d = min(d, sdSegment(p, float2(-w, h), float2(w, h)));             // top bar
    return d;
}

// Letter R
float sdLetterR(float2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, float2(-w, -h), float2(-w, h)));           // vertical
    d = min(d, sdSegment(p, float2(-w, h), float2(w*0.7, h)));         // top bar
    d = min(d, sdSegment(p, float2(w*0.7, h), float2(w*0.7, h*0.2)));  // right top
    d = min(d, sdSegment(p, float2(w*0.7, h*0.2), float2(-w, h*0.2))); // middle bar
    d = min(d, sdSegment(p, float2(-w, h*0.2), float2(w, -h)));        // leg
    return d;
}

// Letter I
float sdLetterI(float2 p, float h) {
    float w = h * 0.3;
    float d = 1e10;
    d = min(d, sdSegment(p, float2(0, -h), float2(0, h)));             // vertical
    d = min(d, sdSegment(p, float2(-w, h), float2(w, h)));             // top bar
    d = min(d, sdSegment(p, float2(-w, -h), float2(w, -h)));           // bottom bar
    return d;
}

// Letter X
float sdLetterX(float2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, float2(-w, -h), float2(w, h)));            // diagonal 1
    d = min(d, sdSegment(p, float2(w, -h), float2(-w, h)));            // diagonal 2
    return d;
}

// Letter S
float sdLetterS(float2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, float2(w, h), float2(-w*0.5, h)));         // top bar
    d = min(d, sdSegment(p, float2(-w*0.5, h), float2(-w, h*0.5)));    // top left curve
    d = min(d, sdSegment(p, float2(-w, h*0.5), float2(w, 0)));         // middle diagonal
    d = min(d, sdSegment(p, float2(w, 0), float2(w, -h*0.5)));         // bottom right
    d = min(d, sdSegment(p, float2(w, -h*0.5), float2(-w, -h)));       // bottom bar
    return d;
}

// Letter H
float sdLetterH(float2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, float2(-w, -h), float2(-w, h)));           // left vertical
    d = min(d, sdSegment(p, float2(w, -h), float2(w, h)));             // right vertical
    d = min(d, sdSegment(p, float2(-w, 0), float2(w, 0)));             // crossbar
    return d;
}

// Letter D
float sdLetterD(float2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, float2(-w, -h), float2(-w, h)));           // left vertical
    d = min(d, sdSegment(p, float2(-w, h), float2(w*0.3, h)));         // top
    d = min(d, sdSegment(p, float2(w*0.3, h), float2(w, 0)));          // top curve
    d = min(d, sdSegment(p, float2(w, 0), float2(w*0.3, -h)));         // bottom curve
    d = min(d, sdSegment(p, float2(w*0.3, -h), float2(-w, -h)));       // bottom
    return d;
}

// Letter E
float sdLetterE(float2 p, float h) {
    float w = h * 0.5;
    float d = 1e10;
    d = min(d, sdSegment(p, float2(-w, -h), float2(-w, h)));           // vertical
    d = min(d, sdSegment(p, float2(-w, h), float2(w, h)));             // top bar
    d = min(d, sdSegment(p, float2(-w, 0), float2(w*0.7, 0)));         // middle bar
    d = min(d, sdSegment(p, float2(-w, -h), float2(w, -h)));           // bottom bar
    return d;
}

// Get distance to MATRIX text
float sdMATRIX(float2 p, float h, float spacing) {
    float d = 1e10;
    float w = h * 0.7;
    float offset = -2.5 * (w + spacing);

    d = min(d, sdLetterM(p - float2(offset + 0.0*(w+spacing), 0), h));
    d = min(d, sdLetterA(p - float2(offset + 1.0*(w+spacing), 0), h));
    d = min(d, sdLetterT(p - float2(offset + 2.0*(w+spacing), 0), h));
    d = min(d, sdLetterR(p - float2(offset + 3.0*(w+spacing), 0), h));
    d = min(d, sdLetterI(p - float2(offset + 4.0*(w+spacing), 0), h));
    d = min(d, sdLetterX(p - float2(offset + 5.0*(w+spacing), 0), h));
    return d;
}

// Get distance to SHADER text
float sdSHADER(float2 p, float h, float spacing) {
    float d = 1e10;
    float w = h * 0.7;
    float offset = -2.5 * (w + spacing);

    d = min(d, sdLetterS(p - float2(offset + 0.0*(w+spacing), 0), h));
    d = min(d, sdLetterH(p - float2(offset + 1.0*(w+spacing), 0), h));
    d = min(d, sdLetterA(p - float2(offset + 2.0*(w+spacing), 0), h));
    d = min(d, sdLetterD(p - float2(offset + 3.0*(w+spacing), 0), h));
    d = min(d, sdLetterE(p - float2(offset + 4.0*(w+spacing), 0), h));
    d = min(d, sdLetterR(p - float2(offset + 5.0*(w+spacing), 0), h));
    return d;
}

// Draw 3D outline text
float3 DrawLogoText(float2 uv) {
    // Flip Y to correct orientation (shader Y increases downward)
    uv.y = -uv.y;

    float h = TEXT_HEIGHT;
    float spacing = h * 0.5;

    // MATRIX above center, SHADER below
    float2 matrixPos = float2(0.0, 0.12);
    float2 shaderPos = float2(0.0, -0.12);

    float dMatrix = sdMATRIX(uv - matrixPos, h, spacing);
    float dShader = sdSHADER(uv - shaderPos, h, spacing);

    // 3D depth effect - draw offset copies behind (outlines only)
    float3 color = float3(0, 0, 0);

    // Back shadow/depth layers - just outlines
    for (int i = 4; i >= 1; i--) {
        float2 depthOffset = float2(1, -1) * TEXT_DEPTH * float(i);
        float dMatrixBack = sdMATRIX(uv - matrixPos - depthOffset, h, spacing);
        float dShaderBack = sdSHADER(uv - shaderPos - depthOffset, h, spacing);

        // Outline only - peak at the edge, transparent inside and outside
        float backEdge = exp(-abs(dMatrixBack - TEXT_THICKNESS) * 150.0);
        backEdge = max(backEdge, exp(-abs(dShaderBack - TEXT_THICKNESS) * 150.0));

        float depth = float(i) / 5.0;
        color += float3(0.0, 0.2 * (1.0 - depth), 0.06) * backEdge * 0.45;
    }

    // Front edge glow - bright at the stroke edge, transparent middle
    float edgeMatrix = exp(-abs(dMatrix - TEXT_THICKNESS * 0.5) * 200.0);
    float edgeShader = exp(-abs(dShader - TEXT_THICKNESS * 0.5) * 200.0);
    float edge = max(edgeMatrix, edgeShader);
    color += float3(0.36, 0.9, 0.45) * edge;

    // Outer glow - fades outward from edge
    float outerGlow = exp(-max(dMatrix - TEXT_THICKNESS, 0.0) * 60.0);
    outerGlow = max(outerGlow, exp(-max(dShader - TEXT_THICKNESS, 0.0) * 60.0));
    color += float3(0.0, 0.36, 0.09) * outerGlow * 0.54;

    return color;
}

// Vertical falling rain (for walls)
float3 DrawWallRain(float2 wall_uv, float depth, float seed) {
    float2 grid = wall_uv * float2(WALL_COLUMNS, 50.0);
    float2 cell_id = floor(grid);
    float2 local_uv = frac(grid);

    float col_rnd = random(float2(cell_id.x + seed, seed));
    if (col_rnd > DENSITY) return float3(0, 0, 0);

    float speed = (col_rnd * 0.5 + 0.5) * RAIN_SPEED * 10.0;
    float rain_pos = cell_id.y - Time * speed + col_rnd * 100.0;
    float cycle = frac(rain_pos * 0.025);
    float trail = pow(cycle, 5.0);

    float char_seed = random(cell_id + floor(Time * 3.5) + seed);
    int glyph_idx = int(char_seed * 16.0);

    float2 padded = (local_uv - 0.1) / 0.8;
    padded = clamp(padded, 0.0, 1.0);
    float glyph = getGlyphPixel(glyph_idx, padded);
    float border = step(0.1, local_uv.x) * step(local_uv.x, 0.9) * step(0.05, local_uv.y) * step(local_uv.y, 0.95);
    float shape = glyph * border;

    float is_head = step(0.93, cycle);
    float3 color = lerp(float3(0.0, 0.8, 0.2), float3(0.9, 1.0, 0.9), is_head);

    float depth_fade = exp(-depth * 0.8);
    return color * shape * trail * depth_fade;
}

// Floor/ceiling code
float3 DrawFloorCode(float2 floor_uv, float depth, float seed, float brightness) {
    float perspective_scale = 1.0 / (depth + 0.1);
    float2 grid = floor_uv * float2(WALL_COLUMNS * perspective_scale, FLOOR_ROWS);
    float2 cell_id = floor(grid);
    float2 local_uv = frac(grid);

    float col_rnd = random(float2(cell_id.x + seed, cell_id.y + seed * 3.0));
    if (col_rnd > DENSITY) return float3(0, 0, 0);

    float char_seed = random(cell_id + floor(Time * 2.0) + seed);
    int glyph_idx = int(char_seed * 16.0);

    float2 padded = (local_uv - 0.15) / 0.7;
    padded = clamp(padded, 0.0, 1.0);
    float glyph = getGlyphPixel(glyph_idx, padded);
    float border = step(0.15, local_uv.x) * step(local_uv.x, 0.85) * step(0.1, local_uv.y) * step(local_uv.y, 0.9);
    float shape = glyph * border;

    float depth_fade = exp(-depth * 1.2) * brightness;
    float flicker = 0.8 + 0.2 * sin(Time * 2.0 + cell_id.x * 0.5);

    return float3(0.0, 0.75, 0.2) * shape * depth_fade * flicker;
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET {
    float3 totalColor = float3(0, 0, 0);

    float2 uv = tex - 0.5;
    float aspect = Resolution.x / Resolution.y;
    uv.x *= aspect;

    // Back wall rectangle bounds (aspect-corrected)
    float backW = BACK_WALL_WIDTH * aspect;
    float backH = BACK_WALL_HEIGHT;

    float3 surfaceColor = float3(0, 0, 0);
    float wireframe = 0.0;

    // Check if we're inside the back wall rectangle
    bool inBackWall = (abs(uv.x) < backW) && (abs(uv.y) < backH);

    if (inBackWall) {
        // Back wall - static grid with subtle code
        float2 back_uv = (uv + float2(backW, backH)) / float2(backW * 2.0, backH * 2.0);
        surfaceColor = DrawFloorCode(back_uv, 0.0, 500.0, 0.3);

        // Grid on back wall
        float grid_x = frac(back_uv.x * 8.0);
        float grid_y = frac(back_uv.y * 12.0);
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

            float2 wall_uv = float2(depth * 5.0, wall_v * 8.0);
            surfaceColor = DrawWallRain(wall_uv, 1.0 - depth, wall_x * 100.0 + 50.0);

            // Wireframe
            float grid_x = frac(wall_uv.x * 3.0);
            wireframe = (step(grid_x, GRID_LINES) + step(1.0 - GRID_LINES, grid_x)) * 0.3;
            float persp_line = frac(depth * 15.0);
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

            float2 floor_uv = float2(floor_h, depth * 4.0);
            float brightness = is_floor > 0.5 ? 0.7 : 0.5;
            surfaceColor = DrawFloorCode(floor_uv, 1.0 - depth, is_floor * 200.0 + 300.0, brightness);

            // Wireframe
            float grid_y = frac(depth * 12.0);
            wireframe = (step(grid_y, GRID_LINES * 2.0)) * 0.25 * (1.0 - depth);
            float grid_x = frac(floor_h * 8.0);
            wireframe += (step(grid_x, GRID_LINES) + step(1.0 - GRID_LINES, grid_x)) * 0.15;
        }
    }

    totalColor = surfaceColor + float3(0.0, 0.4, 0.1) * wireframe;

    // Draw the 4 perspective edge lines along ratio boundary (ratioX == ratioY)
    // These lines go from back wall corners outward at slope backH/backW
    float screenW = 0.5 * aspect;
    float screenH = 0.5;
    float slope = backH / backW;

    // Top-right line: from (backW, backH) toward top-right, slope = backH/backW
    // Extends until it hits screen edge
    float2 trBack = float2(backW, backH);
    float2 trEnd = float2(screenW, backH + (screenW - backW) * slope);
    if (trEnd.y > screenH) trEnd = float2(backW + (screenH - backH) / slope, screenH);
    float distTR = sdSegment(uv, trBack, trEnd);

    // Top-left line: from (-backW, backH) toward top-left
    float2 tlBack = float2(-backW, backH);
    float2 tlEnd = float2(-screenW, backH + (screenW - backW) * slope);
    if (tlEnd.y > screenH) tlEnd = float2(-backW - (screenH - backH) / slope, screenH);
    float distTL = sdSegment(uv, tlBack, tlEnd);

    // Bottom-right line: from (backW, -backH) toward bottom-right
    float2 brBack = float2(backW, -backH);
    float2 brEnd = float2(screenW, -backH - (screenW - backW) * slope);
    if (brEnd.y < -screenH) brEnd = float2(backW + (screenH - backH) / slope, -screenH);
    float distBR = sdSegment(uv, brBack, brEnd);

    // Bottom-left line: from (-backW, -backH) toward bottom-left
    float2 blBack = float2(-backW, -backH);
    float2 blEnd = float2(-screenW, -backH - (screenW - backW) * slope);
    if (blEnd.y < -screenH) blEnd = float2(-backW - (screenH - backH) / slope, -screenH);
    float distBL = sdSegment(uv, blBack, blEnd);

    float minEdgeDist = min(min(distTL, distTR), min(distBL, distBR));
    float edge_line = exp(-minEdgeDist * 150.0) * 0.6;
    totalColor += float3(0.0, 0.6, 0.2) * edge_line;

    // Back wall rectangle outline
    float backOutline = sdBox(uv, float2(backW, backH));
    float backEdge = exp(-abs(backOutline) * 200.0) * 0.4;
    totalColor += float3(0.0, 0.5, 0.15) * backEdge;

    // Center glow (behind text)
    float dist = length(uv);
    float center_glow = exp(-dist * 6.0) * 0.4;
    totalColor += float3(0.1, 0.3, 0.12) * center_glow;

    // MATRIX SHADER logo text (on top)
    float3 logoText = DrawLogoText(uv);
    totalColor += logoText;

    // Depth fog
    float fog = exp(-dist * 2.0) * 0.1;
    totalColor += float3(0.03, 0.12, 0.05) * fog;

    totalColor *= GLOW_STRENGTH;

    float4 text = shaderTexture.Sample(samplerState, tex);
    return text + float4(totalColor, 0.0);
}
