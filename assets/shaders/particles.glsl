// =====================================
// Vertex Shader
// =====================================
#ifdef VERTEX

// x = life phase [0..1], y = base size (pixels), z = type (0=explosion,1=impact,2=spark), w = random seed
attribute vec4 VertexUserData;

varying float v_lifePhase;
varying float v_type;
varying float v_seed;

extern float u_time;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    float lifePhase = VertexUserData.x;
    float baseSize  = VertexUserData.y;
    float pType     = VertexUserData.z;
    float seed      = VertexUserData.w;

    v_lifePhase = lifePhase;
    v_type = pType;
    v_seed = seed;

    // Different expansion profiles per type
    float expansion;
    if (pType < 0.5) {
        // Explosion: big, fast-growing
        expansion = 1.0 + lifePhase * 3.0;
    } else if (pType < 1.5) {
        // Impact: medium puff
        expansion = 0.9 + lifePhase * 1.8;
    } else {
        // Spark: elongated streak-like sprite
        expansion = 0.7 + lifePhase * 1.2;
    }

    float pulse = 1.0 + sin(seed * 31.7 + u_time * 12.0) * 0.12;

    gl_PointSize = baseSize * expansion * pulse;
    return transform_projection * vertex_position;
}

#endif

// =====================================
// Fragment Shader (L0VE PIXEL section)
// =====================================
#ifdef PIXEL

varying float v_lifePhase;
varying float v_type;
varying float v_seed;

extern vec3 u_colorExplosion;
extern vec3 u_colorImpact;
extern vec3 u_colorSpark;
extern float u_intensityExplosion;
extern float u_intensityImpact;
extern float u_intensitySpark;
extern float u_time;

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

vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screen_coords)
{
    vec2 uv = gl_PointCoord - vec2(0.5);
    float dist = length(uv);

    float typeExplosion = step(-0.5, v_type) * step(v_type, 0.5);
    float typeImpact    = step(0.5, v_type) * step(v_type, 1.5);
    float typeSpark     = step(1.5, v_type) * step(v_type, 2.5);

    vec3 baseColor;
    float intensityMul;

    if (typeExplosion > 0.5) {
        baseColor = u_colorExplosion;
        intensityMul = u_intensityExplosion;
    } else if (typeImpact > 0.5) {
        baseColor = u_colorImpact;
        intensityMul = u_intensityImpact;
    } else {
        baseColor = u_colorSpark;
        intensityMul = u_intensitySpark;
    }

    // Shape / alpha by type
    float alpha = 0.0;
    float core = 0.0;

    if (typeExplosion > 0.5) {
        // Soft but bright explosion blob
        float n = noise(uv * 6.0 + v_seed * 20.0 + u_time * 1.7);
        float r = dist * (1.2 - n * 0.25);
        core = exp(-6.0 * r * r);
        float ring = exp(-10.0 * (r - 0.3) * (r - 0.3));
        alpha = (core * 1.2 + ring * 0.8) * (1.0 - v_lifePhase);
    } else if (typeImpact > 0.5) {
        // Tighter impact puff
        float r = dist;
        core = exp(-8.0 * r * r);
        alpha = core * (1.0 - v_lifePhase * 0.8);
    } else {
        // Spark: more elongated, bright core
        vec2 dir = normalize(vec2(cos(v_seed * 20.0), sin(v_seed * 20.0)));
        float along = dot(uv, dir);
        float across = dot(uv, vec2(-dir.y, dir.x));
        float len = abs(along) * 2.0 + across * across * 6.0;
        core = exp(-10.0 * len);
        alpha = core * (1.0 - v_lifePhase * 0.6);
    }

    if (alpha <= 0.01)
        discard;

    float flicker = 0.75 + 0.25 * sin(u_time * 18.0 + v_seed * 13.0);
    alpha *= flicker;

    vec3 colorHot = mix(baseColor, vec3(1.0, 0.95, 0.8), 0.5);
    vec3 finalColor = mix(baseColor, colorHot, 1.0 - v_lifePhase);

    float edge = smoothstep(0.2, 1.0, dist);
    float glow = (1.0 - edge) * 0.35;

    alpha = clamp(alpha * (1.0 + glow) * intensityMul, 0.0, 1.0);

    return vec4(finalColor * alpha, alpha);
}

#endif
