extends Node
# The sound of a match, like a TV football game: a full stadium that breathes with the play
# (a calm murmur, a rising buzz as an attack nears the box, songs and claps when it is quiet),
# reactions that grow out of it and settle back into it, and pitch sounds that never cut each
# other off. The sounds themselves are made by tools/make_sounds.py (files in snd/).

const VAR := {"dribble": 4, "touch": 4, "pass": 4, "shot": 4, "header": 2, "bounce": 3, "thud": 2, "slide": 2, "tackle": 2, "ooh": 3}
# name: [level dB, pitch spread, on the pitch (heard from where it happens)]
const DEF := {
	"dribble": [-1.0, 0.07, true], "touch": [4.5, 0.05, true], "pass": [5.7, 0.05, true], "shot": [9.4, 0.04, true],
	"header": [5.0, 0.05, true], "bounce": [0.0, 0.08, true], "catch": [9.0, 0.04, true], "post": [5.5, 0.015, true],
	"net": [7.5, 0.03, true], "thud": [3.5, 0.06, true], "slide": [5.0, 0.05, true], "tackle": [3.0, 0.05, true],
	"whistle": [-1.2, 0.01, false], "whistle_short": [-1.2, 0.01, false], "whistle_long": [-1.2, 0.0, false],
	"whistle_half": [-1.2, 0.0, false], "whistle_full": [-1.2, 0.0, false],
	"roar": [3.5, 0.0, false], "roar_away": [-1.7, 0.02, false], "ooh": [-1.5, 0.04, false], "aww": [-2.5, 0.04, false],
	"gasp": [-4.7, 0.05, false], "cheer": [-4.6, 0.04, false], "jeer": [-3.7, 0.04, false], "clap": [-4.1, 0.03, false],
	"clap_big": [-1.9, 0.0, false], "click": [-5.0, 0.03, false], "click2": [-3.0, 0.02, false], "whoosh": [-4.0, 0.03, false],
}
# the old names still used around the game
const ALIAS := {"kick": "pass", "win": "tackle", "blip": "click", "blip2": "click2"}

var streams := {}
var pool3: Array[AudioStreamPlayer3D] = []
var pool2: Array[AudioStreamPlayer] = []
var bed: AudioStreamPlayer
var hot: AudioStreamPlayer
var songs: Array[AudioStreamPlayer] = []
var later: Array = [] # [time, name, vol]
var t := 0.0

# what the match tells us every frame
var danger := 0.0 # 0 = ball in midfield, 1 = in the box with a chance on
var in_match := false
var paused := false
var home := 0 # the team most of the ground is behind
var derby := false # a derby in the career: the whole ground is louder

var _danger_s := 0.0
var _boost := 0.0 # after a goal the whole ground stays up and settles slowly
var _bed_l := 0.0
var _hot_l := 0.0
var _calm_t := 0.0
var _song := -1
var _song_t := 0.0
var _song_l := [0.0, 0.0]
var _song_to := 0.0
var _last := {}
var log_on := false

func _ready() -> void:
	log_on = OS.get_cmdline_user_args().has("--sndlog")
	for k in DEF:
		var n: int = VAR.get(k, 1)
		var arr := []
		for i in n:
			var f := "res://snd/%s%s.wav" % [k, str(i) if n > 1 else ""]
			var s = load(f)
			if s != null:
				arr.append(s)
		streams[k] = arr
	for i in 14:
		var p := AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		p.panning_strength = 0.7
		p.max_polyphony = 1
		add_child(p)
		pool3.append(p)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool2.append(p)
	bed = _loop("res://snd/crowd.wav")
	hot = _loop("res://snd/crowd_hot.wav")
	songs = [_loop("res://snd/chant.wav"), _loop("res://snd/claps.wav")]
	# nothing clips when the roar, the whistle and the bed all peak together
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.6
		AudioServer.add_bus_effect(0, lim)

