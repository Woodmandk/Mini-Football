extends Node3D
# Banebold 3D prototype: one 11v11 match, built entirely in code.
# x runs along the pitch (red attacks +x), z across it, y is up. Units are metres.

const PlayerS := preload("res://player.gd")
const HudS := preload("res://hud.gd")
const Sfx := preload("res://sfx.gd")
const World := preload("res://world.gd")
const NetS := preload("res://net.gd")

const HL := 52.5
const HW := 34.0
const GOAL_HW := 3.66
const GOAL_H := 2.44
const BALL_R := 0.2
const LENGTHS := [180.0, 300.0, 480.0] # real seconds for 90 minutes
const LEN_NAMES := ["3 MIN", "5 MIN", "8 MIN"]
const DIFF_NAMES := ["EASY", "NORMAL", "HARD"]
const DIFF := [
	{"need": 0.80, "spd": 0.91, "err": 1.8, "think": 0.55},
	{"need": 0.60, "spd": 0.96, "err": 1.0, "think": 0.32},
	{"need": 0.45, "spd": 1.0, "err": 0.6, "think": 0.22},
]
const FORM := [ # 4-3-3: [role, along 0..1, across -1..1]
	["GK", 0.0, 0.0],
	["DF", 0.22, -0.78], ["DF", 0.17, -0.27], ["DF", 0.17, 0.27], ["DF", 0.22, 0.78],
	["MF", 0.42, -0.45], ["MF", 0.37, 0.0], ["MF", 0.42, 0.45],
	["FW", 0.68, -0.72], ["FW", 0.72, 0.0], ["FW", 0.68, 0.72],
]
const NAMES := [
	["Holm", "Berg", "Lund", "Dahl", "Krogh", "Skov", "Winther", "Bak", "Friis", "Storm", "Juhl"],
	["Marsh", "Reed", "Cole", "Hale", "Frost", "Quinn", "Drake", "Nash", "Voss", "Pike", "Lowe"],
]
const NUMS := [1, 3, 4, 5, 2, 8, 6, 10, 11, 9, 7]
const TEAM_NAMES := ["RED BISON", "HARBOUR SHARKS"]
const CAMS := ["TV", "TOP", "CLOSE"]
const N_F := 10 # numbers per player in a packed frame

class Human:
	var team := 0
	var ctrl = null
	var stick := Vector2.ZERO
	var sprint := false
	var evs := []
	var charging := false
	var charge := 0.0
	var pass_hold := -1.0
	var switch_cool := 0.0
	var local := true

var players := []
var teams := [[], []]
var humans := []
var me := 0
var view_flip := 1.0

var ball: Node3D
var ball_mesh: MeshInstance3D
var ball_vel := Vector3.ZERO
var ball_owner = null
var ball_last = null
var ball_ignore = null
var ignore_t := 0.0
var protect_t := 0.0
var shot_live := false
var set_piece := ""
var pen_wait := false
var off_spot := Vector3.ZERO
var off_line := [0.0, 0.0]
var trail: CPUParticles3D
var land_ring: MeshInstance3D
var ball_net := Vector3.ZERO

var score := [0, 0]
var clock := 0.0
var half := 1
var screen := "menu"
var state := "play"
var state_t := 0.0
var kick_team := 0
var dead_info := {}
var scorer = null
var paused := false
var opt_diff := 1
var opt_len := 1
var opt_mode := "coop"
var room := ""
var tick_n := 0
var _keys := {}

var rec := []
var goal_idx := 0
var rp_pos := 0.0
var rp_to := 0
var anim_rate := 1.0

var cam: Camera3D
var cam_mode := 0
var cam_pos := Vector3(0, 40, 70)
var cam_look := Vector3.ZERO
var cam_fov := 38.0
var cam_focus := Vector3.ZERO
var cam_off := Vector3(0, 21, 31)
var follow_on := false
var shake := 0.0
var fov_punch := 0.0
var hud
var world
var net
var au := {}
var crowd_au: AudioStreamPlayer
var crowd_vol := -14.0
var confetti: CPUParticles3D
var sparks := []
var dust: CPUParticles3D
var out_ev := []
var snap = null
var snap_new := false

var autotest := false
var dbg := false
var seen_how := false
var how_next := ""
var bot_mode := ""
var bot_t := {}
var bstats := {"have": 0, "shots": 0, "passes": 0, "tackles": 0, "switches": 0}
var quality := 2
var slow_t := 0.0
var q_applied := -1
var demo := false
var shot_path := ""
var shot_at := 0.0
var force_goal := -1.0
var real_t := 0.0
var version := "dev"
var stats := {"shots": 0, "passes": 0, "tackles": 0, "outs": 0, "saves": 0, "goals": 0, "fouls": 0, "offsides": 0, "pens": 0, "cards": 0}

func side(t: int) -> float:
	return 1.0 if t == 0 else -1.0

func _ready() -> void:
	var menu_arg := ""
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
		elif a.begins_with("--menu="):
			menu_arg = a.substr(7)
		elif a.begins_with("--bot="):
			bot_mode = a.substr(6)
		elif a.begins_with("--diff="):
			opt_diff = int(a.substr(7))
	if FileAccess.file_exists("res://version.txt"):
		version = FileAccess.get_file_as_string("res://version.txt").strip_edges()
	net = NetS.new()
	if net.web:
		dbg = str(JavaScriptBridge.eval("location.search", true)).contains("dbg")
		if str(JavaScriptBridge.eval("location.search", true)).contains("low"):
			quality = 0
		seen_how = str(JavaScriptBridge.eval("(function(){try{return localStorage.getItem('bb3d-how')||''}catch(e){return ''}})()", true)) == "1"
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
	hud.on_action = _action
	layer.add_child(hud)
	_build_fx()
	_build_audio()
	if autotest or demo:
		screen = "match"
		_begin_match(false)
		if autotest:
			if bot_mode != "":
				humans = [Human.new()]
				if bot_mode != "solo":
					var h2 := Human.new()
					h2.team = 0 if bot_mode == "coop" else 1
					humans.append(h2)
			_kickoff(0)
	else:
		_to_menu()
		if menu_arg != "":
			hud.show_menu(menu_arg, _menu_info())
		else:
			var jc: String = net.join_code()
			if jc.length() == 4:
				_action("code", jc)

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
	# where a high ball will land
	land_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.55
	t.outer_radius = 0.68
	t.rings = 20
	t.ring_segments = 3
	land_ring.mesh = t
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1, 1, 1, 0.8)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	land_ring.material_override = lm
	land_ring.scale = Vector3(1, 0.05, 1)
	land_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	land_ring.visible = false
	add_child(land_ring)

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
			p.pname = NAMES[t][i]
			p.num = NUMS[i]
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
		"blip2": Sfx.blip(1320.0), "whoosh": Sfx.whoosh(),
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

# ---------------------------------------------------------------- effects (also sent to the guest online)

func _quiet() -> bool:
	return autotest or screen == "menu"

func fx(kind: String, a = null) -> void:
	if _quiet():
		return
	if net.role == "host":
		out_ev.append([kind, a])
	_do_fx(kind, a)

func snd(k: String) -> void:
	fx("snd", k)

func _do_fx(kind: String, a) -> void:
	match kind:
		"snd":
			au[a].play()
		"banner":
			hud.show_banner(a[0], Color(a[1]), a[2], a[3], int(a[4]))
		"flash":
			hud.do_flash(a)
		"shake":
			shake = maxf(shake, a)
		"punch":
			fov_punch = maxf(fov_punch, a)
		"pop":
			hud.pop_score()
		"excite":
			world.set_excite(a)
		"net":
			world.kick_net(a > 0.0)
		"confetti":
			confetti.position = Vector3(a, 16, 0)
			confetti.restart()
			var gx := signf(a) * (HL + 4.0)
			for i in sparks.size():
				sparks[i].position = Vector3(gx, 0.2, -9.0 + i * 6.0)
				sparks[i].restart()
		"dust":
			dust.position = Vector3(a[0], 0.1, a[1])
			dust.restart()
		"vib":
			Input.vibrate_handheld(int(a))
		"say":
			net.say(a)
		"toast":
			hud.toast(a)

