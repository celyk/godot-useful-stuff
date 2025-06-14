class_name WebInput extends Node

## A singleton for accessing device sensor APIs from the web
## [br][color=purple]Made by celyk[/color]
## @tutorial(celyk's repo): https://github.com/celyk/godot-useful-stuff


# TODO 
# - Handle orientations
# - Test different browsers
# - Expose orientation

func _ready() -> void:
	_init_sensors()
	$Button.pressed.connect(_init_sensors)

func _init_sensors():
	print("Initializing sensors")
	JavaScriptBridge.eval(_js_code, true)

@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D

func _process(delta: float) -> void:
	var accel := get_accelerometer()
	var gyro := get_gyroscope()
	$Label.text = str(accel) + "\n"
	$Label.text = str(gyro) + "\n"
	
	if gyro.length() > 0.0:
		mesh_instance_3d.rotate(gyro.normalized(), gyro.length() * delta)

func get_gyroscope() -> Vector3:
	if !OS.has_feature('web'): return Input.get_gyroscope()
	var v = get_js_vector("gyro")
	
	v *= TAU / 360.0
	
	match OS.get_name():
		"iOS":
			pass
		_:
			v = Vector3(-v.x, v.z, v.y)
	
	return v

func get_accelerometer() -> Vector3:
	if !OS.has_feature('web'): return Input.get_accelerometer()
	return get_js_vector("acceleration")

func get_js_vector(name:String) -> Vector3:
	var x : float = JavaScriptBridge.eval(name+".x", true);
	var y : float = JavaScriptBridge.eval(name+".y", true);
	var z : float = JavaScriptBridge.eval(name+".z", true);
	
	return Vector3(x, y, z);

const _js_code := '''
var acceleration = { x: 0, y: 0, z: 0 };
var gyro = { x: 0, y: 0, z: 0 };

function registerMotionListener() {
	window.ondevicemotion = function(event) {
		if (event.acceleration.x === null) return;
		acceleration.x = event.acceleration.x;
		acceleration.y = event.acceleration.y;
		acceleration.z = event.acceleration.z;
		
		gyro.x = event.rotationRate.beta;
		gyro.y = event.rotationRate.gamma;
		gyro.z = event.rotationRate.alpha;
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
