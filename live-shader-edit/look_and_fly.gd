extends Node3D

@export var speed = .2
@export var look_sensitivity = .5

var look_enabled : bool = true
@onready var camera : Camera3D = get_viewport().get_camera_3d()
@onready var target_fov : float = camera.fov

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if look_enabled:
		if event is InputEventMouseMotion:
			rotation.y += deg_to_rad(-event.relative.x*look_sensitivity)
			rotation.x += deg_to_rad(-event.relative.y*look_sensitivity)
			rotation.x = clamp(rotation.x, deg_to_rad(-89), deg_to_rad(89))
		if event is InputEventMouseButton:			
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_fov += 5
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_fov -= 5

			

func _process(delta):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		look_enabled = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if Input.is_action_just_pressed("menu"):
		look_enabled = !look_enabled
		if look_enabled:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if look_enabled:
		var j = Vector2(
			int(Input.is_key_pressed(KEY_D))-int(Input.is_key_pressed(KEY_A)),
			int(Input.is_key_pressed(KEY_W))-int(Input.is_key_pressed(KEY_S))
		)
		
		j = j.normalized()
		
		translate(Vector3(j.x,0,-j.y)*speed);
		
		
		camera.fov = lerp(camera.fov,target_fov,.1)
