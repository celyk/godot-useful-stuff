@tool
extends EditorPlugin

const MyCustomGizmoPlugin = preload("VertexHandlesGizmo.gd")

var gizmo_plugin = MyCustomGizmoPlugin.new(self)

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		update_overlays()
		return true
	
	return false

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	add_node_3d_gizmo_plugin(gizmo_plugin)


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	remove_node_3d_gizmo_plugin(gizmo_plugin)
