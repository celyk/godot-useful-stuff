@tool
extends EditorNode3DGizmoPlugin

func _init():
	create_material("main", Color.hex(0xff5555ff), false, true)
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
	
	return node3d.point_arrays[0][id]
	
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
	
	var plane = Plane(camera.get_camera_transform().basis[2],node3d.point_arrays[0][id])
	var p = Geometry3D.segment_intersects_convex(ray_from,ray_from+ray_dir*16384,[plane])
	
	if p.is_empty():
		return
	
	p = p[0]
	
	var d = p.distance_to(node3d.global_position)
	
	node3d.point_arrays[0][id] = p
	node3d.point_arrays = node3d.point_arrays # Force setter call
	
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

	var handles := PackedVector3Array()
	
	for i in range(0,node3d.point_arrays.size()):
		var point_array = node3d.point_arrays[i]
		
		for j in range(0,point_array.size()):
			handles.push_back( point_array[j] )
			#print(arrays[Mesh.ARRAY_VERTEX][j])
	
	gizmo.add_handles(handles, get_material("handles", gizmo), [], false)
	
	var lines = PackedVector3Array()
	
	var mdt := MeshDataTool.new()
	
	for surface_id in range(0,(node3d.mesh as Mesh).get_surface_count()):
		mdt.create_from_surface(node3d.mesh, surface_id)
		for face_id in range(0,mdt.get_face_count()):
			for j in range(0,3):
				lines.push_back( mdt.get_vertex(mdt.get_face_vertex(face_id,j)) )
				lines.push_back( mdt.get_vertex(mdt.get_face_vertex(face_id,(j+1)%3 )) )
	
	gizmo.add_lines(lines, get_material("main", gizmo), false)
	
