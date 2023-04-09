@tool
extends TextEdit

@export var target_shader : Shader

func recompile():
	target_shader.code = text

func _input(event):
	if event is InputEventKey:
		if event.alt_pressed and event.keycode == KEY_ENTER:
			recompile()

func _ready():
	text = target_shader.code
	#clip_children = 0

# Called when the node enters the scene tree for the first time.
#func _ready():
#	text_changed.connect(_update)

@onready var node_3d = $"../../Node3D"

func _process(dt):
	var vp : Viewport = get_viewport()
	var camera : Camera3D = vp.get_camera_3d()
	
	var mvp : Projection = Projection(camera.get_camera_transform().affine_inverse() * node_3d.global_transform)
	
	mvp = Projection.create_perspective(
			camera.fov,
			(vp.size.x * 1.0/vp.size.y),
			camera.near,
			camera.far) * mvp
	
	material.set_shader_parameter("mvp",mvp)