func _banner(text: String, col: Color, hold: float, small := "", fs := 96) -> void:
	fx("banner", [text, col.to_html(), hold, small, fs])

# ---------------------------------------------------------------- menu and online lobby

func _menu_info() -> Dictionary:
	return {
		"diff": DIFF_NAMES[opt_diff], "len": LEN_NAMES[opt_len], "mode": opt_mode, "code": room,
		"connected": net.connected, "role": net.role, "version": version, "web": net.web,
		"score": "%d - %d" % [score[0], score[1]], "online": net.role != "", "result": _result(),
	}

func _result() -> String:
	if score[0] == score[1]:
		return "DRAW"
	var t: int = humans[me].team if humans.size() > me else 0
	var both: bool = humans.size() > 1 and humans[0].team == humans[1].team
	if score[t] > score[1 - t]:
		return "YOU WIN TOGETHER!" if both else "YOU WIN!"
	return "YOU LOSE"

func _to_menu() -> void:
	net.stop()
	Engine.time_scale = 1.0
	paused = false
	screen = "menu"
	humans = []
	me = 0
	view_flip = 1.0
	room = ""
	hud.show_controls = false
	hud.replay_on = false
	hud.hide_banner()
	world.set_excite(0.0)
	score = [0, 0]
	clock = 0.0
	half = 1
	for p in players:
		p.off = false
		p.yellow = 0
		p.visible = true
	_kickoff(0)
	if not crowd_au.playing:
		crowd_au.play()
	hud.show_menu("main", _menu_info())

func _action(act: String, arg = null) -> void:
	au["blip2" if act in ["play", "start", "again"] else "blip"].play()
	if act == "key":
		return
	if act in ["play", "friend"] and not seen_how:
		how_next = act
		hud.show_menu("how", _menu_info())
		return
	match act:
		"how_ok":
			seen_how = true
			if net.web:
				JavaScriptBridge.eval("try{localStorage.setItem('bb3d-how','1')}catch(e){}", true)
			_action(how_next if how_next != "" else "play")
		"play":
			humans = [Human.new()]
			me = 0
			view_flip = 1.0
			screen = "match"
			hud.show_menu("", {})
			_begin_match(true)
		"friend":
			hud.show_menu("friend", _menu_info())
		"host":
			room = "%04d" % (randi() % 9000 + 1000)
			net.host(room)
			hud.show_menu("lobby", _menu_info())
		"joinmenu":
			hud.show_menu("join", _menu_info())
		"code":
			room = str(arg)
			net.join(room)
			hud.show_menu("lobby", _menu_info())
		"mode":
			opt_mode = "versus" if opt_mode == "coop" else "coop"
			_send_lobby()
			hud.show_menu("lobby", _menu_info())
		"diff":
			opt_diff = (opt_diff + 1) % 3
			_send_lobby()
			hud.refresh(_menu_info())
		"len":
			opt_len = (opt_len + 1) % 3
			_send_lobby()
			hud.refresh(_menu_info())
		"share":
			var r: String = net.share(room)
			if r == "copied":
				hud.toast("Link copied")
		"start":
			if net.role == "host" and net.connected:
				_host_start()
		"again":
			if net.role == "host":
				if net.connected:
					_host_start()
				else:
					_to_menu()
			elif net.role == "":
				_action("play")
		"back", "menu":
			_to_menu()
		"pause":
			if screen == "match" and state != "full":
				if net.role == "":
					paused = true
				hud.show_menu("pause", _menu_info())
		"resume":
			paused = false
			hud.show_menu("", {})
		"cam":
			cam_mode = (cam_mode + 1) % CAMS.size()

func _send_lobby() -> void:
	if net.role == "host" and net.connected:
		net.send({"_": "lobby", "mode": opt_mode, "diff": opt_diff, "len": opt_len})

func _host_start() -> void:
	var h0 := Human.new()
	var h1 := Human.new()
	h1.local = false
	h1.team = 0 if opt_mode == "coop" else 1
	humans = [h0, h1]
	me = 0
	view_flip = 1.0
	screen = "match"
	hud.show_menu("", {})
	net.send({"_": "start", "mode": opt_mode, "diff": opt_diff, "len": opt_len})
	_begin_match(true)

func _guest_start(m: Dictionary) -> void:
	opt_mode = m.get("mode", "coop")
	var h0 := Human.new()
	h0.local = false
	var h1 := Human.new()
	h1.team = 0 if opt_mode == "coop" else 1
	humans = [h0, h1]
	me = 1
	view_flip = 1.0 if h1.team == 0 else -1.0
	screen = "match"
	state = "intro"
	state_t = 0.0
	snap = null
	hud.show_menu("", {})
	hud.hide_banner()
	follow_on = false
	cam_pos = Vector3(-30, 46, 78 * view_flip)
	cam_look = Vector3.ZERO

func _net_poll() -> void:
	for m in net.poll():
		if not (m is Dictionary):
			continue
		var k: String = str(m.get("_", ""))
		match k:
			"ready":
				hud.refresh(_menu_info())
			"open":
				net.connected = true
				if net.role == "host":
					_send_lobby()
				if screen == "menu":
					hud.show_menu("lobby", _menu_info())
					au["blip2"].play()
			"lobby":
				opt_mode = m.get("mode", "coop")
				opt_diff = int(m.get("diff", 1))
				opt_len = int(m.get("len", 1))
				if screen == "menu":
					hud.show_menu("lobby", _menu_info())
			"start":
				if net.role == "guest":
					_guest_start(m)
			"s":
				if net.role == "guest" and screen == "match":
					snap = m
					snap_new = true
					for e in m.get("e", []):
						_do_fx(str(e[0]), e[1])
			"i":
				if net.role == "host" and humans.size() > 1:
					var h = humans[1]
					var s: Array = m.get("s", [0, 0])
					h.stick = Vector2(float(s[0]), float(s[1]))
					h.sprint = bool(m.get("sp", false))
					for e in m.get("e", []):
						h.evs.append(str(e))
			"close":
				net.connected = false
				if net.role == "guest":
					_to_menu()
					hud.toast("The host left the match")
				elif screen == "match":
					if humans.size() > 1:
						humans.remove_at(1)
					hud.toast("Your friend left - playing on against the computer")
				else:
					hud.show_menu("lobby", _menu_info())
			"err":
				var em: String = str(m.get("m", ""))
				if net.role == "guest" and not net.connected:
					_to_menu()
					hud.toast("Could not find that room" if em == "peer-unavailable" else "Connection problem (%s)" % em)
				elif net.role == "host" and em == "unavailable-id":
					_action("host")

# ---------------------------------------------------------------- match flow

func _begin_match(with_intro: bool) -> void:
	score = [0, 0]
	clock = 0.0
	half = 1
	kick_team = 0
	rec.clear()
	hud.set_score(0, 0)
	hud.set_clock(0)
	hud.hide_banner()
	hud.replay_on = false
	for p in players:
		p.off = false
		p.yellow = 0
		p.visible = true
	_formation(0, true)
	ball_owner = null
	ball.position = Vector3(0, BALL_R, 0)
	ball_vel = Vector3.ZERO
	state = "intro"
	state_t = 0.0
	follow_on = false
	cam_pos = Vector3(-30, 46, 78)
	cam_look = Vector3(0, 0, 0)
	hud.show_controls = false
	if not autotest:
		if not crowd_au.playing:
			crowd_au.play()
		if with_intro:
			_banner("RED BISON  v  HARBOUR SHARKS", Color(1, 1, 1), 1.9, "", 44)
			snd("whoosh")

