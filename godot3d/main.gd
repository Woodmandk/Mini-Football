extends Node3D
# Banebold 3D prototype: one 11v11 match, built entirely in code.
# x runs along the pitch (red attacks +x), z across it, y is up. Units are metres.

const PlayerS := preload("res://player.gd")
const HudS := preload("res://hud.gd")
const Sfx := preload("res://sfx.gd")
const World := preload("res://world.gd")
const NetS := preload("res://net.gd")
const Career := preload("res://career.gd")

const DIVE_V := 4.9
const HL := 52.5
const TEMPO := 1.25
const SLIDE_T := 0.38
const SLIDE_V := 23.0
const HW := 34.0
const GOAL_HW := 3.66
const GOAL_H := 2.44
const BALL_R := 0.2
const LENGTHS := [180.0, 300.0, 480.0] # real seconds for 90 minutes
const LEN_NAMES := ["3 MIN", "5 MIN", "8 MIN"]
const DIFF_NAMES := ["EASY", "NORMAL", "HARD"]
const SND_NAMES := ["FULL", "LOW", "OFF"]
const DIFF := [
	{"need": 0.70, "spd": 0.86, "err": 3.0, "think": 0.70, "wait": 3.2},
	{"need": 0.50, "spd": 0.92, "err": 1.9, "think": 0.45, "wait": 2.2},
	{"need": 0.38, "spd": 0.98, "err": 1.0, "think": 0.28, "wait": 1.4},
]
# your own computer-run team mates
const MATE := {"need": 0.45, "spd": 1.0, "err": 0.6, "think": 0.22, "wait": 1.4}
# Formations: [role, along 0..1, across -1..1]. Slot 9 is always a central forward and slot 6 a central midfielder (they take the kick-off).
const FORMS := {
	"4-3-3": [
		["GK", 0.0, 0.0],
		["DF", 0.22, -0.78], ["DF", 0.17, -0.27], ["DF", 0.17, 0.27], ["DF", 0.22, 0.78],
		["MF", 0.42, -0.45], ["MF", 0.37, 0.0], ["MF", 0.42, 0.45],
		["FW", 0.68, -0.72], ["FW", 0.72, 0.0], ["FW", 0.68, 0.72],
	],
	"4-4-2": [
		["GK", 0.0, 0.0],
		["DF", 0.22, -0.78], ["DF", 0.17, -0.27], ["DF", 0.17, 0.27], ["DF", 0.22, 0.78],
		["MF", 0.44, -0.76], ["MF", 0.38, -0.24], ["MF", 0.38, 0.24], ["MF", 0.44, 0.76],
		["FW", 0.70, -0.22], ["FW", 0.70, 0.22],
	],
	"3-5-2": [
		["GK", 0.0, 0.0],
		["DF", 0.18, -0.46], ["DF", 0.15, 0.0], ["DF", 0.18, 0.46],
		["MF", 0.44, -0.82], ["MF", 0.38, -0.36], ["MF", 0.31, 0.0], ["MF", 0.38, 0.36], ["MF", 0.44, 0.82],
		["FW", 0.70, -0.22], ["FW", 0.70, 0.22],
	],
	"5-3-2": [
		["GK", 0.0, 0.0],
		["DF", 0.27, -0.82], ["DF", 0.18, -0.42], ["DF", 0.15, 0.0], ["DF", 0.18, 0.42], ["DF", 0.27, 0.82],
		["MF", 0.38, 0.0], ["MF", 0.42, -0.44], ["MF", 0.42, 0.44],
		["FW", 0.70, -0.22], ["FW", 0.70, 0.22],
	],
	"4-2-3-1": [
		["GK", 0.0, 0.0],
		["DF", 0.22, -0.78], ["DF", 0.17, -0.27], ["DF", 0.17, 0.27], ["DF", 0.22, 0.78],
		["MF", 0.34, -0.24], ["MF", 0.34, 0.24], ["MF", 0.54, 0.0],
		["FW", 0.64, -0.72], ["FW", 0.74, 0.0], ["FW", 0.64, 0.72],
	],
}
const FORM_NAMES := ["4-3-3", "4-4-2", "3-5-2", "5-3-2", "4-2-3-1"]
var forms := ["4-3-3", "4-3-3"]
var opt_car := false
var sq_over := []
var form_over := ""
var co_got := false
var test_ft := 0.0
var wd_clock := -1.0
var wd_n := 0
var wd_all := 0
var test_t := 0.0
var co_text := ""
var co_pay := []
const NAMES := [
	["Holm", "Berg", "Lund", "Dahl", "Krogh", "Skov", "Winther", "Bak", "Friis", "Storm", "Juhl"],
	["Marsh", "Reed", "Cole", "Hale", "Frost", "Quinn", "Drake", "Nash", "Voss", "Pike", "Lowe"],
]
const NUMS := [1, 3, 4, 5, 2, 8, 6, 10, 11, 9, 7]
const CLUBS0 := [ # name, short, home kit [shirt, shorts, socks], away kit
	{"n": "RED BISON", "s": "BIS", "k": ["dc2424", "f7f7f7", "dc2424"], "a": ["f7f7f7", "dc2424", "f7f7f7"]},
	{"n": "HARBOUR SHARKS", "s": "SHA", "k": ["2961eb", "142466", "f7f7f7"], "a": ["f2f2f2", "142466", "2961eb"]},
	{"n": "SKY ROVERS", "s": "ROV", "k": ["7fd0ff", "f7f7f7", "7fd0ff"], "a": ["16213a", "7fd0ff", "16213a"]},
	{"n": "GOLDEN LIONS", "s": "LIO", "k": ["f5c518", "1a1a1a", "f5c518"], "a": ["1a1a1a", "f5c518", "1a1a1a"]},
	{"n": "BLACK WOLVES", "s": "WOL", "k": ["1c1c20", "1c1c20", "e8e8e8"], "a": ["e8e8e8", "1c1c20", "1c1c20"]},
	{"n": "WHITE STORKS", "s": "STO", "k": ["f4f4f4", "c62828", "f4f4f4"], "a": ["c62828", "f4f4f4", "c62828"]},
	{"n": "PURPLE KINGS", "s": "KIN", "k": ["7b2fbf", "f7f7f7", "7b2fbf"], "a": ["f7d94a", "7b2fbf", "f7d94a"]},
	{"n": "ORANGE FOXES", "s": "FOX", "k": ["f57c00", "1a1a1a", "f57c00"], "a": ["1a1a1a", "f57c00", "1a1a1a"]},
]
const SURNAMES := ["Holm", "Berg", "Lund", "Dahl", "Krogh", "Skov", "Winther", "Bak", "Friis", "Storm", "Juhl", "Marsh", "Reed", "Cole", "Hale", "Frost", "Quinn", "Drake", "Nash", "Voss", "Pike", "Lowe", "Brandt", "Falk", "Lind", "Mohr", "Ravn", "Stein", "Toft", "Vang", "Kaas", "Bro", "Gram", "Hede", "Kjaer", "Munk", "Noer", "Rask", "Sand", "Thorn", "Ward", "Blake", "Cross", "Dunn", "Ellis", "Ford", "Grant", "Hart", "Kane", "Moss", "Price", "Rhodes", "Shaw", "Tate", "Wolfe", "York", "Abel", "Bech", "Dam", "Eskild"]
var CLUBS: Array = CLUBS0.duplicate(true) # the league as it is now: your own club sits in its place with your name and kit
var own_new := false
var upd_ready := false
var upd_t := 3.0
var app_inst := false
const OWN_COLS := ["dc2424", "f57c00", "f5c518", "2e9e4f", "7fd0ff", "2961eb", "142466", "7b2fbf", "e85aa0", "f4f4f4", "8a8f98", "1c1c20"]
var TEAM_NAMES := ["RED BISON", "HARBOUR SHARKS"]
var opt_club := 0
var guest_club := 1
var clubs := [0, 1]
var kits := [[], []]
var teams_from := "main"
var car
var career_on := false
var car_goals := []
var car_lines := []
var car_sel := -1
var car_msg := ""
var car_sure := false
var car_sell := -1
var subs_left := 3
var sub_sel := -1
var sub_off := []
var sub_played := []
const CAMS := ["TV", "TOP", "CLOSE"]
const N_F := 11 # numbers per player in a packed frame

class Human:
	var dead_t := 0.0
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
	var stam := 1.0
	var skill_cool := 0.0
	var auto_cool := 0.0
	var lob_hold := -1.0
	var thru_hold := -1.0
	var hi := false
	var def_hold := -1.0
	var pull_n := 0
	var shc := 0.0
	var ot := 0
	var ot_t := 0.0
	var pull_t := 0.0
	var meter := 0.0
	var tired := false

var players := []
var teams := [[], []]
var humans := []
var me := 0
var view_flip := 1.0

var ball: Node3D
var ball_mesh: MeshInstance3D
var ball_top: MeshInstance3D
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
var hit_ring: MeshInstance3D
var hit_t := 9.0
var hit_k := 1.0
var meter_bg: MeshInstance3D
var meter_fg: MeshInstance3D
var meter_mat: StandardMaterial3D
var aim_arrow: MeshInstance3D
var aim_hold: Node3D
var ball_net := Vector3.ZERO
var ball_spin := 0.0
var pass_from = null

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
var opt_snd := 0
var opt_voice := true
var opt_len := 1
var opt_mode := "coop"
var room := ""
var wait_friend := 0.0
var start_msg = null
var tick_n := 0
var net_acc := 0.0
var rec_acc := 0.0
var tdt := 1.0 / 60.0
var sup := [[], []]
var runner := [[], []]
var att_team := -1
var pass_pw := -1.0
var test_meter := OS.get_cmdline_user_args().has("--meter")
var car_dir := Vector3.ZERO
var _keys := {}

var rec := []
var goal_idx := 0
var rp_pos := 0.0
var rp_to := 0
var anim_rate := 1.0

var cam: Camera3D
var cam_mode := 1
var bot_thru := false
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
var hub_tab := "play"
var pack_res := {}
var bot_mode := ""
var bot_t := {}
var bstats := {"have": 0, "shots": 0, "passes": 0, "tackles": 0, "switches": 0}
var quality := 2
var base_scale := 1.0
var slow_t := 0.0
var intro_len := 2.6
var intro_t0 := -99.0
var q_applied := -1
var demo := false
var shot_path := ""
var shot_at := 0.0
var force_goal := -1.0
var force_kind := ""
var _sprint_was := false
var _sprint_t := -9.0
var real_t := 0.0
var version := "dev"
var shp := [[0, 0, 0, 0, 0], [0, 0, 0, 0, 0]]
var autotest_on := OS.get_cmdline_user_args().has("--autotest")
var bot_slide := OS.get_cmdline_user_args().has("--slide")
var long_test := OS.get_cmdline_user_args().has("--longtest")
var long_t := 0.0
var long_n := 0
var long_d := 24.0
var long_pw := 1.0
var long_aim := 0.62
var long_arm := 0.0
var bot_hold := OS.get_cmdline_user_args().has("--hold")
var tst := [{"shots": 0, "fouls": 0, "poss": 0, "saves": 0, "g": []}, {"shots": 0, "fouls": 0, "poss": 0, "saves": 0, "g": []}]
var stats := {"shots": 0, "passes": 0, "tackles": 0, "outs": 0, "saves": 0, "goals": 0, "fouls": 0, "offsides": 0, "pens": 0, "cards": 0}

func side(t: int) -> float:
	return 1.0 if t == 0 else -1.0

func _ready() -> void:
	var menu_arg := ""
	var new_car := false
	var car_test := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--longd="):
			long_d = float(a.substr(8))
		if a.begins_with("--longaim="):
			long_aim = float(a.substr(10))
		if a.begins_with("--longpw="):
			long_pw = float(a.substr(9))
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
		elif a == "--thru":
			bot_thru = true
		elif a.begins_with("--cam="):
			cam_mode = int(a.substr(6))
		elif a.begins_with("--menu="):
			menu_arg = a.substr(7)
		elif a.begins_with("--bot="):
			bot_mode = a.substr(6)
		elif a == "--newcareer":
			new_car = true
		elif a == "--career":
			car_test = true
		elif a.begins_with("--force="):
			force_kind = a.substr(8)
		elif a.begins_with("--clubs="):
			var cc := a.substr(8).split(",")
			opt_club = int(cc[0])
			clubs = [int(cc[0]), int(cc[1])]
		elif a.begins_with("--scale="):
			base_scale = float(a.substr(8))
		elif a.begins_with("--diff="):
			opt_diff = int(a.substr(7))
	if FileAccess.file_exists("res://version.txt"):
		version = FileAccess.get_file_as_string("res://version.txt").strip_edges()
	net = NetS.new()
	car = Career.new()
	car.names = SURNAMES
	car.load_save(net.web)
	_apply_own()
	if new_car:
		car.wipe()
	if net.web:
		dbg = str(JavaScriptBridge.eval("location.search", true)).contains("dbg")
		var qs := str(JavaScriptBridge.eval("location.search", true))
		if qs.contains("ft="):
			test_ft = float(qs.split("ft=")[1].split("&")[0])
		if str(JavaScriptBridge.eval("location.search", true)).contains("low"):
			quality = 0
		seen_how = str(JavaScriptBridge.eval("(function(){try{return localStorage.getItem('bb3d-how')||''}catch(e){return ''}})()", true)) == "1"
		var ss := str(JavaScriptBridge.eval("(function(){try{return localStorage.getItem('bb3d-snd')||''}catch(e){return ''}})()", true))
		if ss.length() == 2 and ss.is_valid_int():
			opt_snd = clampi(int(ss.substr(0, 1)), 0, 2)
			opt_voice = ss.substr(1, 1) == "1"
		var sc := str(JavaScriptBridge.eval("(function(){try{return localStorage.getItem('bb3d-club')||''}catch(e){return ''}})()", true))
		if sc.is_valid_int():
			opt_club = clampi(int(sc), 0, CLUBS.size() - 1)
			clubs = [opt_club, 1 if opt_club != 1 else 0]
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
	hud.set_teams(TEAM_NAMES, [CLUBS[clubs[0]]["s"], CLUBS[clubs[1]]["s"]], [Color(kits[0][0]), Color(kits[1][0])])
	_build_fx()
	_build_audio()
	_apply_sound(false)
	if autotest or demo:
		screen = "match"
		if car_test:
			if not car.has_save():
				car.new_career(opt_club, CLUBS.size(), SURNAMES)
			career_on = true
			_set_clubs(int(car.d["club"]), car.next_match()[0], true)
		_begin_match(demo and OS.get_cmdline_user_args().has("--intro"))
		if car_test and menu_arg in ["subs", "pause"]:
			for p in players:
				p.fit = randf_range(0.4, 1.0)
			_substitute(9, 12)
			sub_sel = 7
			print("SUBTEST ", teams[0][9].pname, " num=", teams[0][9].num, " left=", subs_left, " played=", sub_played)
			hud.show_menu(menu_arg, _menu_info())
		if OS.get_cmdline_user_args().has("--passtest"):
			# measures passes: speed off the foot, time to the receiver, speed and height on arrival
			for lofted in [false, true]:
				for dd in [6.4, 10.0, 15.0, 20.0, 30.0, 40.0]:
					var pp = teams[0][9]
					var mm = teams[0][6]
					pp.position = Vector3(-20, 0, 0)
					mm.position = Vector3(-20 + dd, 0, 0)
					mm.vel = Vector3.ZERO
					ball_owner = pp
					set_piece = ""
					_pass(pp, mm, lofted)
					var v0 := Vector2(ball_vel.x, ball_vel.z).length()
					var tt := 0.0
					var apex := 0.0
					var bounces := 0
					var was_up := true
					while ball.position.x < mm.position.x - 0.5 and tt < 8.0 and Vector2(ball_vel.x, ball_vel.z).length() > 0.05:
						_ball_free(1.0 / 60.0)
						tt += 1.0 / 60.0
						apex = maxf(apex, ball.position.y)
						if ball.position.y <= BALL_R + 0.01 and was_up:
							bounces += 1
						was_up = ball.position.y > BALL_R + 0.01
					print("PASSTEST lofted=", lofted, " d=", dd, " v0=", snappedf(v0, 0.1), " t=", snappedf(tt, 0.01), " arrive_v=", snappedf(Vector2(ball_vel.x, ball_vel.z).length(), 0.1), " y=", snappedf(ball.position.y, 0.01), " apex=", snappedf(apex, 0.1), " reached=", ball.position.x >= mm.position.x - 0.6, " landings=", bounces)
			for dd2 in [12.0, 25.0, 38.0]:
				for rep in 3:
					_kickoff(0)
					var p2 = teams[0][6]
					var m2 = teams[0][9]
					p2.position = Vector3(-30, 0, -5 + rep * 5)
					m2.position = Vector3(-30 + dd2, 0, rep * 6 - 6)
					ball_owner = p2
					set_piece = ""
					state = "play"
					_pass(p2, m2, true)
					var t2 := 0.0
					while ball_owner == null and t2 < 6.0 and state == "play":
						_tick(1.0 / 60.0)
						t2 += 1.0 / 60.0
					print("LOBTEST d=", dd2, " got=", players.find(ball_owner), " (want 9) t=", snappedf(t2, 0.01), " state=", state, " recv_dist_from_start=", snappedf(m2.position.distance_to(Vector3(-30 + dd2, 0, rep * 6 - 6)), 0.1))
			# receiver lock: a human passes for real and then holds the stick in every direction
			humans = [Human.new()]
			for sd in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2.ZERO]:
				for dd3 in [8.0, 16.0, 26.0]:
					_kickoff(0)
					for q in players:
						if q.team == 1:
							q.position = Vector3(40, 0, q.position.z)
					var p3 = teams[0][6]
					var m3 = teams[0][9]
					p3.position = Vector3(-30, 0, 0)
					m3.position = Vector3(-30 + dd3, 0, 3)
					p3.yaw = atan2(-1.0, 0.0)
					ball_owner = p3
					ball_last = p3
					set_piece = ""
					protect_t = 0.0
					state = "play"
					var h3 = humans[0]
					h3.ctrl = p3
					h3.stick = Vector2(1, 0.15)
					_tick(1.0 / 60.0)
					h3.evs.append("pass_down")
					_tick(1.0 / 60.0)
					h3.evs.append("pass_up")
					var t3 := 0.0
					var who := -2
					var rc := false
					while t3 < 5.0 and state == "play":
						if t3 > 0.05:
							h3.stick = sd
						_tick(1.0 / 60.0)
						t3 += 1.0 / 60.0
						if t3 < 0.1:
							who = players.find(h3.ctrl)
							rc = h3.ctrl.recv
						if ball_owner != null and t3 > 0.2:
							break
					print("LOCKTEST stick=", sd, " d=", dd3, " ctrl_after_pass=", who, " recv=", rc, " got=", players.find(ball_owner), " t=", snappedf(t3, 0.01), " state=", state)
			get_tree().quit()
			return
		if autotest or demo:
			if bot_mode != "":
				humans = [Human.new()]
				if bot_mode != "solo" and bot_mode != "dribble":
					var h2 := Human.new()
					h2.team = 0 if bot_mode == "coop" else 1
					humans.append(h2)
			_kickoff(0)
	else:
		_to_menu()
		if menu_arg != "":
			if menu_arg == "full":
				tst[0]["g"] = ["STORM 12'", "BAK 40'"]
				tst[1]["g"] = ["PIKE 77'"]
			if menu_arg.begins_with("hub_"):
				hub_tab = menu_arg.substr(4)
				menu_arg = "main"
			if menu_arg == "myclub":
				_own_start()
			if menu_arg == "pack":
				pack_res = {"n": "NORDIN", "pos": "FW", "age": 21, "pot": 84, "ovr": 77, "st": [80, 79, 66, 41]}
			if menu_arg in ["career", "table", "cfull", "market", "club"] or menu_arg.begins_with("squad"):
				_action("career")
			if menu_arg == "seasontest":
				_action("career")
				print("SEASONTEST fac_up=", car.fac_up("stadium"), " coins=", car.d["coins"])
				while not car.season_over():
					var ln: Array = car.finish_match(2, 1, [9])
					print("SEASONTEST r=", car.d["round"], " ", ln.slice(0, 2), " ", ln.filter(func(x): return str(x).begins_with("YOUTH")))
				print("SEASONTEST note=", car.d["note"], " squad=", car.d["squad"].size(), " coins=", car.d["coins"])
				car.next_season()
				print("SEASONTEST next season=", car.d["season"], " round=", car.d["round"], " over=", car.season_over())
				menu_arg = "career"
			if menu_arg == "buytest":
				_action("career")
				car.d["coins"] = 3000
				for bi in 3:
					_action("c_buy", 0)
				print("BUYTEST after buy size=", car.d["squad"].size(), " coins=", car.d["coins"], " msg=", car_msg)
				car_sel = 12
				_action("c_sell")
				_action("c_sell")
				print("BUYTEST after sell size=", car.d["squad"].size(), " coins=", car.d["coins"], " msg=", car_msg, " xi=", car.d["xi"])
				car_sel = 13
				menu_arg = "squad9"
			if menu_arg.begins_with("squad"):
				for fi2 in (int(menu_arg.substr(5)) % 9) if menu_arg.length() > 5 else 0:
					_action("c_form")
				if menu_arg != "squad9":
					car_sel = 9
					if menu_arg == "squad7":
						car.d["squad"][9]["tp"] = 2
				menu_arg = "squad"
			if menu_arg == "cfull":
				career_on = true
				_set_clubs(int(car.d["club"]), car.next_match()[0], true)
				score = [2, 1]
				tst[0]["g"] = ["STORM 12'", "BAK 40'"]
				tst[1]["g"] = ["PIKE 77'"]
				car_lines = car.finish_match(2, 1, [9, 9])
				car_lines.append_array(["YOUTH: HART (18, DF) JOINS, CAN REACH 74", "BLAKE  +1 DEFENDING", "NASH  +1 SHOOTING", "STORM  +1 PACE", "KROGH  +1 PASSING", "LUND  +1 PACE", "2ND IN THE TABLE"])
				menu_arg = "full"
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
	ball_top = MeshInstance3D.new()
	var bt := CylinderMesh.new()
	bt.top_radius = 0.56
	bt.bottom_radius = 0.56
	bt.height = 0.02
	bt.radial_segments = 24
	ball_top.mesh = bt
	var btm := StandardMaterial3D.new()
	btm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	btm.albedo_color = Color(0.02, 0.03, 0.02)
	ball_top.material_override = btm
	ball_top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball_top.visible = false
	ball_top.top_level = true
	ball.add_child(ball_top)
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
	# power meter on the grass at the player's feet
	meter_bg = MeshInstance3D.new()
	var mq := BoxMesh.new()
	mq.size = Vector3(1.0, 0.02, 1.0)
	meter_bg.mesh = mq
	var mb := StandardMaterial3D.new()
	mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mb.albedo_color = Color(0.04, 0.06, 0.05, 0.75)
	mb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	meter_bg.material_override = mb
	meter_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	meter_bg.visible = false
	add_child(meter_bg)
	meter_fg = MeshInstance3D.new()
	meter_fg.mesh = mq
	meter_mat = StandardMaterial3D.new()
	meter_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	meter_fg.material_override = meter_mat
	meter_fg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	meter_fg.visible = false
	add_child(meter_fg)
	aim_arrow = MeshInstance3D.new()
	var am := PrismMesh.new()
	am.size = Vector3(0.55, 0.7, 0.02)
	aim_arrow.mesh = am
	var amat := StandardMaterial3D.new()
	amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	amat.albedo_color = Color(1, 1, 1, 0.92)
	amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amat.cull_mode = BaseMaterial3D.CULL_DISABLED
	aim_arrow.material_override = amat
	aim_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_arrow.visible = false
	# the prism lies flat on the grass with its tip pointing forward (-Z)
	var ah := Node3D.new()
	add_child(ah)
	aim_arrow.rotation.x = -PI * 0.5
	ah.add_child(aim_arrow)
	aim_arrow = ah.get_child(0)
	aim_hold = ah
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
	# a quick white ring on the grass where the ball is struck
	hit_ring = MeshInstance3D.new()
	var ht := TorusMesh.new()
	ht.inner_radius = 0.82
	ht.outer_radius = 1.0
	hit_ring.mesh = ht
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.albedo_color = Color(1, 1, 1, 0.8)
	hit_ring.material_override = hm
	hit_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hit_ring.visible = false
	add_child(hit_ring)

