# TextEdit box for editing a shader at runtime

class_name ShaderTextEdit extends TextEdit

@export var target_shader : Shader

func recompile():
	if target_shader:
		target_shader.code = text

func _input(event):
	if event is InputEventKey:
		if event.alt_pressed and event.keycode == KEY_ENTER:
			if get_viewport().gui_get_focus_owner() == self:
				recompile()

func _ready():
	if target_shader:
		# set text to initial shader file
		text = target_shader.code