func _formation(kicking: int, instant: bool) -> void:
	for p in players:
		var s := side(p.team)
		var u: float = -45.0 + p.home.x * 62.0
		if p.role == "GK":
			u = -HL + 1.5
		u = minf(u, -1.5)
		var pos := Vector3(u * s, 0, p.home.y * 28.0 * s)
		if p.idx == 9 and p.team == kicking:
			pos = Vector3(-0.6 * s, 0, 0)
		if p.idx == 6 and p.team == kicking:
			pos = Vector3(-7.0 * s, 0, 1.5)
		if instant:
			p.position = pos
			p.vel = Vector3.ZERO
			p.yaw = atan2(-s, 0.0)
		p.stun = 0.0
		p.recv = false
		p.offside = false
		p.commit_t = -1.0
		p.mood = 0
		p.mood_t = 0.0
		p.dive_t = -1.0
		p.tackle_t = -1.0
		p.press_t = 0.0
		if p.off:
			_send_off(p)

func _send_off(p) -> void:
	p.off = true
	p.stun = 1e6
	p.vel = Vector3.ZERO
	p.position = Vector3(0, 0, -HW - 30.0)
	p.visible = false
	for h in humans:
		if h.ctrl == p:
			h.ctrl = null
			_switch(h)

func _first_on(team: int, order: Array):
	for i in order:
		if not teams[team][i].off:
			return teams[team][i]
	return teams[team][1]

func _kickoff(team: int) -> void:
	_formation(team, true)
	pen_wait = false
	Engine.time_scale = 1.0
	anim_rate = 1.0
	hud.replay_on = false
	ball.position = Vector3(0, BALL_R, 0)
	ball_vel = Vector3.ZERO
	var st = _first_on(team, [9, 10, 8, 7, 6, 5])
	if st.idx != 9:
		st.position = Vector3(-0.6 * side(team), 0, 0)
	ball_owner = st
	ball_last = st
	set_piece = "kick"
	st.ai_cool = 0.9
	protect_t = 1.5
	shot_live = false
	state = "play"
	state_t = 0.0
	for h in humans:
		h.charging = false
		h.pass_hold = -1.0
		h.ctrl = null
	var taken := false
	for h in humans:
		if h.team == team and not taken:
			h.ctrl = st
			taken = true
		else:
			h.ctrl = _first_on(h.team, [6, 5, 7, 8, 10, 4, 3]) if _hum_of(teams[h.team][6]) == null else _first_on(h.team, [5, 7, 8, 10, 4, 3])
	hud.show_controls = screen == "match" and humans.size() > 0
	fx("excite", 0.0)
	snd("whistle")

func _goal(team: int) -> void:
	score[team] += 1
	stats["goals"] += 1
	state = "goal"
	state_t = 0.0
	kick_team = 1 - team
	goal_idx = rec.size()
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
	for h in humans:
		h.charging = false
		h.charge = 0.0
		h.pass_hold = -1.0
	shot_live = false
	if _quiet():
		return
	Engine.time_scale = 0.3
	hud.set_score(score[0], score[1])
	fx("pop")
	_banner("GOAL!", Color(1.0, 0.86, 0.2), 2.2, "%d  %s   %d'" % [scorer.num, scorer.pname.to_upper(), int(clock / 60.0) + 1], 110)
	fx("flash", 0.75)
	hud.show_controls = false
	fx("shake", 1.0)
	snd("net")
	snd("roar")
	fx("excite", 1.0)
	fx("confetti", ball.position.x * 0.72)
	fx("vib", 180)
	fx("say", "Goal! %s scores for %s!" % [scorer.pname, TEAM_NAMES[team].capitalize()])

func _out(kind: String, pos: Vector3, team: int, wait := 0.9) -> void:
	state = "dead"
	state_t = 0.0
	dead_info = {"kind": kind, "pos": pos, "team": team, "wait": wait}
	stats["outs"] += 1
	shot_live = false
	for h in humans:
		h.charging = false
		h.charge = 0.0
		h.pass_hold = -1.0
	for p in players:
		p.recv = false

func _restart() -> void:
	var team: int = dead_info["team"]
	var pos: Vector3 = dead_info["pos"]
	var kind: String = dead_info["kind"]
	var s := side(team)
	for p in players:
		if p.off and p.visible:
			_send_off(p)
		p.offside = false
		p.commit_t = -1.0
	var taker = null
	if kind == "gk":
		taker = teams[team][0]
	elif kind == "pen":
		pos = Vector3(s * (HL - 11.0), 0, 0)
		taker = _first_on(team, [9, 10, 8, 7, 6, 5])
		for h in humans:
			if h.team == team and h.ctrl != null and h.ctrl.role != "GK":
				taker = h.ctrl
				break
	else:
		var bd := 1e9
		for p in teams[team]:
			if p.role == "GK" or p.off:
				continue
			var d: float = p.position.distance_to(pos)
			if d < bd:
				bd = d
				taker = p
	ball.position = Vector3(pos.x, BALL_R, pos.z)
	ball_vel = Vector3.ZERO
	var inward := Vector3(-pos.x, 0, -pos.z).normalized()
	if kind == "gk":
		inward = Vector3(-signf(pos.x), 0, 0)
	elif kind == "fk" or kind == "pen":
		inward = (Vector3(HL * s, 0, 0) - pos).normalized()
	taker.position = Vector3(pos.x, 0, pos.z) - inward * 0.6
	taker.vel = Vector3.ZERO
	taker.yaw = atan2(-inward.x, -inward.z)
	taker.stun = 0.0
	taker.hold_t = 0.0
	if kind == "fk":
		# the other team must give ten yards
		for o in teams[1 - team]:
			if o.off or o.role == "GK":
				continue
			var away: Vector3 = o.position - pos
			away.y = 0.0
			if away.length() < 9.15:
				var dirn := away.normalized() if away.length() > 0.2 else Vector3(-s, 0, 0)
				dirn = (dirn + Vector3(s, 0, 0) * 0.8).normalized()
				o.position = pos + dirn * 9.3
				o.position.x = clampf(o.position.x, -HL + 1.0, HL - 1.0)
				o.position.z = clampf(o.position.z, -HW + 1.0, HW - 1.0)
				o.vel = Vector3.ZERO
	elif kind == "pen":
		pen_wait = true
		var n := 0
		for p in players:
			if p.off or p == taker:
				continue
			p.vel = Vector3.ZERO
			p.stun = 0.0
			if p.role == "GK":
				if p.team != team:
					p.position = Vector3(s * (HL - 0.4), 0, 0)
					p.yaw = atan2(s, 0.0)
				continue
			# everyone else waits outside the box
			p.position = Vector3(s * (HL - 19.5 - (n % 2) * 2.2), 0, (float(n) - 9.5) * 2.0)
			p.yaw = atan2(-s, 0.0)
			n += 1
	ball_owner = taker
	ball_last = taker
	set_piece = kind
	taker.ai_cool = 1.3 if kind in ["fk", "pen"] else 1.0
	protect_t = 2.5
	state = "play"
	state_t = 0.0
	if taker.role != "GK" and _hum_of(taker) == null:
		var h = _nearest_human(team, taker.position)
		if h != null:
			h.ctrl = taker
	_assign_defenders(1 - team, true)

func _foul(by, on) -> void:
	stats["fouls"] += 1
	var pos: Vector3 = on.position
	on.stun = 1.2
	on.start_tackle()
	by.stun = 0.8
	var gx := -HL * side(by.team)
	var in_box := absf(pos.x - gx) < 16.5 and absf(pos.z) < 20.16
	var closing: float = (by.vel - on.vel).length()
	var card := ""
	if closing > 5.0 or in_box:
		by.yellow += 1
		stats["cards"] += 1
		card = "YELLOW CARD"
		if by.yellow >= 2:
			card = "RED CARD"
			by.off = true
	if in_box:
		stats["pens"] += 1
	snd("whistle")
	if not _quiet():
		var who := "%d  %s" % [by.num, by.pname.to_upper()]
		if in_box:
			_banner("PENALTY!", Color(1.0, 0.86, 0.2), 1.6, (card + "   " + who) if card != "" else "", 96)
			fx("say", "Penalty!")
			snd("ooh")
		elif card == "RED CARD":
			_banner("RED CARD", Color(0.95, 0.2, 0.2), 1.6, who, 84)
			fx("say", "He is sent off!")
			snd("ooh")
		elif card != "":
			_banner("YELLOW CARD", Color(1.0, 0.9, 0.2), 1.4, who, 72)
		else:
			_banner("FOUL", Color(1, 1, 1), 1.0, "", 60)
		fx("shake", 0.35)
		fx("vib", 80)
	ball_owner = null
	ball_vel = Vector3.ZERO
	_out("pen" if in_box else "fk", pos, on.team, 2.0 if (in_box or card != "") else 1.4)

