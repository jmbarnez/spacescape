#version 330 core

// =====================================
// Vertex Shader
// =====================================
#ifdef VERTEX_SHADER

layout(location = 0) in vec3 a_position;
layout(location = 1) in vec2 a_texCoord;
layout(location = 2) in float a_lifetime;  // spawn time or life param
layout(location = 3) in float a_size;

out float v_alpha;
out float v_lifePhase;   // 0..1 for gradient over life

uniform mat4 u_viewProjection;
uniform mat4 u_model;
uniform float u_time;
uniform float u_trailLifetime; // total lifetime for fade (e.g. 1.0–2.0)

// Engine trail color mode
// 0: constant
// 1: from cool (blue) to hot (orange)
// 2: from soft (cyan) to white
// 3: from engineBlue to enginePurple
uniform int u_colorMode;

void main() {
    // Basic life-based fade
    float age = max(u_time - a_lifetime, 0.0);
    float life01 = clamp(age / max(u_trailLifetime, 0.0001), 0.0, 1.0);
    v_lifePhase = life01;

    // Fade out over life (simple)
    v_alpha = 1.0 - life01;

    gl_Position = u_viewProjection * u_model * vec4(a_position, 1.0);
    gl_PointSize = a_size * v_alpha;
}

#endif

// =====================================
// Fragment Shader
// =====================================
#ifdef FRAGMENT_SHADER

in float v_alpha;
in float v_lifePhase;

out vec4 fragColor;

// Color options:
// u_colorMode == 0 : use u_colorA as constant
// u_colorMode == 1 : cool (u_colorA) -> hot (u_colorB)
// u_colorMode == 2 : soft (u_colorA) -> white
// u_colorMode == 3 : engineBlue (u_colorA) -> enginePurple (u_colorB)
uniform vec3 u_colorA;   // base color
uniform vec3 u_colorB;   // target color
uniform int  u_colorMode;
uniform float u_intensity;

void main() {
    // Simple circular falloff
    vec2 center = gl_PointCoord - vec2(0.5);
    float dist = length(center);
    if (dist > 0.5) {
        discard;
    }

    float edge = smoothstep(0.5, 0.0, dist); // 1 at center, 0 at radius 0.5

    // Choose color based on mode
    vec3 color;
    if (u_colorMode == 0) {
        // Constant color
        color = u_colorA;
    } else if (u_colorMode == 1) {
        // Cool to hot across life
        color = mix(u_colorA, u_colorB, v_lifePhase); // e.g. blue -> orange
    } else if (u_colorMode == 2) {
        // Soft to white
        color = mix(u_colorA, vec3(1.0), v_lifePhase);
    } else {
        // Mode 3 and fallback: custom A -> B
        color = mix(u_colorA, u_colorB, v_lifePhase);
    }

    color *= u_intensity;

    float alpha = v_alpha * edge;
    fragColor = vec4(color, alpha);
}

#endif