static func _cdist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

# Picks which clubs play (team 0 and team 1) and rebuilds the 22 players in their kits.
func _set_clubs(a: int, b: int, force := false) -> void:
	a = clampi(a, 0, CLUBS.size() - 1)
	b = clampi(b, 0, CLUBS.size() - 1)
	if not players.is_empty() and clubs[0] == a and clubs[1] == b and not force:
		return
	clubs = [a, b]
	forms = [FORM_NAMES[a % 3], FORM_NAMES[(b * 2 + 1) % FORM_NAMES.size()]]
	if career_on:
		forms[0] = car.form()
	elif form_over != "":
		forms[0] = form_over
	for p in players:
		p.queue_free()
	players.clear()
	teams = [[], []]
	ball_owner = null
	ball_last = null
	ball_ignore = null
	scorer = null
	rec.clear()
	for hm in humans:
		hm.ctrl = null
	_build_teams()

func _other_club(mine: int) -> int:
	var o := randi() % (CLUBS.size() - 1)
	return o if o < mine else o + 1

func _build_teams() -> void:
	var skins := [Color(0.96, 0.80, 0.66), Color(0.87, 0.67, 0.50), Color(0.62, 0.43, 0.29), Color(0.42, 0.28, 0.19), Color(0.93, 0.76, 0.60)]
	var hairs := [Color(0.1, 0.08, 0.06), Color(0.3, 0.19, 0.1), Color(0.75, 0.6, 0.3), Color(0.05, 0.05, 0.05), Color(0.5, 0.3, 0.15)]
	var kit0: Array = CLUBS[clubs[0]]["k"]
	var kit1: Array = CLUBS[clubs[1]]["k"]
	if clubs[0] == clubs[1] or _cdist(Color(kit0[0]), Color(kit1[0])) < 0.5:
		kit1 = CLUBS[clubs[1]]["a"]
	kits = [kit0, kit1]
	TEAM_NAMES = [CLUBS[clubs[0]]["n"], CLUBS[clubs[1]]["n"]]
	var gk_cols := [Color("f5d020"), Color("30d070"), Color("ff5fa2"), Color("9aa0a6"), Color("00c2c7")]
	var gk_used := []
	for t in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = clubs[t] * 977 + 7
		var names := SURNAMES.duplicate()
		for n in range(names.size() - 1, 0, -1):
			var sw := rng.randi_range(0, n)
			var tmp = names[n]
			names[n] = names[sw]
			names[sw] = tmp
		var gk_col: Color = gk_cols[0]
		for c in gk_cols:
			if _cdist(c, Color(kits[0][0])) > 0.5 and _cdist(c, Color(kits[1][0])) > 0.5 and not gk_used.has(c):
				gk_col = c
				break
		gk_used.append(gk_col)
		var FORM: Array = FORMS[forms[t]]
		for i in FORM.size():
			var p = PlayerS.new()
			p.team = t
			p.idx = i
			p.role = FORM[i][0]
			p.home = Vector2(FORM[i][1], FORM[i][2])
			p.pname = names[i]
			p.num = NUMS[i]
			if career_on and t == 0:
				p.num = int(car.d["squad"][int(car.d["xi"][i])]["num"])
			elif t == 0 and sq_over.size() == 11:
				p.pname = str(sq_over[i][0])
				p.num = int(sq_over[i][1])
			var shirt := Color(kits[t][0])
			var shorts := Color(kits[t][1])
			var socks := Color(kits[t][2])
			if p.role == "GK":
				shirt = gk_col
				shorts = Color(0.1, 0.1, 0.1)
				socks = shirt
			var boots: Color = [Color(0.08, 0.08, 0.08), Color(0.95, 0.95, 0.95), Color(1.0, 0.45, 0.1), Color(0.3, 0.9, 0.9)][rng.randi() % 4]
			p.build(shirt, shorts, socks, skins[rng.randi() % skins.size()], hairs[rng.randi() % hairs.size()], boots)
			var base: Array = {"GK": [52, 30, 62, 74], "DF": [68, 46, 64, 76], "MF": [70, 66, 77, 64], "FW": [79, 77, 66, 42]}[p.role]
			var up := 0
			p.star = i == 9 or i == (6 + clubs[t] % 2)
			if p.star:
				up = 8
			p.pac = clampi(base[0] + up + rng.randi_range(-5, 5), 40, 96)
			p.sho = clampi(base[1] + up + rng.randi_range(-5, 5), 25, 96)
			p.pas = clampi(base[2] + up + rng.randi_range(-5, 5), 40, 96)
			p.dfn = clampi(base[3] + up + rng.randi_range(-5, 5), 25, 96)
			match p.role:
				"GK": p.ovr = int(round(p.dfn * 0.8 + p.pas * 0.2))
				"DF": p.ovr = int(round(p.dfn * 0.55 + p.pac * 0.25 + p.pas * 0.2))
				"MF": p.ovr = int(round(p.pas * 0.45 + p.pac * 0.2 + p.sho * 0.2 + p.dfn * 0.15))
				_: p.ovr = int(round(p.sho * 0.5 + p.pac * 0.35 + p.pas * 0.15))
			if career_on:
				if t == 0:
					# your own squad: the eleven you picked, with their own numbers
					var pl: Dictionary = car.d["squad"][int(car.d["xi"][i])]
					var off_pos := -6 if str(pl["pos"]) != p.role else 0
					p.sq = int(car.d["xi"][i])
					p.pname = str(pl["n"])
					p.pac = int(pl["pac"]) + off_pos
					p.sho = int(pl["sho"]) + off_pos
					p.pas = int(pl["pas"]) + off_pos
					p.dfn = int(pl["dfn"]) + off_pos
					p.ovr = Career.ovr_of(pl) + off_pos
					p.star = false
				else:
					var lv: int = car.club_level(clubs[t])
					p.pac += lv
					p.sho += lv
					p.pas += lv
					p.dfn += lv
					p.ovr += lv
			_derive(p)
			p.top_speed = p.base_top
			add_child(p)
			players.append(p)
			teams[t].append(p)
	if hud != null:
		hud.set_teams(TEAM_NAMES, [CLUBS[clubs[0]]["s"], CLUBS[clubs[1]]["s"]], [Color(kits[0][0]), Color(kits[1][0])])
		hud.set_score(score[0], score[1])

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
		"blip2": Sfx.blip(1320.0), "whoosh": Sfx.whoosh(), "slide": Sfx.slide(), "win": Sfx.win(), "thud": Sfx.thud(), "jingle": Sfx.jingle(),
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
			hit_t = 0.0
			hit_k = clampf(float(a), 0.25, 1.0)
			hit_ring.position = Vector3(ball.position.x, 0.06, ball.position.z)
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
			if opt_voice and opt_snd != 2:
				net.say(a)
		"toast":
			hud.toast(a)
		"vs":
			var st := []
			for t in 2:
				var best = teams[t][9]
				for q in teams[t]:
					if q.ovr > best.ovr:
						best = q
				st.append("%d  %s  %d" % [best.num, best.pname.to_upper(), best.ovr])
			hud.show_vs(float(a), TEAM_NAMES, st, view_flip < 0.0)
			intro_t0 = real_t if float(a) > 0.0 else -99.0
			if float(a) > 0.0:
				cam_pos = Vector3(-56, 5.0, 40 * view_flip)
				cam_look = Vector3(-20, 1, 0)

func _banner(text: String, col: Color, hold: float, small := "", fs := 96) -> void:
	fx("banner", [text, col.to_html(), hold, small, fs])

# ---------------------------------------------------------------- menu and online lobby

func _menu_info() -> Dictionary:
	return {
		"diff": DIFF_NAMES[opt_diff], "len": LEN_NAMES[opt_len], "mode": opt_mode, "code": room,
		"connected": net.connected, "role": net.role, "version": version, "web": net.web, "snd": SND_NAMES[opt_snd], "voice": opt_voice,
		"score": "%d - %d" % [score[0], score[1]], "online": net.role != "", "result": _result(), "stats": _stat_rows(), "club": opt_club, "gclub": guest_club, "clubs": CLUBS, "from": teams_from,
		"car": _car_info(), "upd": upd_ready, "inst": app_inst, "own_new": own_new, "own_cols": OWN_COLS, "tab": hub_tab, "pstats": car.stats() if car.has_save() else {}, "packs": car.packs() if car.has_save() else [], "pack": pack_res, "career": career_on, "subs": _subs_info(), "can_sub": career_on and net.role != "guest" and screen == "match", "car_lines": car_lines, "co_text": _co_text() if net.role == "host" else co_text, "has_car": car.has_save(),
		"g0": ",  ".join(PackedStringArray(tst[0].get("g", []))), "g1": ",  ".join(PackedStringArray(tst[1].get("g", []))),
	}

# The substitution screen: who is on the pitch and how tired, and who is on the bench.
func _subs_info() -> Dictionary:
	if not career_on or teams[0].size() < 11:
		return {}
	var on := []
	var on_sq := []
	for p in teams[0]:
		on.append({"slot": p.idx, "n": p.pname.to_upper(), "num": p.num, "role": p.role, "ovr": p.ovr, "fit": p.fit, "off": p.off})
		on_sq.append(p.sq)
	var bench := []
	for i in (car.d["squad"] as Array).size():
		if on_sq.has(i) or sub_off.has(i):
			continue
		var pl: Dictionary = car.d["squad"][i]
		bench.append({"sq": i, "n": str(pl["n"]).to_upper(), "num": int(pl["num"]), "pos": str(pl["pos"]), "ovr": Career.ovr_of(pl)})
	return {"left": subs_left, "on": on, "bench": bench, "sel": sub_sel}

# Bring a bench player on for the man in this place. He takes over the place with fresh legs.
func _substitute(slot: int, sq_i: int) -> void:
	if subs_left <= 0 or slot < 0 or slot >= teams[0].size() or sub_off.has(sq_i):
		return
	var p = teams[0][slot]
	if p.off:
		return
	var pl: Dictionary = car.d["squad"][sq_i]
	var old_name: String = p.pname
	sub_off.append(p.sq)
	if not sub_played.has(sq_i):
		sub_played.append(sq_i)
	var off_pos := -6 if str(pl["pos"]) != p.role else 0
	p.sq = sq_i
	p.pname = str(pl["n"])
	p.set_num(int(pl["num"]))
	p.pac = int(pl["pac"]) + off_pos
	p.sho = int(pl["sho"]) + off_pos
	p.pas = int(pl["pas"]) + off_pos
	p.dfn = int(pl["dfn"]) + off_pos
	p.ovr = Career.ovr_of(pl) + off_pos
	_derive(p)
	p.fit = 1.0
	subs_left -= 1
	snd("whistle")
	fx("say", "Substitution. %s comes on for %s." % [p.pname, old_name])
	hud.toast("%s ON  ·  %s OFF" % [p.pname.to_upper(), old_name.to_upper()])

func _fac_info() -> Array:
	var out := []
	var txt := {
		"stadium": ["STADIUM", "More people at your home matches.", "+%d coins from the gate at home"],
		"training": ["TRAINING GROUND", "Players learn faster and training costs less.", "+%d%% XP from matches"],
		"youth": ["YOUTH ACADEMY", "A young talent joins twice a season.", "Talents who can reach about %d"],
	}
	for k in Career.FAC_KEYS:
		var lv: int = car.fac(k)
		var now := ""
		var nxt := ""
		match k:
			"stadium":
				now = txt[k][2] % (lv * 9)
				nxt = txt[k][2] % ((lv + 1) * 9)
			"training":
				now = (txt[k][2] % ((lv - 1) * 15)) if lv > 1 else "Normal XP from matches"
				nxt = txt[k][2] % (lv * 15)
			_:
				now = txt[k][2] % (66 + lv * 4)
				nxt = txt[k][2] % (70 + lv * 4)
		out.append({"k": k, "n": txt[k][0], "what": txt[k][1], "lv": lv, "max": Career.FAC_MAX, "now": now, "next": nxt if lv < Career.FAC_MAX else "", "cost": car.fac_cost(k)})
	return out

# Everything the career screens show.
func _car_info() -> Dictionary:
	if not car.has_save():
		return {}
	var d: Dictionary = car.d
	var me_c: int = int(d["club"])
	var nm: Array = car.next_match()
	var rows := []
	var ord: Array = car.order()
	for i in ord.size():
		var c: int = ord[i]
		var t: Dictionary = d["table"][c]
		rows.append([i + 1, CLUBS[c]["n"], int(t["p"]), int(t["w"]), int(t["d"]), int(t["l"]), int(t["gf"]) - int(t["ga"]), int(t["pts"]), c == me_c, CLUBS[c]["k"][0]])
	var last := []
	for r in d["last"]:
		last.append("%s  %d - %d  %s" % [CLUBS[int(r[0])]["s"], int(r[2]), int(r[3]), CLUBS[int(r[1])]["s"]])
	var squad := []
	for i in (d["squad"] as Array).size():
		var pl: Dictionary = d["squad"][i]
		squad.append({"n": str(pl["n"]).to_upper(), "num": int(pl["num"]), "pos": str(pl["pos"]), "ovr": Career.ovr_of(pl), "pot": int(pl["pot"]), "age": int(pl["age"]),
			"xp": int(pl["xp"]), "tp": int(pl.get("tp", 0)), "g": int(pl["g"]), "apps": int(pl["apps"]), "st": [int(pl["pac"]), int(pl["sho"]), int(pl["pas"]), int(pl["dfn"])], "cost": car.train_cost(pl), "sell": Career.sell_value(pl)})
	var tp_all := 0
	for pl in d["squad"]:
		tp_all += int(pl.get("tp", 0))
	var mk := []
	for pl in car.market():
		mk.append({"n": str(pl["n"]).to_upper(), "pos": str(pl["pos"]), "ovr": Career.ovr_of(pl), "pot": int(pl["pot"]), "age": int(pl["age"]), "st": [int(pl["pac"]), int(pl["sho"]), int(pl["pas"]), int(pl["dfn"])], "price": Career.value(pl)})
	var roles := []
	for f in FORMS[car.form()]:
		roles.append([f[0], f[1], f[2]])
	return {
		"name": CLUBS[me_c]["n"], "kit": CLUBS[me_c]["k"], "season": int(d["season"]), "round": int(d["round"]), "rounds": car.rounds_total(), "coins": int(d["coins"]),
		"rank": car.rank_of(me_c), "opp": CLUBS[nm[0]]["n"] if nm[0] >= 0 else "", "opp_rank": car.rank_of(nm[0]) if nm[0] >= 0 else 0, "opp_kit": CLUBS[nm[0]]["k"] if nm[0] >= 0 else [],
		"home": nm[1], "over": car.season_over(), "note": str(d.get("note", "")), "last": last, "table": rows, "squad": squad, "xi": d["xi"], "sel": car_sel,
		"fac": _fac_info(), "tp": tp_all, "market": mk, "sell_sure": car_sell, "form": roles, "fname": car.form(), "str": int(round(car.my_strength())), "msg": car_msg, "sure": car_sure,
	}

