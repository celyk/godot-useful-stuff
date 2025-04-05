class_name ShaderRenderTool extends RefCounted

## Helper tool for rendering plain GLSL shaders to a texture via [RenderingDevice].
##
## Blah blah blah blah.
## [br]
## [br]Below is an example of how ShaderRenderTool may be used.
## [codeblock]
##	var grt = ShaderRenderTool.new()
##
##	grt.set_shader(grt.compile_shader())
##
##	var img = grt.render()
## [/codeblock]


# PUBLIC

func compile_shader(source_fragment : String = _default_source_fragment, source_vertex : String = _default_source_vertex) -> RID:
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

func set_shader(value : RID):
	_p_shader = value
	
	_init_render_pipeline()

func render() -> Image:
	# Queue draw commands, without clearing whats already in the frame
	var draw_list : int = -1
	if Engine.get_version_info().major == 4 and Engine.get_version_info().minor < 4:
		draw_list = _RD.call("draw_list_begin",
			_p_framebuffer,
			_RD.INITIAL_ACTION_CLEAR,
			_RD.FINAL_ACTION_READ,
			_RD.INITIAL_ACTION_CLEAR,
			_RD.FINAL_ACTION_READ,
			_clear_colors,
			1.0,
			0,
			Rect2())
	else:
		draw_list = _RD.call("draw_list_begin",
			_p_framebuffer,
			_RD.DRAW_CLEAR_COLOR_ALL,
			_clear_colors,
			1.0, 
			0, 
			Rect2(),
			0)
	
	_RD.draw_list_bind_render_pipeline(draw_list, _p_render_pipeline)
	_RD.draw_list_bind_vertex_array(draw_list, _p_vertex_array)
	_RD.draw_list_bind_index_array(draw_list, _p_index_array)
	#_RD.draw_list_bind_uniform_set(draw_list, _p_render_pipeline_uniform_set, 0)
	_RD.draw_list_draw(draw_list, true, 1)
	_RD.draw_list_end()
	
	# Actually render
	_RD.submit()
	
	# Wait for threads
	_RD.sync()
	
	var output_bytes : PackedByteArray = _RD.texture_get_data(_attachments[0], 0)
	var img := Image.create_from_data(_size.x, _size.y, false, Image.FORMAT_RGBAF, output_bytes)
	
	return img


# PRIVATE

var _size = Vector2i(256,256)
var _color_format := RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
#var _desired_framebuffer_format : RenderingDevice.DataFormat = RenderingDevice.DataFormat.DATA_FORMAT_R32G32B32A32_SFLOAT

var _RD : RenderingDevice
var _attachments = []
var _framebuffer_format
var _p_framebuffer: RID

var _p_render_pipeline : RID
var _p_render_pipeline_uniform_set : RID
var _p_vertex_array : RID
var _p_index_array : RID
var _p_shader : RID
var _clear_colors := PackedColorArray([Color.DARK_RED])

func _init():
	# Create rendering device on a seperate thread
	_RD = RenderingServer.create_local_rendering_device()
	
	_init_framebuffer()

func _init_framebuffer():
	var attachment_formats = [RDAttachmentFormat.new(),RDAttachmentFormat.new()]
	attachment_formats[0].format = _color_format
	attachment_formats[0].usage_flags = _RD.TEXTURE_USAGE_SAMPLING_BIT | _RD.TEXTURE_USAGE_CAN_COPY_FROM_BIT | _RD.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
	attachment_formats[1].format = _RD.DATA_FORMAT_D32_SFLOAT
	attachment_formats[1].usage_flags = _RD.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT

	var color_texture_format = RDTextureFormat.new()
	color_texture_format.texture_type = _RD.TEXTURE_TYPE_2D
	color_texture_format.width = _size.x
	color_texture_format.height = _size.y
	color_texture_format.format = attachment_formats[0].format
	color_texture_format.usage_bits = attachment_formats[0].usage_flags
	
	_attachments.push_back( _RD.texture_create(color_texture_format,RDTextureView.new()) )
	
	var depth_texture_format = RDTextureFormat.new()
	depth_texture_format.texture_type = _RD.TEXTURE_TYPE_2D
	depth_texture_format.width = _size.x
	depth_texture_format.height = _size.y
	depth_texture_format.format = attachment_formats[1].format
	depth_texture_format.usage_bits = attachment_formats[1].usage_flags
	
	_attachments.push_back( _RD.texture_create(depth_texture_format,RDTextureView.new()) )
	
	if _RD.texture_is_valid(_attachments[0]) and _RD.texture_is_format_supported_for_usage(attachment_formats[0].format,attachment_formats[0].usage_flags):
		print("format0 supported")
	else: print("format0 not supported")
	if _RD.texture_is_valid(_attachments[1]) and _RD.texture_is_format_supported_for_usage(attachment_formats[1].format,attachment_formats[1].usage_flags):
		print("format1 supported")
	else: print("format1 not supported")

	_framebuffer_format = _RD.framebuffer_format_create( attachment_formats )
	_p_framebuffer = _RD.framebuffer_create( _attachments )
	#_p_framebuffer = _RD.framebuffer_create_empty(_size)

