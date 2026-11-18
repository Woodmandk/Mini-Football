#!/usr/bin/env python3
# Makes every match sound of Pitch Boss as .ogg files in godot3d/snd/.
# Nothing is recorded: crowds are thousands of synthetic voices, the ball is a struck leather shell,
# the whistle is a pea whistle, and a stadium reverb is baked in. Run again after changing it:
#   python3 godot3d/tools/make_sounds.py
# Needs numpy and ffmpeg (with libvorbis). Fixed seeds, so the same files come out every time.
import os, subprocess, sys, wave
import numpy as np

SR = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "snd")
rng = np.random.default_rng(20261118)

VOWELS = {  # formants (Hz) and bandwidths: a, e, i, o, u and the open "aw" of a groan
	"a": ([800, 1150, 2900], [80, 90, 120], [1.0, 0.5, 0.25]),
	"e": ([400, 1700, 2600], [70, 80, 100], [1.0, 0.35, 0.3]),
	"i": ([300, 2200, 3000], [60, 90, 100], [1.0, 0.3, 0.25]),
	"o": ([450, 800, 2830], [70, 80, 100], [1.0, 0.6, 0.15]),
	"u": ([325, 700, 2530], [50, 60, 170], [1.0, 0.35, 0.1]),
	"aw": ([650, 1000, 2700], [90, 100, 120], [1.0, 0.55, 0.15]),
}

def freqs(n):
	return np.fft.rfftfreq(n, 1.0 / SR)

def ffilt(x, mag):
	"""Zero-phase filter by a magnitude response (circular: loops stay seamless)."""
	return np.fft.irfft(np.fft.rfft(x) * mag, len(x))

def lp(f, fc, o=2):
	return 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * o))

def hp(f, fc, o=2):
	return 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1.0)) ** (2 * o))

def formant_mag(f, vowel, bright=1.0):
	F, B, A = VOWELS[vowel]
	m = np.zeros_like(f)
	for fi, bi, ai in zip(F, B, A):
		m += ai * (bright if fi > 1500 else 1.0) / (1.0 + ((f - fi) / (bi * 1.6)) ** 2)
	return m * hp(f, 90, 1) * lp(f, 4500, 2)

