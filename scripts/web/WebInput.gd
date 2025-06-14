class_name WebInput 
extends Node

## A singleton for accessing device sensor APIs from the web
## [br][color=purple]Made by celyk[/color]
## @tutorial(celyk's repo): https://github.com/celyk/godot-useful-stuff


# TODO
# - Handle orientations
# - Test different browsers
# - Expose orientation


static func request_sensors() -> void:
	_init_sensors()

static func get_accelerometer() -> Vector3:
	if !OS.has_feature("web"): return Input.get_accelerometer()
	return _browser_to_godot_coordinates(_get_js_vector("acceleration"))

static func get_gravity() -> Vector3:
	if !OS.has_feature("web"): return Input.get_gravity()
	return _browser_to_godot_coordinates(_get_js_vector("gravity"))

static func get_gyroscope() -> Vector3:
	if !OS.has_feature("web"): return Input.get_gyroscope()
	var v := _get_js_vector("gyroscope")
	
	# deg_to_rad()
	v *= TAU / 360.0
	
	# Reorient the vector to support all the browsers...
	v = _browser_to_godot_coordinates(v)
	
	return v
#
#static func get_magnetometer() -> Vector3:
	#if !OS.has_feature("web"): return Input.get_magnetometer()
	#return _browser_to_godot_coordinates(_get_js_vector("magnetometer"))

static func _browser_to_godot_coordinates(v : Vector3) -> Vector3:
	if OS.has_feature("web_ios"):
		v = Vector3(-v.x, v.z, v.y)
	
	var orientation := _screen_get_orientation()
	v = _reorient_sensor_vector(v, orientation)
	
	return v

static func _reorient_sensor_vector(v : Vector3, i : DisplayServer.ScreenOrientation = 0) -> Vector3:
	match i:
		DisplayServer.SCREEN_LANDSCAPE:
			v = Vector3(v.x, v.y, v.z)
		DisplayServer.SCREEN_PORTRAIT:
			v = Vector3(-v.z, v.y, v.x)
		DisplayServer.SCREEN_REVERSE_LANDSCAPE:
			v = Vector3(-v.x, v.y, -v.z)
		DisplayServer.SCREEN_SENSOR_PORTRAIT:
			v = Vector3(v.z, v.y, -v.x)
	
	return v

static func _screen_get_orientation() -> DisplayServer.ScreenOrientation:
	var type : String = JavaScriptBridge.eval("screen_orientation", true);
	
	match type:
		"portrait-primary":
			return DisplayServer.SCREEN_PORTRAIT
		"portrait-secondary":
			return DisplayServer.SCREEN_REVERSE_PORTRAIT
		"landscape-primary":
			return DisplayServer.SCREEN_LANDSCAPE
		"landscape-secondary":
			return DisplayServer.SCREEN_REVERSE_LANDSCAPE
	
	return DisplayServer.SCREEN_LANDSCAPE 

static func _get_js_vector(name:String) -> Vector3:
	var x : float = JavaScriptBridge.eval(name+".x", true);
	var y : float = JavaScriptBridge.eval(name+".y", true);
	var z : float = JavaScriptBridge.eval(name+".z", true);
	
	return Vector3(x, y, z);

static func _init_sensors():
	print("Initializing sensors")
	JavaScriptBridge.eval(_js_code, true)


const _js_code := '''
var acceleration = { x: 0, y: 0, z: 0 };
var rotation = { x: 0, y: 0, z: 0 };
var gravity = { x: 0, y: 0, z: 0 };
var gyroscope = { x: 0, y: 0, z: 0 };
//var magnetometer = { x: 0, y: 0, z: 0 };
var screen_orientation = ""

function registerMotionListener() {
	window.ondevicemotion = function(event) {
		if (event.acceleration.x === null) return;
		
		acceleration.x = event.accelerationIncludingGravity.x;
		acceleration.y = event.accelerationIncludingGravity.y;
		acceleration.z = event.accelerationIncludingGravity.z;
		
		gravity.x = event.accelerationIncludingGravity.x;
		gravity.y = event.accelerationIncludingGravity.y;
		gravity.z = event.accelerationIncludingGravity.z;
		
		gyroscope.x = event.rotationRate.beta;
		gyroscope.y = event.rotationRate.gamma;
		gyroscope.z = event.rotationRate.alpha;
	}
	
	window.ondeviceorientation = function(event) {
		rotation.x = event.beta;
		rotation.y = event.gamma;
		rotation.z = event.alpha;
	}
	
	screen.orientation.onchange = function(event) {
		screen_orientation = event.target.type;
	}
}

// Request permission for iOS 13+ devices
console.log("Requesting sensors");
  function onClick() {
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
