// Enhanced Ship Explosion Shader
// Multi-layered explosion with shockwave, fireball, and energy effects

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

float fbm(vec2 p) {
    float value = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amp * noise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return value;
}

vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 screencoord) {
    vec2 p = screencoord - center;
    float dist = length(p);
    float r = max(radius, 0.001);
    float nd = dist / r;
    
    float t = clamp(progress, 0.0, 1.0);
    
    // Angle for radial effects
    float angle = atan(p.y, p.x);
    
    // Animated noise coordinates
    vec2 ncoord = (screencoord + time * 50.0) * 0.04;
    float n = fbm(ncoord);
    float n2 = fbm(ncoord * 2.0 + vec2(time * 20.0, 0.0));
    
    // ============================================
    // LAYER 1: Bright expanding core (flash)
    // ============================================
    float corePhase = smoothstep(0.0, 0.15, t);
    float coreSize = 0.2 + t * 0.4;
    float core = exp(-8.0 * pow(nd / coreSize, 2.0));
    core *= (1.0 - smoothstep(0.0, 0.25, t)); // Fade out quickly
    core *= 2.5; // Bright flash
    
    // ============================================
    // LAYER 2: Expanding fireball body
    // ============================================
    float fireballSize = 0.1 + t * 0.9;
    float fireball = 1.0 - smoothstep(0.0, fireballSize, nd);
    
    // Add turbulent edges using noise
    float turbulence = fbm(vec2(angle * 3.0, nd * 4.0 + time * 3.0));
    float edgeNoise = 0.15 * turbulence;
    fireball = smoothstep(fireballSize + edgeNoise, fireballSize - 0.1, nd);
    
    // Fade fireball over time
    fireball *= (1.0 - pow(t, 1.5));
    
    // ============================================
    // LAYER 3: Shockwave ring
    // ============================================
    float wavePos = t * 1.4; // Ring expands outward
    float waveWidth = 0.08 + t * 0.04;
    float wave = exp(-pow((nd - wavePos) / waveWidth, 2.0));
    wave *= smoothstep(0.0, 0.1, t); // Delay slightly
    wave *= (1.0 - smoothstep(0.4, 0.9, t)); // Fade mid-explosion
    
    // ============================================
    // LAYER 4: Energy tendrils / arcs
    // ============================================
    float arcPattern = sin(angle * 8.0 + time * 15.0 + n * 6.28) * 0.5 + 0.5;
    float arcs = arcPattern * exp(-4.0 * nd);
    arcs *= smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.3, 0.7, t));
    arcs *= 0.6;
    
    // ============================================
    // LAYER 5: Outer glow / haze
    // ============================================
    float haze = exp(-2.0 * nd * nd);
    haze *= (1.0 - pow(t, 2.0));
    haze *= 0.4;
    
    // ============================================
    // LAYER 6: Flickering sparks
    // ============================================
    float sparkle = step(0.85, n2) * exp(-3.0 * nd);
    sparkle *= sin(time * 30.0 + rand(screencoord) * 6.28) * 0.5 + 0.5;
    sparkle *= (1.0 - t);
    sparkle *= 0.5;
    
    // ============================================
    // COMBINE ALL LAYERS
    // ============================================
    float intensity = core + fireball * 0.9 + wave * 0.7 + arcs + haze + sparkle;
    
    // ============================================
    // COLOR GRADING
    // ============================================
    vec3 baseColor = color;
    
    // Hot white/yellow core
    vec3 coreColor = vec3(1.0, 0.95, 0.85);
    
    // Mid-range orange/red for fireball
    vec3 midColor = mix(baseColor, vec3(1.0, 0.6, 0.2), 0.4);
    
    // Outer cooler color (based on entity color)
    vec3 outerColor = baseColor * 0.8;
    
    // Shockwave is bright cyan/white
    vec3 waveColor = vec3(0.7, 0.9, 1.0);
    
    // Blend colors based on distance and layers
    vec3 finalColor = mix(coreColor, midColor, smoothstep(0.0, 0.3, nd));
    finalColor = mix(finalColor, outerColor, smoothstep(0.3, 0.8, nd));
    
    // Add wave color contribution
    finalColor = mix(finalColor, waveColor, wave * 0.5);
    
    // Boost intensity
    finalColor *= intensity * 1.3;
    
    // ============================================
    // ALPHA
    // ============================================
    float alpha = clamp(intensity, 0.0, 1.0);
    
    // Radial falloff
    float radialFade = 1.0 - smoothstep(0.8, 1.2, nd);
    alpha *= radialFade;
    
    if (alpha <= 0.01) {
        discard;
    }
    
    return vec4(finalColor, alpha);
}
