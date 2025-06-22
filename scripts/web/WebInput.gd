class_name WebInput 
extends Node

## A singleton for accessing device sensor APIs from the web
## [br][color=purple]Made by celyk[/color]
## @tutorial(celyk's repo): https://github.com/celyk/godot-useful-stuff


# TODO
# - Test different browsers

## Requests and initializes the sensors. Required by iOS to prompt user for permission to access sensors
static func request_sensors() -> void:
	if !OS.has_feature("web"): return
	
	if _init_sensors() != OK:
		return
	
	_is_initialized = true

static func get_rotation() -> Vector3:
	if not _is_initialized: return Vector3()
		
	var v := _get_js_vector("rotation")
	
	# deg_to_rad()
	v *= TAU / 360.0
	
	return v

static func get_accelerometer() -> Vector3:
	if not _is_initialized: return Input.get_accelerometer()
	return _browser_to_godot_coordinates(_get_js_vector("acceleration"))

static func get_gravity() -> Vector3:
	if not _is_initialized: return Input.get_gravity()
	return _browser_to_godot_coordinates(_get_js_vector("gravity"))

static func get_gyroscope() -> Vector3:
	if not _is_initialized: return Input.get_gyroscope()
	
	var v := _get_js_vector("gyroscope")
	
	# deg_to_rad()
	v *= TAU / 360.0
	
	# Reorient the vector to support all the browsers...
	v = _browser_to_godot_coordinates(v)
	
	return v

static func _browser_to_godot_coordinates(v : Vector3) -> Vector3:
	#if OS.has_feature("web_ios") || true:
	#	v = Vector3(-v.x, v.z, v.y)
	
	var orientation := _screen_get_orientation()
	v = _reorient_sensor_vector(v, orientation)
	
	return v

static func _reorient_sensor_vector(v : Vector3, i : DisplayServer.ScreenOrientation = 0) -> Vector3:
	match i:
		DisplayServer.SCREEN_LANDSCAPE:
			v = Vector3(-v.y, v.x, v.z)
		DisplayServer.SCREEN_PORTRAIT:
			v = Vector3(v.x, v.y, v.z) # Portrait is the default orientation, even on iPad
		DisplayServer.SCREEN_REVERSE_LANDSCAPE:
			v = Vector3(v.y, -v.x, v.z)
		DisplayServer.SCREEN_REVERSE_PORTRAIT:
			v = Vector3(-v.x, -v.y, v.z)
	
	return v

static var _cached_orientation := ""
static func _screen_get_orientation() -> DisplayServer.ScreenOrientation:
	if not _is_initialized: return DisplayServer.screen_get_orientation()
	
	match _cached_orientation:
		"portrait-primary":
			return DisplayServer.SCREEN_PORTRAIT
		"portrait-secondary":
			return DisplayServer.SCREEN_REVERSE_PORTRAIT
		"landscape-primary":
			return DisplayServer.SCREEN_LANDSCAPE
		"landscape-secondary":
			return DisplayServer.SCREEN_REVERSE_LANDSCAPE
	
	return DisplayServer.SCREEN_PORTRAIT 

static var _cached_js_objects := {}
static func _get_js_vector(name:String) -> Vector3:
	if _cached_js_objects.get(name) == null:
		_cached_js_objects[name] = JavaScriptBridge.get_interface(name)
	
	var js_object : JavaScriptObject = _cached_js_objects[name]
	return Vector3(js_object.x, js_object.y, js_object.z)

static var _is_initialized := false
static var _js_callback : JavaScriptObject
static func _init_sensors() -> Error:
	if !OS.has_feature("web"): return ERR_UNAVAILABLE
	
	print("Initializing sensors")
	JavaScriptBridge.eval(_js_code, true)
	
	_cached_orientation = JavaScriptBridge.eval("screen_orientation", true)
	
	var js_screen : JavaScriptObject = JavaScriptBridge.get_interface("screen")
	
	_js_callback = JavaScriptBridge.create_callback(_on_orientation_changed)
	js_screen.orientation.onchange = _js_callback
	
	return OK

static func _on_orientation_changed(args:Array):
	_cached_orientation = args[0].target.type

const _js_code := '''
var rotation = { x: 0, y: 0, z: 0 };
var acceleration = { x: 0, y: 0, z: 0 };
var gravity = { x: 0, y: 0, z: 0 };
var gyroscope = { x: 0, y: 0, z: 0 };
var screen_orientation = ""

// Not supported by the web
//var magnetometer = { x: 0, y: 0, z: 0 };


function registerMotionListener() {
	window.ondevicemotion = function(event) {
		if (event.acceleration.x === null) return;
		
		acceleration.x = event.accelerationIncludingGravity.x;
		acceleration.y = event.accelerationIncludingGravity.y;
		acceleration.z = event.accelerationIncludingGravity.z;
		
		gravity.x = event.accelerationIncludingGravity.x;
		gravity.y = event.accelerationIncludingGravity.y;
		gravity.z = event.accelerationIncludingGravity.z;
		
		gyroscope.x = event.rotationRate.alpha;
		gyroscope.y = event.rotationRate.beta;
		gyroscope.z = event.rotationRate.gamma;
	}
	
	window.ondeviceorientation = function(event) {
		rotation.x = event.beta;
		rotation.y = event.gamma;
		rotation.z = event.alpha;
	}
}

// Request permission for iOS 13+ devices
console.log("Requesting sensors");
  function onClick() {
	screen_orientation = screen.orientation.type;
	
	// feature detect
	if (typeof DeviceMotionEvent.requestPermission === 'function') {
	  DeviceMotionEvent.requestPermission()
		.then(permissionState => {
		  if (permissionState === 'granted') {
			//window.addEventListener('devicemotion', () => {});
			registerMotionListener();
		  }
		})
		.catch(console.error);
	} else {
		// handle regular non iOS 13+ devices
		registerMotionListener();
	}
  }

onClick();
//window.addEventListener("click", onClick);
'''
