@tool
class_name HelloTriangleEffect extends RenderingEffect

# TODO
# Proper cleanup
# Find a way to get internal framebuffer
# Add documentation and comments
# XR support
# Fix hardcoded _framebuffer_format

var transform : Transform3D

# PRIVATE

var _RD : RenderingDevice
var _p_framebuffer : RID
var _framebuffer_format

var _p_render_pipeline : RID
var _p_render_pipeline_uniform_set : RID
var _p_vertex_array : RID
var _p_shader : RID
var _clear_colors := PackedColorArray([Color.DARK_BLUE])

func _init():
	_RD = RenderingServer.get_rendering_device()
	
	RenderingServer.call_on_render_thread(_initialize_render)

func _compile_shader(source_fragment : String = _default_source_fragment, source_vertex : String = _default_source_vertex) -> RID:
	var src := RDShaderSource.new()
	src.source_fragment = source_fragment
	src.source_vertex = source_vertex
	
	var shader_spirv : RDShaderSPIRV = _RD.shader_compile_spirv_from_source(src)
	
	var err = shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_VERTEX)
	if err: push_error( err )
	err = shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_FRAGMENT)
	if err: push_error( err )
	
	var p_shader : RID = _RD.shader_create_from_spirv(shader_spirv)
	
	return p_shader

func _initialize_render():
	#_p_framebuffer = _RD.framebuffer_create_empty(Vector2i(100,100))
	#_framebuffer_format = _RD.screen_get_framebuffer_format()
	var attachment_formats = [RDAttachmentFormat.new(),RDAttachmentFormat.new()]
	attachment_formats[0].format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	attachment_formats[0].usage_flags = _RD.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
	attachment_formats[1].format = _RD.DATA_FORMAT_D24_UNORM_S8_UINT
	attachment_formats[1].usage_flags = _RD.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT
	
	_framebuffer_format = _RD.framebuffer_format_create( attachment_formats )
	
	_p_shader = _compile_shader()
	
	
	var vertex_buffer_bytes : PackedByteArray = _vertex_buffer.to_byte_array()
	var p_vertex_buffer : RID = _RD.vertex_buffer_create(vertex_buffer_bytes.size(), vertex_buffer_bytes)
	
	var vertex_buffers := [p_vertex_buffer, p_vertex_buffer]
	
	var sizeof_float := 4
	var stride := 7
	
	var vertex_attrs = [RDVertexAttribute.new(), RDVertexAttribute.new()]
	vertex_attrs[0].format = _RD.DATA_FORMAT_R32G32B32_SFLOAT
	vertex_attrs[0].location = 0
	vertex_attrs[0].offset = 0 * sizeof_float
	vertex_attrs[0].stride = stride * sizeof_float
	vertex_attrs[1].format = _RD.DATA_FORMAT_R32G32B32A32_SFLOAT
	vertex_attrs[1].location = 1
	vertex_attrs[1].offset = 3 * sizeof_float
	vertex_attrs[1].stride = stride * sizeof_float
	var vertex_format = _RD.vertex_format_create(vertex_attrs)
	
	_p_vertex_array = _RD.vertex_array_create(_vertex_buffer.size()/stride, vertex_format, vertex_buffers)
	
	#var uniforms = [RDUniform.new()]
	#uniforms[0].binding = 0
	#uniforms[0].uniform_type = _RD.UNIFORM_TYPE_UNIFORM_BUFFER
	#uniforms[0].push_back( uniform )
	
	#_p_render_pipeline_uniform_set = _RD.uniform_set_create(uniforms, _p_shader, 0)
	
	var raster_state = RDPipelineRasterizationState.new()
	var depth_state = RDPipelineDepthStencilState.new()
	depth_state.enable_depth_write = true
	depth_state.enable_depth_test = true
	depth_state.depth_compare_operator = RenderingDevice.COMPARE_OP_LESS
	
	var blend = RDPipelineColorBlendState.new()
	blend.attachments.push_back( RDPipelineColorBlendStateAttachment.new() )
	
	_p_render_pipeline = _RD.render_pipeline_create(
		_p_shader,
		_framebuffer_format,
		vertex_format,
		_RD.RENDER_PRIMITIVE_TRIANGLES,
		raster_state,
		RDPipelineMultisampleState.new(),
		depth_state,
		blend)

