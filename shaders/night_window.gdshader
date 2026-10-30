// A kahvehane window at night in the rain: the street outside (buildings with a few lit windows, a street lamp's
// glow, the wet road reflecting it), rain falling past, and drops on the glass. Unshaded: it is the light source.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform float brightness = 1.0;
uniform float seed = 0.0; // a different street per window

float hash(vec2 p) {
	return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float y = 1.0 - uv.y;

	// Sky, faintly lit from below by the city.
	vec3 col = mix(vec3(0.07, 0.07, 0.11), vec3(0.015, 0.02, 0.05), smoothstep(0.35, 1.0, y));

	// Buildings across the street, with lit windows.
	float bx = floor(uv.x * 6.0);
	float roof = 0.5 + 0.32 * hash(vec2(bx, 3.0));
	float building = step(y, roof);
	col = mix(col, vec3(0.02, 0.018, 0.024), building);
	vec2 w = vec2(uv.x * 30.0, y * 24.0);
	vec2 wi = floor(w);
	vec2 wf = fract(w);
	float pane = step(0.25, wf.x) * step(wf.x, 0.75) * step(0.3, wf.y) * step(wf.y, 0.75);
	float lit = step(0.8, hash(wi)) * building * pane * step(0.2, y);
	col += lit * mix(vec3(1.0, 0.72, 0.38), vec3(0.55, 0.7, 1.0), step(0.75, hash(wi + 7.0))) * 0.45;

	// A street lamp: a soft halo in the rain.
	vec2 lamp = vec2(0.7 + 0.1 * hash(vec2(seed, 9.0)), 0.36);
	float d = length((vec2(uv.x, y) - lamp) * vec2(1.0, 1.3));
	col += vec3(1.0, 0.68, 0.32) * (0.9 * exp(-d * d * 400.0) + 0.22 * exp(-d * 7.0));

	// The wet road reflects the lamp in a long smear.
	float road = smoothstep(0.2, 0.02, y);
	vec3 wet = vec3(0.02, 0.02, 0.03) + vec3(1.0, 0.68, 0.32) * 0.3 * exp(-abs(uv.x - lamp.x) * 14.0) * road;
	col = mix(col, wet, road);

	// Rain: thin bright streaks falling past.
	vec2 r = vec2(uv.x * 90.0, y * 2.0 + TIME * 3.5);
	float lane = floor(r.x);
	float fall = fract(r.y + hash(vec2(lane, 1.0)) * 7.0);
	float streak = step(0.75, hash(vec2(lane, 2.0))) * smoothstep(0.0, 0.03, fall) * smoothstep(0.18, 0.03, fall)
		* smoothstep(0.45, 0.1, abs(fract(r.x) - 0.5));
	col += streak * vec3(0.35, 0.4, 0.5) * (0.4 + 0.6 * exp(-d * 4.0));

	// Drops on the glass catch a little light.
	vec2 g = uv * vec2(16.0, 22.0);
	vec2 gi = floor(g);
	vec2 offset = vec2(hash(gi), hash(gi + 1.3)) - 0.5;
	float drop = step(0.78, hash(gi + 3.1)) * smoothstep(0.16, 0.06, length(fract(g) - 0.5 - offset * 0.5));
	col += drop * 0.07;

	// Old glass: a little grime and a cold tint.
	col *= vec3(0.9, 0.95, 1.05) * (0.9 + 0.1 * hash(floor(uv * 40.0)));
	ALBEDO = col * brightness;
}