func _offside(p) -> void:
	stats["offsides"] += 1
	snd("whistle")
	_banner("OFFSIDE", Color(1, 1, 1), 1.1, "%d  %s" % [p.num, p.pname.to_upper()], 64)
	ball_owner = null
	ball_vel = Vector3.ZERO
	_out("fk", off_spot, 1 - p.team, 1.4)

func _is_offside(p, m) -> bool:
	var s := side(p.team)
	var mu: float = m.position.x * s
	if mu <= 0.0 or mu <= ball.position.x * s + 0.3:
		return false
	var n := 0
	for o in teams[1 - p.team]:
		if not o.off and o.position.x * s >= mu - 0.25:
			n += 1
	return n < 2

# ---------------------------------------------------------------- humans

func _hum_of(p):
	for h in humans:
		if h.ctrl == p:
			return h
	return null

func _team_human(t: int) -> bool:
	for h in humans:
		if h.team == t:
			return true
	return false

func _nearest_human(t: int, pos: Vector3):
	var best = null
	var bd := 1e9
	for h in humans:
		if h.team != t:
			continue
		var d: float = h.ctrl.position.distance_to(pos) if h.ctrl != null else 1e6
		if d < bd:
			bd = d
			best = h
	return best

func _assign_defenders(t: int, force: bool) -> void:
	var hs := []
	for h in humans:
		if h.team == t and (force or h.switch_cool <= 0.0):
			hs.append(h)
	if hs.is_empty():
		return
	var own_goal := Vector3(-HL * side(t), 0, 0)
	var cands := []
	for p in teams[t]:
		if p.role == "GK" or p.off:
			continue
		var d: float = p.position.distance_to(ball.position)
		if p.position.distance_to(own_goal) > ball.position.distance_to(own_goal) + 2.0:
			d += 8.0
		cands.append([d, p])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var used := []
	for h in humans:
		if h.team == t and not hs.has(h) and h.ctrl != null:
			used.append(h.ctrl)
	for h in hs:
		for c in cands:
			if not used.has(c[1]):
				if h.ctrl != c[1]:
					h.ctrl = c[1]
					h.switch_cool = 0.7
				used.append(c[1])
				break

func _switch(h) -> void:
	var best = null
	var bd := 1e9
	for p in teams[h.team]:
		if p.role == "GK" or p == h.ctrl or _hum_of(p) != null or p.off:
			continue
		var d: float = p.position.distance_to(ball.position)
		if d < bd:
			bd = d
			best = p
	if best != null:
		h.ctrl = best
	h.switch_cool = 0.9
	if h.local:
		au["blip"].play()

# ---------------------------------------------------------------- main loop

func _physics_process(dt: float) -> void:
	if dbg and Engine.get_physics_frames() % 15 == 0:
		_dbg()
	if autotest:
		for i in 30:
			_bot_inputs(1.0 / 60.0)
			_tick(1.0 / 60.0)
			if state == "full":
				print("AUTOTEST score=", score, " stats=", stats, " bot=", bstats)
				get_tree().quit()
				return
		return
	_net_poll()
	var evs: Array = hud.ev.duplicate()
	hud.ev.clear()
	_keys_to_events(evs)
	if evs.has("cam"):
		cam_mode = (cam_mode + 1) % CAMS.size()
		au["blip"].play()
	if evs.has("pause"):
		_action("pause")
	if screen == "menu":
		_tick(dt)
		return
	var st := _stick() * view_flip
	var sprint: bool = hud.sprint_down or Input.is_physical_key_pressed(KEY_SHIFT)
	var acts := []
	for e in evs:
		if e in ["shoot_down", "shoot_up", "pass_down", "pass_up", "tap"]:
			acts.append(e)
	if net.role == "guest":
		tick_n += 1
		if tick_n % 2 == 0 or not acts.is_empty():
			net.send({"_": "i", "s": [snappedf(st.x, 0.01), snappedf(st.y, 0.01)], "sp": sprint, "e": acts})
		return
	if humans.size() > me:
		var h = humans[me]
		h.stick = st
		h.sprint = sprint
		h.evs.append_array(acts)
	if paused:
		for h in humans:
			h.evs.clear()
		return
	_tick(dt)
	if net.role == "host" and net.connected:
		tick_n += 1
		if tick_n % 2 == 0:
			_send_snap()

func _dbg() -> void:
	# for automated tests: ?dbg in the address publishes a little state to the page
	var hs := []
	for h in humans:
		hs.append([h.team, players.find(h.ctrl), snappedf(h.ctrl.position.x, 0.1) if h.ctrl != null else 0.0, snappedf(h.ctrl.position.z, 0.1) if h.ctrl != null else 0.0])
	JavaScriptBridge.eval("window.bbDbg=%s" % JSON.stringify({
		"screen": screen, "state": state, "room": room, "conn": net.connected, "role": net.role, "score": score,
		"h": hs, "ball": [snappedf(ball.position.x, 0.1), snappedf(ball.position.z, 0.1)], "menu": hud.menu_name, "mode": opt_mode, "clock": int(clock),
		"owner": players.find(ball_owner), "fps": Engine.get_frames_per_second(),
	}), true)

func _tick(dt: float) -> void:
	state_t += dt
	match state:
		"intro":
			if state_t > 2.6:
				_kickoff(kick_team)
		"play":
			_play(dt)
			_record()
		"goal":
			_celebrate(dt)
			if state_t < 1.2:
				_record()
		"replay":
			_replay(dt)
		"dead":
			_idle_players(dt)
			_ball_free(dt)
			if state_t > float(dead_info.get("wait", 0.9)):
				_restart()
		"half":
			_idle_players(dt)
			if state_t > 3.0:
				_kickoff(1)
		"full":
			_idle_players(dt)
	for h in humans:
		h.evs.clear()

func _keys_to_events(evs: Array) -> void:
	var map := {KEY_SPACE: "shoot", KEY_X: "pass", KEY_E: "pass", KEY_C: "cam", KEY_ESCAPE: "pause"}
	for k in map:
		var d := Input.is_physical_key_pressed(k)
		var was: bool = _keys.get(k, false)
		var simple: bool = map[k] in ["cam", "pause"]
		if d and not was:
			evs.append(map[k] if simple else map[k] + "_down")
		elif was and not d and not simple:
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

func _cpu(t: int) -> Dictionary:
	# how sharp a team's computer players are
	if humans.is_empty():
		return DIFF[1]
	if _team_human(t):
		return DIFF[2]
	return DIFF[opt_diff]

