@tool
class_name Feedback extends SubViewport

## [br]A node for creating texture feedback loops.
## [br][color=purple]Made by celyk[/color]
## @tutorial(celyk's repo): https://github.com/celyk/godot-useful-stuff
##
## Feedback is a [Viewport] that simply copies it's parent viewport, enabling safe access to the parent viewports previous frame.
## [br]
## [br]It automatically takes the size of the parent viewport.

## Make Feedback use 2D rendering. Can make 8-bit colors more consistent
@export var only_2d := false

# PRIVATE

# TODO:
# simplify rendering
# cache shader
# xr support

var _parent_viewport : Viewport

func _init():
	size = size
	render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _notification(what):
	match what:
		NOTIFICATION_POST_ENTER_TREE: # the node entered the tree and is ready
			_init_blit()
			
			_safe_disconnect(_parent_viewport, "size_changed", _handle_resize)
			
			_parent_viewport = _find_parent_viewport()
			_handle_resize()
			
			
			# editor shenanigans
			if Engine.is_editor_hint() && has_method("_do_handle_editor") && call("_do_handle_editor"): 
				return
			
			
			_safe_connect(_parent_viewport, "size_changed", _handle_resize)
		
		NOTIFICATION_PREDELETE:
			_cleanup_blit()
			_safe_disconnect(_parent_viewport, "size_changed", _handle_resize)

func _find_parent_viewport():
	return get_parent().get_viewport() # get_viewport() on a viewport returns itself

func _handle_resize():
	size = _parent_viewport.size
	_material.set_shader_parameter("tex", _parent_viewport.get_texture())

func _safe_connect(obj : Object, sig: StringName, callable : Callable, flags : int = 0) -> void:
	if obj && !obj.is_connected(sig, callable): obj.connect(sig, callable, flags)
func _safe_disconnect(obj : Object, sig: StringName, callable : Callable) -> void:
	if obj && obj.is_connected(sig, callable): obj.disconnect(sig, callable)


# RENDERING

var _p_viewport : RID
var _p_scenario : RID
var _p_camera : RID
var _p_base : RID
var _p_instance : RID
var _material : Material
var _p_light_base : RID
var _p_light_instance : RID

func _init_blit() -> void:
	if _p_viewport.is_valid():
		# fixes a bug when switching scene
		RenderingServer.viewport_set_scenario(_p_viewport, _p_scenario)
		RenderingServer.viewport_attach_camera(_p_viewport, _p_camera)
		return
	
	_p_scenario = RenderingServer.scenario_create()
	_p_viewport = get_viewport_rid()

	RenderingServer.viewport_set_scenario(_p_viewport, _p_scenario)
	
	# camera setup
	_p_camera = RenderingServer.camera_create();
	RenderingServer.viewport_attach_camera(_p_viewport, _p_camera)
	var p_env = RenderingServer.environment_create()
	RenderingServer.camera_set_environment(_p_camera, p_env)
	RenderingServer.camera_set_transform(_p_camera, Transform3D(Basis(), Vector3(0, 0, 1)))
	RenderingServer.camera_set_orthogonal(_p_camera, 2.1, 0.1, 10)
	
	# quad setup
	_p_base = RenderingServer.mesh_create()
	_p_instance = RenderingServer.instance_create2(_p_base, _p_scenario)
	
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(2,2)
	var arr = quad_mesh.get_mesh_arrays()
	RenderingServer.mesh_add_surface_from_arrays(_p_base, RenderingServer.PRIMITIVE_TRIANGLES, arr)
	
	_material = ShaderMaterial.new()
	_material.resource_local_to_scene = true
	_material.shader = Shader.new()
	_material.shader.code = _blit_shader_code_spatial
	
	RenderingServer.mesh_surface_set_material(_p_base, 0, _material.get_rid())
	
	# light setup
	_p_light_base = RenderingServer.directional_light_create()
	_p_light_instance = RenderingServer.instance_create2(_p_light_base, _p_scenario)

func _cleanup_blit() -> void:
	RenderingServer.free_rid(_p_instance)
	RenderingServer.free_rid(_p_base)
	RenderingServer.free_rid(_p_camera)
	RenderingServer.free_rid(_p_scenario)
	RenderingServer.free_rid(_p_light_instance)
	RenderingServer.free_rid(_p_light_base)


