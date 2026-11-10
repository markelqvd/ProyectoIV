extends Node3D
## Sonidos del juego generados por código (no hace falta ningún archivo de audio).
## Uso: get_tree().get_first_node_in_group("sfx").call("play", "click", posicion)

const RATE: int = 22050

## Volumen general de los efectos (dB).
@export var volume_db: float = -6.0

var _cache: Dictionary = {}


func _ready() -> void:
	add_to_group("sfx")


## Reproduce un sonido. Si se da una posición, suena en 3D desde ese punto.
func play(sound: String, pos: Vector3 = Vector3.INF, pitch: float = 1.0, gain_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _stream_for(sound)
	if stream == null:
		return
	if pos == Vector3.INF:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = volume_db + gain_db
		p.pitch_scale = pitch
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
	else:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = stream
		p3.volume_db = volume_db + gain_db
		p3.pitch_scale = pitch
		p3.unit_size = 4.0
		p3.max_distance = 25.0
		add_child(p3)
		p3.global_position = pos
		p3.play()
		p3.finished.connect(p3.queue_free)


func _stream_for(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var samples: PackedFloat32Array
	match sound:
		"doorbell": samples = _doorbell()
		"click": samples = _click(0.9, 2200.0)
		"tick": samples = _click(0.5, 3200.0)
		"clack": samples = _clack()
		"rattle": samples = _rattle()
		"drawer_open": samples = _slide(0.35, true)
		"drawer_close": samples = _slide(0.28, false)
		"door_open": samples = _creak(0.7)
		"door_close": samples = _thump(0.3)
		"curtain": samples = _curtain()
		"pickup": samples = _blip(520.0, 880.0, 0.14)
		"place": samples = _blip(700.0, 420.0, 0.16)
		"paper": samples = _paper()
		"drip": samples = _drip()
		"reveal": samples = _reveal()
		"success": samples = _success()
		"static": samples = _static()
		"step": samples = _step()
		"ending": samples = _ending()
		_:
			return null
	var stream := _to_wav(samples)
	_cache[sound] = stream
	return stream


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


# ---------------------------------------------------------------------------
# Generadores
# ---------------------------------------------------------------------------

func _tone(b: PackedFloat32Array, start: float, freq: float, dur: float, amp: float, decay: float) -> void:
	var s0: int = int(start * RATE)
	for i in int(dur * RATE):
		var idx: int = s0 + i
		if idx >= b.size():
			break
		var t: float = float(i) / RATE
		var env: float = exp(-t * decay) * minf(1.0, t * 400.0)
		var v: float = sin(TAU * freq * t) + 0.35 * sin(TAU * freq * 2.0 * t) + 0.15 * sin(TAU * freq * 3.01 * t)
		b[idx] += v * env * amp


func _doorbell() -> PackedFloat32Array:
	var b := _buf(2.0)
	_tone(b, 0.0, 659.0, 1.2, 0.4, 3.0)    # ding
	_tone(b, 0.55, 523.0, 1.4, 0.4, 2.2)   # dong
	return b


func _click(amp: float, freq: float) -> PackedFloat32Array:
	var b := _buf(0.06)
	for i in b.size():
		var t: float = float(i) / RATE
		b[i] = (sin(TAU * freq * t) * 0.5 + (randf() * 2.0 - 1.0) * 0.5) * exp(-t * 120.0) * amp
	return b


func _clack() -> PackedFloat32Array:
	var b := _buf(0.35)
	for i in b.size():
		var t: float = float(i) / RATE
		var v: float = (randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.6
		var t2: float = t - 0.09
		if t2 > 0.0:
			v += (randf() * 2.0 - 1.0) * exp(-t2 * 70.0) * 0.8 + sin(TAU * 140.0 * t2) * exp(-t2 * 25.0) * 0.6
		b[i] = v
	return b


func _rattle() -> PackedFloat32Array:
	var b := _buf(0.4)
	for k in 3:
		var s0: int = int(k * 0.11 * RATE)
		for i in int(0.06 * RATE):
			var t: float = float(i) / RATE
			if s0 + i < b.size():
				b[s0 + i] += ((randf() * 2.0 - 1.0) * 0.6 + sin(TAU * 1800.0 * t) * 0.3) * exp(-t * 80.0)
	return b


func _slide(dur: float, opening: bool) -> PackedFloat32Array:
	var b := _buf(dur + 0.08)
	var lp: float = 0.0
	for i in b.size():
		var t: float = float(i) / RATE
		var env: float = sin(clampf(t / dur, 0.0, 1.0) * PI)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.12)
		b[i] = lp * env * 0.9
	# golpe al final
	var s0: int = int(dur * RATE * 0.95)
	for i in int(0.08 * RATE):
		var t: float = float(i) / RATE
		if s0 + i < b.size():
			b[s0 + i] += sin(TAU * (110.0 if opening else 90.0) * t) * exp(-t * 40.0) * 0.6
	return b


func _creak(dur: float) -> PackedFloat32Array:
	# Puerta de madera: clic del pestillo, roce suave de aire y un leve crujido grave.
	var b := _buf(dur)
	var lp: float = 0.0
	var lp2: float = 0.0
	var phase: float = 0.0
	for i in b.size():
		var t: float = float(i) / RATE
		var v: float = 0.0
		# pestillo (dos clics cortos)
		if t < 0.03:
			v += (randf() * 2.0 - 1.0) * exp(-t * 220.0) * 0.7
		var t2: float = t - 0.045
		if t2 > 0.0 and t2 < 0.03:
			v += (randf() * 2.0 - 1.0) * exp(-t2 * 260.0) * 0.4
		# aire al moverse la hoja: ruido muy filtrado con subida y bajada suave
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.04)
		lp2 = lerpf(lp2, lp, 0.2)
		var swell: float = sin(clampf((t - 0.05) / (dur - 0.05), 0.0, 1.0) * PI)
		v += lp2 * swell * 1.6
		# crujido de la bisagra: tono grave que sube un poco, muy bajito
		var hinge_env: float = sin(clampf((t - 0.08) / 0.35, 0.0, 1.0) * PI)
		phase += (95.0 + 40.0 * clampf((t - 0.08) / 0.35, 0.0, 1.0)) / RATE
		v += sin(TAU * phase + sin(t * 31.0) * 0.6) * hinge_env * 0.08
		b[i] = v
	return b


func _thump(dur: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var lp: float = 0.0
	for i in b.size():
		var t: float = float(i) / RATE
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.1)
		b[i] = (sin(TAU * 70.0 * t) * 0.9 + lp * 0.6) * exp(-t * 18.0)
	return b


func _curtain() -> PackedFloat32Array:
	var b := _buf(0.55)
	for i in b.size():
		var t: float = float(i) / RATE
		var env: float = sin(clampf(t / 0.55, 0.0, 1.0) * PI)
		var rings: float = sin(TAU * 2600.0 * t) * (0.5 + 0.5 * sin(t * 90.0)) * 0.15
		b[i] = ((randf() * 2.0 - 1.0) * 0.25 + rings) * env
	return b


func _blip(f0: float, f1: float, dur: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var phase: float = 0.0
	for i in b.size():
		var t: float = float(i) / RATE
		phase += lerpf(f0, f1, t / dur) / RATE
		b[i] = sin(TAU * phase) * exp(-t * 18.0) * minf(1.0, t * 300.0) * 0.5
	return b


func _paper() -> PackedFloat32Array:
	var b := _buf(0.45)
	var hp: float = 0.0
	var prev: float = 0.0
	for i in b.size():
		var t: float = float(i) / RATE
		var n: float = randf() * 2.0 - 1.0
		hp = 0.7 * (hp + n - prev)
		prev = n
		var crackle: float = 1.0 if randf() < 0.02 else 0.25
		b[i] = hp * crackle * sin(clampf(t / 0.45, 0.0, 1.0) * PI) * 0.6
	return b


func _drip() -> PackedFloat32Array:
	var b := _buf(0.9)
	for k in 3:
		var start: float = k * 0.3
		var phase: float = 0.0
		for i in int(0.09 * RATE):
			var t: float = float(i) / RATE
			phase += lerpf(1400.0, 500.0, t / 0.09) / RATE
			var idx: int = int(start * RATE) + i
			if idx < b.size():
				b[idx] += sin(TAU * phase) * exp(-t * 35.0) * (0.5 - k * 0.12)
	return b


func _reveal() -> PackedFloat32Array:
	var b := _buf(3.0)
	for i in b.size():
		var t: float = float(i) / RATE
		var env: float = sin(clampf(t / 3.0, 0.0, 1.0) * PI)
		var v: float = sin(TAU * 55.0 * t) * 0.4 + sin(TAU * 82.4 * t) * 0.3 + sin(TAU * 880.0 * t + sin(t * 6.0) * 2.0) * 0.05
		b[i] = v * env * 0.7
	return b


func _success() -> PackedFloat32Array:
	var b := _buf(1.4)
	_tone(b, 0.0, 523.0, 1.0, 0.25, 4.0)
	_tone(b, 0.15, 659.0, 1.0, 0.25, 4.0)
	_tone(b, 0.3, 784.0, 1.1, 0.3, 3.0)
	return b


func _static() -> PackedFloat32Array:
	var b := _buf(0.35)
	for i in b.size():
		var t: float = float(i) / RATE
		b[i] = (randf() * 2.0 - 1.0) * 0.35 * minf(1.0, (0.35 - t) * 20.0)
	return b


func _step() -> PackedFloat32Array:
	var b := _buf(0.12)
	var lp: float = 0.0
	for i in b.size():
		var t: float = float(i) / RATE
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.08)
		b[i] = (lp * 1.5 + sin(TAU * 90.0 * t) * 0.4) * exp(-t * 40.0)
	return b


func _ending() -> PackedFloat32Array:
	var b := _buf(5.0)
	for i in b.size():
		var t: float = float(i) / RATE
		var env: float = minf(1.0, t / 1.5) * minf(1.0, (5.0 - t) / 2.0)
		var v: float = sin(TAU * 110.0 * t) * 0.3 + sin(TAU * 164.8 * t) * 0.2 + sin(TAU * 220.0 * t) * 0.15
		v += sin(TAU * 329.6 * t) * 0.08 * (0.5 + 0.5 * sin(t * 1.3))
		b[i] = v * env * 0.6
	return b
