@tool
class_name ShaderTexture extends ImageTexture

## A texture that takes a shader to generate the output. Useful for caching procedural textures


#region Interface

@export_tool_button("Generate", "Callable") var generate_pulse = generate

@export var size := Vector2i(128,128) :
	set(value):
		size = value
		_update_size()

@export var hdr := false :
	set(value):
		hdr = value
		_update_hdr()

@export var transparency := true :
	set(value):
		transparency = value
		_update_transparency()

@export var use_texture_size := false :
	set(value):
		use_texture_size = value
		_update_size()

@export_tool_button("Save", "Callable") var save_pulse = save_output
@export_tool_button("Load last", "Callable") var load_last_pulse = load_last

@export var input_texture : Texture2D :
	set(value):
		input_texture = value
		_update_input()

@export var material : ShaderMaterial :
	set(value):
		material = value
		
		if material == null: return
		
		_update_material()

#endregion

#region Methods

func generate() -> void:
	if not _initialized: return
	
	RenderingServer.viewport_set_update_mode(_p_viewport, RenderingServer.VIEWPORT_UPDATE_ONCE)
	
	# Wait for the frame to render
	await RenderingServer.frame_post_draw
	
	_blit_viewport()

func save_output() -> void:
	if input_texture == null: return
	
	var path := input_texture.resource_path
	var idx : int = int( path.get_file().get_basename().split("_")[-1] )
	var new_path := path.get_basename() + "_" + str(idx+1)# + "." + path.get_extension()
	#print(new_path)
	
	if not input_texture.is_built_in():
		ResourceSaver.save(self, new_path + ".png")
		#ResourceLoader.load(new_path + ".png")
	
	# If the resource isn't associated with a specific file, open a file save dialog
	elif Engine.is_editor_hint():
		var dialog := EditorFileDialog.new()
		dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg ; Supported Images"])
		
		dialog.file_selected.connect(
			func(path: String):
				ResourceSaver.save(self, path)
		
		)
		
		var tree := Engine.get_main_loop() as SceneTree
		tree.root.add_child(dialog)
		
		dialog.popup_file_dialog()

func load_last() -> void:
	pass

#endregion

#region Initialization

var _initialized := false
func _init() -> void:
	_setup_viewport()
	_update_size()
	
	# Prevent generation on load
	(func(): _initialized = true).call_deferred()
	
#endregion

#region Update state

func _update_material():
	RenderingServer.canvas_item_set_material(_p_canvas_item, material.get_rid())
	
	generate()

func _update_size():
	var internal_size := _get_internal_size()
	RenderingServer.viewport_set_size(_p_viewport, internal_size.x, internal_size.y)
	
	_update_rect()
	
	generate()

func _update_hdr():
	RenderingServer.viewport_set_use_hdr_2d(_p_viewport, hdr)
	
	generate()

func _update_transparency():
	RenderingServer.viewport_set_transparent_background(_p_viewport, transparency)
	
	generate()

func _update_input():
	_update_rect()

#endregion

#region Rect setup

func _update_rect():
	RenderingServer.canvas_item_clear(_p_canvas_item)
	
	var internal_size := _get_internal_size()
	
	if input_texture != null:
		RenderingServer.canvas_item_add_texture_rect(_p_canvas_item, Rect2(Vector2(), internal_size), input_texture.get_rid())
	else:
		RenderingServer.canvas_item_add_rect(_p_canvas_item, Rect2(Vector2(), internal_size), Color(1,1,1,1))

func _get_internal_size() -> Vector2i:
	if use_texture_size and input_texture != null:
		return input_texture.get_size()
	
	return size

var _p_viewport : RID
var _p_canvas : RID
var _p_canvas_item : RID
func _setup_viewport():
	_p_viewport = RenderingServer.viewport_create()
	_p_canvas = RenderingServer.canvas_create()
	
	RenderingServer.viewport_attach_canvas(_p_viewport, _p_canvas)
	RenderingServer.viewport_set_update_mode(_p_viewport, RenderingServer.VIEWPORT_UPDATE_DISABLED)
	RenderingServer.viewport_set_clear_mode(_p_viewport, RenderingServer.VIEWPORT_CLEAR_ONLY_NEXT_FRAME)
	RenderingServer.viewport_set_active(_p_viewport, true)
	RenderingServer.viewport_set_use_hdr_2d(_p_viewport, true)
	
	_p_canvas_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_p_canvas_item, _p_canvas)
	
func _blit_viewport():
	var p_tex : RID = RenderingServer.viewport_get_texture(_p_viewport)
	
	if not p_tex.is_valid(): return
	
	var img := RenderingServer.texture_2d_get(p_tex)
	if not p_tex.is_valid(): return
	set_image(img)

func _cleanup():
	RenderingServer.free_rid(_p_viewport)
	RenderingServer.free_rid(_p_canvas_item)

#endregion
