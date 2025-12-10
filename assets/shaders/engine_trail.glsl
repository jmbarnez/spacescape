// =====================================
// BUBBLY INTENSE CYAN GLOW TRAIL SHADER
// For QUAD-based rendering (no point sprites)
// =====================================

#ifdef VERTEX

varying vec2 v_texCoord;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    v_texCoord = VertexTexCoord.xy;
    return transform_projection * vertex_position;
}

#endif

// =====================================
// Fragment Shader
// =====================================
#ifdef PIXEL

varying vec2 v_texCoord;

extern mediump vec3 u_colorA;
extern mediump vec3 u_colorB;
extern mediump float u_colorMode;
extern mediump float u_intensity;
extern highp float u_time;

// Per-bubble uniforms
extern mediump float u_bubbleLifePhase;
extern mediump float u_bubbleSeed;
extern mediump float u_bubbleAlpha;

vec4 effect(vec4 color, Image texture, vec2 texcoord, vec2 screen_coords) {
    // texcoord is 0-1 across the quad, convert to centered coords
    vec2 uv = texcoord - vec2(0.5);
    float dist = length(uv);

    // Hard circular cutoff
    if (dist > 0.5) {
        discard;
    }

    float life = u_bubbleLifePhase;
    float seed = u_bubbleSeed;

    // ============================================
    // BUBBLE SHAPE - soft glowing orb
    // ============================================
    
    // Super bright core
    float coreSize = 0.08;
    float core = 1.0 - smoothstep(0.0, coreSize, dist);
    core = pow(core, 0.4);
    
    // Main bubble body - soft gradient
    float bodyFalloff = 0.45;
    float body = 1.0 - smoothstep(0.0, bodyFalloff, dist);
    body = pow(body, 0.8);
    
    // Bright rim/edge glow
    float rimStart = 0.35;
    float rimEnd = 0.5;
    float rim = smoothstep(rimStart, rimEnd - 0.05, dist) * (1.0 - smoothstep(rimEnd - 0.05, rimEnd, dist));
    rim = pow(rim, 0.6) * 0.8;
    
    // Outer glow halo
    float halo = 1.0 - smoothstep(0.3, 0.5, dist);
    halo = pow(halo, 2.0) * 0.5;

    // Specular highlight - makes it look like a shiny bubble
    vec2 specPos = vec2(-0.12, -0.1);
    float specDist = length(uv - specPos);
    float spec = 1.0 - smoothstep(0.0, 0.1, specDist);
    spec = pow(spec, 1.2) * 0.9;

    // ============================================
    // INTENSE CYAN COLORS
    // ============================================
    
    vec3 cyanHot = vec3(0.6, 1.0, 1.0);       // Hot white-cyan
    vec3 cyanBright = vec3(0.0, 1.0, 1.0);    // Pure bright cyan
    vec3 cyanMid = vec3(0.0, 0.85, 1.0);      // Slightly blue-shifted
    vec3 cyanDeep = vec3(0.0, 0.6, 0.9);      // Deeper blue-cyan
    vec3 white = vec3(1.0, 1.0, 1.0);

    vec3 bubbleColor;
    if (u_colorMode < 0.5) {
        bubbleColor = u_colorA;
    } else if (u_colorMode < 1.5) {
        bubbleColor = mix(u_colorA, u_colorB, life);
    } else {
        // Bubbly cyan mode
        
        // Start with body gradient
        bubbleColor = mix(cyanBright, cyanMid, smoothstep(0.0, 0.4, dist));
        
        // Hot core
        bubbleColor = mix(bubbleColor, cyanHot, core * 0.9);
        
        // Bright rim
        bubbleColor = mix(bubbleColor, cyanBright * 1.2, rim);
        
        // White specular
        bubbleColor = mix(bubbleColor, white, spec);
        
        // Age: older bubbles get deeper/cooler
        bubbleColor = mix(bubbleColor, cyanDeep, life * 0.3);
        
        // Shimmer animation
        float shimmer = 0.9 + 0.1 * sin(u_time * 8.0 + seed * 20.0);
        bubbleColor *= shimmer;
    }

    bubbleColor *= u_intensity;

    // ============================================
    // ALPHA COMPOSITING
    // ============================================
    
    float alpha = 0.0;
    
    // Core is solid
    alpha += core * 1.0;
    
    // Body fill
    alpha += body * 0.7;
    
    // Rim adds brightness
    alpha += rim * 0.6;
    
    // Halo extends glow
    alpha += halo * 0.3;
    
    // Specular pop
    alpha += spec * 0.4;
    
    // Apply lifetime fade
    alpha *= u_bubbleAlpha;
    
    // Fresh bubbles glow brighter
    alpha *= 1.0 + (1.0 - life) * 0.4;
    
    alpha = clamp(alpha, 0.0, 1.0);

    return vec4(bubbleColor, alpha);
}

#endif