# DATA

const _blit_shader_code_spatial = '''
		shader_type spatial;
		
		render_mode cull_disabled, ambient_light_disabled, depth_draw_never;
		
		uniform sampler2D tex : source_color, filter_nearest;
		
		void vertex(){
			POSITION = MODEL_MATRIX * vec4(VERTEX,1);
			UV.y = 1.0 - UV.y;
		}
		
		void fragment(){
			FOG = vec4(0);
		}
		
		// This expects 0-1 range input, outside that range it behaves poorly.
		vec3 srgb_to_linear(vec3 color) {
			// Approximation from http://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html
			return mix(pow((color.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)), color.rgb * (1.0 / 12.92), lessThan(color.rgb, vec3(0.04045)));
		}
		
		// Workaround for ALBEDO color error on the compatibility renderer
		void light(){
			vec4 samp = textureLod(tex, UV, 0.0);
			
			if(OUTPUT_IS_SRGB){
				SPECULAR_LIGHT = srgb_to_linear(samp.rgb);
			}
			else{
				SPECULAR_LIGHT = samp.rgb;
			}
			
			ALPHA = samp.a;
		}
		'''


const _blit_shader_code_canvas_item = '''
		shader_type canvas_item;
		
		render_mode blend_disabled;
		
		uniform sampler2D tex : source_color, filter_nearest;
		
		void vertex(){
			POSITION = MODEL_MATRIX * vec4(VERTEX,1);
			UV.y = 1.0 - UV.y;
		}
		
		void fragment(){
			vec4 samp = textureLod(tex, UV, 0.0);
			COLOR = samp;
		}
'''


# JANK 
# you can safely delete this section

var _editor_viewport : Control
func _find_editor_viewport(node : Node) -> void:
	if node.get_class() == "CanvasItemEditorViewport":
		_safe_disconnect(_editor_viewport, "resized", _handle_2d_editor_resize)

		_parent_viewport = get_tree().get_root()
		_editor_viewport = node
		
		_handle_2d_editor_resize()

		_safe_connect( _editor_viewport, "resized", _handle_2d_editor_resize)

	var parent = node.get_parent()
	if parent && parent.get_class() == "Node3DEditorViewport":
		_safe_disconnect(_editor_viewport, "resized", _handle_2d_editor_resize)

		_parent_viewport = get_tree().get_root()
		_editor_viewport = parent
		
		_handle_2d_editor_resize()

		_safe_connect( _editor_viewport, "resized", _handle_2d_editor_resize)


# texture space to world space transform
func _rect_to_transform(rect : Rect2) -> Transform2D:
	return Transform2D(Vector2(rect.size.x,0), Vector2(0,rect.size.y), rect.position)

func _handle_2d_editor_resize():
	size = _editor_viewport.size
	_material.set_shader_parameter("tex", _parent_viewport.get_texture())

	var transform := Transform2D()
	transform = transform.translated(Vector2(1,1)).scaled(Vector2(0.5,0.5))
	transform = _rect_to_transform( _editor_viewport.get_global_rect() ) * transform
	transform = _editor_viewport.get_viewport_transform().scaled(Vector2(1,1)/Vector2(_parent_viewport.size)) * transform
	transform = transform.translated(-Vector2(0.5,0.5)).scaled(Vector2(2,2))
	transform = transform.affine_inverse()

	RenderingServer.instance_set_transform(_p_instance, Transform3D(transform))

func _do_handle_editor() -> bool:
	# The issue is that our scene root is not used for rendering when inside the editor
	# We must find the actual viewport used
	_safe_disconnect( get_tree().get_root(), "gui_focus_changed", _find_editor_viewport)

	if _parent_viewport != get_tree().get_edited_scene_root().get_parent():
		return false

	_safe_connect( get_tree().get_root(), "gui_focus_changed", _find_editor_viewport)
	
	return true

func _exit_tree():
	_safe_disconnect( get_tree().get_root(), "gui_focus_changed", _find_editor_viewport)
	_safe_disconnect(_editor_viewport, "resized", _handle_2d_editor_resize)