def env_adsr(n, a, r):
	e = np.ones(n)
	na, nr = max(1, int(a * SR)), max(1, int(r * SR))
	na = min(na, n // 2)
	nr = min(nr, n - na)
	e[:na] = np.linspace(0, 1, na) ** 1.5
	e[n - nr:] *= np.linspace(1, 0, nr) ** 1.5
	return e

def glottal(f0):
	"""A voice source for a per-sample pitch contour, with jitter and breath."""
	jit = 1.0 + 0.012 * ffilt(rng.standard_normal(len(f0)), lp(freqs(len(f0)), 30, 1)) * 6
	ph = np.cumsum(f0 * jit / SR)
	saw = 2.0 * (ph - np.floor(ph)) - 1.0
	# soften the edge a little so it is a throat, not a buzzer
	saw = saw - 0.3 * np.sin(2 * np.pi * ph)
	return saw + 0.35 * rng.standard_normal(len(f0))

class Bank:
	"""Voices are summed per vowel and per distance, then each sum is filtered once."""
	def __init__(self, n, circular=True):
		self.n = n
		self.circ = circular
		self.b = {}

	def add(self, key, start, sig):
		buf = self.b.setdefault(key, np.zeros(self.n))
		idx = (start + np.arange(len(sig)))
		if self.circ:
			idx %= self.n
			np.add.at(buf, idx, sig)
		else:
			ok = (idx >= 0) & (idx < self.n)
			buf[idx[ok]] += sig[ok]

	def render(self, bright=1.0):
		f = freqs(self.n)
		out = np.zeros(self.n)
		for (vowel, dist), buf in self.b.items():
			mag = formant_mag(f, vowel, bright) * lp(f, [5000, 2600, 1300][dist], 2)
			out += ffilt(buf, mag)
		return out

def voice(dur, f0a, f0b=None, shape="flat", a=0.06, r=0.15):
	n = max(int(dur * SR), 32)
	t = np.linspace(0, 1, n)
	f0b = f0a if f0b is None else f0b
	if shape == "rise":
		f0 = f0a + (f0b - f0a) * np.sqrt(t)
	elif shape == "arch":  # up then down: an "ooooh"
		f0 = f0a + (f0b - f0a) * np.sin(np.pi * np.minimum(t * 1.3, 1.0)) ** 0.8
	elif shape == "fall":
		f0 = f0a + (f0b - f0a) * t ** 0.7
	else:
		f0 = f0a + (f0b - f0a) * t
	f0 *= 1.0 + 0.01 * np.sin(2 * np.pi * rng.uniform(4, 6) * t * dur + rng.uniform(0, 6))
	return glottal(f0) * env_adsr(n, a, r)

def stadium_ir(rt=1.7, n_sec=2.4, er=True):
	n = int(n_sec * SR)
	t = np.arange(n) / SR
	f = freqs(n)
	ir = np.zeros(n)
	# three bands, the highs die first: open stands, a roof over them
	for fc_lo, fc_hi, k in [(0, 500, 1.0), (500, 2500, 0.8), (2500, 16000, 0.5)]:
		nb = rng.standard_normal(n)
		mag = (hp(f, fc_lo, 2) if fc_lo > 0 else 1.0) * lp(f, fc_hi, 2)
		nb = ffilt(nb, mag)
		ir += nb * np.exp(-6.9 * t / (rt * k))
	ir *= np.minimum(t / 0.02, 1.0)  # the tail starts after the first echoes
	if er:
		for d, g in [(0.031, 0.5), (0.047, 0.35), (0.083, 0.3), (0.12, 0.22), (0.17, 0.15)]:
			ir[int(d * SR)] += g * 6.0
	return ir / np.sqrt(np.sum(ir ** 2))

def reverb(x, wet=0.25, rt=1.7, tail=1.6, circular=False, ir=None):
	ir = stadium_ir(rt) if ir is None else ir
	if circular:
		n = len(x)
		irp = np.zeros(n)
		irp[:min(len(ir), n)] = ir[:n]
		y = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(irp), n)
		return x * (1 - wet) + y * wet * 3.0
	n = len(x) + int(tail * SR)
	xp = np.zeros(n)
	xp[:len(x)] = x
	m = 1 << int(np.ceil(np.log2(n + len(ir))))
	y = np.fft.irfft(np.fft.rfft(xp, m) * np.fft.rfft(ir, m), m)[:n]
	out = xp * (1 - wet) + y * wet * 3.0
	fade = int(0.25 * SR)
	out[-fade:] *= np.linspace(1, 0, fade) ** 2
	return out

def norm(x, peak=0.89):
	m = np.max(np.abs(x))
	return x * (peak / m) if m > 0 else x

def save(name, x, q=4):
	os.makedirs(OUT, exist_ok=True)
	tmp = os.path.join(OUT, name + ".wav")
	pcm = (np.clip(x, -1, 1) * 32000).astype(np.int16)
	with wave.open(tmp, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(pcm.tobytes())
	subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), os.path.join(OUT, name + ".ogg")], check=True)
	os.remove(tmp)
	print("%-14s %5.1f s" % (name, len(x) / SR))

def loop_mod(n, depth, periods):
	"""Slow swells that fit a whole number of times into the loop, so it joins up."""
	t = np.arange(n) / n
	m = np.ones(n)
	for k in periods:
		m += depth * rng.uniform(0.5, 1.0) * np.sin(2 * np.pi * k * t + rng.uniform(0, 6.28))
	return m

def voice_f0(shout=False):
	male = rng.random() < 0.72
	if shout:
		return rng.uniform(150, 260) if male else rng.uniform(280, 420)
	return rng.uniform(95, 165) if male else rng.uniform(180, 270)

# ---------------------------------------------------------------- crowd beds (looping)

