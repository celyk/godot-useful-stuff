@tool
extends EditorNode3DGizmoPlugin

func _init():
	create_material("main", Color(0,1,1),false,true)
	create_handle_material("handles",false)

const MyCustomNode3D = preload("VertexHandles.gd")
func _has_gizmo(node):
	return node is MyCustomNode3D

# show gizmo name in visibility list
func _get_gizmo_name():
	return "VertexHandlesGizmo"

func _get_handle_name(gizmo,id,secondary):
	return str(id)
	match id:
		0:
			return "Radius"
		1:
			return "Width"

func _get_handle_value(gizmo,id,secondary):
	var node3d : Node3D = gizmo.get_node_3d()
	
	return node3d.points[0][id]
	
	match id:
		0:
			return node3d.radius
		1:
			return node3d.width
	
func _set_handle(gizmo,id,secondary,camera,point):
	var node3d : Node3D = gizmo.get_node_3d()
	
	var gt : Transform3D = node3d.get_global_transform()
	var gi : Transform3D = gt.affine_inverse()
	
	var ray_from : Vector3 = camera.project_ray_origin(point)
	var ray_dir : Vector3 = camera.project_ray_normal(point)
	
	ray_from = node3d.global_transform.affine_inverse() * ray_from
	ray_dir = node3d.global_transform.affine_inverse().basis * ray_dir
	
	var plane = Plane(camera.get_camera_transform().basis[2],node3d.points[0][id])
	var p = Geometry3D.segment_intersects_convex(ray_from,ray_from+ray_dir*16384,[plane])
	
	if p.is_empty():
		return
	
	p = p[0]
	
	var d = p.distance_to(node3d.global_position)
	
	node3d.points[0][id] = p
	
	_redraw(gizmo)

func _commit_handle(gizmo,id,secondary,restore,cancel):
	var node3d : Node3D = gizmo.get_node_3d()
	
	match id:
		0:
			#print("commit")
			pass

func _redraw(gizmo):
	gizmo.clear()
	
	var node3d : Node3D = gizmo.get_node_3d()
	#var mesh : Mesh = node3d.mesh
	
	#print(mesh)
	
	#print("redraw")
	
	var lines = PackedVector3Array()

	lines.push_back(Vector3(1, 1, -1))
	lines.push_back(Vector3(0, 0, 0))
	
	var handles := PackedVector3Array()
	
	for i in range(0,node3d.points.size()):
		var point_array = node3d.points[i]
		
		for j in range(0,point_array.size()):
			handles.push_back( point_array[j] )
			#print(arrays[Mesh.ARRAY_VERTEX][j])
	
	#gizmo.add_lines(lines, get_material("main", gizmo), false)
	
	var billboard := false
	gizmo.add_handles(handles, get_material("handles", gizmo), [], billboard)
