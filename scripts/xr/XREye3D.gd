@tool
class_name XREye3D extends Camera3D

## Splits off individual views from an XRCamera. Like for pulling out your eyeball in VR
## Unsure if this will work yet without a custom pojection matrix

## The view index associated with this eye
@export var index := 0

## Set an External Viewport in case you want access to it
@export var external_viewport : Viewport :
	set(value):
		# Reinitialize internal viewport if this value is being nulled
		if value == null: #and internal_viewport == external_viewport: 
			_setup_internal_viewport()
			external_viewport = null
			return
		
		external_viewport = value
		
		if internal_viewport:
			remove_child(internal_viewport)
		
		internal_viewport = external_viewport

var internal_viewport : Viewport
var blit_quad : MeshInstance3D

# TODO
# - Support external viewport
# - Render everything to left eye for recording videos

# PRIVATE

func _get_configuration_warnings() -> PackedStringArray:
	var warnings : PackedStringArray
	
	if not (get_parent() is XRCamera3D):
		warnings.append("XREye3D must be child of XRCamera3D")
	
	return warnings

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	if not external_viewport:
		_setup_internal_viewport()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	global_transform = XRServer.primary_interface.get_transform_for_view(index, get_parent().get_camera_transform())

func _setup_internal_viewport():
	if internal_viewport:
		remove_child(internal_viewport)
	
	internal_viewport = SubViewport.new()
	RenderingServer.viewport_attach_camera(internal_viewport.get_viewport_rid(), self)
	
	# Set resolution
	internal_viewport.size = XRServer.primary_interface.get_render_target_size()
	
	add_child(internal_viewport)
	
	_setup_blit()

func _setup_blit():
	if not blit_quad:
		blit_quad = MeshInstance3D.new()
		blit_quad.material_override = ShaderMaterial.new()
		blit_quad.material_override.shader = Shader.new()
		blit_quad.material_override.shader.code = _blit_shader
		add_child(blit_quad)
	
	blit_quad.material_override.set_shader_paramater("view", index)
	blit_quad.material_override.set_shader_paramater("view_tex", internal_viewport.get_texture())


const _blit_shader : String = "
		shader_type spatial;
		
		render_mode unshaded;
		
		uniform int view = 0;
		uniform sampler2D view_tex : source_color;
		
		void vertex(){
			// Cull everything
			POSITION = vec4(0,0,2,1);
			
			// Find a way to detect XRCamera so we can render only to that
			// Otherwise, undefined behavior might ensue
			bool xr_camera = eye_offset != vec3(0);
			
			// Render it if this is the desired view
			if (xr_camera && VIEW_INDEX == view){
				POSITION = vec4(VERTEX.xy, 0.999999, 1.0);
			}
		}
		
		void fragment(){
			ALBEDO = texture(view_tex, UV).rgb;
		}
"