func _play(dt: float) -> void:
	clock += dt * 5400.0 / LENGTHS[opt_len]
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
	# --- human buttons
	for h in humans:
		h.switch_cool -= dt
		if h.ctrl == null:
			continue
		var dir3 := Vector3(h.stick.x, 0, h.stick.y)
		var mine: bool = ball_owner == h.ctrl
		for e in h.evs:
			if e == "shoot_down":
				if mine:
					h.charging = true
					h.charge = 0.0
				else:
					_human_tackle(h)
			elif e == "shoot_up":
				if h.charging and ball_owner == h.ctrl:
					_shoot(h.ctrl, h.charge, _human_aim(h, dir3), 0.8)
				h.charging = false
				h.charge = 0.0
			elif e == "pass_down":
				if mine and set_piece == "pen":
					pass
				elif mine:
					h.pass_hold = 0.0
				else:
					_switch(h)
			elif e == "pass_up":
				if h.pass_hold >= 0.0 and ball_owner == h.ctrl:
					var m = _pass_target(h.ctrl, dir3, false)
					if m != null:
						_pass(h.ctrl, m, h.pass_hold > 0.28)
				h.pass_hold = -1.0
		if h.charging:
			if ball_owner != h.ctrl:
				h.charging = false
				h.charge = 0.0
			else:
				h.charge = minf(h.charge + dt / 0.75, 1.0)
				if h.charge >= 1.0:
					_shoot(h.ctrl, 1.0, _human_aim(h, dir3), 0.8)
					h.charging = false
					h.charge = 0.0
		if h.pass_hold >= 0.0:
			h.pass_hold += dt
	# --- who chases
	var chaser := [null, null]
	var second := [null, null]
	var aim := _ball_meet_point()
	for t in 2:
		var us := []
		for o in teams[1 - t]:
			if not o.off:
				us.append(o.position.x * side(t))
		us.sort()
		off_line[t] = maxf(maxf(us[us.size() - 2] if us.size() > 1 else 0.0, ball.position.x * side(t)), 0.0)
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
		# loose ball: hand the nearest player to a human on that team
		if ball_owner == null and chaser[t] != null and _hum_of(chaser[t]) == null:
			var h = _nearest_human(t, aim)
			if h != null and h.switch_cool <= 0.0 and h.ctrl != null and not h.ctrl.recv:
				if chaser[t].position.distance_to(aim) + 3.0 < h.ctrl.position.distance_to(aim):
					h.ctrl = chaser[t]
					h.switch_cool = 0.8
	# --- move everyone
	for p in players:
		var want := Vector3.ZERO
		var h = _hum_of(p)
		if p.stun > 0.0:
			p.stun -= dt
		elif pen_wait:
			want = Vector3.ZERO
		elif h != null:
			if p.recv and ball_owner == null and h.stick.length() < 0.5:
				want = _run_to(p, aim, p.top_speed)
			else:
				var sp: float = p.top_speed * (1.0 if h.sprint else 0.8)
				if ball_owner == p:
					sp *= 0.93
				if h.charging:
					sp *= 0.6
				want = Vector3(h.stick.x, 0, h.stick.y) * sp
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
		ball_last = o
		_tackles(dt)
	else:
		_ball_free(dt)
		_pickups()
		if state == "play":
			_check_lines()
	# --- crowd gets louder near the goals
	var near := clampf((absf(ball.position.x) - 20.0) / 30.0, 0.0, 1.0)
	crowd_vol = lerpf(crowd_vol, -15.0 + near * 7.0, dt * 2.0)
	# --- clock
	if state != "play":
		return
	if half == 1 and clock >= 2700.0 and (ball_owner != null or clock > 2790.0) and absf(ball.position.x) < 32.0:
		half = 2
		clock = 2700.0
		state = "half"
		state_t = 0.0
		ball_owner = null
		ball_vel = Vector3.ZERO
		hud.show_controls = false
		snd("whistle_long")
		_banner("HALF TIME", Color(1, 1, 1), 2.2, "%d - %d" % [score[0], score[1]])
	elif half == 2 and clock >= 5400.0 and (ball_owner != null or clock > 5490.0 or autotest) and (absf(ball.position.x) < 32.0 or autotest):
		_full_time()

func _full_time() -> void:
	state = "full"
	state_t = 0.0
	ball_owner = null
	ball_vel = Vector3.ZERO
	hud.show_controls = false
	scorer = null
	if _quiet():
		if screen == "menu":
			score = [0, 0]
			clock = 0.0
			half = 1
			_kickoff(0)
		return
	snd("whistle_long")
	for p in players:
		p.mood_t = 0.0
		p.mood = 0 if score[0] == score[1] else (2 if (score[p.team] > score[1 - p.team]) else 3)
	fx("say", "Full time! %s %d, %s %d." % [TEAM_NAMES[0].capitalize(), score[0], TEAM_NAMES[1].capitalize(), score[1]])
	if score[0] != score[1]:
		fx("excite", 0.6)
	hud.show_menu("full", _menu_info())

func _idle_players(dt: float) -> void:
	for p in players:
		_move(p, Vector3.ZERO, dt)

func _move(p, want: Vector3, dt: float) -> void:
	var acc := 15.0 if want.length() > p.vel.length() else 22.0
	p.vel = p.vel.move_toward(want, acc * dt)
	p.position += p.vel * dt
	p.position.x = clampf(p.position.x, -HL - 2.5, HL + 2.5)
	p.position.z = clampf(p.position.z, -HW - 2.5, HW + 2.5)
	if p.role == "GK" and state == "play" and ball_owner != p:
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
	# inside a net: the net catches the ball
	if absf(ball.position.x) > HL and absf(ball.position.z) < GOAL_HW + 0.2 and ball.position.y < GOAL_H + 0.2 and state == "goal":
		var depth := absf(ball.position.x) - HL
		if depth > 1.7:
			ball.position.x = signf(ball.position.x) * (HL + 1.7)
			ball_vel.x *= -0.1
			ball_vel.z *= 0.3
			fx("net", ball.position.x)
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
	var t := 0.6
	if ball.position.y > 1.0 or ball_vel.y > 3.0:
		# a ball in the air: go where it comes down
		var vy := ball_vel.y
		t = clampf((vy + sqrt(maxf(vy * vy + 19.6 * (p.y - BALL_R), 0.0))) / 9.8, 0.2, 3.0)
		var o2 := p + v * t * 0.97
		o2.y = 0.0
		o2.x = clampf(o2.x, -HL, HL)
		o2.z = clampf(o2.z, -HW, HW)
		return o2
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
	pen_wait = false
	p.hold_t = 0.0
	for q in players:
		q.recv = false
		q.offside = false

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
		if set_piece in ["", "fk", "kick"] and _is_offside(p, m):
			if ai:
				continue
			sc -= 2.0
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
	var h = _hum_of(p)
	var offs: bool = set_piece in ["", "fk", "kick"] and _is_offside(p, m)
	_release(p, v)
	m.recv = true
	if offs:
		m.offside = true
		off_spot = m.position
	stats["passes"] += 1
	snd("kick" if lofted or d > 22.0 else "touch")
	if h != null and m.role != "GK" and _hum_of(m) == null:
		h.ctrl = m
		h.switch_cool = 0.5

func _human_aim(h, dir3: Vector3) -> float:
	var gk = teams[1 - h.team][0]
	if absf(dir3.z) > 0.3:
		return clampf(dir3.z * 1.3, -1.0, 1.0) * GOAL_HW * 0.82
	return (-1.0 if gk.position.z > 0.0 else 1.0) * GOAL_HW * 0.62

func _shoot(p, power: float, aim_z: float, err_k: float) -> void:
	var s := side(p.team)
	var from := ball.position
	var d := Vector2(HL * s - from.x, aim_z - from.z).length()
	var err := (randf() - 0.5) * (0.4 + d * 0.035 + power * 0.8) * err_k
	var goal := Vector3(HL * s, 0, aim_z + err)
	var dir := goal - from
	dir.y = 0.0
	dir = dir.normalized()
	var sp := 19.0 + 13.0 * power
	var t := maxf(d / sp, 0.15)
	var h := 0.35 + power * power * 2.1 + randf() * 0.6 * power * err_k
	var vy := (h - 0.25) / t + 4.9 * t
	_release(p, dir * sp + Vector3(0, vy, 0))
	shot_live = true
	stats["shots"] += 1
	fx("shake", 0.2 + 0.4 * power)
	fx("punch", 1.5 + 3.0 * power)
	snd("kick")
	fx("dust", [from.x, from.z])
	fx("vib", 40)

# ---------------------------------------------------------------- winning the ball

