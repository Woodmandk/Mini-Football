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

# band-pass filtered noise: the "aah" of many voices rather than plain hiss
static func _voices(n: int, freq: float, q: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	var w0 := TAU * freq / RATE
	var alpha := sin(w0) / (2.0 * q)
	var b0 := alpha
	var a0 := 1.0 + alpha
	var a1 := -2.0 * cos(w0)
	var a2 := 1.0 - alpha
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in n:
		var x := randf() * 2.0 - 1.0
		var y := (b0 * x - b0 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		s[i] = y
	return s

static func crowd() -> AudioStreamWAV:
	var n := RATE * 5
	var a := _voices(n, 520.0, 1.2)
	var b := _voices(n, 1150.0, 1.5)
	var lo := _noise(n, 0.05)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var m := 0.78 + 0.14 * sin(t * TAU / 5.0 * 2.0) + 0.08 * sin(t * TAU / 5.0 * 7.0 + 1.0)
		s[i] = (a[i] * 2.2 + b[i] * 1.0 + lo[i] * 3.0) * m
	var x := RATE / 2
	for i in x:
		var f := float(i) / x
		s[i] = s[i] * f + s[n - x + i] * (1.0 - f)
	s.resize(n - x)
	return _wav(s, true)

static func roar() -> AudioStreamWAV:
	var n := int(RATE * 4.5)
	var a := _voices(n, 640.0, 1.0)
	var b := _voices(n, 1300.0, 1.3)
	var c := _voices(n, 2500.0, 1.5)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.18, 1.0) * exp(-maxf(t - 1.4, 0.0) * 0.85)
		var wob := 1.0 + 0.1 * sin(t * 17.0) + 0.07 * sin(t * 29.0)
		s[i] = (a[i] * 4.2 + b[i] * 2.6 + c[i] * 1.4) * env * wob
	return _wav(s)

static func ooh() -> AudioStreamWAV:
	var n := int(RATE * 1.4)
	var a := _voices(n, 420.0, 1.6)
	var b := _voices(n, 800.0, 2.0)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.1, 1.0) * exp(-maxf(t - 0.3, 0.0) * 3.0)
		s[i] = (a[i] * 5.0 + b[i] * 2.0) * env
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

# the slide tackle's "sus": a band of noise that sweeps down, as in the 2D game
static func slide() -> AudioStreamWAV:
	var n := int(RATE * 0.34)
	var s := PackedFloat32Array()
	s.resize(n)
	var lo := 0.0
	var bp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 1500.0 * pow(480.0 / 1500.0, t / 0.34)
		var g := 2.0 * sin(PI * f / RATE)
		var x := randf() * 2.0 - 1.0
		lo += g * bp
		var hi := x - lo - 1.3 * bp
		bp += g * hi
		var env := minf(t / 0.012, 1.0) * exp(-t * 7.5)
		s[i] = bp * env * 1.5
	return _wav(s)

# the ball is won: a low thump and a short bright note
static func win() -> AudioStreamWAV:
	var n := int(RATE * 0.12)
	var s := _noise(n, 0.12)
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(330.0, 490.0, t / 0.08)
		s[i] = s[i] * 4.0 * exp(-t * 40.0) + sin(t * TAU * f) * exp(-t * 30.0) * 0.25
	return _wav(s)

# a body hits the grass
static func thud() -> AudioStreamWAV:
	var n := int(RATE * 0.16)
	var s := _noise(n, 0.06)
	for i in n:
		var t := float(i) / RATE
		s[i] = s[i] * 7.0 * exp(-t * 28.0) + sin(t * TAU * lerpf(75.0, 55.0, t / 0.14)) * exp(-t * 22.0) * 0.6
	return _wav(s)

# four rising notes after a goal
static func jingle() -> AudioStreamWAV:
	var notes := [523.0, 659.0, 784.0, 1047.0]
	var n := int(RATE * 0.95)
	var s := PackedFloat32Array()
	s.resize(n)
	for j in 4:
		var st := int(RATE * (0.25 + j * 0.11))
		for i in int(RATE * 0.25):
			if st + i >= n:
				break
			var t := float(i) / RATE
			var ph: float = fmod(t * notes[j], 1.0)
			var tri: float = 4.0 * absf(ph - 0.5) - 1.0
			s[st + i] += tri * minf(t / 0.01, 1.0) * exp(-t * 9.0) * 0.28
	return _wav(s)
