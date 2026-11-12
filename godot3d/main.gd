extends Node3D
# Banebold 3D prototype: one 11v11 match, built entirely in code.
# x runs along the pitch (red attacks +x), z across it, y is up. Units are metres.

const PlayerS := preload("res://player.gd")
const HudS := preload("res://hud.gd")
const Sfx := preload("res://sfx.gd")
const World := preload("res://world.gd")

const HL := 52.5
const HW := 34.0
const GOAL_HW := 3.66
const GOAL_H := 2.44
const BALL_R := 0.2
const MATCH_REAL := 300.0 # real seconds for 90 minutes

const FORM := [ # 4-3-3: [role, along 0..1, across -1..1]
	["GK", 0.0, 0.0],
	["DF", 0.22, -0.78], ["DF", 0.17, -0.27], ["DF", 0.17, 0.27], ["DF", 0.22, 0.78],
	["MF", 0.42, -0.45], ["MF", 0.37, 0.0], ["MF", 0.42, 0.45],
	["FW", 0.68, -0.72], ["FW", 0.72, 0.0], ["FW", 0.68, 0.72],
]
const CAMS := ["TV", "TOP", "CLOSE"]

var players := []
var teams := [[], []]
var ball: Node3D
var ball_mesh: MeshInstance3D
var ball_vel := Vector3.ZERO
var ball_owner = null
var ball_last = null # last player to kick or hold it
var ball_ignore = null
var ignore_t := 0.0
var protect_t := 0.0
var shot_live := false
var set_piece := ""
var trail: CPUParticles3D

var ctrl = null
var human_team := 0
var switch_cool := 0.0
var charging := false
var charge := 0.0
var pass_hold := -1.0
var _keys := {}

var score := [0, 0]
var clock := 0.0
var half := 1
var state := "title"
var state_t := 0.0
var kick_team := 0
var dead_info := {}
var scorer = null

var cam: Camera3D
var cam_mode := 0
var cam_pos := Vector3(0, 40, 70)
var cam_look := Vector3.ZERO
var cam_fov := 38.0
var cam_focus := Vector3.ZERO
var cam_off := Vector3(0, 21, 31)
var follow_on := false
var shake := 0.0
var hud
var world
var au := {}
var crowd_au: AudioStreamPlayer
var crowd_vol := -14.0
var confetti: CPUParticles3D
var sparks := []
var dust: CPUParticles3D

var autotest := false
var demo := false
var shot_path := ""
var shot_at := 0.0
var force_goal := -1.0
var real_t := 0.0
var stats := {"shots": 0, "passes": 0, "tackles": 0, "outs": 0, "saves": 0}

func side(t: int) -> float:
	return 1.0 if t == 0 else -1.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			autotest = true
		elif a == "--demo":
			demo = true
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--at="):
			shot_at = float(a.substr(5))
		elif a.begins_with("--goal="):
			force_goal = float(a.substr(7))
		elif a.begins_with("--cam="):
			cam_mode = int(a.substr(6))
	world = World.new()
	add_child(world)
	world.build()
	_build_ball()
	_build_teams()
	cam = Camera3D.new()
	cam.fov = cam_fov
	cam.near = 0.5
	cam.far = 400.0
	add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudS.new()
	layer.add_child(hud)
	_build_fx()
	_build_audio()
	_formation(0, true)
	hud.show_controls = false
	if autotest or demo or shot_path != "":
		_start_match()
		if autotest:
			state = "play"
			_kickoff(0)
	else:
		hud.show_banner("BANEBOLD 3D", Color(1, 1, 1), 0.0, "Prototype  -  tap to kick off")

# ---------------------------------------------------------------- building

func _build_ball() -> void:
	ball = Node3D.new()
	add_child(ball)
	ball_mesh = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = BALL_R
	s.height = BALL_R * 2.0
	s.radial_segments = 16
	s.rings = 8
	ball_mesh.mesh = s
	var img := Image.create(64, 32, false, Image.FORMAT_RGB8)
	img.fill(Color(0.97, 0.97, 0.97))
	for y in 32:
		for x in 64:
			var cx := (x + (8 if (y / 8) % 2 == 1 else 0)) % 16
			var cy := y % 8
			if Vector2(cx - 8, (cy - 4) * 2.0).length() < 4.6:
				img.set_pixel(x, y, Color(0.08, 0.08, 0.1))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.5
	ball_mesh.material_override = m
	ball.add_child(ball_mesh)
	ball.position = Vector3(0, BALL_R, 0)
	trail = CPUParticles3D.new()
	trail.emitting = false
	trail.amount = 40
	trail.lifetime = 0.35
	trail.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.28, 0.28)
	trail.mesh = q
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	tm.vertex_color_use_as_albedo = true
	tm.albedo_color = Color(1, 1, 1, 0.7)
	trail.material_override = tm
	trail.gravity = Vector3.ZERO
	trail.spread = 0.0
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.75))
	g.set_color(1, Color(1, 1, 1, 0.0))
	trail.color_ramp = g
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0.2))
	trail.scale_amount_curve = sc
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.add_child(trail)