func _give(p) -> void:
	if p.offside and state == "play":
		_offside(p)
		return
	var prev = ball_last
	ball_owner = p
	ball_last = p
	shot_live = false
	p.hold_t = 0.0
	p.ai_cool = _cpu(p.team)["think"] * (0.8 + randf() * 0.6)
	for q in players:
		q.recv = false
		q.offside = false
	for h in humans:
		h.charging = false
		h.charge = 0.0
		h.pass_hold = -1.0
	if p.role != "GK" and _hum_of(p) == null:
		var h2 = _nearest_human(p.team, p.position)
		if h2 != null:
			h2.ctrl = p
	_assign_defenders(1 - p.team, prev == null or prev.team != p.team)

func _human_tackle(h) -> void:
	var c = ball_owner
	var me_p = h.ctrl
	if me_p.stun > 0.0 or me_p.tackle_t >= 0.0:
		return
	me_p.start_tackle()
	if c == null or c.team == h.team:
		me_p.vel = me_p.fwd() * 9.0
		me_p.stun = 0.35
		return
	var to: Vector3 = c.position - me_p.position
	var d := to.length()
	if d < 2.6:
		me_p.yaw = atan2(-to.x, -to.z)
		me_p.vel = to.normalized() * 9.5
	if d < 2.0 and protect_t <= 0.0 and c.role != "GK":
		var front: float = c.fwd().dot((me_p.position - c.position).normalized())
		if front > -0.45:
			c.stun = 0.6
			stats["tackles"] += 1
			snd("touch")
			fx("shake", 0.25)
			_give(me_p)
			protect_t = 0.7
			return
		if d < 1.7:
			_foul(me_p, c)
			return
	me_p.stun = 0.55

func _tackles(dt: float) -> void:
	var c = ball_owner
	if c == null or c.role == "GK" or protect_t > 0.0:
		return
	for o in teams[1 - c.team]:
		if o.stun > 0.0 or _hum_of(o) != null or o.role == "GK":
			continue
		var d: float = o.position.distance_to(c.position)
		var front: float = c.fwd().dot((o.position - c.position).normalized())
		if o.commit_t >= 0.0:
			# the tackle is already on its way: it lands a moment later, wherever the carrier has turned by then
			o.commit_t -= dt
			if o.commit_t <= 0.0:
				o.commit_t = -1.0
				if d > 1.6:
					o.stun = 0.5
				elif front > -0.35:
					c.stun = 0.55
					stats["tackles"] += 1
					snd("touch")
					_give(o)
					protect_t = 0.7
					return
				else:
					_foul(o, c)
					return
			continue
		if d < 1.3 and front > -0.35:
			o.press_t += dt
			var need: float = _cpu(o.team)["need"]
			if _team_human(o.team):
				need = 0.8
			if o.press_t > need - 0.15:
				o.press_t = 0.0
				o.commit_t = 0.15
				o.start_tackle()
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
		if absf(b.x - gx) > 16.5 or absf(b.z) > 20.16:
			continue
		var reach := 0.85 + (0.75 if g.dive_t >= 0.0 else 0.0)
		var dh := Vector2(b.x - g.position.x, b.z - g.position.z).length()
		if dh < reach and b.y < 2.6:
			if hs > 19.0 and dh > 0.7:
				var sgn := signf(b.z - g.position.z)
				ball_vel = Vector3(-ball_vel.x * 0.3, absf(ball_vel.y) * 0.4 + 2.5, ball_vel.z * 0.4 + sgn * 5.0)
				ball_ignore = g
				ignore_t = 0.5
				ball_last = g
				shot_live = false
				stats["saves"] += 1
				snd("touch")
				snd("ooh")
				fx("shake", 0.3)
				fx("say", "What a save!")
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
		if shot_live and ball_last != null and p.team == ball_last.team:
			continue
		var d := Vector2(b.x - p.position.x, b.z - p.position.z).length()
		# a fast ball that is not meant for you only hits you if it really hits your body
		if hs > 12.0 and not p.recv and d > 0.55:
			continue
		if d < bd:
			bd = d
			best = p
	if best == null:
		return
	if hs > 24.0 and not best.recv:
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
			ball_vel.x *= -0.6
			ball_vel.z += (randf() - 0.5) * 4.0
			ball.position.x = sx * (HL - 0.05)
			shot_live = false
			snd("post")
			snd("ooh")
			fx("shake", 0.5)
			fx("say", "Off the woodwork!")
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
	var cpu := _cpu(p.team)
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
	if set_piece == "pen" or (set_piece == "fk" and dist < 27.0 and absf(p.position.z) < 16.0):
		if p.ai_cool <= 0.0:
			_shoot(p, 0.55 + randf() * 0.3, (1.0 if randf() < 0.5 else -1.0) * GOAL_HW * (0.5 + randf() * 0.35), cpu["err"])
		return Vector3.ZERO
	if set_piece != "":
		if p.ai_cool <= 0.0:
			var m2 = _pass_target(p, Vector3.ZERO, set_piece != "corner")
			if m2 == null:
				m2 = teams[p.team][6]
			_pass(p, m2, set_piece == "corner" or set_piece == "gk")
		return Vector3.ZERO
	if nd < 2.6 and p.ai_cool > 0.12:
		p.ai_cool = 0.12 # a man is on me: decide now
	if p.ai_cool <= 0.0:
		p.ai_cool = cpu["think"] * (0.8 + randf() * 0.6)
		var angle_ok := absf(p.position.z) < 8.0 + (HL - absf(p.position.x)) * 0.8
		if dist < 24.0 and angle_ok and (nd > 1.7 or dist < 14.0):
			if dist < 20.0 or randf() < 0.4:
				var gk = teams[1 - p.team][0]
				var az := (-1.0 if gk.position.z > 0.0 else 1.0) * GOAL_HW * (0.5 + randf() * 0.28)
				_shoot(p, 0.5 + randf() * 0.4, az, cpu["err"])
				return Vector3.ZERO
		var pressured := nd < 4.2
		if pressured or randf() < 0.25:
			var m3 = _pass_target(p, Vector3.ZERO, true)
			if m3 != null:
				var gain: float = (m3.position.x - p.position.x) * s
				if pressured and gain > -20.0 or gain > 6.0:
					_pass(p, m3, false)
					return Vector3.ZERO
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
	return dir.normalized() * p.top_speed * 0.94 * cpu["spd"]

func _ai_offball(p, chaser: Array, second: Array, aim: Vector3) -> Vector3:
	var t: int = p.team
	var s := side(t)
	var cpu := _cpu(t)
	var loose: bool = ball_owner == null
	var ours: bool = not loose and ball_owner.team == t
	if p.recv and loose:
		return _run_to(p, aim, p.top_speed)
	if loose and p == chaser[t]:
		return _run_to(p, aim, p.top_speed * cpu["spd"])
	if not loose and not ours and set_piece == "":
		var c = ball_owner
		var own_goal := Vector3(-HL * s, 0, 0)
		var goal_side: Vector3 = (own_goal - c.position).normalized()
		if p == chaser[t]:
			if _team_human(t):
				# your team mate holds the runner up; you make the tackle
				return _run_to(p, c.position + goal_side * 2.6, p.top_speed * 0.95)
			return _run_to(p, c.position + c.vel * 0.25 + goal_side * 0.5, p.top_speed * 0.97 * cpu["spd"])
		if p == second[t]:
			return _run_to(p, c.position + goal_side * 6.0, p.top_speed * 0.9)
	var bu: float = ball.position.x * s
	var u: float = -45.0 + p.home.x * 62.0 + bu * 0.6 + (9.0 if ours else 0.0)
	if p.role == "FW" and ours:
		u += 4.0 + 3.0 * sin(clock * 0.02 + p.idx * 2.0)
	if p.role == "DF":
		u = clampf(u, -46.0, 14.0)
	else:
		u = clampf(u, -40.0, 47.0)
	if ours:
		u = minf(u, maxf(off_line[t] - 0.8, 0.0))
	var z: float = p.home.y * s * (29.0 if ours else 21.0) + ball.position.z * (0.25 if ours else 0.42)
	z = clampf(z, -HW + 1.5, HW - 1.5)
	return _run_to(p, Vector3(u * s, 0, z), p.top_speed * 0.88)

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
				if p.react_t < 0.24:
					return p.vel * 0.5
				var target := Vector3(gx + s * 0.7, 0, clampf(zc, -GOAL_HW + 0.2, GOAL_HW - 0.2))
				var dz: float = target.z - p.position.z
				if absf(dz) > 1.0 and t < 0.6 and p.dive_t < 0.0:
					var right := Vector3(cos(p.yaw), 0, -sin(p.yaw))
					p.start_dive(signf(Vector3(0, 0, dz).dot(right)))
				var sp := 4.8 if p.dive_t >= 0.0 else 3.5
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

