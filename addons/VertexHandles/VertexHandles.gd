@tool
class_name VertexHandles extends Node3D

@onready var mesh = get_parent().mesh

# Array of points arrays
@export var points := [] : set = _set_points

# TODO
# - Render wireframe
# - Add options
# - Refresh mesh in _set_points
# - Support multiple surfaces
# - Make sure things are commiting and can unddo/redo 
# - Fix handle rendering bug

func _ready() -> void:
	assert(get_parent() is MeshInstance3D)
	
	get_parent().mesh = _to_array_mesh(get_parent().mesh)
	mesh = get_parent().mesh
	
	points = []
	
	for i in range(0,mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(i)
		
		points.push_back(arrays[Mesh.ARRAY_VERTEX])
		
		#print(arrays[Mesh.ARRAY_VERTEX].size())
		#for j in range(0,arrays[Mesh.ARRAY_VERTEX].size()):
			#points.push_back( arrays[Mesh.ARRAY_VERTEX][j] )

func _process(delta: float) -> void:
	_update_mesh()
	#var type : Mesh.PrimitiveType = _get_primitive_type(mesh)

func _update_mesh():
	if is_node_ready() and not points.is_empty():
		mesh = get_parent().mesh
		
		var surface_arrays := []
		for i in range(0,mesh.get_surface_count()):
			var arrays = mesh.surface_get_arrays(i)
			surface_arrays.push_back(arrays)
		
		var type : Mesh.PrimitiveType = _get_primitive_type(mesh)
		
		mesh.clear_surfaces()
		
		for i in range(0,surface_arrays.size()):
			#for j in range(0,surface_arrays[Mesh.ARRAY_VERTEX].size()):
			
			surface_arrays[i][Mesh.ARRAY_VERTEX] = PackedVector3Array( points[i] )
			
			mesh.add_surface_from_arrays(type, surface_arrays[i])

func _set_points(value):
	#print(value)
	points = value
	print("settingsetting")


func _to_array_mesh(_mesh:Mesh) -> ArrayMesh:
	var surface_arrays := []
	for i in range(0,_mesh.get_surface_count()):
		var arrays = _mesh.surface_get_arrays(i)
		surface_arrays.push_back(arrays)
	
	var type : Mesh.PrimitiveType = _get_primitive_type(_mesh)
	#print("type: ", str(type) )
	
	_mesh = ArrayMesh.new()
	
	for i in range(0,surface_arrays.size()):
		_mesh.add_surface_from_arrays(type, surface_arrays[i])
	
	return _mesh

func _get_primitive_type(_mesh:Mesh, id:=0) -> Mesh.PrimitiveType:
	return RenderingServer.mesh_get_surface(_mesh.get_rid(), 0)["primitive"]