func _build_teams() -> void:
	var skins := [Color(0.96, 0.80, 0.66), Color(0.87, 0.67, 0.50), Color(0.62, 0.43, 0.29), Color(0.42, 0.28, 0.19), Color(0.93, 0.76, 0.60)]
	var hairs := [Color(0.1, 0.08, 0.06), Color(0.3, 0.19, 0.1), Color(0.75, 0.6, 0.3), Color(0.05, 0.05, 0.05), Color(0.5, 0.3, 0.15)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for t in 2:
		for i in FORM.size():
			var p = PlayerS.new()
			p.team = t
			p.idx = i
			p.role = FORM[i][0]
			p.home = Vector2(FORM[i][1], FORM[i][2])
			var shirt := Color(0.86, 0.14, 0.14) if t == 0 else Color(0.16, 0.38, 0.92)
			var shorts := Color(0.97, 0.97, 0.97) if t == 0 else Color(0.08, 0.14, 0.4)
			var socks := Color(0.86, 0.14, 0.14) if t == 0 else Color(0.97, 0.97, 0.97)
			if p.role == "GK":
				shirt = Color(0.98, 0.82, 0.12) if t == 0 else Color(0.2, 0.85, 0.45)
				shorts = Color(0.1, 0.1, 0.1)
				socks = shirt
			var boots: Color = [Color(0.08, 0.08, 0.08), Color(0.95, 0.95, 0.95), Color(1.0, 0.45, 0.1), Color(0.3, 0.9, 0.9)][rng.randi() % 4]
			p.build(shirt, shorts, socks, skins[rng.randi() % skins.size()], hairs[rng.randi() % hairs.size()], boots)
			p.top_speed = 7.3 + rng.randf() * 0.5 + (0.35 if p.role == "FW" else 0.0)
			add_child(p)
			players.append(p)
			teams[t].append(p)

func _build_fx() -> void:
	confetti = CPUParticles3D.new()
	confetti.emitting = false
	confetti.one_shot = true
	confetti.amount = 420
	confetti.lifetime = 5.0
	confetti.explosiveness = 0.85
	confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	confetti.emission_box_extents = Vector3(16, 1, 12)
	confetti.direction = Vector3(0, -1, 0)
	confetti.spread = 60.0
	confetti.initial_velocity_min = 0.5
	confetti.initial_velocity_max = 4.0
	confetti.gravity = Vector3(0, -3.2, 0)
	confetti.angular_velocity_min = -400.0
	confetti.angular_velocity_max = 400.0
	confetti.angle_max = 360.0
	var q := QuadMesh.new()
	q.size = Vector2(0.28, 0.16)
	confetti.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	confetti.material_override = m
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([Color(1, 0.85, 0.2), Color(1, 1, 1), Color(0.9, 0.2, 0.2), Color(0.3, 0.9, 0.5), Color(1, 0.85, 0.2)])
	confetti.color_initial_ramp = g
	confetti.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(confetti)
	for i in 4:
		var sp := CPUParticles3D.new()
		sp.emitting = false
		sp.one_shot = true
		sp.amount = 90
		sp.lifetime = 1.6
		sp.explosiveness = 0.95
		sp.direction = Vector3(0, 1, 0)
		sp.spread = 28.0
		sp.initial_velocity_min = 9.0
		sp.initial_velocity_max = 17.0
		sp.gravity = Vector3(0, -9.0, 0)
		var q2 := QuadMesh.new()
		q2.size = Vector2(0.22, 0.22)
		sp.mesh = q2
		var m2 := StandardMaterial3D.new()
		m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m2.vertex_color_use_as_albedo = true
		m2.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m2.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sp.material_override = m2
		var g2 := Gradient.new()
		g2.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
		g2.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
		sp.color_ramp = g2
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sp)
		sparks.append(sp)
	dust = CPUParticles3D.new()
	dust.emitting = false
	dust.one_shot = true
	dust.amount = 14
	dust.lifetime = 0.5
	dust.explosiveness = 1.0
	dust.direction = Vector3(0, 1, 0)
	dust.spread = 50.0
	dust.initial_velocity_min = 1.5
	dust.initial_velocity_max = 4.0
	dust.gravity = Vector3(0, -9.0, 0)
	var q3 := QuadMesh.new()
	q3.size = Vector2(0.12, 0.12)
	dust.mesh = q3
	var m3 := StandardMaterial3D.new()
	m3.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m3.albedo_color = Color(0.35, 0.62, 0.25)
	m3.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dust.material_override = m3
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)

func _build_audio() -> void:
	var defs := {
		"kick": Sfx.kick(1.0), "touch": Sfx.kick(0.45), "whistle": Sfx.whistle(0.5), "whistle_long": Sfx.whistle(1.1),
		"roar": Sfx.roar(), "ooh": Sfx.ooh(), "net": Sfx.net(), "blip": Sfx.blip(), "post": Sfx.post(),
	}
	for k in defs:
		var p := AudioStreamPlayer.new()
		p.stream = defs[k]
		add_child(p)
		au[k] = p
	au["roar"].volume_db = 2.0
	au["touch"].volume_db = -8.0
	crowd_au = AudioStreamPlayer.new()
	crowd_au.stream = Sfx.crowd()
	crowd_au.volume_db = -30.0
	add_child(crowd_au)

func snd(k: String) -> void:
	if autotest:
		return
	au[k].play()

# ---------------------------------------------------------------- match flow

func _start_match() -> void:
	score = [0, 0]
	clock = 0.0
	half = 1
	kick_team = 0
	hud.set_score(0, 0)
	hud.set_clock(0)
	hud.hide_banner()
	_formation(0, true)
	state = "intro"
	state_t = 0.0
	cam_pos = Vector3(-30, 46, 78)
	cam_look = Vector3(0, 0, 0)
	if not autotest:
		crowd_au.play()
		hud.show_banner("RED BISON  v  HARBOUR SHARKS", Color(1, 1, 1), 1.9)
		banner_small()

func banner_small() -> void:
	hud.banner.add_theme_font_size_override("font_size", 44)

func _formation(kicking: int, instant: bool) -> void:
	for p in players:
		var s := side(p.team)
		var u: float = -45.0 + p.home.x * 62.0
		if p.role == "GK":
			u = -HL + 1.5
		u = minf(u, -1.5)
		var pos := Vector3(u * s, 0, p.home.y * 28.0 * s)
		if p.role == "FW" and p.idx == 9 and p.team == kicking:
			pos = Vector3(-0.6 * s, 0, 0)
		if p.role == "MF" and p.idx == 6 and p.team == kicking:
			pos = Vector3(-7.0 * s, 0, 1.5)
		if instant:
			p.position = pos
			p.vel = Vector3.ZERO
			p.yaw = atan2(-s, 0.0)
		p.stun = 0.0
		p.recv = false
		p.mood = 0
		p.mood_t = 0.0
		p.dive_t = -1.0
		p.tackle_t = -1.0
		p.press_t = 0.0

func _kickoff(team: int) -> void:
	_formation(team, true)
	Engine.time_scale = 1.0
	ball.position = Vector3(0, BALL_R, 0)
	ball_vel = Vector3.ZERO
	var st = teams[team][9]
	ball_owner = st
	ball_last = st
	set_piece = "kick"
	st.ai_cool = 0.9
	protect_t = 1.5
	shot_live = false
	charging = false
	pass_hold = -1.0
	state = "play"
	state_t = 0.0
	if team == human_team:
		ctrl = st
	else:
		ctrl = teams[human_team][6]
	hud.show_controls = not (autotest or demo)
	snd("whistle")