# ---------------------------------------------------------------- goal celebration and replay

func _celebrate(dt: float) -> void:
	if not _quiet() and state_t > 0.5 and Engine.time_scale < 1.0:
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
	if _quiet():
		if state_t > 0.2:
			_kickoff(kick_team)
		return
	if state_t > 4.2:
		fx("excite", 0.25)
		if rec.size() > 40:
			state = "replay"
			state_t = 0.0
			rp_pos = float(maxi(goal_idx - 100, 0))
			rp_to = mini(goal_idx + 30, rec.size() - 1)
			anim_rate = 0.55
			hud.replay_on = true
			for p in players:
				p.mood = 0
			snd("whoosh")
		else:
			_kickoff(kick_team)

func _record() -> void:
	if _quiet():
		return
	if Engine.get_physics_frames() % 2 == 0:
		rec.append(_pack())
		if rec.size() > 360:
			rec.pop_front()
			goal_idx -= 1

func _replay(_dt: float) -> void:
	rp_pos += 0.275
	var skip := false
	for h in humans:
		if state_t > 0.6 and (h.evs.has("tap") or h.evs.has("shoot_down")):
			skip = true
	if rp_pos >= float(rp_to) or skip:
		_kickoff(kick_team)
		return
	var i := int(rp_pos)
	_unpack(rec[i], rec[mini(i + 1, rec.size() - 1)], rp_pos - float(i))

func _pack() -> Array:
	var a := []
	a.resize(players.size() * N_F + 7)
	var k := 0
	for p in players:
		a[k] = snappedf(p.position.x, 0.01)
		a[k + 1] = snappedf(p.position.z, 0.01)
		a[k + 2] = snappedf(p.yaw, 0.01)
		a[k + 3] = snappedf(p.vel.x, 0.1)
		a[k + 4] = snappedf(p.vel.z, 0.1)
		a[k + 5] = p.kick_n
		a[k + 6] = p.tackle_n
		a[k + 7] = p.dive_n
		a[k + 8] = p.dive_side
		a[k + 9] = 9 if p.off else p.mood
		k += N_F
	a[k] = snappedf(ball.position.x, 0.01)
	a[k + 1] = snappedf(ball.position.y, 0.01)
	a[k + 2] = snappedf(ball.position.z, 0.01)
	a[k + 3] = snappedf(ball_vel.x, 0.1)
	a[k + 4] = snappedf(ball_vel.y, 0.1)
	a[k + 5] = snappedf(ball_vel.z, 0.1)
	a[k + 6] = players.find(ball_owner)
	return a

# Puts a packed frame on the pitch (replay); f blends towards the next frame.
func _unpack(a: Array, b: Array, f: float) -> void:
	var k := 0
	for p in players:
		p.position = Vector3(lerpf(a[k], b[k], f), 0, lerpf(a[k + 1], b[k + 1], f))
		p.yaw = lerp_angle(a[k + 2], b[k + 2], f)
		p.vel = Vector3(a[k + 3], 0, a[k + 4])
		_anim_sync(p, a, k)
		k += N_F
	ball.position = Vector3(lerpf(a[k], b[k], f), lerpf(a[k + 1], b[k + 1], f), lerpf(a[k + 2], b[k + 2], f))
	ball_vel = Vector3(a[k + 3], a[k + 4], a[k + 5])
	var oi := int(a[k + 6])
	ball_owner = players[oi] if oi >= 0 else null

func _anim_sync(p, a: Array, k: int) -> void:
	if int(a[k + 5]) != p.kick_n:
		p.kick_n = int(a[k + 5])
		p.kick_t = 0.0
	if int(a[k + 6]) != p.tackle_n:
		p.tackle_n = int(a[k + 6])
		p.tackle_t = 0.0
	if int(a[k + 7]) != p.dive_n:
		p.dive_n = int(a[k + 7])
		p.dive_t = 0.0
		p.dive_side = a[k + 8]
	var md := int(a[k + 9])
	p.visible = md != 9
	if md != 9 and md != p.mood:
		p.mood = md
		p.mood_t = 0.0

# ---------------------------------------------------------------- online: snapshots

func _send_snap() -> void:
	var hc := []
	var ch := []
	for h in humans:
		hc.append(players.find(h.ctrl))
		ch.append(snappedf(h.charge, 0.01))
	net.send({
		"_": "s", "st": state, "t": snappedf(state_t, 0.01), "sc": score, "ck": int(clock), "p": _pack(),
		"h": hc, "c": ch, "e": out_ev, "sr": players.find(scorer), "rp": hud.replay_on,
	})
	out_ev = []

func _guest_frame(dt: float) -> void:
	if snap == null:
		return
	var a: Array = snap["p"]
	if snap_new:
		snap_new = false
		var prev := state
		state = str(snap["st"])
		state_t = float(snap["t"])
		var sc: Array = snap["sc"]
		score = [int(sc[0]), int(sc[1])]
		clock = float(snap["ck"])
		hud.set_score(score[0], score[1])
		hud.replay_on = bool(snap.get("rp", false))
		anim_rate = 0.55 if state == "replay" else 1.0
		var si := int(snap.get("sr", -1))
		scorer = players[si] if si >= 0 else null
		var hc: Array = snap["h"]
		for i in humans.size():
			var ci := int(hc[i]) if i < hc.size() else -1
			humans[i].ctrl = players[ci] if ci >= 0 else null
		var ch: Array = snap["c"]
		if me < ch.size():
			humans[me].charge = float(ch[me])
		hud.show_controls = state == "play"
		if state == "full" and prev != "full":
			hud.show_menu("full", _menu_info())
		elif state != "full" and prev == "full":
			hud.show_menu("", {})
		var k := 0
		for p in players:
			p.net_pos = Vector3(a[k], 0, a[k + 1])
			p.net_yaw = a[k + 2]
			p.vel = Vector3(a[k + 3], 0, a[k + 4])
			if p.position.distance_to(p.net_pos) > 6.0:
				p.position = p.net_pos
			_anim_sync(p, a, k)
			k += N_F
		ball_net = Vector3(a[k], a[k + 1], a[k + 2])
		ball_vel = Vector3(a[k + 3], a[k + 4], a[k + 5])
		if ball.position.distance_to(ball_net) > 8.0:
			ball.position = ball_net
		var oi := int(a[k + 6])
		ball_owner = players[oi] if oi >= 0 else null
	else:
		state_t += dt
	var f := clampf(dt * 16.0, 0.0, 1.0)
	var moving := state != "replay" and state != "full"
	for p in players:
		if moving:
			p.net_pos += p.vel * dt
		p.position = p.position.lerp(p.net_pos, f)
		p.yaw = lerp_angle(p.yaw, p.net_yaw, f)
	if moving and ball_owner == null:
		ball_net += ball_vel * dt
		ball_net.y = maxf(ball_net.y, BALL_R)
	ball.position = ball.position.lerp(ball_net, clampf(dt * 22.0, 0.0, 1.0))

# ---------------------------------------------------------------- camera, visuals

