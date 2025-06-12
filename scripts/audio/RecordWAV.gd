@tool
class_name RecordWAV extends AudioStreamWAV

## A Resource that allows recording from the primary microphone.
##
## RecordWAV adds a bus named "Record" to the audio bus layout. You are free to use the Audio tab to add additional effects to the bus!
## [br]
## [br]The following audio settings must be set:
## [br]`audio/driver/enable_input = true`
## [br]`audio/general/ios/session_category = Play and Record`
## [br]
## [br]Code example WIP
## [codeblock]
## var record_wav = RecordWAV.new()
## record_wav.start_record()
## ...
## record_wav.stop_record()
## [/codeblock]

# TODO
# - Add record/stop buttons to mimick tape recorder interface
# - Is there any way to detect the mic in real time?
# - Is there any way to bypass the SceneTree?
# - Is there any way to bypass the audio bus?
# - Microphone should never ever go to Master
# - Make the system more resilient
# - Normalize audio clip? Could delegate to another AudioStream

#@export_tool_button("Pulse") var pulse : _
## Just a variable that controls the recording. Still working on it
@export var recording := false :
	set(value):
		if value == recording: return
		
		recording = value
		
		if recording:
			start_record()
		else:
			stop_record()

## Automatically crops the recording around the peak
@export var crop_to_peak := true

## Controls how much padding is added before the peak of the recording
@export var crop_padding := 0.1

func _init() -> void:
	AudioServer.bus_layout_changed.connect(_validate_audio_state)

## Start the recording
func start_record():
	format = AudioStreamWAV.FORMAT_16_BITS
	#mix_rate = 48000
	stereo = false
	
	if _initialize_bus() != OK:
		push_error("RecordWAV: ", "Failed to initialize bus")
		return
	
	if _initialize_microphone() != OK:
		push_error("RecordWAV: ", "Failed to initialize microphone")
		_cleanup_microphone()
		return
	
	_effect_record.set_recording_active(true)

## Stop the recording
func stop_record():
	_effect_record.set_recording_active(false)
	
	var wav_recording := _effect_record.get_recording()
	
	# Avoid cropping if there's too much data
	if crop_to_peak:
		if wav_recording.get_length() > 3.0:
			push_warning("RecordWAV: ", "Too much data, cropping avoided")
		else:
			var start_t := _find_peak(wav_recording) - crop_padding
			_crop_wav(wav_recording, start_t)
	
	data = wav_recording.data
	format = wav_recording.format
	mix_rate = wav_recording.mix_rate
	stereo = wav_recording.stereo
	
	# Prevent the microphone from hurting our ears
	_cleanup_microphone()
	
	emit_changed()


# PRIVATE

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
	AudioServer.bus_renamed.emit(bus_idx, "New Bus", "Record")
	
	push_warning("RecordWAV: ", "A bus for recording has been added to the audio bus layout")
	
	return OK

static var _microphone_stream_player : AudioStreamPlayer
const _microphone_node_name := "AudioStreamPlayerMicrophone"
func _initialize_microphone() -> Error:
	var tree := Engine.get_main_loop() as SceneTree
	
	# Check to see if the AudioStreamPlayer already exists somewhere
	if _microphone_stream_player == null:
		_microphone_stream_player = tree.root.find_child(_microphone_node_name, false)
	
	# If it exists, we're good to go
	if _microphone_stream_player and _microphone_stream_player.is_inside_tree(): 
		return OK
	
	_microphone_stream_player = AudioStreamPlayer.new()
	_microphone_stream_player.stream = AudioStreamMicrophone.new()
	_microphone_stream_player.bus = "Record"
	_microphone_stream_player.name = _microphone_node_name
	
	tree.root.add_child(_microphone_stream_player)
	
	# Playback must start inside tree
	_microphone_stream_player.playing = true
	
	return OK

func _cleanup_microphone():
	# Another chance to find the node somewhere
	if _microphone_stream_player == null:
		var tree := Engine.get_main_loop() as SceneTree
		_microphone_stream_player = tree.root.find_child(_microphone_node_name, false)
	
	# Free the AudioStreamPlayer
	if _microphone_stream_player and !_microphone_stream_player.is_queued_for_deletion():
		_microphone_stream_player.queue_free()

func _validate_audio_state():
	var bus_idx := AudioServer.get_bus_index("Record")
	if bus_idx == -1:
		if _effect_record and _effect_record.is_recording_active():
			push_error("RecordWAV: ", "Bus was removed during recording. Removing microphone now")
			_cleanup_microphone()

func _crop_wav(wav:AudioStreamWAV, start_t:float, end_t:=-1.0):
	var start_sample_pos : int = start_t * wav.mix_rate
	
	var byte_per_sample := _get_bytes_per_sample(wav)
	
	if end_t < 0.0:
		wav.data = wav.data.slice(start_sample_pos * byte_per_sample, -1)
	else:
		var end_sample_pos : int = end_t * wav.mix_rate
		wav.data = wav.data.slice(start_sample_pos * byte_per_sample, end_sample_pos * byte_per_sample)

func _get_bytes_per_sample(wav:AudioStreamWAV) -> int:
	var bytes_per_sample : int
	match format:
		FORMAT_8_BITS:
			bytes_per_sample = 1
		FORMAT_16_BITS:
			bytes_per_sample = 2
		_:
			bytes_per_sample = 1
	
	if wav.stereo:
		bytes_per_sample *= 2
	
	return bytes_per_sample


# JANK

# Finds the time in seconds of the loudest point in the sound
func _find_peak(wav:AudioStreamWAV) -> float:
	if wav.format > 1: return 0.0
	
	var min_value := 2**16
	var max_value := -2**16
	
	#var difference := 2**31
	
	var sample_pos := 0
	
	var bytes_per_sample : int = _get_bytes_per_sample(wav)
	
	var num_samples := wav.data.size() / bytes_per_sample
	
	
	
	for i in range(0, num_samples):
		var pos := i * bytes_per_sample
		
		var value : int
		
		match format:
			FORMAT_8_BITS:
				value = wav.data.decode_s8(pos)
			FORMAT_16_BITS:
				value = wav.data.decode_s16(pos)
		
		if stereo:
			match format:
				FORMAT_8_BITS:
					value += wav.data.decode_s8(pos+1)
				FORMAT_16_BITS:
					value += wav.data.decode_s16(pos+2)
			
			value /= 2
		
		if value < min_value:
			min_value = value
			sample_pos = i
		
		if value > max_value:
			max_value = value
			sample_pos = i
	
	var max_t := sample_pos * 1.0 / wav.mix_rate
	
	#print("minmax: ", min_value, " ", max_value)
	
	return max_t