#var textures = [RID(), RID()]
var _prev_size : Vector2i
func _render_callback(_effect_callback_type : int, render_data : RenderData):
	if _effect_callback_type != effect_callback_type: return
	
	var render_scene_buffers : RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	var render_scene_data : RenderSceneData = render_data.get_render_scene_data()
	
	if not render_scene_buffers: return
	
	var view_count : int = render_scene_buffers.get_view_count()
	var current_size : Vector2i = render_scene_buffers.get_internal_size()
	
	if not _p_framebuffer.is_valid() || current_size != _prev_size:
		print("framebuffer recreated")
		var textures = [ render_scene_buffers.get_color_texture(), render_scene_buffers.get_depth_texture() ]
		_p_framebuffer = _RD.framebuffer_create(textures, -1, view_count)
		
		_prev_size = current_size
	
	#return
	
	#var textures := [render_scene_buffers.get_color_texture(), render_scene_buffers.get_depth_texture()]
	#var p := RDFramebufferPass.new()
	#p.color_attachments.push_back(0)
	#p.depth_attachment = 1
	#var passes := [p]
	#_p_framebuffer = FramebufferCacheRD.get_cache_multipass(textures, passes, view_count) #_RD.framebuffer_create_empty(Vector2i(100,100))
	
	# Loop through views just in case we're doing stereo rendering. No extra cost if this is mono.
	for view in range(view_count):
		# Get the RID for our color image, we will be reading from and writing to it.
		#var _p_framebuffer : RID = render_scene_buffers.get_color_layer(view)
		#var textures := [ render_scene_buffers.get_color_layer(view), render_scene_buffers.get_depth_layer(view) ]
		#var p := RDFramebufferPass.new()
		#p.color_attachments.push_back(0)
		#p.depth_attachment = 1
		
		#var passes := [p]
		#_p_framebuffer = FramebufferCacheRD.get_cache_multipass(textures, passes, view_count)
		
		#print(_p_framebuffer.is_valid())
		#print(_p_framebuffer)
		
		#var draw_list : int = _RD.draw_list_begin_for_screen(DisplayServer.MAIN_WINDOW_ID, _clear_colors[0])
		var draw_list : int = _RD.draw_list_begin(
			_p_framebuffer, 
			_RD.INITIAL_ACTION_CONTINUE,
			_RD.FINAL_ACTION_CONTINUE,
			_RD.INITIAL_ACTION_CONTINUE,
			_RD.FINAL_ACTION_CONTINUE,
			_clear_colors)
		
		_RD.draw_list_bind_render_pipeline(draw_list, _p_render_pipeline)
		_RD.draw_list_bind_vertex_array(draw_list, _p_vertex_array)
		#_RD.draw_list_bind_uniform_set(draw_list, _p_render_pipeline_uniform_set, 0)
		
		var MVP : Projection = Projection.create_depth_correction(true) * render_scene_data.get_view_projection(view)
		MVP *= Projection(render_scene_data.get_cam_transform().inverse() * transform)
		
		var buffer := PackedFloat32Array()
		buffer.resize(16)
		
		for i in range(0,16):
			buffer[i] = MVP[i/4][i%4]
		
		var buffer_bytes : PackedByteArray = buffer.to_byte_array()
		_RD.draw_list_set_push_constant(draw_list, buffer_bytes, buffer_bytes.size())
		
		_RD.draw_list_draw(draw_list, false, 1)
		
		_RD.draw_list_end()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if _p_shader.is_valid():
			_RD.free_rid(_p_shader)

var _vertex_buffer := PackedFloat32Array([
		-0.3,-0.5,0.0, 1,0,0,1,
		0.3,-0.5,0.0, 0,1,0,1,
		0,0.7,0.0, 0,0,1,1,
		])

const _default_source_vertex = "
		#version 450
		
		layout(location = 0) in vec3 a_Position;
		layout(location = 1) in vec4 a_Color;
		
		layout(push_constant, std430) uniform pc {
			mat4 MVP;
		};
		
		layout(location = 2) out vec4 v_Color;
		
		void main(){
			v_Color = a_Color;
			
			gl_Position = MVP * vec4(a_Position, 1);
		}
		"

const _default_source_fragment = "
		#version 450
		
		layout(location = 2) in vec4 a_Color;
		
		layout(location = 0) out vec4 frag_color; // Bound to buffer index 0
		
		void main(){
			frag_color = a_Color;
		}
		"