func _goal(team: int) -> void:
	score[team] += 1
	state = "goal"
	state_t = 0.0
	kick_team = 1 - team
	scorer = ball_last if (ball_last != null and ball_last.team == team) else teams[team][9]
	for p in players:
		p.recv = false
		p.mood_t = 0.0
		if p == scorer:
			p.mood = 1
		elif p.team == team:
			p.mood = 2
		else:
			p.mood = 3
	charging = false
	pass_hold = -1.0
	shot_live = false
	if autotest:
		return
	Engine.time_scale = 0.3
	hud.set_score(score[0], score[1])
	hud.pop_score()
	hud.banner.add_theme_font_size_override("font_size", 110)
	hud.show_banner("GOAL!", Color(1.0, 0.86, 0.2), 2.2, "RED BISON" if team == 0 else "HARBOUR SHARKS")
	hud.do_flash(0.75)
	hud.show_controls = false
	shake = 1.0
	snd("net")
	snd("roar")
	world.set_excite(1.0)
	confetti.position = Vector3(ball.position.x * 0.72, 16, 0)
	confetti.restart()
	var gx := signf(ball.position.x) * (HL + 4.0)
	for i in sparks.size():
		sparks[i].position = Vector3(gx, 0.2, -9.0 + i * 6.0)
		sparks[i].restart()
	if Input.get_connected_joypads().size() == 0:
		Input.vibrate_handheld(180)

func _out(kind: String, pos: Vector3, team: int) -> void:
	state = "dead"
	state_t = 0.0
	dead_info = {"kind": kind, "pos": pos, "team": team}
	stats["outs"] += 1
	shot_live = false
	charging = false
	pass_hold = -1.0
	for p in players:
		p.recv = false

func _restart() -> void:
	var team: int = dead_info["team"]
	var pos: Vector3 = dead_info["pos"]
	var kind: String = dead_info["kind"]
	var taker = null
	if kind == "gk":
		taker = teams[team][0]
	else:
		var bd := 1e9
		for p in teams[team]:
			if p.role == "GK":
				continue
			var d: float = p.position.distance_to(pos)
			if d < bd:
				bd = d
				taker = p
	ball.position = Vector3(pos.x, BALL_R, pos.z)
	ball_vel = Vector3.ZERO
	var inward := Vector3(-pos.x, 0, -pos.z).normalized()
	taker.position = Vector3(pos.x, 0, pos.z) - inward * 0.6
	taker.vel = Vector3.ZERO
	taker.yaw = atan2(-inward.x, -inward.z)
	taker.stun = 0.0
	taker.hold_t = 0.0
	ball_owner = taker
	ball_last = taker
	set_piece = kind
	taker.ai_cool = 1.0
	protect_t = 2.5
	state = "play"
	state_t = 0.0
	if team == human_team and taker.role != "GK":
		ctrl = taker
	elif team != human_team:
		_auto_switch(true)

# ---------------------------------------------------------------- main loop

func _physics_process(dt: float) -> void:
	if autotest:
		for i in 30:
			_tick(1.0 / 60.0)
			if state == "full":
				print("AUTOTEST score=", score, " stats=", stats)
				get_tree().quit()
				return
	else:
		_tick(dt)

func _tick(dt: float) -> void:
	state_t += dt
	var evs: Array = hud.ev.duplicate()
	hud.ev.clear()
	_keys_to_events(evs)
	if evs.has("cam"):
		cam_mode = (cam_mode + 1) % CAMS.size()
		snd("blip")
	match state:
		"title":
			if evs.has("tap") or evs.has("shoot_down"):
				snd("blip")
				_start_match()
		"intro":
			if state_t > 2.6:
				hud.banner.add_theme_font_size_override("font_size", 96)
				_kickoff(kick_team)
		"play":
			_play(dt, evs)
		"goal":
			_celebrate(dt)
		"dead":
			_idle_players(dt)
			_ball_free(dt)
			if state_t > 0.9:
				_restart()
		"half":
			_idle_players(dt)
			if state_t > 3.0:
				_kickoff(1)
		"full":
			_idle_players(dt)
			if state_t > 2.5 and (evs.has("tap") or evs.has("shoot_down")):
				_start_match()

func _keys_to_events(evs: Array) -> void:
	var map := {KEY_SPACE: "shoot", KEY_X: "pass", KEY_E: "pass", KEY_C: "cam"}
	for k in map:
		var d := Input.is_physical_key_pressed(k)
		var was: bool = _keys.get(k, false)
		if d and not was:
			evs.append(map[k] + "_down" if map[k] != "cam" else "cam")
		elif was and not d and map[k] != "cam":
			evs.append(map[k] + "_up")
		_keys[k] = d

func _stick() -> Vector2:
	var v: Vector2 = hud.stick
	var k := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if k.length() > 0.1:
		v = k.normalized()
	return v.limit_length(1.0)

func _human() -> bool:
	return not (autotest or demo)