func _stat_rows() -> Array:
	var tot: int = maxi(tst[0]["poss"] + tst[1]["poss"], 1)
	var p0 := int(round(100.0 * tst[0]["poss"] / tot))
	return [
		["POSSESSION", "%d%%" % p0, "%d%%" % (100 - p0)],
		["SHOTS", str(tst[0]["shots"]), str(tst[1]["shots"])],
		["SAVES", str(tst[0]["saves"]), str(tst[1]["saves"])],
		["FOULS", str(tst[0]["fouls"]), str(tst[1]["fouls"])],
	]

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
	career_on = false
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
		p.set_meta("fouls", 0)
		p.visible = true
	_kickoff(0)
	if not crowd_au.playing:
		crowd_au.play()
	_show_hub()

# Your own club: its name and kit take the place of the club you started as.
func _apply_own() -> void:
	CLUBS = CLUBS0.duplicate(true)
	if not car.has_save() or not car.d.has("own"):
		return
	var o: Dictionary = car.d["own"]
	var k: Array = o["k"]
	var light: bool = Color(str(k[0])).get_luminance() > 0.6
	var alt := "1c1c20" if light else "f4f4f4"
	CLUBS[int(car.d["club"])] = {"n": str(o["n"]), "s": str(o["s"]), "k": [str(k[0]), str(k[1]), str(k[2])], "a": [alt, str(k[0]), alt]}

func _own_start() -> void:
	if not car.d.has("own"):
		var cc: Dictionary = CLUBS[int(car.d["club"])]
		car.d["own"] = {"n": cc["n"], "s": cc["s"], "k": (cc["k"] as Array).duplicate()}

func _own_changed() -> void:
	car.save()
	_apply_own()
	if screen == "menu":
		# show the new kit on the pitch behind the menu
		var me_c := int(car.d["club"])
		opt_club = me_c
		_set_clubs(me_c, clubs[1] if clubs[1] != me_c else _other_club(me_c), true)
		_kickoff(0)

# The home screen. The club is always there: the first time, you make your own.
func _show_hub(pick := true) -> void:
	if not car.has_save() and pick and net.web:
		car.new_career(opt_club, CLUBS.size(), SURNAMES)
		car.d["own"] = {"n": "MY CLUB", "s": "MYC", "k": (CLUBS0[opt_club]["k"] as Array).duplicate()}
		own_new = true
		_own_changed()
		hud.show_menu("myclub", _menu_info())
		return
	if not car.has_save():
		car.new_career(opt_club, CLUBS.size(), SURNAMES)
		_apply_own()
	car_sel = -1
	car_sell = -1
	hud.show_menu("main", _menu_info())

func _action(act: String, arg = null) -> void:
	au["blip2" if act in ["play", "start", "again"] else "blip"].play()
	if act == "key":
		return
	if act in ["play", "friend", "c_play"] and not seen_how:
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
			_set_clubs(opt_club, _other_club(opt_club))
			screen = "match"
			hud.show_menu("", {})
			_begin_match(true)
		"friend":
			hud.show_menu("friend", _menu_info())
		"career":
			car_msg = ""
			car_sure = false
			if screen == "match":
				_to_menu()
			else:
				_show_hub()
		"tab":
			hub_tab = str(arg)
			car_msg = ""
			car_sure = false
			hud.show_menu("main", _menu_info())
		"quick":
			hud.show_menu("quick", _menu_info())
		"how":
			how_next = "career"
			hud.show_menu("how", _menu_info())
		"pack":
			var pr: Dictionary = car.open_pack(int(arg))
			if pr.has("pl"):
				var ppl: Dictionary = pr["pl"]
				pack_res = {"n": str(ppl["n"]).to_upper(), "pos": str(ppl["pos"]), "age": int(ppl["age"]), "pot": int(ppl["pot"]), "ovr": Career.ovr_of(ppl), "st": [int(ppl["pac"]), int(ppl["sho"]), int(ppl["pas"]), int(ppl["dfn"])]}
				car_msg = ""
				au["cheer"].play()
				fx("flash", 0.5)
				hud.show_menu("pack", _menu_info())
			else:
				car_msg = str(pr.get("err", ""))
				hud.refresh(_menu_info())
		"c_play":
			if not car.season_over():
				career_on = true
				humans = [Human.new()]
				me = 0
				view_flip = 1.0
				_set_clubs(int(car.d["club"]), car.next_match()[0], true)
				screen = "match"
				hud.show_menu("", {})
				_begin_match(true)
		"c_next":
			car.next_season()
			_show_hub()
		"c_table":
			hud.show_menu("table", _menu_info())
		"c_squad":
			car_sell = -1
			car_sel = -1
			car_msg = ""
			hud.show_menu("squad", _menu_info())
		"c_pick":
			var pi := int(arg)
			car_msg = ""
			car_sell = -1
			if car_sel == pi:
				car_sel = -1
			elif car_sel < 0:
				car_sel = pi
			else:
				var xi: Array = car.d["xi"]
				if xi.has(car_sel) or xi.has(pi):
					car.swap(car_sel, pi)
					car_sel = -1
				else:
					car_sel = pi
			hud.refresh(_menu_info())
		"c_train":
			if car_sel >= 0:
				var r2: String = car.train(car_sel)
				car_msg = r2 if r2 != "" else "Not enough coins, or he has reached his best"
				if r2 != "":
					au["blip2"].play()
				hud.refresh(_menu_info())
		"update":
			if net.web:
				JavaScriptBridge.eval("if(window.bbApp)bbApp.update();else location.reload()", true)
			else:
				hud.toast("Updates come by themselves here")
		"install":
			if net.web:
				var ir := str(JavaScriptBridge.eval("(window.bbApp?bbApp.install():'manual')", true))
				if ir != "asked":
					hud.toast("Open the browser menu and tap 'Add to Home screen' or 'Install app'")
			else:
				hud.toast("Already installed")
		"own":
			_own_start()
			own_new = false
			hud.show_menu("myclub", _menu_info())
		"own_name":
			_own_start()
			var cur := str(car.d["own"]["n"])
			var nn := ""
			if net.web:
				var res = JavaScriptBridge.eval("(function(){var r=prompt('Club name', %s);return r===null?'':String(r)})()" % JSON.stringify(cur), true)
				nn = str(res) if res != null else ""
			else:
				nn = "FC TEST %d" % (randi() % 90 + 10)
			var clean := ""
			for ch in nn.to_upper().strip_edges():
				if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == " " or ch in ["Æ", "Ø", "Å", "-"]:
					clean += ch
			clean = clean.strip_edges().substr(0, 16)
			if clean.length() >= 2:
				var sh := ""
				for ch in clean:
					if ch != " " and ch != "-" and sh.length() < 3:
						sh += ch
				car.d["own"]["n"] = clean
				car.d["own"]["s"] = sh
				_own_changed()
			hud.refresh(_menu_info())
		"own_col":
			_own_start()
			car.d["own"]["k"][int(arg[0])] = str(arg[1])
			_own_changed()
			hud.refresh(_menu_info())
		"own_ok":
			own_new = false
			_show_hub(false)
		"c_tp":
			if car_sel >= 0:
				car_msg = car.spend_tp(car_sel, int(arg))
				if car_msg.contains("+1"):
					au["blip2"].play()
				hud.refresh(_menu_info())
		"c_club":
			car_msg = ""
			hud.show_menu("club", _menu_info())
		"c_fac":
			car_msg = car.fac_up(str(arg))
			if car_msg == "BUILT":
				car_msg = ""
				au["blip2"].play()
			hud.refresh(_menu_info())
		"c_market":
			car_msg = ""
			hud.show_menu("market", _menu_info())
		"c_buy":
			car_msg = car.buy(int(arg))
			if car_msg.ends_with("SIGNED"):
				au["blip2"].play()
			hud.refresh(_menu_info())
		"c_sell":
			if car_sel >= 0:
				if car_sell == car_sel:
					car_msg = car.sell(car_sel)
					if car_msg.contains("SOLD"):
						car_sel = -1
						au["blip2"].play()
					car_sell = -1
				else:
					car_sell = car_sel
				hud.refresh(_menu_info())
		"c_form":
			var fi := (FORM_NAMES.find(car.form()) + 1) % FORM_NAMES.size()
			var rl := []
			for f in FORMS[FORM_NAMES[fi]]:
				rl.append(f[0])
			car.set_form(FORM_NAMES[fi], rl)
			car_sel = -1
			car_msg = ""
			hud.refresh(_menu_info())
		"c_new":
			if car_sure:
				# a new start: make the club first
				car.wipe()
				car_sure = false
				hub_tab = "play"
				car.new_career(opt_club, CLUBS.size(), SURNAMES)
				car.d["own"] = {"n": "MY CLUB", "s": "MYC", "k": (CLUBS0[opt_club]["k"] as Array).duplicate()}
				own_new = true
				_own_changed()
				hud.show_menu("myclub", _menu_info())
			else:
				car_sure = true
				hud.refresh(_menu_info())
		"teams":
			teams_from = "lobby" if net.role != "" else "quick"
			hud.show_menu("teams", _menu_info())
		"teams_back":
			if teams_from == "new":
				_show_hub(false)
			else:
				hud.show_menu(teams_from, _menu_info())
		"club":
			opt_club = int(arg)
			if net.web:
				JavaScriptBridge.eval("try{localStorage.setItem('bb3d-club','%d')}catch(e){}" % opt_club, true)
			if net.role == "guest":
				net.send({"_": "club", "id": opt_club})
			else:
				# show the new kit on the pitch behind the menu
				_set_clubs(opt_club, clubs[1] if clubs[1] != opt_club else _other_club(opt_club))
				_kickoff(0)
			if teams_from == "new":
				_show_hub(false)
			else:
				hud.show_menu(teams_from, _menu_info())
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
			if opt_mode == "coop" and not opt_car and car.has_save():
				opt_car = true
			elif opt_mode == "coop":
				opt_car = false
				opt_mode = "versus"
			else:
				opt_mode = "coop"
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
		"subs":
			if career_on and net.role != "guest":
				sub_sel = -1
				hud.show_menu("subs", _menu_info())
		"sub_pick":
			sub_sel = -1 if sub_sel == int(arg) else int(arg)
			hud.refresh(_menu_info())
		"sub_in":
			if sub_sel >= 0:
				_substitute(sub_sel, int(arg))
				sub_sel = -1
				hud.refresh(_menu_info())
		"resume":
			paused = false
			hud.show_menu("", {})
		"snd_opt":
			opt_snd = (opt_snd + 1) % 3
			_apply_sound(true)
			hud.refresh(_menu_info())
		"voice_opt":
			opt_voice = not opt_voice
			_apply_sound(true)
			hud.refresh(_menu_info())

# What a player's numbers mean on the pitch, so that no two players feel the same:
# pace = top speed and how fast he gets there, touch (passing + pace) = how tightly he turns and how
# little the ball slows him, strength (defending, less for quick light players) = holding people off.
func _derive(p) -> void:
	p.base_top = 6.6 + (p.pac - 50) * 0.04
	p.acc_k = clampf(0.82 + (p.pac - 50) * 0.009, 0.75, 1.22)
	var dri: float = p.pas * 0.55 + p.pac * 0.45 - (8.0 if p.role in ["DF", "GK"] else 0.0)
	var dk: float = clampf((dri - 50.0) / 40.0, 0.0, 1.0)
	p.turn_k = lerpf(0.8, 1.25, dk)
	# with the ball he is almost as quick as without it, so a man who gets past his marker is away
	p.carry_k = lerpf(0.95, 0.99, dk)
	p.phy = clampf(p.dfn * 0.7 + (100 - p.pac) * 0.3 + (6.0 if p.role == "DF" else 0.0), 35.0, 99.0)

func _apply_sound(save: bool) -> void:
	AudioServer.set_bus_mute(0, opt_snd == 2)
	AudioServer.set_bus_volume_db(0, -4.0 if opt_snd == 0 else -16.0)
	if save and net.web:
		JavaScriptBridge.eval("try{localStorage.setItem('bb3d-snd','%d%d')}catch(e){}" % [opt_snd, 1 if opt_voice else 0], true)

func _send_lobby() -> void:
	if net.role == "host" and net.connected:
		net.send({"_": "lobby", "mode": opt_mode, "diff": opt_diff, "len": opt_len, "car": _co_text()})

# One line both phones see in the lobby when the next match is a career match played together.
func _co_text() -> String:
	if not (opt_car and opt_mode == "coop" and car.has_save()):
		return ""
	if car.season_over():
		return "%s  ·  NEW SEASON" % CLUBS[int(car.d["club"])]["n"]
	return "%s v %s  ·  ROUND %d OF %d  ·  %s IN THE TABLE" % [CLUBS[int(car.d["club"])]["n"], CLUBS[car.next_match()[0]]["n"], int(car.d["round"]) + 1, car.rounds_total(), Career.ordinal(car.rank_of(int(car.d["club"])))]

func _host_start() -> void:
	var h0 := Human.new()
	var h1 := Human.new()
	h1.local = false
	h1.team = 0 if opt_mode == "coop" else 1
	humans = [h0, h1]
	me = 0
	view_flip = 1.0
	var sq := []
	career_on = _co_text() != ""
	if career_on:
		if car.season_over():
			car.next_season()
		_set_clubs(int(car.d["club"]), car.next_match()[0], true)
		for p in teams[0]:
			sq.append([p.pname, p.num])
	else:
		_set_clubs(opt_club, _other_club(opt_club) if opt_mode == "coop" else guest_club)
	screen = "match"
	hud.show_menu("", {})
	start_msg = {"_": "start", "mode": opt_mode, "diff": opt_diff, "len": opt_len, "clubs": clubs, "forms": forms, "sq": sq}
	wait_friend = 0.0
	net.send(start_msg)
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
	var cl: Array = m.get("clubs", [0, 1])
	sq_over = m.get("sq", [])
	co_got = false
	car_lines = []
	_set_clubs(int(cl[0]), int(cl[1]), true)
	var fm: Array = m.get("forms", [])
	if fm.size() == 2 and FORMS.has(str(fm[0])) and FORMS.has(str(fm[1])) and (forms[0] != str(fm[0]) or forms[1] != str(fm[1])):
		form_over = str(fm[0])
		_set_clubs(int(cl[0]), int(cl[1]), true)
		form_over = ""
	sq_over = []
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
			"club":
				if net.role == "host":
					guest_club = clampi(int(m.get("id", 1)), 0, CLUBS.size() - 1)
					hud.refresh(_menu_info())
			"open":
				net.connected = true
				if net.role == "host" and screen == "match" and wait_friend > 0.0 and start_msg != null:
					# the friend is back after a lost connection: straight into the running match again
					wait_friend = 0.0
					net.send(start_msg)
					hud.toast("Your friend is back")
				elif net.role == "host":
					_send_lobby()
				else:
					net.send({"_": "club", "id": opt_club})
				if screen == "menu":
					hud.show_menu("lobby", _menu_info())
					au["blip2"].play()
			"lobby":
				opt_mode = m.get("mode", "coop")
				opt_diff = int(m.get("diff", 1))
				opt_len = int(m.get("len", 1))
				co_text = str(m.get("car", ""))
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
				if net.role == "guest" and screen == "match" and room.length() == 4:
					# the connection dropped in the middle of a match: call the room again instead of giving up
					hud.toast("Connection lost. Joining again...")
					net.join(room)
				elif net.role == "guest":
					_to_menu()
					hud.toast("The host left the match")
				elif screen == "match":
					if humans.size() > 1 and wait_friend <= 0.0:
						# keep his place for a while: a phone often loses the line for a few seconds only
						wait_friend = 25.0
						humans[1].stick = Vector2.ZERO
						humans[1].sprint = false
						hud.toast("Your friend lost the connection. Waiting for him...")
				else:
					hud.show_menu("lobby", _menu_info())
			"err":
				var em: String = str(m.get("m", ""))
				if net.role == "guest" and not net.connected:
					_to_menu()
					hud.toast("Could not find that room" if em == "peer-unavailable" else ("Could not connect. Try again, or switch between wifi and mobile data" if em == "timeout" else "Connection problem (%s)" % em))
				elif net.role == "host" and em == "unavailable-id":
					_action("host")

# ---------------------------------------------------------------- match flow

func _begin_match(with_intro: bool) -> void:
	subs_left = 3
	sub_sel = -1
	sub_off = []
	sub_played = []
	if career_on:
		for x in car.d["xi"]:
			sub_played.append(int(x))
	for p in players:
		p.fit = 1.0
	test_t = Time.get_ticks_msec() / 1000.0
	car_goals = []
	car_lines = []
	score = [0, 0]
	clock = 0.0
	half = 1
	kick_team = 0
	rec.clear()
	tst = [{"shots": 0, "fouls": 0, "poss": 0, "saves": 0, "g": []}, {"shots": 0, "fouls": 0, "poss": 0, "saves": 0, "g": []}]
	for h in humans:
		h.stam = 1.0
		h.tired = false
	hud.set_score(0, 0)
	hud.set_clock(0)
	hud.hide_banner()
	hud.replay_on = false
	for p in players:
		p.off = false
		p.yellow = 0
		p.set_meta("fouls", 0)
		p.visible = true
	_formation(0, true)
	ball_owner = null
	ball.position = Vector3(0, BALL_R, 0)
	ball_vel = Vector3.ZERO
	state = "intro"
	state_t = 0.0
	intro_len = 2.6
	follow_on = false
	cam_pos = Vector3(-30, 46, 78)
	cam_look = Vector3(0, 0, 0)
	hud.show_controls = false
	if not autotest:
		if not crowd_au.playing:
			crowd_au.play()
		if with_intro:
			intro_len = 5.4
			fx("vs", 3.6)
			snd("whoosh")
			fx("excite", 0.7)

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
		# the other team waits outside the centre circle
		if p.team != kicking and Vector2(pos.x, pos.z).length() < 10.5:
			pos.x = -sqrt(10.5 * 10.5 - pos.z * pos.z) * s
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
		p.fall_t = -1.0
		p.tackle_t = -1.0
		p.press_t = 0.0
		p.step_t = 0.0
		p.wait_t = 0.0
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
	if clock < 1.0 and half == 1:
		fx("say", "And we are under way!")

