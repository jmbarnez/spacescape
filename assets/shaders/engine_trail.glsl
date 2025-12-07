// =====================================
// Vertex Shader (LÖVE VERTEX section)
// =====================================
#ifdef VERTEX

attribute vec4 VertexUserData; // x = lifetime (spawn time), y = size, z = seed, w = unused

varying float v_alpha;
varying float v_lifePhase;
varying float v_seed;

extern float u_time;
extern float u_trailLifetime;
extern int u_colorMode;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    float a_lifetime = VertexUserData.x;
    float a_size = VertexUserData.y;
    float a_seed = VertexUserData.z;

    float age = max(u_time - a_lifetime, 0.0);
    float life01 = clamp(age / max(u_trailLifetime, 0.0001), 0.0, 1.0);
    v_lifePhase = life01;
    v_seed = a_seed;

    // Slower fade for a denser, more persistent plume
    v_alpha = pow(1.0 - life01, 0.6);

    // Plume expands aggressively over lifetime - starts fairly thick, grows larger
    float expansion = 1.3 + life01 * 3.0;

    // Slightly stronger pulsing to keep the trail alive and energetic
    float pulse = 1.0 + sin(a_seed * 20.0 + u_time * 3.0) * 0.20;

    // Global scale factor tuned for a visibly thick trail
    gl_PointSize = a_size * expansion * pulse * 2.1;

    return transform_projection * vertex_position;
}

#endif

// =====================================
// Fragment Shader (LÖVE PIXEL section)
// =====================================
#ifdef PIXEL

varying float v_alpha;
varying float v_lifePhase;
varying float v_seed;
varying vec2 v_texCoord;

extern vec3 u_colorA;
extern vec3 u_colorB;
extern int  u_colorMode;
extern float u_intensity;
extern float u_time;

// Noise functions for smoke/plume variation
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, float seed) {
    float value = 0.0;
    float amplitude = 0.5;
    p += seed * 100.0;
    
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// Billowing smoke shape function
float billow(vec2 p, float seed) {
    float n = fbm(p * 3.0, seed);
    return abs(n * 2.0 - 1.0);
}

vec4 effect(vec4 color, Image texture, vec2 texcoord, vec2 screen_coords) {
    vec2 uv = gl_PointCoord - vec2(0.5);
    float dist = length(uv);
    
    // Larger base radius for a thicker plume sprite
    if (dist > 0.6) {
        discard;
    }
    
    // Create billowing smoke shape
    float angle = atan(uv.y, uv.x);
    float angleNoise = fbm(vec2(angle * 1.5 + u_time * 0.3, v_seed * 5.0), v_seed);
    
    // Irregular, puffy edges like real smoke
    float puffiness = 0.4 + angleNoise * 0.1;
    
    // Add large-scale billowing deformation
    float billowNoise = billow(uv * 2.0 + v_lifePhase * 0.5, v_seed);
    puffiness += billowNoise * 0.08;
    
    // Turbulent wisps that increase with age
    float turbulence = fbm(uv * 6.0 + u_time * 0.2 + v_lifePhase * 3.0, v_seed + 2.0);
    puffiness += (turbulence - 0.5) * 0.12 * (0.5 + v_lifePhase * 0.5);
    
    // Soft edge - don't hard discard, fade instead for smoky look
    float edgeDist = dist / puffiness;
    if (edgeDist > 1.3) {
        discard;
    }
    
    // Volumetric density - denser at center, wispy at edges
    float density = 1.0 - smoothstep(0.0, 1.0, edgeDist);
    density = pow(density, 0.6); // Softer falloff for thick smoke
    
    // Internal smoke structure - swirling patterns
    float swirl = fbm(uv * 8.0 + vec2(cos(u_time * 0.4), sin(u_time * 0.3)) * 0.5, v_seed + 1.0);
    float internalStructure = 0.6 + swirl * 0.4;
    
    // Add darker wisps/pockets within the smoke
    float darkWisps = fbm(uv * 12.0 - u_time * 0.15, v_seed + 3.0);
    internalStructure *= 0.8 + darkWisps * 0.2;
    
    // Combine density with internal variation
    density *= internalStructure;
    
    // Choose color based on mode
    vec3 trailColor;
    if (u_colorMode == 0) {
        trailColor = u_colorA;
    } else if (u_colorMode == 1) {
        trailColor = mix(u_colorA, u_colorB, v_lifePhase);
    } else if (u_colorMode == 2) {
        // Hot core to cooler smoke transition
        float heatFade = pow(1.0 - v_lifePhase, 2.0);
        trailColor = mix(u_colorA, vec3(0.8, 0.8, 0.9), v_lifePhase * 0.6);
        trailColor = mix(trailColor, vec3(1.0, 0.95, 0.8), heatFade * density);
    } else {
        trailColor = mix(u_colorA, u_colorB, v_lifePhase);
    }
    
    // Hot glowing core for fresh particles
    float coreHeat = (1.0 - v_lifePhase) * (1.0 - edgeDist);
    coreHeat = pow(coreHeat, 1.5);
    vec3 hotCore = vec3(0.75, 1.0, 1.0);
    trailColor = mix(trailColor, hotCore, coreHeat * 0.5);
    
    // Darken edges slightly for depth, but keep them brighter overall
    float edgeDarken = smoothstep(0.3, 1.0, edgeDist) * 0.2;
    trailColor *= 1.0 - edgeDarken;
    
    trailColor *= u_intensity;
    
    // Thick, opaque smoke alpha
    float alpha = v_alpha * density;
    
    // Extra soft glow around edges for stronger halo
    float glow = smoothstep(1.0, 0.5, edgeDist) * 0.18;
    alpha += glow * v_alpha;
    
    // Boost overall opacity for a thicker, more prominent plume
    alpha *= 1.7;
    
    alpha = clamp(alpha, 0.0, 1.0);
    
    return vec4(trailColor, alpha);
}

#endif