func _play(dt: float, evs: Array) -> void:
	clock += dt * 5400.0 / MATCH_REAL
	hud.set_clock(int(clock / 60.0))
	switch_cool -= dt
	ignore_t -= dt
	protect_t -= dt
	if force_goal >= 0.0 and state_t > force_goal:
		force_goal = -1.0
		ball_owner = null
		ball_last = teams[0][9]
		teams[0][9].position = Vector3(HL - 20, 0, 3)
		ball.position = Vector3(HL - 10, 0.5, 1.0)
		ball_vel = Vector3(26, 3.0, 4.0)
		ignore_t = 1.0
		ball_ignore = teams[1][0]
		teams[1][0].stun = 2.0
	var stick := _stick()
	var dir3 := Vector3(stick.x, 0, stick.y)
	var mine: bool = _human() and ctrl != null and ball_owner == ctrl
	# --- human buttons
	if _human() and ctrl != null:
		for e in evs:
			if e == "shoot_down":
				if mine:
					charging = true
					charge = 0.0
				else:
					_human_tackle()
			elif e == "shoot_up":
				if charging and mine:
					_shoot(ctrl, charge, _human_aim(dir3))
				charging = false
				charge = 0.0
			elif e == "pass_down":
				if mine:
					pass_hold = 0.0
				else:
					_switch()
			elif e == "pass_up":
				if pass_hold >= 0.0 and mine:
					var m = _pass_target(ctrl, dir3, false)
					if m != null:
						_pass(ctrl, m, pass_hold > 0.28)
				pass_hold = -1.0
		if charging:
			if not mine:
				charging = false
				charge = 0.0
			else:
				charge = minf(charge + dt / 0.75, 1.0)
				if charge >= 1.0:
					_shoot(ctrl, 1.0, _human_aim(dir3))
					charging = false
					charge = 0.0
		if pass_hold >= 0.0:
			pass_hold += dt
		hud.charge = charge
		var ours: bool = ball_owner != null and ball_owner.team == human_team
		hud.lab_a = "SHOOT" if ours else "TACKLE"
		hud.lab_b = "PASS" if ours else "SWITCH"
	# --- who chases
	var chaser := [null, null]
	var second := [null, null]
	var aim := _ball_meet_point()
	for t in 2:
		var b1 := 1e9
		var b2 := 1e9
		for p in teams[t]:
			if p.role == "GK" or p.stun > 0.0:
				continue
			var d: float = p.position.distance_to(aim)
			if d < b1:
				b2 = b1
				second[t] = chaser[t]
				b1 = d
				chaser[t] = p
			elif d < b2:
				b2 = d
				second[t] = p
	if _human() and ball_owner == null and chaser[human_team] != null and chaser[human_team] != ctrl and switch_cool <= 0.0:
		if ctrl == null or not ctrl.recv:
			var dc: float = ctrl.position.distance_to(aim) if ctrl != null else 1e9
			if chaser[human_team].position.distance_to(aim) + 3.0 < dc:
				ctrl = chaser[human_team]
				switch_cool = 0.8
	# --- move everyone
	for p in players:
		var want := Vector3.ZERO
		if p.stun > 0.0:
			p.stun -= dt
		elif p == ctrl and _human():
			if p.recv and ball_owner == null:
				want = _run_to(p, aim, p.top_speed)
			else:
				var sp: float = p.top_speed * (1.0 if hud.sprint_down or Input.is_physical_key_pressed(KEY_SHIFT) else 0.8)
				if ball_owner == p:
					sp *= 0.93
				if charging:
					sp *= 0.6
				want = dir3 * sp
		elif p == ball_owner:
			want = _ai_carrier(p, dt)
		elif p.role == "GK":
			want = _ai_keeper(p, dt)
		else:
			want = _ai_offball(p, chaser, second, aim)
		_move(p, want, dt)
	_separate()
	# --- ball
	if ball_owner != null:
		var o = ball_owner
		var f: Vector3 = o.fwd()
		var bob: float = 0.5 + 0.22 * absf(sin(o.phase * 0.5)) * clampf(o.vel.length() / 6.0, 0.0, 1.0)
		var tgt: Vector3 = o.position + f * bob + Vector3(0, BALL_R, 0)
		if o.role == "GK":
			tgt = o.position + f * 0.35 + Vector3(0, 1.15, 0)
		ball.position = ball.position.lerp(tgt, clampf(dt * 22.0, 0.0, 1.0))
		ball_vel = o.vel
		_spin_ball(o.vel, dt)
		ball_last = o
		_tackles(dt)
	else:
		_ball_free(dt)
		_pickups()
		_check_lines()
	trail.emitting = ball_owner == null and ball_vel.length() > 17.0
	# --- crowd gets louder near the goals
	var near := clampf((absf(ball.position.x) - 20.0) / 30.0, 0.0, 1.0)
	crowd_vol = lerpf(crowd_vol, -15.0 + near * 7.0, dt * 2.0)
	# --- clock
	if half == 1 and clock >= 2700.0 and ball_owner != null and absf(ball.position.x) < 30.0:
		half = 2
		clock = 2700.0
		state = "half"
		state_t = 0.0
		ball_owner = null
		ball_vel = Vector3.ZERO
		hud.show_controls = false
		snd("whistle_long")
		hud.show_banner("HALF TIME", Color(1, 1, 1), 2.2, "%d - %d" % [score[0], score[1]])
	elif half == 2 and clock >= 5400.0 and (ball_owner != null or autotest) and absf(ball.position.x) < 30.0:
		state = "full"
		state_t = 0.0
		ball_owner = null
		ball_vel = Vector3.ZERO
		hud.show_controls = false
		snd("whistle_long")
		var res := "DRAW"
		if score[0] > score[1]:
			res = "YOU WIN!"
		elif score[1] > score[0]:
			res = "YOU LOSE"
		hud.show_banner("FULL TIME  %d - %d" % [score[0], score[1]], Color(1, 1, 1), 0.0, res + "   -   tap to play again")
		hud.banner.add_theme_font_size_override("font_size", 64)
		for p in players:
			p.mood_t = 0.0
			p.mood = 0 if score[0] == score[1] else (2 if (score[p.team] > score[1 - p.team]) else 3)

func _idle_players(dt: float) -> void:
	for p in players:
		_move(p, Vector3.ZERO, dt)

func _move(p, want: Vector3, dt: float) -> void:
	var acc := 16.0 if want.length() > p.vel.length() else 22.0
	p.vel = p.vel.move_toward(want, acc * dt)
	p.position += p.vel * dt
	p.position.x = clampf(p.position.x, -HL - 2.5, HL + 2.5)
	p.position.z = clampf(p.position.z, -HW - 2.5, HW + 2.5)
	if p.role == "GK" and state == "play":
		p.face(ball.position - p.position, 10.0, dt)
	elif p.vel.length() > 0.6:
		p.face(p.vel, 11.0, dt)

func _run_to(p, target: Vector3, speed: float) -> Vector3:
	var d: Vector3 = target - p.position
	d.y = 0.0
	var l := d.length()
	if l < 0.15:
		return Vector3.ZERO
	return d / l * minf(speed, l * 4.0)

func _separate() -> void:
	for i in players.size():
		var a = players[i]
		for j in range(i + 1, players.size()):
			var b = players[j]
			var d: Vector3 = b.position - a.position
			d.y = 0.0
			var l := d.length()
			if l < 0.75 and l > 0.001:
				var push := d / l * (0.75 - l) * 0.5
				a.position -= push
				b.position += push

