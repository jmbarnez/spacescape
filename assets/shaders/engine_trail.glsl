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

    // Fade out with easing
    v_alpha = pow(1.0 - life01, 1.5);

    // Size varies over lifetime - starts small, grows, then shrinks,
    // but does not shrink with alpha so it stays visually prominent.
    float sizeMultiplier = sin(life01 * 3.14159) * 0.5 + 0.5; // 0..1 over life
    gl_PointSize = a_size * (0.7 + sizeMultiplier * 1.3);

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

// Noise functions for particle shape variation
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
    
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

vec4 effect(vec4 color, Image texture, vec2 texcoord, vec2 screen_coords) {
    vec2 uv = gl_PointCoord - vec2(0.5);
    float dist = length(uv);
    
    // Base discard for outer boundary
    if (dist > 0.5) {
        discard;
    }
    
    // Create irregular particle shape using noise
    float angle = atan(uv.y, uv.x);
    float noiseVal = fbm(vec2(angle * 2.0, v_seed * 10.0), v_seed);
    
    // Vary the radius based on noise for irregular edges
    float radiusVariation = 0.35 + noiseVal * 0.15;
    
    // Add some turbulence that changes over lifetime
    float turbulence = fbm(uv * 8.0 + v_lifePhase * 2.0, v_seed);
    radiusVariation += (turbulence - 0.5) * 0.1 * (1.0 - v_lifePhase);
    
    if (dist > radiusVariation) {
        discard;
    }
    
    // Create internal density variation (hot core, wispy edges)
    float coreDist = dist / radiusVariation;
    float coreIntensity = 1.0 - pow(coreDist, 0.5);
    
    // Add flickering/turbulent internal structure
    float internalNoise = fbm(uv * 12.0 + u_time * 0.5, v_seed + 1.0);
    coreIntensity *= 0.7 + internalNoise * 0.3;
    
    // Soft edge falloff
    float edgeFalloff = smoothstep(radiusVariation, radiusVariation * 0.3, dist);
    
    // Choose color based on mode
    vec3 trailColor;
    if (u_colorMode == 0) {
        trailColor = u_colorA;
    } else if (u_colorMode == 1) {
        trailColor = mix(u_colorA, u_colorB, v_lifePhase);
    } else if (u_colorMode == 2) {
        trailColor = mix(u_colorA, vec3(1.0), v_lifePhase);
    } else {
        trailColor = mix(u_colorA, u_colorB, v_lifePhase);
    }
    
    // Add hot core color shift (brighter/whiter at center)
    vec3 hotColor = mix(trailColor, vec3(1.0), 0.3);
    trailColor = mix(trailColor, hotColor, coreIntensity * (1.0 - v_lifePhase * 0.5));
    
    trailColor *= u_intensity;
    
    // Combine all alpha factors and boost visibility
    float alpha = v_alpha * edgeFalloff * coreIntensity * 1.5;
    
    // Add slight glow at edges
    float glow = smoothstep(radiusVariation, radiusVariation * 0.7, dist) * 0.2;
    alpha += glow * v_alpha * 1.2;

    alpha = clamp(alpha, 0.0, 1.0);
    
    return vec4(trailColor, alpha);
}

#endif
