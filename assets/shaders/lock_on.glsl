// Uniforms
extern number time;
extern vec2 center;
extern number radius;
extern vec3 color;
extern number progress;

// Constants
const float PI = 3.14159265;
const float TAU = 6.2831853;
const float SEGMENTS = 8.0;
const float MIN_ALPHA = 0.01;
const float MAX_DISTANCE = 1.7;

// Normalized ring mask around a target radius in unit space
float ringMask(float distNorm, float target, float thickness)
{
    float edge = abs(distNorm - target);
    return smoothstep(thickness, 0.0, edge);
}

// Generate rotating dashed pattern
float dashedPattern(vec2 pos, float scrollSpeed)
{
    float angle = atan(pos.y, pos.x);
    float normalizedAngle = (angle + PI) / TAU;
    float scroll = time * scrollSpeed;
    float pattern = fract(normalizedAngle * SEGMENTS - scroll);
    return smoothstep(0.50, 0.35, pattern);
}

// Animated pulse effect
float calculatePulse(float t)
{
    float pulseAnimated = 0.7 + 0.3 * sin(time * 4.0 + t * PI);
    float pulseStatic = 1.0;
    float animWeight = step(t, 0.999);
    return mix(pulseStatic, pulseAnimated, animWeight);
}

// Calculate ring parameters based on progress
void getRingParams(float t, out float outerRadius, out float innerRadius, out float thickness)
{
    thickness = mix(0.035, 0.018, t);
    outerRadius = mix(1.25, 1.02, t);
    innerRadius = mix(0.40, 0.20, t);
}

vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 screencoord)
{
    // Normalize position by radius (radius = 1.0 in this space)
    float r = max(radius, 0.001);
    vec2 pos = (screencoord - center) / r;
    float dist = length(pos);
    float t = clamp(progress, 0.0, 1.0);

    // Early discard for distant pixels
    if (dist > MAX_DISTANCE)
        discard;

    // Get ring parameters
    float outerRadius, innerRadius, baseThickness;
    getRingParams(t, outerRadius, innerRadius, baseThickness);

    // Calculate ring masks
    float outerRing = ringMask(dist, outerRadius, baseThickness);
    float innerRing = ringMask(dist, innerRadius, baseThickness * 0.9);
    
    // Rotating dashed ring
    float dashScrollSpeed = 1.8 + t * 1.2;
    float dash = dashedPattern(pos, dashScrollSpeed);
    float dashedRing = ringMask(dist, outerRadius * 0.9, baseThickness * 0.6) * dash;

    // Calculate pulse
    float pulse = calculatePulse(t);

    // Combine ring intensities
    float intensity = 0.0;
    intensity += outerRing * (0.7 + 0.6 * t);
    intensity += dashedRing * (0.8 + 0.4 * t);
    intensity *= pulse;

    // Apply center fade for clean focal point
    float centerFade = smoothstep(0.12, innerRadius * 1.1, dist);
    intensity *= centerFade;

    // Color grading
    vec3 glowColor = mix(color, vec3(1.0), 0.35 + 0.35 * t);
    vec3 finalColor = glowColor * (0.6 + 0.6 * intensity);

    // Alpha calculation with radial falloff
    float alpha = clamp(intensity, 0.0, 1.0);
    float radialFade = smoothstep(1.6, 1.0, dist);
    alpha *= radialFade;

    // Discard near-transparent pixels
    if (alpha <= MIN_ALPHA)
        discard;

    return vec4(finalColor * alpha, alpha);
}
