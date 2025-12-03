extern number time;
extern vec2 center;
extern number radius;
extern vec3 color;
extern number progress;

float rand(vec2 n) {
    return fract(sin(dot(n, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 screencoord) {
    vec2 p = screencoord - center;
    float dist = length(p);
    float r = max(radius, 0.001);
    float nd = dist / r;

    float t = clamp(progress, 0.0, 1.0);

    vec2 ncoord = (screencoord + time * 35.0) * 0.055;
    float n = noise(ncoord);

    float core = exp(-6.0 * nd * nd);
    float halo = exp(-10.0 * (nd - 0.35) * (nd - 0.35));

    float timeShape = 1.0 - t;
    timeShape *= timeShape;

    float intensity = (core * 1.6 + halo * 0.7) * timeShape;

    float flicker = 0.5 + 0.5 * sin(time * 12.0 + n * 6.28318);
    intensity *= 0.8 + 0.4 * flicker;

    float arcs = smoothstep(0.6, 1.0, n) * core * (1.0 - t);
    intensity += arcs * 0.5;

    float radialFade = smoothstep(0.9, 0.1, nd);
    intensity *= radialFade;

    vec3 baseColor = color;
    vec3 plasmaTint = vec3(0.65, 0.9, 1.0);
    vec3 glowColor = mix(baseColor, plasmaTint, 0.7);
    vec3 finalColor = mix(glowColor, vec3(1.0), 0.3);

    float alpha = clamp(intensity, 0.0, 1.0);
    if (alpha <= 0.01) {
        discard;
    }

    return vec4(finalColor * intensity, alpha);
}
