@tool
class_name HelloTriangleEffect extends RenderingEffect

## This script serves as an example for rendering directly into the scene via the RenderingEffect API


# TODO
# Find a way to get internal framebuffer
# Fix hardcoded _framebuffer_format
# XR support


# PUBLIC

var transform : Transform3D


# PRIVATE

var _RD : RenderingDevice
var _p_framebuffer : RID
var _framebuffer_format

var _p_render_pipeline : RID
var _p_render_pipeline_uniform_set : RID
var p_vertex_buffer : RID
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
	# Get the framebuffer format, somehow
	var attachment_formats = [RDAttachmentFormat.new(),RDAttachmentFormat.new()]
	attachment_formats[0].usage_flags = _RD.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
	attachment_formats[0].format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	attachment_formats[1].usage_flags = _RD.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT
	attachment_formats[1].format = _RD.DATA_FORMAT_D24_UNORM_S8_UINT if _RD.texture_is_format_supported_for_usage(_RD.DATA_FORMAT_D24_UNORM_S8_UINT, attachment_formats[1].usage_flags) else _RD.DATA_FORMAT_D32_SFLOAT_S8_UINT
	
	_framebuffer_format = _RD.framebuffer_format_create( attachment_formats )
	
	# Compile using the default shader source defined at the end of this file
	_p_shader = _compile_shader()
	
	# Create vertex buffer
	var vertex_buffer_bytes : PackedByteArray = _vertex_buffer.to_byte_array()
	p_vertex_buffer = _RD.vertex_buffer_create(vertex_buffer_bytes.size(), vertex_buffer_bytes)
	
	# A little trick to reuse the same buffer for multiple attributes
	var vertex_buffers := [p_vertex_buffer, p_vertex_buffer]
	
	var sizeof_float := 4 # Needed to compute byte offset and stride
	var stride := 7 # How far until the next element
	
	var vertex_attrs = [RDVertexAttribute.new(), RDVertexAttribute.new()]
	vertex_attrs[0].format = _RD.DATA_FORMAT_R32G32B32_SFLOAT # vec3 equivalent
	vertex_attrs[0].location = 0 # layout binding
	vertex_attrs[0].offset = 0 * sizeof_float
	vertex_attrs[0].stride = stride * sizeof_float # How far until the next element, in bytes
	vertex_attrs[1].format = _RD.DATA_FORMAT_R32G32B32A32_SFLOAT # vec4 equivalent
	vertex_attrs[1].location = 1  # layout binding
	vertex_attrs[1].offset = 3 * sizeof_float
	vertex_attrs[1].stride = stride * sizeof_float # How far until the next element, in bytes
	var vertex_format = _RD.vertex_format_create(vertex_attrs)
	
	# Create a VAO, which keeps all of our vertex state handy for later
	_p_vertex_array = _RD.vertex_array_create(_vertex_buffer.size()/stride, vertex_format, vertex_buffers)
	
	# Inform the rasterizer what we need to do
	var raster_state = RDPipelineRasterizationState.new()
	raster_state.cull_mode = RenderingDevice.POLYGON_CULL_DISABLED
	var depth_state = RDPipelineDepthStencilState.new()
	depth_state.enable_depth_write = true
	depth_state.enable_depth_test = true
	depth_state.depth_compare_operator = RenderingDevice.COMPARE_OP_LESS
	
	var blend = RDPipelineColorBlendState.new()
	blend.attachments.push_back( RDPipelineColorBlendStateAttachment.new() )
	
	# Finally, create the render pipeline
	_p_render_pipeline = _RD.render_pipeline_create(
		_p_shader,
		_framebuffer_format,
		vertex_format,
		_RD.RENDER_PRIMITIVE_TRIANGLES,
		raster_state,
		RDPipelineMultisampleState.new(),
		depth_state,
		blend)

var _prev_size : Vector2i
func _render_callback(_effect_callback_type : int, render_data : RenderData):
	# Exit if we are not at the correct time
	if _effect_callback_type != effect_callback_type: return
	
	var render_scene_buffers : RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	var render_scene_data : RenderSceneData = render_data.get_render_scene_data()
	
	# Exit if, for whatever reason, we cannot aquire buffers
	if not render_scene_buffers: return
	
	var view_count : int = render_scene_buffers.get_view_count()
	var current_size : Vector2i = render_scene_buffers.get_internal_size()

	# Recreate framebuffer if needed
	if current_size != _prev_size:
		# Unsure what to do here, just getting a lot of errors
		#if _p_framebuffer.is_valid():
		#	_RD.free_rid(_p_framebuffer)
		
		var textures = [ render_scene_buffers.get_color_texture(), render_scene_buffers.get_depth_texture() ]
		_p_framebuffer = _RD.framebuffer_create(textures, -1, view_count)
		
		_prev_size = current_size
	
	
	_RD.draw_command_begin_label("Hello, Triangle!", Color(1.0, 1.0, 1.0, 1.0))
	
	# Loop through views just in case we're doing stereo rendering. No extra cost if this is mono.
	for view in range(view_count):
		var draw_list : int = _RD.draw_list_begin(
			_p_framebuffer, 
			_RD.INITIAL_ACTION_CONTINUE,
			_RD.FINAL_ACTION_CONTINUE,
			_RD.INITIAL_ACTION_CONTINUE,
			_RD.FINAL_ACTION_CONTINUE,
			_clear_colors)
		
		_RD.draw_list_bind_render_pipeline(draw_list, _p_render_pipeline)
		_RD.draw_list_bind_vertex_array(draw_list, _p_vertex_array)
		
		# Setup model view projection
		var flip_y := true # true here implies that we are not using the OpenGL renderer. Oddly enough, projection matrices are provided in OpenGL style
		var MVP : Projection = Projection.create_depth_correction(flip_y) * render_scene_data.get_view_projection(view)
		MVP *= Projection(render_scene_data.get_cam_transform().inverse() * transform)
		
		# Send data to our shader
		var buffer := PackedFloat32Array()
		buffer.resize(16)
		
		for i in range(0,16):
			buffer[i] = MVP[i/4][i%4]
		
		var buffer_bytes : PackedByteArray = buffer.to_byte_array()
		_RD.draw_list_set_push_constant(draw_list, buffer_bytes, buffer_bytes.size())
		
		# Draw it!
		_RD.draw_list_draw(draw_list, false, 1)
		
		_RD.draw_list_end()
	
	_RD.draw_command_end_label()

func _notification(what):
	if what == NOTIFICATION_PREDELETE: # Cleanup
		if _p_render_pipeline.is_valid():
			_RD.free_rid(_p_render_pipeline)
		if _p_shader.is_valid():
			_RD.free_rid(_p_shader)
		if _p_vertex_array.is_valid():
			_RD.free_rid(_p_vertex_array)
		if p_vertex_buffer.is_valid():
			_RD.free_rid(p_vertex_buffer)
		if _p_render_pipeline_uniform_set.is_valid():
			_RD.free_rid(_p_render_pipeline_uniform_set)
		if _p_framebuffer.is_valid():
			_RD.free_rid(_p_framebuffer)

var _vertex_buffer := PackedFloat32Array([
		-0.5,-0.288675,0, 1,0,0,1,
		0.5,-0.288675,0, 0,1,0,1,
		0,0.57735,0, 0,0,1,1,
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