func _goal(team: int) -> void:
	score[team] += 1
	if long_test:
		var gk0 = teams[1 - team][0]
		print("LONGDBG ball=", snappedf(ball.position.z, 0.01), ",", snappedf(ball.position.y, 0.01), " gk=", snappedf(gk0.position.x, 0.1), ",", snappedf(gk0.position.z, 0.01), " dive=", snappedf(gk0.dive_t, 0.01), " react=", snappedf(gk0.react_t, 0.01), " gkv=", snappedf(gk0.vel.z, 0.1), " bv=", snappedf(ball_vel.length(), 0.1), " stun=", snappedf(gk0.stun, 0.01))
	stats["goals"] += 1
	state = "goal"
	state_t = 0.0
	kick_team = 1 - team
	goal_idx = rec.size()
	scorer = ball_last if (ball_last != null and ball_last.team == team) else teams[team][9]
	tst[team]["g"].append("%s %d'" % [scorer.pname.to_upper(), int(clock / 60.0) + 1])
	if career_on and scorer.team == 0 and scorer.sq >= 0 and not _quiet():
		car_goals.append(scorer.sq)
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
	snd("jingle")
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
	elif kind == "corner":
		_corner_setup(team, taker, pos)
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

# Corner kick: attackers take up spots in the box, each with a marker goal-side of him.
func _corner_setup(team: int, taker, pos: Vector3) -> void:
	var s := side(team)
	var gx := HL * s
	var zs := signf(pos.z)
	var spots := [
		Vector3(gx - s * 5.0, 0, zs * 3.2), Vector3(gx - s * 10.5, 0, zs * 0.5), Vector3(gx - s * 6.0, 0, -zs * 4.2),
		Vector3(gx - s * 8.0, 0, -zs * 1.0), Vector3(gx - s * 17.5, 0, zs * 3.0), Vector3(gx - s * 4.0, 0, zs * 15.0),
	]
	var att := []
	for i in [9, 2, 3, 8, 10, 7, 5, 6]:
		var a = teams[team][i]
		if a != taker and not a.off and att.size() < spots.size():
			att.append(a)
	var free_def := []
	for d in teams[1 - team]:
		if d.role != "GK" and not d.off:
			free_def.append(d)
	# the fastest forward of the defending side stays up for the break
	free_def.sort_custom(func(x, y): return x.idx < y.idx)
	var up = free_def.pop_back() if free_def.size() > 6 else null
	for i in att.size():
		var a = att[i]
		a.position = spots[i] + Vector3(randf() - 0.5, 0, randf() - 0.5) * 0.8
		a.vel = Vector3.ZERO
		a.yaw = atan2(-(pos.x - a.position.x), -(pos.z - a.position.z))
		if not free_def.is_empty() and i < 5:
			var d = free_def.pop_front()
			d.position = a.position + (Vector3(gx, 0, 0) - a.position).normalized() * 1.0
			d.vel = Vector3.ZERO
			d.yaw = a.yaw
	# the rest of the defence: near post, six-yard line, edge of the box
	var extra := [Vector3(gx - s * 0.8, 0, zs * 3.4), Vector3(gx - s * 5.5, 0, 0), Vector3(gx - s * 13.0, 0, zs * 6.0), Vector3(gx - s * 15.0, 0, -zs * 5.0), Vector3(gx - s * 20.0, 0, 0)]
	var n := 0
	for d in free_def:
		d.position = extra[n % extra.size()] + Vector3(randf() - 0.5, 0, randf() - 0.5) * 0.6
		d.vel = Vector3.ZERO
		d.yaw = atan2(-(pos.x - d.position.x), -(pos.z - d.position.z))
		n += 1
	if up != null:
		up.position = Vector3(gx - s * 42.0, 0, 0)
		up.vel = Vector3.ZERO
	var gk = teams[1 - team][0]
	gk.position = Vector3(gx - s * 0.9, 0, zs * 0.6)
	gk.vel = Vector3.ZERO
	# the attacking side's remaining players hold the halfway line
	var back := 0
	for a in teams[team]:
		if a == taker or a.off or att.has(a) or a.role == "GK":
			continue
		a.position = Vector3(gx - s * (38.0 + back * 4.0), 0, (back - 0.5) * 14.0)
		a.vel = Vector3.ZERO
		back += 1

# Who a corner is swung in to: a man in the box, the less marked the better.
func _cross_target(p):
	var s := side(p.team)
	var best = null
	var bs := -1e9
	for m in teams[p.team]:
		if m == p or m.off or m.role == "GK":
			continue
		var gd := Vector2(HL * s - m.position.x, m.position.z).length()
		if gd > 15.0:
			continue
		var mark := 9.0
		for o in teams[1 - p.team]:
			mark = minf(mark, o.position.distance_to(m.position))
		var sc: float = minf(mark, 4.0) * 0.6 - gd * 0.08 + randf() * 2.2 + m.sho * 0.01
		if sc > bs:
			bs = sc
			best = m
	return best if best != null else _pass_target(p, Vector3.ZERO, true)

# Skill move: a quick spin with the ball. Tackles miss for a moment and a defender right in front is wrong-footed.
func _skill(p, dir3: Vector3) -> void:
	var d: Vector3 = dir3.normalized() if dir3.length() > 0.25 else p.fwd()
	p.vel = d * p.top_speed * 1.08
	p.start_kick(0.5, 3)
	protect_t = maxf(protect_t, 0.55)
	for o in teams[1 - p.team]:
		if o.role == "GK" or o.stun > 0.0:
			continue
		if o.position.distance_to(p.position) < 2.3:
			o.stun = 0.5
			o.commit_t = -1.0
			o.press_t = 0.0
	snd("whoosh")

# A ball at head height: the nearest man jumps for it.
func _header(p) -> void:
	var s := side(p.team)
	var b := ball.position
	var to_goal := Vector2(HL * s - p.position.x, p.position.z).length()
	var own_goal := Vector2(-HL * s - p.position.x, p.position.z).length()
	var kind := "down"
	if to_goal < 15.0 and absf(p.position.z) < 12.0:
		var err := (randf() - 0.5) * lerpf(5.5, 2.5, clampf((p.sho - 40) / 50.0, 0.0, 1.0))
		var tz := (1.0 if randf() < 0.5 else -1.0) * GOAL_HW * 0.6 + err
		var dir := Vector3(HL * s - b.x, 0, tz - b.z).normalized()
		var spd := 14.0 + randf() * 4.0
		ball_vel = dir * spd + Vector3(0, -1.0 + randf() * 2.5, 0)
		shot_live = true
		stats["shots"] += 1
		tst[p.team]["shots"] += 1
		kind = "shot"
	elif own_goal < 30.0:
		var away := Vector3(s, 0, signf(b.z) * 0.5 + (randf() - 0.5) * 0.8).normalized()
		ball_vel = away * (12.0 + randf() * 4.0) + Vector3(0, 6.5, 0)
		shot_live = false
	else:
		ball_vel = p.vel * 0.6 + p.fwd() * 1.5 + Vector3(0, -1.5, 0)
		shot_live = false
	ball_spin = 0.0
	ball_last = p
	ball_ignore = p
	ignore_t = 0.45
	p.yaw = atan2(-ball_vel.x, -ball_vel.z) if kind != "down" else p.yaw
	p.start_kick(0.7, 1)
	for q in players:
		q.recv = false
		q.offside = false
	if p.offside:
		pass
	snd("touch")
	if kind == "shot":
		fx("punch", 2.0)

func _foul(by, on, man_first := false) -> void:
	stats["fouls"] += 1
	tst[by.team]["fouls"] += 1
	var pos: Vector3 = on.position
	by.stun = 0.8
	var gx := -HL * side(by.team)
	var in_box := absf(pos.x - gx) < 16.5 and absf(pos.z) < 20.16
	var closing: float = (by.vel - on.vel).length()
	var card := ""
	# a booking is for a reckless challenge, not for every foul
	# (2D rule) from behind at speed, or the same man fouling again and again
	var nf: int = int(by.get_meta("fouls", 0)) + 1
	by.set_meta("fouls", nf)
	var rear: bool = on.fwd().dot((on.position - by.position).normalized()) > 0.5
	var slid: bool = by.tackle_t >= 0.0
	if (slid and rear and man_first) or (not slid and closing > (5.5 if in_box else 7.0)) or nf >= 3:
		by.yellow += 1
		stats["cards"] += 1
		card = "YELLOW CARD"
		if by.yellow >= 2:
			card = "RED CARD"
			by.off = true
	# advantage, as in the 2D game: the fouled side still has the ball, so the referee lets them play on.
	# A red card or a penalty always stops the game.
	var o = ball_owner
	if not in_box and card != "RED CARD" and o != null and o.team == on.team and set_piece == "" and state == "play":
		stats["adv"] = int(stats.get("adv", 0)) + 1
		by.stun = 1.1
		by.vel = Vector3.ZERO
		on.stun = maxf(on.stun, 0.12)
		protect_t = maxf(protect_t, 0.6)
		snd("thud")
		if not _quiet():
			_banner("ADVANTAGE", Color(1, 1, 1), 0.9, card, 44)
			fx("say", "The referee lets play go on. Advantage!")
			fx("vib", 60)
		return
	on.stun = 1.2
	on.start_fall(1.2)
	if in_box:
		stats["pens"] += 1
	snd("whistle")
	snd("thud")
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
	# the best few places, one per thumb. A man who is already on one of them keeps it,
	# so two people on a team never take each other's player.
	var top := []
	for c in cands:
		if not used.has(c[1]) and top.size() < hs.size():
			top.append(c[1])
	var need := []
	for h in hs:
		if h.ctrl != null and top.has(h.ctrl):
			top.erase(h.ctrl)
		else:
			need.append(h)
	for h in need:
		if top.is_empty():
			break
		# of the places left, each takes the one nearest his own man
		var bi := 0
		if h.ctrl != null:
			for i in top.size():
				if top[i].position.distance_to(h.ctrl.position) < top[bi].position.distance_to(h.ctrl.position):
					bi = i
		h.ctrl = top[bi]
		h.switch_cool = 0.7
		top.remove_at(bi)

func _switch(h) -> void:
	# SWITCH walks through the three players nearest the ball, never one your partner is playing
	var c := []
	for p in teams[h.team]:
		if p.role == "GK" or p.off or (_hum_of(p) != null and p != h.ctrl):
			continue
		var dsw: float = p.position.distance_to(ball.position)
		# when they attack, SWITCH gives you a man between the ball and your goal first
		if ball_owner != null and ball_owner.team != h.team:
			var ogs := Vector3(-HL * side(h.team), 0, 0)
			if p.position.distance_to(ogs) > ball.position.distance_to(ogs) + 1.0:
				dsw += 12.0
		c.append([dsw, p])
	c.sort_custom(func(a, b): return a[0] < b[0])
	var n: int = mini(c.size(), 3)
	if n > 0:
		var at := -1
		for i in n:
			if c[i][1] == h.ctrl:
				at = i
		h.ctrl = c[(at + 1) % n][1]
	h.switch_cool = 1.6
	if h.local:
		au["blip"].play()

# the other side plays a pass: put a defender who can get to the receiver under a thumb, like FIFA's auto switch
func _switch_for_pass(t: int, m) -> void:
	var own_goal := Vector3(-HL * side(t), 0, 0)
	var spot: Vector3 = m.position + (own_goal - m.position).normalized() * 2.0
	var best = null
	var bd := 1e9
	for p in teams[t]:
		if p.role == "GK" or p.off or _hum_of(p) != null:
			continue
		var d: float = p.position.distance_to(spot)
		if d < bd:
			bd = d
			best = p
	if best == null:
		return
	var hw = null
	var worst := 0.0
	for h in humans:
		if h.team == t and h.ctrl != null and h.switch_cool <= 0.0:
			# a man who stands in the path of the pass, or close to the receiver, is kept: he can win it himself
			var ln: Vector3 = m.position - ball.position
			ln.y = 0.0
			var hp: Vector3 = h.ctrl.position - ball.position
			hp.y = 0.0
			var tl: float = clampf(hp.dot(ln) / maxf(ln.length_squared(), 0.01), 0.0, 1.0)
			if (hp - ln * tl).length() < 5.0 or h.ctrl.position.distance_to(m.position) < 9.0:
				continue
			var d2: float = h.ctrl.position.distance_to(spot)
			if d2 > worst:
				worst = d2
				hw = h
	if hw != null and bd + 7.0 < worst:
		hw.ctrl = best
		hw.switch_cool = 0.9

# ---------------------------------------------------------------- main loop

func _physics_process(dt: float) -> void:
	if dbg and Engine.get_physics_frames() % 15 == 0:
		_dbg()
	if autotest:
		for i in 30:
			_bot_inputs(1.0 / 60.0)
			_tick(1.0 / 60.0)
			if clock != wd_clock:
				wd_clock = clock
				wd_n = 0
			wd_n += 1
			wd_all += 1
			if wd_all % 6000 == 0:
				print("AUTOTEST tick=", wd_all, " state=", state, " t=", snappedf(state_t, 0.1), " set=", set_piece, " clock=", int(clock), " owner=", players.find(ball_owner), " ball=", ball.position, " hctrl=", players.find(humans[0].ctrl) if humans.size() > 0 else -9)
			if wd_n == 4000:
				var hc2 = humans[0].ctrl if humans.size() > 0 else null
				print("AUTOTEST STUCK state=", state, " t=", state_t, " set=", set_piece, " clock=", clock, " owner=", players.find(ball_owner), " ball=", ball.position, " hctrl=", players.find(hc2), " forms=", forms, " clubs=", clubs, " kick_team=", kick_team)
				get_tree().quit()
				return
			if state == "full":
				print("AUTOTEST score=", score, " stats=", stats, " bot=", bstats)
				print("AUTOTEST team=", tst)
				for ti in 2:
					var m: Array = shp[ti]
					print("AUTOTEST shape t", ti, " n=", m[0], " ahead=", snappedf(float(m[1]) / maxf(m[0], 1), 0.01), " near18=", snappedf(float(m[2]) / maxf(m[0], 1), 0.01), " inbox=", snappedf(float(m[3]) / maxf(m[4], 1), 0.01))
				var fits := []
				for p in teams[0]:
					fits.append(snappedf(p.fit, 0.01))
				print("AUTOTEST fit=", fits)
				if career_on:
					car_lines = car.finish_match(score[0], score[1], [9] if score[0] > 0 else [])
					print("AUTOTEST career=", car_lines, " round=", car.d["round"], " rank=", car.rank_of(int(car.d["club"])), " names=", players[9].pname, "/", players[9].ovr)
				get_tree().quit()
				return
		return

# The match runs once per drawn frame, with that frame's own time step. A fixed 60 steps a second
# stutters on any screen that does not draw exactly 60 pictures a second (90/120 Hz phones, slow phones).
func _frame(dt: float) -> void:
	_net_poll()
	var evs: Array = hud.ev.duplicate()
	hud.ev.clear()
	_keys_to_events(evs)
	if evs.has("pause"):
		_action("pause")
	if screen == "menu":
		_ticks(dt)
		return
	var st := _stick() * view_flip
	var sprint: bool = hud.sprint_down or Input.is_physical_key_pressed(KEY_SHIFT)
	var acts := []
	for e in evs:
		if e in ["shoot_down", "shoot_up", "pass_down", "pass_up", "tap", "lob_down", "lob_up", "thru_down", "thru_up", "hi"]:
			acts.append(e)
	_sprint_was = sprint
	if net.role == "guest":
		net_acc += dt
		if net_acc >= 0.033 or not acts.is_empty():
			net_acc = 0.0
			net.send({"_": "i", "s": [snappedf(st.x, 0.01), snappedf(st.y, 0.01)], "sp": sprint, "e": acts})
		return
	if humans.size() > me:
		var h = humans[me]
		h.stick = st
		h.sprint = sprint
		h.evs.append_array(acts)
	if demo and bot_mode != "":
		_bot_inputs(dt)
	if paused:
		for h in humans:
			h.evs.clear()
		return
	_ticks(dt)
	if net.role == "host" and net.connected:
		net_acc += dt
		if net_acc >= 0.033:
			net_acc = 0.0
			_send_snap()

func _ticks(dt: float) -> void:
	# long frames are cut into steps of at most 1/50 s, so nothing tunnels on a slow phone
	if screen == "match":
		# the whole match runs a little faster than real football, like the 2D game
		dt *= TEMPO
	var n: int = maxi(int(ceil(dt * 50.0 - 0.001)), 1)
	for i in n:
		_tick(dt / n)

func _dbg() -> void:
	# for automated tests: ?dbg in the address publishes a little state to the page
	var hs := []
	for h in humans:
		hs.append([h.team, players.find(h.ctrl), snappedf(h.ctrl.position.x, 0.1) if h.ctrl != null else 0.0, snappedf(h.ctrl.position.z, 0.1) if h.ctrl != null else 0.0])
	JavaScriptBridge.eval("window.bbDbg=%s" % JSON.stringify({
		"screen": screen, "state": state, "room": room, "conn": net.connected, "role": net.role, "score": score,
		"h": hs, "ball": [snappedf(ball.position.x, 0.1), snappedf(ball.position.z, 0.1)], "menu": hud.menu_name, "mode": opt_mode, "clock": int(clock),
		"owner": players.find(ball_owner), "fps": Engine.get_frames_per_second(), "clubs": clubs,
		"forms": forms, "career": career_on, "lines": car_lines, "coins": int(car.d.get("coins", -1)), "round": int(car.d.get("round", -1)), "n9": players[9].pname if players.size() > 9 else "",
	}), true)
	if test_ft > 0.0 and screen == "match" and state == "play" and net.role != "guest":
		if Time.get_ticks_msec() / 1000.0 - test_t > test_ft:
			_full_time()

func _tick(dt: float) -> void:
	state_t += dt
	match state:
		"intro":
			if state_t > 0.7 and state_t < intro_len - 1.9:
				for h in humans:
					if h.evs.has("tap") or h.evs.has("shoot_down") or h.evs.has("pass_down"):
						state_t = intro_len - 1.9
						fx("vs", 0.0)
			if state_t > intro_len:
				_kickoff(kick_team)
		"play":
			_play(dt)
			_record(dt)
		"goal":
			_celebrate(dt)
			if state_t < 1.2:
				_record(dt)
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
	var map := {KEY_SPACE: "shoot", KEY_X: "pass", KEY_E: "lob", KEY_Q: "thru", KEY_ESCAPE: "pause"}
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
		return MATE
	return DIFF[opt_diff]

