#version 330 core

in vec4 fragColor;
in vec2 fragTexCoord;
out vec4 finalColor;

uniform float time;

#define PI 3.14159265359

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

vec2 rotate2D(vec2 uv, float angle) {
    return mat2(cos(angle), -sin(angle), sin(angle), cos(angle)) * uv;
}

void main() {
    vec2 uv = fragTexCoord;
    
    // Grid parameters
    float gridSize = 10.0;
    float beat = abs(sin(time * 3.0));
    vec3 baseColor = fragColor.rgb; // Use input color as the base
    
    // Create grid pattern
    vec2 gridUV = uv * gridSize;
    vec2 cell = floor(gridUV);
    vec2 localUV = fract(gridUV) - 0.5;
    
    // Animate cells
    float cellTime = time * (0.8 + random(cell) * 1.5);
    localUV = rotate2D(localUV, cellTime);
    localUV += vec2(sin(cellTime), cos(cellTime)) * 0.15;
    
    // Calculate distance to edges
    float d = length(localUV);
    float edge = smoothstep(0.35, 0.34, d);
    
    // Slightly modulate the input color
    vec3 color = baseColor * (0.9 + 0.2 * sin(uv.x * PI * 2.0 + time));
    color = mix(color, baseColor, smoothstep(0.3, 0.7, sin(time * 0.5)));
    
    // Glowing effect using the input color
    float glow = pow(1.0 - d, 3.0) * 0.6;
    glow *= sin(time * 4.0 + cell.x * 5.0) * 0.5 + 0.5;
    
    // Combine elements while preserving the input color
    float alpha = edge + glow;
    vec3 final = mix(baseColor, color, alpha * 1.2);
    
    // Add subtle pulsing background using the input color
    vec2 waveUV = uv + vec2(sin(time * 0.8 + uv.y * 3.0), cos(time * 0.8 + uv.x * 2.0)) * 0.1;
    float background = sin(waveUV.x * 20.0 + time) * cos(waveUV.y * 15.0 - time);
    final += baseColor * background * 0.1 * (1.0 - edge); // Soft background
    
    finalColor = vec4(final, fragColor.a); // Preserve input alpha
}