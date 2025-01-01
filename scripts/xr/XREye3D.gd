@tool
class_name XREye3D extends Camera3D

## Splits off individual views from an XRCamera. Like for pulling out your eyeball in VR
## Unsure if this will work yet without a custom pojection matrix
## Despite that, this Node may still be useful for rendering something custom to each eye

## The view index associated with this eye
@export var index := 0 :
	set(value):
		index = value
		_setup_blit()

## Set an external Viewport in case you want access to it
@export var external_viewport : Viewport :
	set(value):
		# Reinitialize internal viewport if this value is being nulled
		if value == null: #and internal_viewport == external_viewport: 
			external_viewport = null
			_setup_internal_viewport()
			_setup_blit()
			return
		
		# Set the value
		external_viewport = value
		
		# The internal viewport is no longer needed
		if internal_viewport:
			remove_child(internal_viewport)
		
		# Now it is a proxy for the external viewport
		internal_viewport = external_viewport
		
		# Update the viewport with the latest info
		_setup_blit()

## The viewport that is used internally to render the view. Equals to external viewport when specified
var internal_viewport : Viewport

## A quad for copying the rendered view into the main XR viewport
var blit_quad : MeshInstance3D


# TODO
# - Support an external viewport
# - Support an external XRCamera3D (one that is not parent)
# - Render everything to left eye for recording videos


# PRIVATE

# Warns user if the node is setup incorrectly
func _get_configuration_warnings() -> PackedStringArray:
	var warnings : PackedStringArray
	
	if not (get_parent() is XRCamera3D):
		warnings.append("XREye3D must be child of XRCamera3D")
	
	return warnings

# Akin to set_perspective(), but the space is sheared around the camera position.
func _set_perspective_and_shear(camera:Camera3D, fov:float, z_near:float, z_far:float, shear:Vector2):
	camera.set_frustum(2.0 * tan(deg_to_rad(fov/2.0)) * z_near, shear * z_near, z_near, z_far)

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if not (get_parent() is XRCamera3D): return
	
	if external_viewport:
		internal_viewport = external_viewport
	else:
		_setup_internal_viewport()
	
	_setup_blit()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if not (get_parent() is XRCamera3D): return
	
	var aspect : float = float(internal_viewport.size.x) / internal_viewport.size.y
	
	# Set the eye transform relative to the head camera
	global_transform = XRServer.primary_interface.get_transform_for_view(index, XRServer.world_origin)
	
	var projection_matrix : Projection = XRServer.primary_interface.get_projection_for_view(index, aspect, get_parent().near, get_parent().far)
	
	# Match the projection the best we can. Won't work for all XR devices without custom projection
	near = get_parent().near
	far = get_parent().far
	fov = get_parent().fov
	
	_set_perspective_and_shear(self, fov, near, far, Vector2(projection_matrix[2].x, projection_matrix[2].y) / projection_matrix[2].z)

func _setup_internal_viewport() -> void:
	if internal_viewport:
		remove_child(internal_viewport)
	
	internal_viewport = SubViewport.new()
	add_child(internal_viewport)

func _setup_blit() -> void:
	if internal_viewport == null:
		return
	
	RenderingServer.viewport_attach_camera(internal_viewport.get_viewport_rid(), get_camera_rid())
	
	# Set resolution
	internal_viewport.size = XRServer.primary_interface.get_render_target_size()
	
	if blit_quad == null:
		blit_quad = MeshInstance3D.new()
		blit_quad.mesh = QuadMesh.new()
		blit_quad.mesh.size = Vector2(2,2)
		
		# No idea why this doesn't work
		#blit_quad.material_override = ShaderMaterial.new()
		#blit_quad.material_override.resource_local_to_scene = true
		#blit_quad.material_override.shader = Shader.new()
		#blit_quad.material_override.shader.code = _blit_shader_code
		
		var _material : Material = ShaderMaterial.new()
		_material.material_override.resource_local_to_scene = true
		_material.material_override.shader = Shader.new()
		_material.material_override.shader.code = _blit_shader_code
		blit_quad.material_override = _material
		
		add_child(blit_quad)
	
	# Update the uniforms
	blit_quad.material_override.set_shader_paramater("view", index)
	blit_quad.material_override.set_shader_paramater("view_tex", internal_viewport.get_texture())


const _blit_shader_code : String = "
		shader_type spatial;
		
		render_mode unshaded, cull_disabled;
		
		uniform int view = 0;
		uniform sampler2D view_tex : source_color;
		
		void vertex(){
			// Cull everything
			POSITION = vec4(0,0,2,1);
			
			// Find a way to detect XRCamera so we can render only to that
			// Otherwise, undefined behavior could ensue
			bool xr_camera = eye_offset != vec3(0);
			
			// Workaround because VIEW_INDEX doesn't work on the OpenGL renderer
			int my_view_index = (EYE_OFFSET > 0.0) ? 1 : 0;
			
			// Render it if this is the desired view
			if (xr_camera && my_view_index == view){
				POSITION = vec4(VERTEX.xy, 0.999999, 1.0);
			}
		}
		
		void fragment(){
			vec2 uv = SCREEN_UV;
			
			// Unsure why this is needed for it to work on the OpenGL renderer
			if(OUTPUT_IS_SRGB){
				uv.y = 1.0 - uv.y;
			}
			
			ALBEDO = texture(view_tex, uv).rgb;
		}
"