def crowd_bed(sec, density, shout_k, excite, name):
	n = int(sec * SR)
	bank = Bank(n)
	vows = list(VOWELS.keys())
	# chatter: thousands of short syllables from all round the ground
	for _ in range(int(density * sec)):
		dist = rng.choice(3, p=[0.12, 0.38, 0.5])
		shout = rng.random() < shout_k
		dur = rng.uniform(0.12, 0.5) if not shout else rng.uniform(0.35, 1.1)
		f0 = voice_f0(shout)
		sig = voice(dur, f0, f0 * rng.uniform(0.85, 1.25 if shout else 1.08), "arch" if shout else "flat", 0.03, 0.08)
		g = [1.0, 0.5, 0.25][dist] * rng.lognormal(0, 0.45) * (1.8 if shout else 1.0)
		bank.add((rng.choice(vows), dist), rng.integers(0, n), sig * g)
	v = bank.render(bright=1.0 + excite)
	v /= np.std(v) + 1e-9
	# the far mass: thousands more, too far away to be voices, just the sound of a full ground
	f = freqs(n)
	mass = ffilt(rng.standard_normal(n), (formant_mag(f, "a") * 0.6 + formant_mag(f, "o") * 0.6 + 0.15 / (1.0 + (f / 700.0) ** 2)) * lp(f, 2400 + 1600 * excite, 2))
	mass /= np.std(mass) + 1e-9
	# a few claps and the odd finger whistle
	claps = np.zeros(n)
	for _ in range(int(sec * (2 + 10 * excite))):
		i = rng.integers(0, n)
		ln = int(rng.uniform(0.004, 0.012) * SR)
		idx = (i + np.arange(ln)) % n
		claps[idx] += rng.standard_normal(ln) * np.exp(-np.arange(ln) / (ln / 4)) * rng.uniform(0.3, 1.0)
	claps = ffilt(claps, hp(f, 700, 2) * lp(f, 3500, 2))
	whis = np.zeros(n)
	for _ in range(int(sec * (0.1 + 0.6 * excite))):
		d = rng.uniform(0.3, 0.9)
		ln = int(d * SR)
		tt = np.arange(ln) / SR
		fw = rng.uniform(2000, 3200) * (1.0 + 0.08 * np.sin(np.pi * tt / d))
		s = np.sin(2 * np.pi * np.cumsum(fw) / SR) * env_adsr(ln, 0.04, 0.12) * rng.uniform(0.1, 0.25)
		idx = (rng.integers(0, n) + np.arange(ln)) % n
		whis[idx] += s
	mix = v * 0.9 + mass * (0.9 - 0.3 * excite) + claps / (np.std(claps) + 1e-9) * 0.12 + whis * 0.6
	mix *= loop_mod(n, 0.14 + 0.1 * excite, [1, 2, 3, 5])
	mix = reverb(mix, wet=0.45, rt=2.0, circular=True)
	save(name, norm(mix, 0.7))

# ---------------------------------------------------------------- the chant (looping)