func _loop(f: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s = load(f)
	# plain WAV (QOA), not Ogg: Ogg is decoded on the phone's main thread and made the sound crackle
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(round(s.get_length() * s.mix_rate))
	p.stream = s
	p.volume_db = -80.0
	add_child(p)
	return p

func _free3() -> AudioStreamPlayer3D:
	var best: AudioStreamPlayer3D = pool3[0]
	var bt := -1.0
	for p in pool3:
		if not p.playing:
			return p
		var pt := p.get_playback_position()
		if pt > bt:
			bt = pt
			best = p
	return best

func _free2() -> AudioStreamPlayer:
	var best: AudioStreamPlayer = pool2[0]
	var bt := -1.0
	for p in pool2:
		if not p.playing:
			return p
		var pt := p.get_playback_position()
		if pt > bt:
			bt = pt
			best = p
	return best

# Play one sound. vol 0..1 scales it, at = where on the pitch it happened (null = everywhere).
func play(k: String, vol := 1.0, at = null) -> void:
	k = ALIAS.get(k, k)
	if not DEF.has(k) or vol <= 0.01:
		return
	var arr: Array = streams.get(k, [])
	if arr.is_empty():
		return
	# the same sound twice in the same instant is one sound, a little louder
	var now := t
	if _last.has(k) and now - float(_last[k]) < 0.045:
		return
	_last[k] = now
	var d: Array = DEF[k]
	if log_on:
		print("SND %.2f %s %.2f" % [t, k, vol])
	var db: float = float(d[0]) + linear_to_db(clampf(vol, 0.0, 1.5))
	var pitch: float = 1.0 + randf_range(-1.0, 1.0) * float(d[1])
	var s = arr[randi() % arr.size()]
	if bool(d[2]) and at != null:
		var p := _free3()
		p.stream = s
		p.global_position = at
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			# farther from the camera = quieter and a little duller, as from the TV gantry
			var dist: float = cam.global_position.distance_to(at)
			db -= clampf((dist - 25.0) * 0.08, 0.0, 4.0)
		p.volume_db = db
		p.pitch_scale = pitch
		p.play()
	else:
		var p := _free2()
		p.stream = s
		p.volume_db = db
		p.pitch_scale = pitch
		p.play()

func play_in(sec: float, k: String, vol := 1.0) -> void:
	later.append([t + sec, k, vol])

# a goal: the home end explodes, or the away end does and the rest of the ground sighs
func goal(team: int) -> void:
	if team == home:
		play("roar")
		_boost = 1.0
		_song_to = t + 7.0 # then they sing
	else:
		play("roar_away")
		play_in(0.15, "aww", 0.9)
		_boost = 0.35
		_song_to = t + 30.0
	_stop_song()

func stop_all() -> void:
	for p in pool2:
		p.stop()
	for p in pool3:
		p.stop()
	later.clear()

func _stop_song() -> void:
	_song_t = 0.0

func _process(sdt: float) -> void:
	# real time: the goal's slow motion must not slow the crowd down
	var dt := sdt / maxf(Engine.time_scale, 0.05)
	t += dt
	for i in range(later.size() - 1, -1, -1):
		if t >= float(later[i][0]):
			play(str(later[i][1]), float(later[i][2]))
			later.remove_at(i)
	# the buzz rises quickly as the danger comes, and falls slowly after it
	var dk := 2.2 if danger > _danger_s else 0.6
	_danger_s = lerpf(_danger_s, danger, clampf(dt * dk, 0.0, 1.0))
	_boost = maxf(_boost - dt * 0.09, 0.0)
	var on := in_match and not paused
	var bed_to := 0.0
	var hot_to := 0.0
	if on:
		bed_to = 0.42 + 0.22 * (1.0 - _danger_s) + 0.45 * _boost
		hot_to = clampf(pow(_danger_s, 1.3) * 0.85 + _boost * 0.7, 0.0, 1.0)
	elif in_match:
		bed_to = 0.22 # paused: the ground is still there, further away
	else:
		bed_to = 0.0
	var fade := clampf(dt * (1.6 if on else 0.9), 0.0, 1.0)
	_bed_l = lerpf(_bed_l, bed_to, fade)
	_hot_l = lerpf(_hot_l, hot_to, fade)
	var dby := 3.0 if derby else 0.0
	_level(bed, _bed_l, 0.0 + dby)
	_level(hot, _hot_l, -2.0 + dby)
	if log_on and int(t * 2.0) != int((t - dt) * 2.0):
		print("CROWD %.1f danger=%.2f bed=%.2f hot=%.2f boost=%.2f song=%d/%.2f/%.2f" % [t, _danger_s, _bed_l, _hot_l, _boost, _song, _song_l[0], _song_l[1]])
	# songs: when the game is calm for a while, part of the ground starts singing or clapping
	if on and _danger_s < 0.3:
		_calm_t += dt
	else:
		_calm_t = maxf(_calm_t - dt * 2.0, 0.0)
	if on and _song_t <= 0.0 and ((_calm_t > 16.0 and t > _song_to) or (_song_to > 0.0 and t > _song_to and t < _song_to + 1.0 and _boost > 0.3)):
		_song = randi() % 2
		_song_t = randf_range(14.0, 26.0)
		_song_to = t + _song_t + randf_range(25.0, 50.0)
		var sp: AudioStreamPlayer = songs[_song]
		if not sp.playing:
			sp.play(0.0)
		_calm_t = 0.0
	if _song_t > 0.0:
		_song_t -= dt
		# a chance or a goal ends the singing at once
		if _danger_s > 0.6 or not on:
			_song_t = minf(_song_t, 0.0)
	for i in 2:
		var want := 1.0 if (i == _song and _song_t > 0.0) else 0.0
		_song_l[i] = lerpf(_song_l[i], want, clampf(dt * (0.55 if want > 0.0 else 0.9), 0.0, 1.0))
		_level(songs[i], _song_l[i], -4.0 if i == 0 else -2.0)

func _level(p: AudioStreamPlayer, l: float, top_db: float) -> void:
	if l < 0.003:
		if p.playing:
			p.stop()
		p.volume_db = -80.0
		return
	if not p.playing:
		if p == bed or p == hot:
			p.play(randf() * 10.0)
		else:
			p.play()
	p.volume_db = top_db + linear_to_db(l)