func _play(dt: float) -> void:
	tdt = dt
	var gdt: float = dt * 5400.0 / LENGTHS[opt_len]
	clock += gdt
	# match fitness: everyone tires, those who run the most tire the most, and tired legs are slower
	for p in players:
		var sr: float = clampf(p.vel.length() / maxf(p.base_top, 1.0), 0.0, 1.2)
		p.fit = maxf(p.fit - gdt * (0.00002 + 0.00012 * sr * sr), 0.0)
		p.top_speed = p.base_top * (0.84 + 0.16 * p.fit)
	ignore_t -= dt
	protect_t -= dt
	if force_kind != "" and state_t > 3.0:
		if force_kind == "corner":
			_out("corner", Vector3(HL - 0.6, 0, HW - 0.6), 0)
		elif force_kind == "pen" or force_kind == "pen0":
			_out("pen", Vector3.ZERO, 0 if force_kind == "pen0" else 1, 2.0)
		else:
			_out("throw", Vector3(20, 0, HW - 0.3), 0)
		force_kind = ""
		return
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
		h.skill_cool -= dt
		if h.ctrl == null:
			continue
		if h.ctrl.role == "GK" and ball_owner != h.ctrl:
			# the keeper is only yours while he holds the ball
			_assign_defenders(h.team, true)
			if h.ctrl.role == "GK":
				continue
		var dir3 := Vector3(h.stick.x, 0, h.stick.y)
		var mine: bool = ball_owner == h.ctrl
		# a full meter plays the ball by itself
		if h.pass_hold >= 0.6:
			h.evs.append("pass_up")
		if h.lob_hold >= 0.6:
			h.evs.append("lob_up")
		if h.thru_hold >= 0.6:
			h.evs.append("thru_up")
		# is a pass from a team mate on its way to my man?
		var coming: bool = ball_owner == null and h.ctrl.recv and ball_last != null and ball_last.team == h.team
		# First-time play: a button pressed while the pass is still on its way is carried out the moment the ball arrives.
		if h.ot > 0:
			h.ot_t -= dt
			if mine and set_piece == "":
				var k1: int = h.ot
				h.ot = 0
				if k1 == 3:
					_shoot(h.ctrl, 0.62, _human_aim(h, dir3), 0.95, 0.2)
				else:
					var m1 = _pass_target(h.ctrl, dir3, false, 22.0 if k1 == 2 else -1.0)
					if m1 != null:
						_pass(h.ctrl, m1, k1 == 2)
				mine = ball_owner == h.ctrl
			elif h.ot_t <= 0.0 or (ball_owner != null and ball_owner != h.ctrl):
				h.ot = 0
		for e in h.evs:
			# thumb slid up on PASS: the same pass goes high
			if e == "pass_up" and h.hi and h.pass_hold >= 0.0 and set_piece != "kick":
				h.lob_hold = h.pass_hold
				h.pass_hold = -1.0
				e = "lob_up"
			if e == "hi":
				h.hi = true
			elif e == "thru_down":
				h.hi = false
				if mine and set_piece != "pen":
					h.thru_hold = 0.0
				elif coming:
					h.ot = 1
					h.ot_t = 1.6
			elif e == "thru_up":
				# through ball: into the space in front of the runner, not to his feet
				if h.thru_hold >= 0.0 and ball_owner == h.ctrl:
					var tpw: float = clampf(h.thru_hold / 0.6, 0.0, 1.0)
					pass_pw = tpw
					var mt = _cross_target(h.ctrl) if set_piece == "corner" else _pass_target(h.ctrl, dir3, false, 12.0 + 26.0 * tpw, true)
					if mt == null and set_piece != "":
						mt = _pass_target(h.ctrl, Vector3.ZERO, false)
					if mt != null:
						if set_piece == "":
							_pass(h.ctrl, mt, h.hi, false, 5.0 + 6.0 * tpw)
						else:
							_pass(h.ctrl, mt, h.hi or set_piece in ["corner", "gk"], set_piece == "corner")
				h.thru_hold = -1.0
			elif e == "shoot_down":
				if coming:
					h.ot = 3
					h.ot_t = 1.6
				elif mine and set_piece in ["corner", "throw"]:
					var cm = _cross_target(h.ctrl) if set_piece == "corner" else _pass_target(h.ctrl, dir3, false)
					if cm != null:
						_pass(h.ctrl, cm, true, set_piece == "corner")
				elif mine:
					h.charging = true
					h.charge = 0.0
				elif ball_owner == null or ball_owner.team != h.team:
					_human_tackle(h)
					h.def_hold = 0.0
			elif e == "shoot_up":
				h.def_hold = -1.0
				if h.charging and ball_owner == h.ctrl:
					_shoot(h.ctrl, h.charge, _human_aim(h, dir3), 0.8, lerpf(0.75, 0.2, clampf((h.charge - 0.55) / 0.4, 0.0, 1.0)))
				h.charging = false
				h.charge = 0.0
			elif e == "skill":
				if mine and set_piece == "" and h.skill_cool <= 0.0 and h.stam > 0.15:
					h.skill_cool = 1.5
					h.stam = maxf(h.stam - 0.15, 0.0)
					_skill(h.ctrl, dir3)
			elif e == "pass_down":
				if mine and set_piece == "pen":
					pass
				elif mine:
					h.pass_hold = 0.0
					h.hi = false
				elif coming:
					h.ot = 1
					h.ot_t = 1.6
				else:
					_switch(h)
			elif e == "pass_up":
				if h.pass_hold >= 0.0 and ball_owner == h.ctrl:
					var ppw: float = clampf(h.pass_hold / 0.6, 0.0, 1.0)
					pass_pw = ppw
					var m = _pass_target(h.ctrl, dir3, false, 7.0 + 28.0 * ppw)
					if set_piece == "kick" and dir3.length() < 0.25:
						m = _first_on(h.team, [6, 5, 7])
					if m == null and set_piece != "":
						m = _pass_target(h.ctrl, Vector3.ZERO, false)
					if m != null:
						_pass(h.ctrl, m, set_piece == "gk")
				h.pass_hold = -1.0
			elif e == "lob_down":
				if mine and set_piece != "pen":
					h.lob_hold = 0.0
				elif coming:
					h.ot = 2
					h.ot_t = 1.6
			elif e == "lob_up":
				# the high ball has its own button: the longer the hold, the further the man it looks for
				if h.lob_hold >= 0.0 and ball_owner == h.ctrl:
					var lpw: float = clampf(h.lob_hold / 0.6, 0.0, 1.0)
					var ml = _cross_target(h.ctrl) if set_piece == "corner" else _pass_target(h.ctrl, dir3, false, 14.0 + 28.0 * lpw)
					if ml == null and set_piece != "":
						ml = _pass_target(h.ctrl, Vector3.ZERO, false)
					if ml != null:
						_pass(h.ctrl, ml, true, set_piece == "corner")
				h.lob_hold = -1.0
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
		if ball_owner != h.ctrl:
			h.pass_hold = -1.0
			h.lob_hold = -1.0
			h.thru_hold = -1.0
		if h.thru_hold >= 0.0:
			h.thru_hold += dt
		if h.pass_hold >= 0.0:
			h.pass_hold += dt
		if h.lob_hold >= 0.0:
			h.lob_hold += dt
		h.meter = maxf(h.charge, maxf(maxf(h.pass_hold, h.lob_hold), h.thru_hold) / 0.6)
		# Tackle help: run your man into the ball and he puts his foot in by himself.
		h.auto_cool -= dt
		h.pull_t -= dt
		var oc = ball_owner
		if oc != null and oc.team != h.team and not oc.hands() and h.auto_cool <= 0.0 and protect_t <= 0.0 and h.ctrl.stun <= 0.0 and h.stick.length() > 0.3 and set_piece == "":
			var tb: Vector3 = ball.position - h.ctrl.position
			tb.y = 0.0
			var rc: float = 1.55 + (h.ctrl.dfn - 60) * 0.006 - (oc.phy - 60) * 0.004
			# shoulder to shoulder, as in the 2D game: not at once, but a contest that builds while you have a foot
			# on the ball side. Quicker when the ball is out of his feet, never while his body shields it.
			var qh: float = _tq(h.ctrl, oc)
			if tb.length() < 0.95 and dir3.normalized().dot(tb.normalized()) > 0.3 and oc.fwd().dot((h.ctrl.position - oc.position).normalized()) > -0.1 and qh > 0.2:
				h.shc += maxf(qh, 0.0) * dt * 2.4
				if h.shc >= 1.0:
					h.shc = 0.0
					h.auto_cool = 1.2
					_human_tackle(h, true)
			else:
				h.shc = maxf(h.shc - dt * 1.5, 0.0)
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
		var opp_has: bool = ball_owner != null and ball_owner.team != t
		var og0 := Vector3(-HL * side(t), 0, 0)
		var bg0: float = aim.distance_to(og0)
		for p in teams[t]:
			if p.role == "GK" or p.stun > 0.0:
				continue
			var d: float = p.position.distance_to(aim)
			# against a man on the ball the job goes to someone between him and our goal:
			# a player chasing from behind never gets there, and the door stays open
			if opp_has and p.position.distance_to(og0) > bg0 + 1.0:
				d += 9.0
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
				# Not while your man can still cut the ball out himself: standing in or near the path of an
				# opponent's pass you keep him, however close someone else is to where it will land.
				var ln: Vector3 = aim - ball.position
				ln.y = 0.0
				var hp: Vector3 = h.ctrl.position - ball.position
				hp.y = 0.0
				var tl: float = clampf(hp.dot(ln) / maxf(ln.length_squared(), 0.01), 0.0, 1.0)
				var in_lane: bool = (hp - ln * tl).length() < 5.0
				var margin := 3.0 if ball_last == null or ball_last.team == t else 6.0
				if not in_lane and chaser[t].position.distance_to(aim) + margin < h.ctrl.position.distance_to(aim):
					h.ctrl = chaser[t]
					h.switch_cool = 0.8
	# --- who offers for the ball and who runs in behind
	sup = [[], []]
	runner = [[], []]
	att_team = -1
	if ball_owner != null:
		att_team = ball_owner.team
	elif ball_last != null:
		# a pass on its way still counts as having the ball, so the team does not drop back mid-pass
		for q in teams[ball_last.team]:
			if q.recv:
				att_team = ball_last.team
	if ball_owner != null and set_piece == "":
		var ot: int = ball_owner.team
		var near_m := []
		var fws := []
		for q in teams[ot]:
			if q == ball_owner or q.role == "GK" or q.off or _hum_of(q) != null:
				continue
			near_m.append([q.position.distance_to(ball_owner.position), q])
			if q.role == "FW":
				fws.append(q)
		near_m.sort_custom(func(a, b): return a[0] < b[0])
		for i in mini(2, near_m.size()):
			sup[ot].append(near_m[i][1])
		if not fws.is_empty() and ball_owner.position.x * side(ot) > -40.0:
			# the forwards take turns, a new run about every six seconds
			var k0 := int(clock / 108.0)
			var rn = fws[k0 % fws.size()]
			if not sup[ot].has(rn):
				runner[ot].append(rn)
			# from the middle third on a second man goes too
			if fws.size() > 1 and ball_owner.position.x * side(ot) > -14.0:
				var rn2 = fws[(k0 + 1) % fws.size()]
				if not sup[ot].has(rn2):
					runner[ot].append(rn2)
			# and in their half a midfielder breaks forward as well, so there is always someone to play it up to
			if ball_owner.position.x * side(ot) > 4.0:
				for nm in near_m:
					var mq = nm[1]
					if mq.role == "MF" and not sup[ot].has(mq) and not runner[ot].has(mq) and mq.position.x * side(ot) < ball_owner.position.x * side(ot) + 12.0:
						runner[ot].append(mq)
						break
	# --- move everyone
	for p in players:
		var want := Vector3.ZERO
		var h = _hum_of(p)
		if p.stun > 0.0:
			p.stun -= dt
		elif set_piece == "kick" and ball_owner != null and p != ball_owner:
			# kick-off: everybody stays where he stands until the ball is played
			want = Vector3.ZERO
			if h != null:
				h.dead_t = 0.0
		elif pen_wait:
			want = Vector3.ZERO
			if p == ball_owner and h == null:
				want = _ai_carrier(p, dt)
			elif p == ball_owner:
				# a human taker who never shoots: the penalty is taken for him after ten seconds
				h.dead_t += dt
				if h.dead_t > 10.0 and not h.charging:
					h.dead_t = 0.0
					_shoot(p, 0.6, (1.0 if randf() < 0.5 else -1.0) * GOAL_HW * 0.6, 1.0)
		elif h != null:
			if p.recv and ball_owner == null:
				# Receiver lock: the man a pass is meant for goes to meet the ball by himself, whatever the stick says.
				# The stick only picks the direction of his first touch.
				var ma := _meet_for(p, aim)
				want = _run_to(p, ma, p.top_speed)
				h.stam = clampf(h.stam + 0.16 * dt, 0.0, 1.0)
			else:
				var run: bool = h.sprint and not h.tired and h.stick.length() > 0.3
				h.stam = clampf(h.stam + (-0.125 if run else 0.16) * dt, 0.0, 1.0)
				if h.stam <= 0.0:
					h.tired = true
				elif h.stam > 0.3:
					h.tired = false
				var sp: float = p.top_speed * (1.0 if run else 0.88)
				if ball_owner == p:
					sp *= p.carry_k
				if p.role == "GK" and ball_owner == p and set_piece == "":
					if p.hands():
						sp *= 0.3
					# six seconds, then he plays it himself
					p.hold_t += dt
					if p.hold_t > 6.0:
						var gm = _pass_target(p, Vector3.ZERO, true)
						if gm == null:
							gm = teams[p.team][1 + randi() % 4]
						_pass(p, gm, p.position.distance_to(gm.position) > 22.0)
				if h.charging:
					sp *= 0.6
				want = Vector3(h.stick.x, 0, h.stick.y) * sp
				var oc2 = ball_owner
				if h.def_hold >= 0.0:
					h.def_hold += dt
					if oc2 == null or oc2.team == h.team or oc2.hands() or set_piece != "":
						if oc2 != null:
							h.def_hold = -1.0
					elif h.def_hold > 0.22:
						# pressing like this costs legs
						h.stam = clampf(h.stam - 0.05 * dt, 0.0, 1.0)
						# TACKLE held: your man closes the runner down by himself, stays goal side at a
						# step's distance facing him, and puts his foot in when the ball is there to be won.
						var og2 := Vector3(-HL * side(h.team), 0, 0)
						var gs3: Vector3 = (og2 - oc2.position).normalized()
						var dd2: float = p.position.distance_to(oc2.position)
						var spot2: Vector3 = oc2.position + oc2.vel * 0.3 + gs3 * 1.7
						var goal_side2: bool = (p.position - oc2.position).dot(gs3) > 0.2 * dd2
						if not goal_side2 or dd2 > 4.5:
							spot2 = oc2.position + oc2.vel * 0.55 + gs3 * 2.6
							want = _run_to(p, spot2, p.top_speed)
						else:
							want = _run_to(p, spot2, p.top_speed * 0.9)
							p.jock = true
						# the stick still lets you shade to one side
						want += Vector3(h.stick.x, 0, h.stick.y) * p.top_speed * 0.35
						var tb2: Vector3 = ball.position - p.position
						tb2.y = 0.0
						var rc2: float = 1.75 + (p.dfn - 60) * 0.006 - (oc2.phy - 60) * 0.004
						if h.auto_cool <= 0.0 and protect_t <= 0.0 and p.stun <= 0.0 and tb2.length() < rc2 * 0.9 and oc2.fwd().dot((p.position - oc2.position).normalized()) > -0.3 and _tq(p, oc2) >= 0.5:
							h.auto_cool = 0.9
							_human_tackle(h, true)
				if not (ball_owner == p and set_piece != ""):
					h.dead_t = 0.0
				if ball_owner == p and set_piece in ["corner", "throw", "gk", "fk", "kick"]:
					# a dead ball is played from where it lies: the stick only turns the taker
					want = Vector3.ZERO
					# nobody waits for ever: after ten seconds the taker plays it himself
					h.dead_t += dt
					if h.dead_t > 10.0:
						h.dead_t = 0.0
						var dm = _cross_target(p) if set_piece == "corner" else _pass_target(p, Vector3.ZERO, true)
						if dm == null:
							dm = _first_on(h.team, [6, 5, 7])
						if dm != null:
							_pass(p, dm, set_piece == "corner" or set_piece == "gk", set_piece == "corner")
					if h.stick.length() > 0.3 and set_piece != "kick":
						p.face(Vector3(h.stick.x, 0, h.stick.y), 9.0, dt)
		elif p == ball_owner:
			want = _ai_carrier(p, dt)
		elif p.role == "GK":
			want = _ai_keeper(p, dt)
		else:
			want = _ai_offball(p, chaser, second, aim)
		_move(p, want, dt)
	_separate()
	_slides()
	# --- ball
	if ball_owner != null:
		var o = ball_owner
		var f: Vector3 = o.fwd()
		# Dribbling: small touches at a jog, longer ones at a sprint, and the ball is kept on the foot
		# away from the nearest opponent, with the body in between.
		var osp: float = o.vel.length()
		var bob: float = 0.48 + 0.2 * absf(sin(o.phase * 0.5)) * clampf(osp / 6.0, 0.0, 1.0)
		# At a sprint he knocks the ball on and runs after it: a touch, the ball jumps ahead, he catches it up.
		# A poorer dribbler knocks it further. The ball is easier to take while it is away from his feet.
		var spk: float = clampf((osp / maxf(o.top_speed, 1.0) - 0.84) / 0.1, 0.0, 1.0)
		o.touch_ph = fmod(o.touch_ph + dt * 2.2, 1.0)
		bob += spk * (0.2 + 0.6 * (2.0 - o.turn_k) * (0.5 + 0.5 * cos(o.touch_ph * TAU)))
		var rgt := Vector3(-f.z, 0, f.x)
		var want_side := 0.0
		var nd2 := 3.2
		for q in teams[1 - o.team]:
			var dq: float = q.position.distance_to(o.position)
			if dq < nd2:
				nd2 = dq
				want_side = -signf((q.position - o.position).dot(rgt)) * 0.3 * clampf((3.2 - dq) / 1.6, 0.0, 1.0)
		if nd2 < 1.8:
			bob = minf(bob, 0.5)
		o.ball_side = lerpf(o.ball_side, want_side, clampf(dt * 7.0, 0.0, 1.0))
		var tgt: Vector3 = o.position + f * bob + rgt * o.ball_side + Vector3(0, BALL_R, 0)
		if o.hands():
			tgt = o.position + f * 0.35 + Vector3(0, 1.15, 0)
		elif set_piece == "throw":
			tgt = o.position - f * 0.12 + Vector3(0, 2.32, 0)
		ball.position = ball.position.lerp(tgt, clampf(dt * 22.0, 0.0, 1.0))
		ball_vel = o.vel
		ball_last = o
		tst[o.team]["poss"] += 1
		if autotest_on and set_piece == "" and o.role != "GK":
			var su := side(o.team)
			var bu0: float = o.position.x * su
			if bu0 > 15.0:
				var m: Array = shp[o.team]
				m[0] += 1
				for q in teams[o.team]:
					if q == o or q.role == "GK":
						continue
					var qu: float = q.position.x * su
					if qu > bu0 + 1.0:
						m[1] += 1
					if q.position.distance_to(o.position) < 18.0:
						m[2] += 1
					if bu0 > 30.0 and qu > 36.0 and absf(q.position.z) < 20.0:
						m[3] += 1
				if bu0 > 30.0:
					m[4] += 1
		_tackles(dt)
		# keeper goes down at the feet of a runner who brings the ball too close to him
		if set_piece == "" and protect_t <= 0.0 and ball_owner != null and ball_owner.role != "GK":
			var kg = teams[1 - ball_owner.team][0]
			var kx := -HL * side(kg.team)
			if kg.stun <= 0.0 and absf(ball.position.x - kx) < 16.0 and absf(ball.position.z) < 20.0:
				var kd := Vector2(ball.position.x - kg.position.x, ball.position.z - kg.position.z).length()
				if kd < 0.95:
					var lost = ball_owner
					lost.stun = 0.4
					snd("touch")
					snd("ooh")
					_give(kg)
		if state == "play" and set_piece == "" and ball_owner != null and ball_owner.role != "GK":
			# running the ball over the line is out, just like kicking it out
			_check_lines()
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
	if half == 1 and clock >= 2700.0 and (ball_owner != null or clock > 2790.0) and (absf(ball.position.x) < 32.0 or clock > 2850.0):
		half = 2
		clock = 2700.0
		for p in players:
			p.fit = minf(p.fit + 0.08, 1.0)
		state = "half"
		state_t = 0.0
		ball_owner = null
		ball_vel = Vector3.ZERO
		hud.show_controls = false
		snd("whistle_long")
		_banner("HALF TIME", Color(1, 1, 1), 2.2, "%d - %d" % [score[0], score[1]])
	elif half == 2 and clock >= 5400.0 and (ball_owner != null or clock > 5490.0 or autotest) and (absf(ball.position.x) < 32.0 or autotest or clock > 5550.0):
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
	if career_on:
		car_lines = car.finish_match(score[0], score[1], car_goals, sub_played)
		car_lines.append("%s IN THE TABLE" % Career.ordinal(car.rank_of(int(car.d["club"]))))
		co_pay = [car.last_coins, score[0] > score[1], [car_lines[car_lines.size() - 1]] + ([str(car.d["note"])] if car.season_over() else [])]
	hud.show_menu("full", _menu_info())