def chant():
	bpm = 116.0
	beat = 60.0 / bpm
	bars = 8
	n = int(bars * 4 * beat * SR)
	# an original terrace tune: (semitones above A, beats); None = a gap the crowd claps in
	A = 0
	phrase1 = [(0, 1), (0, 0.5), (3, 0.5), (5, 1), (7, 1), (5, 1), (3, 1), (0, 2)]
	phrase2 = [(0, 1), (0, 0.5), (3, 0.5), (5, 1), (7, 1), (10, 1.5), (7, 0.5), (5, 2)]
	notes = phrase1 + phrase2 + phrase1 + [(0, 1), (0, 0.5), (3, 0.5), (5, 1), (3, 1), (0, 4)]
	total = sum(b for _, b in notes)
	assert abs(total - bars * 4) < 1e-6, total
	bank = Bank(n)
	f = freqs(n)
	for s in range(320):
		root = 220.0 if rng.random() < 0.3 else 110.0 * rng.choice([1.0, 2.0], p=[0.35, 0.65])
		det = 2 ** (rng.normal(0, 0.25) / 12)
		lag = rng.normal(0.0, 0.035)
		f0 = np.zeros(n)
		amp = np.zeros(n)
		pos = 0.0
		for semi, b in notes:
			i0 = int((pos + lag) * beat * SR) % n
			ln = int(b * beat * SR * rng.uniform(0.78, 0.92))
			idx = (i0 + np.arange(ln)) % n
			f0[idx] = root * det * 2 ** (semi / 12)
			e = env_adsr(ln, 0.05, 0.12)
			amp[idx] = e
			pos += b
		# glide between notes (singers slide), fill the gaps with the last pitch
		nz = f0 > 0
		idxs = np.where(nz, np.arange(n), 0)
		np.maximum.accumulate(idxs, out=idxs)
		f0 = f0[idxs]
		f0[f0 == 0] = root
		f0 = ffilt(f0 - f0.mean(), lp(f, 12, 1)) + f0.mean()
		src = glottal(f0) * amp * rng.lognormal(0, 0.35)
		dist = rng.choice(3, p=[0.15, 0.4, 0.45])
		bank.add((rng.choice(["o", "a", "aw"]), dist), 0, src * [1.0, 0.55, 0.3][dist])
	sing = bank.render(bright=1.4)
	sing /= np.std(sing) + 1e-9
	# claps: two on the gaps and on the long notes
	claps = np.zeros(n)
	clap_beats = []
	pos = 0.0
	for semi, b in notes:
		if b >= 2:
			for k in range(int(b)):
				clap_beats.append(pos + k + 0.0)
		pos += b
	for cb in clap_beats:
		for _ in range(260):
			i = int((cb * beat + rng.normal(0, 0.018)) * SR) % n
			ln = int(rng.uniform(0.005, 0.014) * SR)
			idx = (i + np.arange(ln)) % n
			claps[idx] += rng.standard_normal(ln) * np.exp(-np.arange(ln) / (ln / 4))
	claps = ffilt(claps, hp(f, 500, 2) * lp(f, 4000, 2) + 0.3 * lp(f, 300, 2) * hp(f, 120, 1))
	claps /= np.std(claps) + 1e-9
	mix = sing + claps * 0.35
	mix = reverb(mix, wet=0.5, rt=2.1, circular=True)
	save("chant", norm(mix, 0.7))

def clap_rhythm():
	"""Clap, clap, clap-clap-clap, a shout. The whole ground, looping."""
	bpm = 104.0
	beat = 60.0 / bpm
	n = int(8 * beat * SR)
	f = freqs(n)
	claps = np.zeros(n)
	for cb in [0, 1, 2, 2.5, 3, 4, 5, 6, 6.5, 7]:
		for _ in range(300):
			i = int((cb * beat + rng.normal(0, 0.02)) * SR) % n
			ln = int(rng.uniform(0.005, 0.014) * SR)
			idx = (i + np.arange(ln)) % n
			claps[idx] += rng.standard_normal(ln) * np.exp(-np.arange(ln) / (ln / 4))
	claps = ffilt(claps, hp(f, 500, 2) * lp(f, 4000, 2) + 0.35 * lp(f, 300, 2) * hp(f, 120, 1))
	claps /= np.std(claps)
	bank = Bank(n)
	for cb in [3.5, 7.5]:
		for _ in range(220):
			f0 = voice_f0(True)
			sig = voice(rng.uniform(0.22, 0.32), f0, f0 * 1.1, "rise", 0.02, 0.1)
			bank.add(("e", rng.choice(3)), int((cb * beat + rng.normal(0, 0.03)) * SR) % n, sig * rng.lognormal(0, 0.3))
	hey = bank.render(1.3)
	hey /= np.std(hey) + 1e-9
	mix = claps + hey * 0.45
	mix = reverb(mix, wet=0.5, rt=2.1, circular=True)
	save("claps", norm(mix, 0.7))

# ---------------------------------------------------------------- crowd reactions (one-shots)

def reaction(sec, n_voices, f0k, shape, vowel_p, env_fn, bright, name, wet=0.4, extra=None):
	n = int(sec * SR)
	bank = Bank(n, circular=False)
	vows = list(vowel_p.keys())
	pv = np.array(list(vowel_p.values()), float)
	pv /= pv.sum()
	for _ in range(n_voices):
		st = rng.normal(0.0, 0.07)
		f0 = voice_f0(True) * f0k
		dur = sec * rng.uniform(0.45, 0.9)
		up = {"arch": 1.35, "rise": 1.3, "fall": 0.72, "flat": 1.04}[shape] * rng.uniform(0.92, 1.08)
		sig = voice(dur, f0, f0 * up, shape, rng.uniform(0.04, 0.15), dur * 0.5)
		dist = rng.choice(3, p=[0.15, 0.4, 0.45])
		bank.add((vows[rng.choice(len(vows), p=pv)], dist), int(max(st, 0.0) * SR), sig * [1.0, 0.55, 0.3][dist] * rng.lognormal(0, 0.4))
	x = bank.render(bright)
	x /= np.std(x[: int(min(sec, 1.5) * SR)]) + 1e-9
	t = np.arange(n) / SR
	x *= env_fn(t)
	if extra is not None:
		x += extra(n)
	save(name, norm(reverb(x, wet=wet, rt=2.0, tail=1.8), 0.89))

