#version 320 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
  vec4 c = texture(tex, v_texcoord);

  // Amber night-light balance to avoid green tint.
  vec3 warm = vec3(
    min(c.r * 1.06, 1.0),
    c.g * 0.88,
    c.b * 0.62
  );

  // Subtle extra warmth bias.
  warm += vec3(0.015, 0.004, 0.0);
  fragColor = vec4(clamp(warm, 0.0, 1.0), c.a);
}
