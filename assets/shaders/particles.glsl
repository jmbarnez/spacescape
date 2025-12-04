extern float u_time;

varying float v_life;
varying vec3 v_color;

#ifdef VERTEX
attribute float a_life;
attribute float a_maxLife;
attribute vec3 a_color;
attribute float a_size;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    v_life = a_life / a_maxLife;
    v_color = a_color;
    gl_PointSize = a_size;
    return transform_projection * vertex_position;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_pos) {
    vec2 center = gl_PointCoord - vec2(0.5);
    float dist = length(center) * 2.0;
    
    float glow = 1.0 - smoothstep(0.0, 1.0, dist);
    glow = pow(glow, 1.5);
    
    float core = 1.0 - smoothstep(0.0, 0.3, dist);
    
    vec3 finalColor = v_color * glow + vec3(1.0) * core * 0.5;
    float alpha = glow * v_life;
    
    return vec4(finalColor, alpha);
}
#endif
