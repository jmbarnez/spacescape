extern vec2 center;
extern vec2 impact;
extern number radius;
extern vec3 color;
extern number progress;

vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 screencoord) {
    // Vector from shield center to current pixel in screen-space
    vec2 toCenter = screencoord - center;
    float distCenter = length(toCenter);

    // Guard against degenerate radius
    float r = max(radius, 0.001);
    float ndCenter = distCenter / r;

    // Vector from impact point to current pixel
    vec2 toImpact = screencoord - impact;
    float ndImpact = length(toImpact) / r;

    // Normalized time within the effect's lifetime
    float t = clamp(progress, 0.0, 1.0);

    // Core glow: tight, bright region around the impact point.
    float core = exp(-14.0 * ndImpact * ndImpact);

    // Direction from center to impact, used to smear light across the shield
    // surface so the hit feels like it splashes over a curved field.
    vec2 centerToImpact = impact - center;
    float lenCI = length(centerToImpact);
    vec2 dirCI = lenCI > 0.0 ? centerToImpact / lenCI : vec2(0.0, 1.0);

    // Project the current pixel onto the center->impact axis in shield space.
    vec2 shieldDir = toCenter / r;
    float lenSD = length(shieldDir);
    vec2 shieldDirNorm = lenSD > 0.0 ? shieldDir / lenSD : dirCI;
    float cosAngle = clamp(dot(shieldDirNorm, dirCI), -1.0, 1.0);
    float angleDiff = acos(cosAngle);
    float normAngle = angleDiff / 3.14159265;

    // A thin streak along the axis from center toward impact.
    float streak = exp(-36.0 * normAngle * normAngle);

    // Outward-traveling energy wave along the shield radius.
    float spread = 0.08 + t * 0.9; // angular spread grows over time
    float wave = exp(- (normAngle * normAngle) / (2.0 * spread * spread));

    // Fade intensity toward the outer edge of the shield so the effect feels
    // contained within the field rather than a hard disc.
    float radialFalloff = exp(-((ndCenter - 1.0) * (ndCenter - 1.0)) / (2.0 * 0.08 * 0.08));

    // Combine components into a single intensity value.
    float intensity = 0.0;
    intensity += core * 2.1;   // dense core at the impact point
    intensity += streak * 0.9; // subtle streak along field surface
    intensity += wave * 0.7;   // expanding wave over time
    intensity *= radialFalloff;

    // Temporal fade so the hit starts sharp and then quickly softens out.
    float timeFade = 1.0 - t;
    timeFade *= timeFade;
    intensity *= timeFade;

    // Clamp and discard very faint fragments for performance.
    intensity = clamp(intensity, 0.0, 1.5);
    if (intensity <= 0.01 || ndCenter > 1.25) {
        discard;
    }

    // Slightly push the color toward a cool plasma tone for a sleek shield look.
    vec3 plasmaTint = vec3(0.7, 0.9, 1.0);
    vec3 glowColor = mix(color, plasmaTint, 0.55);

    // Final color with intensity baked in; alpha tracks intensity for blending.
    float alpha = clamp(intensity, 0.0, 1.0);
    return vec4(glowColor * intensity, alpha);
}