func _spin_ball(v: Vector3, dt: float) -> void:
	var h := Vector3(v.x, 0, v.z)
	var sp := h.length()
	if sp > 0.2:
		var axis := Vector3(h.z, 0, -h.x).normalized()
		ball_mesh.rotate(axis, sp / BALL_R * dt * 0.6)

func _ball_free(dt: float) -> void:
	ball_vel.y -= 9.8 * dt
	ball_vel *= 1.0 - 0.05 * dt
	ball.position += ball_vel * dt
	if ball.position.y <= BALL_R:
		ball.position.y = BALL_R
		if ball_vel.y < -1.6:
			ball_vel.y = -ball_vel.y * 0.52
			ball_vel.x *= 0.82
			ball_vel.z *= 0.82
			if ball_vel.y > 2.0:
				snd("touch")
		else:
			ball_vel.y = 0.0
		var h := Vector2(ball_vel.x, ball_vel.z)
		var sp := h.length()
		if sp > 0.0:
			var ns := maxf(sp - (1.5 + 0.35 * sp) * dt, 0.0)
			ball_vel.x *= ns / sp
			ball_vel.z *= ns / sp
	_spin_ball(ball_vel, dt)
	# inside a net: the net catches the ball
	if absf(ball.position.x) > HL and absf(ball.position.z) < GOAL_HW + 0.2 and ball.position.y < GOAL_H + 0.2 and state == "goal":
		var depth := absf(ball.position.x) - HL
		if depth > 1.7:
			ball.position.x = signf(ball.position.x) * (HL + 1.7)
			ball_vel.x *= -0.1
			ball_vel.z *= 0.3
			world.kick_net(ball.position.x > 0.0)
		if absf(ball.position.z) > GOAL_HW - BALL_R:
			ball.position.z = signf(ball.position.z) * (GOAL_HW - BALL_R)
			ball_vel.z *= -0.2
		ball_vel *= 1.0 - 3.0 * dt

func _ball_meet_point() -> Vector3:
	if ball_owner != null:
		return ball_owner.position
	var p := ball.position
	var v := Vector3(ball_vel.x, 0, ball_vel.z)
	var sp := v.length()
	if sp < 1.0:
		return Vector3(p.x, 0, p.z)
	# where the ball will roughly be in about 0.6 seconds
	var t := 0.6
	var travel := sp * t - 0.5 * (1.5 + 0.35 * sp) * t * t
	var out := p + v / sp * maxf(travel, 0.0)
	out.y = 0.0
	return out

# ---------------------------------------------------------------- kicking

func _release(p, v: Vector3) -> void:
	var h := Vector3(v.x, 0, v.z).normalized()
	p.yaw = atan2(-h.x, -h.z)
	p.start_kick()
	ball_owner = null
	ball.position = p.position + h * 0.75 + Vector3(0, BALL_R + 0.05, 0)
	ball_vel = v
	ball_last = p
	ball_ignore = p
	ignore_t = 0.3
	set_piece = ""
	p.hold_t = 0.0
	for q in players:
		q.recv = false

func _pass_target(p, dir3: Vector3, ai: bool):
	var best = null
	var bs := -1e9
	var s := side(p.team)
	var has_dir := dir3.length() > 0.25
	var dn := dir3.normalized() if has_dir else Vector3.ZERO
	for m in teams[p.team]:
		if m == p or m.stun > 0.0:
			continue
		var to: Vector3 = m.position - p.position
		var d := to.length()
		if d < 3.5 or d > 44.0:
			continue
		var n := to / d
		var sc := 0.0
		if has_dir:
			var a := dn.dot(n)
			if a < 0.3:
				continue
			sc += a * 5.0 - d * 0.02
		else:
			sc += n.x * s * 1.6 - absf(d - 15.0) * 0.04
		if m.role == "GK":
			sc -= 3.0
		var lane := 99.0
		var mark := 99.0
		for o in teams[1 - p.team]:
			var ap: Vector3 = o.position - p.position
			var tt := clampf(ap.dot(n), 0.0, d)
			lane = minf(lane, (ap - n * tt).length())
			mark = minf(mark, o.position.distance_to(m.position))
		if lane < 1.5:
			if ai:
				continue
			sc -= 2.5
		sc += minf(mark, 6.0) * 0.18
		if sc > bs:
			bs = sc
			best = m
	return best

func _pass(p, m, lofted: bool) -> void:
	var to: Vector3 = m.position - p.position
	to.y = 0.0
	var d := to.length()
	var v := Vector3.ZERO
	if not lofted:
		var sp := clampf(7.0 + d * 0.72, 10.0, 25.0)
		var aim: Vector3 = m.position + m.vel * (d / sp) * 0.8
		var dir: Vector3 = (aim - p.position)
		dir.y = 0.0
		v = dir.normalized() * sp + Vector3(0, 0.6, 0)
	else:
		var vh := clampf(9.0 + d * 0.36, 12.0, 23.0)
		var t := d / vh
		var aim2: Vector3 = m.position + m.vel * t * 0.7 + Vector3(side(p.team) * 2.0, 0, 0)
		var dir2: Vector3 = (aim2 - p.position)
		dir2.y = 0.0
		t = dir2.length() / vh
		v = dir2.normalized() * vh * 1.03 + Vector3(0, 4.9 * t, 0)
	_release(p, v)
	m.recv = true
	stats["passes"] += 1
	snd("kick" if lofted or d > 22.0 else "touch")
	if p.team == human_team and _human() and m.role != "GK":
		ctrl = m
		switch_cool = 0.5

func _human_aim(dir3: Vector3) -> float:
	var gk = teams[1 - human_team][0]
	if absf(dir3.z) > 0.3:
		return clampf(dir3.z * 1.3, -1.0, 1.0) * GOAL_HW * 0.82
	return (-1.0 if gk.position.z > 0.0 else 1.0) * GOAL_HW * 0.62

func _shoot(p, power: float, aim_z: float) -> void:
	var s := side(p.team)
	var from := ball.position
	var d := Vector2(HL * s - from.x, aim_z - from.z).length()
	var err := (randf() - 0.5) * (0.5 + d * 0.05 + power * 1.3)
	var goal := Vector3(HL * s, 0, aim_z + err)
	var dir := goal - from
	dir.y = 0.0
	dir = dir.normalized()
	var sp := 19.0 + 13.0 * power
	var t := maxf(d / sp, 0.15)
	var h := 0.35 + power * power * 2.3 + randf() * 0.7 * power
	var vy := (h - 0.25) / t + 4.9 * t
	_release(p, dir * sp + Vector3(0, vy, 0))
	shot_live = true
	stats["shots"] += 1
	shake = maxf(shake, 0.25 + 0.5 * power)
	snd("kick")
	if not autotest:
		dust.position = from
		dust.restart()
		Input.vibrate_handheld(40)

