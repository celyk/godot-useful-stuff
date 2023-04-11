class_name ShaderTextEdit extends TextEdit

## A text box for editing a shader at runtime.

## The shader which you want to edit.
@export var target_shader : Shader

## Sets the code of the shader to the current text.
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