def applause_sig(n, rate, env):
	f = freqs(n)
	x = np.zeros(n)
	t = np.arange(n) / SR
	k = int(rate * n / SR)
	pos = rng.integers(0, n, k)
	keep = rng.random(k) < env(pos / SR)
	for i in pos[keep]:
		ln = int(rng.uniform(0.004, 0.013) * SR)
		e = min(ln, n - i)
		x[i:i + e] += rng.standard_normal(e) * np.exp(-np.arange(e) / (ln / 4)) * rng.uniform(0.3, 1.0)
	return ffilt(x, hp(f, 450, 2) * lp(f, 5000, 2) + 0.25 * lp(f, 350, 2) * hp(f, 100, 1))

def crowd_one_shots():
	# the goal: a burst of thousands, a long held roar, applause and whistles inside it, then it settles
	def goal_env(t):
		return np.minimum(t / 0.18, 1.0) ** 1.2 * (0.82 + 0.18 * np.exp(-((t - 0.9) / 0.6) ** 2)) * np.exp(-np.maximum(t - 3.2, 0) * 0.55)
	def goal_extra(n):
		ap = applause_sig(n, 9000, lambda t: np.clip((t - 0.6) / 0.8, 0, 1) * np.exp(-np.maximum(t - 4.0, 0) * 0.5))
		ap /= np.std(ap) + 1e-9
		return ap * 0.28
	reaction(8.0, 2400, 1.05, "rise", {"e": 2, "a": 3, "i": 1, "o": 1}, goal_env, 1.6, "roar", extra=goal_extra)
	# away goal: the visitors' end goes up, the rest of the ground groans
	def away_env(t):
		return np.minimum(t / 0.25, 1.0) * np.exp(-np.maximum(t - 1.8, 0) * 0.8)
	reaction(5.0, 500, 1.0, "rise", {"e": 2, "a": 3}, away_env, 1.3, "roar_away", wet=0.55)
	# near miss: everybody "ooooh"
	for i in range(3):
		def ooh_env(t, k=i):
			return np.minimum(t / (0.12 + 0.04 * k), 1.0) * np.exp(-np.maximum(t - 0.55 - 0.1 * k, 0) * 2.6)
		reaction(2.4, 1400, 0.9, "arch", {"o": 4, "u": 3}, ooh_env, 1.0, "ooh%d" % i)
	# disappointment: "aww"
	reaction(2.2, 1200, 0.85, "fall", {"aw": 4, "o": 1}, lambda t: np.minimum(t / 0.1, 1.0) * np.exp(-np.maximum(t - 0.4, 0) * 2.2), 0.9, "aww")
	# a hard tackle, a big chance: a quick gasp
	reaction(1.2, 900, 1.0, "rise", {"a": 2, "o": 2}, lambda t: np.minimum(t / 0.05, 1.0) * np.exp(-np.maximum(t - 0.12, 0) * 6.0), 1.1, "gasp")
	# a positive buzz: corner won, a good run, a new card in the shop
	reaction(2.6, 900, 1.05, "rise", {"e": 2, "a": 2}, lambda t: np.minimum(t / 0.3, 1.0) * np.exp(-np.maximum(t - 0.7, 0) * 1.6), 1.4, "cheer")
	# boos and whistles at a foul or a card
	def jeer_extra(n):
		x = np.zeros(n)
		for _ in range(70):
			d = rng.uniform(0.4, 1.3)
			ln = int(d * SR)
			i = int(rng.uniform(0, 0.6) * SR)
			ln = min(ln, n - i)
			tt = np.arange(ln) / SR
			fw = rng.uniform(1900, 3300) * (1.0 + rng.uniform(-0.1, 0.12) * tt / d)
			x[i:i + ln] += np.sin(2 * np.pi * np.cumsum(fw) / SR) * env_adsr(ln, 0.05, 0.2) * rng.uniform(0.2, 1.0)
		return x / (np.std(x) + 1e-9) * 0.5
	reaction(2.6, 1100, 0.8, "flat", {"u": 4, "o": 2}, lambda t: np.minimum(t / 0.2, 1.0) * np.exp(-np.maximum(t - 1.0, 0) * 1.5), 0.8, "jeer", extra=jeer_extra)
	# applause: a save, a substitution, half time
	for name, sec, rate in [("clap", 4.0, 6000), ("clap_big", 7.0, 11000)]:
		n = int(sec * SR)
		env = lambda t, s=sec: np.minimum(t / 0.35, 1.0) * np.exp(-np.maximum(t - s * 0.35, 0) * (3.2 / s))
		ap = applause_sig(n, rate, env)
		ap *= env(np.arange(n) / SR)
		save(name, norm(reverb(ap, wet=0.4, rt=1.8), 0.85))

