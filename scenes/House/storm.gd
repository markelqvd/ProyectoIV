extends WorldEnvironment

const MIX_RATE: float = 22050.0

@export var sky_light: NodePath
@export var min_interval: float = 7.0
@export var max_interval: float = 20.0
@export var flash_energy: float = 4.0
@export var rain_volume_db: float = -14.0
@export var enable_audio: bool = true

var _sky: DirectionalLight3D
var _base_light: float = 0.0
var _base_sky: float = 1.0
var _timer: float = 0.0
var _playback: AudioStreamGeneratorPlayback
var _low: float = 0.0
var _low2: float = 0.0
var _drop: float = 0.0
var _brown: float = 0.0
var _thunder: float = 0.0
var _thunder_length: float = 3.0


func _ready() -> void:
	_sky = get_node_or_null(sky_light) as DirectionalLight3D
	if _sky:
		_base_light = _sky.light_energy
	if environment:
		_base_sky = environment.background_energy_multiplier
	_timer = randf_range(3.0, 6.0)
	if enable_audio:
		_start_audio()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(min_interval, max_interval)
		_lightning()
	if _playback:
		_fill_audio()


func _start_audio() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.2
	var audio := AudioStreamPlayer.new()
	audio.stream = generator
	audio.volume_db = rain_volume_db
	add_child(audio)
	audio.play()
	_playback = audio.get_stream_playback() as AudioStreamGeneratorPlayback


func _lightning() -> void:
	var tween := create_tween()
	for i in randi_range(2, 3):
		var energy: float = flash_energy * randf_range(0.5, 1.0)
		tween.tween_callback(_set_flash.bind(energy))
		tween.tween_interval(randf_range(0.04, 0.09))
		tween.tween_callback(_set_flash.bind(energy * 0.2))
		tween.tween_interval(randf_range(0.05, 0.15))
	tween.tween_callback(_set_flash.bind(0.0))
	tween.tween_interval(randf_range(0.4, 2.0))
	tween.tween_callback(_start_thunder)


func _set_flash(extra: float) -> void:
	if _sky:
		_sky.light_energy = _base_light + extra
	if environment:
		environment.background_energy_multiplier = _base_sky + extra * 0.6


func _start_thunder() -> void:
	_thunder = 1.0
	_thunder_length = randf_range(2.0, 4.0)


func _fill_audio() -> void:
	for i in _playback.get_frames_available():
		var white: float = randf() * 2.0 - 1.0
		_low = lerpf(_low, white, 0.35)
		_low2 = lerpf(_low2, _low, 0.5)
		var sample: float = _low2 * 0.5
		if randf() < 0.0012:
			_drop = randf_range(0.3, 1.0)
		_drop *= 0.92
		sample += white * _drop * 0.25
		if _thunder > 0.0:
			_brown = clampf(_brown + white * 0.03, -1.0, 1.0) * 0.999
			sample += _brown * _thunder * 1.2
			_thunder -= 1.0 / (MIX_RATE * _thunder_length)
		_playback.push_frame(Vector2(sample, sample))