func _process(dt: float) -> void:
	real_t += dt
	_auto_quality(dt)
	var rdt := dt / maxf(Engine.time_scale, 0.05)
	if net.role == "guest" and screen == "match":
		_guest_frame(dt)
	if not paused:
		_spin_ball(ball_vel, dt * anim_rate)
	var loose: bool = ball_owner == null
	trail.emitting = loose and ball_vel.length() > 17.0 and screen == "match"
	# landing ring for high balls
	var show_ring := false
	if loose and state == "play" and ball.position.y > 1.6 and screen == "match":
		var vy := ball_vel.y
		var t := (vy + sqrt(maxf(vy * vy + 19.6 * (ball.position.y - BALL_R), 0.0))) / 9.8
		if t > 0.25:
			var lp := ball.position + Vector3(ball_vel.x, 0, ball_vel.z) * t * 0.97
			if absf(lp.x) < HL and absf(lp.z) < HW:
				land_ring.position = Vector3(lp.x, 0.05, lp.z)
				show_ring = true
	land_ring.visible = show_ring
	var show_rings := state == "play" and screen == "match"
	for p in players:
		if not paused:
			p.animate(dt * anim_rate)
		p.set_ring(false, Color.WHITE, false)
	if show_rings:
		for i in humans.size():
			var h = humans[i]
			if h.ctrl != null:
				if i == me:
					h.ctrl.set_ring(true, Color(1.0, 0.92, 0.25), true)
				elif humans.size() > me and h.team == humans[me].team:
					h.ctrl.set_ring(true, Color(0.3, 0.9, 1.0), true)
	# HUD state
	hud.cam_name = CAMS[cam_mode]
	hud.in_match = screen == "match"
	if screen == "match":
		hud.set_clock(int(clock / 60.0))
		if humans.size() > me:
			var hm = humans[me]
			var ours: bool = ball_owner != null and ball_owner.team == hm.team
			hud.lab_a = "SHOOT" if ours else "TACKLE"
			hud.lab_b = "PASS" if ours else "SWITCH"
			hud.charge = hm.charge
		_minimap()
	crowd_au.volume_db = lerpf(crowd_au.volume_db, crowd_vol if screen == "match" else -26.0, clampf(rdt * 3.0, 0.0, 1.0))
	_camera(rdt)
	if shot_path != "" and real_t >= shot_at:
		var img := get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("saved ", shot_path, " state=", state, " score=", score)
		shot_path = ""
		get_tree().quit()

func _minimap() -> void:
	var pts := PackedVector3Array()
	var my = humans[me].ctrl if humans.size() > me else null
	for p in players:
		if not p.visible:
			continue
		pts.append(Vector3(p.position.x * view_flip, p.position.z * view_flip, 2.0 if p == my else float(p.team)))
	hud.mm_pts = pts
	hud.mm_ball = Vector2(ball.position.x, ball.position.z) * view_flip

func _camera(dt: float) -> void:
	var f := ball.position
	var want_pos := Vector3.ZERO
	var want_look := Vector3.ZERO
	var want_fov := 38.0
	var k := 3.2
	fov_punch = maxf(fov_punch - dt * 9.0, 0.0)
	if screen == "menu":
		var a := real_t * 0.1
		want_pos = Vector3(sin(a) * 62.0, 15.0 + sin(a * 0.7) * 4.0, cos(a) * 50.0)
		want_look = Vector3(f.x * 0.35, 0, f.z * 0.35)
		want_fov = 44.0
		k = 2.0
	elif state == "intro":
		want_look = Vector3(0, 0, 0)
		want_pos = Vector3(0, 21, 31 * view_flip)
		want_fov = 27.0
		k = 1.6
	elif state == "replay":
		var sx := signf(f.x) if absf(f.x) > 1.0 else 1.0
		want_look = Vector3(f.x, 0.9, f.z)
		want_pos = Vector3(f.x - sx * 11.0, 2.6, f.z + 7.5 * view_flip)
		want_fov = 34.0
		k = 3.5
	elif state == "goal" and scorer != null and state_t > 0.5:
		var a2 := state_t * 0.55 + 0.6
		var c: Vector3 = scorer.position + Vector3(0, 1.3, 0)
		want_look = c
		want_pos = c + Vector3(sin(a2) * 7.5 * -signf(scorer.position.x), 1.6 + minf(state_t, 6.0) * 0.25, cos(a2) * 7.5)
		want_fov = 44.0
		k = 2.4
	elif state == "goal":
		want_look = Vector3(f.x, 1.0, f.z)
		want_pos = Vector3(f.x - signf(f.x) * 14.0, 5.0, f.z + 12.0 * view_flip)
		want_fov = 34.0
		k = 4.0
	elif state == "full":
		var a4 := real_t * 0.15
		want_pos = Vector3(sin(a4) * 40.0, 14.0, cos(a4) * 34.0)
		want_look = Vector3(0, 0, 0)
		want_fov = 40.0
		k = 1.5
	else:
		var off := Vector3(0, 21.0, 31.0)
		var fx2 := clampf(f.x, -HL + 8.0, HL - 8.0)
		var foc := Vector3(fx2, 0, f.z * 0.6)
		want_fov = 27.0
		if cam_mode == 1:
			off = Vector3(0, 38.0, 5.0)
			foc = Vector3(clampf(f.x, -HL + 14.0, HL - 14.0), 0, clampf(f.z, -20.0, 20.0))
			want_fov = 30.0
		elif cam_mode == 2:
			off = Vector3(0, 9.0, 14.5)
			foc = Vector3(f.x, 0.5, f.z)
			want_fov = 40.0
		off.z *= view_flip
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
	var off2 := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * shake * 0.7
	cam.fov = cam_fov - fov_punch
	if cam_pos.distance_to(cam_look) > 0.5:
		cam.look_at_from_position(cam_pos + off2, cam_look, Vector3.UP)

# Weak phones: drop shadows, then resolution, if the frame rate stays low.
func _auto_quality(dt: float) -> void:
	if real_t > 4.0 and quality > 0 and not autotest and shot_path == "":
		if Engine.get_frames_per_second() < 40.0:
			slow_t += dt
			if slow_t > 3.0:
				quality -= 1
				slow_t = 0.0
		else:
			slow_t = maxf(slow_t - dt, 0.0)
	if quality != q_applied:
		q_applied = quality
		world.sun.shadow_enabled = quality >= 2
		get_viewport().msaa_3d = Viewport.MSAA_2X if quality >= 2 else Viewport.MSAA_DISABLED
		get_viewport().scaling_3d_scale = 1.0 if quality >= 1 else 0.7
		for p in players:
			p.blob.visible = quality < 2

# Test only: a scripted "thumb" that plays through the same inputs as a person, to exercise the human code paths.
func _bot_inputs(dt: float) -> void:
	for h in humans:
		var p = h.ctrl
		if p == null:
			continue
		var s := side(h.team)
		var id: int = h.get_instance_id()
		var t: float = bot_t.get(id, 0.0) - dt
		h.sprint = true
		if ball_owner == p:
			bstats["have"] += 1
			var goal := Vector3(HL * s, 0, 0)
			var dist: float = p.position.distance_to(goal)
			h.stick = Vector2(s, clampf(-p.position.z * 0.05, -0.5, 0.5)).normalized()
			if h.charging:
				if h.charge > 0.55:
					h.evs.append("shoot_up")
					bstats["shots"] += 1
			elif dist < 21.0 and t <= 0.0:
				h.evs.append("shoot_down")
				t = 1.0
			elif t <= 0.0:
				var nd := 99.0
				for o in teams[1 - h.team]:
					nd = minf(nd, o.position.distance_to(p.position))
				if nd < 3.5:
					h.evs.append("pass_down")
					h.evs.append("pass_up")
					bstats["passes"] += 1
					t = 0.5
		elif ball_owner != null and ball_owner.team == h.team:
			h.stick = Vector2(s * 0.6, 0)
		else:
			var to: Vector3 = ball.position - p.position
			to.y = 0.0
			h.stick = Vector2(to.x, to.z).normalized() if to.length() > 0.3 else Vector2.ZERO
			if t <= 0.0:
				if ball_owner != null and to.length() < 1.9:
					h.evs.append("shoot_down")
					h.evs.append("shoot_up")
					bstats["tackles"] += 1
					t = 0.9
				elif to.length() > 14.0:
					h.evs.append("pass_down")
					h.evs.append("pass_up")
					bstats["switches"] += 1
					t = 1.2
		bot_t[id] = t