# ---------------------------------------------------------------- on the pitch

def modal(n, parts, click=0.0, click_lp=4000, noise_dec=200.0):
	t = np.arange(n) / SR
	x = np.zeros(n)
	for fr, dec, a in parts:
		x += a * np.sin(2 * np.pi * fr * t * (1 + rng.uniform(-0.02, 0.02))) * np.exp(-t * dec)
	if click > 0:
		c = rng.standard_normal(n) * np.exp(-t * noise_dec)
		x += click * ffilt(c, lp(freqs(n), click_lp, 2) * hp(freqs(n), 150, 1))
	return x

def ball_sounds():
	# Leather ball struck: a low body "pock", the shell rings briefly, a scuff of boot and grass.
	for i in range(4):  # soft dribble taps
		n = int(0.12 * SR)
		x = modal(n, [(rng.uniform(170, 230), 55, 1.0), (rng.uniform(420, 520), 90, 0.35)], click=0.35, click_lp=2200, noise_dec=260)
		x *= np.minimum(np.arange(n) / (0.0015 * SR), 1)
		save("dribble%d" % i, norm(reverb(x, 0.12, 1.4, 0.6), 0.8))
	for i in range(4):  # first touch / short pass
		n = int(0.2 * SR)
		x = modal(n, [(rng.uniform(150, 190), 38, 1.0), (rng.uniform(360, 440), 70, 0.5), (rng.uniform(900, 1150), 140, 0.2)], click=0.6, click_lp=3500, noise_dec=320)
		x *= np.minimum(np.arange(n) / (0.001 * SR), 1)
		save("touch%d" % i, norm(reverb(x, 0.15, 1.5, 0.8), 0.85))
	for i in range(4):  # a firm pass or long ball
		n = int(0.26 * SR)
		x = modal(n, [(rng.uniform(120, 150), 30, 1.0), (rng.uniform(300, 360), 55, 0.6), (rng.uniform(800, 1000), 120, 0.3), (rng.uniform(1900, 2300), 300, 0.1)], click=0.9, click_lp=5000, noise_dec=380)
		x *= np.minimum(np.arange(n) / (0.0008 * SR), 1)
		save("pass%d" % i, norm(reverb(x, 0.18, 1.6, 1.0), 0.88))
	for i in range(4):  # a shot: a deep thump, a crack, then the ball tearing through the air
		n = int(0.55 * SR)
		t = np.arange(n) / SR
		x = modal(n, [(rng.uniform(85, 105), 22, 1.2), (rng.uniform(210, 250), 40, 0.7), (rng.uniform(600, 720), 90, 0.35), (rng.uniform(1500, 1800), 220, 0.15)], click=1.6, click_lp=6500, noise_dec=520)
		air = ffilt(rng.standard_normal(n), hp(freqs(n), 900, 2) * lp(freqs(n), 4500, 2))
		air *= np.clip((t - 0.02) / 0.05, 0, 1) * np.exp(-np.maximum(t - 0.07, 0) * 9.0) * 0.12
		x = x * np.minimum(t / 0.0006, 1) + air
		save("shot%d" % i, norm(reverb(x, 0.24, 1.8, 1.3), 0.95))
	for i in range(2):  # header: duller, no boot
		n = int(0.2 * SR)
		x = modal(n, [(rng.uniform(190, 230), 45, 1.0), (rng.uniform(480, 560), 90, 0.35)], click=0.25, click_lp=1500, noise_dec=200)
		save("header%d" % i, norm(reverb(x, 0.16, 1.5, 0.8), 0.85))
	for i in range(3):  # ball lands on grass
		n = int(0.16 * SR)
		x = modal(n, [(rng.uniform(95, 130), 45, 1.0), (rng.uniform(260, 320), 90, 0.25)], click=0.45, click_lp=1600, noise_dec=180)
		save("bounce%d" % i, norm(reverb(x, 0.12, 1.4, 0.6), 0.8))
	# the goalkeeper's gloves: a slap and a hug of the ball
	n = int(0.22 * SR)
	t = np.arange(n) / SR
	slap = ffilt(rng.standard_normal(n), hp(freqs(n), 600, 2) * lp(freqs(n), 5000, 1)) * np.exp(-t * 70) * 0.9
	x = slap + modal(n, [(160, 45, 0.8), (380, 80, 0.3)])
	save("catch", norm(reverb(x, 0.18, 1.5, 0.8), 0.85))
	# the post: aluminium rings, clearly and for a long time
	n = int(1.6 * SR)
	t = np.arange(n) / SR
	x = modal(n, [(98, 9, 0.6), (523, 3.2, 1.0), (1380, 4.0, 0.7), (2640, 5.5, 0.45), (4290, 8.0, 0.25), (6200, 12, 0.12)], click=1.2, click_lp=7000, noise_dec=600)
	x += modal(n, [(140, 30, 1.0), (330, 50, 0.4)]) * 0.8  # the ball itself
	save("post", norm(reverb(x, 0.3, 2.0, 1.6), 0.92))
	# the net: the ball in the rope, then the net shivering
	n = int(1.0 * SR)
	t = np.arange(n) / SR
	rustle = ffilt(rng.standard_normal(n), hp(freqs(n), 1200, 2) * lp(freqs(n), 7000, 1))
	flutter = 0.6 + 0.4 * np.sin(2 * np.pi * 23 * t) * np.exp(-t * 3)
	x = rustle * flutter * np.minimum(t / 0.01, 1) * np.exp(-t * 4.5) * 0.7 + modal(n, [(110, 25, 0.8), (260, 40, 0.3)], click=0.3, click_lp=1500)
	save("net", norm(reverb(x, 0.2, 1.6, 1.0), 0.88))
	# a body on the grass
	for i in range(2):
		n = int(0.3 * SR)
		t = np.arange(n) / SR
		x = modal(n, [(rng.uniform(60, 75), 18, 1.0), (rng.uniform(140, 170), 35, 0.4)], click=0.8, click_lp=900, noise_dec=40)
		grass = ffilt(rng.standard_normal(n), hp(freqs(n), 1500, 2) * lp(freqs(n), 6000, 1)) * np.exp(-t * 14) * 0.25
		save("thud%d" % i, norm(reverb(x + grass, 0.12, 1.4, 0.6), 0.85))
	# the slide: studs and hip through wet grass
	for i in range(2):
		n = int(0.55 * SR)
		t = np.arange(n) / SR
		x = rng.standard_normal(n)
		x = ffilt(x, hp(freqs(n), 500, 2) * lp(freqs(n), 5000, 1))
		grain = 0.55 + 0.45 * np.abs(ffilt(rng.standard_normal(n), lp(freqs(n), 60, 1))) / 0.05
		grain = np.clip(grain, 0, 2)
		x *= grain * np.minimum(t / 0.02, 1) * np.exp(-t * 5.5)
		# the sweep down as he slows
		x = x * (0.5 + 0.5 * np.exp(-t * 3)) + ffilt(x, lp(freqs(n), 900, 2)) * (1 - np.exp(-t * 3))
		save("slide%d" % i, norm(reverb(x, 0.12, 1.4, 0.6), 0.8))
	# boot meets ball meets boot: a won tackle
	for i in range(2):
		n = int(0.25 * SR)
		x = modal(n, [(rng.uniform(140, 170), 40, 1.0), (rng.uniform(420, 500), 80, 0.4)], click=1.0, click_lp=3000, noise_dec=300)
		d = int(rng.uniform(0.035, 0.05) * SR)
		x2 = np.zeros(n)
		x2[d:] = modal(n - d, [(rng.uniform(110, 130), 45, 0.7)], click=0.6, click_lp=2000)
		save("tackle%d" % i, norm(reverb(x + x2, 0.14, 1.5, 0.7), 0.85))

