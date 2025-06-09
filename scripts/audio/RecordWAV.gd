@tool
class_name RecordWAV extends AudioStreamWAV

## A resource that allows recording from the primary microphone

#@export_tool_button("Pulse") var pulse : _
@export var recording := false :
	set(value):
		if value == recording: return
		
		recording = value
		
		if recording:
			start_record()
		else:
			stop_record()

func start_record():
	format = AudioStreamWAV.FORMAT_16_BITS
	#mix_rate = 48000
	stereo = false
	
	if _initialize_bus() != OK:
		printerr("Failed to initialize bus")
		return
	
	if _initialize_microphone() != OK:
		printerr("Failed to initialize microphone")
		return
	
	_effect_record.set_recording_active(true)

func stop_record():
	_effect_record.set_recording_active(false)
	
	var test = preload("res://confirmation_004.wav")
	test = _effect_record.get_recording()
	
	data = test.data
	format = test.format
	stereo = test.stereo
	
	emit_changed()

var _effect_record := AudioEffectRecord.new()
func _initialize_bus() -> Error:
	var bus_idx := AudioServer.get_bus_index("Record")
	if bus_idx != -1:
		_effect_record = AudioServer.get_bus_effect(bus_idx, 0)
		return OK
	
	AudioServer.add_bus()
	
	bus_idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_idx, "Record")
	AudioServer.set_bus_mute(bus_idx, true)
	
	#AudioServer.add_bus_effect(bus_idx, AudioEffectCapture.new())
	AudioServer.add_bus_effect(bus_idx, _effect_record)
	
	# Refresh the bus layout
	AudioServer.bus_layout_changed.emit()
	
	return OK

var _microphone_stream_player : AudioStreamPlayer
func _initialize_microphone() -> Error:
	if _microphone_stream_player and _microphone_stream_player.is_inside_tree(): 
		return OK
	
	_microphone_stream_player = AudioStreamPlayer.new()
	_microphone_stream_player.stream = AudioStreamMicrophone.new()
	_microphone_stream_player.bus = "Record"
	
	var tree := Engine.get_main_loop() as SceneTree
	
	tree.root.add_child(_microphone_stream_player)
	
	# Playback must start inside tree
	_microphone_stream_player.playing = true
	
	return OK
