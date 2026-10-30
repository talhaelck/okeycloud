// Okey tile: glossy cream bakelite with the printed, engraved face taken from the tile atlas
// (tools/tile_atlas.py). Every tile shares this material; the atlas cell comes from an instance uniform.
shader_type spatial;

uniform sampler2D atlas_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D atlas_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 bakelite : source_color = vec3(0.9, 0.86, 0.76);
uniform vec2 grid = vec2(8.0, 7.0);
uniform vec3 highlight_color : source_color = vec3(1.0, 0.78, 0.25);

instance uniform float cell = 53.0;
// 0..1 hover glow.
instance uniform float highlight = 0.0;
// 0 or 1: picked with Ctrl+click to be moved together (a cool blue rim, apart from the warm hover).
uniform vec3 selected_color : source_color = vec3(0.35, 0.7, 1.0);
instance uniform float selected = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	if (UV.x >= 0.0) {
		vec2 c = vec2(mod(cell, grid.x), floor(cell / grid.x));
		// Keep a hair inside the cell so mipmaps never bleed in the neighbour.
		vec2 uv = (c + clamp(UV, vec2(0.004), vec2(0.996))) / grid;
		ALBEDO = texture(atlas_albedo, uv).rgb;
		NORMAL_MAP = texture(atlas_normal, uv).rgb;
		ROUGHNESS = 0.32;
	} else {
		// Sides and back: plain bakelite with faint swirls.
		float swirl = sin(local_pos.x * 260.0 + sin(local_pos.y * 180.0) * 2.0) * 0.5 + 0.5;
		ALBEDO = bakelite * (0.96 + 0.04 * swirl);
		ROUGHNESS = 0.38;
	}
	CLEARCOAT = 0.55;
	CLEARCOAT_ROUGHNESS = 0.22;
	SPECULAR = 0.55;
	// Hover: a warm rim glow, so the number stays readable.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	EMISSION = highlight_color * highlight * (0.08 + rim * 0.9) + selected_color * selected * (0.12 + rim * 1.2);
}