# ---------------------------------------------------------------- winning the ball

func _give(p) -> void:
	var prev = ball_last
	ball_owner = p
	ball_last = p
	shot_live = false
	p.hold_t = 0.0
	p.ai_cool = 0.35 + randf() * 0.3
	for q in players:
		q.recv = false
	charging = false
	pass_hold = -1.0
	if _human():
		if p.team == human_team:
			if p.role != "GK":
				ctrl = p
		elif prev == null or prev.team == human_team or switch_cool <= 0.0:
			_auto_switch(false)

func _auto_switch(force: bool) -> void:
	if not _human():
		return
	if switch_cool > 0.0 and not force:
		return
	var best = null
	var bd := 1e9
	var own_goal := Vector3(-HL * side(human_team), 0, 0)
	for p in teams[human_team]:
		if p.role == "GK":
			continue
		# prefer someone between the ball and our goal
		var d: float = p.position.distance_to(ball.position)
		if p.position.distance_to(own_goal) > ball.position.distance_to(own_goal) + 2.0:
			d += 8.0
		if d < bd:
			bd = d
			best = p
	if best != null:
		ctrl = best
		switch_cool = 0.7

func _switch() -> void:
	var cur = ctrl
	ctrl = null
	var best = null
	var bd := 1e9
	for p in teams[human_team]:
		if p.role == "GK" or p == cur:
			continue
		var d: float = p.position.distance_to(ball.position)
		if d < bd:
			bd = d
			best = p
	ctrl = best if best != null else cur
	switch_cool = 0.9
	snd("blip")

func _human_tackle() -> void:
	var c = ball_owner
	if ctrl.stun > 0.0 or ctrl.tackle_t >= 0.0:
		return
	ctrl.tackle_t = 0.0
	if c == null or c.team == human_team:
		ctrl.vel = ctrl.fwd() * 9.0
		ctrl.stun = 0.35
		return
	var to: Vector3 = c.position - ctrl.position
	var d := to.length()
	if d < 2.4:
		ctrl.yaw = atan2(-to.x, -to.z)
		ctrl.vel = to.normalized() * 9.5
	if d < 1.9 and protect_t <= 0.0 and c.role != "GK":
		var front: float = c.fwd().dot((ctrl.position - c.position).normalized())
		if front > -0.45:
			c.stun = 0.6
			stats["tackles"] += 1
			snd("touch")
			_give(ctrl)
			protect_t = 0.7
			return
	ctrl.stun = 0.55

func _tackles(dt: float) -> void:
	var c = ball_owner
	if c == null or c.role == "GK" or protect_t > 0.0:
		return
	for o in teams[1 - c.team]:
		if o.stun > 0.0 or (o == ctrl and _human()):
			continue
		var d: float = o.position.distance_to(c.position)
		if d < 1.3:
			o.press_t += dt
			var need := 0.4 if (o.team != human_team or not _human()) else 0.75
			if o.press_t > need:
				o.press_t = 0.0
				o.tackle_t = 0.0
				var front: float = c.fwd().dot((o.position - c.position).normalized())
				if front > -0.35:
					c.stun = 0.55
					stats["tackles"] += 1
					snd("touch")
					_give(o)
					protect_t = 0.7
					return
				else:
					o.stun = 0.75
		else:
			o.press_t = maxf(o.press_t - dt, 0.0)

func _pickups() -> void:
	var b := ball.position
	var hs := Vector2(ball_vel.x, ball_vel.z).length()
	# keepers: catch or parry
	for t in 2:
		var g = teams[t][0]
		if g.stun > 0.0 or (g == ball_ignore and ignore_t > 0.0):
			continue
		var gx := -HL * side(t)
		if absf(b.x - gx) > 17.0 or absf(b.z) > 20.5:
			continue
		var reach := 1.05 + (1.15 if g.dive_t >= 0.0 else 0.0)
		var dh := Vector2(b.x - g.position.x, b.z - g.position.z).length()
		if dh < reach and b.y < 2.7:
			if hs > 20.0 and dh > 0.75:
				# parry it away
				var sgn := signf(b.z - g.position.z)
				ball_vel = Vector3(-ball_vel.x * 0.3, absf(ball_vel.y) * 0.4 + 2.5, ball_vel.z * 0.4 + sgn * 5.0)
				ball_ignore = g
				ignore_t = 0.5
				ball_last = g
				shot_live = false
				stats["saves"] += 1
				snd("touch")
				snd("ooh")
				shake = maxf(shake, 0.3)
			else:
				if shot_live:
					stats["saves"] += 1
					snd("ooh")
				snd("touch")
				_give(g)
			return
	if b.y > 1.7:
		return
	var best = null
	var bd := 0.95
	for p in players:
		if p.stun > 0.0 or p.role == "GK":
			continue
		if p == ball_ignore and ignore_t > 0.0:
			continue
		var d := Vector2(b.x - p.position.x, b.z - p.position.z).length()
		if d < bd:
			bd = d
			best = p
	if best == null:
		return
	if hs > 24.0 and not best.recv:
		# too hard to control: it bounces off the player
		var n := Vector3(b.x - best.position.x, 0, b.z - best.position.z).normalized()
		ball_vel = ball_vel.bounce(n) * 0.35
		ball_ignore = best
		ignore_t = 0.4
		ball_last = best
		shot_live = false
		snd("touch")
		return
	if hs > 6.0:
		snd("touch")
	_give(best)