func _idle_players(dt: float) -> void:
	for p in players:
		_move(p, Vector3.ZERO, dt)

func _move(p, want: Vector3, dt: float) -> void:
	if p.tackle_t >= 0.0 and p.tackle_t < SLIDE_T and p.slide_live:
		# sliding on the grass, the 2D game's curve: a burst that eases off to under half
		var sk: float = 0.45 + 0.55 * (1.0 - p.tackle_t / SLIDE_T)
		p.vel = p.slide_dir * SLIDE_V * sk
		p.position += p.vel * dt
		p.position.x = clampf(p.position.x, -HL - 2.5, HL + 2.5)
		p.position.z = clampf(p.position.z, -HW - 2.5, HW + 2.5)
		return
	var acc: float = (15.0 if want.length() > p.vel.length() else 22.0) * p.acc_k
	var cur: float = p.vel.length()
	if _hum_of(p) != null:
		# the man under your thumb answers the stick at once
		acc = (24.0 if want.length() > p.vel.length() else 30.0) * p.acc_k
	if _hum_of(p) != null and cur > 1.6 and want.length() > 1.0 and p.stun <= 0.0:
		# Running is steered like a body, not like a cursor: the run bends round towards the stick.
		# Slow = tight turns, full sprint = wider arcs, a better player turns quicker, and the ball costs a little.
		var vd: Vector3 = p.vel / cur
		var wd: Vector3 = want.normalized()
		var ang: float = vd.signed_angle_to(wd, Vector3.UP)
		if absf(ang) > 2.3:
			# turning right back: plant the foot, then go the other way
			p.vel = p.vel.move_toward(Vector3.ZERO, 34.0 * dt)
		else:
			var sr: float = clampf(cur / maxf(p.top_speed, 1.0), 0.0, 1.0)
			var rate: float = lerpf(15.0, 8.5, sr) * p.turn_k
			vd = vd.rotated(Vector3.UP, clampf(ang, -rate * dt, rate * dt))
			var tgt_sp: float = want.length() * (1.0 - 0.18 * clampf(absf(ang) / 1.6, 0.0, 1.0))
			p.vel = vd * move_toward(cur, tgt_sp, acc * dt)
	else:
		p.vel = p.vel.move_toward(want, acc * dt)
	p.position += p.vel * dt
	p.position.x = clampf(p.position.x, -HL - 2.5, HL + 2.5)
	p.position.z = clampf(p.position.z, -HW - 2.5, HW + 2.5)
	if p.role == "GK" and state == "play" and ball_owner != p:
		p.face(ball.position - p.position, 10.0, dt)
	elif p.jock and ball_owner != null:
		p.face(ball_owner.position - p.position, 9.0, dt)
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
	if ball_spin != 0.0:
		ball_vel = ball_vel.rotated(Vector3.UP, ball_spin * dt)
	ball.position += ball_vel * dt
	if ball.position.y <= BALL_R:
		ball.position.y = BALL_R
		ball_spin *= maxf(1.0 - 5.0 * dt, 0.0)
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
			var ns := maxf(sp - (1.3 + 0.28 * sp) * dt, 0.0)
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

# Where the man a pass is meant for can first get to the ball: he runs on to a ball played ahead of him
# and comes to meet one played short, instead of always running at the ball.
func _meet_for(p, aim: Vector3) -> Vector3:
	if ball_owner != null or ball.position.y > 1.0 or ball_vel.y > 3.0:
		return aim
	var v := Vector3(ball_vel.x, 0, ball_vel.z)
	var sp := v.length()
	if sp < 2.0:
		return aim
	var dir := v / sp
	var drag := 1.5 + 0.35 * sp
	var t_stop := sp / drag
	var b0 := Vector3(ball.position.x, 0, ball.position.z)
	var out := b0
	var t := 0.1
	while t < 3.0:
		var tt := minf(t, t_stop)
		out = b0 + dir * (sp * tt - 0.5 * drag * tt * tt)
		if p.position.distance_to(out) <= p.top_speed * 0.85 * t + 0.5:
			break
		t += 0.1
	return out

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

func _release(p, v: Vector3, kind := 0) -> void:
	var h := Vector3(v.x, 0, v.z).normalized()
	p.yaw = atan2(-h.x, -h.z)
	p.start_kick(clampf((v.length() - 9.0) / 20.0, 0.2, 1.0), kind)
	ball_owner = null
	ball.position = p.position + h * 0.75 + Vector3(0, BALL_R + 0.05, 0)
	if kind == 2:
		ball.position = p.position + h * 0.4 + Vector3(0, 2.3, 0)
	ball_vel = v
	ball_spin = 0.0
	ball_last = p
	ball_ignore = p
	ignore_t = 0.3
	if set_piece == "kick":
		protect_t = maxf(protect_t, 1.2)
	set_piece = ""
	pen_wait = false
	p.hold_t = 0.0
	for q in players:
		q.recv = false
		q.offside = false

func _pass_target(p, dir3: Vector3, ai: bool, want_d := -1.0, thru := false):
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
			sc += a * 5.0
			# power picks the distance: a tap finds the near man, a long hold the far one
			sc -= (absf(d - want_d) * 0.07) if want_d > 0.0 else d * 0.02
		else:
			sc += n.x * s * 1.6 - absf(d - 15.0) * 0.04
		if m.role == "GK":
			sc -= 3.0
		if thru:
			# a through ball looks for the man going forward
			sc += clampf(m.vel.x * s, -2.0, 7.0) * 0.22 + clampf((m.position.x - p.position.x) * s, -10.0, 10.0) * 0.08
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

func _pass(p, m, lofted: bool, cross := false, lead := 0.0) -> void:
	var to: Vector3 = m.position - p.position
	to.y = 0.0
	var d := to.length()
	var v := Vector3.ZERO
	var thrown := set_piece == "throw"
	var leadv := Vector3.ZERO
	if lead > 0.0:
		var md: Vector3 = m.vel
		md.y = 0.0
		leadv = Vector3(side(p.team), 0, 0) * 0.7
		if md.length() > 1.5:
			leadv += md.normalized() * 0.45
		leadv = leadv.normalized() * lead
	if thrown:
		# thrown by hand: a soft arc, never far
		var vt := clampf(6.0 + d * 0.42, 7.0, 14.5)
		var tt := d / vt
		var aim3: Vector3 = m.position + m.vel * tt * 0.6
		var dir3: Vector3 = aim3 - p.position
		dir3.y = 0.0
		if dir3.length() > 24.0:
			dir3 = dir3.normalized() * 24.0
		tt = dir3.length() / vt
		v = dir3.normalized() * vt + Vector3(0, (0.4 - 2.3) / tt + 4.9 * tt, 0)
	elif cross:
		# whipped in to arrive at head height
		var vc := clampf(11.0 + d * 0.32, 15.0, 22.0)
		var tc := d / vc
		var aim4: Vector3 = m.position + m.vel * tc * 0.5
		var dir4: Vector3 = aim4 - p.position
		dir4.y = 0.0
		tc = dir4.length() / vc
		v = dir4.normalized() * vc + Vector3(0, (2.05 - 0.3) / tc + 4.9 * tc, 0)
	elif not lofted:
		var sp := clampf(8.0 + d * 0.75, 12.0, 27.0)
		if pass_pw >= 0.0:
			# a held pass is struck harder
			sp = minf(sp * lerpf(0.97, 1.18, pass_pw), 29.0)
		var aim: Vector3 = m.position + m.vel * (d / sp) * 0.8 + leadv
		aim.x = clampf(aim.x, -HL + 3.0, HL - 3.0)
		aim.z = clampf(aim.z, -HW + 2.0, HW - 2.0)
		var dir: Vector3 = (aim - p.position)
		dir.y = 0.0
		if lead > 0.0:
			# weighted to slow down in front of him
			sp = clampf(8.5 + dir.length() * 0.72, 13.0, 27.0)
		v = dir.normalized() * sp + Vector3(0, 0.6, 0)
	else:
		# a real high ball: about 1.0 s over 10 m, 1.6 s over 30 m, and drops at the receiver's feet
		var t := clampf(0.62 + d * 0.034, 0.8, 2.15)
		var aim2: Vector3 = m.position + m.vel * t * 0.7 + (leadv * 1.2 if lead > 0.0 else Vector3(side(p.team) * 2.0, 0, 0))
		aim2.x = clampf(aim2.x, -HL + 3.0, HL - 3.0)
		aim2.z = clampf(aim2.z, -HW + 2.0, HW - 2.0)
		var dir2: Vector3 = (aim2 - p.position)
		dir2.y = 0.0
		t = clampf(0.62 + dir2.length() * 0.034, 0.8, 2.15)
		var vh := dir2.length() / t * (1.0 + 0.026 * t)
		v = dir2.normalized() * vh + Vector3(0, 4.9 * t + 0.12 * t * t, 0)
	v = v.rotated(Vector3.UP, (randf() - 0.5) * 2.0 * maxf(92 - p.pas, 0) * 0.0011 * (1.6 if lofted else 1.0))
	var h = _hum_of(p)
	var offs: bool = set_piece in ["", "fk", "kick"] and _is_offside(p, m)
	_release(p, v, 2 if thrown else 0)
	if cross:
		ball_spin = 0.0
	m.recv = true
	if offs:
		m.offside = true
		off_spot = m.position
	stats["passes"] += 1
	pass_from = p
	pass_pw = -1.0
	snd("kick" if (lofted or d > 22.0) and not thrown else "touch")
	if lofted and not thrown:
		fx("shake", 0.1)
	if h != null and m.role != "GK" and _hum_of(m) == null:
		h.ctrl = m
		h.switch_cool = 0.5
	if _team_human(1 - p.team):
		_switch_for_pass(1 - p.team, m)

func _human_aim(h, dir3: Vector3) -> float:
	var gk = teams[1 - h.team][0]
	if absf(dir3.z) > 0.3:
		return clampf(dir3.z * 1.3, -1.0, 1.0) * GOAL_HW * 0.82
	return (-1.0 if gk.position.z > 0.0 else 1.0) * GOAL_HW * 0.62

func _shoot(p, power: float, aim_z: float, err_k: float, curl := 0.0) -> void:
	var s := side(p.team)
	var from := ball.position
	var d := Vector2(HL * s - from.x, aim_z - from.z).length()
	if d > 42.0 and set_piece != "pen":
		# Too far out to shoot: SHOOT is a clearance, a long ball the way the stick points (or the way he faces).
		var hh = _hum_of(p)
		var cd: Vector3 = p.fwd()
		if hh != null and hh.stick.length() > 0.3:
			cd = Vector3(hh.stick.x, 0, hh.stick.y).normalized()
		var far := 24.0 + 22.0 * power
		var tc := 1.4 + 1.0 * power
		_release(p, cd * (far / tc) + Vector3(0, 4.9 * tc, 0))
		snd("kick")
		fx("dust", [from.x, from.z])
		return
	err_k *= lerpf(1.3, 0.72, clampf((p.sho - 40) / 50.0, 0.0, 1.0))
	var err := (randf() - 0.5) * (0.4 + d * 0.035 + power * 0.8) * err_k
	var goal := Vector3(HL * s, 0, aim_z + err)
	var dir := goal - from
	dir.y = 0.0
	dir = dir.normalized()
	var sp := 19.0 + 13.0 * power
	var t := maxf(d / sp, 0.15)
	# full power rises: from close in and from the edge of the box it tends to fly over, as it should
	var h := 0.35 + power * power * 2.1 + randf() * 0.6 * power * err_k
	var vy := (h - 0.25) / t + 4.9 * t
	# a curled shot starts wide of its target and bends back in
	var spin := 0.0
	if curl > 0.0 and d > 9.0:
		spin = curl * lerpf(0.7, 1.15, clampf((p.sho - 50) / 40.0, 0.0, 1.0))
		var wide := dir.rotated(Vector3.UP, -spin * t * 0.5)
		var sg := signf(goal.z) if absf(goal.z) > 0.3 else (1.0 if randf() < 0.5 else -1.0)
		if (wide.z - dir.z) * sg < 0.0:
			spin = -spin
			wide = dir.rotated(Vector3.UP, -spin * t * 0.5)
		dir = wide
	_release(p, dir * sp + Vector3(0, vy, 0))
	ball_spin = spin
	shot_live = true
	stats["shots"] += 1
	tst[p.team]["shots"] += 1
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
	pass_from = null
	p.feet = false
	p.hold_t = 0.0
	p.ai_cool = _cpu(p.team)["think"] * (0.8 + randf() * 0.6)
	for q in players:
		q.recv = false
		q.offside = false
		q.step_t = 0.0
		q.wait_t = 0.0
	var hr = _hum_of(p)
	if hr != null and hr.stick.length() > 0.3 and p.role != "GK" and set_piece == "" and state == "play":
		# first touch goes the way the stick points
		var sd := Vector3(hr.stick.x, 0, hr.stick.y).normalized()
		p.vel = sd * clampf(p.vel.length(), 3.2, p.top_speed * 0.8)
	if _team_human(p.team) and prev != null and prev.team == p.team:
		# a first touch in peace: nobody takes the ball off you the instant a pass arrives
		protect_t = maxf(protect_t, 0.4)
	for h in humans:
		h.charging = false
		h.charge = 0.0
		h.pass_hold = -1.0
	if _hum_of(p) == null:
		# the keeper too: he makes his saves by himself, but with the ball in his hands the throw or kick is yours
		var h2 = _nearest_human(p.team, p.position)
		if h2 != null:
			h2.ctrl = p
	_assign_defenders(1 - p.team, prev == null or prev.team != p.team)

func _human_tackle(h, standing := false) -> void:
	var c = ball_owner
	var me_p = h.ctrl
	if me_p.stun > 0.0 or me_p.tackle_t >= 0.0:
		return
	var bd: float = Vector2(me_p.position.x - ball.position.x, me_p.position.z - ball.position.z).length()
	# SPRINT held and still a few steps away: a slide tackle. Otherwise a standing tackle.
	# TACKLE is always a slide, as in the 2D game. Only the help (hold, or running into the ball) is a foot in.
	if not standing:
		_slide_tackle(h)
		return
	# Standing tackle: a step and a foot in for the ball. Win it and he keeps it at his feet and plays on.
	me_p.start_kick(0.25)
	if c == null or c.team == h.team:
		me_p.stun = 0.2
		return
	var to: Vector3 = ball.position - me_p.position
	to.y = 0.0
	if bd < 3.0 and bd > 0.05:
		# he lunges at the ball, so a tackle from a step away still gets there
		me_p.yaw = atan2(-to.x, -to.z)
		me_p.vel = to.normalized() * 7.2
	# reach: a better defender gets a longer leg in, a stronger carrier holds him off
	var reach: float = 1.6
	if bd < reach and protect_t <= 0.0 and not c.hands():
		var front: float = c.fwd().dot((me_p.position - c.position).normalized())
		var pd: float = me_p.position.distance_to(c.position)
		if front < -0.5 and pd < bd and c.vel.length() > 2.0:
			# Chasing him from behind there is no ball to win: a tug on the shirt and a shoulder slow him down
			# so you can get round him. Keep doing it and the referee gives a free kick.
			if pd < 1.5:
				h.pull_n = (h.pull_n + 1) if h.pull_t > 0.0 else 1
				h.pull_t = 2.5
				if h.pull_n >= 3:
					h.pull_n = 0
					_foul(me_p, c)
				else:
					c.vel *= 0.5
					snd("touch")
			me_p.stun = 0.15
			return
		_poke(me_p, c)
		return
	me_p.stun = 0.22

func _slide_tackle(h) -> void:
	# A real slide: he throws himself along the grass towards the ball and keeps sliding for a few metres.
	# Whatever his leading foot meets on the way decides it: the ball is won, the man from behind is a foul.
	var c = ball_owner
	var me_p = h.ctrl
	me_p.start_tackle()
	var dirs: Vector3 = me_p.fwd()
	var to: Vector3 = ball.position - me_p.position
	to.y = 0.0
	# he only finds the ball by himself when it is close and in front of him; from further out you aim the slide yourself
	if h.stick.length() > 0.3 and to.length() >= 4.0:
		dirs = Vector3(h.stick.x, 0, h.stick.y).normalized()
		me_p.yaw = atan2(-dirs.x, -dirs.z)
	if to.length() < 4.0 and to.length() > 0.1 and dirs.dot(to.normalized()) > 0.35 and (c == null or c.team != h.team):
		var lead: Vector3 = to + (c.vel * 0.18 if c != null else Vector3(ball_vel.x, 0, ball_vel.z) * 0.18)
		dirs = lead.normalized()
		me_p.yaw = atan2(-dirs.x, -dirs.z)
	# like the 2D game: a fast burst along the grass, more than twice his running speed, about six metres
	me_p.slide_dir = dirs
	me_p.vel = dirs * SLIDE_V
	me_p.slide_live = true
	me_p.slide_fx = 0.0
	me_p.stun = SLIDE_T + 0.3
	snd("slide")
	fx("dust", [me_p.position.x, me_p.position.z])

func _slides() -> void:
	for p in players:
		if not p.slide_live:
			continue
		if p.tackle_t < 0.0 or p.tackle_t > SLIDE_T + 0.02:
			# the slide found nothing: he is on the grass for a second, and the man with the ball is away
			p.slide_live = false
			p.stun = maxf(p.stun, 1.0)
			p.vel *= 0.3
			continue
		# grass flies up all the way along the slide
		p.slide_fx -= get_process_delta_time()
		if p.slide_fx <= 0.0:
			p.slide_fx = 0.07
			fx("dust", [p.position.x, p.position.z])
		var c = ball_owner
		var bd: float = Vector2(p.position.x - ball.position.x, p.position.z - ball.position.z).length()
		if c == null:
			if bd < 1.0 and ball.position.y < 0.8 and state == "play" and set_piece == "":
				p.slide_live = false
				p.stun = 0.3
				snd("touch")
				_give(p)
		elif c.team != p.team and not c.hands() and protect_t <= 0.0 and set_piece == "":
			var front: float = c.fwd().dot((p.position - c.position).normalized())
			var pd: float = p.position.distance_to(c.position)
			if bd < 1.15 + (p.dfn - 60) * 0.004:
				p.slide_live = false
				if front > -0.45:
					c.stun = 0.6
					c.start_fall(0.6)
					stats["tackles"] += 1
					snd("win")
					fx("shake", 0.3)
					fx("vib", 40)
					p.stun = 0.3
					_give(p)
					protect_t = 0.7
				else:
					_foul(p, c)
			elif pd < 0.75:
				# missed the ball and took the man
				p.slide_live = false
				_foul(p, c, true)

