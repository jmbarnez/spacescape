extern number time;
extern vec2 resolution;
extern number paletteVariant;
// Improved hash function for better randomness
vec3 hash3(vec2 p) {
    vec3 q = vec3(dot(p, vec2(127.1, 311.7)),
                  dot(p, vec2(269.5, 183.3)),
                  dot(p, vec2(419.2, 371.9)));
    return fract(sin(q) * 43758.5453);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    // Quintic interpolation for smoother results
    f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float a = dot(hash3(i), vec3(0.3333));
    float b = dot(hash3(i + vec2(1.0, 0.0)), vec3(0.3333));
    float c = dot(hash3(i + vec2(0.0, 1.0)), vec3(0.3333));
    float d = dot(hash3(i + vec2(1.0, 1.0)), vec3(0.3333));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float gain = 0.5;
    float lacunarity = 2.2;
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    
    for (int i = 0; i < 8; i++) {
        if (i >= octaves) break;
        value += amplitude * valueNoise(p);
        p = rot * p * lacunarity;
        amplitude *= gain;
    }
    return value;
}

// Ridged multifractal for dramatic cloud edges
float ridgedFbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float prev = 1.0;
    mat2 rot = mat2(cos(0.6), sin(0.6), -sin(0.6), cos(0.6));
    
    for (int i = 0; i < 5; i++) {
        float n = abs(valueNoise(p) * 2.0 - 1.0);
        n = 1.0 - n;
        n = n * n;
        value += n * amplitude * prev;
        prev = n;
        p = rot * p * 2.1;
        amplitude *= 0.5;
    }
    return value;
}

// Enhanced vignette with soft falloff
float vignette(vec2 uv) {
    vec2 cuv = uv * 2.0 - 1.0;
    float r = length(cuv);
    return 1.0 - smoothstep(0.3, 1.4, r * r);
}

// Complex domain-warped nebula field
float nebulaField(vec2 uv, float t) {
    // Multi-level domain warping for organic shapes
    vec2 q = vec2(
        fbm(uv * 2.5 + vec2(0.0, t * 0.03), 5),
        fbm(uv * 2.5 + vec2(5.2, t * 0.025), 5)
    );
    
    vec2 r = vec2(
        fbm(uv * 3.0 + q * 2.0 + vec2(1.7, t * 0.02), 5),
        fbm(uv * 3.0 + q * 2.0 + vec2(9.2, t * 0.015), 5)
    );
    
    vec2 s = vec2(
        fbm(uv * 4.0 + r * 1.5 + vec2(3.3, t * 0.01), 4),
        fbm(uv * 4.0 + r * 1.5 + vec2(7.8, t * 0.008), 4)
    );

    float f = fbm(uv * 3.0 + s * 1.8, 6);
    f = pow(clamp(f, 0.0, 1.0), 1.4);
    return f;
}

// Wispy tendrils using ridged noise
float tendrilField(vec2 uv, float t) {
    vec2 warp = vec2(
        fbm(uv * 1.5 + t * 0.02, 4),
        fbm(uv * 1.5 + vec2(100.0) + t * 0.015, 4)
    );
    return ridgedFbm(uv * 2.0 + warp * 0.8) * 0.7;
}

// Color palette function for smooth gradients
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    return a + b * cos(6.28318 * (c * t + d));
}

