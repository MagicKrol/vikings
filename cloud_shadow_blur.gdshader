shader_type canvas_item;

uniform float blur_radius = 18.0;

void fragment() {
	vec4 tint = COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE * blur_radius;
	vec4 color = texture(TEXTURE, UV) * 4.0;
	color += texture(TEXTURE, UV + vec2(px.x, 0.0));
	color += texture(TEXTURE, UV - vec2(px.x, 0.0));
	color += texture(TEXTURE, UV + vec2(0.0, px.y));
	color += texture(TEXTURE, UV - vec2(0.0, px.y));
	color += texture(TEXTURE, UV + vec2(px.x, px.y));
	color += texture(TEXTURE, UV + vec2(-px.x, px.y));
	color += texture(TEXTURE, UV + vec2(px.x, -px.y));
	color += texture(TEXTURE, UV + vec2(-px.x, -px.y));
	color /= 12.0;
	COLOR = color * tint;
}