func _init_render_pipeline():
	var vertex_buffer_bytes : PackedByteArray = _vertex_buffer.to_byte_array()
	var index_buffer_bytes : PackedByteArray = _index_buffer.to_byte_array()
	
	var p_vertex_buffer : RID = _RD.vertex_buffer_create(vertex_buffer_bytes.size(), vertex_buffer_bytes)
	var p_index_buffer : RID = _RD.index_buffer_create(6, _RD.INDEX_BUFFER_FORMAT_UINT32, index_buffer_bytes)
	
	var vertex_buffers := [p_vertex_buffer, p_vertex_buffer]
	
	var sizeof_float = 4
	
	var vertex_attrs = [RDVertexAttribute.new(), RDVertexAttribute.new()]
	vertex_attrs[0].format = _RD.DATA_FORMAT_R32G32B32_SFLOAT
	vertex_attrs[0].location = 0
	vertex_attrs[0].offset = 0*sizeof_float
	vertex_attrs[0].stride = 5*sizeof_float
	vertex_attrs[1].format = _RD.DATA_FORMAT_R32G32_SFLOAT
	vertex_attrs[1].location = 1
	vertex_attrs[1].offset = 3*sizeof_float
	vertex_attrs[1].stride = 5*sizeof_float
	var vertex_format = _RD.vertex_format_create(vertex_attrs)
	
	#var vertex_count = _index_buffer.size()
	#vertex_count = 3
	_p_vertex_array = _RD.vertex_array_create(_vertex_buffer.size()/5, vertex_format, vertex_buffers)#, PackedInt64Array([0,3]))
	_p_index_array =  _RD.index_array_create(p_index_buffer, 0, _index_buffer.size())
	
	var uniforms = []
	var uniform := RDUniform.new()
	#uniform.binding = 0
	#uniform.uniform_type = _RD.
	#uniforms.push_back( uniform )
	
	#_p_render_pipeline_uniform_set = _RD.uniform_set_create(uniforms,_p_shader,0)
	
	var raster_state = RDPipelineRasterizationState.new()
	var depth_state = RDPipelineDepthStencilState.new()
	depth_state.enable_depth_write = true
	depth_state.enable_depth_test = true
	depth_state.depth_compare_operator = RenderingDevice.COMPARE_OP_LESS
	#depth_state.depth_compare_operator = RenderingDevice.COMPARE_OP_ALWAYS
	
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

# Destructor... RefCounted may have issues
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		_RD.free_rid(_p_framebuffer)		
		
		# Free all framebuffer attachments
		for p_texture in _attachments:
			_RD.free_rid(p_texture)
		
		#_RD.free_rid(_framebuffer_format) ??
		#_RD.free_rid(_p_render_pipeline_uniform_set)
		_RD.free_rid(_p_vertex_array)
		_RD.free_rid(_p_index_array)
		_RD.free_rid(_p_shader)
		
		_RD.free()

# DATA
#var _vertex_buffer := PackedFloat32Array([-1,-1,0, 0,0, 1,-1,0, 1,0, 1,1,0, 1,1, -1,1,0, 0,1])
#var _index_buffer := PackedInt32Array([0,1,2, 2,3,0])
var _vertex_buffer := PackedFloat32Array([
		-.5,-.8,.5, 0,0, 
		1,-1,.5, 1,0, 
		0,1,.5, 1,1, 
		-1,1,1, .5,.5,
		1,1,1, .5,.5, 
		0,0,0, 0,0
		])
var _index_buffer := PackedInt32Array([0,1,2, 3,4,5])

const _default_source_vertex = "
		#version 450
		
		layout(location = 0) in vec3 a_Position;
		layout(location = 1) in vec2 a_Uv;
		
		layout(location = 2) out vec2 v_Uv;
		
		void main(){
			v_Uv = a_Uv;
			gl_Position = vec4(a_Position, 1);
		}
		"

const _default_source_fragment = "
		#version 450
		
		layout(location = 2) in vec2 v_Uv;
		
		layout(location = 0) out vec4 COLOR;
		
		//layout(location = 0) uniform float u_test;
		
		void main(){
			COLOR = vec4(v_Uv, 1, 1);
		}
		"