def whistle_blast(dur, pitch=3150.0):
	n = int(dur * SR)
	t = np.arange(n) / SR
	# the pea rattles in the chamber: an uneven 30-50 Hz warble in both pitch and level
	rate = 38 + 6 * np.sin(2 * np.pi * 0.7 * t)
	warble = np.sin(2 * np.pi * np.cumsum(rate) / SR)
	warble = np.tanh(warble * 2.5)
	blow = np.minimum(t / 0.025, 1.0) ** 0.7 * np.minimum((dur - t) / 0.06, 1.0).clip(0, 1) ** 1.2
	f0 = pitch * (1 + 0.025 * warble + 0.01 * np.minimum(t / 0.08, 1))
	ph = np.cumsum(f0 / SR)
	tone = np.sin(2 * np.pi * ph) + 0.18 * np.sin(4 * np.pi * ph) + 0.05 * np.sin(6 * np.pi * ph)
	am = 0.72 + 0.28 * warble
	breath = ffilt(rng.standard_normal(n), hp(freqs(n), 2000, 2) * lp(freqs(n), 8000, 2)) * 0.12
	return (tone * am + breath) * blow

def whistles():
	ir = stadium_ir(2.0)
	def out(name, parts):
		total = sum(d + g for d, g in parts)
		x = np.zeros(int(total * SR) + 10)
		pos = 0
		for d, g in parts:
			b = whistle_blast(d, rng.uniform(3100, 3200))
			x[pos:pos + len(b)] += b
			pos += int((d + g) * SR)
		save(name, norm(reverb(x, 0.32, 2.0, 1.6, ir=ir), 0.8))
	out("whistle_short", [(0.22, 0)])
	out("whistle", [(0.42, 0)])
	out("whistle_long", [(0.95, 0)])
	out("whistle_half", [(0.3, 0.16), (0.95, 0)])
	out("whistle_full", [(0.3, 0.14), (0.3, 0.14), (1.2, 0)])

