/** @resolution */
uniform vec2 u_resolution;

/** @time */
uniform float u_time;

/**
 * @label Color
 * @color
 * @default #FB4B16
 */
uniform vec3 u_color;

void main() {
  vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution) / min(u_resolution.x, u_resolution.y);
  float r = length(uv);

  float alpha = 0.0;

  for (int i = 0; i < 3; i++) {
    float t = fract(u_time * 0.4 + float(i) / 3.0);
    float radius = 0.14 + t * 0.34;
    float ring = smoothstep(0.028, 0.0, abs(r - radius));
    alpha += ring * (1.0 - t) * 0.45;
  }

  alpha += 0.10 * smoothstep(0.48, 0.08, r) * (0.7 + 0.3 * sin(u_time * 2.0));

  alpha = clamp(alpha, 0.0, 1.0);
  gl_FragColor = vec4(u_color, alpha);
}
