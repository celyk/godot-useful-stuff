class_name WorldGrab extends RefCounted

## The WorldGrab utility makes it easy to add world-grab navigation to your XR project!
## [br][color=purple]Made by celyk[/color]
##
## Right now, WorldGrab is designed for a single use case: art viewing.
## [br]It allows one to grab the world with both hands and move it around, viewing it from all angles; It is not restricted by any up direction.
## [br]
## [br]Example usage:
## [codeblock]
## wg = WorldGrab.new()
##	soon()
## [/codeblock]
## @tutorial(celyk's repo): https://github.com/celyk/godot-useful-stuff
## @tutorial(xr-grid): https://github.com/V-Sekai/V-Sekai.xr-grid

## The transform that takes one to the other. Intended for a one handed grab.
func get_grab_transform(from : Transform3D, to : Transform3D) -> Transform3D:
	return from.affine_inverse() * to

## For orbitting around a central point, without scale, like spinning a globe.
func get_orbit_transform(from_pivot : Vector3, from_b : Vector3, to_pivot : Vector3, to_b : Vector3) -> Transform3D:
	# Center the pivot
	from_b -= from_pivot
	to_b -= to_pivot
	
	# Gather information on the shortest rotation
	var axis : Vector3 = from_b.cross(to_b)
	var angle : float = from_b.angle_to(to_b)

	# Construct the transformation that orbits about the pivot, with no scale!
	return Transform3D(Basis(axis, angle), to_pivot)

## This is a transformation which takes line (from_a,from_b) to line (to_a,to_b). It is analagous to pinch gesture on a touch screen.
func get_pinch_transform(from_a : Vector3, from_b : Vector3, to_a : Vector3, to_b : Vector3) -> Transform3D:
	var delta_scale : float = sqrt(to_b.dot(to_b) / from_b.dot(from_b))
	
	# Orbit around pivot point a, and scale so that b is fixed in place.
	# According to symmetry, it is the same as if a and b are swapped.
	return get_orbit_transform(from_a, from_b, to_a, to_b) * Transform3D(Basis.from_scale(Vector3(1,1,1) * delta_scale))

## Separable blending of position, rotation and scale. Fine tune smoothing for maximum comfort.
## [br]
## [br]Weights of 0 are optimized to avoid unnecessary compute.
func split_blend(
		from : Transform3D,
		to : Transform3D, 
		pos_weight : float = 0.0, 
		rot_weight : float = 0.0, 
		scale_weight : float = 0.0) -> Transform3D:
	
	# Interpolate position
	if pos_weight != 0.0:
		from.origin = from.origin.lerp(to.origin, pos_weight)
	
	# Interpolate rotation
	var from_rot : Quaternion = from.basis.get_rotation_quaternion()
	from.basis = Basis(from_rot)
	if rot_weight != 0.0:
		var to_rot : Quaternion = to.basis.get_rotation_quaternion()
		from.basis = Basis(from_rot.slerp(to_rot, rot_weight))
	
	# Interpolate scale
	if scale_weight != 0.0:
		var from_scale : Vector3 = from.basis.get_scale()
		var to_scale : Vector3 = to.basis.get_scale()
		from.basis *= Basis.from_scale(from_scale.lerp(to_scale, scale_weight))
	
	return from
