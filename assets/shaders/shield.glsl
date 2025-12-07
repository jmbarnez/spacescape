// Shield impact flare
// Inspired by energy ripple/hemisphere flash on hit
#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

uniform float time;         // global time (seconds)
uniform vec2 center;        // screen-space center of the shield
uniform float radius;       // shield radius in pixels
uniform vec3 color;         // base color (RGB 0-1)
uniform vec2 contactDir;    // normalized dir from center toward impact
uniform float progress;     // 0 → 1 over the effect lifetime

vec3 hsl2rgb(vec3 hsl) {
    vec3 rgb = clamp(abs(mod(hsl.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    rgb = rgb * rgb * (3.0 - 2.0 * rgb);
    return hsl.z + hsl.y * (rgb - 0.5) * (1.0 - abs(2.0 * hsl.z - 1.0));
}

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

void main() {
    vec2 uv = love_PixelCoord.xy;
    vec2 toFrag = uv - center;
    float dist = length(toFrag);
    float norm = dist / max(radius, 0.0001);

    // Fade out with progress and distance
    float shell = smoothstep(1.05, 0.2, norm);
    float edge = smoothstep(0.95, 0.75, norm) * smoothstep(0.2, 0.4, norm);

    // Impact direction emphasis
    vec2 dir = normalize(contactDir + vec2(1e-4, 0.0));
    float dirAmt = max(0.0, dot(normalize(toFrag + dir * 0.001), dir));
    float directional = pow(dirAmt, 2.2);

    // Ripple traveling outward
    float wave = sin(12.0 * norm - time * 18.0) * 0.5 + 0.5;
    float ripple = smoothstep(0.0, 1.0, 1.0 - progress) * wave * edge;

    // Micro noise twinkle
    float noise = hash21(floor(uv * 0.7 + time * 20.0)) * 0.35;

    float fade = (1.0 - progress);
    float intensity = (shell * 0.65 + edge * 0.4 + ripple * 0.4 + noise * 0.25) * fade;
    intensity += directional * 0.45 * fade;

    vec3 glowColor = mix(color, hsl2rgb(vec3(time * 0.03, 0.25, 0.55)), 0.25);
    vec3 rgb = glowColor * intensity;

    float alpha = intensity;
    gl_FragColor = vec4(rgb, alpha);
}
