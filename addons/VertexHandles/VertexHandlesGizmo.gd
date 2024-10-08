@tool
extends EditorNode3DGizmoPlugin

var editor_plugin : EditorPlugin

func _init(_editor_plugin:EditorPlugin):
	editor_plugin = _editor_plugin
	
	create_material("main", Color(1,1,1), false, true, true)
	create_handle_material("handles",false)

const MyCustomNode3D = preload("VertexHandles.gd")
func _has_gizmo(node):
	return node is MyCustomNode3D

func _create_gizmo(for_node_3d: Node3D) -> EditorNode3DGizmo:
	if not _has_gizmo(for_node_3d):
		return null
	
	var gizmo = EditorNode3DGizmo.new()
	
	# Allows the node3d associated with this gizmo to request redraw
	for_node_3d._request_redraw.connect(_redraw.bind(gizmo))
	
	return gizmo

# show gizmo name in visibility list
func _get_gizmo_name():
	return "VertexHandlesGizmo"

func _get_handle_name(gizmo,id,secondary):
	return str(id)

func _get_handle_value(gizmo,id,secondary):
	var node3d : Node3D = gizmo.get_node_3d()
	return node3d.point_arrays[0][id]

func _set_handle(gizmo,id,secondary,camera,point):
	var node3d : Node3D = gizmo.get_node_3d()
	
	# Construct the view ray in world space
	var ray_from : Vector3 = camera.project_ray_origin(point)
	var ray_dir : Vector3 = camera.project_ray_normal(point)
	
	# Intersect the ray with a camera facing plane
	var plane = Plane(camera.get_camera_transform().basis[2], node3d.global_transform * node3d.point_arrays[0][id])
	var p = Geometry3D.segment_intersects_convex(ray_from,ray_from+ray_dir*16384,[plane])
	
	if p.is_empty():
		return
	
	p = p[0]
	
	# Transform the intersection point from world space to local node space
	p = node3d.global_transform.affine_inverse() * p
	
	node3d.set_point(0, id, p)
	
	_redraw(gizmo)

func _commit_handle(gizmo,id,secondary,restore,cancel):
	var node3d : Node3D = gizmo.get_node_3d()
	
	var undo : EditorUndoRedoManager = editor_plugin.get_undo_redo()
	
	# Allows user to undo
	undo.create_action("Move handle " + str(id))
	undo.add_do_method(node3d, "set_point", 0, id, node3d.point_arrays[0][id])
	undo.add_undo_method(node3d, "set_point", 0, id, restore)
	undo.commit_action(false)

func _redraw(gizmo):
	gizmo.clear()
	
	var node3d : Node3D = gizmo.get_node_3d()
		
	if node3d.wireframe:
		var lines = PackedVector3Array()
		
		var mdt := MeshDataTool.new()
		
		for surface_id in range(0,(node3d.mesh as Mesh).get_surface_count()):
			mdt.create_from_surface(node3d.mesh, surface_id)
			for face_id in range(0,mdt.get_face_count()):
				for j in range(0,3):
					lines.push_back( mdt.get_vertex(mdt.get_face_vertex(face_id,j)) )
					lines.push_back( mdt.get_vertex(mdt.get_face_vertex(face_id,(j+1)%3 )) )
		
		gizmo.add_lines(lines, get_material("main", gizmo), false, node3d.wireframe_color)
	
	
	var handles := PackedVector3Array()
	
	for i in range(0,node3d.point_arrays.size()):
		var point_array = node3d.point_arrays[i]
		
		for j in range(0,point_array.size()):
			handles.push_back( point_array[j] )
			#print(arrays[Mesh.ARRAY_VERTEX][j])
	
	gizmo.add_handles(handles, get_material("handles", gizmo), [], false)
	
	
	#gizmo.set_hidden(not gizmo.is_subgizmo_selected(0))