# How good the moment is for a foot in, the 2D game's rule (no dice): how close the foot is to the ball,
# whether the ball is out of his feet (sprinting) or tucked in (slow, turning), whether his body is between
# you and the ball (he shields it), the angle, whether you are set or flying in, and defending against his dribbling.
# 0.5 or more wins it clean, 0.36 or more knocks it loose, less is a miss.
func _tq(p, c) -> float:
	var dt2: float = Vector2(p.position.x - ball.position.x, p.position.z - ball.position.z).length()
	var dpo: float = maxf(Vector2(p.position.x - c.position.x, p.position.z - c.position.z).length(), 0.01)
	var reach: float = 1.3 + clampf((p.dfn - 40) / 55.0, 0.0, 1.0) * 0.25
	if dt2 > reach:
		return -1.0
	var cs: float = c.vel.length()
	var ctop: float = maxf(c.top_speed, 1.0)
	var expo := 0.25
	if c.skill_t >= 0.0:
		expo = 0.0
	elif cs > ctop * 0.3:
		expo = 1.0 if cs > ctop * 0.88 else 0.45
	var shield: float = clampf((dt2 - dpo - 0.06) / 0.37, 0.0, 1.0)
	var rear: float = -c.fwd().dot((p.position - c.position) / dpo)
	var ang: float = 0.07 if rear < -0.3 else (0.03 if rear < 0.3 else -0.12)
	var ptop: float = maxf(p.top_speed, 1.0)
	var setk: float = 0.06 if p.vel.length() < ptop * 0.65 else 0.0
	var vin: float = p.vel.dot((c.position - p.position) / dpo)
	var lunge: float = maxf(0.0, vin - ptop * 0.75) / ptop
	var cdr: float = clampf((c.ovr - 40) / 55.0, 0.0, 1.0)
	var duel: float = (clampf((p.dfn - 40) / 55.0, 0.0, 1.0) - (cdr * 0.6 + clampf((c.pac - 40) / 55.0, 0.0, 1.0) * 0.2 + clampf((c.phy - 40) / 55.0, 0.0, 1.0) * 0.2)) * 0.3
	return 0.14 + (1.0 - dt2 / reach) * 0.3 + expo * 0.38 - shield * (0.35 + 0.3 * clampf((c.phy - 40) / 55.0, 0.0, 1.0)) + ang + setk - lunge * 0.3 + duel - (0.3 if c.skill_t >= 0.0 else 0.0)

# The foot goes in: won clean, knocked loose between the two, or missed. Returns true when the ball changed hands or went loose.
func _poke(p, c) -> bool:
	var q := _tq(p, c)
	stats["pq"] = int(stats.get("pq", 0)) + 1
	if q >= 0.5:
		c.stun = 0.4
		c.vel *= 0.3
		stats["tackles"] += 1
		snd("win")
		_give(p)
		protect_t = 0.7
		return true
	if q >= 0.36:
		# a toe on it: it squirts loose and whoever reacts first has it
		var dv: Vector3 = ball.position - p.position
		dv.y = 0.0
		ball_owner = null
		ball_vel = dv.normalized() * 4.7 + c.vel * 0.35
		ball_last = p
		ball_ignore = c
		ignore_t = 0.25
		c.vel *= 0.6
		p.vel *= 0.5
		snd("touch")
		stats["nick"] = int(stats.get("nick", 0)) + 1
		return true
	# missed: he is past you
	p.stun = 0.3 + (0.25 if q < 0.0 else 0.0)
	p.vel *= 0.3
	stats["pmiss"] = int(stats.get("pmiss", 0)) + 1
	return false

func _tackles(dt: float) -> void:
	var c = ball_owner
	if c == null or c.hands() or protect_t > 0.0:
		return
	# a sharp turn wrong-foots anyone who was about to step in
	var cv: Vector3 = c.vel
	if cv.length() > 3.0:
		var cd: Vector3 = cv.normalized()
		if car_dir.dot(cd) < 0.45 and car_dir.length() > 0.5:
			car_dir = cd
			for o in teams[1 - c.team]:
				if o.commit_t < 0.0:
					o.press_t = 0.0
					if o.step_t > 0.0:
						o.step_t = 0.0
						o.wait_t = 0.0
		car_dir = car_dir.lerp(cd, clampf(dt * 4.0, 0.0, 1.0)).normalized()
	for o in teams[1 - c.team]:
		if o.stun > 0.0 or _hum_of(o) != null or o.role == "GK":
			continue
		# a tackle has to reach the ball, not the man: a body between defender and ball shields it
		var d: float = Vector2(o.position.x - ball.position.x, o.position.z - ball.position.z).length()
		if c.vel.length() < 2.0:
			# shielding only works on the move: a man who stands still gets robbed
			d = minf(d, o.position.distance_to(c.position) - 0.1)
		var front: float = c.fwd().dot((o.position - c.position).normalized())
		if o.commit_t >= 0.0:
			# the tackle is already on its way: it lands a moment later, wherever the carrier has turned by then
			o.commit_t -= dt
			if o.commit_t <= 0.0:
				o.commit_t = -1.0
				o.step_t = 0.0
				if front < -0.5 and d < 1.15 and c.vel.length() >= 2.0:
					_foul(o, c)
					return
				if _poke(o, c):
					return
			continue
		# only the man who steps in makes a tackle; anyone else only if you run right into him
		var stepping: bool = o.step_t > 0.0 or _team_human(o.team)
		var reach := 1.05 if stepping else 0.8
		reach += (o.dfn - 60) * 0.004 - (c.phy - 60) * 0.004
		# a man who stands still on the ball can be robbed from any side
		var still: bool = c.vel.length() < 2.0
		# a clever defender waits until the ball is out of your feet; a poor one goes in early
		var want_q: float = 0.42 - (1.0 - clampf((o.dfn - 40) / 45.0, 0.0, 1.0)) * 0.2
		if d < reach + 0.25 and (still or front > (0.0 if stepping else 0.3)) and _tq(o, c) >= want_q:
			o.press_t += dt
			var need: float = _cpu(o.team)["need"]
			if _team_human(o.team):
				need = 0.6
			elif not stepping:
				need *= 1.4
			need *= lerpf(1.15, 0.88, clampf((o.dfn - 40) / 45.0, 0.0, 1.0))
			if o.press_t > need - 0.15:
				o.press_t = 0.0
				o.commit_t = 0.15
				o.start_kick(0.25)
		else:
			o.press_t = maxf(o.press_t - dt * 2.0, 0.0)

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
		var gq: float = clampf((g.dfn - 60) / 30.0, 0.0, 1.0)
		var reach := 0.8 + (lerpf(0.72, 0.86, gq) if g.dive_t >= 0.0 else 0.0)
		# high balls are harder to reach, so the top corners are open to a good shot
		if shot_live:
			reach -= maxf(b.y - 1.5, 0.0) * 0.45
		var dh := Vector2(b.x - g.position.x, b.z - g.position.z).length()
		if dh < reach and b.y < 2.6:
			# good keepers hold harder shots, the rest push them away
			if hs > lerpf(15.0, 21.0, gq) and dh > 0.55:
				var sgn := signf(b.z - g.position.z)
				ball_vel = Vector3(-ball_vel.x * 0.3, absf(ball_vel.y) * 0.4 + 2.5, ball_vel.z * 0.4 + sgn * 5.0)
				ball_ignore = g
				ignore_t = 0.5
				ball_last = g
				shot_live = false
				stats["saves"] += 1
				tst[t]["saves"] += 1
				snd("touch")
				snd("ooh")
				fx("shake", 0.3)
				fx("say", "What a save!")
			else:
				if shot_live:
					stats["saves"] += 1
					tst[t]["saves"] += 1
					snd("ooh")
				snd("touch")
				# Back pass rule: a ball a team mate played to him on purpose he may not pick up. He takes it
				# with his feet, and then he can be closed down and tackled like anyone else.
				var bp: bool = pass_from != null and pass_from.team == t and ball_last == pass_from and pass_from != g
				_give(g)
				g.feet = bp
			return
	if b.y > 1.7:
		if b.y < 2.75 and hs < 27.0 and ball_vel.y < 3.0 and state == "play":
			var hb = null
			var hd := 1.25
			for p in players:
				if p.stun > 0.0 or p.role == "GK" or p.off or (p == ball_ignore and ignore_t > 0.0) or p.head_t >= 0.0:
					continue
				var d2 := Vector2(b.x - p.position.x, b.z - p.position.z).length() - randf() * 0.35
				if d2 < hd:
					hd = d2
					hb = p
			if hb != null:
				if hb.offside:
					_offside(hb)
				else:
					_header(hb)
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
		if p.hold_t > (0.45 if p.feet else 1.1):
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
			var m2 = _cross_target(p) if set_piece == "corner" else _pass_target(p, Vector3.ZERO, true)
			if m2 == null:
				m2 = teams[p.team][6]
			_pass(p, m2, set_piece == "corner" or set_piece == "gk", set_piece == "corner")
		return Vector3.ZERO
	if nd < 2.0 and p.star and p.skill_t < 0.0 and protect_t <= 0.0 and randf() < dt * 0.9:
		_skill(p, Vector3(s, 0, signf(p.position.z - near.position.z) * 0.7))
	if nd < 2.6 and p.ai_cool > 0.12:
		p.ai_cool = 0.12 # a man is on me: decide now
	if p.ai_cool <= 0.0:
		p.ai_cool = cpu["think"] * (0.8 + randf() * 0.6)
		var angle_ok := absf(p.position.z) < 8.0 + (HL - absf(p.position.x)) * 0.8
		if dist < 24.0 and angle_ok and (nd > 1.7 or dist < 14.0):
			if dist < 20.0 or randf() < 0.4:
				var gk = teams[1 - p.team][0]
				var az := (-1.0 if gk.position.z > 0.0 else 1.0) * GOAL_HW * (0.5 + randf() * 0.28)
				_shoot(p, 0.5 + randf() * 0.4, az, cpu["err"], 0.7 if (p.sho > 74 and randf() < 0.6) else 0.0)
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
	return dir.normalized() * p.top_speed * p.carry_k * 0.99 * cpu["spd"]

func _ai_offball(p, chaser: Array, second: Array, aim: Vector3) -> Vector3:
	var t: int = p.team
	var s := side(t)
	var cpu := _cpu(t)
	var loose: bool = ball_owner == null
	var ours: bool = not loose and ball_owner.team == t
	p.jock = false
	if p.recv and loose:
		return _run_to(p, _meet_for(p, aim), p.top_speed)
	if loose and p == chaser[t]:
		return _run_to(p, aim, p.top_speed * cpu["spd"])
	if not loose and not ours and set_piece == "":
		var c = ball_owner
		var own_goal := Vector3(-HL * s, 0, 0)
		var goal_side: Vector3 = (own_goal - c.position).normalized()
		if p == chaser[t]:
			if _team_human(t):
				# your team mate holds the runner up; you make the tackle.
				# But if you are far away, or the runner is close to your goal, he goes in himself.
				var hd := 99.0
				for hm in humans:
					if hm.team == t and hm.ctrl != null:
						hd = minf(hd, hm.ctrl.position.distance_to(c.position))
				if hd > 4.5 or c.position.distance_to(own_goal) < 30.0:
					return _run_to(p, c.position + c.vel * 0.25 + goal_side * 0.5, p.top_speed * 0.95)
				return _run_to(p, c.position + goal_side * 2.6, p.top_speed * 0.95)
			# Defending like a real defender: get goal side, hold him up at arm's length and follow,
			# and only step in when he slows down, comes close to goal, or has been held up for a while.
			var dd: float = p.position.distance_to(c.position)
			var gs: bool = (p.position - c.position).dot(goal_side) > 0.25 * dd
			var gd: float = c.position.distance_to(own_goal)
			if p.step_t > 0.0:
				p.step_t -= tdt
				return _run_to(p, c.position + c.vel * 0.2 + goal_side * 0.4, p.top_speed * 0.93 * cpu["spd"])
			if not gs or dd > 5.0:
				p.wait_t = 0.0
				return _run_to(p, c.position + c.vel * 0.6 + goal_side * 3.4, p.top_speed * 0.95 * cpu["spd"])
			p.wait_t += tdt
			var patience: float = cpu["wait"]
			if c.vel.length() < c.top_speed * 0.5:
				patience *= 0.45
			if gd < 24.0:
				patience *= 0.35
			if p.wait_t > patience:
				p.wait_t = 0.0
				p.step_t = 0.9
			p.jock = true
			return _run_to(p, c.position + c.vel * 0.35 + goal_side * 2.5, p.top_speed * 0.82 * cpu["spd"])
		if p == second[t]:
			# the cover man shuts the road to goal behind the first defender
			var cvd: float = clampf(c.position.distance_to(own_goal) * 0.22, 3.5, 6.5)
			return _run_to(p, c.position + c.vel * 0.3 + goal_side * cvd, p.top_speed * 0.97)
	var bu: float = ball.position.x * s
	var att: bool = att_team == t
	var u: float = -45.0 + p.home.x * 62.0 + bu * 0.6
	var z: float = p.home.y * s * 21.0 + ball.position.z * 0.42
	var hurry := false
	if att:
		# With the ball the whole team moves up with it, like a real side: the back line squeezes up,
		# the midfield stays close around the ball, full backs overlap and the forwards stretch the line.
		var wide: bool = absf(p.home.y) > 0.6
		var same: bool = p.home.y * s * ball.position.z > 0.0
		z = p.home.y * s * 29.0 + ball.position.z * 0.25
		u = bu + (p.home.x - 0.40) * 50.0
		if p.role == "DF":
			if wide:
				u = clampf(bu - (4.0 if same and bu > 0.0 else 14.0), -40.0, 40.0)
			else:
				u = clampf(bu - 24.0, -42.0, 8.0)
		elif p.role == "MF":
			if p.home.x <= 0.38:
				u -= 5.0
			u = clampf(u, -30.0, 40.0)
		else:
			u = clampf(u + 3.0 * sin(clock * 0.02 + p.idx * 2.0), -6.0, 47.0)
		if bu > 26.0:
			# around their box: men at both posts, midfielders on the edge for the cut back
			if p.role == "FW":
				if not wide:
					u = 45.5
					z = p.home.y * s * 18.0 + clampf(ball.position.z * 0.15, -3.0, 3.0)
				elif not same:
					u = 46.0
					z = signf(p.home.y * s) * 6.5
			elif p.role == "MF":
				u = clampf(bu - 7.0, 31.0, 37.0)
				z = p.home.y * s * 17.0 + ball.position.z * 0.2
		u = minf(u, maxf(off_line[t] - 0.8, 0.0))
		hurry = u - p.position.x * s > 5.0
	elif p.role == "DF":
		u = clampf(u, -46.0, 14.0)
	else:
		u = clampf(u, -40.0, 47.0)
	z = clampf(z, -HW + 1.5, HW - 1.5)
	var spot := Vector3(u * s, 0, z)
	p.think_t -= tdt
	if ours and set_piece == "":
		var c2 = ball_owner
		if sup[t].has(p):
			# Offer for the ball: find a spot near the man on the ball that he can actually pass to,
			# away from markers, a little ahead of him if possible, and not on top of a team mate.
			if p.think_t <= 0.0:
				p.think_t = 0.35 + randf() * 0.15
				var cur: Vector3 = p.position - c2.position
				cur.y = 0.0
				if cur.length() < 0.5:
					cur = Vector3(s, 0, 0)
				var cn: Vector3 = cur.normalized()
				var bs := -1e9
				for k in [-2, -1, 0, 1, 2]:
					var dc: Vector3 = cn.rotated(Vector3.UP, k * 0.55)
					for r in [8.0, 13.0]:
						var q: Vector3 = c2.position + dc * r
						if absf(q.x) > HL - 2.0 or absf(q.z) > HW - 2.0:
							continue
						var sc: float = (q.x - c2.position.x) * s * 0.14 - absf(k) * 0.5
						if q.x * s > off_line[t] - 0.5:
							sc -= 6.0
						var free := 8.0
						var lane := 4.0
						for o in teams[1 - t]:
							free = minf(free, o.position.distance_to(q))
							var ap: Vector3 = o.position - c2.position
							var tt: float = clampf(ap.dot(dc), 0.0, r)
							lane = minf(lane, (ap - dc * tt).length())
						sc += free * 0.9 + lane * 1.6
						for m2 in teams[t]:
							if m2 != p and m2 != c2 and m2.position.distance_to(q) < 6.0:
								sc -= 1.2
						if sc > bs:
							bs = sc
							p.think_at = q
			return _run_to(p, p.think_at, p.top_speed * 0.95)
		if runner[t].has(p):
			# A run in behind: along the last line, into the widest gap between defenders, never offside.
			if p.think_t <= 0.0:
				p.think_t = 0.5
				var ru: float = maxf(off_line[t] - 0.6, u)
				var bz: float = p.position.z
				var bg := -1.0
				for dz in [-9.0, -4.0, 0.0, 4.0, 9.0]:
					var zz: float = clampf(p.position.z + dz, -HW + 4.0, HW - 4.0)
					var gap := 12.0
					for o in teams[1 - t]:
						if o.role != "GK" and absf(o.position.x * s - off_line[t]) < 8.0:
							gap = minf(gap, absf(o.position.z - zz))
					gap -= absf(dz) * 0.15 + absf(zz) * 0.05
					if gap > bg:
						bg = gap
						bz = zz
				p.think_at = Vector3(ru * s, 0, bz)
			return _run_to(p, p.think_at, p.top_speed)
	elif not ours and not loose and set_piece == "" and p != chaser[t] and p != second[t]:
		# Mark up: pick up the opponent in your area and stand goal side of him, instead of guarding a patch of grass.
		var reach := 11.0 if p.role == "DF" else 9.0
		var mk = null
		for o in teams[1 - t]:
			if o == ball_owner or o.role == "GK":
				continue
			var dm: float = o.position.distance_to(spot)
			if dm < reach:
				reach = dm
				mk = o
		if mk != null:
			var og := Vector3(-HL * s, 0, 0)
			var gs2: Vector3 = (og - mk.position).normalized()
			var tb: Vector3 = (ball.position - mk.position)
			tb.y = 0.0
			# goal side and a touch towards the ball, so a pass to him can be cut out
			var mp: Vector3 = mk.position + gs2 * 1.9 + tb.normalized() * 0.7
			spot = spot.lerp(mp, 0.7 if p.role != "DF" else 0.6)
			return _run_to(p, spot, p.top_speed * 0.92)
	return _run_to(p, spot, p.top_speed * (1.0 if hurry else 0.88))

