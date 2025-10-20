@tool
class_name FFTTexture extends ImageTexture

@export var fft_size := 2048
@export var sample_rate := 44100
@export var mix_rate := 44100

func _init() -> void:
	AudioServer.bus_layout_changed.connect(_validate_audio_state)
	start_record.call_deferred()

## Start the recording
func start_record():
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

## Stop the recording
func stop_record():
	# Prevent the microphone from hurting our ears
	_cleanup_microphone()
	
	emit_changed()

# PRIVATE

func _initialize_bus() -> Error:
	var bus_idx := AudioServer.get_bus_index("Record")
	if bus_idx != -1:
		return OK
	
	AudioServer.add_bus()
	
	bus_idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_idx, "Record")
	AudioServer.set_bus_mute(bus_idx, true)
	
	#AudioServer.add_bus_effect(bus_idx, AudioEffectCapture.new())
	#AudioServer.add_bus_effect(bus_idx, _effect_record)
	
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
		effect.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048

		# Search for the effect to get it's index
		var effect_idx : int = _get_audio_effects(bus_idx).rfind(effect)
		
		_spectrum_analyzer_instance = AudioServer.get_bus_effect_instance(bus_idx, effect_idx)
	else:
		# No effect found. Initialize it
		var _spectrum_analyzer = AudioEffectSpectrumAnalyzer.new()
		_spectrum_analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048

		AudioServer.add_bus_effect(bus_idx, _spectrum_analyzer)
		
		_spectrum_analyzer_instance = AudioServer.get_bus_effect_instance(bus_idx, AudioServer.get_bus_effect_count(bus_idx)-1)
		
		# Refresh the bus layout
		AudioServer.bus_layout_changed.emit()
	
	return OK

var _max_volume : Vector2
var _max_volume_t_msec := 0
var _fft : Array[Vector2]
func _record_process():
	var volume := _spectrum_analyzer_instance.get_magnitude_for_frequency_range(0.0, 20000, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
	#print(volume, _max_volume)
	
	_fft.resize(fft_size / 2)
	
	var bin_size := sample_rate / _fft.size()
	
	for i in range(0, _fft.size()-1):
		_fft[i] = _spectrum_analyzer_instance.get_magnitude_for_frequency_range(bin_size * i, bin_size * (i+1), AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)# / float(_fft.size())
	
	var average := (volume.x + volume.y) / 2.0
	if average > _max_volume.x:
		_max_volume.x = average
		_max_volume_t_msec = Time.get_ticks_msec()
	
	var img := Image.create_empty(fft_size, 2, false, Image.FORMAT_RGBAF)
	for i in range(0, _fft.size()-1):
		var magnitude := max(_fft[i].x, _fft[i].y)
		
		var v := Vector4(magnitude, 0, 0, 1)
		var col := Color(v.x, v.y, v.z, v.w)
		#col = Color.AQUA
		img.set_pixel(i, 0, col)
		img.set_pixel(i, 1, col)
	
	#print(_fft)
	
	set_image(img)

func _validate_audio_state():
	var bus_idx := AudioServer.get_bus_index("Record")

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
