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
##
## @tutorial(celyk's repo): https://github.com/celyk/godot-useful-stuff

# TODO
# - Add record/stop buttons to mimick tape recorder interface
# - Is there any way to detect the mic in real time?
# - Is there any way to bypass the SceneTree?
# - Is there any way to bypass the audio bus?
# - Microphone should never ever go to Master
# - Make the system more resilient
# - Normalize audio clip? Could delegate to another AudioStream

# Some buttons for the inspector
@export_tool_button("Record", "DebugSkipBreakpointsOff") var record_button := func(): recording = true
@export_tool_button("Stop", "EditorPathSmoothHandle") var stop_button := func(): recording = false

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

## Time in seconds subtracted from the start of the recording. Use negative values for padding around the volume peak
@export var crop_begin := -0.1
## Time in seconds subtracted from the end of the recording. Useful for avoiding unwanted sound
@export var crop_end := 0.1

func _validate_property(property: Dictionary):
	# Prevent var recording from being saved true by PROPERTY_USAGE_STORAGE
	if property.name == "recording":
		property.usage = PROPERTY_USAGE_EDITOR
	
	# Hide some inhertited properties that clutter the UI
	var hide_me := false
	var disable_me := false
	match property.name:
		#"loop_mode": hide_me = true
		#"loop_begin": hide_me = true
		#"loop_end": hide_me = true
		"format": disable_me = true
		"mix_rate": disable_me = true
		"stereo": disable_me = true
	
	if hide_me:
		# Block the PROPERTY_USAGE_EDITOR bitflag
		property.usage &= ~PROPERTY_USAGE_EDITOR
	
	if disable_me:
		property.usage |= PROPERTY_USAGE_READ_ONLY


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
	
	if _initialize_meter() != OK:
		push_error("RecordWAV: ", "Failed to initialize volume meter")
		_cleanup_microphone()
		return
	
	
	_effect_record.set_recording_active(true)

## Stop the recording
func stop_record():
	_effect_record.set_recording_active(false)
	
	var wav_recording := _effect_record.get_recording()
	
	# Avoid cropping if there's too much data
	if crop_begin != 0.0 or crop_end != 0.0:
		var start_t : float = 0.0 + crop_begin
		var end_t : float = wav_recording.get_length() - crop_end
		
		if crop_to_peak:
			start_t += get_peak_t()
		
		# Prevent negative crop start time. Unsure why it's needed
		start_t = max(start_t, 0.0)
		
		_crop_wav(wav_recording, start_t, end_t)
	
	data = wav_recording.data
	format = wav_recording.format
	mix_rate = wav_recording.mix_rate
	stereo = wav_recording.stereo
	
	# Prevent the microphone from hurting our ears
	_cleanup_microphone()
	
	emit_changed()

## Get the time when the volume peaked
func get_peak_t() -> float:
	return (_max_volume_t_msec - _start_t_msec) / 1000.0


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

# FFT for tracking peaks in volume
var _spectrum_analyzer_instance : AudioEffectSpectrumAnalyzerInstance
var _start_t_msec : int = 0
func _initialize_meter() -> Error:
	var bus_idx := AudioServer.get_bus_index("Record")
	if bus_idx == -1:
		return ERR_UNCONFIGURED
	
	# Reset these before recording
	_start_t_msec = Time.get_ticks_msec()
	_max_volume_t_msec = Time.get_ticks_msec()
	_max_volume = Vector2(0,0)
	
	# Start processing the FFT
	var tree := Engine.get_main_loop() as SceneTree
	tree.process_frame.connect(_record_process)
	
	# Check to see if the effect already exists
	var effects := _get_audio_effects(bus_idx, ["AudioEffectSpectrumAnalyzer"])
	
	if not effects.is_empty():
		var effect : AudioEffectSpectrumAnalyzer = effects.back()
		
		# Search for the effect to get it's index
		var effect_idx : int = _get_audio_effects(bus_idx).rfind(effect)
		
		_spectrum_analyzer_instance = AudioServer.get_bus_effect_instance(bus_idx, effect_idx)
	else:
		# No effect found. Initialize it
		var _spectrum_analyzer = AudioEffectSpectrumAnalyzer.new()
		AudioServer.add_bus_effect(bus_idx, _spectrum_analyzer)
		
		_spectrum_analyzer_instance = AudioServer.get_bus_effect_instance(bus_idx, AudioServer.get_bus_effect_count(bus_idx)-1)
		
		# Refresh the bus layout
		AudioServer.bus_layout_changed.emit()
	
	return OK

var _max_volume : Vector2
var _max_volume_t_msec := 0
func _record_process():
	# Disconnect this function if recording is over
	if _effect_record and (not _effect_record.is_recording_active()):
		var tree := Engine.get_main_loop() as SceneTree
		tree.process_frame.disconnect(_record_process)
		return
	
	var volume := _spectrum_analyzer_instance.get_magnitude_for_frequency_range(0.0, 20000, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
	#print(volume, _max_volume)
	
	var average := (volume.x + volume.y) / 2.0
	if average > _max_volume.x:
		_max_volume.x = average
		_max_volume_t_msec = Time.get_ticks_msec()

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

# Get's audio bus effect objects with an optional type filter
func _get_audio_effects(bus_idx:int, filter:=[]) -> Array[AudioEffect]:
	var effects : Array[AudioEffect]
	
	for i in range(0, AudioServer.get_bus_effect_count(bus_idx)):
		var effect : AudioEffect = AudioServer.get_bus_effect(bus_idx, i)
		effects.append(effect)
	
	if filter.is_empty():
		return effects
	
	var filtered_effects : Array[AudioEffect]
	for effect in effects:
		if effect.get_class() in filter:
			filtered_effects.append(effect)
	
	return filtered_effects
