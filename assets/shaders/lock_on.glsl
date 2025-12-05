extern number time;
extern vec2 center;
extern number radius;
extern vec3 color;
extern number progress;

// Normalized ring mask around a target radius in unit space
float ringMask(float distNorm, float target, float thickness)
{
    float e = abs(distNorm - target);
    return smoothstep(thickness, 0.0, e);
}

vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 screencoord)
{
    // Position in screen space, normalized by radius so that radius = 1.0 in this space
    float r = max(radius, 0.001);
    vec2 p = (screencoord - center) / r;
    float d = length(p);          // distance in normalized lock space
    float t = clamp(progress, 0.0, 1.0);

    // Early discard for pixels far from the effect
    if (d > 1.7)
        discard;

    float baseThickness = mix(0.035, 0.018, t);

    // Outer ring shrinks slightly toward target as lock completes
    float outerRadius = mix(1.25, 1.02, t);
    float innerRadius = mix(0.40, 0.20, t);

    float outerRing = ringMask(d, outerRadius, baseThickness);
    float innerRing = ringMask(d, innerRadius, baseThickness * 0.9);

    // Rotating dashed ring just inside the outer ring
    float angle = atan(p.y, p.x);                      // -pi..pi
    float a = (angle + 3.14159265) / 6.2831853;        // 0..1

    float segments = 8.0;
    float dashScroll = time * (1.8 + t * 1.2);
    float pattern = fract(a * segments - dashScroll);

    // Only keep first half of each segment for a dashed look
    float dash = smoothstep(0.50, 0.35, pattern);
    float dashedRing = ringMask(d, outerRadius * 0.9, baseThickness * 0.6) * dash;

    // Suppress central reactor-like symbol; only rings remain
    float crosshair = 0.0;

    // Add a subtle pulsing based on time and progress
    float pulseAnimated = 0.7 + 0.3 * sin(time * 4.0 + t * 3.14159265);
    float pulseStatic = 1.0;
    float animWeight = step(t, 0.999);
    float pulse = mix(pulseStatic, pulseAnimated, animWeight);

    float intensity = 0.0;
    intensity += outerRing * (0.7 + 0.6 * t);
    intensity += innerRing * 0.0;
    intensity += dashedRing * (0.8 + 0.4 * t);

    intensity *= pulse;

    // Soften very close to the center for a clean focal point
    float centerFade = smoothstep(0.12, innerRadius * 1.1, d);
    intensity *= centerFade;

    // Final color grading
    vec3 baseColor = color;
    vec3 glowColor = mix(baseColor, vec3(1.0), 0.35 + 0.35 * t);
    vec3 finalColor = glowColor * (0.6 + 0.6 * intensity);

    float alpha = clamp(intensity, 0.0, 1.0);

    // Extra falloff towards the outside
    float radialFade = smoothstep(1.6, 1.0, d);
    alpha *= radialFade;

    if (alpha <= 0.01)
        discard;

    return vec4(finalColor * alpha, alpha);
}
