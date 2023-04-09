shader_type canvas_item;

render_mode skip_vertex_transform;

uniform mat4 mvp;

varying vec4 modulate_interp;
varying vec4 position_interp;
void vertex(){
	modulate_interp = COLOR;
	
	VERTEX.y = -VERTEX.y;
	position_interp = mvp * vec4(VERTEX,0,1);
	
	position_interp.w = 1.0/position_interp.w;
	
	
	VERTEX = position_interp.xy;
	VERTEX.y = -VERTEX.y;
	VERTEX *= position_interp.w;
	UV *= position_interp.w;
	modulate_interp *= position_interp.w;
	
	
	VERTEX = (inverse(CANVAS_MATRIX) * inverse(SCREEN_MATRIX) * vec4(VERTEX,0,1)).xy;
	
	if(position_interp.w < 0.0){
		VERTEX /= 0.0;
	}
}

void fragment() {
	float w = 1.0 / position_interp.w;
	vec2 uv = UV * w;
	vec4 col = modulate_interp * w;
	
	COLOR = texture(TEXTURE,uv) * col;
	//COLOR.xyz = vec3(position_interp.xy*.1,0);
	//UV = vec2(.1);
	//COLOR = texture(TEXTURE,UV);
}