// Time-varying color function for dynamic hues
vec3 varyingColor(vec3 baseColor, float t, float speed, float intensity) {
    float hueShift = sin(t * speed) * intensity;
    float satShift = cos(t * speed * 0.7) * intensity * 0.5;
    
    // Simple hue rotation approximation
    float angle = hueShift * 3.14159;
    mat3 hueRot = mat3(
        0.299 + 0.701 * cos(angle) + 0.168 * sin(angle),
        0.587 - 0.587 * cos(angle) + 0.330 * sin(angle),
        0.114 - 0.114 * cos(angle) - 0.497 * sin(angle),
        0.299 - 0.299 * cos(angle) - 0.328 * sin(angle),
        0.587 + 0.413 * cos(angle) + 0.035 * sin(angle),
        0.114 - 0.114 * cos(angle) + 0.292 * sin(angle),
        0.299 - 0.300 * cos(angle) + 1.250 * sin(angle),
        0.587 - 0.588 * cos(angle) - 1.050 * sin(angle),
        0.114 + 0.886 * cos(angle) - 0.203 * sin(angle)
    );
    
    return hueRot * baseColor * (1.0 + satShift);
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 uv = sc / resolution;
    float t = time * 0.12;

    // Gentle drift motion
    vec2 p = uv;
    p.x += t * 0.015;
    p.y += sin(t * 0.25) * 0.02 + cos(t * 0.18) * 0.015;

    // Base nebula structure
    float baseField = nebulaField(p, t);
    float tendrils = tendrilField(p + vec2(50.0), t);

    // Multiple gas cloud layers at different depths
    float layer1 = nebulaField(p * 0.7 + vec2(10.0, -7.0), t * 0.7);
    float layer2 = nebulaField(p * 1.1 + vec2(-5.0, 3.0), t * 0.9);
    float layer3 = nebulaField(p * 1.5 + vec2(20.0, 15.0), t * 1.2);
    float layer4 = nebulaField(p * 0.5 + vec2(-30.0, 40.0), t * 0.5);

    // Organic cloud masks
    float mask1 = smoothstep(0.25, 0.7, fbm(p * 0.7 + 40.0, 5));
    float mask2 = smoothstep(0.2, 0.65, fbm(p * 0.9 + 90.0, 5));
    float mask3 = smoothstep(0.3, 0.75, fbm(p * 1.3 + 150.0, 5));
    float mask4 = smoothstep(0.15, 0.6, fbm(p * 0.5 + 200.0, 5));

    layer1 *= mask1;
    layer2 *= mask2;
    layer3 *= mask3;
    layer4 *= mask4;

    // Rich color palette for cosmic gases with time-varying hues
    vec3 deepViolet;
    vec3 cosmicPurple;
    vec3 nebulaTeal;
    vec3 warmMagenta;
    vec3 electricBlue;
    vec3 goldenGlow;

    // Additional cycling colors
    vec3 cyberCyan;
    vec3 solarOrange;
    vec3 emeraldGreen;

    float scheme = floor(paletteVariant + 0.5);

    if (scheme < 0.5) {
        deepViolet = varyingColor(vec3(0.08, 0.01, 0.18), t, 0.3, 0.4);
        cosmicPurple = varyingColor(vec3(0.18, 0.04, 0.28), t, 0.25, 0.5);
        nebulaTeal = varyingColor(vec3(0.02, 0.12, 0.18), t, 0.4, 0.6);
        warmMagenta = varyingColor(vec3(0.22, 0.05, 0.15), t, 0.35, 0.45);
        electricBlue = varyingColor(vec3(0.05, 0.08, 0.25), t, 0.2, 0.55);
        goldenGlow = varyingColor(vec3(0.3, 0.15, 0.05), t, 0.5, 0.35);

        cyberCyan = varyingColor(vec3(0.0, 0.2, 0.22), t * 1.2, 0.45, 0.5);
        solarOrange = varyingColor(vec3(0.35, 0.12, 0.02), t * 0.8, 0.38, 0.42);
        emeraldGreen = varyingColor(vec3(0.02, 0.15, 0.08), t * 1.1, 0.32, 0.48);
    } else if (scheme < 1.5) {
        deepViolet = varyingColor(vec3(0.02, 0.06, 0.03), t, 0.3, 0.4);
        cosmicPurple = varyingColor(vec3(0.04, 0.16, 0.07), t, 0.28, 0.45);
        nebulaTeal = varyingColor(vec3(0.02, 0.18, 0.16), t, 0.42, 0.6);
        warmMagenta = varyingColor(vec3(0.06, 0.2, 0.12), t, 0.35, 0.45);
        electricBlue = varyingColor(vec3(0.04, 0.14, 0.16), t, 0.24, 0.55);
        goldenGlow = varyingColor(vec3(0.22, 0.26, 0.08), t, 0.48, 0.35);

        cyberCyan = varyingColor(vec3(0.0, 0.24, 0.2), t * 1.2, 0.45, 0.5);
        solarOrange = varyingColor(vec3(0.32, 0.18, 0.05), t * 0.8, 0.38, 0.42);
        emeraldGreen = varyingColor(vec3(0.03, 0.22, 0.1), t * 1.1, 0.32, 0.48);
    } else {
        deepViolet = varyingColor(vec3(0.12, 0.0, 0.0), t, 0.32, 0.4);
        cosmicPurple = varyingColor(vec3(0.22, 0.02, 0.04), t, 0.3, 0.5);
        nebulaTeal = varyingColor(vec3(0.24, 0.08, 0.02), t, 0.4, 0.55);
        warmMagenta = varyingColor(vec3(0.3, 0.04, 0.02), t, 0.35, 0.45);
        electricBlue = varyingColor(vec3(0.1, 0.02, 0.02), t, 0.22, 0.5);
        goldenGlow = varyingColor(vec3(0.4, 0.18, 0.06), t, 0.5, 0.35);

        cyberCyan = varyingColor(vec3(0.2, 0.08, 0.06), t * 1.2, 0.45, 0.5);
        solarOrange = varyingColor(vec3(0.5, 0.16, 0.05), t * 0.8, 0.38, 0.42);
        emeraldGreen = varyingColor(vec3(0.26, 0.14, 0.08), t * 1.1, 0.32, 0.48);
    }

    // Dynamic color mixing based on density and position
    float colorShift = fbm(p * 0.8 + t * 0.01, 4);
    float colorCycle = sin(t * 0.15) * 0.5 + 0.5;
    float colorCycle2 = cos(t * 0.12 + 1.5) * 0.5 + 0.5;
    
    vec3 nebula = vec3(0.0);
    nebula += deepViolet * baseField * 0.8;
    nebula += cosmicPurple * layer1 * 0.9;
    nebula += mix(nebulaTeal, cyberCyan, colorCycle) * layer2 * 1.1;
    nebula += mix(warmMagenta, solarOrange, colorCycle2) * layer3 * 0.85;
    nebula += mix(electricBlue, emeraldGreen, colorCycle * colorCycle2) * layer4 * 0.7;
    nebula += goldenGlow * tendrils * 0.4;

    // Animated color variation across the nebula
    vec3 colorVar = palette(colorShift + t * 0.02, 
        vec3(0.5, 0.5, 0.5), 
        vec3(0.5, 0.5, 0.5), 
        vec3(1.0 + sin(t * 0.1) * 0.2, 0.7 + cos(t * 0.15) * 0.2, 0.4 + sin(t * 0.12) * 0.2), 
        vec3(0.0 + t * 0.01, 0.15, 0.2));
    nebula *= mix(vec3(1.0), colorVar, 0.35);

    // Pulsating color overlay
    vec3 pulseColor = palette(t * 0.05 + uv.x * 0.3 + uv.y * 0.2,
        vec3(0.5, 0.5, 0.5),
        vec3(0.3, 0.3, 0.3),
        vec3(1.0, 1.0, 1.0),
        vec3(0.0, 0.33, 0.67));
    float pulseMask = pow(baseField * layer1, 2.0) * 0.15;
    nebula += pulseColor * pulseMask;

    // Luminous highlights on dense regions with color shifting
    float highlight = pow(clamp(baseField * 1.4, 0.0, 1.0), 4.0);
    float tendrilHighlight = pow(clamp(tendrils * 1.3, 0.0, 1.0), 3.0);
    
    vec3 highlightColor = varyingColor(vec3(0.6, 0.45, 0.8), t, 0.28, 0.3);
    vec3 tendrilHighlightColor = varyingColor(vec3(0.4, 0.6, 0.9), t, 0.33, 0.35);
    
    nebula += highlightColor * highlight * 0.35;
    nebula += tendrilHighlightColor * tendrilHighlight * 0.2;

    // Subtle emission glow in brightest areas with color variation
    float emission = pow(clamp((baseField + layer1 + layer2) * 0.5, 0.0, 1.0), 5.0);
    vec3 emissionColor = varyingColor(vec3(0.9, 0.7, 1.0), t, 0.22, 0.25);
    nebula += emissionColor * emission * 0.15;

    // Soft color grading for cinematic look with animated tint
    nebula = pow(nebula, vec3(1.15));
    vec3 tint = vec3(1.1 + sin(t * 0.08) * 0.05, 1.0, 1.15 + cos(t * 0.1) * 0.05);
    nebula = mix(nebula, nebula * tint, 0.3);

    // Apply vignette
    float vig = vignette(uv);
    nebula *= vig;

    // Compute alpha from combined density
    float density = max(max(layer1, layer2), max(max(layer3, layer4), max(baseField, tendrils * 0.6)));
    float alpha = clamp(density * 0.85 * vig, 0.0, 1.0);

    // Subtle dithering to reduce banding
    float dither = (fract(sin(dot(sc, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 0.015;
    nebula += dither;

    return vec4(nebula, alpha);
}
