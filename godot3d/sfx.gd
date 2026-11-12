extends RefCounted
# All sounds are made in code when the game starts, so there are no sound files to load.

const RATE := 22050

static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

static func kick(strength := 1.0) -> AudioStreamWAV:
	var n := int(RATE * 0.16)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(210.0, 55.0, clampf(t / 0.09, 0.0, 1.0))
		ph += TAU * f / RATE
		var env := exp(-t * 26.0)
		var click := (randf() * 2.0 - 1.0) * exp(-t * 160.0) * 0.7
		s[i] = (sin(ph) * env + click) * 0.9 * strength
	return _wav(s)

static func whistle(dur := 0.55) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 2750.0 + sin(t * TAU * 38.0) * 140.0
		ph += TAU * f / RATE
		var env := minf(t / 0.02, 1.0) * minf((dur - t) / 0.05, 1.0)
		s[i] = (sin(ph) * 0.5 + sin(ph * 2.0) * 0.12 + (randf() - 0.5) * 0.08) * env * 0.5
	return _wav(s)

static func _noise(n: int, lp: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	var y := 0.0
	var y2 := 0.0
	for i in n:
		var x := randf() * 2.0 - 1.0
		y += (x - y) * lp
		y2 += (y - y2) * lp
		s[i] = y2
	return s

static func crowd() -> AudioStreamWAV:
	var n := RATE * 5
	var s := _noise(n, 0.11)
	var hi := _noise(n, 0.3)
	for i in n:
		var t := float(i) / RATE
		var m := 0.75 + 0.15 * sin(t * TAU / 5.0 * 2.0) + 0.1 * sin(t * TAU / 5.0 * 5.0 + 1.0)
		s[i] = (s[i] * 5.5 + hi[i] * 0.8) * m
	# crossfade the ends so the loop has no click
	var x := RATE / 2
	for i in x:
		var a := float(i) / x
		s[i] = s[i] * a + s[n - x + i] * (1.0 - a)
	s.resize(n - x)
	return _wav(s, true)

static func roar() -> AudioStreamWAV:
	var n := int(RATE * 4.2)
	var s := _noise(n, 0.16)
	var hi := _noise(n, 0.45)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.25, 1.0) * exp(-maxf(t - 1.2, 0.0) * 0.9)
		var wob := 1.0 + 0.12 * sin(t * 19.0) + 0.08 * sin(t * 31.0)
		s[i] = (s[i] * 6.5 + hi[i] * 1.6) * env * wob
	return _wav(s)

static func ooh() -> AudioStreamWAV:
	var n := int(RATE * 1.3)
	var s := _noise(n, 0.09)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.12, 1.0) * exp(-maxf(t - 0.25, 0.0) * 3.2)
		s[i] = s[i] * 9.0 * env
	return _wav(s)

static func net() -> AudioStreamWAV:
	var n := int(RATE * 0.45)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := randf() * 2.0 - 1.0
		var hp := x - prev
		prev = x
		s[i] = hp * exp(-t * 9.0) * 0.45
	return _wav(s)

static func blip(f := 880.0) -> AudioStreamWAV:
	var n := int(RATE * 0.09)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(t * TAU * f) * exp(-t * 40.0) * 0.4
	return _wav(s)

static func post() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = (sin(t * TAU * 640.0) + 0.6 * sin(t * TAU * 1530.0) + 0.3 * sin(t * TAU * 2710.0)) * exp(-t * 11.0) * 0.4
	return _wav(s)

static func whoosh() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var s := _noise(n, 0.25)
	for i in n:
		var t := float(i) / RATE
		var env := sin(clampf(t / 0.5, 0.0, 1.0) * PI)
		s[i] = s[i] * 3.0 * env * env
	return _wav(s)
