@tool
extends Node

var _macros := {}

# Adds a macro to the shader include. Overrides any macros of the same name that come before the #include directive, but not after.
func set_shader_macro(name : StringName, code : String = "") -> void:
	_macros[name] = code
	
	_update()

## Gets a previously set macro by set_shader_macro()
func get_shader_macro(name : StringName) -> String:
	return _macros[name]

func clear_shader_macros() -> void:
	_macros.clear()
	
	_update()

## Updates the ShaderInclude resource, which triggers all shaders that depend on it to recompile!
func _update():
	var include_file : ShaderInclude = preload("macroaccess.gdshaderinc")
	
	var new_code : String = ""
	for name in _macros.keys():
		new_code += "#ifdef " + name + "\n"
		new_code += "#undef " + name + "\n"
		new_code += "#endif\n"
		
		new_code += "#define " + name + " " + _macros[name] + "\n\n"
	
	include_file.code = new_code
	#print(updated_code.code)
