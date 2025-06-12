@tool
extends EditorPlugin


func _enter_tree():
	var plugin_dir : String = get_script().resource_path.path_join("..").simplify_path()
	add_autoload_singleton("MacroAccess", plugin_dir.path_join("macroaccess.tscn"))

func _exit_tree():
	remove_autoload_singleton("MacroAccess")