def ui_sounds():
	# soft, wooden: nothing that beeps
	for name, fr, dec, a2 in [("click", 1150, 70, 0.3), ("click2", 1560, 55, 0.35)]:
		n = int(0.12 * SR)
		x = modal(n, [(fr, dec, 1.0), (fr * 2.7, dec * 1.8, a2), (fr * 0.5, dec * 1.3, 0.25)], click=0.25, click_lp=6000, noise_dec=900)
		save(name, norm(x, 0.6))
	# the transition swish for replays and the intro
	n = int(0.7 * SR)
	t = np.arange(n) / SR
	x = rng.standard_normal(n)
	parts = np.zeros(n)
	for k, fc in enumerate(np.linspace(600, 3200, 8)):
		seg = ffilt(x, hp(freqs(n), fc, 2) * lp(freqs(n), fc * 1.6, 2))
		w = np.exp(-((t - 0.1 - k * 0.04) / 0.18) ** 2)
		parts += seg * w
	save("whoosh", norm(parts * np.sin(np.clip(t / 0.7, 0, 1) * np.pi), 0.6))

if __name__ == "__main__":
	only = sys.argv[1:]
	jobs = {
		"beds": lambda: (crowd_bed(24.0, 260, 0.05, 0.0, "crowd"), crowd_bed(20.0, 420, 0.3, 0.6, "crowd_hot")),
		"chant": lambda: (chant(), clap_rhythm()),
		"react": crowd_one_shots,
		"ball": ball_sounds,
		"whistle": whistles,
		"ui": ui_sounds,
	}
	for k, fn in jobs.items():
		if not only or k in only:
			fn()
