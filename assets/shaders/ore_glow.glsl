// =====================================
// ORE GLOW OVERLAY SHADER
// Designed to be drawn on a simple quad and clipped via stencil to the asteroid.
// =====================================

#ifdef VERTEX

varying vec2 v_texCoord;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    v_texCoord = VertexTexCoord.xy;
    return transform_projection * vertex_position;
}

#endif

#ifdef PIXEL

varying vec2 v_texCoord;

// Time in seconds (for shimmer / animation)
extern highp float u_time;

// Quad radius in local units (half the drawn quad size)
extern mediump float u_radius;

// Glow tint
extern mediump vec3 u_glowColor;

// Overall strength multiplier (typically 0..1)
extern mediump float u_intensity;

// Number of active patches in u_patches
extern mediump float u_patchCount;

// Up to 8 patches (x, y, r) in the asteroid's local space.
extern mediump vec3 u_patches[8];

float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

vec4 effect(vec4 color, Image texture, vec2 texcoord, vec2 screen_coords) {
    // Map quad texcoord to asteroid-local position.
    // When the quad is drawn centered on the asteroid, this yields local units.
    vec2 uv = texcoord - vec2(0.5);
    vec2 p = uv * (u_radius * 2.0);

    // Accumulate glow from ore patches.
    float g = 0.0;
    int count = int(clamp(u_patchCount, 0.0, 8.0));
    for (int i = 0; i < 8; i++) {
        if (i >= count) {
            break;
        }
        vec3 patch = u_patches[i];
        float r = max(patch.z, 0.001);
        float d = length(p - patch.xy);

        // Gaussian-ish falloff
        float falloff = exp(- (d * d) / (r * r));

        // Brighten the center slightly
        falloff *= 0.6 + 0.4 * exp(- (d * d) / (r * r * 0.35));

        g += falloff;
    }

    if (g <= 0.001) {
        discard;
    }

    // Alien shimmer: animated domain-warped noise.
    vec2 warp = vec2(
        fbm(p * 0.035 + vec2(u_time * 0.8, 0.0)),
        fbm(p * 0.035 + vec2(0.0, u_time * 0.7))
    );
    vec2 q = p + (warp - 0.5) * 22.0;

    float n = fbm(q * 0.06 + vec2(u_time * 1.25, u_time * -0.9));
    float bands = 0.65 + 0.35 * sin((q.x + q.y) * 0.06 + u_time * 4.0);

    float shimmer = mix(0.85, 1.25, n) * bands;

    // Soft edge fade so the quad doesn't look like a rectangle.
    float radial = length(uv) * 2.0;
    float quadFade = 1.0 - smoothstep(0.85, 1.0, radial);

    float alpha = clamp(g * 0.55, 0.0, 1.0);
    alpha *= quadFade;
    alpha *= u_intensity;

    if (alpha <= 0.01) {
        discard;
    }

    vec3 col = u_glowColor;
    // Add a bit of hot core tint towards white.
    col = mix(col, vec3(1.0), clamp(g * 0.08, 0.0, 1.0));
    col *= shimmer;

    return vec4(col, clamp(alpha, 0.0, 1.0));
}

#endif
