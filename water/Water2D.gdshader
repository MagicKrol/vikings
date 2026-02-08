shader_type canvas_item;

uniform vec2 wave_direction = vec2(1.0, 0.0);
uniform float wave_speed = 0.2;
uniform float wave_amplitude = 0.01;
uniform float wave_frequency = 8.0;

uniform sampler2D normalmap_a_sampler;
uniform sampler2D normalmap_b_sampler;
uniform vec2 normal_scale = vec2(0.25, 0.25);
uniform float normal_strength = 0.004;

uniform sampler2D foam_sampler;
uniform vec2 foam_scale = vec2(0.5, 0.5);
uniform float foam_strength = 0.016;

uniform sampler2D caustic_sampler;
uniform vec2 caustic_scale = vec2(0.5, 0.5);
uniform float caustic_strength = 0.016;

void fragment() {
	vec2 uv = UV;
	vec2 dir = normalize(wave_direction);
	float wave_phase = dot(uv, dir) * wave_frequency + TIME * wave_speed;
	vec2 wave_offset = dir * sin(wave_phase) * wave_amplitude;

	vec2 n_uv_a = fract((uv + wave_offset) * normal_scale);
	vec2 n_uv_b = fract((uv + wave_offset * 1.5) * normal_scale);
	vec2 n_a = texture(normalmap_a_sampler, n_uv_a).rg * 2.0 - 1.0;
	vec2 n_b = texture(normalmap_b_sampler, n_uv_b).rg * 2.0 - 1.0;
	vec2 n_offset = (n_a * 0.75 + n_b * 0.25) * normal_strength;

	vec2 final_uv = uv + wave_offset + n_offset;
	vec4 base = texture(TEXTURE, final_uv);

	float foam = texture(foam_sampler, fract((uv + wave_offset) * foam_scale)).r;
	vec3 color = mix(base.rgb, vec3(1.0), foam * foam_strength);

	float caustic = texture(caustic_sampler, fract((uv + wave_offset * 1.25) * caustic_scale)).r;
	color += caustic * caustic_strength;

	COLOR = vec4(color, base.a);
}