func _check_lines() -> void:
	var b := ball.position
	if absf(b.x) > HL:
		var sx := signf(b.x)
		var in_mouth := absf(b.z) < GOAL_HW and b.y < GOAL_H
		if absf(b.x) < HL + 0.6 and (absf(absf(b.z) - GOAL_HW) < 0.22 and b.y < GOAL_H + 0.2 or absf(b.z) < GOAL_HW and absf(b.y - GOAL_H) < 0.2) and ball_vel.x * sx > 0.0:
			# post or bar
			ball_vel.x *= -0.6
			ball_vel.z += (randf() - 0.5) * 4.0
			ball.position.x = sx * (HL - 0.05)
			shot_live = false
			snd("post")
			snd("ooh")
			shake = maxf(shake, 0.5)
			return
		if in_mouth:
			_goal(0 if sx > 0.0 else 1)
			return
		if absf(b.x) > HL + 0.4:
			var defending := 0 if sx < 0.0 else 1
			if shot_live:
				snd("ooh")
			if ball_last != null and ball_last.team == defending:
				_out("corner", Vector3(sx * (HL - 0.6), 0, signf(b.z) * (HW - 0.6)), 1 - defending)
			else:
				_out("gk", Vector3(sx * (HL - 5.5), 0, 0), defending)
			return
	if absf(b.z) > HW + 0.3:
		var t: int = 1 - (ball_last.team if ball_last != null else 0)
		_out("throw", Vector3(clampf(b.x, -HL + 1.0, HL - 1.0), 0, signf(b.z) * (HW - 0.3)), t)

# ---------------------------------------------------------------- AI

func _ai_carrier(p, dt: float) -> Vector3:
	var s := side(p.team)
	if p.role == "GK":
		p.hold_t += dt
		if p.hold_t > 1.1:
			var m = _pass_target(p, Vector3.ZERO, true)
			if m == null:
				m = teams[p.team][1 + randi() % 4]
			_pass(p, m, p.position.distance_to(m.position) > 22.0)
		return Vector3.ZERO
	p.ai_cool -= dt
	var goal := Vector3(HL * s, 0, 0)
	var to_goal: Vector3 = goal - p.position
	var dist := to_goal.length()
	var nd := 99.0
	var near = null
	for o in teams[1 - p.team]:
		var d: float = o.position.distance_to(p.position)
		if d < nd:
			nd = d
			near = o
	if set_piece != "":
		if p.ai_cool <= 0.0:
			var m2 = _pass_target(p, Vector3.ZERO, set_piece != "corner")
			if m2 == null:
				m2 = teams[p.team][6]
			_pass(p, m2, set_piece == "corner" or set_piece == "gk")
		return Vector3.ZERO
	if p.ai_cool <= 0.0:
		p.ai_cool = 0.3 + randf() * 0.25
		var angle_ok := absf(p.position.z) < 9.0 + (HL - absf(p.position.x)) * 0.75
		if dist < 25.0 and angle_ok and (nd > 1.8 or dist < 13.0):
			if dist < 17.0 or randf() < 0.3:
				var gk = teams[1 - p.team][0]
				var az := (-1.0 if gk.position.z > 0.0 else 1.0) * GOAL_HW * (0.5 + randf() * 0.35)
				_shoot(p, 0.45 + randf() * 0.45, az)
				return Vector3.ZERO
		var pressured := nd < 3.2
		if pressured or randf() < 0.22:
			var m3 = _pass_target(p, Vector3.ZERO, true)
			if m3 != null:
				var gain: float = (m3.position.x - p.position.x) * s
				if pressured and gain > -14.0 or gain > 6.0:
					_pass(p, m3, false)
					return Vector3.ZERO
	# dribble: towards goal, steering away from the nearest defender
	var dir := to_goal.normalized()
	if dist > 30.0:
		dir = Vector3(s, 0, clampf(-p.position.z * 0.01, -0.3, 0.3)).normalized()
	if near != null and nd < 5.0:
		var away: Vector3 = (p.position - near.position).normalized()
		var side_step := Vector3(-dir.z, 0, dir.x)
		if side_step.dot(away) < 0.0:
			side_step = -side_step
		dir = (dir + side_step * (1.0 - nd / 5.0) * 1.3).normalized()
	if absf(p.position.z) > HW - 3.0 and signf(dir.z) == signf(p.position.z):
		dir.z *= -0.5
	return dir.normalized() * p.top_speed * 0.9

func _ai_offball(p, chaser: Array, second: Array, aim: Vector3) -> Vector3:
	var t: int = p.team
	var s := side(t)
	var loose: bool = ball_owner == null
	var ours: bool = not loose and ball_owner.team == t
	if p.recv and loose:
		return _run_to(p, aim, p.top_speed)
	if loose and p == chaser[t]:
		return _run_to(p, aim, p.top_speed)
	if not loose and not ours:
		var c = ball_owner
		var own_goal := Vector3(-HL * s, 0, 0)
		var goal_side: Vector3 = (own_goal - c.position).normalized()
		if p == chaser[t]:
			if t == human_team and _human():
				# your team mate holds the runner up; you make the tackle
				return _run_to(p, c.position + goal_side * 2.6, p.top_speed * 0.95)
			return _run_to(p, c.position + c.vel * 0.25 + goal_side * 0.5, p.top_speed * 0.97)
		if p == second[t]:
			return _run_to(p, c.position + goal_side * 6.0, p.top_speed * 0.9)
	# formation spot, sliding with the ball
	var bu: float = ball.position.x * s
	var u: float = -45.0 + p.home.x * 62.0 + bu * 0.6 + (9.0 if ours else 0.0)
	if p.role == "FW" and ours:
		u += 4.0 + 3.0 * sin(clock * 0.02 + p.idx * 2.0)
	if p.role == "DF":
		u = clampf(u, -46.0, 14.0)
	else:
		u = clampf(u, -40.0, 47.0)
	var z: float = p.home.y * s * (29.0 if ours else 21.0) + ball.position.z * (0.25 if ours else 0.42)
	z = clampf(z, -HW + 1.5, HW - 1.5)
	var target := Vector3(u * s, 0, z)
	return _run_to(p, target, p.top_speed * 0.88)

