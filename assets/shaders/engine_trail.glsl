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

    // Fade over life; still bright when fresh, then quickly softens as
    // particles drift away and dissipate.
    v_alpha = pow(1.0 - life01, 1.1);

    // Slight expansion over lifetime; particles stay fairly compact so they
    // read as distinct points rather than a solid blade.
    float expansion = mix(1.0, 1.6, life01);

    // Gentle pulsing to keep the particles feeling alive without wobbling too much
    float pulse = 1.0 + sin(a_seed * 18.0 + u_time * 4.0) * 0.12;

    // Global scale factor tuned for thicker, chunkier particles while still
    // keeping them visually separate.
    gl_PointSize = a_size * expansion * pulse * 1.8;

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
    // Centered UV inside point-sprite space: gl_PointCoord is [0, 1] each axis
    vec2 uv = gl_PointCoord - vec2(0.5);
    float dist = length(uv);

    // Soft cut-off radius; slightly larger so each particle has a meatier core
    // and halo without needing huge point sizes.
    float maxRadius = 0.7;
    if (dist > maxRadius) {
        discard;
    }

    float life = v_lifePhase;

    // ------------------------------------------------------------
    // Radial structure: bright core + soft halo + slightly stretched body
    // ------------------------------------------------------------

    // Inner core radius controls how tight the central glow is.
    // Fixed radius keeps each particle visually similar as it moves and fades.
    float coreRadius = maxRadius * 0.3;
    float glowRadius = maxRadius;

    // Very bright center
    float core = 1.0 - smoothstep(0.0, coreRadius, dist);

    // Softer surrounding glow that keeps the disc visible even when thin
    float glow = 1.0 - smoothstep(coreRadius, glowRadius, dist);

    // A subtle directional stretch to suggest forward motion
    float stretch = mix(1.35, 1.0, life);
    vec2 stretchedUV = vec2(uv.x * stretch, uv.y);
    float stretchedDist = length(stretchedUV);
    float trail = 1.0 - smoothstep(coreRadius * 0.8, glowRadius, stretchedDist);

    // ------------------------------------------------------------
    // Stylized turbulence: gentle energy ripples instead of heavy smoke
    // ------------------------------------------------------------

    float swirl = fbm(uv * 6.0 + vec2(u_time * 0.9, v_seed * 3.5), v_seed + 1.0);
    float swirl2 = fbm(uv * 3.0 + vec2(-u_time * 0.5, v_seed * 6.0), v_seed + 4.0);
    float swirlCombined = mix(swirl, swirl2, 0.5);

    float density = core * 1.0 + glow * 0.6 + trail * 0.3;
    // Slightly narrower modulation range keeps the particles from looking
    // too smoky while still giving some internal variation.
    density *= mix(0.9, 1.2, swirlCombined);
    density *= (1.0 - life * 0.6);
    density = clamp(density, 0.0, 1.0);

    // ------------------------------------------------------------
    // Color styling
    // ------------------------------------------------------------

    vec3 trailColor;
    if (u_colorMode == 0) {
        trailColor = u_colorA;
    } else if (u_colorMode == 1) {
        trailColor = mix(u_colorA, u_colorB, life);
    } else if (u_colorMode == 2) {
        // Neon exhaust: bright cyan/white core with cooler outer halo
        float hueShift = clamp(life * 0.55 + swirlCombined * 0.25, 0.0, 1.0);
        vec3 mixed = mix(u_colorA, u_colorB, hueShift);

        // Fresh particles burn hotter; older ones cool off into softer smoke
        float coreHeat = pow(core, 1.4) * (1.0 - life * 0.7);
        vec3 hotCore = vec3(0.9, 1.0, 1.0);
        trailColor = mix(mixed, hotCore, coreHeat);

        // Slightly tinted outer halo that gives the trail a soft edge
        float outerGlow = smoothstep(coreRadius * 1.4, glowRadius, dist);
        vec3 outerTint = vec3(0.6, 0.9, 1.0);
        trailColor = mix(trailColor, outerTint, outerGlow * 0.35);
    } else {
        trailColor = mix(u_colorA, u_colorB, life);
    }

    trailColor *= u_intensity;

    // ------------------------------------------------------------
    // Alpha / glow
    // ------------------------------------------------------------

    // Base opacity from lifetime and radial density
    float alpha = v_alpha * density;

    // Extra halo that keeps a visible outline even as the core fades
    float halo = smoothstep(glowRadius, coreRadius * 0.6, dist);
    halo *= 0.25 * (1.0 - life * 0.4);
    alpha += halo * v_alpha;

    alpha = clamp(alpha, 0.0, 1.0);

    return vec4(trailColor, alpha);
}

#endif