func _ai_keeper(p, dt: float) -> Vector3:
	var s := side(p.team)
	var gx := -HL * s
	var goal := Vector3(gx, 0, 0)
	var b := ball.position
	if ball_owner == null and ball_vel.x * -s > 5.0:
		var t := (gx - b.x) / ball_vel.x
		if t > 0.0 and t < 1.7:
			var zc := b.z + ball_vel.z * t
			if ball_spin != 0.0:
				# the keeper reads most of the bend on a curled shot
				var bent := ball_vel.rotated(Vector3.UP, ball_spin * t * 0.45)
				if absf(bent.x) > 1.0:
					zc = b.z + bent.z * ((gx - b.x) / bent.x)
			if absf(zc) < GOAL_HW + 1.2:
				p.react_t += dt
				if p.react_t < lerpf(0.27, 0.19, clampf((p.dfn - 60) / 30.0, 0.0, 1.0)):
					return p.vel * 0.5
				var target := Vector3(gx + s * 0.7, 0, clampf(zc, -GOAL_HW + 0.2, GOAL_HW - 0.2))
				# off his line he saves where he stands instead of running back to the goal line
				var tk: float = (p.position.x - b.x) / ball_vel.x
				if tk > 0.0 and absf(p.position.x - gx) > 1.2:
					t = tk
					var zk: float = b.z + ball_vel.z * tk
					if ball_spin != 0.0:
						# he reads the bend out here too
						var bent2 := ball_vel.rotated(Vector3.UP, ball_spin * tk * 0.45)
						if absf(bent2.x) > 1.0:
							zk = b.z + bent2.z * ((p.position.x - b.x) / bent2.x)
					target = Vector3(p.position.x, 0, zk)
				var dz: float = target.z - p.position.z
				if long_test and long_n < 4:
					print("KDBG n=", long_n, " t=", snappedf(t, 0.01), " zc=", snappedf(zc, 0.01), " tz=", snappedf(target.z, 0.01), " pz=", snappedf(p.position.z, 0.01), " px=", snappedf(p.position.x, 0.1), " dive=", snappedf(p.dive_t, 0.01), " by=", snappedf(b.y, 0.01), " spin=", snappedf(ball_spin, 0.01))
				if absf(dz) > 1.0 and t < 0.6 and p.dive_t < 0.0:
					var right := Vector3(cos(p.yaw), 0, -sin(p.yaw))
					p.start_dive(signf(Vector3(0, 0, dz).dot(right)))
					p.vel = Vector3(0, 0, signf(dz) * DIVE_V)
				if p.dive_t >= 0.0:
					# in the air he keeps his speed all the way to the ball
					var dv: Vector3 = target - p.position
					dv.y = 0.0
					return dv.normalized() * DIVE_V if dv.length() > 0.25 else Vector3.ZERO
				return _run_to(p, target, 4.2)
	p.react_t = 0.0
	if ball_owner == null and absf(b.x - gx) < 15.0 and absf(b.z) < 18.0 and ball_vel.length() < 12.0:
		var mine: float = p.position.distance_to(b)
		var theirs := 99.0
		for o in teams[1 - p.team]:
			theirs = minf(theirs, o.position.distance_to(b))
		if mine < theirs + 1.0:
			return _run_to(p, Vector3(b.x, 0, b.z), p.top_speed)
	# a cross or high ball dropping in front of goal: come and claim it
	if ball_owner == null and b.y > 2.0 and set_piece == "":
		var lp := _ball_meet_point()
		if absf(lp.x - gx) < 8.5 and absf(lp.z) < 10.0:
			return _run_to(p, lp, p.top_speed)
	var d := b - goal
	d.y = 0.0
	var dist := d.length()
	var c = ball_owner
	if c != null and c.team != p.team and set_piece == "" and dist < 17.0 and absf(b.z) < 18.0:
		# one on one: if no defender is between the runner and the goal, come out and make yourself big
		var cover := false
		var dn: Vector3 = d / maxf(dist, 0.1)
		for m in teams[p.team]:
			if m == p or m.off or m.stun > 0.0:
				continue
			var am: Vector3 = m.position - goal
			var tm: float = am.dot(dn)
			if tm > 1.0 and tm < dist - 0.8 and (am - dn * tm).length() < 3.5:
				cover = true
		if not cover:
			if p.position.distance_to(b) < 3.0 and absf(b.x - gx) < 16.0:
				# down at his feet
				return _run_to(p, Vector3(b.x, 0, b.z), p.top_speed)
			var o1 := clampf(dist * 0.28, 1.5, 4.5)
			return _run_to(p, goal + dn * o1, 6.2)
	# stands higher the further away the ball is, to sweep up behind a high back line
	var out := clampf(dist * 0.11, 1.0, 4.5) + clampf((dist - 45.0) * 0.14, 0.0, 4.5)
	var target2 := goal + d.normalized() * out
	target2.z = clampf(target2.z, -3.3, 3.3)
	return _run_to(p, target2, 5.8)

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

func _record(dt: float) -> void:
	if _quiet():
		return
	rec_acc += dt
	if rec_acc >= 1.0 / 30.0:
		rec_acc = minf(rec_acc - 1.0 / 30.0, 1.0 / 30.0)
		rec.append(_pack())
		if rec.size() > 360:
			rec.pop_front()
			goal_idx -= 1

func _replay(dt: float) -> void:
	rp_pos += 16.5 * dt
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
		a[k + 5] = p.kick_n * 4 + p.kick_kind
		a[k + 6] = p.tackle_n
		a[k + 7] = p.dive_n
		a[k + 8] = p.dive_side
		a[k + 9] = 9 if p.off else p.mood
		a[k + 10] = p.fall_n * 2 + (1 if p.fall_dur > 0.9 else 0)
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
	if int(a[k + 5]) / 4 != p.kick_n:
		p.start_kick(0.7, int(a[k + 5]) % 4)
		p.kick_n = int(a[k + 5]) / 4
	if int(a[k + 6]) != p.tackle_n:
		p.tackle_n = int(a[k + 6])
		p.tackle_t = 0.0
	if int(a[k + 7]) != p.dive_n:
		p.dive_n = int(a[k + 7])
		p.dive_t = 0.0
		p.dive_side = a[k + 8]
	if int(a[k + 10]) / 2 != p.fall_n:
		p.fall_n = int(a[k + 10]) / 2
		p.fall_t = 0.0
		p.fall_dur = 1.2 if int(a[k + 10]) % 2 == 1 else 0.6
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
		ch.append(snappedf(h.meter, 0.01))
	net.send({
		"_": "s", "st": state, "t": snappedf(state_t, 0.01), "sc": score, "ck": int(clock), "p": _pack(),
		"h": hc, "c": ch, "e": out_ev, "sr": players.find(scorer), "rp": hud.replay_on,
		"ts": tst if state == "full" else null, "co": co_pay if (state == "full" and career_on) else null, "sm": snappedf(humans[1].stam, 0.02) if humans.size() > 1 else 1.0,
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
			humans[me].meter = float(ch[me])
		hud.show_controls = state == "play"
		if snap.get("ts") != null:
			tst = snap["ts"]
		if humans.size() > me:
			humans[me].stam = float(snap.get("sm", 1.0))
		if state == "full" and snap.get("co") != null and not co_got:
			# a career match played together pays the guest's own club too
			co_got = true
			var cp: Array = snap["co"]
			if not car.has_save():
				car.new_career(opt_club, CLUBS.size(), SURNAMES)
			car_lines = car.coop_reward(int(cp[0]), bool(cp[1]))
			car_lines.append_array(cp[2])
			if prev == "full":
				hud.show_menu("full", _menu_info())
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
	if wait_friend > 0.0:
		wait_friend -= dt
		if wait_friend <= 0.0 or screen != "match":
			wait_friend = 0.0
			if screen == "match" and net.role == "host" and not net.connected and humans.size() > 1:
				humans.remove_at(1)
				hud.toast("Your friend left - playing on against the computer")
	if net.web and screen == "menu":
		# is a newer version out? The page asks the server now and then; here we only read its answer
		upd_t -= dt
		if upd_t <= 0.0:
			upd_t = 5.0
			var lv := str(JavaScriptBridge.eval("(window.bbApp?bbApp.latest():'')", true))
			app_inst = str(JavaScriptBridge.eval("(window.bbApp?bbApp.installed():0)", true)) == "1"
			var was := upd_ready
			upd_ready = lv != "" and lv != "null" and lv != version and version != "dev"
			if upd_ready and not was:
				hud.toast("A new version is ready: tap UPDATE")
				if hud.menu_name == "main":
					hud.refresh(_menu_info())
	_auto_quality(dt)
	var rdt := dt / maxf(Engine.time_scale, 0.05)
	if not autotest:
		_frame(minf(dt, 0.1))
	if net.role == "guest" and screen == "match":
		_guest_frame(dt)
	if not paused:
		_spin_ball(ball_vel, dt * anim_rate)
	var loose: bool = ball_owner == null
	# seen from above everything is further away: the ball and the men are drawn bigger (the play itself is the same)
	var top: bool = cam_mode == 1
	var bs := 1.0
	if top:
		bs = 3.4 * (1.0 + clampf(ball.position.y - BALL_R, 0.0, 12.0) * 0.07)
	ball_mesh.scale = ball_mesh.scale.lerp(Vector3.ONE * bs, clampf(rdt * 10.0, 0.0, 1.0))
	ball_mesh.position.y = BALL_R * ((3.4 if top else 1.0) - 1.0) + (0.25 if top else 0.0)
	ball_top.visible = top
	if top:
		# a dark rim on the grass under the ball, so the white ball stands out everywhere
		ball_top.global_position = Vector3(ball.position.x, 0.12, ball.position.z)
	# from above the men are round discs in their shirt colour (the play is the same)
	for p in players:
		p.set_top(top)
	trail.scale_amount_min = 2.6 if top else 1.0
	trail.scale_amount_max = 2.6 if top else 1.0
	trail.emitting = loose and ball_vel.length() > (12.0 if top else 17.0) and screen == "match"
	hit_t += rdt
	hit_ring.visible = hit_t < 0.32 and screen == "match"
	if hit_ring.visible:
		var hk := hit_t / 0.32
		var hs := (0.8 + 4.2 * hk) * (0.6 + 0.6 * hit_k) * (1.5 if top else 1.0)
		hit_ring.scale = Vector3(hs, 0.04, hs)
		hit_ring.material_override.albedo_color = Color(1, 1, 1, 0.85 * (1.0 - hk))
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
	var mv := 0.0
	if humans.size() > me and humans[me].ctrl != null and state == "play" and screen == "match":
		mv = humans[me].meter
		if test_meter:
			mv = 0.65
	meter_bg.visible = mv > 0.02
	meter_fg.visible = mv > 0.02
	aim_arrow.visible = false
	if humans.size() > me and humans[me].ctrl != null and state == "play" and screen == "match":
		# the arrow on the grass always shows which way your man is heading (and where the ball will go)
		var mp0: Vector3 = humans[me].ctrl.position
		var st0 := _stick() * view_flip
		var ad0: Vector3 = Vector3(st0.x, 0, st0.y).normalized() if st0.length() > 0.3 else humans[me].ctrl.fwd()
		aim_arrow.visible = true
		aim_hold.position = mp0 + ad0 * 1.7 + Vector3(0, 0.06, 0)
		aim_hold.rotation.y = atan2(-ad0.x, -ad0.z)
	if mv > 0.02:
		var mp: Vector3 = humans[me].ctrl.position
		var mw := 2.1
		meter_bg.position = Vector3(mp.x, 0.05, mp.z + 1.35 * view_flip)
		meter_bg.scale = Vector3(mw + 0.12, 1.0, 0.42)
		meter_fg.position = Vector3(mp.x - (mw * 0.5 - mw * mv * 0.5) * view_flip, 0.07, mp.z + 1.35 * view_flip)
		meter_fg.scale = Vector3(mw * mv, 1.0, 0.3)
		meter_mat.albedo_color = Color(0.3, 0.95, 0.4).lerp(Color(1.0, 0.85, 0.2), clampf(mv * 2.0, 0.0, 1.0)).lerp(Color(1.0, 0.25, 0.15), clampf((mv - 0.6) / 0.4, 0.0, 1.0))
	var show_rings := state == "play" and screen == "match"
	for p in players:
		p.windup = 0.0
		p.hold_up = ball_owner == p and p.role != "GK" and ball.position.y > 1.9
	for h in humans:
		if h.ctrl != null and h.charging and ball_owner == h.ctrl:
			h.ctrl.windup = h.charge
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
			var mine2: bool = ball_owner != null and ball_owner == hm.ctrl
			# the buttons are for what YOUR man can do: with a partner on the ball you can only switch player
			hud.lab_a = "SHOOT" if mine2 else ("" if ours else "TACKLE")
			hud.lab_b = "PASS" if mine2 else "SWITCH"
			hud.charge = hm.charge
			hud.stam = hm.stam
			hud.ctrl_name = ("%d  %s  %d" % [hm.ctrl.num, hm.ctrl.pname.to_upper(), hm.ctrl.ovr]) if hm.ctrl != null else ""
			if state == "play" and hm.ctrl != null and ball_owner == hm.ctrl and set_piece != "pen":
				var st2 := _stick() * view_flip
				var tgt = _pass_target(hm.ctrl, Vector3(st2.x, 0, st2.y), false)
				if tgt != null:
					tgt.set_hint(Color(0.55, 0.95, 1.0))
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
	if cam_mode == 1 and screen == "menu":
		# behind the menus: a slow drift over the pitch, seen from above like the match
		var a := real_t * 0.08
		want_look = Vector3(sin(a) * 14.0, 0, cos(a * 0.7) * 5.0)
		want_pos = want_look + Vector3(0, 60.0, 6.0)
		want_fov = 38.5
		k = 2.0
	elif cam_mode == 1 and state in ["intro", "replay", "goal", "full"]:
		# the whole game is seen from above now: kick-off line-up, goals and replays too.
		# Replays and goals come a little closer, so you see who did what.
		var hw := 40.0
		var c2 := Vector3(f.x, 0, f.z)
		want_fov = 38.5
		k = 3.0
		if state == "replay":
			want_fov = 29.0
			hw = 30.0
			k = 5.0
		elif state == "goal":
			want_fov = 31.0
			hw = 32.0
			if scorer != null and state_t > 0.5:
				c2 = Vector3(scorer.position.x, 0, scorer.position.z)
		else:
			c2 = Vector3.ZERO
		var hh: float = hw * 0.47
		want_look = Vector3(clampf(c2.x, -HL - 4.0 + hw, HL + 4.0 - hw), 0, clampf(c2.z * view_flip, -HW - 3.0 + hh, HW + 6.0 - hh) * view_flip)
		want_pos = want_look + Vector3(0, 60.0, 6.0 * view_flip)
	elif screen == "menu":
		var a := real_t * 0.1
		want_pos = Vector3(sin(a) * 62.0, 15.0 + sin(a * 0.7) * 4.0, cos(a) * 50.0)
		want_look = Vector3(f.x * 0.35, 0, f.z * 0.35)
		want_fov = 44.0
		k = 2.0
	elif state == "intro" and real_t - intro_t0 < 3.5:
		var it := real_t - intro_t0
		want_look = Vector3(-14.0 + it * 4.0, 1.0, 0)
		want_pos = Vector3(-52.0 + it * 13.0, 4.5 + it * 1.6, (38.0 - it * 2.0) * view_flip)
		want_fov = 50.0
		k = 2.2
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
		# on the near side the camera comes with the ball, so the touchline under the buttons stays in view
		var nz: float = f.z * view_flip
		var foc := Vector3(fx2, 0, maxf(nz * 0.6, nz - 0.5) * view_flip)
		want_fov = 27.0
		if cam_mode == 1:
			# from above, like the old 2D game: a wide slice of the pitch, tilted just enough to read the players
			# the same slice as the 2D game showed: about 42 m of the pitch from top to bottom
			off = Vector3(0, 60.0, 6.0)
			foc = Vector3(clampf(f.x, -HL + 40.0, HL - 40.0), 0, clampf(f.z * view_flip, -15.0, 18.5) * view_flip)
			want_fov = 38.5
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
	var off2 := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * shake * (1.7 if cam_mode == 1 else 0.7)
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
	if net.web and shot_path == "":
		var hpx: float = DisplayServer.window_get_size().y
		var want := clampf(820.0 / maxf(hpx, 1.0), 0.5, 1.0)
		if absf(want - base_scale) > 0.03:
			base_scale = want
			q_applied = -1
	if quality != q_applied:
		q_applied = quality
		world.sun.shadow_enabled = quality >= 2
		get_viewport().msaa_3d = Viewport.MSAA_2X if quality >= 2 else Viewport.MSAA_DISABLED
		get_viewport().scaling_3d_scale = (1.0 if quality >= 1 else 0.7) * base_scale
		for p in players:
			p.blob.visible = quality < 2

# Test only: a scripted "thumb" that plays through the same inputs as a person, to exercise the human code paths.
func _bot_inputs(dt: float) -> void:
	if long_test:
		for hz in humans:
			hz.stick = Vector2.ZERO
			hz.sprint = false
		# long shot test: again and again a full power shot from 24-30 m aimed at a corner
		long_t -= dt
		if state == "play" and set_piece == "" and long_t <= 0.0 and humans.size() > 0:
			long_t = 4.0
			var lp = humans[0].ctrl
			if lp != null and lp.role != "GK":
				var ls := side(lp.team)
				lp.position = Vector3((HL - long_d - randf() * 5.0) * ls, 0, randf_range(-10.0, 10.0))
				lp.vel = Vector3.ZERO
				lp.stun = 0.0
				protect_t = 0.0
				_give(lp)
				ball.position = lp.position + Vector3(0.5 * ls, BALL_R, 0)
				protect_t = 2.8
				long_arm = 2.4
		if long_arm > 0.0:
			long_arm -= dt
			var lq = humans[0].ctrl
			if long_arm <= 0.0 and ball_owner == lq and state == "play":
				var before: int = stats["shots"]
				_shoot(lq, long_pw, (-1.0 if teams[1 - lq.team][0].position.z > 0.0 else 1.0) * GOAL_HW * long_aim, 0.8, lerpf(0.75, 0.2, clampf((long_pw - 0.55) / 0.4, 0.0, 1.0)))
				if stats["shots"] > before:
					long_n += 1
		if state == "full" and long_n > 0:
			print("AUTOTEST long shots=", long_n, " goals=", score[humans[0].team])
			long_n = 0
		return
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
				var no: Vector3 = Vector3.ZERO
				for o in teams[1 - h.team]:
					if o.position.distance_to(p.position) <= nd + 0.01:
						no = o.position
				if bot_mode == "dribble" and nd < 4.0 and set_piece == "":
					# a dribbler: steps away from the nearest man instead of passing
					var aw: Vector3 = (p.position - no).normalized()
					var lat := Vector2(-h.stick.y, h.stick.x)
					h.stick = (h.stick + lat * signf(lat.dot(Vector2(aw.x, aw.z))) * 0.9).normalized()
				if (nd < 3.5 and bot_mode != "dribble") or set_piece != "":
					if bot_thru and set_piece == "":
						h.evs.append("thru_down")
						if bstats["passes"] % 3 == 0:
							h.evs.append("hi")
						h.evs.append("thru_up")
					else:
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
			if bot_slide:
				if t <= 0.0 and ball_owner != null and to.length() < 4.2 and to.length() > 2.0 and p.stun <= 0.0:
					_slide_tackle(h)
					bstats["tackles"] += 1
					t = 1.6
			elif bot_hold:
				# test of holding TACKLE: thumb off the stick, button kept down
				h.stick = Vector2.ZERO
				if ball_owner != null and h.def_hold < 0.0:
					h.evs.append("shoot_down")
			elif t <= 0.0:
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
