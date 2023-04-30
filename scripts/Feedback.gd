@tool
class_name Feedback extends SubViewport

## A node for creating texture feedback loops.
##
## Feedback is a [Viewport] that simply copies it's parent viewport, enabling safe access to the parent viewports previous frame.
## [br]
## [br]It automatically takes the size of the parent viewport.
## [br]
## [br]This node is still in development.


# PRIVATE

# TODO:
# update on resize
# cleanup signals
# simplify rendering
# cache _material

var _editor_viewport : Node
var _parent_viewport : Viewport

func _init():
	render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _notification(what):
	match what:
		NOTIFICATION_POST_ENTER_TREE:
			_init_blit()
			
			# get_viewport() on a viewport returns itself
			_parent_viewport = get_parent().get_viewport()
			_update()
			
			if Engine.is_editor_hint(): 
				get_tree().get_root().gui_focus_changed.connect(_find_editor_viewport)
		
		NOTIFICATION_PREDELETE:
			_cleanup_blit()


func _find_editor_viewport(node : Node) -> void:
	print(node)
	if node.get_class() == "CanvasItemEditorViewport":
		print("2d time")
		_parent_viewport = get_tree().get_root()
		_editor_viewport = node
		_update()
		
	var parent = node.get_parent()	
	if parent && parent.get_class() == "Node3DEditorViewport":
		print("not 2d time")
		_parent_viewport = parent.get_child(0).get_child(0)
		_editor_viewport = node
		_update()

func _update() -> void:
	if not _is_editor_viewport(_parent_viewport):
		size = _parent_viewport.size
	else:
		size = _editor_viewport.size
	
	_set_blit_crop_transform()
	
	_material.set_shader_parameter("tex", _parent_viewport.get_texture())

func _is_editor_viewport(vp : Viewport) -> bool:
	return Engine.is_editor_hint() && vp == get_tree().get_root()


# RENDERING

var _p_viewport : RID
var _p_scenario : RID
var _p_camera : RID
var _p_base : RID
var _p_instance : RID
var _material : Material

func _init_blit() -> void:
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
	_material.shader.code = _blit_shader_code
	
	RenderingServer.mesh_surface_set_material(_p_base, 0, _material.get_rid())

func _cleanup_blit() -> void:
	RenderingServer.free_rid(_p_instance)
	RenderingServer.free_rid(_p_base)
	RenderingServer.free_rid(_p_camera)
	RenderingServer.free_rid(_p_scenario)

# texture space to world space transform
func _rect_to_transform(rect : Rect2) -> Transform2D:
	return Transform2D(Vector2(rect.size.x,0), Vector2(0,rect.size.y), rect.position)

func _set_blit_crop_transform() -> void: # bad name
	var transform := Transform2D()
	
	if _is_editor_viewport(_parent_viewport):
		transform = transform.translated(Vector2(1,1)).scaled(Vector2(0.5,0.5))
		transform = _rect_to_transform( _editor_viewport.get_global_rect() ) * transform
		transform = _editor_viewport.get_viewport_transform().scaled(Vector2(1,1)/Vector2(_parent_viewport.size)) * transform
		transform = transform.translated(-Vector2(0.5,0.5)).scaled(Vector2(2,2))
		transform = transform.affine_inverse()
	
	RenderingServer.instance_set_transform(_p_instance, Transform3D(transform))


# DATA

const _blit_shader_code = "
		shader_type spatial;
		
		render_mode unshaded, cull_disabled;
		
		uniform sampler2D tex : source_color,filter_nearest;
		
		void vertex(){
			POSITION = MODEL_MATRIX * vec4(VERTEX,1);
			UV.y = 1.0 - UV.y;
		}
		
		void fragment(){
			vec4 samp = textureLod(tex, UV, 0.0);
			ALBEDO = samp.rgb;
			ALPHA = samp.a;
			//ALBEDO = vec3(1,.3,.4);
		}
		"
