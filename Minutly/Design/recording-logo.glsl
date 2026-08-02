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

/**
 * @label Line Count
 * @default 100
 * @range 24, 180
 */
uniform float u_count;

/**
 * @label Intensity
 * @default 1.0
 * @range 0.0, 2.0
 */
uniform float u_intensity;

#define PI 3.14159265359
#define TAU 6.28318530718

void main() {
  vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution) / min(u_resolution.x, u_resolution.y);

  float r = length(uv);
  float a = atan(uv.y, uv.x);

  float n = floor(u_count);
  float sector = (a + PI) / TAU * n;
  float idx = floor(sector);
  float d = abs(fract(sector) - 0.5) * 2.0;

  float seed = idx;
  float amp = sin(u_time * 2.6 + seed * 0.55)
            + 0.6 * sin(u_time * 4.7 + seed * 1.7)
            + 0.4 * sin(u_time * 7.9 + seed * 0.9);
  amp = 0.5 + 0.5 * (amp / 2.0);

  float inner = 0.085;
  float len = inner + (0.16 + 0.21 * amp * u_intensity);

  float angMask = smoothstep(0.62, 0.40, d);
  float radMask = smoothstep(inner - 0.006, inner + 0.006, r)
                * smoothstep(len + 0.012, len - 0.012, r);
  float line = angMask * radMask;

  float ring = smoothstep(0.012, 0.0, abs(r - inner * 0.62));
  float dot = smoothstep(0.052, 0.040, r);

  float alpha = clamp(line + dot * 0.95 + ring * 0.5, 0.0, 1.0);

  float glow = 0.10 * smoothstep(0.5, 0.0, r) * (0.6 + 0.4 * sin(u_time * 2.0));
  alpha = clamp(alpha + glow * 0.4, 0.0, 1.0);

  gl_FragColor = vec4(u_color, alpha);
}
