# Echo con IA
extends Node

const RATE: int = 22050

@export var volume_db: float = -6.0

var _cache: Dictionary = {}


func play(sound: String, pos: Vector3 = Vector3.INF, pitch: float = 1.0, gain_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _stream_for(sound)
	if stream == null:
		return
	var player: Node
	if pos == Vector3.INF:
		var flat := AudioStreamPlayer.new()
		flat.stream = stream
		flat.volume_db = volume_db + gain_db
		flat.pitch_scale = pitch
		player = flat
	else:
		var spatial := AudioStreamPlayer3D.new()
		spatial.stream = stream
		spatial.volume_db = volume_db + gain_db
		spatial.pitch_scale = pitch
		spatial.unit_size = 4.0
		spatial.max_distance = 25.0
		spatial.position = pos
		player = spatial
	add_child(player)
	player.connect("finished", player.queue_free)
	player.call("play")


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
		"door_open": samples = _door(0.7)
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


func _buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


func _noise() -> float:
	return randf() * 2.0 - 1.0


func _arc(t: float, duration: float) -> float:
	return sin(clampf(t / duration, 0.0, 1.0) * PI)


func _tone(b: PackedFloat32Array, start: float, freq: float, duration: float, amp: float, decay: float) -> void:
	var first: int = int(start * RATE)
	for i in int(duration * RATE):
		var idx: int = first + i
		if idx >= b.size():
			break
		var t: float = float(i) / RATE
		var env: float = exp(-t * decay) * minf(1.0, t * 400.0)
		var v: float = sin(TAU * freq * t) + 0.35 * sin(TAU * freq * 2.0 * t) + 0.15 * sin(TAU * freq * 3.01 * t)
		b[idx] += v * env * amp


func _doorbell() -> PackedFloat32Array:
	var b := _buffer(2.0)
	_tone(b, 0.0, 659.0, 1.2, 0.4, 3.0)
	_tone(b, 0.55, 523.0, 1.4, 0.4, 2.2)
	return b


func _click(amp: float, freq: float) -> PackedFloat32Array:
	var b := _buffer(0.06)
	for i in b.size():
		var t: float = float(i) / RATE
		b[i] = (sin(TAU * freq * t) * 0.5 + _noise() * 0.5) * exp(-t * 120.0) * amp
	return b


func _clack() -> PackedFloat32Array:
	var b := _buffer(0.35)
	for i in b.size():
		var t: float = float(i) / RATE
		var v: float = _noise() * exp(-t * 90.0) * 0.6
		var t2: float = t - 0.09
		if t2 > 0.0:
			v += _noise() * exp(-t2 * 70.0) * 0.8 + sin(TAU * 140.0 * t2) * exp(-t2 * 25.0) * 0.6
		b[i] = v
	return b


func _rattle() -> PackedFloat32Array:
	var b := _buffer(0.4)
	for k in 3:
		var first: int = int(k * 0.11 * RATE)
		for i in int(0.06 * RATE):
			var t: float = float(i) / RATE
			if first + i < b.size():
				b[first + i] += (_noise() * 0.6 + sin(TAU * 1800.0 * t) * 0.3) * exp(-t * 80.0)
	return b


func _slide(duration: float, opening: bool) -> PackedFloat32Array:
	var b := _buffer(duration + 0.08)
	var lp: float = 0.0
	for i in b.size():
		var t: float = float(i) / RATE
		lp = lerpf(lp, _noise(), 0.12)
		b[i] = lp * _arc(t, duration) * 0.9
	var first: int = int(duration * RATE * 0.95)
	var freq: float = 110.0 if opening else 90.0
	for i in int(0.08 * RATE):
		var t: float = float(i) / RATE
		if first + i < b.size():
			b[first + i] += sin(TAU * freq * t) * exp(-t * 40.0) * 0.6
	return b


func _door(duration: float) -> PackedFloat32Array:
	var b := _buffer(duration)
	var lp: float = 0.0
	var lp2: float = 0.0
	var phase: float = 0.0
	for i in b.size():
		var t: float = float(i) / RATE
		var v: float = 0.0
		if t < 0.03:
			v += _noise() * exp(-t * 220.0) * 0.7
		var t2: float = t - 0.045
		if t2 > 0.0 and t2 < 0.03:
			v += _noise() * exp(-t2 * 260.0) * 0.4
		lp = lerpf(lp, _noise(), 0.04)
		lp2 = lerpf(lp2, lp, 0.2)
		v += lp2 * _arc(t - 0.05, duration - 0.05) * 1.6
		var hinge: float = clampf((t - 0.08) / 0.35, 0.0, 1.0)
		phase += (95.0 + 40.0 * hinge) / RATE
		v += sin(TAU * phase + sin(t * 31.0) * 0.6) * sin(hinge * PI) * 0.08
		b[i] = v
	return b


func _thump(duration: float) -> PackedFloat32Array:
	var b := _buffer(duration)
	var lp: float = 0.0
	for i in b.size():
		var t: float = float(i) / RATE
		lp = lerpf(lp, _noise(), 0.1)
		b[i] = (sin(TAU * 70.0 * t) * 0.9 + lp * 0.6) * exp(-t * 18.0)
	return b


func _curtain() -> PackedFloat32Array:
	var b := _buffer(0.55)
	for i in b.size():
		var t: float = float(i) / RATE
		var rings: float = sin(TAU * 2600.0 * t) * (0.5 + 0.5 * sin(t * 90.0)) * 0.15
		b[i] = (_noise() * 0.25 + rings) * _arc(t, 0.55)
	return b


func _blip(f0: float, f1: float, duration: float) -> PackedFloat32Array:
	var b := _buffer(duration)
	var phase: float = 0.0
	for i in b.size():
		var t: float = float(i) / RATE
		phase += lerpf(f0, f1, t / duration) / RATE
		b[i] = sin(TAU * phase) * exp(-t * 18.0) * minf(1.0, t * 300.0) * 0.5
	return b


func _paper() -> PackedFloat32Array:
	var b := _buffer(0.45)
	var hp: float = 0.0
	var prev: float = 0.0
	for i in b.size():
		var t: float = float(i) / RATE
		var n: float = _noise()
		hp = 0.7 * (hp + n - prev)
		prev = n
		var crackle: float = 1.0 if randf() < 0.02 else 0.25
		b[i] = hp * crackle * _arc(t, 0.45) * 0.6
	return b


func _drip() -> PackedFloat32Array:
	var b := _buffer(0.9)
	for k in 3:
		var phase: float = 0.0
		for i in int(0.09 * RATE):
			var t: float = float(i) / RATE
			phase += lerpf(1400.0, 500.0, t / 0.09) / RATE
			var idx: int = int(k * 0.3 * RATE) + i
			if idx < b.size():
				b[idx] += sin(TAU * phase) * exp(-t * 35.0) * (0.5 - k * 0.12)
	return b


func _reveal() -> PackedFloat32Array:
	var b := _buffer(3.0)
	for i in b.size():
		var t: float = float(i) / RATE
		var v: float = sin(TAU * 55.0 * t) * 0.4 + sin(TAU * 82.4 * t) * 0.3 + sin(TAU * 880.0 * t + sin(t * 6.0) * 2.0) * 0.05
		b[i] = v * _arc(t, 3.0) * 0.7
	return b


func _success() -> PackedFloat32Array:
	var b := _buffer(1.4)
	_tone(b, 0.0, 523.0, 1.0, 0.25, 4.0)
	_tone(b, 0.15, 659.0, 1.0, 0.25, 4.0)
	_tone(b, 0.3, 784.0, 1.1, 0.3, 3.0)
	return b


func _static() -> PackedFloat32Array:
	var b := _buffer(0.35)
	for i in b.size():
		var t: float = float(i) / RATE
		b[i] = _noise() * 0.35 * minf(1.0, (0.35 - t) * 20.0)
	return b


func _step() -> PackedFloat32Array:
	var b := _buffer(0.12)
	var lp: float = 0.0
	for i in b.size():
		var t: float = float(i) / RATE
		lp = lerpf(lp, _noise(), 0.08)
		b[i] = (lp * 1.5 + sin(TAU * 90.0 * t) * 0.4) * exp(-t * 40.0)
	return b


func _ending() -> PackedFloat32Array:
	var b := _buffer(5.0)
	for i in b.size():
		var t: float = float(i) / RATE
		var env: float = minf(1.0, t / 1.5) * minf(1.0, (5.0 - t) / 2.0)
		var v: float = sin(TAU * 110.0 * t) * 0.3 + sin(TAU * 164.8 * t) * 0.2 + sin(TAU * 220.0 * t) * 0.15
		v += sin(TAU * 329.6 * t) * 0.08 * (0.5 + 0.5 * sin(t * 1.3))
		b[i] = v * env * 0.6
	return b
