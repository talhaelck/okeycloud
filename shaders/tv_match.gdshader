// A football match on an old TV: the camera slowly pans along the pitch, two teams run about chasing the ball,
// the crowd blurs in the stands, a score bar sits in the corner. Scanlines and a curved dark edge make it a CRT.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform float brightness = 1.4;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

// A player (or the ball) at `at`, drawn as a small upright blob.
float blob(vec2 uv, vec2 at, vec2 size) {
	vec2 d = (uv - at) / size;
	return smoothstep(1.0, 0.6, dot(d, d));
}

void fragment() {
	vec2 uv = UV;
	float pan = sin(TIME * 0.11) * 0.35 + sin(TIME * 0.37) * 0.05;
	float x = uv.x + pan;

	// Pitch: mown stripes, touchline, halfway line and the centre circle.
	vec3 col = mix(vec3(0.12, 0.44, 0.13), vec3(0.15, 0.52, 0.16), step(0.5, fract(x * 5.0)));
	float lines = step(abs(uv.y - 0.27), 0.006) + step(abs(x - 0.5), 0.005) * step(0.27, uv.y);
	float ring = abs(length((vec2(x, uv.y) - vec2(0.5, 0.62)) * vec2(1.0, 1.8)) - 0.2);
	lines += step(ring, 0.006) * step(0.27, uv.y);
	col = mix(col, vec3(0.88), clamp(lines, 0.0, 1.0));

	// Stands: a dark, speckled crowd above the touchline.
	float stands = step(uv.y, 0.25);
	float fan = hash(floor(x * 120.0) + floor(uv.y * 60.0) * 131.0);
	vec3 crowd = vec3(0.12, 0.1, 0.12) + vec3(fan * 0.25, fan * 0.15, fan * 0.2) * step(0.5, fan);
	col = mix(col, crowd, stands);

	// Ten players and the ball drifting about the middle of the pitch.
	vec2 ball = vec2(0.5 + 0.3 * sin(TIME * 0.5) + 0.1 * sin(TIME * 1.7), 0.6 + 0.2 * sin(TIME * 0.8));
	for (int i = 0; i < 10; i++) {
		float f = float(i);
		vec2 home = vec2(0.2 + 0.6 * hash(f + 1.0), 0.4 + 0.5 * hash(f + 11.0));
		vec2 at = mix(home, ball, 0.35 + 0.2 * sin(TIME * (0.6 + hash(f) * 0.6) + f));
		at.x += 0.02 * sin(TIME * 3.0 + f);
		vec3 kit = i < 5 ? vec3(0.85, 0.15, 0.12) : vec3(0.92, 0.92, 0.95);
		col = mix(col, kit, blob(vec2(x, uv.y), at, vec2(0.012, 0.035)));
	}
	col = mix(col, vec3(1.0), blob(vec2(x, uv.y), ball, vec2(0.007, 0.012)));

	// Score bar, top left: two team colours and a few white ticks.
	if (uv.x > 0.04 && uv.x < 0.34 && uv.y > 0.05 && uv.y < 0.13) {
		col = vec3(0.05, 0.06, 0.12);
		if (uv.x < 0.08) col = vec3(0.85, 0.15, 0.12);
		if (uv.x > 0.17 && uv.x < 0.21) col = vec3(0.92);
		if (uv.x > 0.24 && uv.x < 0.31 && fract(uv.x * 60.0) < 0.6 && uv.y > 0.07 && uv.y < 0.11) col = vec3(0.8);
	}

	// CRT: scanlines, a slow roll, rounded dark corners.
	col *= 0.86 + 0.14 * sin(uv.y * 520.0 + TIME * 4.0);
	col *= 0.95 + 0.05 * sin(TIME * 0.7 + uv.y * 3.0);
	vec2 c = uv - 0.5;
	col *= smoothstep(0.72, 0.45, length(c * vec2(1.0, 1.15)));
	ALBEDO = col * brightness;
}
