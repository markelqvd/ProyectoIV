extends WorldEnvironment
## Tormenta: relámpagos que iluminan la escena, sonido de lluvia y truenos.
## El sonido se genera por código (ruido filtrado), no hacen falta archivos de audio.

## Luz direccional que hará de relámpago (el "sol" nublado de la escena).
@export var sky_light: DirectionalLight3D
## Segundos mínimos y máximos entre relámpagos.
@export var min_interval: float = 7.0
@export var max_interval: float = 20.0
## Intensidad del destello.
@export var flash_energy: float = 4.0
## Volumen de la lluvia (dB).
@export var rain_volume_db: float = -14.0
## Activar el sonido generado.
@export var enable_audio: bool = true

const MIX_RATE: float = 22050.0

var _base_light: float = 0.0
var _base_sky: float = 1.0
var _timer: float = 0.0

var _audio: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _lp: float = 0.0
var _lp2: float = 0.0
var _drop: float = 0.0
var _brown: float = 0.0
var _thunder: float = 0.0
var _thunder_len: float = 3.0


func _ready() -> void:
	if sky_light:
		_base_light = sky_light.light_energy
	if environment:
		_base_sky = environment.background_energy_multiplier
	_timer = randf_range(3.0, 6.0)

	if enable_audio:
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = MIX_RATE
		gen.buffer_length = 0.2
		_audio = AudioStreamPlayer.new()
		_audio.stream = gen
		_audio.volume_db = rain_volume_db
		add_child(_audio)
		_audio.play()
		_playback = _audio.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(min_interval, max_interval)
		_lightning()
	if _playback:
		_fill_audio()


func _lightning() -> void:
	var t := create_tween()
	# Dos o tres destellos rápidos, como un relámpago real.
	for i in randi_range(2, 3):
		var e: float = flash_energy * randf_range(0.5, 1.0)
		t.tween_callback(_set_flash.bind(e))
		t.tween_interval(randf_range(0.04, 0.09))
		t.tween_callback(_set_flash.bind(e * 0.2))
		t.tween_interval(randf_range(0.05, 0.15))
	t.tween_callback(_set_flash.bind(0.0))
	# El trueno llega un poco después.
	t.tween_interval(randf_range(0.4, 2.0))
	t.tween_callback(_start_thunder)


func _set_flash(extra: float) -> void:
	if sky_light:
		sky_light.light_energy = _base_light + extra
	if environment:
		environment.background_energy_multiplier = _base_sky + extra * 0.6


func _start_thunder() -> void:
	_thunder = 1.0
	_thunder_len = randf_range(2.0, 4.0)


func _fill_audio() -> void:
	var frames: int = _playback.get_frames_available()
	for i in frames:
		# Lluvia: ruido blanco filtrado dos veces (sonido "siseante" suave).
		var white: float = randf() * 2.0 - 1.0
		_lp = lerpf(_lp, white, 0.35)
		_lp2 = lerpf(_lp2, _lp, 0.5)
		var s: float = _lp2 * 0.5
		# Gotas sueltas golpeando el cristal.
		if randf() < 0.0012:
			_drop = randf_range(0.3, 1.0)
		_drop *= 0.92
		s += white * _drop * 0.25
		# Trueno: ruido marrón con envolvente que se apaga.
		if _thunder > 0.0:
			_brown = clampf(_brown + white * 0.03, -1.0, 1.0) * 0.999
			s += _brown * _thunder * 1.2
			_thunder -= 1.0 / (MIX_RATE * _thunder_len)
		_playback.push_frame(Vector2(s, s))
