@tool
class_name RestartEditor extends EditorScript

## An EditorScript that restarts the editor

func _run() -> void:
	EditorInterface.save_all_scenes()
	EditorInterface.restart_editor.call_deferred(true)