func _ai_keeper(p, dt: float) -> Vector3:
	var s := side(p.team)
	var gx := -HL * s
	var goal := Vector3(gx, 0, 0)
	var b := ball.position
	if ball_owner == null and ball_vel.x * -s > 5.0:
		var t := (gx - b.x) / ball_vel.x
		if t > 0.0 and t < 1.7:
			var zc := b.z + ball_vel.z * t
			if absf(zc) < GOAL_HW + 1.2:
				p.react_t += dt
				if p.react_t < 0.2:
					return p.vel * 0.5
				var target := Vector3(gx + s * 0.7, 0, clampf(zc, -GOAL_HW + 0.2, GOAL_HW - 0.2))
				var dz: float = target.z - p.position.z
				if absf(dz) > 1.2 and t < 0.5 and p.dive_t < 0.0:
					p.dive_t = 0.0
					var right := Vector3(cos(p.yaw), 0, -sin(p.yaw))
					p.dive_side = signf(Vector3(0, 0, dz).dot(right))
				var sp := 9.5 if p.dive_t >= 0.0 else 5.8
				return _run_to(p, target, sp)
	p.react_t = 0.0
	if ball_owner == null and absf(b.x - gx) < 15.0 and absf(b.z) < 18.0 and ball_vel.length() < 12.0:
		var mine: float = p.position.distance_to(b)
		var theirs := 99.0
		for o in teams[1 - p.team]:
			theirs = minf(theirs, o.position.distance_to(b))
		if mine < theirs + 1.0:
			return _run_to(p, Vector3(b.x, 0, b.z), p.top_speed)
	var d := b - goal
	d.y = 0.0
	var dist := d.length()
	var out := clampf(dist * 0.11, 1.0, 5.0)
	var target2 := goal + d.normalized() * out
	target2.z = clampf(target2.z, -3.3, 3.3)
	return _run_to(p, target2, 5.0)

# ---------------------------------------------------------------- goal celebration

func _celebrate(dt: float) -> void:
	if not autotest and state_t > 0.5 and Engine.time_scale < 1.0:
		Engine.time_scale = 1.0
	_ball_free(dt)
	var s := side(scorer.team)
	var corner := Vector3(s * (HL - 9.0), 0, (1.0 if scorer.position.z >= 0.0 else -1.0) * (HW - 7.0))
	for p in players:
		var want := Vector3.ZERO
		if p == scorer:
			if state_t < 2.6 and p.position.distance_to(corner) > 1.0:
				want = _run_to(p, corner, 7.5)
		elif p.mood == 2:
			if p.role != "GK" and p.position.distance_to(scorer.position) > 2.6:
				want = _run_to(p, scorer.position, 6.5)
		else:
			if p.role != "GK" and state_t > 2.0:
				var u: float = -45.0 + p.home.x * 62.0
				want = _run_to(p, Vector3(minf(u, -1.5) * side(p.team), 0, p.home.y * 28.0 * side(p.team)), 2.2)
		_move(p, want, dt)
	_separate()
	if state_t > (0.2 if autotest else 5.2):
		world.set_excite(0.0)
		_kickoff(kick_team)

# ---------------------------------------------------------------- camera, visuals

func _process(dt: float) -> void:
	real_t += dt
	var rdt := dt / maxf(Engine.time_scale, 0.05)
	for p in players:
		p.animate(dt)
		p.ring.visible = p == ctrl and state == "play" and _human()
	hud.cam_name = CAMS[cam_mode]
	crowd_au.volume_db = lerpf(crowd_au.volume_db, crowd_vol if state != "title" else -40.0, clampf(rdt * 3.0, 0.0, 1.0))
	_camera(rdt)
	if shot_path != "" and real_t >= shot_at:
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("saved ", shot_path, " state=", state, " score=", score)
		shot_path = ""
		get_tree().quit()

func _camera(dt: float) -> void:
	var f := ball.position
	var want_pos := Vector3.ZERO
	var want_look := Vector3.ZERO
	var want_fov := 38.0
	var k := 3.2
	if state == "title":
		var a := real_t * 0.12
		want_pos = Vector3(sin(a) * 78.0, 26.0, cos(a) * 62.0)
		want_look = Vector3(0, 0, 0)
		want_fov = 42.0
		k = 5.0
	elif state == "intro":
		want_look = Vector3(0, 0, 0)
		want_pos = Vector3(0, 21, 31)
		want_fov = 27.0
		k = 1.6
	elif state == "goal" and state_t > 0.5:
		var a2 := state_t * 0.55 + 0.6
		var c: Vector3 = scorer.position + Vector3(0, 1.3, 0)
		want_look = c
		want_pos = c + Vector3(sin(a2) * 7.5 * -signf(scorer.position.x), 1.6 + state_t * 0.25, cos(a2) * 7.5)
		want_fov = 44.0
		k = 2.4
	elif state == "goal":
		want_look = Vector3(f.x, 1.0, f.z)
		want_pos = Vector3(f.x - signf(f.x) * 14.0, 5.0, f.z + 12.0)
		want_fov = 34.0
		k = 4.0
	else:
		var off := Vector3(0, 21.0, 31.0)
		var fx := clampf(f.x, -HL + 8.0, HL - 8.0)
		var foc := Vector3(fx, 0, f.z * 0.6)
		want_fov = 27.0
		if cam_mode == 1:
			off = Vector3(0, 38.0, 5.0)
			foc = Vector3(clampf(f.x, -HL + 14.0, HL - 14.0), 0, clampf(f.z, -20.0, 20.0))
			want_fov = 30.0
		elif cam_mode == 2:
			off = Vector3(0, 9.0, 14.5)
			foc = Vector3(f.x, 0.5, f.z)
			want_fov = 40.0
		# one smoothed focus point, so the camera never twists when the ball moves fast
		if not follow_on:
			follow_on = true
			cam_focus = cam_look
			cam_off = cam_pos - cam_look
		cam_focus = cam_focus.lerp(foc, clampf(dt * 4.0, 0.0, 1.0))
		cam_off = cam_off.lerp(off, clampf(dt * 2.5, 0.0, 1.0))
		cam_pos = cam_focus + cam_off
		cam_look = cam_focus
		cam_fov = lerpf(cam_fov, want_fov, clampf(dt * 2.5, 0.0, 1.0))
		k = -1.0
	if k > 0.0:
		follow_on = false
		var a3 := clampf(dt * k, 0.0, 1.0)
		cam_pos = cam_pos.lerp(want_pos, a3)
		cam_look = cam_look.lerp(want_look, a3)
		cam_fov = lerpf(cam_fov, want_fov, a3)
	shake = maxf(shake - dt * 2.2, 0.0)
	var off := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * shake * 0.7
	cam.fov = cam_fov
	cam.look_at_from_position(cam_pos + off, cam_look, Vector3.UP)
