@tool
extends EditorPlugin


func _enter_tree():
	add_autoload_singleton("MacroAccess", "res://addons/macroaccess/macroaccess.tscn")

func _exit_tree():
	remove_autoload_singleton("MacroAccess")
