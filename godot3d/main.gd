extends Node3D
# Banebold 3D prototype: one 11v11 match, built entirely in code.
# x runs along the pitch (red attacks +x), z across it, y is up. Units are metres.

const PlayerS := preload("res://player.gd")
const HudS := preload("res://hud.gd")
const AudioDir := preload("res://audio.gd")
const World := preload("res://world.gd")
const NetS := preload("res://net.gd")
const Career := preload("res://career.gd")
const ClubDB := preload("res://clubdb.gd")
const RankS := preload("res://rank.gd")
const FB := "https://banebold-default-rtdb.europe-west1.firebasedatabase.app/"

const DIVE_V := 4.6
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
	{"need": 0.70, "spd": 0.86, "err": 1.8, "think": 0.70, "wait": 3.2},
	{"need": 0.50, "spd": 0.92, "err": 1.2, "think": 0.45, "wait": 2.2},
	{"need": 0.38, "spd": 0.98, "err": 0.85, "think": 0.28, "wait": 1.4},
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
var sq1_over := [] # online guest: the other club's names and numbers, as the host has them
var form_over := ""
var lay_over := {}
var co_got := false
var test_ft := 0.0
var wd_clock := -1.0
var wd_n := 0
var wd_all := 0
var test_t := 0.0
var co_text := ""
var co_pay := []
var prbadge := false # test: show the live rating badge in any match
var guest_prt := -1.0 # the friend's live rating, from the host
var pro_bar := {} # the player career's XP bar at full time (before and after the match)
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
var CLUBS: Array = ClubDB.clubs(CLUBS0) # the league as it is now: your own club sits in its place with your name and kit
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
var start_li := 3 # the league picked on the new-career screen
var cup_ctry := "ENGLAND" # the cup mode's country
var opt_slen := "full" # a new career's season: "full" (home and away) or "short" (each club once)
var scout_li := -1 # the league shown on the other clubs' screen
var scout_c := -1 # the club whose squad you are looking at
var scout_i := -1 # the man you are looking at
var scout_res := {} # the answer to your last bid
var car
var car_main # your own club outside the career; car points to the career or the cup mode while you are in them
var carc # the career mode: its own save, its own club and its own money in euros
var in_career := false # inside the career mode until you leave it yourself
# Playing together: the friend's phone gets the host's whole career and can look around in it as the assistant manager.
var carv # the host's career as the friend sees it (never saved)
var assist := false # the friend is looking around in it now
var as_prev = null # where car pointed before
var cv_last := 0 # the host: the last career sent (its hash)
var cv_t := 0.0
var sugs := [] # the host: the assistant's suggestions still waiting
var ct_from := "" # where a contract talk started: back there when it ends
var co_rdy := [false, false] # career together: the manager and the friend have tapped PLAY
var sug_cur := {}
var sug_prev := ""
var proc # the player career: you are one player at a club
var pro_sq := -1 # your man's place in the squad while you play a match as him
var pro_sq2 := -1 # your friend's man, when you play the player career together
var pro_new := {"pos": "FW", "c": -1, "pick": []}
var cupc # the cup mode: a cup of its own, with your club or any club
var cup_mode := false
var start_kind := "" # how a new career (or cup) starts: "mine", "new", "club", "cup"
var new_sure := false
var rk # ranked online: your rank, points and season
var rk_looking := false # searching for an opponent
var rk_on := false # this match is ranked
var rk_me := {} # your team as the other phone sees it
var rk_opp := {} # the other side's team
var rk_res := {} # the last ranked result
var rk_t := 0.0
var rk_msg := ""
var rk_walk := false
var tov := [{}, {}] # ranked: each side's own team (name, kit, formation, eleven)
var RKI := 0 # the two places in CLUBS that the ranked teams use
var ft_on := false # a match in a friend's room where a side plays with its own club and squad
var opt_own := true # in a friend's room you play with your own club (not one of the eight)
var guest_tm := {} # the host's copy of the friend's own team ({} = the friend picked one of the eight)
var lb := [] # the leaderboard
var lb_state := ""
var fr_t := 3.0 # online friends: next card update / poll (see bbFr in web/net.js)
var fr_poll := 1.0
var fr := {} # the friends list as the page last told it
var fr_inv := {} # a match invite waiting for an answer
var career_on := false
var cup_on := false
var eu_on := false # a Champions Cup match in the career
var nat_on := false # your national team's match (the career is set aside while it is played)
var opt_cup := false
var golden := false
var pen_shot := false
var shot_hard := 0.0 # a Cannon shot: the keeper's reach is shorter against it
# extra time and a penalty shootout when a cup tie or a match against each other ends level
var half_kick := 1
var et_kick := 0
var so_on := false
var so_done := false
var so_g := [0, 0]
var so_n := [0, 0]
var so_turn := 0
var so_shot := false
var so_t := 0.0
var so_win := -1
var so_last := false
var car_goals := []
var y_tab := 0 # youth page: 0 scouts, 1 reports, 2 academy
var mail_sel := -1 # the inbox: the open mail's id
var cab_tab := 0 # trophy cabinet: 0 trophies, 1 awards, 2 records
var scout_sw := 0 # the man of yours offered in a swap
var nat_tab := 0 # national team page: 0 squad, 1 group, 2 the job
var cal_m := 0 # the calendar shows this many months after the month of your next match
var sim_res := {} # the last simulated match, for its screen
var adv_info := {} # the days between two matches: dates and news
var adv_from := -99 # the day of the match just played: CONTINUE shows the days going by from here
var q_opt := [1, 1] # the quick-match level and length, kept while the career uses its own
var car_lines := []
var car_sel := -1
var car_msg := ""
var ab_slot := 0 # which skill place the picker is choosing for
var car_sure := false
var car_sell := -1
var subs_left := 3
var sub_sel := -1
var sub_off := []
var sub_played := []
var sub_bench := [[], []] # each side's bench for this match: player dicts (career men carry "sq", their squad index)
var sub_left2 := [3, 3]
var sub_used := [[], []] # bench places already brought on
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
	var auto_on := false # the player career: one tap and your man finds his own position, until you take the stick or get the ball
	var pick_t := 0.0 # you picked this man yourself with SWITCH: the game leaves him under your thumb for a while
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
	var psq := -1 # the player career: this thumb's own man (his place in the squad)
	var pnode = null
	var ptrk := {}

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
# backspin (+) / topspin (-): how fast the Magnus force turns the flight up (or down), rad/s
var ball_bs := 0.0
# how the ball is spinning, only for drawing it (rad/s about each axis)
var ball_wv := Vector3.ZERO
var pass_from = null

var score := [0, 0]
var clock := 0.0
var half := 1
var screen := "menu"
var state := "play"
var state_t := 0.0
var kick_team := 0
var dead_info := {}
# The referee: runs with play, and books a man at the next stop (after advantage too), card held up for all to see.
var ref = null
var ref_card := [] # [player, "y"] waiting for the next stop in play
var book_p = null
var book_t := -1.0
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
var audio # audio.gd: every sound of the match and the menus
var derby_on := false # a derby in the career: the crowd is louder
var tac_m := [[0.0, 0.0, 0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]] # autotest: how far up and how wide each team stood
var tac_t := [[2, 1, 1], [2, 1, 1]] # each team's plan: mentality 0-4, press 0-2, width 0-2 (career sets them)
var tac_base := [[2, 1, 1], [2, 1, 1]] # the plan the team started with (the computer manager changes tac_t from it)
var tac_mood := ["", ""] # what the computer manager is doing right now ("push", "allout", "sit", "bus", "ten", "")
var mgr_t := 0.0
var cpu_sub_at := [0.0, 0.0] # match clock of the computer's last change
var sub_hint := {} # players we already told you are tired (instance id)
var paused_by := ""
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
var test_drag := []
var shot_at := 0.0
var strip_n := -1
var strip_t := 0.0
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
		if a == "--prbadge":
			prbadge = true
		if a == "--autotest":
			autotest = true
		elif a == "--demo":
			demo = true
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--at="):
			shot_at = float(a.substr(5))
		elif a.begins_with("--drag="):
			# test: a finger drag on the screen, x0,y0,x1,y1[,hold] (starts 1 s in, 0.5 s long)
			test_drag = Array(a.substr(7).split_floats(","))
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
	car_main = car
	carc = Career.new()
	carc.key = "bb3d-cmode"
	carc.eur = true
	carc.names = SURNAMES
	carc.load_save(net.web)
	carv = Career.new()
	carv.key = "bb3d-assist"
	carv.eur = true
	carv.ro = true
	carv.names = SURNAMES
	_split_career()
	# the game always opens on the normal home screen (Daniel); the career waits, saved, until you go into it
	in_career = false
	car = car_main
	proc = Career.new()
	proc.key = "bb3d-pro"
	proc.eur = true
	proc.names = SURNAMES
	proc.load_save(net.web)
	cupc = Career.new()
	cupc.key = "bb3d-cupmode"
	cupc.names = SURNAMES
	cupc.load_save(net.web)
	rk = RankS.new()
	rk.load_save(net.web)
	_apply_own()
	if new_car:
		car_main.wipe()
		car_main.stash_clear()
		carc.wipe()
		cupc.wipe()
		car = car_main
		in_career = false
	if net.web:
		dbg = str(JavaScriptBridge.eval("location.search", true)).contains("dbg")
		var qs := str(JavaScriptBridge.eval("location.search", true))
		if qs.contains("sndtest"):
			# test: the page starts a match at once (sound checks in a browser)
			demo = true
			bot_mode = "solo"
		if qs.contains("ft="):
			test_ft = float(qs.split("ft=")[1].split("&")[0])
		if str(JavaScriptBridge.eval("location.search", true)).contains("low"):
			quality = 0
		seen_how = str(JavaScriptBridge.eval("(function(){try{return localStorage.getItem('bb3d-how')||''}catch(e){return ''}})()", true)) == "1"
		var ss := str(JavaScriptBridge.eval("(function(){try{return localStorage.getItem('bb3d-snd')||''}catch(e){return ''}})()", true))
		if ss.length() == 2 and ss.is_valid_int():
			opt_snd = clampi(int(ss.substr(0, 1)), 0, 2)
			opt_voice = ss.substr(1, 1) == "1"
		opt_own = str(JavaScriptBridge.eval("(function(){try{return localStorage.getItem('bb3d-ftown')||''}catch(e){return ''}})()", true)) != "0"
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
	var rs: Array = rk.season()
	if int(rs[1]) > 0 and car.has_save():
		car.d["coins"] = int(car.d["coins"]) + int(rs[1])
		car.save()
		hud.toast(str(rs[0]))
	if autotest or demo:
		screen = "match"
		if car_test:
			if not car.has_save():
				car.new_career(-1)
			career_on = true
			_set_clubs(int(car.d["club"]), car.next_match()[0], true)
			if OS.get_cmdline_user_args().has("--cup"):
				cup_on = true
				_set_clubs(int(car.d["club"]), car.cup_opp(), true)
		_begin_match(demo and OS.get_cmdline_user_args().has("--intro"))
		if menu_arg in ["subs", "pause", "mtac"]:
			tac_mood[1] = "push"
			for p in players:
				p.fit = randf_range(0.4, 1.0)
			_substitute(9, 0)
			sub_sel = 7
			print("SUBTEST ", teams[0][9].pname, " num=", teams[0][9].num, " left=", subs_left, " played=", sub_played)
			hud.show_menu(menu_arg, _menu_info())
		if OS.get_cmdline_user_args().has("--picktest"):
			# who does a human pass go to? tap = nearest in the stick direction, hold = further
			_kickoff(0)
			var pp = teams[0][6]
			pp.position = Vector3(-10, 0, 0)
			var spots := [Vector3(-2, 0, 2), Vector3(14, 0, -3), Vector3(2, 0, 11), Vector3(-10, 0, -14), Vector3(-26, 0, 0)]
			var who := []
			for i in spots.size():
				var q = teams[0][[9, 10, 8, 2, 3][i]]
				q.position = spots[i]
				q.vel = Vector3.ZERO
				who.append(q)
			for q in teams[0]:
				if not (q in who) and q != pp:
					q.position = Vector3(-HL + 1, 0, HW - 1)
			for q in teams[1]:
				q.position = Vector3(40, 0, 30)
			for c in [[Vector2(1, 0), -1.0], [Vector2(1, 0), 0.3], [Vector2(1, 0), 0.5], [Vector2(1, 0), 0.75], [Vector2(1, 0), 1.0], [Vector2(1, 0.45), -1.0], [Vector2(0, 0), -1.0], [Vector2(1, 0.8), -1.0], [Vector2(0.3, 1), -1.0], [Vector2(0, -1), -1.0], [Vector2(-1, 0), -1.0], [Vector2(1, -0.25), -1.0]]:
				var st: Vector2 = c[0].normalized()
				var mm = _pass_target(pp, Vector3(st.x, 0, st.y), false, c[1])
				print("PICKTEST stick=", st, " pw=", c[1], " -> ", (who.find(mm) if mm != null else -1), " at ", (mm.position if mm != null else Vector3.ZERO))
			get_tree().quit()
			return
		if OS.get_cmdline_user_args().has("--gktest"):
			# the same shots at both keepers (same stats), with a human on team 0: do both save the same?
			humans = [Human.new()]
			for gstat in [55, 75, 90]:
				var res := [[0, 0, 0], [0, 0, 0]]
				for t in 2:
					for si in 150:
						_kickoff(0)
						clock = 600.0
						half = 1
						var g = teams[t][0]
						var gv := ""
						for a9 in OS.get_cmdline_user_args():
							if a9.begins_with("--gkvar="):
								gv = a9.substr(8)
						g.pac = gstat if gv in ["", "pac"] else 75
						g.sho = gstat if gv in ["", "sho"] else 75
						g.dfn = gstat if gv in ["", "dfn"] else 75
						_derive(g)
						g.pas = 60
						g.ab = []
						var a = teams[1 - t][9]
						for q in players:
							if q != g and q != a:
								q.position = Vector3(0, 0, HW + 1.0)
								q.stun = 99.0
						humans[0].ctrl = teams[0][5]
						var rr := RandomNumberGenerator.new()
						rr.seed = si * 31 + 5
						var sa := side(1 - t)
						var dd := rr.randf_range(10.0, 22.0)
						var zz := rr.randf_range(-9.0, 9.0)
						a.position = Vector3(sa * (HL - dd), 0, zz)
						a.yaw = atan2(-float(sa), 0.0)
						g.position = Vector3(-side(t) * (HL - 1.0), 0, clampf(zz * 0.25, -2.0, 2.0))
						g.vel = Vector3.ZERO
						g.dive_t = -1.0
						g.react_t = 0.0
						ball_owner = a
						ball_last = a
						ball.position = a.position + Vector3(sa * 0.6, BALL_R, 0)
						set_piece = ""
						protect_t = 0.0
						state = "play"
						var aimz := rr.randf_range(-1.0, 1.0) * GOAL_HW * 0.8
						seed(si * 7 + 3)
						_shoot(a, rr.randf_range(0.4, 0.9), aimz, 0.8)
						var tt := 0.0
						var out := 2
						while tt < 3.0:
							_tick(1.0 / 60.0)
							tt += 1.0 / 60.0
							if ball_owner == g or ball_last == g:
								out = 1
								break
							if state != "play":
								out = 0 if score[1 - t] > 0 or state == "goal" else 2
								break
						score = [0, 0]
						res[t][out] += 1
				print("GKTEST stats=", gstat, " team0 keeper goals/saves/miss=", res[0], "  team1 keeper=", res[1])
			get_tree().quit()
			return
		if OS.get_cmdline_user_args().has("--autopos"):
			# the player career: CALL held = your man positions himself
			humans = [Human.new()]
			var hh = humans[0]
			_kickoff(1)
			clock = 600.0
			var me9 = teams[0][9]
			hh.ctrl = me9
			hh.psq = 0
			hh.pnode = me9
			me9.position = Vector3(-40, 0, 20)
			for held in [false, true]:
				hh.auto_on = held
				var p0: Vector3 = me9.position
				var tt := 0.0
				while tt < 4.0:
					_tick(1.0 / 60.0)
					tt += 1.0 / 60.0
					if held:
						hh.auto_on = true
					hh.ctrl = me9
				print("AUTOPOS held=", held, " moved=", snappedf(me9.position.distance_to(p0), 0.1), " at=", me9.position, " ball=", ball.position, " state=", state)
			get_tree().quit()
			return
		if OS.get_cmdline_user_args().has("--cornertest"):
			# a human corner aimed with the stick: where does the cross come down, and who gets to it?
			humans = [Human.new()]
			humans[0].team = 0
			for st in [Vector2.ZERO, Vector2(0, 1), Vector2(0, -1), Vector2(-1, 0), Vector2(0.7, 0.7)]:
				for rep in 3:
					_kickoff(0)
					clock = 600.0
					_out("corner", Vector3(HL - 0.6, 0, HW - 0.6), 0)
					var w := 0.0
					while not (state == "play" and set_piece == "corner" and ball_owner != null) and w < 8.0:
						_tick(1.0 / 60.0)
						w += 1.0 / 60.0
					var tk = ball_owner
					humans[0].ctrl = tk
					humans[0].stick = st
					var aim := _corner_aim(tk, st)
					humans[0].evs.append("lob_down")
					_tick(1.0 / 60.0)
					humans[0].evs.append("lob_up")
					_tick(1.0 / 60.0)
					var t5 := 0.0
					var drop := Vector3.ZERO
					var was := ball.position.y
					while t5 < 3.0 and ball_owner == null and state == "play":
						_tick(1.0 / 60.0)
						t5 += 1.0 / 60.0
						if ball_last == tk and (drop == Vector3.ZERO or Vector2(ball.position.x - aim.x, ball.position.z - aim.z).length() < Vector2(drop.x - aim.x, drop.z - aim.z).length()):
							drop = ball.position
						was = ball.position.y
					var who := "loose"
					if ball_owner != null:
						who = "ours" if ball_owner.team == 0 else "theirs"
					elif ball_last != null and ball_last != tk:
						who = ("ours" if ball_last.team == 0 else "theirs") + "-touch"
					print("CORNERTEST stick=", st, " aim=", Vector2(snappedf(aim.x, 0.1), snappedf(aim.z, 0.1)), " nearest=", Vector3(snappedf(drop.x, 0.1), snappedf(drop.y, 0.1), snappedf(drop.z, 0.1)), " taker_human=", _hum_of(tk) != null, " -> ", who, " state=", state)
			get_tree().quit()
			return
		if OS.get_cmdline_user_args().has("--thrudef"):
			# a through ball over or through a real back line: who gets it, high and on the ground?
			humans = [Human.new()]
			for hi in [false, true]:
				var won := {"9": 0, "def": 0, "gk": 0, "none": 0, "other": 0}
				for k in 40:
					_kickoff(0)
					clock = 600.0
					var rr := RandomNumberGenerator.new()
					rr.seed = k * 17 + 1
					var lx := rr.randf_range(12.0, 30.0)
					var dz := [-13.0, -4.5, 4.5, 13.0]
					for q in teams[1]:
						q.position = Vector3(55, 0, q.position.z)
						q.stun = 99.0
					for di in 4:
						var dq = teams[1][1 + di]
						dq.position = Vector3(lx + rr.randf_range(-1.0, 1.0), 0, dz[di] + rr.randf_range(-1.5, 1.5))
						dq.stun = 0.0
						dq.vel = Vector3.ZERO
					var g1 = teams[1][0]
					g1.position = Vector3(HL - 1.0, 0, 0)
					g1.stun = 0.0
					for q in teams[0]:
						q.position = Vector3(-40, 0, q.position.z)
					var tp = teams[0][6]
					var tm = teams[0][9]
					tp.position = Vector3(lx - rr.randf_range(16.0, 26.0), 0, rr.randf_range(-6.0, 6.0))
					tm.position = Vector3(lx - 1.5, 0, rr.randf_range(-8.0, 8.0))
					tm.vel = Vector3(tm.top_speed * 0.8, 0, 0)
					tp.yaw = atan2(-1.0, 0.0)
					ball_owner = tp
					ball_last = tp
					ball.position = tp.position + Vector3(0.6, BALL_R, 0)
					set_piece = ""
					protect_t = 0.0
					state = "play"
					var th = humans[0]
					th.ctrl = tp
					var to: Vector3 = tm.position + Vector3(8, 0, 0) - tp.position
					th.stick = Vector2(to.x, to.z).normalized()
					th.evs.append("thru_down")
					if hi:
						th.evs.append("hi")
					var tt := 0.0
					var hold := rr.randf_range(0.1, 0.6)
					while tt < hold:
						_tick(1.0 / 60.0)
						tt += 1.0 / 60.0
					th.evs.append("thru_up")
					_tick(1.0 / 60.0)
					th.stick = Vector2(1, 0)
					var t4 := 0.0
					while t4 < 5.0 and state == "play" and ball_owner == null:
						_tick(1.0 / 60.0)
						t4 += 1.0 / 60.0
					var key := "none"
					if ball_owner == tm:
						key = "9"
					elif ball_owner != null and ball_owner.team == 1:
						key = "gk" if ball_owner.role == "GK" else "def"
						print("THRUDEF_LOST hi=", hi, " by=", ball_owner.idx, " at=", ball.position, " t=", snappedf(t4, 0.01), " from=", tp.position, " lx=", snappedf(lx, 0.1), " head=", ball_owner.head_t)
					elif ball_owner != null:
						key = "other"
					won[key] += 1
				print("THRUDEF hi=", hi, " ", won)
			get_tree().quit()
			return
		if OS.get_cmdline_user_args().has("--thrutest"):
			# through balls played by a human to a runner going forward: does the runner get there first?
			humans = [Human.new()]
			for hi in [false, true]:
				for dd in [8.0, 14.0, 22.0]:
					for hold in [0.0, 0.3, 0.6]:
						_kickoff(0)
						for q in teams[1]:
							if q.role != "GK":
								q.position = Vector3(60, 0, q.position.z)
								q.stun = 99.0
						var tp = teams[0][6]
						var tm = teams[0][9]
						tp.position = Vector3(-5, 0, 0)
						tm.position = Vector3(-5 + dd, 0, 6)
						tm.vel = Vector3(tm.top_speed * 0.9, 0, 0)
						tp.yaw = atan2(-1.0, 0.0)
						ball_owner = tp
						ball_last = tp
						ball.position = tp.position + Vector3(0.6, BALL_R, 0)
						set_piece = ""
						protect_t = 0.0
						state = "play"
						var th = humans[0]
						th.ctrl = tp
						th.stick = Vector2(1, 0.25).normalized()
						th.evs.append("thru_down")
						if hi:
							th.evs.append("hi")
						var tt := 0.0
						while tt < hold:
							_tick(1.0 / 60.0)
							tt += 1.0 / 60.0
						th.evs.append("thru_up")
						_tick(1.0 / 60.0)
						var v00 := Vector2(ball_vel.x, ball_vel.z).length()
						var start: Vector3 = tm.position
						var t4 := 0.0
						var gap := 0.0
						th.stick = Vector2(1, 0)
						while t4 < 6.0 and state == "play" and ball_owner == null:
							_tick(1.0 / 60.0)
							t4 += 1.0 / 60.0
							gap = maxf(gap, (ball.position.x - tm.position.x))
						print("THRUTEST hi=", hi, " d=", dd, " hold=", hold, " got=", players.find(ball_owner), " (want 9) t=", snappedf(t4, 0.01), " state=", state, " ran=", snappedf(tm.position.distance_to(start), 0.1),  " max_ball_ahead=", snappedf(gap, 0.1), " ball_x=", snappedf(ball.position.x, 0.1), " v0=", snappedf(v00, 0.1))
			get_tree().quit()
			return
		if OS.get_cmdline_user_args().has("--balltest"):
			# shots: where they cross the goal line against where they were aimed, time and pace on arrival
			for pw in [0.2, 0.5, 0.8, 1.0]:
				for cu in [0.0, 0.6]:
					var pp = teams[0][9]
					pp.position = Vector3(HL - 20.0, 0, 3.0)
					ball.position = pp.position + Vector3(0.6, BALL_R, 0)
					ball_owner = pp
					set_piece = ""
					seed(7)
					_shoot(pp, pw, 1.8, 0.0, cu)
					var v0 := ball_vel.length()
					var tt := 0.0
					var apex := 0.0
					while ball.position.x < HL and tt < 4.0:
						_ball_free(1.0 / 60.0)
						tt += 1.0 / 60.0
						apex = maxf(apex, ball.position.y)
						print("TRAJ shot", pw, "_", cu, " ", snappedf(ball.position.x - HL + 20.0, 0.01), " ", snappedf(ball.position.y, 0.01), " ", snappedf(ball.position.z, 0.01))
					print("BALLTEST pw=", pw, " curl=", cu, " v0=", snappedf(v0 * 3.6, 1), "kmh at_goal=", snappedf(ball_vel.length() * 3.6, 1), "kmh t=", snappedf(tt, 0.01), " z=", snappedf(ball.position.z, 0.01), " y=", snappedf(ball.position.y, 0.01), " apex=", snappedf(apex, 0.01), " bs=", snappedf(ball_bs, 0.01))
			for dd in [15.0, 30.0, 45.0]:
				var pp = teams[0][9]
				var mm = teams[0][6]
				pp.position = Vector3(-30, 0, 0)
				mm.position = Vector3(-30 + dd, 0, 0)
				mm.vel = Vector3.ZERO
				ball_owner = pp
				set_piece = ""
				_pass(pp, mm, true)
				var tt := 0.0
				var bounces := []
				var prev := ball_vel.y
				while tt < 6.0 and Vector2(ball_vel.x, ball_vel.z).length() > 0.3:
					_ball_free(1.0 / 60.0)
					tt += 1.0 / 60.0
					if int(tt * 60.0) % 3 == 0:
						print("TRAJ lob", dd, " ", snappedf(ball.position.x + 30.0, 0.01), " ", snappedf(ball.position.y, 0.01))
					if prev < 0.0 and ball_vel.y > 0.0:
						bounces.append(snappedf(ball.position.x + 30.0, 0.1))
					prev = ball_vel.y
				print("LOBROLL d=", dd, " bounces_at=", bounces, " stops_at=", snappedf(ball.position.x + 30.0, 0.1), " t=", snappedf(tt, 0.1))
			get_tree().quit()
			return
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
			if menu_arg in ["pause", "mtac"]:
				hud.show_menu(menu_arg, _menu_info())
	else:
		_to_menu()
		if menu_arg != "":
			if menu_arg == "full":
				tst[0]["g"] = ["STORM 12'", "BAK 40'"]
				tst[1]["g"] = ["PIKE 77'"]
			if menu_arg.begins_with("hub_"):
				hub_tab = menu_arg.substr(4)
				menu_arg = "main"
				var ht := hub_tab
				if ht in ["career", "play_on", "transfers", "office", "teamc", "clubc"]:
					carc.new_career(carc.weakest(1), false)
					carc.set_mode("simple")
					if ht != "play_on":
						_cr_enter(false)
						hub_tab = {"teamc": "team", "clubc": "club"}.get(ht, ht)
				if ht == "play_on":
					hub_tab = "play"
			if menu_arg in ["ytest0", "ytest1", "ytest2"]:
				carc.new_career(carc.weakest(3), true)
				carc.set_mode("full")
				_cr_enter(false)
				car.scout_hire(1)
				car.scout_send(0)
				for r9 in 5:
					if car.cup_due():
						car.cup_finish(2, 1, true)
					var ln9: Array = car.finish_match(1, 0, [])
					for l9 in ln9:
						if str(l9).begins_with("SCOUT") or str(l9).begins_with("ACAD"):
							print("YLINE ", l9)
				car.youth_sign(0)
				y_tab = int(menu_arg.substr(5))
				menu_arg = "youth"
			if menu_arg in ["wtest0", "wtest1", "wtest2", "wtest3", "wtest4"]:
				carc.new_career(carc.weakest(3), true)
				carc.set_mode("full")
				_cr_enter(false)
				var wl := []
				for r9 in 3:
					if car.cup_due():
						car.cup_finish(2, 1, true)
					wl = car.finish_match(1, 0, [])
				for l9 in wl:
					print("WLINE ", l9)
				var rng9 := RandomNumberGenerator.new()
				rng9.randomize()
				car._cpu_bid(rng9, wl)
				print("WIN ", car.window(), " deals=", car.deals().size(), " inbox=", car.inbox().size(), " unread=", car.unread())
				for m9 in car.inbox():
					print("MAIL ", m9["k"], " | ", m9["t"], " | ", m9["b"])
				var wt := menu_arg
				if wt == "wtest0":
					mail_sel = int(car.inbox()[0]["id"])
					car.mail_read(mail_sel)
					menu_arg = "inbox"
				elif wt == "wtest1":
					var bids := []
					for m9 in car.inbox():
						if str(m9["k"]) == "bid" and str(m9["st"]) == "open":
							bids.append(int(m9["id"]))
					var n0: int = (car.d["squad"] as Array).size()
					var c0: int = int(car.d["coins"])
					if bids.size() >= 1:
						print("BIDANS more ", car.bid_answer(bids[0], "more"))
						print("BIDANS acc ", car.bid_answer(bids[0], "acc"))
					if bids.size() >= 2:
						print("BIDANS rej ", car.bid_answer(bids[1], "rej"))
					print("BIDANS squad ", n0, " -> ", (car.d["squad"] as Array).size(), " coins ", c0, " -> ", car.d["coins"], " xi ", car.d["xi"])
					menu_arg = "tnews"
				elif wt == "wtest4":
					# deadline day: play on until the last stop before 1 September, then answer a bid
					for r8 in 20:
						if bool(car.window().get("deadline", false)) or not bool(car.window().get("open", false)):
							break
						if car.cup_due():
							car.cup_finish(2, 1, true)
						car.finish_match(1, 0, [])
					print("DL ", car.window(), " today ", car.date_text(car.today()))
					adv_from = car.today()
					_adv_show(adv_from)
					menu_arg = "adv"
				else:
					hub_tab = "career" if wt == "wtest2" else "transfers"
					menu_arg = "main"
			if menu_arg in ["copro0", "copro1", "copro2", "copro3"]:
				var pk8: Array = _pro_picks()
				proc.new_pro(int(pk8[0]), "LARSEN", "FW")
				_pro_enter(false)
				if menu_arg != "copro0":
					proc.add_pro2("SCHALDE", "MF")
					print("COPRO pro2 i=", proc.pro_i("pro2"), " xi=", proc.d["xi"], " both start=", proc.pro_starts(), proc.pro_starts("pro2"))
				if menu_arg == "copro3":
					for r8 in 4:
						_sim_mine()
						print("COPRO sim lines=", sim_res.get("lines", []).slice(0, 2), " lines2=", sim_res.get("lines2", []).slice(0, 2))
				if menu_arg == "copro2":
					# the match together, on the manager's phone
					seen_how = true
					set_meta("pro_fast", true)
					opt_mode = "coop"
					opt_car = true
					opt_cup = false
					net.role = "host"
					_host_start()
					print("COPRO match pro_sq=", pro_sq, " pro_sq2=", pro_sq2, " humans=", humans.size(), " screen=", screen, " sqs=", teams[0].map(func(q): return q.sq), " h1team=", humans[1].team)
					menu_arg = ""
				else:
					# the friend's phone
					carv.d = proc.d.duplicate(true)
					net.role = "guest"
					net.connected = true
					_action("as_open")
					hub_tab = "pro"
					if menu_arg == "copro0":
						pro_new = {"pos": "MF", "n": "SCHALDE", "pick": []}
					print("COPRO guest pro info keys=", _pro_info().keys().slice(0, 5), " n=", _pro_info().get("n", ""))
					menu_arg = "main"
			if menu_arg == "xpbar":
				# full time in the player career: the XP bar fills and a new level gets its party
				pro_bar = {"lv0": 3, "x0": 150, "n0": 200, "lv1": 4, "x1": 40, "n1": 240, "rt": 7.4}
				car_lines = ["YOUR RATING 7.4  ·  1 GOAL", "+90 XP", "LEVEL 4!  +2 SKILL POINTS TO SPEND", "MANAGER'S TRUST 62"]
				career_on = true
				menu_arg = "full"
				get_tree().create_timer(0.6).timeout.connect(func(): hud.show_menu("full", _menu_info()))
			if menu_arg == "gkcard":
				# a keeper's card shows keeper skills; an old save's keeper gets them with about the same rating
				carc.new_career(carc.weakest(3), true)
				carc.set_mode("full")
				_cr_enter(false)
				var old := {"pos": "GK", "pac": 52, "sho": 30, "pas": 62, "dfn": 74}
				var o0 := Career.ovr_of({"pos": "GK", "pac": 0, "sho": 0, "pas": 62, "dfn": 74})
				Career.gk_fix({"sq": [old]})
				print("GKFIX old_rating~", int(round(74 * 0.8 + 62 * 0.2)), " now=", Career.ovr_of(old), " ", old, " (zero-check ", o0, ")")
				_action("c_squad")
				for gi in (car.d["squad"] as Array).size():
					if str(car.d["squad"][gi]["pos"]) == "GK":
						set_meta("tsel", gi)
						print("GKCARD idx=", gi, " ", car.d["squad"][gi])
						break
				menu_arg = "squad9"
			if menu_arg.begins_with("rv-"):
				# review: the same career page alone (s), as the manager with the friend in the room (h), and on the friend's phone (g)
				var rp: PackedStringArray = menu_arg.split("-")
				set_meta("rv", true)
				var rwho := rp[1]
				var rtg := rp[3]
				seen_how = true
				if rp[2] == "p":
					var pkr: Array = _pro_picks()
					proc.new_pro(int(pkr[0]), "LARSEN", "FW")
					_pro_enter(false)
					if rwho != "s":
						proc.add_pro2("SCHALDE", "MF")
				else:
					carc.new_career(carc.weakest(3), true)
					carc.set_mode("full")
					_cr_enter(false)
				for rr in 3:
					_sim_mine()
				var rsrc = proc if rp[2] == "p" else carc
				if OS.get_environment("RVOOP") != "" and rp[2] == "m":
					# a forward in defence and a defender up front: out of position on purpose
					var xo: Array = carc.d["xi"]
					var t0 = xo[2]
					xo[2] = xo[9]
					xo[9] = t0
				if OS.get_environment("RVNAT") != "" and rp[2] == "m":
					carc.nat_take(int(OS.get_environment("RVNAT")))
				if rwho == "h":
					net.role = "host"
					net.connected = true
					room = "KQWX"
					opt_car = true
				elif rwho == "g":
					carv.d = rsrc.d.duplicate(true)
					net.role = "guest"
					net.connected = true
					_action("as_open")
				menu_arg = "main"
				if rtg.begins_with("a."):
					for ra in rtg.substr(2).split("."):
						var rab := ra.split("=")
						_action(rab[0], (int(rab[1]) if rab[1].is_valid_int() else rab[1]) if rab.size() > 1 else null)
					menu_arg = hud.menu_name
				else:
					hub_tab = rtg
					_show_hub()
				print("REVIEW ", rwho, " ", rp[2], " ", rtg, " -> ", hud.menu_name, " assist=", assist)
			if menu_arg == "prostart":
				pro_new = {"pos": "MF", "c": -1, "pick": _pro_picks(), "n": "LARSEN"}
				pro_new["c"] = int(pro_new["pick"][1])
				menu_arg = "pro_start"
			if menu_arg in ["pro0", "pro1", "pro2", "pro3", "pro4"]:
				var pk9: Array = _pro_picks()
				proc.new_pro(int(pk9[0]), "LARSEN", "FW")
				_pro_enter(false)
				print("PRO start club=", CLUBS[int(car.d["club"])]["n"], " me=", car.pro_i(), " ovr=", Career.ovr_of(car.pro_pl()), " starts=", car.pro_starts(), " xi=", car.d["xi"])
				var nsim: int = {"pro0": 0, "pro1": 8, "pro2": 3, "pro3": 0, "pro4": 60}[menu_arg]
				for r9 in nsim:
					if car.season_over() and not car.cup_due() and not car.eu_due():
						print("PRO season over: offer=", car.pro_d().get("offer"), " hist=", car.pro_d().get("hist"))
						car.pro_next_season()
						print("PRO new season club=", CLUBS[int(car.d["club"])]["n"], " me=", car.pro_i(), " trust=", car.pro_d()["trust"])
						continue
					_sim_mine()
					print("PRO sim ", r9, " ", car_lines.slice(0, 3), " starts next=", car.pro_starts())
				for m9 in car.inbox():
					if str(m9["k"]) == "pjob":
						print("PRO offer mail ", m9["t"], " ", m9["st"])
				print("PRO tp=", car.pro_pl().get("tp", 0), " pxp=", car.pro_d()["pxp"], " avg=", car.pro_avg(), " ss=", car.pro_d()["ss"])
				hub_tab = {"pro0": "career", "pro1": "pro", "pro2": "league", "pro3": "career", "pro4": "pro"}[menu_arg]
				if menu_arg == "pro3":
					# into a match as your player
					car.pro_d()["trust"] = 100
					seen_how = true
					set_meta("pro_fast", true)
					car.pro_select()
					print("PRO before play starts=", car.pro_starts(), " in_career=", in_career, " car==proc ", car == proc, " assist=", assist)
					_action("c_play")
					print("PRO match pro_sq=", pro_sq, " screen=", screen)
					menu_arg = ""
				else:
					menu_arg = "main"
			if menu_arg in ["ptest0", "ptest1", "ptest2", "ptest3"]:
				carc.new_career(carc.weakest(3), true)
				carc.set_mode("full")
				_cr_enter(false)
				var pt := menu_arg
				# a run of wins, so the press come; a benched starter goes unhappy and knocks on the door
				var sq7: Array = car.d["squad"]
				var star := int(car.d["xi"][9])
				sq7[star]["mo"] = 38
				var bench7: Array = []
				for i7 in sq7.size():
					if not (car.d["xi"] as Array).has(i7):
						bench7.append(i7)
				car.d["xi"][9] = int(bench7[0])
				for r7 in 6:
					if car.cup_due():
						car.cup_finish(2, 1, true)
					var l7: Array = car.finish_match(2 if r7 != 4 else 0, 0 if r7 != 4 else 1, [int(car.d["xi"][10])])
					for x7 in l7:
						if "PRESS" in str(x7) or "UNHAPPY" in str(x7) or "PROMISE" in str(x7) or "WORDS" in str(x7):
							print("PLINE ", x7)
				for m7 in car.inbox():
					if str(m7["k"]) in ["press", "talk"]:
						print("PMAIL ", m7["k"], " | ", m7["t"], " | ", m7["st"])
				var pick := -1
				var kind7 := "talk" if pt in ["ptest1", "ptest3"] else "press"
				for m7 in car.inbox():
					if str(m7["k"]) == kind7 and str(m7["st"]) == "open":
						pick = int(m7["id"])
						break
				if pt == "ptest1" or pt == "ptest2":
					if pick >= 0:
						print("PANS ", car.mail_pick(pick, 0))
				if pt == "ptest3" and pick >= 0:
					# promise, then keep him on the bench: the promise breaks
					var pn7 := str(car.mail(pick)["pn"])
					print("PANS ", car.mail_pick(pick, 0))
					for r7 in 5:
						var l8: Array = car.finish_match(1, 0, [])
						for x7 in l8:
							if "PROMISE" in str(x7):
								print("PLINE ", x7)
					var i9: int = car._sq_find(pn7)
					if i9 >= 0:
						print("PMOOD ", car.d["squad"][i9]["mo"], " tr=", car.d["squad"][i9].has("tr"))
				var fm7 := []
				for p7 in car.d["squad"]:
					fm7.append(Career.pform(p7))
				print("PFORM ", fm7)
				if pick >= 0:
					mail_sel = pick
				else:
					mail_sel = int(car.inbox()[0]["id"])
				car.mail_read(mail_sel)
				menu_arg = "inbox"
			if menu_arg in ["etest0", "etest1", "etest2", "etest3", "etest4"]:
				var top0: int = int(ClubDB.start_leagues(Career.FIRST)[0][int(OS.get_environment("ETI")) if OS.get_environment("ETI") != "" else 1])
				carc.new_career(top0, false)
				carc.set_mode("full")
				_cr_enter(false)
				print("EU in: ", not car.eu().is_empty(), " ", car.eu_name() if not car.eu().is_empty() else "", " group ", car.eu().get("gl", "-"), " md0 after round ", car.eu_after(0), " day ", car.date_text(car.eu_day(0)))
				var et := menu_arg
				var stop_md: int = {"etest0": 0, "etest1": 3, "etest2": 8, "etest3": 2, "etest4": 99}[et]
				var guard := 0
				while guard < 80 and not car.season_over():
					guard += 1
					if car.cup_due():
						car.cup_finish(2, 1, true)
						continue
					if car.eu_due():
						if int(car.eu()["md"]) >= stop_md:
							break
						var eo9: Array = car.eu_opp()
						var ln9: Array = car.eu_finish(2, 1, true)
						print("EU md", int(car.eu()["md"]) - 1, " v ", CLUBS[int(eo9[0])]["n"], " home=", eo9[1], " ", car.date_text(car.today()), " | ", ln9.filter(func(x): return "EUROPE" in str(x) or "GROUP" in str(x) or "CHAMPIONS" in str(x)))
						continue
					car.finish_match(1, 0, [])
				print("EU state md=", car.eu().get("md"), " out=", car.eu().get("out"), " done=", car.eu().get("done"), " won=", car.eu().get("won"), " next=", car.date_text(car.next_day()), " eu_due=", car.eu_due())
				if et == "etest0" or et == "etest4":
					hub_tab = "career"
					menu_arg = "main"
				elif et == "etest3":
					menu_arg = "cal"
				else:
					menu_arg = "eu"
			if menu_arg in ["htest0", "htest1", "htest2", "htest3", "htest4"]:
				carc.new_career(carc.weakest(3), true)
				carc.set_mode("full")
				_cr_enter(false)
				if OS.get_environment("HOWN") != "":
					# your own club, made by you: its own name everywhere (awards, mails)
					car.d["own"] = {"n": "VIKINGS", "s": "VIK", "k": ["7b2fbe", "7b2fbe", "f05aa0"]}
					_apply_own()
				var rng8 := RandomNumberGenerator.new()
				rng8.seed = 7
				var full_s := menu_arg != "htest4"
				var n8: int = car.rounds_total() if full_s else 9
				for r8 in n8:
					if car.cup_due():
						car.cup_finish(2, 1, true)
					var fw := []
					for i8 in car.d["xi"]:
						if str(car.d["squad"][int(i8)]["pos"]) in ["FW", "MF"]:
							fw.append(int(i8))
					var mine8: int = rng8.randi_range(1, 4)
					var sc8 := []
					for g8 in mine8:
						sc8.append(fw[rng8.randi() % fw.size()])
					for l8 in car.finish_match(mine8, rng8.randi_range(0, 1), sc8):
						if "MONTH" in str(l8) or "SEASON" in str(l8) or "BOOT" in str(l8):
							print("HLINE ", l8)
				print("HON cab ", car.cabinet())
				print("HON aw ", car.awards().size(), " rec ", car.records())
				print("HON top ", car.scorers_top(5))
				for m8 in car.inbox().slice(0, 6):
					print("HMAIL ", m8["t"], " | ", m8["b"])
				if OS.get_environment("HOWN") != "":
					if OS.get_environment("HSCR") != "":
						for k8 in car.inbox().size():
							car.inbox()[k8]["rd"] = k8 != 9
					_action("inbox")
					menu_arg = hud.menu_name
				elif menu_arg == "htest0":
					menu_arg = "scorers"
				else:
					cab_tab = {"htest1": 0, "htest2": 1, "htest3": 2, "htest4": 1}[menu_arg]
					menu_arg = "cab"
			if menu_arg in ["ftest0", "ftest1", "ftest2"]:
				carc.new_career(carc.weakest(3), true)
				carc.set_mode("full")
				_cr_enter(false)
				var nin := 0
				for r9 in 12:
					if car.cup_due():
						for l9 in car.cup_finish(2, 1, true):
							if "INJURED" in str(l9):
								nin += 1
					var c9: Array = []
					for i9 in car.d["xi"]:
						c9.append(car.cond_of(car.d["squad"][int(i9)]))
					print("FIT r", r9, " ", car.date_text(car.now()), " xi ", c9)
					for l9 in car.finish_match(1, 0, []):
						if "INJURED" in str(l9):
							nin += 1
							print("FIT ", l9)
				print("FIT injuries in 12+ matches: ", nin)
				# a busy week: two matches three days apart
				var xi9: Array = car.d["xi"]
				car.d["squad"][int(xi9[3])]["cond"] = 58
				car.d["squad"][int(xi9[3])]["cday"] = car.now()
				car.d["squad"][int(xi9[7])]["inj"] = car.now() + 18
				car.d["squad"][int(xi9[7])]["injn"] = "a hamstring strain"
				var bi9 := -1
				for j9 in (car.d["squad"] as Array).size():
					if not xi9.has(j9) and str(car.d["squad"][j9]["pos"]) != "GK":
						bi9 = j9
				car.d["squad"][bi9]["inj"] = car.now() + 30
				car.d["squad"][bi9]["injn"] = "a knee injury"
				print("FIT swap msg: ", car.swap(int(xi9[5]), bi9))
				if menu_arg == "ftest2":
					# retraining: he works on a new role; show what playing there costs as he learns
					var rp9: Dictionary = car.d["squad"][int(xi9[3])]
					rp9["rt"] = "MF"
					for st9 in 12:
						var ln9 := []
						car._rt_tick(xi9, ln9)
						print("RT ", st9, " prog ", Career.rt_prog(rp9, "MF"), " off MF ", Career.pos_off(rp9, "MF"), " off FW ", Career.pos_off(rp9, "FW"), " ", ln9)
					rp9["rt"] = "MF"
					rp9["rtp"] = {"MF": 42.0}
					print("RT strength ", car.match_strength())
				set_meta("tsel", -1 if menu_arg == "ftest0" else (int(xi9[7]) if menu_arg == "ftest1" else int(xi9[3])))
				menu_arg = "squad9"
			if menu_arg in ["caltest", "simtest", "advtest", "csettest", "calhome"]:
				carc.new_career(carc.weakest(3), false)
				carc.set_mode("simple")
				_cr_enter(false)
				for r9 in 4:
					if car.cup_due():
						car.cup_finish(2, 1, true)
					car.finish_match(r9 % 3, 1, [])
				var ma := menu_arg
				menu_arg = "main"
				hub_tab = "career"
				if ma == "caltest":
					menu_arg = "cal"
				elif ma == "simtest":
					_sim_mine()
					menu_arg = "simres"
					print("SIMTEST ", sim_res.get("mine"), "-", sim_res.get("theirs"), " goals=", sim_res.get("goals"), " day=", car.today(), " next=", car.next_day())
				elif ma == "advtest":
					_sim_mine()
					_adv_show(adv_from)
					menu_arg = "adv"
				elif ma == "csettest":
					car.set_cfg("diff", 2)
					menu_arg = "cset"
			if menu_arg == "myclub":
				_own_start()
			if menu_arg == "pack":
				pack_res = {"n": "NORDIN", "pos": "FW", "age": 21, "pot": 84, "ovr": 77, "st": [80, 79, 66, 41]}
			if menu_arg == "table" and OS.get_cmdline_user_args().has("--rounds"):
				# a few rounds played, so the table has form
				for r7 in 7:
					car.finish_match(r7 % 3, (r7 * 2) % 3, [])
			if (menu_arg in ["career", "table", "cfull", "market", "club"] or menu_arg.begins_with("squad")) and not has_meta("rv"):
				_action("career")
			if menu_arg == "start_club":
				start_li = 0
			if menu_arg in ["car_start", "start_new", "start_mine"]:
				car_main.d["own"] = {"n": "WOODMAN FC", "s": "WFC", "k": ["2961eb", "f4f4f4", "2961eb"]}
				_apply_own()
				if menu_arg == "start_new":
					start_kind = "new"
					menu_arg = "start_lg"
				elif menu_arg == "start_mine":
					start_kind = "mine"
					menu_arg = "start_lg"
			if menu_arg == "cmclub":
				start_kind = "cup"
				cup_ctry = "DENMARK"
				menu_arg = "start_lg"
			if menu_arg in ["cupmode", "cupmine"]:
				if menu_arg == "cupmode":
					_cup_start(ClubDB.start_leagues(Career.FIRST)[0][3])
				else:
					_cup_start_mine("DENMARK")
				car_main.d["squad"][0]["n"] = "OUTSIDEGK" if menu_arg == "cupmine" else car_main.d["squad"][0]["n"]
				print("CUPMODE gk inside=", car.d["squad"][0]["n"], " outside=", car_main.d["squad"][0]["n"])
				for k3 in 2:
					print("CUPMODE ", car.cup_round_name(), " v ", car.cup_opp(), " due=", car.cup_due(), " ", car.cup_finish(3, 1, true), " main coins=", car_main.d["coins"])
				_cm_leave()
				print("CUPMODE after leave outside gk=", car_main.d["squad"][0]["n"], " cup gk=", cupc.d["squad"][0]["n"])
				_cm_enter()
				menu_arg = "cup"
			if menu_arg == "splittest":
				# an old save with a running career at a club taken over, and the own club waiting
				car_main.d["squad"][0]["n"] = "OWNGK"
				car_main.stash_put()
				car_main.new_career(ClubDB.start_leagues(Career.FIRST)[0][0], false)
				car_main.d.erase("on")
				car_main.save()
				carc.wipe()
				in_career = false
				_split_career()
				print("SPLIT career=", carc.has_save(), " on=", carc.on(), " club=", carc.d["club"], " mine=", carc.is_mine(), " | outside on=", car_main.on(), " mine=", car_main.is_mine(), " gk=", car_main.d["squad"][0]["n"], " in=", in_career)
				get_tree().quit()
				return
			if menu_arg in ["astest", "assist", "sugshot"]:
				# playing a career together: the friend looks around as assistant manager, his changes are suggestions
				start_li = 1
				_start_mine()
				carv.d = carc.d.duplicate(true)
				net.role = "guest"
				net.connected = true
				_action("as_open")
				print("ASSIST in=", assist, " car=carv ", car == carv, " menu=", hud.menu_name, " club=", CLUBS[int(carv.d["club"])]["n"], " budget=", car.money(int(car.d["coins"])))
				var bench := -1
				for i4 in (car.d["squad"] as Array).size():
					if not (car.d["xi"] as Array).has(i4):
						bench = i4
						break
				var n0 := (carc.d["squad"] as Array).size()
				_action("c_squad")
				_action("c_pick", bench)
				_action("c_sell")
				car_sell = car_sel
				var t1 := _sug_text("c_sell", null)
				var s1 := {"act": "c_sell", "arg": null, "ui": {"sel": car_sel, "ab": 0, "sc": -1, "si": -1}, "t": t1}
				var s2 := {"act": "c_swap", "arg": [0.0, float(bench)], "ui": {"sel": -1, "ab": 0, "sc": -1, "si": -1}, "t": "SWAP SOMEONE AND SOMEONE ELSE"}
				var s3 := {"act": "c_form", "arg": null, "ui": {"sel": -1, "ab": 0, "sc": -1, "si": -1}, "t": _sug_text("c_form", null)}
				print("ASSIST sug1=", t1, " | sug3=", s3["t"], " | carv squad unchanged=", (carv.d["squad"] as Array).size() == n0)
				_action("c_buy", 0)
				print("ASSIST after buy tap carv=", (carv.d["squad"] as Array).size(), " carc=", (carc.d["squad"] as Array).size())
				_action("cr_exit")
				print("ASSIST after exit tap assist=", assist, " menu=", hud.menu_name)
				if menu_arg == "assist":
					_action("as_open")
					for la in ["inbox", "cal", "cab", "scorers", "tnews", "youth"]:
						_action(la)
						print("ASSIST look ", la, " -> ", hud.menu_name)
					menu_arg = "main"
				else:
					_as_leave(false)
					net.role = "host"
					print("HOST in=", in_career, " car=carc ", (car == carc or car == proc))
					var f0: String = car.form()
					for sg2 in [s1, s2, s3]:
						sug_cur = sg2
						sug_prev = "main"
						if menu_arg == "sugshot":
							hud.show_menu("sug", _menu_info())
							break
						_sug_answer(true)
						print("HOST answered ", sg2["t"])
					if menu_arg == "astest":
						print("HOST squad ", n0, " -> ", (carc.d["squad"] as Array).size(), " form ", f0, " -> ", car.form())
						get_tree().quit()
						return
					menu_arg = "sug"
			if menu_arg in ["ecotest", "ctshot", "ctsign", "sqsel", "ecoclub", "ecotr"]:
				# the career's money: wages, contracts, talks, buildings from the board
				start_li = 1
				_start_mine()
				car.d["mode"] = "full"
				print("ECO wages=", car.wages(), " wb=", car.wb(), " fac=", car.d.get("fac", {}), " coins=", car.money(int(car.d["coins"])))
				var bi := 13
				car.talk_renew(bi)
				var t0: Dictionary = car.talk()
				print("ECO renew ask=", t0.get("ask"), " min=", t0.get("min"), " maxy=", t0.get("maxy"), " ct=", t0.get("ct"))
				if menu_arg == "ctshot":
					car.talk_set("w", -3)
					car_msg = car.talk_offer()
					menu_arg = "contract"
				elif menu_arg == "sqsel":
					car.talk_end()
					car_sel = 2
					menu_arg = "squad"
				elif menu_arg == "ecoclub":
					car.talk_end()
					car.d["board"]["conf"] = 70
					car_msg = car.fac_ask("training")
					menu_arg = "club"
				elif menu_arg == "ecotr":
					car.talk_end()
					hub_tab = "transfers"
					menu_arg = "main"
				else:
					car.talk_set("w", -6)
					print("ECO low offer: ", car.talk_offer())
					car.talk_set("w", 6)
					print("ECO fair offer: ", car.talk_offer(), " wk=", car.d["squad"][bi]["wk"], " ct=", car.d["squad"][bi]["ct"])
					var n0 := (car.d["squad"] as Array).size()
					car.buy(0)
					print("ECO market talk=", not car.talk().is_empty(), " squad still ", (car.d["squad"] as Array).size() == n0)
					if menu_arg == "ctsign":
						menu_arg = "contract"
					else:
						print("ECO sign: ", car.talk_offer(), " squad ", n0, " -> ", (car.d["squad"] as Array).size(), " wages=", car.wages(), "/", car.wb())
						print("ECO wb up: '", car.wb_move(true), "' wb=", car.wb(), " | down: '", car.wb_move(false), "'")
						car.d["board"]["conf"] = 30
						print("ECO fac low conf: ", car.fac_ask("stadium"))
						car.d["freq"] = 0
						car.d["board"]["conf"] = 90
						car.d["coins"] = 99999
						print("ECO fac yes: ", car.fac_ask("stadium"), " | again: ", car.fac_ask("youth"))
						var lv0: int = car.fac("stadium")
						var ln: Array = []
						for r9 in 8:
							ln = car.finish_match(2, 0, [], [])
						print("ECO after 8 matches stadium ", lv0, " -> ", car.fac("stadium"), " lines has ready=", str(ln).contains("READY"), " grow lines=", str(ln).contains("+1"))
						var gl := 0
						var o0 := _avg_ovr(car.d)
						while not car.season_over():
							for l9 in car.finish_match(1, 0, [], []):
								if str(l9).contains("  +") and not str(l9).contains("TP"):
									gl += 1
						print("ECO season growth lines=", gl, " xi ovr ", o0, " -> ", _avg_ovr(car.d))
						var cts := []
						for pl9 in car.d["squad"]:
							cts.append(int(pl9.get("ct", -9)))
						car.next_season()
						print("ECO contracts before ", cts, " squad now ", (car.d["squad"] as Array).size(), " note=", car.d["note"], " xi ok=", (car.d["xi"] as Array).max() < (car.d["squad"] as Array).size())
						get_tree().quit()
						return
			if menu_arg in ["moodtest", "trshot", "moodsq", "moodteam"]:
				# mood and training: men who sit out get unhappy, the plan changes growth and mood
				start_li = 1
				_start_mine()
				car.set_plan("attack", 2)
				var ro0: Dictionary = car.roles()
				var sq0: Array = car.d["squad"]
				var xi0: Array = (car.d["xi"] as Array).duplicate()
				var bench := []
				for i9 in sq0.size():
					if not xi0.has(i9):
						bench.append(i9)
				var sho0 := 0
				for i9 in sq0.size():
					sho0 += int(sq0[i9]["sho"])
				var unh := 0
				var lv := 0
				var played_k := 0
				for k9 in (12 if menu_arg == "moodtest" else 9):
					for l9 in car.finish_match(2, 1, [], xi0):
						if str(l9).contains("UNHAPPY"):
							unh += 1
						if str(l9).contains("ASKED TO LEAVE"):
							lv += 1
					played_k += 1
				var sho1 := 0
				for i9 in sq0.size():
					sho1 += int(sq0[i9]["sho"])
				var moods := []
				for i9 in sq0.size():
					moods.append("%d:%s r%d %d%s" % [i9, "XI" if xi0.has(i9) else "b", int(ro0.get(i9, 9)), int(sq0[i9].get("mo", -1)), " TR" if sq0[i9].has("tr") else ""])
				print("MOOD after ", played_k, " matches: ", moods)
				print("MOOD unhappy lines=", unh, " leave lines=", lv, " total sho ", sho0, " -> ", sho1, " plan=", car.plan())
				var sad := -1
				for i9 in bench:
					if int(sq0[i9].get("mo", 65)) < 35:
						sad = i9
						break
				if sad >= 0:
					car.talk_renew(sad)
					var ts: Dictionary = car.talk()
					print("MOOD unhappy renew ask=", ts.get("ask"), " wk=", sq0[sad]["wk"], " maxy=", ts.get("maxy"), " unhappy=", ts.get("unhappy"), " off=", car.mood_off(sq0[sad]))
					car.talk_end()
				print("MOOD off for xi[0]=", car.mood_off(sq0[xi0[0]]), " k young/old ", car.train_k({"age": 19}), "/", car.train_k({"age": 33}))
				car.set_focus(xi0[5])
				car.set_focus(xi0[5])
				print("MOOD focus ", car.focus_name(str(sq0[xi0[5]].get("tf", ""))))
				if menu_arg == "moodtest":
					get_tree().quit()
					return
				if menu_arg == "trshot":
					menu_arg = "training"
				elif menu_arg == "moodsq":
					car_sel = sad if sad >= 0 else xi0[5]
					menu_arg = "squad"
				else:
					hub_tab = "team"
					menu_arg = "main"
			if menu_arg == "simpletest":
				# a SIMPLE career: no contract talks, nobody leaves when a contract runs out
				start_li = 1
				_start_mine()
				car.d["mode"] = "simple"
				car.d["coins"] = 99999
				var n0 := (car.d["squad"] as Array).size()
				var m0: String = car.buy(0)
				print("SIMPLE buy: '", m0, "' talk=", not car.talk().is_empty(), " squad ", n0, " -> ", (car.d["squad"] as Array).size(), " wg=", _car_info()["wg"])
				var g8 := 0
				while not car.season_over() and g8 < 200:
					car.finish_match(1, 0, [], [])
					g8 += 1
				print("SIMPLE season 0 rounds ", g8)
				var n1 := (car.d["squad"] as Array).size()
				for k9 in 4:
					car.next_season()
					var g9 := 0
					while not car.season_over() and g9 < 200:
						car.finish_match(1, 0, [], [])
						g9 += 1
					print("SIMPLE season ", k9, " rounds ", g9, " squad ", (car.d["squad"] as Array).size())
				print("SIMPLE after 4 seasons squad ", n1, " -> ", (car.d["squad"] as Array).size())
				get_tree().quit()
				return
			if menu_arg == "rectest":
				# the Profile record counts every match you play (here: a quick match won 2-1, then lost 0-3 as the guest)
				print("REC before ", _rec())
				humans = [Human.new()]
				screen = "match"
				score = [2, 1]
				_full_time()
				print("REC after win ", _rec())
				humans[0].team = 1
				score = [3, 0]
				_full_time()
				print("REC after loss as team 1 ", _rec(), " shown=", _menu_info()["pstats"])
				net.role = "host"
				humans[0].team = 0
				score = [1, 0]
				var cc0 := int(car_main.d["coins"])
				_full_time()
				print("FRIEND win lines=", car_lines.slice(0, 3), " coins ", cc0, " -> ", int(car_main.d["coins"]))
				net.role = ""
				get_tree().quit()
				return
			if menu_arg == "fttest":
				# a friend's room: both bring their own club and eleven (host, then the same start on the guest)
				print("FT has_own=", _has_own(), " own=", car_main.d.get("own", {}).get("n", "-"))
				var gt := _ft_me().duplicate(true)
				gt["n"] = "DADS FC"
				gt["k"] = ["2961eb", "f4f4f4", "2961eb"]
				gt["f"] = "4-4-2"
				for i8 in 11:
					gt["xi"][i8]["n"] = "DAD%d" % i8
					gt["xi"][i8]["sho"] = 90
				guest_tm = gt if _ft_ok(gt) else {}
				var nm := func(t: int) -> String:
					var o8 := []
					for p8 in teams[t]:
						o8.append("%s#%d" % [p8.pname, p8.num])
					return " ".join(PackedStringArray(o8.slice(0, 4)))
				var xi0: Dictionary = car_main.d["squad"][int(car_main.d["xi"][1])]
				print("FT my squad #1 = ", xi0["n"], " #", xi0["num"])
				for md8 in ["versus", "coop"]:
					opt_mode = md8
					_host_start()
					print("FT host ", md8, " ft_on=", ft_on, " teams=", TEAM_NAMES, " forms=", forms, " | t0: ", nm.call(0), " | t1: ", nm.call(1), " | t1 sho=", teams[1][9].sho)
					var sm: Dictionary = JSON.parse_string(JSON.stringify(start_msg))
					_to_menu(true)
					print("FT after menu ft_on=", ft_on, " teams=", CLUBS[RKI]["n"])
					_guest_start(sm)
					print("FT guest ", md8, " ft_on=", ft_on, " teams=", TEAM_NAMES, " forms=", forms, " | t0: ", nm.call(0), " | t1: ", nm.call(1))
					_to_menu(true)
				opt_own = false
				guest_tm = {}
				opt_mode = "versus"
				opt_club = 2
				guest_club = 5
				_host_start()
				print("FT plain clubs ft_on=", ft_on, " teams=", TEAM_NAMES, " start has ft=", start_msg.has("ft"))
				get_tree().quit()
				return
			if menu_arg == "coinstest":
				# a whole season won in the career: a few coins a match, a lot for the title, some for the cup
				start_li = 1
				_start_mine()
				var c0 := int(car_main.d["coins"])
				career_on = true
				while not car.season_over():
					score = [3, 0]
					car_lines = car.finish_match(3, 0, [], [])
					_car_coins(true)
				print("COINS season: ", car_lines.slice(car_lines.size() - 2), " outside ", c0, " -> ", int(car_main.d["coins"]))
				var c1 := int(car_main.d["coins"])
				while not car.cup_over():
					score = [2, 0]
					car_lines = car.cup_finish(2, 0, true)
					_car_coins(false)
				print("COINS cup: ", car_lines[car_lines.size() - 1], " outside ", c1, " -> ", int(car_main.d["coins"]), " career money ", car.money(int(car.d["coins"])))
				get_tree().quit()
				return
			if menu_arg == "minetest":
				# own club outside -> career with my club (own money) -> back out: the club outside is untouched
				car.d["coins"] = 4321
				car.d["squad"][0]["n"] = "KEEPME"
				start_li = 1
				_start_mine()
				print("MINE career in=", in_career, " lg=", car.league_name(), " money=", car.money(int(car.d["coins"])), " gk=", car.d["squad"][0]["n"], " name=", CLUBS[int(car.d["club"])]["n"])
				car.d["squad"][0]["n"] = "CAREERGK"
				car.d["coins"] = 99
				car.save()
				_action("cr_exit")
				print("MINE outside in=", in_career, " coins=", car.money(int(car.d["coins"])), " gk=", car.d["squad"][0]["n"], " tab=", hub_tab)
				_action("tab", "team")
				_action("c_home")
				print("MINE back in=", in_career, " gk=", car.d["squad"][0]["n"], " tab=", hub_tab, " money=", car.money(int(car.d["coins"])))
				get_tree().quit()
				return
			if menu_arg in ["rkfull", "rktest"]:
				if menu_arg == "rktest":
					var seq := [1.0, 1.0, 1.0, 0.0, 1.0, 0.5, 0.0, 0.0, 1.0]
					for i3 in 40:
						var r3: Dictionary = rk.match_result(rk.rp() + 30, seq[i3 % seq.size()], 1, 2)
						print("RKTEST ", i3, " ", r3["k0"]["n"], " -> ", r3["k1"]["n"], " d=", r3["delta"], " rp=", rk.rp(), " sh=", r3["sh"], " road=", r3["road"], " coins=", r3["coins"])
					rk.d["sm"] = "2000-01"
					print("RKTEST season ", rk.season(), " rp=", rk.rp())
					get_tree().quit()
					return
				rk_on = true
				rk_opp = {"n": "FC NORDSTAR", "rp": 340}
				score = [2, 1]
				_rk_finish()
				menu_arg = "full"
			if menu_arg == "strtest":
				for li in 6:
					car.new_career(car.ids(li)[0] if li < 0 else ClubDB.start_leagues(Career.FIRST)[li][0], false)
					var top: float = car.my_strength()
					car.new_career(car.weakest(li), true)
					print("STRTEST ", car.league_name(), " top club ", car.rating(ClubDB.start_leagues(Career.FIRST)[li][0]), " -> squad ", snappedf(top, 0.1), "   own club in place of ", car.rating(car.d["club"]), " -> squad ", snappedf(car.my_strength(), 0.1), " exp=", car.expected_rank(), " goal=", car.board()["obj"][0]["t"], " cup=", car.board()["obj"][1]["t"])
				get_tree().quit()
				return
			if menu_arg in ["scout", "scout_sq", "bidtest"] and not has_meta("rv"):
				_action("career")
				scout_li = 0
				if menu_arg != "scout":
					scout_c = car.ids(0)[2]
					scout_i = 9
					car.d["coins"] = 5000
					if menu_arg == "bidtest":
						print("BIDTEST ask=", car.ask_price(scout_c, 9), " low=", car.bid(scout_c, 9, 100), " counter=", car.bid(scout_c, 9, int(car.ask_price(scout_c, 9) * 0.8)))
						var nm0 := str(car.cpu_squad(scout_c)[9]["n"])
						print("BIDTEST pay=", car.bid(scout_c, 9, car.ask_price(scout_c, 9)), " squad=", car.d["squad"].size(), " their9=", car.cpu_squad(scout_c)[9]["n"], " was=", nm0, " coins=", car.d["coins"])
						car.d["xi"].erase(5)
						print("BIDTEST sell=", car.sell(5))
						get_tree().quit()
						return
					scout_res = car.bid(scout_c, scout_i, int(car.ask_price(scout_c, 9) * 0.85))
				menu_arg = "scout_sq" if menu_arg == "scout_sq" else "scout"
			if menu_arg in ["board", "review", "reviewsack", "boardtest", "cmode"]:
				# test screens for the board: play a season by script (win most, or lose most for the sack)
				_action("career")
				if menu_arg != "cmode":
					car.set_mode("full")
				if menu_arg in ["review", "reviewsack", "boardtest"]:
					var lose := menu_arg == "reviewsack"
					var k := 0
					while not car.season_over():
						if car.cup_due():
							print("BOARDTEST cup ", car.cup_round_name(), " ", car.cup_finish(0 if lose else 2, 1, false))
						var ln: Array = car.finish_match(0 if lose else (2 if k % 3 != 2 else 1), 1, [9])
						k += 1
						print("BOARDTEST r=", car.d["round"], " ", ln[1], " rank=", car.rank_of(int(car.d["club"])), " objs=", car.board()["obj"].map(func(o): return car.obj_state(o)))
					print("BOARDTEST review=", car.review(), " offers=", car.offers(), " coins=", car.d["coins"])
					if menu_arg == "boardtest":
						car.next_season()
						print("BOARDTEST next: season=", car.d["season"], " div=", car.div(), " cup=", car.cup()["r"], " objs=", car.board()["obj"])
						get_tree().quit()
						return
					menu_arg = "review"
				elif menu_arg == "board":
					for k2 in 5:
						if car.cup_due():
							car.cup_finish(2, 0, true)
						car.finish_match(k2 % 3, 1, [9])
			if menu_arg in ["cup", "cup2", "cuptest"]:
				_action("career")
				if menu_arg != "cup":
					car.cup_new()
					print("CUPTEST ", car.cup_round_name(), " v ", car.cup_opp(), " ", car.cup_finish(2, 1))
					print("CUPTEST ", car.cup_round_name(), " v ", car.cup_opp(), " ", car.cup_finish(3, 0))
				if menu_arg == "cuptest":
					print("CUPTEST ", car.cup_round_name(), " v ", car.cup_opp(), " ", car.cup_finish(1, 0), " over=", car.cup_over(), " cups=", car.stats().get("cups", 0))
					car.cup_new()
					print("CUPTEST ", car.cup_round_name(), " v ", car.cup_opp(), " ", car.cup_finish(0, 1), " over=", car.cup_over(), " opp=", car.cup_opp())
				menu_arg = "cup"
			if menu_arg in ["derbytest", "derbyres"]:
				carc.new_career(carc.weakest(3), true)
				carc.set_mode("full")
				_cr_enter(false)
				var me_d := int(car.d["club"])
				print("DERBY me=", CLUBS[me_d]["n"], " rival=", CLUBS[car.rival_of(me_d)]["n"], " same lg=", car.league_of(car.rival_of(me_d)) == car.league_of(me_d))
				for c9 in [8, 20, 40, 60, 100]:
					if c9 < CLUBS.size():
						print("DERBY ", CLUBS[c9]["n"], " v ", CLUBS[car.rival_of(c9)]["n"] if car.rival_of(c9) >= 0 else "-")
				for it in 60:
					if car._next_derby():
						break
					_sim_mine()
				print("DERBY next=", car._next_derby(), " round=", car.d["round"], " obj=", car.board()["obj"][2]["t"])
				if menu_arg == "derbyres":
					_sim_mine()
					print("DERBY after sim lines=", car_lines.slice(0, 6), " rec=", car.derby_rec())
					menu_arg = "simres"
				else:
					menu_arg = "main"
					hub_tab = "career"
			if menu_arg == "dealtest":
				# smarter deals: swap, sell-on both ways, release clauses
				carc.new_career(carc.weakest(3), true)
				carc.set_mode("full")
				_cr_enter(false)
				car.d["coins"] = 99999
				car.d["wb"] = 9999
				# who would come to a Division 4 club: per league, how many say no
				print("NO my strength ", car.my_strength())
				for li9 in 6:
					var nno := 0
					var nall := 0
					var ex9 := ""
					for c9 in car.ids(li9):
						var cs9: Array = car.cpu_squad(int(c9))
						for j9 in cs9.size():
							nall += 1
							var r9: String = car.refuses(cs9[j9], int(c9))
							if r9 != "":
								nno += 1
								ex9 = "%s %d: %s" % [str(cs9[j9]["n"]), Career.ovr_of(cs9[j9]), r9]
					print("NO league ", li9, " ", nno, "/", nall, " e.g. ", ex9)
				var c0: int = car.ids()[1] if car.ids()[0] == int(car.d["club"]) else car.ids()[0]
				var n0: int = (car.d["squad"] as Array).size()
				# a swap: my man 5 + money for their man 3 (simple path: no contract talk)
				car.d["mode"] = "simple"
				var mine5: String = str(car.d["squad"][5]["n"])
				var w5: int = car.swap_worth(c0, 3, 5)
				var r1: Dictionary = car.bid(c0, 3, 0, {"swap": mine5})
				print("DEAL swap worth=", w5, " ask=", car.ask_price(c0, 3), " -> ", r1, " squad ", n0, "->", (car.d["squad"] as Array).size(), " mine5 now at them=", (car.cpu_squad(c0) as Array).map(func(p): return str(p["n"])).has(mine5))
				# buy with a sell-on for them, then sell him: they get 20%
				var ask4: int = car.ask_price(c0, 4)
				var r2: Dictionary = car.bid(c0, 4, int(round(ask4 * Career.SELLON_CUT / 5.0)) * 5, {"so": true})
				var last: Dictionary = car.d["squad"][(car.d["squad"] as Array).size() - 1]
				print("DEAL buy with sell-on: ", r2, " sob=", last.get("sob"))
				var coins0: int = int(car.d["coins"])
				var sr: String = car._sell_to((car.d["squad"] as Array).size() - 1, car.ids()[2], 1000)
				print("DEAL sold him on: ", sr, " got=", int(car.d["coins"]) - coins0)
				# sell with a sell-on, then a CPU deal moves him: we get our share
				var rng := RandomNumberGenerator.new()
				rng.randomize()
				car._mail("bid", "test", "test", {"c": car.ids()[3], "pn": str(car.d["squad"][7]["n"]), "amt": 500, "st": "open", "left": 1, "cnt": 0})
				var mid: int = int(car.d["mid"])
				var so_n: String = str(car.d["squad"][7]["n"])
				print("DEAL sell with sell-on: ", car.bid_answer(mid, "son"))
				var coins1: int = int(car.d["coins"])
				var paid := false
				for k in 400:
					var x: Array = car._cpu_deal(rng, 10)
					if not x.is_empty() and str(x[1]) == so_n:
						print("DEAL cpu deal moved him: ", x, " we got ", int(car.d["coins"]) - coins1, " mail=", car.inbox()[0]["t"])
						paid = true
						break
				print("DEAL sell-on paid=", paid)
				# a release clause of mine paid by a club
				car.d["mode"] = "full"
				car.d["squad"][2]["rc"] = 50
				var fired := false
				for k in 200:
					var ln: Array = []
					car._clause_tick(rng, ln)
					if not ln.is_empty():
						print("DEAL clause: ", ln, " ", car.inbox()[0]["t"])
						fired = true
						break
				print("DEAL clause fired=", fired)
				get_tree().quit()
				return
			if menu_arg == "natseason":
				# two seasons with a national job: every match simulated, the days advanced
				carc.new_career(carc.weakest(3), true)
				carc.set_mode("full")
				_cr_enter(false)
				car.nat_take(int(OS.get_environment("NATN")) if OS.get_environment("NATN") != "" else 0)
				print("NAT squad=", car.nat_squad().size(), " xi=", car.nat_xi().size(), " str=", snappedf(car.nat_str(int(car.nat()["n"])), 0.1), " grp=", car.nat_q()["grp"], " afters=", range(10).map(func(i): return car.nat_after(i)), " mine=", range(10).map(func(i): return not car._nat_mine_q(i).is_empty()))
				var nn := 0
				for it in 300:
					if car.season_over() and not car.cup_due() and not car.eu_due() and not car.nat_due():
						print("NAT season end ", car.d["season"], " hist=", car.nat().get("hist"), " st=", car.nat().get("st"), " ok=", car.nat().get("ok"))
						if int(car.d["season"]) >= 2:
							break
						car.next_season()
						print("NAT new season q=", car.nat_q().get("grp"), " t=", car.nat_t().is_empty())
						continue
					while car.now() < car.next_day():
						car.advance()
					var nd: bool = car.nat_due() and not car.cup_due() and not car.eu_due()
					var d0: int = car.next_day()
					_sim_mine()
					if nd:
						nn += 1
						print("NAT match ", nn, " ", car.date_text(d0), " ", sim_res.get("what"), " ", sim_res.get("a"), " ", sim_res.get("mine"), "-", sim_res.get("theirs"), " ", sim_res.get("b"), " lines=", (sim_res.get("lines", []) as Array).slice(0, 3), " today=", car.today(), " next=", car.next_day(), " round=", car.d["round"])
				get_tree().quit()
				return
			if menu_arg == "advseason":
				# a whole season a day at a time: advance to match day, simulate, again
				carc.new_career(carc.weakest(3), true)
				carc.set_mode("full")
				_cr_enter(false)
				var steps := 0
				var mails := 0
				for it in int(OS.get_environment("ADVN")) if OS.get_environment("ADVN") != "" else 400:
					if car.season_over() and not car.cup_due() and not car.eu_due():
						break
					var m0: int = int(car.d.get("mid", 0))
					while car.now() < car.next_day():
						car.advance()
						steps += 1
					mails += int(car.d.get("mid", 0)) - m0
					_sim_mine()
					if it % 5 == 0:
						print("ADV it=", it, " round=", car.d["round"], " ", car.date_text(car.today()), " steps=", steps, " t=", Time.get_ticks_msec())
				print("ADVSEASON round=", car.d["round"], " day=", car.today(), " ", car.date_text(car.today()), " steps=", steps, " mails=", mails, " deals=", car.deals().size(), " over=", car.season_over())
				get_tree().quit()
				return
				menu_arg = "main"
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
				print("BUYTEST after list listed=", Career.listed(car.d["squad"][12]))
				car.d["wlast"] = car.now() - 7
				var bl: Array = []
				for bt in 6:
					car.world_tick(bl)
					car.d["wlast"] = car.now() - 7
				print("BUYTEST bids=", bl)
				print("BUYTEST after sell size=", car.d["squad"].size(), " coins=", car.d["coins"], " msg=", car_msg, " xi=", car.d["xi"])
				car_sel = 12
				menu_arg = "squad9"
			if menu_arg == "abil":
				car_sel = 9
				car.d["coins"] = 900
				print("ABTEST before=", Career.ab_of(car.d["squad"][9]), " pos=", car.d["squad"][9]["pos"], " ovr=", Career.ovr_of(car.d["squad"][9]))
				ab_slot = Career.ab_of(car.d["squad"][9]).size()
				var kk: String = Career.ab_for(str(car.d["squad"][9]["pos"]))[0]
				car.learn_ab(9, ab_slot, kk)
				print("ABTEST after=", Career.ab_of(car.d["squad"][9]), " coins=", car.d["coins"])
				var nab := 0
				for pq in car.d["squad"]:
					nab += Career.ab_of(pq).size()
				print("ABTEST squad skills=", nab, " of ", car.d["squad"].size(), " players")
				ab_slot = mini(1, Career.ab_of(car.d["squad"][9]).size())
			if menu_arg == "squadab":
				car_sel = 9
				menu_arg = "squad"
			if menu_arg.begins_with("squad") and not has_meta("rv"):
				for fi2 in (int(menu_arg.substr(5)) % 9) if menu_arg.length() > 5 else 0:
					_action("c_form")
				if menu_arg != "squad9":
					car_sel = 9
					if menu_arg == "squad7":
						car.d["squad"][9]["tp"] = 2
				elif has_meta("tsel"):
					car_sel = int(get_meta("tsel"))
				menu_arg = "squad"
			if menu_arg in ["ftteams", "ftlobby"]:
				# the friend's room: team picker with MY CLUB, and the lobby with the friend's own club
				teams_from = "lobby"
				net.role = "host"
				net.connected = true
				room = "4821"
				opt_mode = "versus"
				guest_tm = {"n": "DADS FC", "xi": []}
				menu_arg = "teams" if menu_arg == "ftteams" else "lobby"
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
	# a career club plays its own formation
	if CLUBS[b].has("f"):
		forms[1] = FORM_NAMES[clampi(int(CLUBS[b]["f"]), 0, FORM_NAMES.size() - 1)]
	if rk_on or ft_on:
		for t in 2:
			var fn := str((tov[t] as Dictionary).get("f", ""))
			if FORMS.has(fn):
				forms[t] = fn
	elif career_on:
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

# Your formation with the spots you dragged your men to: [[role, along, across], ...]
func _my_form(fname: String, lay: Dictionary) -> Array:
	var out := []
	var base: Array = FORMS.get(fname, FORMS["4-3-3"])
	for i in base.size():
		var f: Array = base[i]
		var k := str(i)
		if i > 0 and lay.has(k) and lay[k] is Array and (lay[k] as Array).size() == 2:
			var a := float(lay[k][0])
			out.append([Career.role_at(a), a, float(lay[k][1])])
		else:
			out.append([f[0], f[1], f[2]])
	return out

func _other_club(mine: int) -> int:
	if mine >= Career.FIRST:
		return randi() % Career.FIRST
	var o := randi() % (Career.FIRST - 1)
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
		var cpu_xi := []
		if t == 1 and career_on and clubs[1] >= Career.FIRST:
			var rl := []
			for f in FORM:
				rl.append(str(f[0]))
			cpu_xi = car.cpu_xi(clubs[1], rl)
		if rk_on or ft_on:
			var tl = (tov[t] as Dictionary).get("lay", {})
			FORM = _my_form(forms[t], tl if tl is Dictionary else {})
		elif t == 0 and career_on:
			FORM = _my_form(forms[0], car.lay())
		elif t == 0 and not lay_over.is_empty():
			FORM = _my_form(forms[0], lay_over)
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
			var base: Array = {"GK": [72, 70, 60, 74], "DF": [68, 46, 64, 76], "MF": [70, 66, 77, 64], "FW": [79, 77, 66, 42]}[p.role]
			var up := 0
			p.star = i == 9 or i == (6 + clubs[t] % 2)
			if p.star:
				up = 8
			p.pac = clampi(base[0] + up + rng.randi_range(-5, 5), 40, 96)
			p.sho = clampi(base[1] + up + rng.randi_range(-5, 5), 25, 96)
			p.pas = clampi(base[2] + up + rng.randi_range(-5, 5), 40, 96)
			p.dfn = clampi(base[3] + up + rng.randi_range(-5, 5), 25, 96)
			match p.role:
				"GK": p.ovr = int(round(p.dfn * 0.35 + p.pac * 0.3 + p.sho * 0.25 + p.pas * 0.1))
				"DF": p.ovr = int(round(p.dfn * 0.55 + p.pac * 0.25 + p.pas * 0.2))
				"MF": p.ovr = int(round(p.pas * 0.45 + p.pac * 0.2 + p.sho * 0.2 + p.dfn * 0.15))
				_: p.ovr = int(round(p.sho * 0.5 + p.pac * 0.35 + p.pas * 0.15))
			# skills: a club's stars have one, the keeper sometimes too
			p.ab = []
			if p.star or (p.role == "GK" and rng.randf() < 0.35):
				var pool0 := Career.ab_for(p.role)
				p.ab = [pool0[rng.randi() % pool0.size()]]
			var rxi: Array = (tov[t] as Dictionary).get("xi", []) if (rk_on or ft_on) else []
			if rxi.size() == 11 and rxi[i] is Dictionary:
				# ranked: each side plays with its own club's eleven
				var rp: Dictionary = rxi[i]
				var off3 := Career.pos_off(rp, p.role)
				p.pname = str(rp.get("n", p.pname))
				p.num = int(rp.get("num", p.num))
				p.pac = clampi(int(rp.get("pac", 60)), 20, 99) + off3
				p.sho = clampi(int(rp.get("sho", 60)), 20, 99) + off3
				p.pas = clampi(int(rp.get("pas", 60)), 20, 99) + off3
				p.dfn = clampi(int(rp.get("dfn", 60)), 20, 99) + off3
				p.ovr = Career.ovr_of({"pos": str(rp.get("pos", "MF")), "pac": p.pac, "sho": p.sho, "pas": p.pas, "dfn": p.dfn})
				p.star = false
				var rab = rp.get("ab", [])
				p.ab = []
				if rab is Array:
					for k in rab:
						if Career.ABIL.has(str(k)) and p.ab.size() < 2:
							p.ab.append(str(k))
			elif career_on:
				if t == 0:
					# your own squad: the eleven you picked, with their own numbers
					var pl: Dictionary = car.d["squad"][int(car.d["xi"][i])]
					var off_pos: int = Career.pos_off(pl, p.role) + car.mood_off(pl)
					p.sq = int(car.d["xi"][i])
					p.pname = str(pl["n"])
					p.pac = int(pl["pac"]) + off_pos
					p.sho = int(pl["sho"]) + off_pos
					p.pas = int(pl["pas"]) + off_pos
					p.dfn = int(pl["dfn"]) + off_pos
					p.ovr = Career.ovr_of(pl) + off_pos
					p.star = false
					p.ab = Career.ab_of(pl)
				elif t == 1 and clubs[1] >= Career.FIRST:
					# the other club's own men, the best eleven for its formation
					var cx: Dictionary = cpu_xi[i]
					p.pname = str(cx["n"])
					p.num = int(cx["num"])
					var off2 := Career.pos_off(cx, p.role)
					p.pac = int(cx["pac"]) + off2
					p.sho = int(cx["sho"]) + off2
					p.pas = int(cx["pas"]) + off2
					p.dfn = int(cx["dfn"]) + off2
					p.ovr = Career.ovr_of(cx) + off2
					p.star = Career.ovr_of(cx) >= car.rating(clubs[1]) + 4
					p.ab = Career.ab_of(cx)
				else:
					var lv: int = car.club_level(clubs[t])
					p.pac += lv
					p.sho += lv
					p.pas += lv
					p.dfn += lv
					p.ovr += lv
			elif t == 1 and sq1_over.size() == 11:
				p.pname = str(sq1_over[i][0])
				p.num = int(sq1_over[i][1])
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
	audio = AudioDir.new()
	add_child(audio)

# ---------------------------------------------------------------- effects (also sent to the guest online)

func _quiet() -> bool:
	return autotest or screen == "menu"

var _cf_ball := Vector3.ZERO
var _cf_v := 0.0
# The crowd follows the play every frame (on the guest's phone too): the ball near a goal, and
# the ball running at a goal fast, make the ground rise; midfield lets it settle again.
func _crowd_feed(rdt: float) -> void:
	if audio == null:
		return
	audio.in_match = screen == "match" and not autotest
	audio.paused = paused
	audio.derby = derby_on
	var bp := ball.position
	if rdt > 0.0 and Engine.time_scale > 0.0:
		var vx := (bp.x - _cf_ball.x) / (rdt * Engine.time_scale)
		if absf(vx) < 60.0:
			_cf_v = lerpf(_cf_v, vx, clampf(rdt * 6.0, 0.0, 1.0))
	_cf_ball = bp
	var bx := absf(bp.x)
	var near := clampf((bx - 18.0) / 30.0, 0.0, 1.0)
	var run := clampf(_cf_v * signf(bp.x) / 14.0, 0.0, 1.0) * clampf((bx - 4.0) / 28.0, 0.0, 1.0)
	var box := 1.0 if (bx > HL - 17.0 and absf(bp.z) < 21.0) else 0.0
	var dg := maxf(near * 0.7 + run * 0.4, box * 0.92)
	if state in ["half", "full", "goal", "replay", "intro", "off"] or set_piece == "throw":
		dg *= 0.35
	audio.danger = clampf(dg, 0.0, 1.0)

func fx(kind: String, a = null) -> void:
	if _quiet():
		return
	if net.role == "host":
		out_ev.append([kind, a])
	_do_fx(kind, a)

# a sound where the ball is; vol 0..1 (a soft tap to a full strike)
func snd(k: String, vol := 1.0) -> void:
	if _quiet():
		return
	fx("snd", [k, snappedf(vol, 0.01), snappedf(ball.position.x, 0.1), snappedf(ball.position.y, 0.1), snappedf(ball.position.z, 0.1)])

func _do_fx(kind: String, a) -> void:
	match kind:
		"snd":
			if a is String:
				audio.play(a)
			else:
				audio.play(str(a[0]), float(a[1]), Vector3(float(a[2]), float(a[3]), float(a[4])))
		"goal_snd":
			audio.goal(int(a))
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
		"ab":
			var ai := int(a[0])
			if ai >= 0 and ai < players.size() and Career.ABIL.has(str(a[1])):
				players[ai].pop_ab(Career.ABIL[str(a[1])][0])
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
		"score": "%d - %d" % [score[0], score[1]], "online": net.role != "", "result": _result(), "stats": _stat_rows(), "club": opt_club, "gclub": guest_club, "own_ft": opt_own and _has_own(), "lclub": _lobby_club(), "gname": _guest_name(), "own_i": int(car_main.d["club"]) if _has_own() else -1, "clubs": CLUBS, "from": teams_from,
		"car": _car_info(), "pro": _pro_info(), "pro_new": _pro_new_info(), "pro_tile": _pro_tile(), "upd": upd_ready, "inst": app_inst, "own_new": own_new, "own_cols": OWN_COLS, "tab": hub_tab, "pstats": _rec(), "packs": car.packs() if car.has_save() else [], "pack": pack_res, "career": career_on or nat_on, "subs": _subs_info(), "mtac": _mtac_info(), "paused_by": paused_by, "can_sub": screen == "match" and state != "full" and pro_sq < 0 and not _subs_info().is_empty(), "car_lines": car_lines, "pxp": pro_bar, "co_text": _co_text() if net.role == "host" else co_text, "co_cup": opt_cup, "has_car": car.has_save(), "world": _world_info(), "start_li": start_li, "slen": opt_slen, "scout": _scout_info(),
		"rank": _rk_info(), "fr": fr, "fr_inv": fr_inv, "rk": rk_on, "start_kind": start_kind, "cup_ctry": cup_ctry, "new_sure": new_sure, "cupm": cup_mode, "cupc": _cupc_info(), "my": _my_info(), "car_on": carc.has_save() and carc.on(), "incar": in_career or assist, "assist": assist, "has_cv": carv.has_save() and net.role == "guest" and net.connected, "cv_pro": carv.has_save() and carv.pro(), "sug": sug_cur, "co_room": room if (net.role == "host" and in_career and opt_car) else "", "co_conn": net.connected, "co_rdy": co_rdy, "co_car": opt_car and in_career, "eur": car.eur, "has_cr": carc.has_save(), "cr": _cr_tile(),
		"g0": ",  ".join(PackedStringArray(tst[0].get("g", []))), "g1": ",  ".join(PackedStringArray(tst[1].get("g", []))),
	}

# the career's state for its tile on the Play tab
func _cr_tile() -> Dictionary:
	if not carc.has_save() or not carc.on():
		return {}
	var cc := ClubDB.clubs(CLUBS0)
	var me_c := int(carc.d["club"])
	var nm := str(carc.d["own"]["n"]) if carc.is_mine() else str(cc[me_c]["n"])
	return {"name": nm, "lg": carc.league_name(), "season": int(carc.d["season"]), "rank": carc.rank_of(me_c)}

# the cup mode's state for its tile on the Play tab
func _cupc_info() -> Dictionary:
	if not cupc.has_save():
		return {}
	var o: int = cupc.cup_opp()
	var cc := CLUBS if cup_mode else ClubDB.clubs(CLUBS0)
	var me_c := int(cupc.d["club"])
	var nm := str(cupc.d["own"]["n"]) if cupc.is_mine() else str(cc[me_c]["n"])
	return {"club": nm, "cname": cupc.cup_name(), "round": cupc.cup_round_name(), "opp": str(cc[o]["n"]) if o >= 0 else "", "won": bool(cupc.cup()["won"]), "out": bool(cupc.cup()["out"])}

# your own club, also while it waits
func _my_info() -> Dictionary:
	var mc := _my_club()
	if mc.is_empty():
		return {}
	var o: Dictionary = mc.get("own", {})
	return {"n": str(o.get("n", "MY CLUB")), "k": o.get("k", ["888888", "f4f4f4", "888888"]), "r": _avg_ovr(mc), "coins": int(mc.get("coins", 0)), "running": car_main.is_mine() and car_main.on()}

func _ab_rows(keys: Array) -> Array:
	var out := []
	for k in keys:
		out.append([k, Career.ABIL[k][0], Career.ABIL[k][1]])
	return out

# the skill picker: what this player's position can learn, and what it costs
func _ab_pick_info() -> Dictionary:
	if car_sel < 0 or car_sel >= (car.d["squad"] as Array).size():
		return {}
	var pl: Dictionary = car.d["squad"][car_sel]
	var have := Career.ab_of(pl)
	var opts := []
	for k in Career.ab_for(str(pl["pos"])):
		opts.append({"k": k, "n": Career.ABIL[k][0], "d": Career.ABIL[k][1], "has": have.has(k)})
	return {"slot": ab_slot, "n": str(pl["n"]).to_upper(), "pos": str(pl["pos"]), "price": car.ab_price(pl, ab_slot), "swap": ab_slot < have.size(),
		"cur": Career.ABIL[have[ab_slot]][0] if ab_slot < have.size() else "", "opts": opts}

# Your side in this match (the guest plays team 1 against the host; together you are both team 0).
# Your side's plan changed in the pause menu: it counts at once (and the computer manager leaves it alone).
func _tac_change(t: int, k: int, v: int) -> void:
	if t < 0 or t > 1 or k < 0 or k > 2:
		return
	v = clampi(v, 0, 4 if k == 0 else 2)
	if net.role == "guest":
		tac_t[t][k] = v
		net.send({"_": "tacq", "t": t, "k": k, "v": v})
		return
	tac_t[t][k] = v
	tac_base[t][k] = v
	if net.role == "host" and net.connected:
		net.send({"_": "tacd", "t": t, "v": tac_t[t]})

func _my_name() -> String:
	# against each other: the club that stopped it; on the same side: your team mate
	if _team_human(0) and _team_human(1):
		return str(TEAM_NAMES[_my_side()])
	return "your friend"

func _mtac_info() -> Dictionary:
	if screen != "match" or pro_sq >= 0 or teams[0].size() < 2:
		return {}
	var t := _my_side()
	if not _team_human(t):
		return {}
	var o: int = 1 - t
	var opp := ""
	if not _team_human(o):
		var md := str(tac_mood[o])
		opp = "%s: %s" % [str(TEAM_NAMES[o]).capitalize(), (str(MOOD_TXT[md][0]).to_lower() if md != "" else "playing their usual game")]
	return {"tac": tac_t[t], "opp": opp, "sub": "%s  %d - %d  %s   ·   %d'" % [str(TEAM_NAMES[0]), score[0], score[1], str(TEAM_NAMES[1]), int(clock / 60.0) + 1]}

func _my_side() -> int:
	for h in humans:
		if h.local:
			return h.team
	return 0

# The substitution screen: who is on the pitch and how tired, and who is on the bench. Every match has a bench.
func _subs_info() -> Dictionary:
	var t := _my_side()
	if teams[t].size() < 11 or (sub_bench[t] as Array).is_empty():
		return {}
	var on := []
	for p in teams[t]:
		on.append({"slot": p.idx, "n": p.pname.to_upper(), "num": p.num, "role": p.role, "ovr": p.ovr, "fit": p.fit, "off": p.off})
	var bench := []
	var bl: Array = sub_bench[t]
	for i in bl.size():
		if (sub_used[t] as Array).has(i):
			continue
		var pl: Dictionary = bl[i]
		bench.append({"sq": i, "n": str(pl["n"]).to_upper(), "num": int(pl["num"]), "pos": str(pl["pos"]), "ovr": Career.ovr_of(pl)})
	return {"left": int(sub_left2[t]), "on": on, "bench": bench, "sel": sub_sel}

# The benches for this match (host or alone): the career squad, your own club's squad, or five men of the club.
func _make_benches() -> void:
	sub_bench = [[], []]
	sub_left2 = [3, 3]
	sub_used = [[], []]
	for t in 2:
		var bl := []
		if career_on and t == 0:
			for i in (car.d["squad"] as Array).size():
				if not (car.d["xi"] as Array).has(i) and not (car.d["xi"] as Array).has(float(i)):
					var pl: Dictionary = (car.d["squad"][i] as Dictionary).duplicate()
					pl["sq"] = i
					bl.append(pl)
		elif (rk_on or ft_on) and (tov[t] as Dictionary).get("bench", []) is Array and not ((tov[t] as Dictionary).get("bench", []) as Array).is_empty():
			for e in (tov[t] as Dictionary)["bench"]:
				if e is Dictionary and e.has("n") and e.has("pos"):
					bl.append(e)
		else:
			bl = _gen_bench(t)
		sub_bench[t] = bl.slice(0, 9)

# five substitutes for a club without a squad: a keeper and one or two of each line, a little under the eleven
func _gen_bench(t: int) -> Array:
	if teams[t].size() < 11:
		return []
	var avg := 0.0
	var used := []
	var taken := []
	for p in teams[t]:
		avg += p.ovr
		used.append(p.num)
		taken.append(p.pname)
	avg /= teams[t].size()
	var rng := RandomNumberGenerator.new()
	rng.seed = clubs[t] * 7919 + 13
	var out := []
	var num := 12
	for role in ["GK", "DF", "MF", "MF", "FW"]:
		var base: Array = Career.ROLE_BASE[role]
		var q := int(round(avg)) - 72 - 3 + rng.randi_range(-2, 2)
		var nm: String = SURNAMES[rng.randi() % SURNAMES.size()]
		var tries := 0
		while taken.has(nm) and tries < 20:
			nm = SURNAMES[rng.randi() % SURNAMES.size()]
			tries += 1
		taken.append(nm)
		while used.has(num):
			num += 1
		used.append(num)
		out.append({"n": nm, "num": num, "pos": role, "pac": clampi(int(base[0]) + q, 30, 95), "sho": clampi(int(base[1]) + q, 25, 95),
			"pas": clampi(int(base[2]) + q, 30, 95), "dfn": clampi(int(base[3]) + q, 25, 95), "ab": []})
	return out

# The career's own bookkeeping still uses this (who played, who came off).
func _substitute(slot: int, b: int) -> void:
	var t := _my_side()
	if net.role == "guest":
		net.send({"_": "subq", "t": t, "slot": slot, "b": b})
		return
	_sub_do(t, slot, b)

# Bring a bench player on for the man in this place. He takes over the place with fresh legs.
func _sub_do(t: int, slot: int, b: int) -> void:
	if t < 0 or t > 1 or int(sub_left2[t]) <= 0 or slot < 0 or slot >= teams[t].size():
		return
	var bl: Array = sub_bench[t]
	if b < 0 or b >= bl.size() or (sub_used[t] as Array).has(b):
		return
	var p = teams[t][slot]
	if p.off:
		return
	var pl: Dictionary = bl[b]
	var old_name: String = p.pname
	(sub_used[t] as Array).append(b)
	var mo := 0
	if pl.has("sq") and career_on and t == 0:
		var sq_i := int(pl["sq"])
		sub_off.append(p.sq)
		if not sub_played.has(sq_i):
			sub_played.append(sq_i)
		p.sq = sq_i
		mo = car.mood_off(car.d["squad"][sq_i])
	var off_pos: int = Career.pos_off(car.d["squad"][int(pl["sq"])] if pl.has("sq") and career_on and t == 0 else pl, p.role) + mo
	p.pname = str(pl["n"])
	p.set_num(int(pl["num"]))
	p.pac = int(pl["pac"]) + off_pos
	p.sho = int(pl["sho"]) + off_pos
	p.pas = int(pl["pas"]) + off_pos
	p.dfn = int(pl["dfn"]) + off_pos
	p.ovr = Career.ovr_of(pl) + off_pos
	p.ab = Career.ab_of(pl) if pl.has("ab") else []
	_derive(p)
	p.fit = _start_fit(p)
	sub_left2[t] = int(sub_left2[t]) - 1
	subs_left = int(sub_left2[0])
	if net.role == "host":
		net.send({"_": "subd", "t": t, "slot": slot, "b": b})
	_sub_show(old_name, p.pname)

func _sub_show(old_name: String, new_name: String) -> void:
	snd("whistle_short")
	snd("clap", 0.7)
	fx("say", "Substitution. %s comes on for %s." % [new_name, old_name])
	hud.toast("%s ON  ·  %s OFF" % [new_name.to_upper(), old_name.to_upper()])
	if hud.menu_name == "subs":
		hud.refresh(_menu_info())

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
				now = "+%s from the gate at home" % car.money(lv * 9)
				nxt = "+%s from the gate at home" % car.money((lv + 1) * 9)
			"training":
				now = (txt[k][2] % ((lv - 1) * 15)) if lv > 1 else "Normal XP from matches"
				nxt = txt[k][2] % (lv * 15)
			_:
				now = txt[k][2] % (66 + lv * 4)
				nxt = txt[k][2] % (70 + lv * 4)
		out.append({"k": k, "n": txt[k][0], "what": txt[k][1], "lv": lv, "max": Career.FAC_MAX, "now": now, "next": nxt if lv < Career.FAC_MAX else "",
			"cost": car.fac_build_cost(k) if car.eur else car.fac_cost(k), "need": car.fac_need(k)})
	return out

# Everything the career screens show.
# the player career for the hud: you, your stats, the manager's trust, your season
func _pro_info() -> Dictionary:
	if not car.has_save() or not car.pro():
		return {}
	# on the friend's phone "my player" is his own man
	var pk := "pro2" if assist else "pro"
	if assist and not car.pro2():
		return {"need2": true, "pos2": str(pro_new.get("pos", "MF")), "n2": str(pro_new.get("n", ""))}
	var pl: Dictionary = car.pro_pl(pk)
	if pl.is_empty():
		return {}
	var p: Dictionary = car.pro_d(pk)
	var of := int(p.get("offer", -1))
	var hist := []
	for h9 in p.get("hist", []):
		hist.append({"season": int(h9[0]), "club": str(CLUBS[int(h9[1])]["n"]).capitalize(), "apps": int(h9[2]), "g": int(h9[3]), "a": int(h9[4]), "avg": float(h9[5])})
	return {"n": str(pl["n"]), "pos": str(pl["pos"]), "age": int(pl["age"]), "ovr": Career.ovr_of(pl), "pot": int(pl["pot"]), "tp": int(pl.get("tp", 0)),
		"st": [int(pl["pac"]), int(pl["sho"]), int(pl["pas"]), int(pl["dfn"])], "trust": int(p["trust"]), "next": "start" if car.pro_starts(pk) else "bench",
		"ss": p["ss"], "all": p["all"], "avg": car.pro_avg(true, pk), "avg_all": car.pro_avg(false, pk), "rt": p.get("rt", []), "obj": car.pro_obj(pk), "pxp": int(p.get("pxp", 0)),
		"together": car.pro2(), "mate": str(car.pro_pl("pro2" if pk == "pro" else "pro").get("n", "")).capitalize(),
		"lv": car.pro_lv(pk), "need": car.pro_need(pk), "drill": car.pro_drill(pk), "dp": car.pro_dp(pk), "ab": Career.ab_of(pl).map(func(a): return str(Career.ABIL[a][0]).capitalize()),
		"cost": [Career.pro_cost(int(pl["pac"])), Career.pro_cost(int(pl["sho"])), Career.pro_cost(int(pl["pas"])), Career.pro_cost(int(pl["dfn"]))], "top": Career.ovr_of(pl) >= int(pl["pot"]),
		"abl": _pro_ab_list(pl),
		"offer": str(CLUBS[of]["n"]).capitalize() if of >= 0 else "", "hist": hist, "fm": Career.pform(pl), "cond": car.cond_of(pl), "inj": car.injured(pl),
		"club": str(CLUBS[int(car.d["club"])]["n"]).capitalize(), "kit": CLUBS[int(car.d["club"])]["k"], "msg": car_msg}

# the skills your player can buy with points
func _pro_ab_list(pl: Dictionary) -> Array:
	var have := Career.ab_of(pl)
	var out := []
	var cost: int = Career.PRO_AB_PTS[mini(have.size(), 1)]
	for k in Career.ab_for(str(pl["pos"])):
		var why := ""
		if have.has(k):
			why = "yours"
		elif have.size() >= 2:
			why = "full"
		elif have.size() == 1 and Career.ovr_of(pl) < Career.AB_SLOT2:
			why = "rating %d" % Career.AB_SLOT2
		out.append({"k": k, "n": str(Career.ABIL[k][0]).capitalize(), "t": str(Career.ABIL[k][1]), "cost": cost, "why": why, "ok": why == "" and int(pl.get("tp", 0)) >= cost})
	return out

func _pro_new_info() -> Dictionary:
	if (pro_new.get("pick", []) as Array).is_empty():
		return {}
	var picks := []
	for c in pro_new.get("pick", []):
		picks.append({"c": int(c), "n": str(CLUBS[int(c)]["n"]).capitalize(), "k": CLUBS[int(c)]["k"], "lg": str(ClubDB.LEAGUES[int(CLUBS[int(c)]["lg"])]["n"]).capitalize(), "r": int(CLUBS[int(c)].get("r", 0))})
	return {"pos": str(pro_new["pos"]), "c": int(pro_new["c"]), "picks": picks, "n": str(pro_new.get("n", ""))}

func _pro_tile() -> String:
	if not proc.has_save() or not proc.pro():
		return "Be one player. Earn your place."
	var pl: Dictionary = proc.pro_pl()
	return "%s  ·  %s %d" % [str(pl.get("n", "")).capitalize(), str(pl.get("pos", "")), Career.ovr_of(pl)] if not pl.is_empty() else ""

func _car_info() -> Dictionary:
	if not car.has_save():
		return {}
	car.money_init()
	var d: Dictionary = car.d
	var me_c: int = int(d["club"])
	var nm: Array = car.next_match()
	var rows := []
	var ord: Array = car.order()
	for i in ord.size():
		var c: int = ord[i]
		var t: Dictionary = d["table"][str(c)]
		rows.append([i + 1, CLUBS[c]["n"], int(t["p"]), int(t["w"]), int(t["d"]), int(t["l"]), int(t["gf"]) - int(t["ga"]), int(t["pts"]), c == me_c, CLUBS[c]["k"][0], str(t.get("fm", ""))])
	var last := []
	for r in d["last"]:
		last.append("%s  %d - %d  %s" % [CLUBS[int(r[0])]["s"], int(r[2]), int(r[3]), CLUBS[int(r[1])]["s"]])
	var squad := []
	var ro_all: Dictionary = car.roles() if car.eur else {}
	for i in (d["squad"] as Array).size():
		var pl: Dictionary = d["squad"][i]
		squad.append({"n": str(pl["n"]).to_upper(), "num": int(pl["num"]), "pos": str(pl["pos"]), "ovr": Career.ovr_of(pl), "pot": int(pl["pot"]), "age": int(pl["age"]),
			"xp": int(pl["xp"]), "tp": int(pl.get("tp", 0)), "g": int(pl["g"]), "apps": int(pl["apps"]), "st": [int(pl["pac"]), int(pl["sho"]), int(pl["pas"]), int(pl["dfn"])], "cost": car.train_cost(pl), "sell": Career.sell_value(pl), "tl": Career.listed(pl), "fm": Career.pform(pl),
			"ab": _ab_rows(Career.ab_of(pl)), "ab_cost": [car.ab_price(pl, 0), car.ab_price(pl, 1)], "ab_lock2": Career.ovr_of(pl) < Career.AB_SLOT2,
			"wk": int(pl.get("wk", 0)), "ct": int(pl.get("ct", 0)), "mo": int(pl.get("mo", 65)), "role": int(ro_all.get(i, 2)), "tf": str(pl.get("tf", "")), "tr": pl.has("tr"), "pos2": Career.pos2_of(pl), "rt": str(pl.get("rt", "")), "rtp": int(Career.rt_prog(pl, str(pl.get("rt", "")))), "rto": Career.rt_options(pl).size() > 1,
			"cond": car.cond_of(pl) if car.eur else -1, "inj": car.injured(pl) if car.eur else false, "injt": car.inj_text(pl) if car.eur and car.injured(pl) else ""})
	# where each man of the eleven plays now, and what it costs him when that is not his own place
	var sr0: Array = car.slot_roles()
	for k0 in mini((d["xi"] as Array).size(), sr0.size()):
		var xi0 := int(d["xi"][k0])
		if xi0 < squad.size():
			squad[xi0]["sr"] = str(sr0[k0])
			squad[xi0]["po"] = Career.pos_off(d["squad"][xi0], str(sr0[k0]))
	var tp_all := 0
	for pl in d["squad"]:
		tp_all += int(pl.get("tp", 0))
	var mk := []
	for pl in car.market():
		mk.append({"n": str(pl["n"]).to_upper(), "pos": str(pl["pos"]), "ovr": Career.ovr_of(pl), "pot": int(pl["pot"]), "age": int(pl["age"]), "st": [int(pl["pac"]), int(pl["sho"]), int(pl["pas"]), int(pl["dfn"])], "price": Career.value(pl), "wk": Career.wage_of(pl), "no": car.refuses(pl, -1, true)})
	var roles := _my_form(car.form(), car.lay())
	return {
		"name": CLUBS[me_c]["n"], "kit": CLUBS[me_c]["k"], "season": int(d["season"]), "round": int(d["round"]), "rounds": car.rounds_total(), "coins": int(d["coins"]),
		"rank": car.rank_of(me_c), "opp": CLUBS[nm[0]]["n"] if nm[0] >= 0 else "", "opp_rank": car.rank_of(nm[0]) if nm[0] >= 0 else 0, "opp_kit": CLUBS[nm[0]]["k"] if nm[0] >= 0 else [], "derby": car._next_derby() if car.d.has("leagues") else false, "rival": str(CLUBS[car.rival_of(me_c)]["n"]) if car.d.has("leagues") and car.rival_of(me_c) >= 0 else "", "drb": car.derby_rec(),
		"home": nm[1], "over": car.season_over(), "note": str(d.get("note", "")), "last": last, "table": rows, "squad": squad, "xi": d["xi"], "sel": car_sel,
		"div": car.div(), "lgname": car.league_name(), "n": car.ids().size(), "up": int(car.league()["up"]), "down": int(car.league()["down"]), "slen": str(d.get("slen", "full")), "cup": _cup_info(),
		"fac": _fac_info(), "tp": tp_all, "market": mk, "sell_sure": car_sell, "form": roles, "fname": car.form(), "moved": not car.lay().is_empty(), "str": int(round(car.my_strength())), "msg": car_msg, "sure": car_sure,
		"ab_pick": _ab_pick_info(), "board": _board_info(), "cup_due": car.cup_due(), "cup_after": car.cup_after(), "mode": car.mode(),
		"sacked": car.d.has("sacked"), "on": car.on(),
		"eur": car.eur, "wg": car.wages_on(), "wages": car.wages() if car.eur else 0, "wb": car.wb() if car.eur else 0, "talk": car.talk(), "talk_rc": [0, car.clause_of_talk({"rc": 1, "ovr": int(car.talk().get("ovr", 60)), "pot": int(car.talk().get("pot", 60)), "age": int(car.talk().get("age", 25))}), car.clause_of_talk({"rc": 2, "ovr": int(car.talk().get("ovr", 60)), "pot": int(car.talk().get("pot", 60)), "age": int(car.talk().get("age", 25))})], "fbuild": car.d.get("fbuild", {}), "conf": car.conf(), "plan": car.plan(),
		"club_n": CLUBS[int(car.talk().get("from", -1))]["n"] if int(car.talk().get("from", -1)) >= 0 else "",
		"cal": _cal_info(), "today": car.today(), "tdate": [int(car.date_of(car.today())["y"]), int(car.date_of(car.today())["m"]), int(car.date_of(car.today())["d"])], "nday": car.next_day(), "ndate": car.date_text(car.next_day()) if car.next_day() >= 0 else "", "cdate": car.date_text(car.now(), true), "dleft": maxi(car.next_day() - car.now(), 0) if car.next_day() >= 0 and not bool(car.d.get("cupmode", false)) else 0,
		"tac": car.tac(), "otac": car.cpu_tac(car._next_opp()) if car.d.has("leagues") else [2, 1, 1], "cdiff": int(car.d.get("diff", 1)), "clen": int(car.d.get("len", 1)), "cal_m": cal_m, "sim": sim_res, "adv": adv_info, "yth": _youth_info(), "live": _live_info(), "hon": _hon_info(), "eu_due": car.eu_due(), "eu": _eu_info(), "nat_due": car.nat_due(), "natm": _natm_info(), "natp": _nat_info(),
	}

# The Champions Cup for the hud: your next European match, the groups and the knockout rounds.
func _eu_info() -> Dictionary:
	var e: Dictionary = car.eu()
	if e.is_empty() or bool(car.d.get("cupmode", false)):
		return {}
	var me_c := int(car.d["club"])
	var out := {"name": car.eu_name(), "k": car.eu_k(), "md": int(e["md"]), "out": bool(e.get("out", false)), "done": bool(e.get("done", false)), "won": bool(e.get("won", false)),
		"win": str(CLUBS[int(e["win"])]["n"]).capitalize() if int(e.get("win", -1)) >= 0 else "", "gl": str(e.get("gl", "A")), "rname": car.eu_round_name() if not bool(e.get("done", false)) else "",
		"day": car.date_text(car.eu_day(mini(int(e["md"]), 9)), true)}
	if car.eu_due_ever():
		var eo: Array = car.eu_opp()
		var oc := int(eo[0])
		if oc >= 0:
			out["opp"] = CLUBS[oc]["n"]
			out["opp_kit"] = CLUBS[oc]["k"]
			out["home"] = bool(eo[1])
			out["opp_lg"] = car._eu_country(oc)
	var groups := []
	for g in 8:
		var rows := []
		for c in car.eu_group(g):
			var r: Array = e["gt"][str(c)]
			rows.append([str(CLUBS[int(c)]["n"]).capitalize(), int(r[0]), int(r[4]) - int(r[5]), int(r[6]), int(c) == me_c, CLUBS[int(c)]["k"]])
		groups.append(rows)
	var rounds := []
	var lg_e: Array = e.get("log", [])
	for md in range(6, lg_e.size()):
		var ties := []
		for t in lg_e[md]:
			ties.append([str(CLUBS[int(t[0])]["n"]).capitalize(), str(CLUBS[int(t[1])]["n"]).capitalize(), int(t[2]), int(t[3]), int(t[0]) == me_c or int(t[1]) == me_c])
		rounds.append({"name": Career.EU_RD[md], "ties": ties})
	if int(e["md"]) >= 6 and not bool(e.get("done", false)):
		var ties2 := []
		for t in e.get("ko", []):
			ties2.append([str(CLUBS[int(t[0])]["n"]).capitalize(), str(CLUBS[int(t[1])]["n"]).capitalize(), -1, -1, int(t[0]) == me_c or int(t[1]) == me_c])
		rounds.append({"name": Career.EU_RD[int(e["md"])], "ties": ties2, "now": true})
	out["groups"] = groups
	out["rounds"] = rounds
	return out

# Top scorers, awards, the trophy cabinet and the club's records for the hud.
func _hon_info() -> Dictionary:
	if bool(car.d.get("cupmode", false)) or not car.d.has("leagues"):
		return {}
	var me_c := int(car.d["club"])
	var top := []
	for x in car.scorers_top(20):
		top.append({"g": int(x[0]), "n": str(x[2]).capitalize(), "pos": str(x[3]), "club": str(CLUBS[int(x[1])]["n"]).capitalize(), "k": CLUBS[int(x[1])]["k"], "mine": int(x[1]) == me_c})
	var aw := []
	for a in car.awards():
		var c := int(a["c"])
		aw.append({"t": str(a["t"]), "who": (str(a["n"]).capitalize() + "  ·  " if str(a["n"]) != "" else "") + str(CLUBS[c]["n"]).capitalize(), "v": str(a["v"]), "mine": c == me_c, "k": str(a["k"]), "kit": CLUBS[c]["k"]})
	var cab := []
	var cnt := {}
	for h in car.cabinet():
		cab.append({"s": int(h[0]), "k": str(h[1]), "t": str(h[2])})
		cnt[str(h[1])] = int(cnt.get(str(h[1]), 0)) + 1
	var r: Dictionary = car.records()
	var rec := []
	var put := func(lbl: String, key: String, f: Callable):
		rec.append([lbl, f.call(r[key]) if r.has(key) else "None yet"])
	put.call("Biggest win", "bw", func(v): return str(v[1]))
	put.call("Heaviest defeat", "bl", func(v): return str(v[1]))
	put.call("Longest unbeaten run", "unb", func(v): return str(v[1]))
	put.call("Most goals in a season", "sg", func(v): return "%s, %d (season %d)" % [str(v[1]).capitalize(), int(v[0]), int(v[2])])
	put.call("Most goals for the club", "cg", func(v): return "%s, %d" % [str(v[1]).capitalize(), int(v[0])])
	put.call("Most matches for the club", "ca", func(v): return "%s, %d" % [str(v[1]).capitalize(), int(v[0])])
	put.call("Record signing", "buy", func(v): return "%s, %s (season %d)" % [str(v[1]).capitalize(), car.money(int(v[0])), int(v[2])])
	put.call("Record sale", "sell", func(v): return "%s, %s (season %d)" % [str(v[1]).capitalize(), car.money(int(v[0])), int(v[2])])
	put.call("Best finish", "bf", func(v): return str(v[2]))
	put.call("Most points in a season", "pts", func(v): return "%d, %s" % [int(v[0]), str(v[1])])
	return {"top": top, "aw": aw, "cab": cab, "cnt": cnt, "rec": rec, "tab": cab_tab, "season": int(car.d.get("season", 1))}

# The living world for the hud: the transfer window, your inbox and the deals between the clubs.
func _live_info() -> Dictionary:
	if bool(car.d.get("cupmode", false)) or not car.d.has("leagues"):
		return {}
	var ib := []
	for m in car.inbox():
		var e: Dictionary = (m as Dictionary).duplicate()
		e["date"] = car.date_text(int(m["day"]))
		if str(m["k"]) == "bid":
			var i: int = car._sq_find(str(m["pn"]))
			e["cn"] = str(CLUBS[int(m["c"])]["n"]).capitalize()
			e["ck"] = CLUBS[int(m["c"])]["k"]
			e["amt_t"] = car.money(int(m["amt"]))
			if i >= 0:
				var pl: Dictionary = car.d["squad"][i]
				e["val_t"] = car.money(Career.value(pl))
				e["ovr"] = Career.ovr_of(pl)
				e["pos"] = str(pl["pos"])
				e["xi"] = (car.d["xi"] as Array).has(i)
		ib.append(e)
	var dl := []
	for x in car.deals():
		dl.append({"date": car.date_text(int(x[0])), "n": str(x[1]).capitalize(), "pos": str(x[2]), "ovr": int(x[3]), "age": int(x[4]),
			"from": str(CLUBS[int(x[5])]["n"]).capitalize(), "to": str(CLUBS[int(x[6])]["n"]).capitalize(), "kt": CLUBS[int(x[6])]["k"], "fee": car.money(int(x[7])),
			"near": car.ids().has(int(x[5])) or car.ids().has(int(x[6]))})
	return {"win": car.window(), "won": car.windows_on(), "inbox": ib, "unread": car.unread(), "sel": mail_sel, "deals": dl}

# In the career your men start a match as fit as they are (tired legs are slower); everyone else is fresh.
func _start_fit(p) -> float:
	if career_on and car.eur and p.team == 0 and p.sq >= 0 and p.sq < (car.d["squad"] as Array).size() and net.role != "guest":
		return clampf(car.cond_of(car.d["squad"][p.sq]) / 100.0, 0.45, 1.0)
	return 1.0

# Scouting and the academy for the hud.
func _youth_info() -> Dictionary:
	if bool(car.d.get("cupmode", false)):
		return {}
	var sc := []
	for x in car.scouts():
		var e: Dictionary = x
		if e.is_empty():
			sc.append({})
		else:
			sc.append({"n": str(e["n"]), "st": int(e["st"]), "away": int(e.get("left", 0)), "rg": str(Career.REGIONS[int(e["rg"])][0]) if int(e.get("rg", -1)) >= 0 else "",
				"pick": str(Career.REGIONS[int(e.get("pick", 0))][0])})
	var row := func(pl: Dictionary) -> Dictionary:
		return {"n": str(pl["n"]).capitalize(), "age": int(pl["age"]), "pos": str(pl["pos"]), "olo": int(pl["olo"]), "ohi": int(pl["ohi"]), "plo": int(pl["plo"]), "phi": int(pl["phi"]),
			"rg": str(Career.REGIONS[clampi(int(pl.get("rg", 0)), 0, Career.REGIONS.size() - 1)][0]), "fee": int(pl.get("fee", 0)), "exp": int(pl.get("exp", 0)), "ab": _ab_rows(Career.ab_of(pl)), "known": bool(pl.get("known", false))}
	var pr := []
	for pl in car.prospects():
		pr.append(row.call(pl))
	var ac := []
	for pl in car.academy():
		ac.append(row.call(pl))
	var hire := []
	for x in car.scouts():
		hire.append(car.scout_cost(1 if (x as Dictionary).is_empty() else int(x["st"]) + 1))
	return {"scouts": sc, "pros": pr, "acad": ac, "tab": y_tab, "hire": hire, "amax": Career.ACAD_MAX, "sq": (car.d["squad"] as Array).size(), "sqmax": Career.SQUAD_MAX, "yf": car.fac("youth")}

# The season's calendar for the hud: every match with its date, opponent and result.
func _cal_info() -> Array:
	if bool(car.d.get("cupmode", false)) or not car.d.has("fix"):
		return []
	if not car.d.has("day") and int(car.d.get("round", 0)) > 0:
		# a career from before the calendar: today is the last round played
		car.d["day"] = car.lg_day(int(car.d["round"]) - 1)
	var out := []
	for e in car.calendar():
		var o := int(e["opp"])
		var dt: Dictionary = car.date_of(int(e["day"]))
		if str(e["kind"]) == "nat":
			out.append({"day": int(e["day"]), "y": int(dt["y"]), "m": int(dt["m"]), "d": int(dt["d"]), "wd": int(dt["wd"]), "kind": "nat", "name": str(e["name"]),
				"opp": Career.nat_name(o) if o >= 0 else "", "os": str(Career.NATIONS[o][1]) if o >= 0 else "?", "ok": Career.nat_kit(o) if o >= 0 else ["888888"], "home": bool(e["home"]),
				"res": e["res"], "played": bool(e["played"]), "next": bool(e["next"]), "date": car.date_text(int(e["day"]))})
			continue
		out.append({"day": int(e["day"]), "y": int(dt["y"]), "m": int(dt["m"]), "d": int(dt["d"]), "wd": int(dt["wd"]), "kind": str(e["kind"]), "name": str(e["name"]),
			"opp": CLUBS[o]["n"] if o >= 0 else "", "os": CLUBS[o]["s"] if o >= 0 else "?", "ok": CLUBS[o]["k"] if o >= 0 else ["888888"], "home": bool(e["home"]),
			"res": e["res"], "played": bool(e["played"]), "next": bool(e["next"]), "date": car.date_text(int(e["day"]))})
	return out

func _board_info() -> Dictionary:
	var b: Dictionary = car.board()
	var objs := []
	for o in b["obj"]:
		var st: Array = car.obj_state(o)
		objs.append({"t": str(o["t"]), "now": str(st[0]), "st": str(st[1])})
	var rv: Dictionary = car.review()
	var offers := []
	for of in car.offers():
		var oc := int(of[0])
		offers.append({"n": CLUBS[oc]["n"], "k": CLUBS[oc]["k"], "lgname": car.league_name(int(of[1])), "lv": car.rating(oc)})
	var hist := []
	for hh in b.get("hist", []):
		hist.append({"s": int(hh["s"]), "div": int(hh["div"]), "pos": int(hh["pos"]), "g": str(hh["g"])})
	return {"conf": car.conf(), "mood": Career.mood_of(car.conf()), "chg": int(b.get("chg", 0)), "msg": str(b.get("msg", "")), "obj": objs, "ex": int(b.get("ex", 0)),
		"review": rv, "offers": offers, "hist": hist, "bonus": car.conf() >= 80, "full": car.full(), "sack_at": Career.SACK_AT}

# Every league and its clubs, strongest first: for the new-career screens and the scout.
func _world_info() -> Array:
	# a new start begins from the leagues as they are at the start of the game
	var lgs: Array = car.d["leagues"] if car.has_save() and car.d.has("leagues") and start_kind == "" else ClubDB.start_leagues(Career.FIRST)
	var cc0: Array = CLUBS if start_kind == "" else ClubDB.clubs(CLUBS0)
	var out := []
	for li in ClubDB.LEAGUES.size():
		var cl := []
		for c in lgs[li]:
			cl.append({"i": int(c), "n": cc0[int(c)]["n"], "k": cc0[int(c)]["k"], "r": car.rating(int(c)), "me": car.has_save() and int(c) == int(car.d.get("club", -1))})
		cl.sort_custom(func(a, b): return int(a["r"]) > int(b["r"]))
		var L: Dictionary = ClubDB.LEAGUES[li]
		out.append({"n": L["n"], "c": L["c"], "t": int(L["t"]), "clubs": cl, "up": int(L["up"]), "down": int(L["down"])})
	return out

func _scout_info() -> Dictionary:
	if not car.has_save() or scout_li < 0:
		return {}
	var sq := []
	if scout_c >= 0:
		var cs: Array = car.cpu_squad(scout_c)
		for i in cs.size():
			var pl: Dictionary = cs[i]
			sq.append({"n": str(pl["n"]).to_upper(), "pos": str(pl["pos"]), "age": int(pl["age"]), "ovr": Career.ovr_of(pl), "pot": int(pl["pot"]),
				"st": [int(pl["pac"]), int(pl["sho"]), int(pl["pas"]), int(pl["dfn"])], "ask": car.ask_price(scout_c, i), "ab": _ab_rows(Career.ab_of(pl)), "rc": car.cpu_clause(scout_c, i), "no": car.refuses(pl, scout_c, true)})
	return {"li": scout_li, "c": scout_c, "i": scout_i, "cn": CLUBS[scout_c]["n"] if scout_c >= 0 else "", "ck": CLUBS[scout_c]["k"] if scout_c >= 0 else [],
		"cr": car.rating(scout_c) if scout_c >= 0 else 0, "clg": car.league_name(car.league_of(scout_c)) if scout_c >= 0 else "", "sq": sq, "res": scout_res, "sw": _swap_info()}

# the swap row on a scouted player: your man, what he is worth to them, and the cash on top
func _swap_info() -> Dictionary:
	if scout_c < 0 or scout_i < 0 or not car.d.has("squad") or (car.d["squad"] as Array).is_empty():
		return {}
	var nsq: int = (car.d["squad"] as Array).size()
	scout_sw = clampi(scout_sw, 0, nsq - 1)
	var pl: Dictionary = car.d["squad"][scout_sw]
	var wv: int = car.swap_worth(scout_c, scout_i, scout_sw)
	var ask: int = car.ask_price(scout_c, scout_i)
	return {"n": str(pl["n"]).capitalize(), "pos": str(pl["pos"]), "ovr": Career.ovr_of(pl), "worth": wv, "cash": maxi(0, ask - wv), "ok": wv > 0, "key": str(pl["n"]),
		"worth_t": car.money(wv), "cash_t": car.money(maxi(0, ask - wv))}

func _cup_info() -> Dictionary:
	var cp: Dictionary = car.cup()
	var me_c: int = int(car.d["club"])
	var nm: Array = car.cup_names()
	# each round: your own tie first, then a few of the others
	var rounds := []
	var logs: Array = cp["log"]
	for ri in logs.size():
		var rr := []
		for x in logs[ri]:
			var mine: bool = int(x[0]) == me_c or int(x[1]) == me_c
			var row := [CLUBS[int(x[0])]["n"], CLUBS[int(x[1])]["n"], int(x[2]), int(x[3]), mine]
			if mine:
				rr.push_front(row)
			elif rr.size() < 6:
				rr.append(row)
		rounds.append({"name": str(nm[clampi(ri, 0, nm.size() - 1)]), "ties": rr, "n": (logs[ri] as Array).size()})
	if not car.cup_over():
		var t: Array = cp["teams"]
		var rr2 := []
		for i in range(0, t.size() - 1, 2):
			var mine2: bool = int(t[i]) == me_c or int(t[i + 1]) == me_c
			var row2 := [CLUBS[int(t[i])]["n"], CLUBS[int(t[i + 1])]["n"], -1, -1, mine2]
			if mine2:
				rr2.push_front(row2)
			elif rr2.size() < 6:
				rr2.append(row2)
		rounds.append({"name": car.cup_round_name(), "ties": rr2, "n": t.size() / 2, "now": true})
	var opp: int = car.cup_opp()
	return {"r": int(cp["r"]), "name": car.cup_round_name(), "out": bool(cp["out"]), "won": bool(cp["won"]), "rounds": rounds,
		"opp": CLUBS[opp]["n"] if opp >= 0 else "", "opp_kit": CLUBS[opp]["k"] if opp >= 0 else [], "opp_rank": car.rank_of(opp) if opp >= 0 else 0,
		"opp_lg": car.league_name(car.league_of(opp)) if opp >= 0 else "", "cname": car.cup_name(), "left": (cp["teams"] as Array).size() + (cp.get("byes", []) as Array).size(), "total": nm.size(), "cups": int(car.stats().get("cups", 0))}

func _stat_rows() -> Array:
	var tot: int = maxi(tst[0]["poss"] + tst[1]["poss"], 1)
	var p0 := int(round(100.0 * tst[0]["poss"] / tot))
	return [
		["POSSESSION", "%d%%" % p0, "%d%%" % (100 - p0)],
		["SHOTS", str(int(tst[0]["shots"])), str(int(tst[1]["shots"]))],
		["SAVES", str(int(tst[0]["saves"])), str(int(tst[1]["saves"]))],
		["FOULS", str(int(tst[0]["fouls"])), str(int(tst[1]["fouls"]))],
	]

func _result() -> String:
	var w := _winner()
	if w < 0:
		return "DRAW"
	var t: int = humans[me].team if humans.size() > me else 0
	var both: bool = humans.size() > 1 and humans[0].team == humans[1].team
	var pens := ("  %d - %d ON PENALTIES" % [so_g[0], so_g[1]]) if score[0] == score[1] else ""
	if w == t:
		return ("YOU WIN TOGETHER!" if both else "YOU WIN!") + pens
	return "YOU LOSE" + pens

func _to_menu(keep_net := false) -> void:
	pro_sq = -1
	pro_sq2 = -1
	if rk_on and screen == "match" and state != "full" and rk_res.is_empty():
		rk.match_result(int(rk_opp.get("rp", 0)), 0.0, -3, 0)
		hud.toast("You left a ranked match: it counts as a loss")
	rk_looking = false
	if rk_on:
		rk_on = false
		tov = [{}, {}]
		_apply_own()
	_ft_off()
	if not keep_net:
		net.stop()
		room = ""
		co_rdy = [false, false]
	career_on = false
	cup_on = false
	eu_on = false
	nat_on = false
	Engine.time_scale = 1.0
	paused = false
	screen = "menu"
	humans = []
	me = 0
	view_flip = 1.0
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
	if not keep_net:
		_show_hub()

# Your own club: its name and kit take the place of the club you started as.
func _apply_own() -> void:
	_apply_own0()
	# the friend's phone: the host's own club looks the same here
	if carv != null and car != carv and net.role == "guest" and carv.has_save():
		# Playing in the host's career, this phone's own club must not sit in the host's world: it took the place
		# of a real club here, and that club may be the very opponent (Daniel's dad saw another team).
		if car.has_save() and car.d.has("own"):
			var mi := int(car.d["club"])
			var base: Array = ClubDB.clubs(CLUBS0)
			if mi >= 0 and mi < base.size():
				CLUBS[mi] = base[mi]
	if carv != null and car != carv and net.role == "guest" and carv.has_save() and carv.d.has("own"):
		var o: Dictionary = carv.d["own"]
		var k: Array = o["k"]
		var alt := "1c1c20" if Color(str(k[0])).get_luminance() > 0.6 else "f4f4f4"
		var ci := int(carv.d["club"])
		if ci >= 0 and ci < CLUBS.size():
			CLUBS[ci] = {"n": str(o["n"]), "s": str(o["s"]), "k": [str(k[0]), str(k[1]), str(k[2])], "a": [alt, str(k[0]), alt]}

func _apply_own0() -> void:
	CLUBS = ClubDB.clubs(CLUBS0)
	# two more places at the end for the ranked teams
	RKI = CLUBS.size()
	for t in 2:
		CLUBS.append(_rk_club(tov[t]) if not (tov[t] as Dictionary).is_empty() else (CLUBS[t] as Dictionary).duplicate(true))
	if car.has_save() and car.d.has("mig"):
		# an old save: the club it played as comes with it into the new world
		if not car.d.has("own"):
			var oc: Dictionary = CLUBS0[clampi(int(car.d["mig"]), 0, CLUBS0.size() - 1)]
			car.d["own"] = {"n": oc["n"], "s": oc["s"], "k": (oc["k"] as Array).duplicate()}
		car.d.erase("mig")
		car.save()
	if not car.has_save() or not car.d.has("own"):
		return
	var o: Dictionary = car.d["own"]
	var k: Array = o["k"]
	var light: bool = Color(str(k[0])).get_luminance() > 0.6
	var alt := "1c1c20" if light else "f4f4f4"
	CLUBS[int(car.d["club"])] = {"n": str(o["n"]), "s": str(o["s"]), "k": [str(k[0]), str(k[1]), str(k[2])], "a": [alt, str(k[0]), alt]}

# Your own club, wherever it is: the club you run now, or the one waiting while you run another.
func _my_club() -> Dictionary:
	return car_main.my_club()

func _avg_ovr(dd: Dictionary) -> int:
	if dd.is_empty():
		return 0
	var t := 0
	var n := 0
	for x in dd["xi"]:
		t += Career.ovr_of(dd["squad"][int(x)])
		n += 1
	return int(round(float(t) / maxf(n, 1)))

# A career with your own club: its players and kit go in, in the league you picked, with the career's own money.
func _start_mine() -> void:
	var base := _my_club()
	if base.is_empty():
		start_kind = "new"
		_action("st_club", -1)
		return
	carc.start_mine(start_li, opt_slen, base)
	start_kind = ""
	_cr_enter(false)
	_own_changed()
	hud.show_menu("cmode", _menu_info())

# ---- the career mode: a place of its own. You are in it until you leave it yourself.
# Saves from before: the running career moves into the career mode, your own club stays outside.
func _split_career() -> void:
	if not car_main.has_save() or not car_main.on() or carc.has_save():
		return
	carc.d = car_main.d.duplicate(true)
	carc._ints()
	carc.save()
	var st: Dictionary = car_main.stash_get()
	if not st.is_empty():
		car_main.d = st
		car_main._ints()
	elif not car_main.is_mine():
		car_main.new_club()
		car_main.d["own"] = {"n": "MY CLUB", "s": "MYC", "k": ["dc2424", "f4f4f4", "dc2424"]}
	car_main.d["on"] = false
	car_main.d["mode"] = "simple"
	car_main.stash_clear()
	car_main.save()

func _incar_save() -> void:
	if net.web:
		JavaScriptBridge.eval("try{localStorage.setItem('bb3d-incar','%s')}catch(e){}" % ("1" if in_career else "0"), true)

func _cr_enter(show := true) -> void:
	if cup_mode:
		_cm_leave()
	if not in_career:
		q_opt = [opt_diff, opt_len]
	in_career = true
	car = carc
	_incar_save()
	_apply_own()
	hub_tab = "career"
	car_sel = -1
	car_sell = -1
	car_msg = ""
	car_sure = false
	if show:
		_show_hub()

# Into the player career: the same career screens, as one player at a club.
func _pro_enter(show := true) -> void:
	if cup_mode:
		_cm_leave()
	if not in_career:
		q_opt = [opt_diff, opt_len]
	in_career = true
	car = proc
	car.pro_select("pro")
	if car.pro2():
		car.pro_select("pro2")
	_apply_own()
	hub_tab = "career"
	car_sel = -1
	car_msg = ""
	if show:
		_show_hub()

# a few clubs to choose from for a new player career: lower and middle clubs in both countries
func _pro_picks() -> Array:
	var lgs: Array = ClubDB.start_leagues(Career.FIRST)
	var out := []
	for li in [3, 5, 3, 2, 5, 4]:
		if li < lgs.size():
			var ids: Array = (lgs[li] as Array).duplicate()
			ids.shuffle()
			out.append(int(ids[0]))
	return out

func _cr_exit() -> void:
	if in_career:
		opt_diff = int(q_opt[0])
		opt_len = int(q_opt[1])
	in_career = false
	car = car_main
	_incar_save()
	_apply_own()
	hub_tab = "play"
	car_msg = ""
	_show_hub()

# ---- the cup mode: a cup on its own, with any club in England or Denmark, or your own
func _cup_start(c: int) -> void:
	cupc.new_career(c, false)
	cupc.d["cupmode"] = true
	cupc.d["mode"] = "simple"
	cupc.save()
	_cm_enter()

func _cup_start_mine(ctry: String) -> void:
	var mc := _my_club()
	if mc.is_empty():
		return
	var li := 3 if ctry == "ENGLAND" else 5
	cupc.new_career(cupc.weakest(li), true)
	cupc.d["own"] = (mc["own"] as Dictionary).duplicate(true) if mc.has("own") else {"n": "MY CLUB", "s": "MYC", "k": ["dc2424", "f4f4f4", "dc2424"]}
	# your team goes into the cup as a copy: what happens there stays there
	for k in ["squad", "xi", "form", "lay", "abv"]:
		if mc.has(k):
			cupc.d[k] = mc[k].duplicate(true) if (mc[k] is Array or mc[k] is Dictionary) else mc[k]
	cupc._ints()
	cupc.d["cupmode"] = true
	cupc.d["mode"] = "simple"
	cupc.save()
	_cm_enter()

# Into the cup mode: your own club brings its squad as it is now.
func _cm_enter() -> void:
	start_kind = ""
	cup_mode = true
	car = cupc
	_apply_own()
	hud.show_menu("cup", _menu_info())

# Out of the cup mode: what your own players learned there goes home with them.
func _cm_leave() -> void:
	if not cup_mode:
		return
	_cm_sync()
	car = car_main
	cup_mode = false
	_apply_own()

func _cm_sync() -> void:
	# the cup's team is its own copy (Daniel: each mode keeps its own team), so nothing goes back
	pass

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
	if cup_mode and not assist:
		hud.show_menu("cup", _menu_info())
		return
	if not car.has_save() and not assist:
		# the first time: your own club, no career yet. Give it a name and colours
		car.new_club()
		car.d["own"] = {"n": "MY CLUB", "s": "MYC", "k": (CLUBS[int(car.d["club"])]["k"] as Array).duplicate()}
		car.save()
		_own_changed()
		if pick and net.web:
			own_new = true
			hud.show_menu("myclub", _menu_info())
			return
	car_sel = -1
	car_sell = -1
	if in_career or assist:
		var okt: Array = ["career", "pro", "league", "office"] if car.pro() else ["career", "team", "transfers", "club", "office"]
		if not (hub_tab in okt):
			hub_tab = "career"
	elif hub_tab in ["career", "transfers", "office"]:
		hub_tab = "play"
	if car.on() and car.mode() == "" and not assist:
		# an old save, or a career made before the choice existed: ask once
		hud.show_menu("cmode", _menu_info())
		return
	hud.show_menu("main", _menu_info())

func _action(act: String, arg = null) -> void:
	audio.play("click2" if act in ["play", "start", "again"] else "click")
	if act == "key":
		return
	if assist and _as_take(act, arg):
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
			if in_career and (car == carc or car == proc) and net.role == "":
				# the career together: open a room and stay in the career, the friend comes in with the code
				_action("host")
			elif in_career and net.role == "host":
				_action("share")
			else:
				hud.show_menu("friend", _menu_info())
		"career":
			car_msg = ""
			car_sure = false
			if adv_from > -99 and in_career and (car == carc or car == proc) and not assist and net.role == "" and not car.d.has("cur"):
				var f := adv_from
				adv_from = -99
				if car.next_day() > f:
					if screen == "match":
						_to_menu()
					_adv_show(f)
					return
			adv_from = -99
			if screen == "match":
				_to_menu()
			else:
				_show_hub()
		"cal":
			cal_m = 0 if arg == null else cal_m + int(arg)
			hud.show_menu("cal", _menu_info())
		"cset":
			hud.show_menu("cset", _menu_info())
		"ctac":
			hud.show_menu("ctac", _menu_info())
		"tac_set":
			var ta: Array = arg if arg is Array else ([int(arg) / 10, int(arg) % 10] if arg is int else [0, 2])
			car.set_tac(int(ta[0]), int(ta[1]))
			hud.refresh(_menu_info())
		"cfg_diff":
			car.set_cfg("diff", int(arg))
			hud.refresh(_menu_info())
		"cfg_len":
			car.set_cfg("len", int(arg))
			hud.refresh(_menu_info())
		"c_sim":
			if _not_match_day():
				_action("c_adv")
				return
			_sim_mine()
		"c_adv":
			# FIFA's ADVANCE: day by day to the next news or to match day
			if in_career and (car == carc or car == proc) and (not car.season_over() or car.cup_due() or car.eu_due() or car.nat_due()):
				var af: int = car.advance()
				_adv_show(af, car.now())
		"youth":
			car_msg = ""
			hud.show_menu("youth", _menu_info())
		"inbox":
			car_msg = ""
			# open on the news the home card showed: the newest unread mail, else the newest
			if not car.inbox().is_empty():
				mail_sel = int(car.inbox()[0]["id"])
				for m0 in car.inbox():
					if not bool(m0.get("rd", false)):
						mail_sel = int(m0["id"])
						break
			car.mail_read(mail_sel)
			hud.show_menu("inbox", _menu_info())
		"mail":
			car_msg = ""
			mail_sel = int(arg)
			car.mail_read(mail_sel)
			hud.refresh(_menu_info())
		"mail_pick":
			var mp2: Array = arg
			car_msg = ""
			car.mail_pick(int(mp2[0]), int(mp2[1]))
			audio.play("click2")
			hud.refresh(_menu_info())
		"bid_acc", "bid_rej", "bid_more", "bid_son":
			car_msg = car.bid_answer(int(arg), {"bid_acc": "acc", "bid_rej": "rej", "bid_more": "more", "bid_son": "son"}[act])
			hud.refresh(_menu_info())
		"tnews":
			hud.show_menu("tnews", _menu_info())
		"y_tab":
			y_tab = int(arg)
			car_msg = ""
			hud.refresh(_menu_info())
		"y_pick":
			car.scout_pick(int(arg))
			hud.refresh(_menu_info())
		"y_send":
			car_msg = car.scout_send(int(arg))
			hud.refresh(_menu_info())
		"y_hire":
			car_msg = car.scout_hire(int(arg))
			hud.refresh(_menu_info())
		"y_sign":
			car_msg = car.youth_sign(int(arg))
			hud.refresh(_menu_info())
		"y_drop":
			car.youth_drop(int(arg))
			hud.refresh(_menu_info())
		"y_prom":
			car_msg = car.youth_promote(int(arg))
			hud.refresh(_menu_info())
		"y_rel":
			car.youth_release(int(arg))
			hud.refresh(_menu_info())
		"adv_done":
			adv_info = {}
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
				audio.play("cheer")
				fx("flash", 0.5)
				hud.show_menu("pack", _menu_info())
			else:
				car_msg = str(pr.get("err", ""))
				hud.refresh(_menu_info())
		"cup":
			hud.show_menu("cup", _menu_info())
		"eu_play":
			if car.eu_due() and int(car.eu_opp()[0]) >= 0:
				car.go_match()
				career_on = true
				eu_on = true
				# the knockouts need a winner: extra time and penalties, like a cup tie
				cup_on = car.eu_ko()
				humans = [Human.new()]
				me = 0
				view_flip = 1.0
				var eo: Array = car.eu_opp()
				_set_clubs(int(car.d["club"]), int(eo[0]), true)
				_car_opts()
				screen = "match"
				hud.show_menu("", {})
				_begin_match(true)
		"eu":
			hud.show_menu("eu", _menu_info())
		"dbgnat":
			# review hooks only: take a national job, and play on to its next match
			if " ".join(OS.get_cmdline_user_args()).contains("--menu="):
				if not car.nat_job():
					car.nat_take(0 if arg == null else int(arg))
		"dbgsc":
			# review hooks only: open a scouted player, 0 = one with a release clause, 1 = one without
			if " ".join(OS.get_cmdline_user_args()).contains("--menu="):
				car.d["coins"] = 99999
				scout_li = car.lg()
				for c in car.ids():
					if c == int(car.d["club"]):
						continue
					for i in (car.cpu_squad(c) as Array).size():
						if (car.cpu_clause(c, i) > 0) == (int(arg) == 0 if arg != null else true):
							scout_c = c
							scout_i = i
							scout_res = {}
							scout_sw = 10
							hud.show_menu("scout_sq", _menu_info())
							return
		"dbgft":
			if " ".join(OS.get_cmdline_user_args()).contains("--menu=") and screen == "match":
				score = [2, 1]
				_full_time()
		"dbgnatdue":
			if " ".join(OS.get_cmdline_user_args()).contains("--menu="):
				var gq := 0
				while not car.nat_due() and gq < 60:
					while car.now() < car.next_day():
						car.advance()
					_sim_mine()
					gq += 1
				while car.now() < car.next_day():
					car.advance()
				_show_hub()
		"nat_play":
			if car.nat_due() and int(car.nat_opp()[0]) >= 0:
				car.go_match()
				_nat_setup()
				humans = [Human.new()]
				me = 0
				view_flip = 1.0
				_car_opts()
				screen = "match"
				hud.show_menu("", {})
				_begin_match(true)
		"nat":
			hud.show_menu("nat", _menu_info())
		"nat_tab":
			nat_tab = int(arg) if arg != null else 0
			hud.show_menu("nat", _menu_info())
		"nat_pick":
			var npm: String = car.nat_pick(str(arg))
			if npm != "":
				hud.toast(npm)
			hud.refresh(_menu_info())
		"nat_auto":
			car.nat_call_auto()
			car.save()
			hud.toast("The best 23 are called up")
			hud.refresh(_menu_info())
		"nat_quit":
			car.nat_quit()
			_show_hub()
		"cup_play":
			if car.cup_due() and car.cup_opp() >= 0:
				car.go_match()
				career_on = true
				eu_on = false
				cup_on = true
				humans = [Human.new()]
				me = 0
				view_flip = 1.0
				_set_clubs(int(car.d["club"]), car.cup_opp(), true)
				_car_opts()
				screen = "match"
				hud.show_menu("", {})
				_begin_match(true)
		"c_play":
			if _not_match_day():
				# no match before match day: the days go by first
				_action("c_adv")
				return
			if net.role == "host" and net.connected and in_career and (car == carc or car == proc):
				# together: the match starts when both have tapped PLAY
				co_rdy[0] = not co_rdy[0]
				_co_ready_send()
				if co_rdy[0] and co_rdy[1]:
					_co_go()
				else:
					hud.refresh(_menu_info())
				return
			pro_sq = -1
			pro_sq2 = -1
			if in_career and (car == carc or car == proc) and not car.season_over():
				car.go_match()
			if car.pro() and not car.season_over() or (car.pro() and (car.cup_due() or car.eu_due())):
				car.pro_select()
				if not car.pro_starts():
					# on the bench: the match is played without you (you may come on)
					_sim_mine()
					return
				pro_sq = car.pro_i()
			if car.cup_due():
				_action("cup_play")
			elif car.eu_due():
				_action("eu_play")
			elif car.nat_due():
				_action("nat_play")
			elif car.d.has("sacked"):
				hud.show_menu("review", _menu_info())
			elif not car.season_over():
				career_on = true
				cup_on = false
				eu_on = false
				humans = [Human.new()]
				me = 0
				view_flip = 1.0
				_set_clubs(int(car.d["club"]), car.next_match()[0], true)
				_car_opts()
				screen = "match"
				hud.show_menu("", {})
				_begin_match(true)
		"c_next":
			if not car.pro() and car.nat_due():
				hud.toast("The %s comes first" % str(car.nat_t().get("name", "tournament")).to_lower())
				_show_hub()
				return
			if car.pro():
				car.pro_next_season()
			elif not car.d.has("sacked"):
				car.next_season()
			_show_hub()
		"c_review":
			hud.show_menu("review", _menu_info())
		"c_job":
			car.take_job(int(arg))
			_apply_own()
			opt_club = int(car.d["club"])
			_set_clubs(opt_club, car.next_match()[0], true)
			_kickoff(0)
			hub_tab = "career"
			_show_hub()
		"c_board":
			hud.show_menu("board", _menu_info())
		"p_home":
			if proc.has_save() and proc.pro():
				_pro_enter()
			else:
				pro_new = {"pos": "FW", "c": -1, "pick": _pro_picks()}
				hud.show_menu("pro_start", _menu_info())
		"p_new":
			pro_new = {"pos": "FW", "c": -1, "pick": _pro_picks()}
			hud.show_menu("pro_start", _menu_info())
		"p_pos":
			pro_new["pos"] = str(arg)
			hud.refresh(_menu_info())
		"p_club":
			pro_new["c"] = int(arg)
			hud.refresh(_menu_info())
		"p_more":
			pro_new["pick"] = _pro_picks()
			pro_new["c"] = -1
			hud.refresh(_menu_info())
		"p_name":
			var nn2 := ""
			if net.web:
				var res2 = JavaScriptBridge.eval("(function(){var r=prompt('Your player name', %s);return r===null?'':String(r)})()" % JSON.stringify(str(pro_new.get("n", ""))), true)
				nn2 = str(res2) if res2 != null else ""
			else:
				nn2 = "LARSEN"
			var cl2 := ""
			for ch in nn2.to_upper().strip_edges():
				if (ch >= "A" and ch <= "Z") or ch == " " or ch in ["Æ", "Ø", "Å", "-"]:
					cl2 += ch
			cl2 = cl2.strip_edges().substr(0, 12)
			if cl2.length() >= 2:
				pro_new["n"] = cl2
			hud.refresh(_menu_info())
		"p_go":
			if int(pro_new["c"]) >= 0:
				proc.new_pro(int(pro_new["c"]), str(pro_new.get("n", "ROOKIE")), str(pro_new["pos"]))
				_pro_enter()
		"p_spend":
			car_msg = car.pro_spend(int(arg), "pro2" if assist else "pro")
			hud.refresh(_menu_info())
		"p_drill":
			car.pro_set_drill(int(arg), "pro2" if assist else "pro")
			car_msg = ""
			hud.refresh(_menu_info())
		"p_skills":
			car_msg = ""
			hud.show_menu("pro_ab", _menu_info())
		"p_learn":
			car_msg = car.pro_learn(str(arg), "pro2" if assist else "pro")
			if car_msg.begins_with("YOU LEARNED"):
				audio.play("click2")
				hub_tab = "pro"
				_show_hub()
			else:
				hud.refresh(_menu_info())
		"p2_make":
			# the friend makes his own player: the manager's phone puts him in the squad
			if str(pro_new.get("n", "")) != "":
				net.send({"_": "pro2", "n": str(pro_new["n"]), "pos": str(pro_new.get("pos", "MF"))})
				hud.toast("Your player is joining the club")
		"c_home":
			if carc.has_save() and carc.on():
				_cr_enter()
			else:
				_action("c_start")
		"cr_exit":
			if net.role == "host":
				net.stop()
				room = ""
				co_rdy = [false, false]
			_cr_exit()
		"co_back":
			_co_back(true)
		"co_leave":
			_as_leave(false)
			_to_menu()
		"co_close":
			net.stop()
			room = ""
			co_rdy = [false, false]
			hud.toast("The room is closed")
			_show_hub()
		"as_open":
			_as_open()
		"as_back":
			_as_leave(true)
		"sug_yes":
			_sug_answer(true)
		"sug_no":
			_sug_answer(false)
		"c_start":
			start_kind = ""
			new_sure = false
			hud.show_menu("car_start", _menu_info())
		"cs_mine":
			start_kind = "mine"
			if _my_club().is_empty():
				start_kind = "new"
			hud.show_menu("start_lg", _menu_info())
		"cs_new":
			start_kind = "new"
			hud.show_menu("start_lg", _menu_info())
		"cs_club":
			start_kind = "club"
			hud.show_menu("start_lg", _menu_info())
		"st_lg":
			start_li = int(arg)
			if start_kind == "mine":
				_start_mine()
			elif start_kind == "new":
				_action("st_club", -1)
			else:
				hud.show_menu("start_club", _menu_info())
		"st_len":
			opt_slen = "short" if opt_slen == "full" else "full"
			hud.refresh(_menu_info())
		"st_back":
			hud.show_menu("start_lg", _menu_info())
		"st_club":
			if start_kind == "cup":
				_cup_start(int(arg))
				return
			# arg: a club to take over, or -1 = your own new club in the place of the league's weakest
			var own := int(arg) < 0
			var sc: int = carc.weakest(start_li) if own else int(arg)
			carc.new_career(sc, own, opt_slen)
			start_kind = ""
			_cr_enter(false)
			if own:
				car.d["own"] = {"n": "NEW CLUB", "s": "NEW", "k": (ClubDB.clubs(CLUBS0)[sc]["k"] as Array).duplicate()}
				own_new = true
				_own_changed()
				hud.show_menu("myclub", _menu_info())
			else:
				_own_changed()
				hud.show_menu("cmode", _menu_info())
		"scout":
			if not (in_career or assist):
				return
			if scout_li < 0:
				scout_li = car.lg()
			scout_c = -1
			scout_res = {}
			hud.show_menu("scout", _menu_info())
		"sc_lg":
			scout_li = int(arg)
			hud.refresh(_menu_info())
		"sc_club":
			scout_c = int(arg)
			scout_i = -1
			scout_res = {}
			hud.show_menu("scout_sq", _menu_info())
		"sc_pl":
			scout_i = int(arg)
			scout_res = {}
			hud.refresh(_menu_info())
		"sc_swp":
			# pick which of your men goes the other way in a swap
			var nsq: int = (car.d["squad"] as Array).size()
			if nsq > 0:
				scout_sw = (scout_sw + (int(arg) if arg != null else 1) + nsq) % nsq
			hud.refresh(_menu_info())
		"sc_bid", "sc_bid_so", "sc_rc", "sc_swap":
			if scout_c >= 0 and scout_i >= 0:
				var amt := int(arg) if act in ["sc_bid", "sc_bid_so"] else 0
				var bex := {}
				if act == "sc_bid_so":
					bex["so"] = true
				elif act == "sc_rc":
					bex["rc"] = true
				elif act == "sc_swap":
					bex["swap"] = str(arg)
				scout_res = car.bid(scout_c, scout_i, amt, bex)
				if bool(scout_res.get("talk", false)):
					car_msg = str(scout_res.get("msg", ""))
					ct_from = "scout_sq"
					hud.show_menu("contract", _menu_info())
					return
				if bool(scout_res.get("ok", false)):
					audio.play("cheer")
					scout_i = -1
				hud.refresh(_menu_info())
		"sc_back":
			scout_c = -1
			scout_res = {}
			hud.show_menu("scout", _menu_info())
		"cmode":
			hud.show_menu("cmode", _menu_info())
		"cmode_set":
			car.set_mode(str(arg))
			_show_hub()
		"c_table":
			hud.show_menu("table", _menu_info())
		"scorers":
			hud.show_menu("scorers", _menu_info())
		"cab":
			cab_tab = int(arg) if arg != null else 0
			hud.show_menu("cab", _menu_info())
		"cab_tab":
			cab_tab = int(arg)
			hud.refresh(_menu_info())
		"c_squad":
			car_sell = -1
			car_sel = -1
			car_msg = ""
			hud.show_menu("squad", _menu_info())
		"c_pick":
			var pi := int(arg)
			car_msg = ""
			car_sell = -1
			# a tap only picks the man to look at; swapping is done by dragging (Daniel)
			car_sel = -1 if car_sel == pi else pi
			hud.refresh(_menu_info())
		"c_train":
			if car_sel >= 0:
				var r2: String = car.train(car_sel)
				car_msg = r2 if r2 != "" else "Not enough coins, or he has reached his best"
				if r2 != "":
					audio.play("click2")
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
			if car.on() and car.mode() == "":
				hud.show_menu("cmode", _menu_info())
			else:
				_show_hub(false)
		"c_ab":
			# open the skill picker for this place
			if car_sel >= 0:
				ab_slot = int(arg)
				car_msg = ""
				hud.show_menu("abil", _menu_info())
		"c_abuy":
			if car_sel >= 0:
				car_msg = car.learn_ab(car_sel, ab_slot, str(arg))
				if car_msg.contains("LEARNED"):
					audio.play("click2")
					hud.show_menu("squad", _menu_info())
				else:
					hud.refresh(_menu_info())
		"c_abback":
			car_msg = ""
			hud.show_menu("squad", _menu_info())
		"c_tp":
			if car_sel >= 0:
				car_msg = car.spend_tp(car_sel, int(arg))
				if car_msg.contains("+1"):
					audio.play("click2")
				hud.refresh(_menu_info())
		"c_club":
			car_msg = ""
			hud.show_menu("club", _menu_info())
		"ct_open":
			if car_sel >= 0:
				car_msg = car.talk_renew(car_sel)
				if not car.talk().is_empty():
					ct_from = "squad"
					hud.show_menu("contract", _menu_info())
				else:
					hud.refresh(_menu_info())
		"ct_rc":
			car.talk_set("rc", int(arg) if arg != null else 1)
			hud.refresh(_menu_info())
		"ct_w", "ct_y":
			car.talk_set("w" if act == "ct_w" else "y", int(arg))
			hud.refresh(_menu_info())
		"ct_go":
			if arg is Array and (arg as Array).size() >= 3:
				# the assistant's contract offer: the same talk, with his numbers
				car.talk_renew(int(arg[0]))
				car.talk_force(int(arg[1]), int(arg[2]), int(arg[3]) if (arg as Array).size() > 3 else -1)
			car_msg = car.talk_offer()
			if car.talk().is_empty():
				# the talk is over: back to where it started, with the answer
				audio.play("click2" if car_msg.contains("SIGN") else "click")
				car_sel = -1
				scout_i = -1
				scout_res = {}
				hud.show_menu("squad" if car_msg.contains("SIGN") or ct_from == "squad" else ct_from, _menu_info())
			else:
				hud.refresh(_menu_info())
		"ct_back":
			car.talk_end()
			car_msg = ""
			scout_res = {}
			hud.show_menu(ct_from if ct_from != "" else "squad", _menu_info())
		"c_focus":
			if car_sel >= 0:
				car.set_focus(car_sel)
				hud.refresh(_menu_info())
		"c_rt":
			if car_sel >= 0:
				car.retrain(car_sel)
				hud.refresh(_menu_info())
		"c_trainm":
			hud.show_menu("training", _menu_info())
		"c_plan":
			var pa: Array = arg
			car.set_plan(str(pa[0]), int(pa[1]))
			hud.refresh(_menu_info())
		"c_wb":
			car_msg = car.wb_move(str(arg) == "up")
			hud.refresh(_menu_info())
		"c_fac":
			car_msg = car.fac_up(str(arg)) if not car.eur else car.fac_ask(str(arg))
			if car_msg == "BUILT":
				car_msg = ""
				audio.play("click2")
			hud.refresh(_menu_info())
		"c_market":
			car_msg = ""
			hud.show_menu("market", _menu_info())
		"c_buy":
			car_msg = car.buy(int(arg))
			if not car.talk().is_empty():
				ct_from = "market"
				hud.show_menu("contract", _menu_info())
				return
			if car_msg.ends_with("SIGNED"):
				audio.play("click2")
			hud.refresh(_menu_info())
		"c_sell":
			# on or off the transfer list (one tap, it can always be undone)
			if car_sel >= 0:
				car_msg = car.sell(car_sel)
				car_sell = -1
				audio.play("click2")
				hud.refresh(_menu_info())
		"c_spot":
			# a man dragged to a new spot on the team screen: [slot, along, across]
			var sa: Array = arg
			car.set_spot(int(sa[0]), float(sa[1]), float(sa[2]))
			car_sel = -1
			car_msg = ""
			hud.refresh(_menu_info())
		"c_swap":
			# a man dropped onto another: they change places (the spots stay)
			var ws: Array = arg
			if int(ws[0]) != int(ws[1]):
				car_msg = car.swap(int(ws[0]), int(ws[1]))
				if car_msg == "":
					audio.play("click2")
			car_sel = -1
			hud.refresh(_menu_info())
		"c_lay0":
			car.clear_lay()
			car_sel = -1
			car_msg = ""
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
			_action("c_start")
		"online":
			if cup_mode:
				_cm_leave()
			hud.show_menu("online", _menu_info())
		"rk_find":
			_rk_find()
		"rk_stop":
			_rk_stop()
			hud.show_menu("online", _menu_info())
		"rk_next":
			_to_menu()
			_rk_find()
		"rk_lb":
			_lb_fetch()
			hud.show_menu("rk_lb", _menu_info())
		"friends":
			if net.web:
				_fr_card()
				net._js("bbFr.open()")
			fr_poll = 0.6
			hud.show_menu("friends", _menu_info())
		"fr_add":
			hud.show_menu("fr_add", _menu_info())
		"fr_code":
			net._js("bbFr.add(%s)" % JSON.stringify(str(arg)))
			fr_poll = 0.4
			hud.show_menu("friends", _menu_info())
		"fr_rm":
			net._js("bbFr.remove(%s)" % JSON.stringify(str(arg)))
			fr_poll = 0.0
		"fr_invite":
			# open a room the normal way and tell the friend's phone the code
			_action("host")
			if net.role == "host" and room.length() == 4:
				net._js("bbFr.invite(%s, %s)" % [JSON.stringify(str(arg)), JSON.stringify(room)])
		"inv_yes":
			var ic := str(fr_inv.get("c", ""))
			fr_inv = {}
			net._js("bbFr.inviteDone()")
			if ic.length() == 4:
				_action("code", ic)
		"inv_no":
			fr_inv = {}
			net._js("bbFr.inviteDone()")
			_show_hub(false)
		"rk_road":
			hud.show_menu("rk_road", _menu_info())
		"cupm":
			if cupc.has_save():
				_cm_enter()
			else:
				hud.show_menu("cm_pick", _menu_info())
		"cm_mine":
			_cup_start_mine(str(arg))
		"cm_club":
			start_kind = "cup"
			cup_ctry = str(arg)
			hud.show_menu("start_lg", _menu_info())
		"cm_back":
			_cm_leave()
			hub_tab = "play"
			_show_hub()
		"cm_new":
			_cm_leave()
			cupc.wipe()
			hud.show_menu("cm_pick", _menu_info())
		"cm_team":
			car_sell = -1
			car_sel = -1
			car_msg = ""
			hud.show_menu("squad", _menu_info())
		"teams":
			teams_from = "lobby" if net.role != "" else "quick"
			hud.show_menu("teams", _menu_info())
		"club_own":
			# back to your own club in the friend's room
			_own_ft(true)
			_ft_send()
			hud.show_menu(teams_from, _menu_info())
		"teams_back":
			if teams_from == "new":
				_show_hub(false)
			else:
				hud.show_menu(teams_from, _menu_info())
		"club":
			opt_club = int(arg)
			if net.web:
				JavaScriptBridge.eval("try{localStorage.setItem('bb3d-club','%d')}catch(e){}" % opt_club, true)
			if teams_from == "lobby":
				_own_ft(false)
			if net.role == "guest":
				_ft_send()
			else:
				# show the new kit on the pitch behind the menu
				_set_clubs(opt_club, clubs[1] if clubs[1] != opt_club else _other_club(opt_club))
				_kickoff(0)
			if teams_from == "new":
				_show_hub(false)
			else:
				hud.show_menu(teams_from, _menu_info())
		"host":
			if in_career and carc.has_save() and (car == carc or car == proc):
				# a room made from inside the career: the friend comes into the career with you
				opt_mode = "coop"
				opt_car = true
				opt_cup = false
			room = "%04d" % (randi() % 9000 + 1000)
			guest_tm = {}
			net.host(room)
			co_rdy = [false, false]
			if opt_car and in_career:
				hud.toast("ROOM %s: YOUR FRIEND JOINS WITH THIS CODE" % room)
				hub_tab = "career"
				_show_hub()
			else:
				hud.show_menu("lobby", _menu_info())
		"joinmenu":
			hud.show_menu("join", _menu_info())
		"code":
			room = str(arg)
			net.join(room)
			hud.show_menu("lobby", _menu_info())
		"mode":
			opt_cup = false
			if opt_mode == "coop" and not opt_car and car.has_save() and car.on():
				opt_car = true
			elif opt_mode == "coop":
				opt_car = false
				opt_cup = false
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
				paused = true
				paused_by = ""
				if net.role != "" and net.connected:
					# online the match stops on both phones, and the other one sees who stopped it
					net.send({"_": "pz", "on": true, "by": _my_name()})
				hud.show_menu("pause", _menu_info())
		"mtac":
			if screen == "match" and state != "full":
				hud.show_menu("mtac", _menu_info())
		"mtac_set":
			var ta: Array = arg if arg is Array else [0, 2]
			_tac_change(_my_side(), int(ta[0]), int(ta[1]))
			hud.refresh(_menu_info())
		"subs":
			if screen == "match" and not _subs_info().is_empty():
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
			paused_by = ""
			if net.role != "" and net.connected and screen == "match":
				net.send({"_": "pz", "on": false})
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
	# with the ball he is clearly slower than a free runner (good dribblers lose less), like FIFA
	p.carry_k = lerpf(0.86, 0.93, dk)
	p.phy = clampf(p.dfn * 0.7 + (100 - p.pac) * 0.3 + (6.0 if p.role == "DF" else 0.0), 35.0, 99.0)
	if p.has_ab("raket"):
		p.base_top *= 1.06
		p.acc_k *= 1.06
	if p.has_ab("bamse"):
		p.phy = minf(p.phy + 12.0, 99.0)

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
	if opt_cup and opt_mode == "coop" and car.has_save():
		if car.cup_over():
			return "CUP  ·  %s  ·  A NEW CUP STARTS" % CLUBS[int(car.d["club"])]["n"]
		return "CUP %s  ·  %s v %s" % [car.cup_round_name(), CLUBS[int(car.d["club"])]["n"], CLUBS[car.cup_opp()]["n"]]
	if not (opt_car and opt_mode == "coop" and car.has_save()):
		return ""
	if car.d.has("sacked"):
		return ""
	if car.cup_due():
		return "CUP %s  ·  %s v %s  ·  BOARD: %s" % [car.cup_round_name(), CLUBS[int(car.d["club"])]["n"], CLUBS[car.cup_opp()]["n"], Career.mood_of(car.conf())]
	if car.season_over():
		return "%s  ·  NEW SEASON" % CLUBS[int(car.d["club"])]["n"]
	return "%s v %s  ·  ROUND %d OF %d  ·  %s IN THE TABLE  ·  BOARD: %s" % [CLUBS[int(car.d["club"])]["n"], CLUBS[car.next_match()[0]]["n"], int(car.d["round"]) + 1, car.rounds_total(), Career.ordinal(car.rank_of(int(car.d["club"]))), Career.mood_of(car.conf())]

# ---------------------------------------------------------------- ranked online
# Your team as the other phone needs it: the club's name and kit, its formation and your eleven with their numbers.
func _rk_team(c = null) -> Dictionary:
	if c == null:
		c = car
	var me_c := int(c.d["club"])
	var cl: Dictionary = CLUBS[me_c]
	var xi := []
	for x in c.d["xi"]:
		var pl: Dictionary = c.d["squad"][int(x)]
		xi.append({"n": str(pl["n"]), "num": int(pl["num"]), "pos": str(pl["pos"]), "pac": int(pl["pac"]), "sho": int(pl["sho"]), "pas": int(pl["pas"]), "dfn": int(pl["dfn"]), "ab": Career.ab_of(pl)})
	# the bench too: up to seven men who are not in the eleven, so you can make changes in the match
	var bench := []
	for i in (c.d["squad"] as Array).size():
		if bench.size() >= 7:
			break
		if (c.d["xi"] as Array).has(i) or (c.d["xi"] as Array).has(float(i)):
			continue
		var bp: Dictionary = c.d["squad"][i]
		bench.append({"n": str(bp["n"]), "num": int(bp["num"]), "pos": str(bp["pos"]), "pac": int(bp["pac"]), "sho": int(bp["sho"]), "pas": int(bp["pas"]), "dfn": int(bp["dfn"]), "ab": Career.ab_of(bp)})
	return {"n": str(cl["n"]), "s": str(cl["s"]), "k": (cl["k"] as Array).duplicate(), "a": (cl.get("a", cl["k"]) as Array).duplicate(), "f": c.form(), "lay": c.lay(),
		"xi": xi, "bench": bench, "rp": rk.rp(), "rn": str(rk.now()["n"]), "ov": int(round(c.my_strength()))}

# ---- a friend's room: each of you can bring your own club, with your own eleven, formation and spots
func _has_own() -> bool:
	return car_main.has_save() and car_main.d.has("own") and (car_main.d.get("xi", []) as Array).size() == 11

# your own team for the friend's room, or {} when you picked one of the eight clubs
func _ft_me() -> Dictionary:
	if not opt_own or not _has_own():
		return {}
	var t := _rk_team(car_main)
	# the club outside the career: its own name and kit, not what the menu shows right now
	var o: Dictionary = car_main.d["own"]
	var k: Array = o["k"]
	var alt := "1c1c20" if Color(str(k[0])).get_luminance() > 0.6 else "f4f4f4"
	t["n"] = str(o["n"])
	t["s"] = str(o["s"])
	t["k"] = [str(k[0]), str(k[1]), str(k[2])]
	t["a"] = [alt, str(k[0]), alt]
	return t

# one of the eight clubs written like an own team (no eleven: the usual players)
func _ft_plain(ci: int) -> Dictionary:
	var cl: Dictionary = CLUBS[clampi(ci, 0, CLUBS.size() - 1)]
	return {"n": str(cl["n"]), "s": str(cl["s"]), "k": (cl["k"] as Array).duplicate(), "a": (cl.get("a", cl["k"]) as Array).duplicate()}

func _ft_ok(t) -> bool:
	return t is Dictionary and t.get("xi", []) is Array and (t["xi"] as Array).size() == 11

# the club button in the lobby: your own club or the one of the eight you picked
func _lobby_club() -> int:
	if opt_own and _has_own():
		return int(car_main.d["club"])
	return opt_club

func _guest_name() -> String:
	if not guest_tm.is_empty():
		return str(guest_tm.get("n", "")).substr(0, 18)
	return str(CLUBS[clampi(guest_club, 0, CLUBS.size() - 1)]["n"])

func _own_ft(v: bool) -> void:
	opt_own = v
	if net.web:
		JavaScriptBridge.eval("try{localStorage.setItem('bb3d-ftown','%d')}catch(e){}" % (1 if v else 0), true)

func _ft_send() -> void:
	if net.role == "guest" and net.connected:
		net.send({"_": "club", "id": opt_club, "tm": _ft_me()})

func _ft_off() -> void:
	if ft_on:
		ft_on = false
		tov = [{}, {}]
		_apply_own()

# a ranked team as a club entry: name, short name and both kits, with care for what came over the wire
func _rk_club(t: Dictionary) -> Dictionary:
	var hx := func(v, dflt: String) -> String:
		var x := str(v)
		return x if (x.length() == 6 and x.is_valid_hex_number()) else dflt
	var k: Array = t.get("k", []) if t.get("k", []) is Array else []
	var a: Array = t.get("a", []) if t.get("a", []) is Array else []
	var kk := []
	var aa := []
	for i in 3:
		kk.append(hx.call(k[i] if i < k.size() else "", "888888"))
		aa.append(hx.call(a[i] if i < a.size() else "", "f4f4f4"))
	return {"n": str(t.get("n", "OPPONENT")).substr(0, 18), "s": str(t.get("s", "OPP")).substr(0, 3), "k": kk, "a": aa}

func _rk_find() -> void:
	if not net.web:
		hud.toast("Ranked works in the game's own link")
		return
	if not car.has_save():
		return
	if cup_mode:
		_cm_leave()
	if in_career:
		in_career = false
		car = car_main
		_incar_save()
		_apply_own()
	net.stop()
	rk_looking = true
	rk_on = false
	rk_res = {}
	rk_opp = {}
	rk_walk = false
	rk_t = 0.0
	rk_msg = "LOOKING FOR AN OPPONENT"
	rk_me = _rk_team()
	net.find()
	hud.show_menu("rk_find", _menu_info())

func _rk_stop() -> void:
	rk_looking = false
	net.stop()

# the host puts both teams on the pitch and starts the match on both phones
func _rk_host_start() -> void:
	rk_looking = false
	rk_on = true
	tov = [rk_me, rk_opp]
	_apply_own()
	opt_mode = "versus"
	opt_len = 1
	opt_diff = 1
	career_on = false
	cup_on = false
	eu_on = false
	var h0 := Human.new()
	var h1 := Human.new()
	h1.local = false
	h1.team = 1
	humans = [h0, h1]
	me = 0
	view_flip = 1.0
	_set_clubs(RKI, RKI + 1, true)
	screen = "match"
	hud.show_menu("", {})
	start_msg = {"_": "start", "mode": "versus", "diff": 1, "len": 1, "clubs": [RKI, RKI + 1], "forms": forms, "sq": [], "sq1": [], "lay": {}, "rk": 1, "ta": rk_me, "tb": rk_opp}
	wait_friend = 0.0
	net.send(start_msg)
	_begin_match(true)

# Full time in a ranked match (on both phones): rank points, coins and XP for your eleven.
func _rk_finish() -> void:
	if not rk_res.is_empty():
		return
	var mt := 1 if net.role == "guest" else 0
	var w := _winner()
	var res := 0.5 if w < 0 else (1.0 if w == mt else 0.0)
	if rk_walk:
		res = 1.0
	var gf: int = score[mt]
	var ga: int = score[1 - mt]
	rk_res = rk.match_result(int(rk_opp.get("rp", 0)), res, maxi(gf - ga, 1) if rk_walk else gf - ga, gf)
	var k1: Dictionary = rk_res["k1"]
	var dl := int(rk_res["delta"])
	car_lines = ["%s%d RANK POINTS  ·  %s" % ["+" if dl >= 0 else "", dl, str(k1["n"])]]
	if rk_walk:
		car_lines.append("YOUR OPPONENT LEFT: YOU WIN")
	if bool(rk_res["up"]):
		car_lines.append("PROMOTED TO %s!" % str(k1["n"]))
	elif bool(rk_res["down"]):
		car_lines.append("DOWN TO %s" % str(k1["n"]))
	if bool(rk_res["shield"]):
		car_lines.append("A SHIELD KEPT YOU IN THE RANK (%d LEFT)" % int(rk_res["sh"]))
	car_lines.append_array(rk_res["road"])
	car_lines.append_array(car.coop_reward(int(rk_res["coins"]), res >= 1.0))
	car.save()
	_lb_publish()

# the other player left in the middle: you win
func _rk_walkover() -> void:
	rk_walk = true
	hud.toast("Your opponent left the match")
	if state != "full":
		_full_time()

# ---- the leaderboard: everybody's card on the shared database (only the web build talks to it)
func _lb_publish() -> void:
	if not net.web:
		return
	_fr_card()
	net._js("bbFr.tick()")

# your public card: the leaderboard and your friends see it
func _fr_card() -> void:
	if not net.web or rk == null:
		return
	var nm := (str(CLUBS[int(car_main.d["club"])]["n"]) if car_main.has_save() else "Coach").substr(0, 14)
	var body := {"n": nm, "rp": 0, "rp11": rk.rp(), "w": int(rk.d["w"]), "d": int(rk.d["dr"]), "l": int(rk.d["l"]), "g": int(rk.d["g"]), "ov": clampi(int(round(car_main.my_strength())) if car_main.has_save() else 0, 0, 99), "s": 1 if (screen == "match" or net.role != "") else 0}
	net._js("bbFr.setMe(%s, %s)" % [JSON.stringify(str(rk.d["id"])), JSON.stringify(JSON.stringify(body))])

# read the page's friends state once a second: new friends, invites, and the list when it is on screen
func _fr_tick(dt: float) -> void:
	if not net.web:
		return
	fr_t -= dt
	if fr_t <= 0.0:
		fr_t = 20.0
		_fr_card()
		net._js("bbFr.tick()")
	fr_poll -= dt
	if fr_poll > 0.0:
		return
	fr_poll = 1.0
	var raw = net._js("bbFr.state()")
	var v = JSON.parse_string(str(raw)) if raw != null else null
	if not (v is Dictionary):
		return
	var was := JSON.stringify(fr)
	fr = v
	if str(v.get("toast", "")) != "":
		hud.toast(str(v["toast"]))
	fr.erase("toast")
	var iv = v.get("inv")
	if iv is Dictionary and fr_inv.is_empty() and screen == "menu" and net.role == "" and not rk_looking and not rk_on:
		fr_inv = iv
		audio.play("click2")
		hud.show_menu("fr_inv", _menu_info())
		return
	if hud.menu_name == "friends" and JSON.stringify(fr) != was:
		hud.refresh(_menu_info())

func _lb_fetch() -> void:
	if not net.web:
		lb_state = "off"
		return
	lb_state = "loading"
	var hr := HTTPRequest.new()
	add_child(hr)
	hr.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		hr.queue_free()
		if code == 200:
			var v = JSON.parse_string(body.get_string_from_utf8())
			var fv = JSON.parse_string(str(net._js("bbFr.ids()")))
			var fids: Array = fv if fv is Array else []
			lb = []
			if v is Dictionary:
				for id in v:
					var c = v[id]
					if c is Dictionary and (int(c.get("rp11", 0)) > 0 or int(c.get("w", 0)) + int(c.get("d", 0)) + int(c.get("l", 0)) > 0):
						lb.append({"n": str(c.get("n", "?")), "rp": int(c.get("rp11", 0)), "w": int(c.get("w", 0)), "d": int(c.get("d", 0)), "l": int(c.get("l", 0)), "me": str(id) == str(rk.d["id"]), "fr": fids.has(str(id))})
			lb.sort_custom(func(a, b): return int(a["rp"]) > int(b["rp"]))
			lb_state = "ok"
		else:
			lb_state = "off" if code in [401, 403] else "err"
		if hud.menu_name == "rk_lb":
			hud.refresh(_menu_info()))
	var base := str(net._js("bbFr.base()"))
	if not base.begins_with("https://"):
		base = FB
	if hr.request(base + "pl.json?orderBy=%22rp11%22&limitToLast=100") != OK:
		lb_state = "err"

func _rk_info() -> Dictionary:
	var k: Dictionary = rk.now()
	return {"n": k["n"], "c": k["c"], "c2": k["c2"], "rp": k["rp"], "p": k["p"], "in": k["in"], "need": k["need"], "nn": k["nn"], "t": k["t"], "dv": k["dv"],
		"sh": int(rk.d["sh"]), "ws": int(rk.d["ws"]), "w": int(rk.d["w"]), "dr": int(rk.d["dr"]), "l": int(rk.d["l"]), "days": RankS.days_left(),
		"msg": rk_msg, "t_s": int(rk_t), "res": rk_res, "opp": str(rk_opp.get("n", "")), "opp_rn": str(rk_opp.get("rn", "")), "lb": lb, "lb_state": lb_state,
		"tiers": RankS.TIERS}

func _host_start() -> void:
	_ft_off()
	var h0 := Human.new()
	var h1 := Human.new()
	h1.local = false
	h1.team = 0 if opt_mode == "coop" else 1
	humans = [h0, h1]
	me = 0
	view_flip = 1.0
	var sq := []
	career_on = _co_text() != ""
	pro_sq = -1
	pro_sq2 = -1
	if career_on and in_career and (car == carc or car == proc):
		car.go_match()
	if career_on and car.pro() and not car.pro2():
		# never a player career match together before the friend has made his own man
		career_on = false
		humans = [Human.new()]
		hud.toast("Your friend makes his own player first")
		hud.refresh(_menu_info())
		return
	if career_on and car.pro():
		# The player career together: the manager picks you like anyone else, so one of you can be on the
		# bench (then that thumb plays like a normal match, switching between the others). Never both.
		car.pro_select("pro")
		if car.pro2():
			car.pro_select("pro2")
			if not car.pro_starts() and not car.pro_starts("pro2"):
				car.pro_select("pro", true)
		pro_sq = car.pro_i()
		pro_sq2 = car.pro_i("pro2")
	cup_on = career_on and car.cup_due()
	eu_on = career_on and not cup_on and car.eu_due()
	if career_on and not cup_on and not eu_on and not car.pro() and car.nat_due():
		# the national team together: both countries go over the wire like a friend's room
		_nat_setup()
		for p in teams[0]:
			sq.append([p.pname, p.num])
	elif eu_on:
		cup_on = car.eu_ko()
		_set_clubs(int(car.d["club"]), int(car.eu_opp()[0]), true)
		for p in teams[0]:
			sq.append([p.pname, p.num])
	elif cup_on:
		_set_clubs(int(car.d["club"]), car.cup_opp(), true)
		for p in teams[0]:
			sq.append([p.pname, p.num])
	elif career_on:
		if car.season_over():
			if car.pro():
				car.pro_next_season()
			else:
				car.next_season()
		_set_clubs(int(car.d["club"]), car.next_match()[0], true)
		for p in teams[0]:
			sq.append([p.pname, p.num])
	else:
		var ta := _ft_me()
		var tb: Dictionary = guest_tm if opt_mode == "versus" else {}
		if not ta.is_empty() or not tb.is_empty():
			# own clubs: each side plays with its own eleven, formation and spots
			ft_on = true
			if ta.is_empty():
				ta = _ft_plain(opt_club)
			if tb.is_empty():
				tb = _ft_plain(_other_club(opt_club) if opt_mode == "coop" else guest_club)
			tov = [ta, tb]
			_apply_own()
			_set_clubs(RKI, RKI + 1, true)
		else:
			_set_clubs(opt_club, _other_club(opt_club) if opt_mode == "coop" else guest_club)
	screen = "match"
	hud.show_menu("", {})
	var sq1 := []
	for p in teams[1]:
		sq1.append([p.pname, p.num])
	start_msg = {"_": "start", "mode": opt_mode, "diff": opt_diff, "len": opt_len, "clubs": clubs, "forms": forms, "sq": sq, "sq1": sq1, "lay": car.lay() if career_on else {}}
	if ft_on:
		start_msg["ft"] = 1
		start_msg["ta"] = tov[0]
		start_msg["tb"] = tov[1]
	wait_friend = 0.0
	net.send(start_msg)
	_begin_match(true)

func _guest_start(m: Dictionary) -> void:
	_as_leave(false)
	opt_mode = m.get("mode", "coop")
	if m.has("rk") and m.get("ta") is Dictionary and m.get("tb") is Dictionary:
		rk_looking = false
		rk_on = true
		rk_opp = m["ta"]
		tov = [m["ta"], m["tb"]]
		_apply_own()
		m["clubs"] = [RKI, RKI + 1]
		career_on = false
		cup_on = false
		eu_on = false
	elif m.has("ft") and m.get("ta") is Dictionary and m.get("tb") is Dictionary:
		# a friend's room with own clubs: the host sends both teams
		ft_on = true
		tov = [m["ta"], m["tb"]]
		_apply_own()
		m["clubs"] = [RKI, RKI + 1]
	else:
		_ft_off()
	var h0 := Human.new()
	h0.local = false
	var h1 := Human.new()
	h1.team = 0 if opt_mode == "coop" else 1
	humans = [h0, h1]
	me = 1
	view_flip = 1.0 if h1.team == 0 else -1.0
	var cl: Array = m.get("clubs", [0, 1])
	if car.has_save() and car.d.has("own") and not ft_on and not rk_on:
		# this phone's own club sits in place of a real club of the host's world: show that club as it is
		var mi := int(car.d["club"])
		if mi == int(cl[1]) or (mi == int(cl[0]) and not (carv.has_save() and carv.d.has("own") and int(carv.d["club"]) == mi)):
			var base0: Array = ClubDB.clubs(CLUBS0)
			if mi >= 0 and mi < base0.size():
				CLUBS[mi] = base0[mi]
	sq_over = m.get("sq", [])
	sq1_over = m.get("sq1", [])
	co_got = false
	car_lines = []
	pro_bar = {}
	guest_prt = -1.0
	_set_clubs(int(cl[0]), int(cl[1]), true)
	var fm: Array = m.get("forms", [])
	var lm = m.get("lay", {})
	if fm.size() == 2 and FORMS.has(str(fm[0])) and FORMS.has(str(fm[1])) and (forms[0] != str(fm[0]) or forms[1] != str(fm[1]) or (lm is Dictionary and not lm.is_empty())):
		form_over = str(fm[0])
		lay_over = lm if lm is Dictionary else {}
		_set_clubs(int(cl[0]), int(cl[1]), true)
		form_over = ""
		lay_over = {}
	sq_over = []
	sq1_over = []
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
			"role":
				net.role = "host" if str(m.get("r", "")) == "host" else "guest"
			"wait":
				rk_msg = "WAITING FOR AN OPPONENT"
				if hud.menu_name == "rk_find":
					hud.refresh(_menu_info())
			"rkt":
				# the other side's team for a ranked match
				var tt = m.get("t", {})
				if rk_looking and tt is Dictionary and tt.get("xi", []) is Array and (tt["xi"] as Array).size() == 11:
					rk_opp = tt
					rk_msg = "OPPONENT FOUND: %s" % str(tt.get("n", ""))
					if net.role == "host":
						_rk_host_start()
					elif hud.menu_name == "rk_find":
						hud.refresh(_menu_info())
			"ready":
				hud.refresh(_menu_info())
			"bn":
				# the benches for this match, from the host
				var bb = m.get("b", [])
				if net.role == "guest" and bb is Array and bb.size() == 2 and bb[0] is Array and bb[1] is Array:
					sub_bench = bb
					sub_left2 = [3, 3]
					sub_used = [[], []]
			"pz":
				# the other phone paused (or carried on): the match stops and goes on together
				if screen == "match" and state != "full":
					paused = bool(m.get("on", false))
					if paused:
						paused_by = str(m.get("by", "your friend"))
						if hud.menu_name == "":
							hud.show_menu("pause", _menu_info())
						else:
							hud.refresh(_menu_info())
					else:
						paused_by = ""
						if hud.menu_name in ["pause", "mtac", "subs"]:
							hud.show_menu("", {})
			"tacq":
				# the friend changed his side's tactics in the pause menu
				if net.role == "host" and screen == "match":
					var tqt := int(m.get("t", -1))
					for hm in humans:
						if not hm.local and hm.team == tqt:
							_tac_change(tqt, int(m.get("k", 0)), int(m.get("v", 2)))
							break
			"tacd":
				if net.role == "guest":
					var tdt2 := int(m.get("t", -1))
					var tv = m.get("v", [])
					if tdt2 >= 0 and tdt2 < 2 and tv is Array and tv.size() == 3:
						tac_t[tdt2] = [int(tv[0]), int(tv[1]), int(tv[2])]
						if hud.menu_name == "mtac":
							hud.refresh(_menu_info())
			"toast":
				if net.role == "guest":
					hud.toast(str(m.get("s", "")))
			"subq":
				# the friend makes a substitution in his side: the host does it and tells both phones
				if net.role == "host" and screen == "match":
					var st := int(m.get("t", -1))
					var ok_t := false
					for hm in humans:
						if not hm.local and hm.team == st:
							ok_t = true
					if ok_t:
						_sub_do(st, int(m.get("slot", -1)), int(m.get("b", -1)))
			"subd":
				# the host made a substitution: the same man on this phone
				if net.role == "guest":
					var dt9 := int(m.get("t", -1))
					var ds := int(m.get("slot", -1))
					var db := int(m.get("b", -1))
					if dt9 >= 0 and dt9 < 2 and ds >= 0 and ds < teams[dt9].size() and db >= 0 and db < (sub_bench[dt9] as Array).size():
						var dp = teams[dt9][ds]
						var dpl: Dictionary = sub_bench[dt9][db]
						var on9: String = dp.pname
						dp.pname = str(dpl["n"])
						dp.set_num(int(dpl["num"]))
						(sub_used[dt9] as Array).append(db)
						sub_left2[dt9] = int(sub_left2[dt9]) - 1
						_sub_show(on9, dp.pname)
			"club":
				if net.role == "host":
					guest_club = clampi(int(m.get("id", 1)), 0, CLUBS.size() - 1)
					var gt = m.get("tm", {})
					guest_tm = gt if _ft_ok(gt) else {}
					hud.refresh(_menu_info())
			"open":
				net.connected = true
				if rk_looking:
					# ranked: tell the other phone who you are, the host starts when both teams are known
					net.send({"_": "rkt", "t": rk_me})
					audio.play("click2")
					continue
				cv_last = 0
				cv_t = 0.0
				if net.role == "host" and screen == "match" and wait_friend > 0.0 and start_msg != null:
					# the friend is back after a lost connection: straight into the running match again
					wait_friend = 0.0
					net.send(start_msg)
					hud.toast("Your friend is back")
				elif net.role == "host":
					_send_lobby()
				else:
					_ft_send()
				if screen == "menu" and net.role == "host" and in_career and opt_car:
					hud.toast("YOUR FRIEND IS IN THE CAREER")
					audio.play("click2")
					if hud.menu_name != "sug":
						hud.refresh(_menu_info())
				elif screen == "menu":
					hud.show_menu("lobby", _menu_info())
					audio.play("click2")
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
			"cv":
				# the host's career, fresh: the assistant sees what the manager sees
				if net.role == "guest":
					var cvd = JSON.parse_string(str(m.get("d", "")))
					if cvd is Dictionary and cvd.has("squad"):
						carv.d = cvd
						carv._ints()
						_apply_own()
						if screen == "menu" and not assist and hud.menu_name in ["lobby", "join", "friend", ""]:
							# straight into the host's career: no lobby, no team to pick
							_as_open()
						elif screen == "menu" or assist or (screen == "match" and state == "full"):
							hud.refresh(_menu_info())
			"pro2":
				if net.role == "host" and in_career and car == proc:
					car.add_pro2(str(m.get("n", "")), str(m.get("pos", "MF")))
					cv_last = 0
					hud.toast("%s has a player at the club now" % _guest_name())
					if screen == "menu":
						hud.refresh(_menu_info())
			"psp":
				if net.role == "host" and in_career and car == proc and car.pro2():
					car.pro_spend(int(m.get("si", 0)), "pro2")
					cv_last = 0
			"pdev":
				if net.role == "host" and in_career and car == proc and car.pro2():
					if str(m.get("a", "")) == "p_drill":
						car.pro_set_drill(int(m.get("x", 0)), "pro2")
					elif str(m.get("a", "")) == "p_learn":
						car.pro_learn(str(m.get("x", "")), "pro2")
					cv_last = 0
			"simr":
				if net.role == "guest" and m.get("d") is Dictionary:
					sim_res = m["d"]
					if sim_res.has("lines2") and not (sim_res["lines2"] as Array).is_empty():
						# the friend sees his own player's rating first
						sim_res["lines"] = sim_res["lines2"]
					# a simulated match played together pays the friend's own club too
					var cp9 = m.get("co")
					if cp9 is Array and cp9.size() >= 2 and car_main.has_save():
						car_main.coop_reward(int(cp9[0]), bool(cp9[1]))
						car_main.save()
					if assist:
						hud.show_menu("simres", _menu_info())
			"sug":
				if net.role == "host" and in_career and (car == carc or car == proc):
					sugs.append(m)
					if sugs.size() > 6:
						sugs.pop_front()
					_sug_next()
			"sugr":
				if net.role == "guest":
					hud.toast(("THE MANAGER SAID YES: " if bool(m.get("ok", false)) else "THE MANAGER SAID NO: ") + str(m.get("t", "")) + ("   " + str(m.get("r", "")) if str(m.get("r", "")) != "" else ""))
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
				guest_tm = {}
				_as_leave(false)
				carv.d = {}
				sugs = []
				if rk_looking:
					# the other one went away before the start: look again
					_rk_find()
					continue
				if rk_on:
					if screen == "match" and state != "full":
						_rk_walkover()
					continue
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
				elif in_career and opt_car:
					co_rdy = [false, false]
					hud.toast("Your friend left the career")
					if hud.menu_name != "sug":
						hud.refresh(_menu_info())
				else:
					hud.show_menu("lobby", _menu_info())
			"rdy":
				if net.role == "host":
					co_rdy[1] = bool(m.get("r", false))
					_co_ready_send()
					if co_rdy[0] and co_rdy[1] and screen == "menu":
						_co_go()
					elif screen == "menu" and hud.menu_name != "sug":
						hud.refresh(_menu_info())
				else:
					var hr = m.get("h", [false, false])
					if hr is Array and hr.size() == 2:
						co_rdy = [bool(hr[0]), bool(hr[1])]
					if screen == "menu":
						hud.refresh(_menu_info())
			"cob":
				# the manager went back to the career after the match: the friend comes along
				if net.role == "guest" and screen == "match":
					_co_back(false)
			"err":
				var em: String = str(m.get("m", ""))
				if rk_looking:
					rk_msg = "THE MATCH SERVER CANNOT BE REACHED. TRY AGAIN IN A MOMENT" if em != "full" else "EVERY WAITING PLACE IS TAKEN. TRY AGAIN IN A MOMENT"
					rk_looking = false
					net.stop()
					if hud.menu_name == "rk_find":
						hud.refresh(_menu_info())
					continue
				if net.role == "guest" and not net.connected:
					_to_menu()
					hud.toast("Could not find that room" if em == "peer-unavailable" else ("Could not connect. Try again, or switch between wifi and mobile data" if em == "timeout" else "Connection problem (%s)" % em))
				elif net.role == "host" and em == "unavailable-id":
					_action("host")

# ---------------------------------------------------------------- match flow

func _begin_match(with_intro: bool) -> void:
	pro_bar = {}
	guest_prt = -1.0
	derby_on = career_on and in_career and car.has_save() and car.d.has("leagues") and car._next_derby()
	tac_t = [[2, 1, 1], [2, 1, 1]]
	if career_on and in_career and car.has_save() and car.d.has("leagues") and not car.pro():
		tac_t = [car.tac(), car.cpu_tac(car._next_opp())]
	if nat_on:
		tac_t = [car.tac(), [2, 1, 1]]
	if autotest:
		for ti in 2:
			var te := OS.get_environment("TACT%d" % ti)
			if te != "":
				var tp := te.split(",")
				tac_t[ti] = [int(tp[0]), int(tp[1]), int(tp[2])]
	tac_base = tac_t.duplicate(true)
	tac_mood = ["", ""]
	mgr_t = 0.0
	cpu_sub_at = [0.0, 0.0]
	sub_hint = {}
	paused_by = ""
	golden = false
	half_kick = 1
	so_on = false
	so_done = false
	so_g = [0, 0]
	so_n = [0, 0]
	so_win = -1
	subs_left = 3
	sub_sel = -1
	sub_off = []
	sub_played = []
	if career_on:
		for x in car.d["xi"]:
			sub_played.append(int(x))
	sub_bench = [[], []]
	sub_left2 = [3, 3]
	sub_used = [[], []]
	if net.role != "guest":
		_make_benches()
		if net.role == "host":
			# the friend's phone shows the benches too (and asks the host to make its changes)
			net.send({"_": "bn", "b": sub_bench})
	for p in players:
		p.fit = _start_fit(p)
	test_t = Time.get_ticks_msec() / 1000.0
	car_goals = []
	car_lines = []
	score = [0, 0]
	clock = 0.0
	half = 1
	# a real coin toss: either side can kick off, the other one starts the second half
	kick_team = randi() % 2
	half_kick = 1 - kick_team
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
	_formation(kick_team, true)
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
	for rc in ref_card:
		var bp = rc[0]
		if bp != null and is_instance_valid(bp) and not bp.off:
			bp.yellow += 1
			if bp.yellow >= 2:
				bp.off = true
				_send_off(bp)
			if not _quiet():
				_banner("RED CARD" if bp.off else "YELLOW CARD", Color(0.95, 0.2, 0.2) if bp.off else Color(1.0, 0.9, 0.2), 1.3, "%d  %s" % [bp.num, bp.pname.to_upper()], 56)
	ref_card.clear()
	book_t = -1.0
	if ref != null:
		ref.card_up = 0
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
		snd("cheer", 0.8)
		snd("clap", 0.7)
		fx("say", "And we are under way!")

func _goal(team: int) -> void:
	if so_on:
		if state == "play":
			_so_result(true)
		return
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
		if pro_sq >= 0:
			for h9 in humans:
				var pm9 = _pro_man(h9)
				if pm9 == null:
					continue
				if scorer == pm9:
					h9.ptrk["g"] = int(h9.ptrk.get("g", 0)) + 1
				elif h9.ptrk.get("prev") == pm9 and h9.ptrk.get("last") == scorer:
					h9.ptrk["a"] = int(h9.ptrk.get("a", 0)) + 1
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
	fx("goal_snd", team)
	fx("excite", 1.0)
	fx("confetti", ball.position.x * 0.72)
	fx("vib", 180)
	fx("say", "Goal! %s scores for %s!" % [scorer.pname, TEAM_NAMES[team].capitalize()])

func _out(kind: String, pos: Vector3, team: int, wait := 0.9) -> void:
	if so_on:
		if state == "play":
			_so_result(false)
		return
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
		if dead_info.get("taker") != null:
			taker = dead_info["taker"]
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
# A corner you take yourself goes where you point: stick at rest = round the penalty spot, towards the near
# post, the far post or back to the edge of the box. The man nearest that spot attacks it.
var cross_spot = null

func _corner_aim(p, st: Vector2) -> Vector3:
	var s := side(p.team)
	var gx := HL * s
	var a := Vector3(gx - s * 8.5, 0, 0) + Vector3(st.x, 0, st.y).limit_length(1.0) * 8.0
	a.x = clampf(a.x, minf(gx - s * 19.0, gx - s * 2.5), maxf(gx - s * 19.0, gx - s * 2.5))
	a.z = clampf(a.z, -11.0, 11.0)
	return a

func _human_cross(h):
	var p = h.ctrl
	var a := _corner_aim(p, h.stick)
	var best = null
	var bd := 1e9
	for m in teams[p.team]:
		if m == p or m.off or m.role == "GK":
			continue
		var d: float = m.position.distance_to(a)
		if d < bd:
			bd = d
			best = m
	if best == null:
		return _cross_target(p)
	cross_spot = a
	return best

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
		var spd := 14.0 + randf() * 4.0 + (4.0 if p.has_ab("luft") else 0.0)
		if p.has_ab("luft"):
			_ab_pop(p, "luft")
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
	ball_bs = 0.0
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
	snd("header", 1.0 if kind == "shot" else 0.75)
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
		# the card comes at the next stop in play: the referee walks over and shows it
		var due := 0
		for rc in ref_card:
			if rc[0] == by:
				due += 1
		if due == 0:
			ref_card.append([by, "y"])
			stats["cards"] += 1
			card = "YELLOW CARD"
			if by.yellow + 1 >= 2:
				card = "RED CARD"
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
			_banner("ADVANTAGE", Color(1, 1, 1), 0.9, "", 44)
			fx("say", "The referee lets play go on. Advantage!")
			fx("vib", 60)
		return
	on.stun = 1.2
	on.start_fall(1.2)
	if in_box:
		stats["pens"] += 1
	snd("whistle")
	snd("thud")
	if not in_box and randf() < 0.6:
		snd("jeer", 0.55)
	if not _quiet():
		var who := "%d  %s" % [by.num, by.pname.to_upper()]
		if in_box:
			_banner("PENALTY!", Color(1.0, 0.86, 0.2), 1.6, "", 96)
			fx("say", "Penalty!")
			snd("gasp")
			snd("ooh")
		else:
			_banner("FOUL", Color(1, 1, 1), 1.0, "", 60)
			if card != "":
				fx("say", "That is a booking, surely.")
		fx("shake", 0.35)
		fx("vib", 80)
	ball_owner = null
	ball_vel = Vector3.ZERO
	_out("pen" if in_box else "fk", pos, on.team, 2.0 if in_box else 1.4)

func _offside(p) -> void:
	stats["offsides"] += 1
	snd("whistle_short")
	snd("aww", 0.45)
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
		if h.team != t or _locked(h):
			continue
		var d: float = h.ctrl.position.distance_to(pos) if h.ctrl != null else 1e6
		if d < bd:
			bd = d
			best = h
	return best

# a thumb on its own man in the player career (not one on the bench) is never switched
func _locked(h) -> bool:
	return h.psq >= 0 and _pro_man(h) != null

# the player career: is this the man one of you plays? (his team mates look for him)
func _is_pro_man(m) -> bool:
	if pro_sq < 0 or m == null:
		return false
	for h in humans:
		if h.psq >= 0 and _pro_man(h) == m:
			return true
	return false

func _assign_defenders(t: int, force: bool) -> void:
	var hs := []
	for h in humans:
		if h.team == t and (force or h.switch_cool <= 0.0) and not _locked(h):
			if h.pick_t > 0.0 and h.ctrl != null and not h.ctrl.off and h.ctrl.role != "GK":
				continue # he picked this man himself a moment ago
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

# ---- the player career: your thumb stays on your man, and the match keeps a few numbers on him
func _pro_man(h = null):
	if h == null:
		h = humans[0] if not humans.is_empty() else null
	if h == null or h.psq < 0:
		return null
	if h.pnode != null and is_instance_valid(h.pnode):
		return h.pnode
	for p in teams[0]:
		if p.sq == h.psq:
			h.pnode = p
			return p
	return null

func _pro_play(dt: float) -> void:
	if has_meta("pro_fast") and state_t > 6.0 and not get_meta("pro_jumped", false):
		set_meta("pro_jumped", true)
		half = 2
		clock = 5385.0
	for hi in humans.size():
		var h = humans[hi]
		if h.psq < 0 and h.ptrk.is_empty():
			# the first moment of the match: each thumb gets its own man
			h.ptrk = {"pok": 0, "lost": 0, "won": 0, "sh": 0, "g": 0, "a": 0, "tch": 0, "last": null, "prev": null}
			h.psq = pro_sq if hi == 0 else (pro_sq2 if h.team == 0 else -1)
		var pm = _pro_man(h)
		if pm == null or pm.off:
			continue
		if has_meta("pro_fast") and Engine.get_physics_frames() % 120 == 0:
			print("PROLOCK ", humans.find(h), " ctrl_is_me=", h.ctrl == pm, " owner=", players.find(ball_owner), " trk=", h.ptrk.get("pok"), "/", h.ptrk.get("lost"), "/", h.ptrk.get("tch"))
		if h.ctrl != pm:
			h.ctrl = pm
		var tk: Dictionary = h.ptrk
		tk["call"] = float(tk.get("call", 0.0)) - dt
		# you asked for the ball: the man on it (not a friend's man) plays it to you
		if float(tk["call"]) > 0.0 and ball_owner != null and ball_owner.team == pm.team and ball_owner != pm and set_piece == "" and ball_owner.role != "GK" and _hum_of(ball_owner) == null:
			tk["call"] = 0.0
			_pass(ball_owner, pm, ball_owner.position.distance_to(pm.position) > 24.0)
		# who had it last: passes, balls won and lost
		var bl = ball_owner
		if bl != null and bl != tk.get("last"):
			var was = tk.get("last")
			if was == pm:
				if bl.team == pm.team:
					tk["pok"] = int(tk.get("pok", 0)) + 1
				else:
					tk["lost"] = int(tk.get("lost", 0)) + 1
			if bl == pm:
				tk["tch"] = int(tk.get("tch", 0)) + 1
				if was != null and was.team != pm.team:
					tk["won"] = int(tk.get("won", 0)) + 1
			tk["prev"] = was
			tk["last"] = bl

# your rating for the match, 3 to 10, from what you did and how it went
func _pro_rating(h, k := "pro") -> float:
	var pm = _pro_man(h)
	var tk: Dictionary = h.ptrk
	var pos: String = str(car.pro_pl(k).get("pos", "MF"))
	var r := 6.0
	r += 1.1 * int(tk.get("g", 0)) + 0.8 * int(tk.get("a", 0))
	r += 0.07 * int(tk.get("pok", 0)) - 0.18 * int(tk.get("lost", 0)) + 0.22 * int(tk.get("won", 0))
	r += 0.12 * int(tk.get("sh", 0))
	r += 0.4 if score[0] > score[1] else (-0.4 if score[0] < score[1] else 0.0)
	if pos == "DF":
		r += 0.5 if score[1] == 0 else -0.15 * score[1]
	if int(tk.get("tch", 0)) < 3:
		r -= 0.5 # hardly in the game
	if pm != null and pm.off:
		r -= 1.0 # sent off
	return clampf(r, 3.0, 10.0)

# as a player the club's money and the board are not yours: those lines go
func _pro_lines(ls: Array) -> Array:
	return ls.filter(func(x): return not str(x).begins_with("+") and not str(x).begins_with("THE BOARD") and not "COINS" in str(x) and not "  +" in str(x))

func _switch(h) -> void:
	if h.psq >= 0 and _pro_man(h) != null and not _pro_man(h).off:
		# a player career: no switching. The button asks for the ball instead.
		h.ctrl = _pro_man(h)
		if ball_owner != null and ball_owner.team == 0 and ball_owner != h.ctrl:
			h.ptrk["call"] = 1.2
		return
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
	# Daniel: the game took away the man he had just switched to. A man you pick yourself stays yours
	# for a couple of seconds: no auto switch takes him, only you (SWITCH again) or a ball he wins.
	h.pick_t = 3.0
	if h.local:
		audio.play("click")

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
		if h.team == t and h.ctrl != null and h.switch_cool <= 0.0 and h.pick_t <= 0.0 and not _locked(h):
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
			if state == "play" and wd_all % 30 == 0:
				for tq in 2:
					for pq in teams[tq]:
						if pq.role != "GK":
							var ai := 0 if att_team == tq else 3
							tac_m[tq][ai] += pq.position.x * side(tq)
							tac_m[tq][ai + 1] += absf(pq.position.z)
							tac_m[tq][ai + 2] += 1.0
			if state == "full":
				for tq in 2:
					var tm2: Array = tac_m[tq]
					print("AUTOTEST tac team ", tq, " ", tac_t[tq], " with ball up/width=", snappedf(tm2[0] / maxf(tm2[2], 1), 0.1), "/", snappedf(tm2[1] / maxf(tm2[2], 1), 0.1),
						" without ball up/width=", snappedf(tm2[3] / maxf(tm2[5], 1), 0.1), "/", snappedf(tm2[4] / maxf(tm2[5], 1), 0.1))
				print("AUTOTEST score=", score, " stats=", stats, " bot=", bstats)
				print("AUTOTEST gk_hands frames=", get_meta("gk_n", 0), " nearest_opp_min=", snappedf(get_meta("gk_min", 99.0), 0.1))
				print("AUTOTEST team=", tst)
				print("AUTOTEST hold passes=", hold_m[0], " avg_on_ball=", snappedf(hold_m[1] / maxf(hold_m[0], 1), 0.01), " pressed=", snappedf(float(hold_m[3]) / maxf(hold_m[2], 1), 0.01))
				if def_dbg:
					print("AUTOTEST def frames=", def_m[0], " dfspeed=", snappedf(def_m[1] / maxf(def_m[0], 1), 0.01), " close4=", snappedf(float(def_m[2]) / maxf(def_m[0], 1), 0.01), " nobody_goalside=", snappedf(float(def_m[3]) / maxf(def_m[0], 1), 0.01))
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
	_cv_tick(dt)
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
		"tn": TEAM_NAMES, "ft": ft_on, "n20": players[20].pname if players.size() > 20 else "", "gname": _guest_name(), "own": _has_own(), "own_ft": opt_own, "gtm": guest_tm.size(), "me_xi": (_ft_me().get("xi", []) as Array).size(),
	}), true)
	# a test can press a menu button by name: window.bbDo = "action" or "action|arg"
	var cmd := str(JavaScriptBridge.eval("(function(){var c=window.bbDo||'';window.bbDo='';return c})()", true))
	if cmd != "":
		var cp := cmd.split("|")
		_action(cp[0], cp[1] if cp.size() > 1 else null)
	if test_ft > 0.0 and screen == "match" and state == "play" and net.role != "guest":
		if Time.get_ticks_msec() / 1000.0 - test_t > test_ft:
			_full_time()

func _tick(dt: float) -> void:
	state_t += dt
	thru_left -= dt
	if autotest and ball_owner != null and ball_owner.hands() and ball_owner.hold_t > 1.5:
		var gmin := 99.0
		for o in teams[1 - ball_owner.team]:
			gmin = minf(gmin, o.position.distance_to(ball_owner.position))
		set_meta("gk_min", minf(get_meta("gk_min", 99.0), gmin))
		set_meta("gk_n", get_meta("gk_n", 0) + 1)
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
			if so_on and state == "play":
				_so_watch(dt)
		"goal":
			_celebrate(dt)
			if state_t < 1.2:
				_record(dt)
		"replay":
			_replay(dt)
		"dead":
			_idle_players(dt)
			_ball_free(dt)
			_booking(dt)
			if state_t > float(dead_info.get("wait", 0.9)) and book_t < 0.0:
				_restart()
		"half":
			_idle_players(dt)
			if state_t > (4.0 if half >= 3 else 3.0):
				_kickoff(half_kick)
		"pens":
			_idle_players(dt)
			_ball_free(dt)
			if state_t > 2.4:
				if so_win >= 0:
					_so_end()
				else:
					_so_kick()
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

var sim_t := 0.0 # match time that the play itself has run (also in the fast tests, unlike real_t)

func _play(dt: float) -> void:
	tdt = dt
	sim_t += dt
	var gdt: float = dt * 5400.0 / LENGTHS[opt_len]
	clock += gdt
	# match fitness: everyone tires, those who run the most tire the most, and tired legs are slower
	for p in players:
		var sr: float = clampf(p.vel.length() / maxf(p.base_top, 1.0), 0.0, 1.2)
		p.fit = maxf(p.fit - gdt * (0.00002 + 0.00012 * sr * sr) * (0.6 if p.has_ab("motor") else 1.0), 0.0)
		p.top_speed = p.base_top * (0.84 + 0.16 * p.fit)
	mgr_t -= dt
	if mgr_t <= 0.0 and net.role != "guest":
		mgr_t = 2.0
		_managers()
	ignore_t -= dt
	protect_t -= dt
	if force_kind != "" and state_t > 3.0:
		if force_kind == "corner":
			_out("corner", Vector3(HL - 0.6, 0, HW - 0.6), 0)
		elif force_kind == "pen" or force_kind == "pen0":
			_out("pen", Vector3.ZERO, 0 if force_kind == "pen0" else 1, 2.0)
		elif force_kind == "so":
			_so_start()
		elif force_kind == "book":
			# test: a booking at a free kick
			ref_card.append([teams[1][4], "y"])
			_out("fk", Vector3(-10, 0, 6), 0, 1.4)
		elif force_kind == "et":
			# test: jump to the end of normal time with the score level
			score = [1, 1]
			clock = 5399.0
			half = 2
			force_kind = ""
			return
		else:
			_out("throw", Vector3(20, 0, HW - 0.3), 0)
		force_kind = ""
		return
	if demo and OS.get_cmdline_user_args().has("--abpop") and real_t - teams[0][9].ab_at > 1.0:
		teams[0][9].ab = ["kanon"]
		teams[0][9].ab_at = -99.0
		_ab_pop(teams[0][9], "kanon")
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
	if pro_sq >= 0:
		_pro_play(dt)
	# --- human buttons
	for h in humans:
		h.switch_cool -= dt
		h.pick_t -= dt
		if h.ctrl != null and h.pick_t > 0.0 and ball_owner == h.ctrl:
			h.pick_t = 0.0 # he has the ball now: from here the usual rules
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
					var m1 = _pass_target(h.ctrl, dir3, false, 0.5 if k1 == 2 else -1.0)
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
					var mt = _human_cross(h) if set_piece == "corner" else _pass_target(h.ctrl, dir3, false, maxf(tpw, 0.01), true)
					if mt == null and set_piece != "":
						mt = _pass_target(h.ctrl, Vector3.ZERO, false)
					if mt != null:
						if set_piece == "":
							# tap = a few metres in front of him, full meter = well into the space behind
							lead_dir = dir3
							_pass(h.ctrl, mt, h.hi, false, 0.9 + 1.6 * tpw)
							lead_dir = Vector3.ZERO
						else:
							_pass(h.ctrl, mt, h.hi or set_piece in ["corner", "gk"], set_piece == "corner")
				h.thru_hold = -1.0
			elif e == "shoot_down":
				if coming:
					h.ot = 3
					h.ot_t = 1.6
				elif mine and set_piece in ["corner", "throw"]:
					var cm = _human_cross(h) if set_piece == "corner" else _pass_target(h.ctrl, dir3, false)
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
				elif h.psq >= 0 and _pro_man(h) != null:
					# your own player: one tap and he runs his own position (Daniel: a tap, not a hold); with a team
					# mate on the ball the same tap also calls for it, and he moves into space to get it
					h.auto_on = true
					if ball_owner != null and ball_owner.team == h.team and ball_owner != h.ctrl:
						_switch(h)
				else:
					_switch(h)
			elif e == "pass_up":
				if h.pass_hold >= 0.0 and ball_owner == h.ctrl:
					var ppw: float = clampf(h.pass_hold / 0.6, 0.0, 1.0)
					pass_pw = ppw
					var m = _pass_target(h.ctrl, dir3, false, maxf(ppw, 0.01))
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
					var ml = _human_cross(h) if set_piece == "corner" else _pass_target(h.ctrl, dir3, false, maxf(0.3 + 0.7 * lpw, 0.01))
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
		if h.auto_on and (ball_owner == h.ctrl or h.stick.length() > 0.3 or not _locked(h)):
			h.auto_on = false # the ball is his, or you steer him again
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
			if h != null and h.switch_cool <= 0.0 and h.pick_t <= 0.0 and h.ctrl != null and not h.ctrl.recv:
				# Not while your man can still cut the ball out himself: standing in or near the path of an
				# opponent's pass you keep him, however close someone else is to where it will land.
				var ln: Vector3 = aim - ball.position
				ln.y = 0.0
				var hp: Vector3 = h.ctrl.position - ball.position
				hp.y = 0.0
				var tl: float = clampf(hp.dot(ln) / maxf(ln.length_squared(), 0.01), 0.0, 1.0)
				var in_lane: bool = (hp - ln * tl).length() < 5.0
				var margin := 3.0 if ball_last == null or ball_last.team == t else 6.0
				if h.stick.length() > 0.3:
					# you are steering him somewhere: only switch when the other man is clearly nearer
					margin += 4.0
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
		if not go_run.is_empty():
			for q2 in teams[ot]:
				var gid: int = q2.get_instance_id()
				if go_run.has(gid):
					if float(go_run[gid]) < sim_t or q2 == ball_owner:
						go_run.erase(gid)
					elif not runner[ot].has(q2) and _hum_of(q2) == null:
						sup[ot].erase(q2)
						runner[ot].append(q2)
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
			elif h.auto_on and ball_owner != p and set_piece == "":
				# auto-positioning: he moves like the computer would move him (runs, support, his place in the shape)
				want = _ai_offball(p, chaser, second, aim)
				h.stam = clampf(h.stam + 0.1 * dt, 0.0, 1.0)
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
		var tph0: float = o.touch_ph
		o.touch_ph = fmod(o.touch_ph + dt * 2.2, 1.0)
		# the little taps of a dribble, harder when he knocks it on at a sprint
		if o.touch_ph < tph0 and osp > 1.5 and set_piece == "" and not o.hands():
			snd("dribble", clampf(0.35 + osp / 10.0 + spk * 0.4, 0.35, 1.0))
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
		snd("whistle_half")
		snd("clap_big", 0.7)
		_banner("HALF TIME", Color(1, 1, 1), 2.2, "%d - %d" % [score[0], score[1]])
	elif half == 2 and clock >= 5400.0 and score[0] == score[1] and _needs_winner() and (ball_owner != null or clock > 5490.0 or autotest) and (absf(ball.position.x) < 32.0 or autotest or clock > 5550.0):
		# level after 90 minutes in a tie that needs a winner: two halves of extra time
		_break(3, 5400.0, randi() % 2, "EXTRA TIME", "2 x 15 MINUTES")
	elif half == 3 and clock >= 6300.0 and (ball_owner != null or clock > 6390.0 or autotest) and (absf(ball.position.x) < 32.0 or autotest or clock > 6450.0):
		_break(4, 6300.0, 1 - et_kick, "HALF TIME", "EXTRA TIME  %d - %d" % [score[0], score[1]])
	elif half == 4 and clock >= 7200.0 and (ball_owner != null or clock > 7290.0 or autotest) and (absf(ball.position.x) < 32.0 or autotest or clock > 7350.0):
		if score[0] == score[1]:
			_so_start()
		else:
			_full_time()
	elif half == 2 and clock >= 5400.0 and (ball_owner != null or clock > 5490.0 or autotest) and (absf(ball.position.x) < 32.0 or autotest or clock > 5550.0):
		_full_time()

# a cup tie, or a single match where you play against each other, cannot end level
func _needs_winner() -> bool:
	if rk_on:
		# ranked is like a league match: a draw is a draw
		return false
	if cup_on:
		return true
	if career_on:
		return false
	return _team_human(0) and _team_human(1)

func _break(nh: int, at: float, kicker: int, title: String, small: String) -> void:
	half = nh
	clock = at
	half_kick = kicker
	if nh == 3:
		et_kick = kicker
	for p in players:
		p.fit = minf(p.fit + 0.05, 1.0)
	state = "half"
	state_t = 0.0
	ball_owner = null
	ball_vel = Vector3.ZERO
	hud.show_controls = false
	snd("whistle_half")
	snd("clap", 0.8)
	_banner(title, Color(1.0, 0.86, 0.2) if nh == 3 else Color(1, 1, 1), 2.6, small, 84)
	if nh == 3:
		fx("say", "Still level after ninety minutes. We go to extra time!")

# ---------------------------------------------------------------- penalty shootout

func _so_start() -> void:
	so_on = true
	so_g = [0, 0]
	so_n = [0, 0]
	so_win = -1
	so_turn = randi() % 2
	half = 5
	state = "pens"
	state_t = -1.2
	ball_owner = null
	ball_vel = Vector3.ZERO
	hud.show_controls = false
	snd("whistle_long")
	_banner("PENALTIES", Color(1.0, 0.86, 0.2), 3.0, "FIVE EACH, THEN SUDDEN DEATH", 96)
	fx("say", "It is still level. This one goes to penalties!")
	fx("excite", 0.8)

# the five men who take them, then the rest; the keeper takes the eleventh
const SO_ORDER := [9, 10, 8, 7, 6, 5, 4, 3, 2, 1, 0]

func _so_taker(t: int):
	var list := []
	for i in SO_ORDER:
		if i < teams[t].size() and not teams[t][i].off:
			list.append(teams[t][i])
	return list[int(so_n[t]) % list.size()]

func _so_kick() -> void:
	var t := so_turn
	var taker = _so_taker(t)
	dead_info = {"kind": "pen", "pos": Vector3.ZERO, "team": t, "wait": 0.0, "taker": taker}
	_restart()
	so_shot = false
	so_t = 0.0
	# everyone else waits in the centre circle
	var n := 0
	for p in players:
		if p.off or p == taker or (p.role == "GK" and p.team != t):
			continue
		p.position = Vector3(cos(n * 0.33) * 7.5, 0, sin(n * 0.33) * 7.5 - 0.5) if p.role != "GK" else Vector3(-side(t) * 6.0, 0, 9.0)
		p.vel = Vector3.ZERO
		p.stun = 1e5
		n += 1
	# with two of you on a team you take turns at the spot
	var mine := []
	for h in humans:
		if h.team == t:
			mine.append(h)
	if not mine.is_empty():
		var hh = mine[int(so_n[t]) % mine.size()]
		for h in mine:
			if h != hh and h.ctrl == taker:
				h.ctrl = null
		hh.ctrl = taker
		hh.dead_t = 0.0
		for h in mine:
			if h.ctrl == null:
				h.ctrl = teams[t][1]
	for h in humans:
		if h.team != t:
			h.ctrl = teams[h.team][0]
	hud.show_controls = screen == "match" and humans.size() > 0
	protect_t = 0.0
	taker.ai_cool = 1.4

# the shot is on its way: goal, save, wide or over decides it
func _so_watch(dt: float) -> void:
	if not so_shot:
		if set_piece != "pen":
			so_shot = true
		return
	so_t += dt
	var sp := Vector2(ball_vel.x, ball_vel.z).length()
	# a save counts as a miss even if it rolls in afterwards
	var saved: bool = ball_last != null and ball_last.team != so_turn
	if so_t > 3.0 or saved or (ball_owner != null and so_t > 0.1) or (so_t > 0.8 and sp < 1.5):
		_so_result(false, saved)

func _so_result(scored: bool, saved := false) -> void:
	var t := so_turn
	so_n[t] += 1
	if scored:
		so_g[t] += 1
	so_last = scored
	# decided? In the first five each, when the other side cannot catch up; after that, after each pair
	var a: int = so_g[0]
	var b: int = so_g[1]
	var ra: int = maxi(5 - int(so_n[0]), 0)
	var rb: int = maxi(5 - int(so_n[1]), 0)
	if int(so_n[0]) <= 5 and int(so_n[1]) <= 5 and (a > b + rb or b > a + ra):
		so_win = 0 if a > b else 1
	elif int(so_n[0]) >= 5 and so_n[0] == so_n[1] and a != b:
		so_win = 0 if a > b else 1
	if autotest:
		print("SOTEST team=", t, " scored=", scored, " saved=", saved, " tally=", so_g, " n=", so_n, " win=", so_win, " taker=", players.find(ball_last))
	so_turn = 1 - t
	state = "pens"
	state_t = 0.0
	ball_owner = null
	hud.show_controls = false
	var tally := "PENALTIES  %d - %d" % [a, b]
	if scored:
		snd("net")
		fx("goal_snd", t)
		fx("flash", 0.4)
		fx("excite", 0.9)
		_banner("SCORED!", Color(1.0, 0.86, 0.2), 1.8, tally, 96)
		fx("say", "Scored!")
	else:
		snd("ooh")
		_banner("MISSED!", Color(1.0, 0.45, 0.4), 1.8, tally, 96)
		fx("say", "Saved!" if saved else "Missed!")

func _so_end() -> void:
	so_on = false
	so_done = true
	var w: String = TEAM_NAMES[so_win].to_upper()
	_banner("%s WIN!" % w, Color(1.0, 0.86, 0.2), 3.0, "%d - %d ON PENALTIES" % [so_g[0], so_g[1]], 84)
	fx("confetti", HL * 0.72 * side(so_win))
	fx("say", "%s win it on penalties!" % TEAM_NAMES[so_win].capitalize())
	_full_time()

# who won the match: the score, or the shootout after a draw (-1 = a draw)
func _winner() -> int:
	if score[0] != score[1]:
		return 0 if score[0] > score[1] else 1
	return so_win

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
	snd("whistle_full")
	snd("clap_big")
	for p in players:
		p.mood_t = 0.0
		p.mood = 0 if score[0] == score[1] else (2 if (score[p.team] > score[1 - p.team]) else 3)
	fx("say", "Full time! %s %d, %s %d." % [TEAM_NAMES[0].capitalize(), score[0], TEAM_NAMES[1].capitalize(), score[1]])
	var ti0 := int(car.stats().get("titles", 0)) if career_on and not cup_on and car.has_save() else -1
	if score[0] != score[1]:
		fx("excite", 0.6)
	if rk_on:
		_rk_finish()
	elif nat_on:
		car_lines = car.nat_finish(score[0], score[1], _winner() == 0)
		adv_from = car.today()
		co_pay = [0, _winner() == 0, car_lines.slice(0, 2)]
	elif career_on and eu_on:
		car_lines = car.eu_finish(score[0], score[1], _winner() == 0)
		adv_from = car.today() if (car == carc or car == proc) and in_career else -99
		co_pay = [car.last_coins, _winner() == 0, ([car_lines[1]] if car_lines.size() > 1 else [])]
		_car_coins(false)
	elif career_on and cup_on:
		car_lines = car.cup_finish(score[0], score[1], _winner() == 0)
		adv_from = car.today() if (car == carc or car == proc) and in_career else -99
		if cup_mode:
			# no board in the cup mode
			car_lines = car_lines.filter(func(x): return not str(x).begins_with("THE BOARD"))
			# the cup mode pays your club at home
			car_main.d["coins"] = int(car_main.d["coins"]) + car.last_coins
			car_main.save()
			_cm_sync()
		co_pay = [car.last_coins, _winner() == 0, ([car_lines[2]] if car_lines.size() > 2 else []) + ([car_lines[1]] if car_lines.size() > 1 else [])]
		_car_coins(false)
	elif career_on:
		car_lines = car.finish_match(score[0], score[1], car_goals, sub_played)
		adv_from = car.today() if (car == carc or car == proc) and in_career else -99
		car_lines.append("%s IN THE TABLE" % Career.ordinal(car.rank_of(int(car.d["club"]))))
		_car_coins(true)
		co_pay = [car.last_coins, score[0] > score[1], [car_lines[car_lines.size() - 1], car_lines[1]] + ([str(car.d["note"])] if car.season_over() else [])]
	elif net.role != "":
		car_lines = _friend_reward()
	if career_on and pro_sq >= 0 and car.pro():
		var pl9: Array = []
		for hi in humans.size():
			var h9 = humans[hi]
			if h9.psq < 0:
				continue
			var k9 := "pro" if hi == 0 else "pro2"
			var on_p: bool = _pro_man(h9) != null
			var xb := {"lv0": car.pro_lv(k9), "x0": int(car.pro_d(k9).get("pxp", 0)), "n0": car.pro_need(k9), "rt": snappedf(_pro_rating(h9, k9), 0.1) if on_p else -1.0}
			var l9: Array = car.pro_after(_pro_rating(h9, k9), int(h9.ptrk.get("g", 0)), int(h9.ptrk.get("a", 0)), on_p, on_p, k9)
			xb["lv1"] = car.pro_lv(k9)
			xb["x1"] = int(car.pro_d(k9).get("pxp", 0))
			xb["n1"] = car.pro_need(k9)
			if hi == 0:
				pl9 = l9
				pro_bar = xb
			elif co_pay.size() > 2:
				# the friend's own rating goes to his phone with the result, and his XP bar
				co_pay[2] = l9 + (co_pay[2] as Array)
				co_pay.append(xb)
		car_lines = pl9 + _pro_lines(car_lines)
		if car.pro2():
			car.pro_select("pro")
			car.pro_select("pro2")
		if has_meta("pro_fast"):
			print("PRO full time lines=", car_lines.slice(0, 4), " pro2 lv=", car.pro_lv("pro2"), " xp=", car.pro_d("pro2").get("pxp"), " co2=", (co_pay[2] as Array).slice(0, 3) if co_pay.size() > 2 else [])
		car.pro_select()
		car.save()
		pro_sq = -1
	_rec_add(ti0 >= 0 and int(car.stats().get("titles", 0)) > ti0)
	hud.show_menu("full", _menu_info())

# A match in a friend's room pays your own club a little, on both phones: a few coins and XP for your eleven.
# No form or energy is used. (A career played together pays through the career instead.)
const FRIEND_COINS := [20, 10, 5] # win, draw, loss
func _friend_reward() -> Array:
	if not car_main.has_save():
		return []
	var mt := 0
	for h in humans:
		if h.local:
			mt = h.team
			break
	var w := _winner()
	var k := 1 if w < 0 else (0 if w == mt else 2)
	var lines: Array = car_main.coop_reward(FRIEND_COINS[k], k == 0)
	car_main.save()
	return lines

# Your record on the Profile tab: every match you play counts, in every mode, on both phones.
func _rec() -> Dictionary:
	if not car_main.has_save():
		return {}
	if not car_main.d.has("rec"):
		# the first time: start from what the club and the career have played so far
		var r := {"p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "titles": 0}
		for c in [car_main, carc]:
			if c.has_save() and c.d.has("st"):
				for k in r:
					r[k] = int(r[k]) + int(c.d["st"].get(k, 0))
		car_main.d["rec"] = r
	return car_main.d["rec"]

func _rec_add(title: bool) -> void:
	var r := _rec()
	if r.is_empty():
		return
	var mt := -1
	for h in humans:
		if h.local:
			mt = h.team
			break
	if mt < 0:
		return
	var w := _winner()
	r["p"] = int(r["p"]) + 1
	var k := "d" if w < 0 else ("w" if w == mt else "l")
	r[k] = int(r[k]) + 1
	r["gf"] = int(r["gf"]) + score[mt]
	r["ga"] = int(r["ga"]) + score[1 - mt]
	if title:
		r["titles"] = int(r["titles"]) + 1
	car_main.save()

func _idle_players(dt: float) -> void:
	for p in players:
		_move(p, Vector3.ZERO, dt)

func _move(p, want: Vector3, dt: float) -> void:
	if p.tackle_t >= 0.0 and p.tackle_t < SLIDE_T and p.slide_live:
		# sliding on the grass, the 2D game's curve: a burst that eases off to under half
		var sk: float = 0.45 + 0.55 * (1.0 - p.tackle_t / SLIDE_T)
		p.vel = p.slide_dir * SLIDE_V * sk * p.slide_k
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
	if ball.position.y < BALL_R + 0.03 or ball_owner != null:
		# on the grass (or at his feet) it rolls: it turns exactly as fast as it travels, so it never seems to slide
		var roll := Vector3.ZERO
		if sp > 0.05:
			roll = Vector3(h.z, 0, -h.x) / BALL_R
		ball_wv = ball_wv.lerp(roll, clampf(dt * 14.0, 0.0, 1.0))
	else:
		# in the air it keeps the spin the boot gave it, slowly fading
		ball_wv *= maxf(1.0 - 0.25 * dt, 0.0)
	var w := ball_wv.length()
	if w > 0.05:
		ball_mesh.rotate(ball_wv / w, w * dt)

# Ball physics (our own model, not a rigid body: players, keepers, passes and the landing ring all have to
# know where it will be, so they use the same sums). In the air: gravity, air drag that grows with the
# square of the speed (a hard shot loses pace on its way), curl (side spin) and backspin/topspin (Magnus:
# a lofted ball with backspin hangs, a driven shot with topspin dips). On the grass: bounces that get
# smaller each time, backspin bites on landing, then it rolls with rolling friction.
const AIR_K := 0.0105
const ROLL_DRAG := 0.05

func _air_vel(v: Vector3, curl: float, bs: float, dt: float) -> Vector3:
	v.y -= 9.8 * dt
	v -= v * (AIR_K * v.length() * dt)
	if curl != 0.0:
		v = v.rotated(Vector3.UP, curl * dt)
	if bs != 0.0:
		var hd := Vector3(v.x, 0, v.z)
		if hd.length() > 0.5:
			v = v.rotated(hd.normalized().cross(Vector3.UP), bs * dt)
	return v

# where a ball in flight is after t seconds (it does not touch the ground on the way)
func _fly_pos(pos: Vector3, v: Vector3, curl: float, bs: float, t: float) -> Vector3:
	var st := 1.0 / 60.0
	var n := int(ceil(t / st))
	if n < 1:
		return pos
	st = t / n
	for i in n:
		v = _air_vel(v, curl, bs * exp(-0.12 * i * st), st)
		pos += v * st
	return pos

# the same flight in the old, almost drag-free model the kicks were aimed with
func _fly_pos_plain(pos: Vector3, v: Vector3, curl: float, t: float) -> Vector3:
	var st := 1.0 / 60.0
	var n := int(ceil(t / st))
	if n < 1:
		return pos
	st = t / n
	for i in n:
		v.y -= 9.8 * st
		v *= 1.0 - 0.05 * st
		if curl != 0.0:
			v = v.rotated(Vector3.UP, curl * st)
		pos += v * st
	return pos

# where (and when) the ball now in the air comes down
var _land_k := [Vector3.INF, Vector3.INF]
var _land_c := [Vector3.ZERO, 0.0]
func _land() -> Array:
	if _land_k[0] == ball.position and _land_k[1] == ball_vel:
		return _land_c
	_land_k = [ball.position, ball_vel]
	var pos := ball.position
	var v := ball_vel
	var bs := ball_bs
	var st := 1.0 / 60.0
	var t := 0.0
	while t < 4.0:
		v = _air_vel(v, ball_spin, bs, st)
		bs *= 1.0 - 0.12 * st
		pos += v * st
		t += st
		if pos.y <= BALL_R and v.y < 0.0:
			break
	pos.y = 0.0
	_land_c = [pos, t]
	return _land_c

# The kick formulas aim with the old near-drag-free flight and a flight time t. Keep the spot and the time
# and find the strike that gets there through the real air: harder off the foot, it slows on its way.
func _fit_flight(v0: Vector3, t: float) -> void:
	if t <= 0.05:
		return
	var from := ball.position
	var tgt := _fly_pos_plain(from, v0, ball_spin, t)
	var v := v0
	for i in 6:
		var e := tgt - _fly_pos(from, v, ball_spin, ball_bs, t)
		if e.length() < 0.03:
			break
		v += e / t
	ball_vel = v

func _ball_free(dt: float) -> void:
	if ball.position.y > BALL_R + 0.01 or ball_vel.y > 0.0:
		ball_vel = _air_vel(ball_vel, ball_spin, ball_bs, dt)
		ball_bs *= maxf(1.0 - 0.12 * dt, 0.0)
	else:
		ball_vel.y -= 9.8 * dt
		ball_vel *= 1.0 - ROLL_DRAG * dt
		if ball_spin != 0.0:
			ball_vel = ball_vel.rotated(Vector3.UP, ball_spin * dt)
	ball.position += ball_vel * dt
	if ball.position.y <= BALL_R:
		ball.position.y = BALL_R
		ball_spin *= maxf(1.0 - 5.0 * dt, 0.0)
		if ball_vel.y < -1.4:
			# each bounce is lower: a soft pitch takes more out of a hard landing
			var vin := -ball_vel.y
			ball_vel.y = vin * clampf(0.64 - 0.012 * vin, 0.48, 0.6)
			# the grass grips the ball: backspin bites and checks it, topspin skids on
			var grip := clampf(0.82 - 1.7 * ball_bs, 0.6, 0.9)
			ball_vel.x *= grip
			ball_vel.z *= grip
			ball_bs *= 0.3
			ball_wv *= 0.5
			if ball_vel.y > 1.2:
				snd("bounce", clampf(ball_vel.y / 7.0, 0.3, 1.0))
		else:
			ball_vel.y = 0.0
			ball_bs = 0.0
		var h := Vector2(ball_vel.x, ball_vel.z)
		var sp := h.length()
		if sp > 0.0:
			var ns := maxf(sp - (ROLL_C + (ROLL_K - ROLL_DRAG) * sp) * dt, 0.0)
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
	var drag := ROLL_C + ROLL_K * sp
	var t_stop := sp / drag
	var b0 := Vector3(ball.position.x, 0, ball.position.z)
	var out := b0
	var t := 0.1
	# a through ball is run ONTO: he keeps his run going and meets it out in the space it was played into,
	# he does not stop or come back to cut it off on the way
	if p == thru_rx and thru_left > 0.0:
		t = maxf(0.1, thru_left * 0.85)
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
		var o2: Vector3 = _land()[0]
		o2.x = clampf(o2.x, -HL, HL)
		o2.z = clampf(o2.z, -HW, HW)
		return o2
	var travel := sp * t - 0.5 * (ROLL_C + ROLL_K * sp) * t * t
	var out := p + v / sp * maxf(travel, 0.0)
	out.y = 0.0
	return out

# ---------------------------------------------------------------- kicking

func _release(p, v: Vector3, kind := 0, fit_t := 0.0, bs := 0.0, curl := 0.0) -> void:
	var h := Vector3(v.x, 0, v.z).normalized()
	p.yaw = atan2(-h.x, -h.z)
	p.start_kick(clampf((v.length() - 9.0) / 20.0, 0.2, 1.0), kind)
	ball_owner = null
	ball.position = p.position + h * 0.75 + Vector3(0, BALL_R + 0.05, 0)
	if kind == 2:
		ball.position = p.position + h * 0.4 + Vector3(0, 2.3, 0)
	ball_vel = v
	ball_spin = curl
	ball_bs = bs
	_fit_flight(v, fit_t)
	# what the boot puts on it, for drawing: backspin turns it against the way it rolls, curl about the vertical
	var hr := Vector3(ball_vel.x, 0, ball_vel.z)
	ball_wv = Vector3.ZERO
	if hr.length() > 0.5:
		ball_wv = Vector3(hr.z, 0, -hr.x).normalized() * (-bs * 140.0 + 4.0)
	ball_wv += Vector3.UP * curl * 18.0
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

# A human pass like FIFA: the stick picks the direction, and the NEAREST team mate in that direction
# gets it. Only a longer hold (power past the first third of the meter) reaches for a man further away.
# pw is the power 0..1 (-1 = plain tap). Defenders in the lane or a marker do not change who it goes to.
func _human_target(p, dir3: Vector3, pw: float, thru := false):
	var dn := Vector3(dir3.x, 0, dir3.z).normalized()
	var s := side(p.team)
	var cand := []
	for m in teams[p.team]:
		if m == p or m.stun > 0.0:
			continue
		# where he is about to be: a runner is picked by where he is going
		var fut: Vector3 = m.position + Vector3(m.vel.x, 0, m.vel.z) * (0.45 if thru else 0.25)
		var to: Vector3 = fut - p.position
		to.y = 0.0
		var d := to.length()
		if d < 3.0 or d > 55.0:
			continue
		cand.append([m, d, dn.dot(to / d)])
	# Nearest in the direction you aim: angle and distance are weighed together, so a man a bit off
	# the line close by beats one dead on the line far away (like FIFA). The wide cone is only used
	# when nobody is roughly where you point.
	for cone in [0.5, 0.0]:
		var ins := []
		var near := 1e9
		for c in cand:
			if c[2] >= cone:
				ins.append(c)
				near = minf(near, c[1])
		if ins.is_empty():
			continue
		# a normal press is a tap; only a clear hold (over half the meter) reaches for a man further on
		var eff := clampf((pw - 0.5) / 0.5, 0.0, 1.0)
		var want := lerpf(near, 45.0, eff)
		var best = null
		var bs := 1e9
		for c in ins:
			var m = c[0]
			var d: float = c[1]
			# 30 degrees off the line costs as much as 13 m further away
			var sc: float = (1.0 - c[2]) * 18.0
			sc += (d * 0.18) if eff <= 0.0 else absf(d - want) * 0.16
			if m.role == "GK":
				sc += 4.0
			if thru:
				sc -= clampf(m.vel.x * s, 0.0, 8.0) * 0.08
			if set_piece in ["", "fk", "kick"] and _is_offside(p, m):
				sc += 1.0
			if sc < bs:
				bs = sc
				best = m
		return best
	return null

func _pass_target(p, dir3: Vector3, ai: bool, want_d := -1.0, thru := false):
	if not ai and dir3.length() <= 0.25 and set_piece == "" and p.role != "GK":
		# no stick: FIFA passes the way the player is facing
		dir3 = p.fwd()
	if not ai and dir3.length() > 0.25 and set_piece != "corner":
		var pw := -1.0 if want_d <= 0.0 else want_d
		return _human_target(p, dir3, pw, thru)
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
			sc += n.x * s * (2.2 if ai and p.position.x * s > 0.0 else 1.6) - absf(d - 15.0) * 0.04
			if ai and p.position.x * s > -22.0:
				# in their half the computer looks for the dangerous ball: a man near goal, in the box, between the lines
				var gdm: float = Vector2(HL * s - m.position.x, m.position.z).length()
				sc += clampf(32.0 - gdm, 0.0, 20.0) * 0.11 * _ai_vision(p.team)
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
		if ai and mark > 2.5 and _is_pro_man(m):
			# the player career: your team mates look for you when you are free, more the further forward you are
			sc += 1.2 + clampf((m.position.x - p.position.x) * s, 0.0, 12.0) * 0.06
		if sc > bs:
			bs = sc
			best = m
	return best

# Rolling ball: it slows by 1.3 + 0.33 * speed per second (see _ball_free).
const ROLL_C := 1.3
const ROLL_K := 0.33

# the speed off the foot that rolls the ball dd metres in t seconds
func _roll_speed(dd: float, t: float) -> float:
	var e := 1.0 - exp(-ROLL_K * t)
	var v0 := (dd + ROLL_C / ROLL_K * t) * ROLL_K / maxf(e, 0.001) - ROLL_C / ROLL_K
	# never so soft that it stops short of the spot
	var lo := 0.0
	var hi := 40.0
	for i in 24:
		var mid := (lo + hi) * 0.5
		var stop := mid / ROLL_K - ROLL_C / (ROLL_K * ROLL_K) * log(1.0 + ROLL_K * mid / ROLL_C)
		if stop < dd + 0.5:
			lo = mid
		else:
			hi = mid
	return maxf(v0, hi)

# how fast it is still rolling after t seconds
func _roll_left(v0: float, t: float) -> float:
	return maxf((v0 + ROLL_C / ROLL_K) * exp(-ROLL_K * t) - ROLL_C / ROLL_K, 0.0)

var lead_dir := Vector3.ZERO
var loft_at := -99.0 # when the last high pass was struck (sim_t)
var thru_rx = null
var thru_left := 0.0

func _pass(p, m, lofted: bool, cross := false, lead := 0.0) -> void:
	var to: Vector3 = m.position - p.position
	to.y = 0.0
	var d := to.length()
	var v := Vector3.ZERO
	var thrown := set_piece == "throw"
	var leadv := Vector3.ZERO
	var thru_v := -1.0
	var thru_t := 0.0
	# flight time the high balls are aimed with, and the backspin on them
	var ft := 0.0
	var fb := 0.0
	if lead > 0.0:
		# A through ball goes where the runner will BE when it gets there, weighted so it slows down
		# in front of him: lead is the time (s) he gets to run onto it, not a distance.
		var md: Vector3 = m.vel
		md.y = 0.0
		# Into the space he is running into: his run, the way you pushed the stick and towards goal,
		# and in the last third it bends in towards the goal instead of out to the corner flag.
		var sx := float(side(p.team))
		var rd := Vector3(sx, 0, 0) * 0.55
		if md.length() > 1.5:
			rd += md.normalized() * 0.65
		if lead_dir.length() > 0.25:
			rd += lead_dir.normalized() * 0.45
		if (m.position.x * sx) > HL - 36.0:
			var tog: Vector3 = Vector3(HL * sx, 0, 0) - m.position
			tog.y = 0.0
			rd += tog.normalized() * 0.5
		if rd.x * sx < 0.15:
			rd.x = 0.15 * sx
		rd = rd.normalized()
		var vr: float = m.top_speed * 0.82
		var tl := lead
		var spot: Vector3 = m.position
		for it in 30:
			spot = m.position + rd * vr * tl
			spot.x = clampf(spot.x, -HL + 7.0, HL - 7.0)
			spot.z = clampf(spot.z, -HW + 3.0, HW - 3.0)
			var dd: float = Vector2(spot.x - p.position.x, spot.z - p.position.z).length()
			if lofted:
				thru_t = clampf(0.62 + dd * 0.034, 0.8, 2.15)
				# in the air it lands a step short of him and runs on with him
				if absf(thru_t * 0.85 - tl) < 0.05:
					break
				tl = thru_t * 0.85
				continue
			# A real through ball is struck firmly: it gets to the spot a little before him and keeps rolling
			# on into his path, so he runs onto it at speed instead of waiting for it (Daniel: "for svag").
			thru_v = _roll_speed(dd, (tl + 0.12) * 0.9)
			# too hard to control: give him a little longer and look again
			if (thru_v <= 28.0 and _roll_left(thru_v, (tl + 0.12) * 0.9) <= 12.5) or tl > 3.3:
				break
			tl += 0.08
		leadv = spot - m.position
		leadv.y = 0.0
		thru_rx = m
		thru_left = tl + 0.12
		if OS.get_cmdline_user_args().has("--picktest"):
			# who does a human pass go to? tap = nearest in the stick direction, hold = further
			_kickoff(0)
			var pp = teams[0][6]
			pp.position = Vector3(-10, 0, 0)
			var spots := [Vector3(-2, 0, 2), Vector3(14, 0, -3), Vector3(2, 0, 11), Vector3(-10, 0, -14), Vector3(-26, 0, 0)]
			var who := []
			for i in spots.size():
				var q = teams[0][[9, 10, 8, 2, 3][i]]
				q.position = spots[i]
				q.vel = Vector3.ZERO
				who.append(q)
			for q in teams[0]:
				if not (q in who) and q != pp:
					q.position = Vector3(-HL + 1, 0, HW - 1)
			for q in teams[1]:
				q.position = Vector3(40, 0, 30)
			for c in [[Vector2(1, 0), -1.0], [Vector2(1, 0), 0.3], [Vector2(1, 0), 0.5], [Vector2(1, 0), 0.75], [Vector2(1, 0), 1.0], [Vector2(1, 0.45), -1.0], [Vector2(0, 0), -1.0], [Vector2(1, 0.8), -1.0], [Vector2(0.3, 1), -1.0], [Vector2(0, -1), -1.0], [Vector2(-1, 0), -1.0], [Vector2(1, -0.25), -1.0]]:
				var st: Vector2 = c[0].normalized()
				var mm = _pass_target(pp, Vector3(st.x, 0, st.y), false, c[1])
				print("PICKTEST stick=", st, " pw=", c[1], " -> ", (who.find(mm) if mm != null else -1), " at ", (mm.position if mm != null else Vector3.ZERO))
			get_tree().quit()
			return
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
		ft = tt
		fb = 0.03
	elif cross:
		# whipped in to arrive at head height
		var aim4: Vector3 = m.position + m.vel * (d / clampf(11.0 + d * 0.32, 15.0, 22.0)) * 0.5
		if cross_spot is Vector3:
			aim4 = cross_spot
			cross_spot = null
		var dc: float = Vector2(aim4.x - p.position.x, aim4.z - p.position.z).length()
		var vc := clampf(11.0 + dc * 0.32, 15.0, 22.0)
		var tc := dc / vc
		var dir4: Vector3 = aim4 - p.position
		dir4.y = 0.0
		tc = dir4.length() / vc
		v = dir4.normalized() * vc + Vector3(0, (2.05 - 0.3) / tc + 4.9 * tc, 0)
		ft = tc
		fb = 0.04
	elif not lofted:
		var sp := clampf(8.0 + d * 0.75, 12.0, 27.0)
		if pass_pw >= 0.0:
			# a held pass is struck harder
			sp = minf(sp * lerpf(0.97, 1.18, pass_pw), 29.0)
		var aim: Vector3 = (m.position + leadv) if lead > 0.0 else (m.position + m.vel * (d / sp) * 0.8)
		aim.x = clampf(aim.x, -HL + 3.0, HL - 3.0)
		aim.z = clampf(aim.z, -HW + 2.0, HW - 2.0)
		var dir: Vector3 = (aim - p.position)
		dir.y = 0.0
		if lead > 0.0:
			# weighted to slow down in front of him
			sp = clampf(thru_v, 11.0, 27.0)
		v = dir.normalized() * sp + Vector3(0, 0.6, 0)
	else:
		# a real high ball: about 1.0 s over 10 m, 1.6 s over 30 m, and drops at the receiver's feet
		var t := clampf(0.62 + d * 0.034, 0.8, 2.15)
		var aim2: Vector3 = (m.position + leadv) if lead > 0.0 else (m.position + m.vel * t * 0.7 + Vector3(side(p.team) * 2.0, 0, 0))
		aim2.x = clampf(aim2.x, -HL + 3.0, HL - 3.0)
		aim2.z = clampf(aim2.z, -HW + 2.0, HW - 2.0)
		var dir2: Vector3 = (aim2 - p.position)
		dir2.y = 0.0
		t = clampf(0.62 + dir2.length() * 0.034, 0.8, 2.15)
		var vh := dir2.length() / t * (1.0 + 0.026 * t)
		v = dir2.normalized() * vh + Vector3(0, 4.9 * t + 0.12 * t * t, 0)
		# struck under the ball: backspin makes it hang and then sit down where it lands
		ft = t
		fb = 0.10
	var perr: float = maxf(92 - p.pas, 0) * 0.0011 * (1.6 if lofted else 1.0)
	if p.has_ab("dirigent"):
		perr *= 0.35
		if d > 20.0 or lead > 0.0:
			_ab_pop(p, "dirigent")
	v = v.rotated(Vector3.UP, (randf() - 0.5) * 2.0 * perr)
	var h = _hum_of(p)
	var offs: bool = set_piece in ["", "fk", "kick"] and _is_offside(p, m)
	_release(p, v, 2 if thrown else 0, ft, fb)
	if lofted and not thrown:
		loft_at = sim_t
	if cross:
		ball_spin = 0.0
		ball_bs = 0.0
	m.recv = true
	if offs:
		m.offside = true
		off_spot = m.position
	stats["passes"] += 1
	pass_from = p
	pass_pw = -1.0
	if thrown:
		snd("touch", 0.25)
	else:
		var pv := v.length()
		snd("pass" if (lofted or d > 22.0 or pv > 17.0) else "touch", clampf(pv / 24.0, 0.5, 1.0))
	if lofted and not thrown:
		fx("shake", 0.1)
	if h == null and set_piece == "" and not lofted and p.role in ["MF", "FW"] and p.position.x * side(p.team) > -6.0 and (m.position.x - p.position.x) * side(p.team) > -8.0:
		# the computer plays and goes: after a pass in their half he runs on for the return (one-two)
		go_run[p.get_instance_id()] = sim_t + 2.6
	if h != null and m.role != "GK" and _hum_of(m) == null:
		# Co-op: a pass goes to your partner. When one of you passes, the other one gets the man on the ball
		# (Daniel: "aflevere jeg skal min far modtage den og omvendt"); you keep the passer and can run on.
		# Playing alone you follow your own pass.
		var taker = h
		for q in humans:
			if q != h and q.team == h.team and q.ctrl != null and not q.ctrl.off:
				taker = q
				break
		taker.ctrl = m
		taker.switch_cool = 0.5
		if taker != h:
			h.switch_cool = 0.5
			if taker.local:
				audio.play("click")
	if _team_human(1 - p.team):
		_switch_for_pass(1 - p.team, m)

# A penalty like FIFA: it goes where it is aimed (only a hair of error), the power sets the height
# (a full-power one can fly over), and the keeper guesses a side as it is struck instead of reading it.
func _pen_kick(p, power: float, aim_z: float) -> void:
	var s := side(p.team)
	var from := ball.position
	# Like FIFA: it never lands exactly where you aimed. How far off depends on his shooting and on how hard
	# he hits it (a soft one is placed, a full-power one sprays). Most land close to the aim, a few well off.
	var sn: float = clampf((p.sho - 40) / 50.0, 0.0, 1.0)
	var spread: float = lerpf(0.8, 0.25, sn) * (0.65 + 0.7 * power)
	var err: float = (randf() + randf() - 1.0) * spread
	if absf(aim_z) > 0.6 and signf(aim_z + err) != signf(aim_z):
		# a miss can drift wide or towards the middle, never across to the other side of the goal
		err = -aim_z * 0.85
	var goal := Vector3(HL * s, 0, clampf(aim_z + err, -GOAL_HW - 0.6, GOAL_HW + 0.6))
	var dir := goal - from
	dir.y = 0.0
	var d := dir.length()
	dir = dir.normalized()
	var sp := 15.0 + 13.0 * power
	var t := maxf(d / sp, 0.15)
	var hgt := maxf(0.22 + power * power * 2.75 + (randf() + randf() - 1.0) * spread * 0.45, 0.15)
	var vy := (hgt - 0.25) / t + 4.9 * t
	pen_shot = true
	shot_hard = 0.0
	var gk = teams[1 - p.team][0]
	var goes := signf(goal.z) if absf(goal.z) > 0.9 else 0.0
	var right := 0.3 + clampf((gk.dfn - 60) / 30.0, 0.0, 1.0) * 0.08 + (0.14 if gk.has_ab("straf") else 0.0)
	var r := randf()
	if r < 0.12:
		gk.pen_z = 0.0
	elif goes == 0.0:
		gk.pen_z = (1.0 if randf() < 0.5 else -1.0) * GOAL_HW * 0.5
	else:
		gk.pen_z = goes * GOAL_HW * 0.5 * (1.0 if r < 0.12 + right else -1.0)
	if autotest:
		print("PENKICK sho=", p.sho, " want=", snappedf(aim_z, 0.1), " aim=", snappedf(goal.z, 0.1), " guess=", snappedf(gk.pen_z, 0.1), " pw=", snappedf(power, 0.01), " h=", snappedf(hgt, 0.1), " gkz=", snappedf(gk.position.z, 0.1))
	_release(p, dir * sp + Vector3(0, vy, 0), 0, t, -0.03 * power)
	shot_live = true
	stats["shots"] += 1
	tst[p.team]["shots"] += 1
	fx("shake", 0.2 + 0.4 * power)
	fx("punch", 1.5 + 3.0 * power)
	snd("shot", 0.6 + 0.4 * power)
	fx("dust", [from.x, from.z])
	fx("vib", 40)

func _human_aim(h, dir3: Vector3) -> float:
	var gk = teams[1 - h.team][0]
	if set_piece == "pen":
		# a penalty goes exactly where you aim: stick to the side = that far across the goal, centred = the middle
		return clampf(dir3.z, -1.0, 1.0) * GOAL_HW * 0.84
	# The shot goes to the side the stick points to, always (Daniel: it sometimes went the other way when
	# the stick was only a little to one side, because that counted as "no side" and it took the far post).
	# A little to a side = inside that post, all the way = into the corner.
	# With the thumb off the stick it is the way he faces, the same way the arrow on the grass shows.
	var ad: Vector3 = dir3.normalized() if dir3.length() > 0.3 else (h.ctrl.fwd() if h.ctrl != null else Vector3.ZERO)
	if absf(ad.z) > 0.08:
		var k: float = clampf((absf(ad.z) - 0.08) / 0.55, 0.0, 1.0)
		return signf(ad.z) * lerpf(0.42, 0.82, k) * GOAL_HW
	# stick dead straight or let go: the far side from the keeper, well inside the post
	return (-1.0 if gk.position.z > 0.0 else 1.0) * GOAL_HW * 0.74

func _shoot(p, power: float, aim_z: float, err_k: float, curl := 0.0) -> void:
	if pro_sq >= 0:
		for h in humans:
			if h.psq >= 0 and p == _pro_man(h):
				h.ptrk["sh"] = int(h.ptrk.get("sh", 0)) + 1
	seq_m[1] += 1
	if ai_ev[0] != "" and p.team == ai_ev[1] and sim_t - ai_ev[2] < 7.0:
		stats[ai_ev[0] + "_sh"] = int(stats.get(ai_ev[0] + "_sh", 0)) + 1
		ai_ev[0] = ""
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
		_release(p, cd * (far / tc) + Vector3(0, 4.9 * tc, 0), 0, tc, 0.07)
		snd("shot", 0.55 + 0.35 * power)
		fx("dust", [from.x, from.z])
		return
	if set_piece == "pen":
		_pen_kick(p, power, aim_z)
		return
	# Like FIFA: a shot never goes exactly where you aimed. His shooting decides how close it gets (a top
	# finisher lands it near the spot, a defender sprays it), and so do power, distance, a man in his face
	# and shooting on the run. Most shots land near the aim, now and then one is well off.
	var skill_k: float = lerpf(1.3, 0.5, clampf((p.sho - 40) / 50.0, 0.0, 1.0))
	var nd_o := 99.0
	for o in teams[1 - p.team]:
		if not o.off and o.role != "GK":
			nd_o = minf(nd_o, o.position.distance_to(p.position))
	var press_k: float = 1.0 + 0.45 * clampf((3.0 - nd_o) / 2.0, 0.0, 1.0)
	var run_k: float = 1.0 + 0.25 * clampf((p.vel.length() / maxf(p.top_speed, 1.0) - 0.6) / 0.4, 0.0, 1.0)
	err_k *= skill_k * press_k * run_k
	pen_shot = set_piece == "pen"
	var cannon: bool = p.has_ab("kanon") and power > 0.45 and set_piece != "pen"
	if cannon:
		err_k *= 0.85
	var err := (randf() + randf() - 1.0) * (0.35 + d * 0.03 + power * 0.75) * err_k
	if absf(aim_z) > 1.0 and signf(aim_z + err) != signf(aim_z):
		# a poor finish goes wide or at the keeper, it does not swap to the other corner
		err = -aim_z * 0.8
	var goal := Vector3(HL * s, 0, aim_z + err)
	var dir := goal - from
	dir.y = 0.0
	dir = dir.normalized()
	var sp := 19.0 + 13.0 * power + (2.8 if cannon else 0.0)
	var t := maxf(d / sp, 0.15)
	# full power rises: from close in and from the edge of the box it tends to fly over, as it should
	var h := 0.35 + power * power * 2.1 + randf() * 0.6 * power * err_k
	var vy := (h - 0.25) / t + 4.9 * t
	# a curled shot starts wide of its target and bends back in
	var spin := 0.0
	if curl > 0.0 and d > 9.0:
		spin = curl * lerpf(0.7, 1.15, clampf((p.sho - 50) / 40.0, 0.0, 1.0)) * (1.55 if p.has_ab("skrue") else 1.0)
		if p.has_ab("skrue"):
			_ab_pop(p, "skrue")
		var wide := dir.rotated(Vector3.UP, -spin * t * 0.5)
		var sg := signf(goal.z) if absf(goal.z) > 0.3 else (1.0 if randf() < 0.5 else -1.0)
		if (wide.z - dir.z) * sg < 0.0:
			spin = -spin
			wide = dir.rotated(Vector3.UP, -spin * t * 0.5)
		dir = wide
	# struck through the middle with the laces: the harder it is hit, the more topspin, so it dips late
	_release(p, dir * sp + Vector3(0, vy, 0), 0, t, -0.06 * power * power, spin)
	shot_live = true
	shot_hard = 0.12 if cannon else 0.0
	if cannon and spin == 0.0:
		_ab_pop(p, "kanon")
	stats["shots"] += 1
	tst[p.team]["shots"] += 1
	fx("shake", 0.2 + 0.4 * power)
	fx("punch", 1.5 + 3.0 * power)
	snd("shot", 0.6 + 0.4 * power)
	fx("dust", [from.x, from.z])
	fx("vib", 40)

# ---------------------------------------------------------------- winning the ball

func _give(p) -> void:
	if ai_ev[0] != "" and not ai_ev[3] and sim_t - ai_ev[2] < 4.0:
		# what came of the computer's last attacking ball (test numbers)
		var rk: String = ai_ev[0] + ("_off" if p.offside else ("_ok" if p.team == ai_ev[1] else "_lost"))
		if OS.get_cmdline_user_args().has("--thrudbg") and ai_ev[0].begins_with("ai_thru"):
			var nd9 := 99.0
			for o9 in teams[1 - p.team]:
				if o9.role != "GK":
					nd9 = minf(nd9, o9.position.distance_to(p.position))
			print("THRU ", ai_ev[0], " got=", p.team == ai_ev[1], " t=", snappedf(sim_t - ai_ev[2], 0.1), " at=", Vector2(snappedf(p.position.x * side(ai_ev[1]), 0.1), snappedf(p.position.z, 0.1)), " role=", p.role, " near_def=", snappedf(nd9, 0.1))
		stats[rk] = int(stats.get(rk, 0)) + 1
		ai_ev[3] = true
	if p.offside and state == "play":
		_offside(p)
		return
	var prev = ball_last
	if prev == null or prev.team != p.team:
		poss_t = sim_t
		if prev != null:
			if autotest:
				var lx: float = prev.position.x * side(prev.team)
				var lk: String = "loss" + str(prev.team) + ("_3" if lx > HL - 35.0 else ("_m" if lx > -HL + 35.0 else "_1")) + ("_tk" if p.position.distance_to(prev.position) < 3.0 else "_pass")
				stats[lk] = int(stats.get(lk, 0)) + 1
			_seq_end(prev.team)
	own_at = sim_t
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
	_slide_go(me_p, dirs)

func _slide_go(me_p, dirs: Vector3) -> void:
	# like the 2D game: a fast burst along the grass, more than twice his running speed, about six metres
	if me_p.tackle_t < 0.0:
		me_p.start_tackle()
	me_p.yaw = atan2(-dirs.x, -dirs.z)
	me_p.slide_dir = dirs
	# a computer man goes in a touch slower and shorter than you: a slide you can see coming and step past
	me_p.slide_k = 1.0 if _hum_of(me_p) != null else 0.82
	me_p.vel = dirs * SLIDE_V * me_p.slide_k
	me_p.slide_live = true
	me_p.slide_fx = 0.0
	me_p.stun = SLIDE_T + 0.3
	snd("slide")
	fx("dust", [me_p.position.x, me_p.position.z])

# A computer defender goes to ground, like a real one: only when the ball is out of the runner's feet
# (a long touch at speed), he comes from the front or the side, the ball is within a slide, and the moment
# has lasted his reaction time. A good defender waits for that moment; a poor one goes early or from a bad
# angle. What the slide meets decides it (_slides): the ball is won, the man from behind is a foul. No dice.
var slide_team_t := [0.0, 0.0] # sim_t before which that side's computer men stay on their feet

func _cpu_slide(o, c, dt: float) -> bool:
	o.slide_cd -= dt
	if o.slide_cd > 0.0 or o.tackle_t >= 0.0 or o.stun > 0.0 or state != "play" or set_piece != "":
		o.slide_w = 0.0
		return false
	var cs: float = c.vel.length()
	var to: Vector3 = ball.position - o.position
	to.y = 0.0
	var bd: float = to.length()
	var front: float = c.fwd().dot((o.position - c.position).normalized())
	var dq: float = clampf((o.dfn - 40) / 50.0, 0.0, 1.0)
	# at speed the ball runs a step ahead of him (out of his feet); slow, it is tucked in and a slide only finds the man.
	# A good defender waits for a runner at full tilt and a clean angle; a poor one also goes in early or from a worse angle.
	var need_sp: float = lerpf(0.55, 0.75, dq)
	var need_front: float = lerpf(-0.45, -0.15, dq)
	var ok: bool = cs > c.top_speed * need_sp and c.skill_t < 0.0 and bd > 2.0 and bd < 3.9 and front > need_front and sim_t > slide_team_t[o.team] and ball.position.y < 0.5
	# not in his own box: a slide there is a penalty if it goes wrong (only the very best dare)
	var own_x := -HL * side(o.team)
	if ok and absf(ball.position.x - own_x) < 16.5 and absf(ball.position.z) < 20.16 and dq < 0.8:
		ok = false
	# only one man of a team on the grass at a time
	if ok:
		for m in teams[o.team]:
			if m != o and m.slide_live:
				ok = false
				break
	if not ok:
		o.slide_w = maxf(o.slide_w - dt * 2.0, 0.0)
		return false
	o.slide_w += dt
	if o.slide_w < lerpf(0.32, 0.18, dq) * (_cpu(o.team)["need"] / 0.5):
		return false
	o.slide_w = 0.0
	o.slide_cd = 9.0
	# a side does not throw itself in again and again: a real defender stays on his feet most of the time
	slide_team_t[o.team] = sim_t + 8.0
	# aim where the ball will be when he gets there
	var t: float = bd / (SLIDE_V * 0.82 * 0.6)
	# a good defender reads where the ball is going; a poor one slides at where it is now and arrives behind it, into the man
	var lead: Vector3 = to + c.vel * t * lerpf(0.25, 1.0, dq) * randf_range(0.55, 1.45)
	# nobody aims a slide perfectly: a poor defender can be well off and slides past the ball altogether
	lead = lead.rotated(Vector3.UP, randf_range(-1.0, 1.0) * lerpf(0.55, 0.2, dq))
	_slide_go(o, lead.normalized())
	stats["cslide"] = int(stats.get("cslide", 0)) + 1
	return true

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
			var hum_s: bool = _hum_of(p) != null
			# your own slide gets the ball when it gets there; a computer man's boot has to meet it more squarely
			var sreach: float = (1.15 if hum_s else 0.8) + (p.dfn - 60) * 0.004
			if bd < sreach:
				p.slide_live = false
				if front > -0.45 and hum_s:
					# Yours: reach the ball from the front or side and it is won. Only a man in the middle of a trick
					# can get a toe to it first and it runs loose.
					stats["hslide"] = int(stats.get("hslide", 0)) + 1
					if c.skill_t >= 0.0:
						var dv2: Vector3 = ball.position - p.position
						dv2.y = 0.0
						ball_owner = null
						ball_vel = (dv2.normalized() * 0.6 + p.slide_dir * 0.4).normalized() * 5.5
						ball_last = p
						ball_ignore = c
						ignore_t = 0.25
						c.vel *= 0.5
						p.stun = 0.8
						snd("touch")
					else:
						c.stun = 0.6
						c.start_fall(0.6)
						stats["tackles"] += 1
						snd("win")
						fx("shake", 0.3)
						fx("vib", 40)
						p.stun = 0.3
						_give(p)
						protect_t = 0.7
				elif front > -0.45:
					# Reaching the ball is not winning it: how cleanly the boot meets it, the tackler's defending
					# against the dribbler's skill, the angle, and a dribbler mid-trick rides it.
					var sq2: float = _slide_q(p, c, bd, sreach, front)
					stats["sq"] = int(stats.get("sq", 0)) + 1
					if sq2 >= 0.5:
						c.stun = 0.6
						c.start_fall(0.6)
						stats["tackles"] += 1
						stats["swin"] = int(stats.get("swin", 0)) + 1
						snd("win")
						fx("shake", 0.3)
						fx("vib", 40)
						p.stun = 0.3
						_give(p)
						protect_t = 0.7
					elif sq2 >= 0.42:
						# a toe on it: the ball squirts away and it is anyone's
						stats["sloose"] = int(stats.get("sloose", 0)) + 1
						var dv: Vector3 = ball.position - p.position
						dv.y = 0.0
						ball_owner = null
						ball_vel = (dv.normalized() * 0.6 + p.slide_dir * 0.4).normalized() * 5.5
						ball_last = p
						ball_ignore = c
						ignore_t = 0.25
						c.vel *= 0.5
						c.stun = maxf(c.stun, 0.2)
						p.stun = 1.0
						snd("touch")
					else:
						# he rides it: the slide goes past and the man is away
						stats["smiss"] = int(stats.get("smiss", 0)) + 1
						c.stun = maxf(c.stun, 0.1)
						c.vel *= 0.85
						p.stun = 1.2
						p.vel *= 0.4
						if c.has_ab("tryl"):
							_ab_pop(c, "tryl")
				else:
					_foul(p, c)
			elif pd < (0.75 if _hum_of(p) != null else 0.6):
				# missed the ball and took the man
				p.slide_live = false
				_foul(p, c, true)

# A slide that reaches the ball: how well it is won (0.5+ clean, 0.34+ knocked loose, less = he rides it).
func _slide_q(p, c, bd: float, sreach: float, front: float) -> float:
	# how square the boot meets it: the ball's distance from the line of the slide
	var rel: Vector3 = ball.position - p.position
	rel.y = 0.0
	var perp: float = (rel - p.slide_dir * rel.dot(p.slide_dir)).length()
	var clean: float = 1.0 - clampf(perp / 0.9, 0.0, 1.0)
	var cdr: float = clampf((c.ovr - 40) / 55.0, 0.0, 1.0)
	var duel: float = (clampf((p.dfn - 40) / 55.0, 0.0, 1.0) - (cdr * 0.7 + clampf((c.pac - 40) / 55.0, 0.0, 1.0) * 0.3)) * 0.45
	var side_on: float = 0.08 if absf(front) < 0.55 else 0.0
	var abk := (0.08 if p.has_ab("mur") else 0.0) - (0.1 if c.has_ab("tryl") else 0.0)
	if OS.get_cmdline_user_args().has("--sqdbg"):
		print("SQ clean=%.2f duel=%.2f side=%.2f sk=%d" % [clean, duel, side_on, 1 if c.skill_t >= 0.0 else 0])
	return 0.32 + clean * 0.45 + duel + side_on + abk - (0.35 if c.skill_t >= 0.0 else 0.0)

# How good the moment is for a foot in, the 2D game's rule (no dice): how close the foot is to the ball,
# whether the ball is out of his feet (sprinting) or tucked in (slow, turning), whether his body is between
# you and the ball (he shields it), the angle, whether you are set or flying in, and defending against his dribbling.
# 0.5 or more wins it clean, 0.36 or more knocks it loose, less is a miss.
func _tq(p, c) -> float:
	var dt2: float = Vector2(p.position.x - ball.position.x, p.position.z - ball.position.z).length()
	var dpo: float = maxf(Vector2(p.position.x - c.position.x, p.position.z - c.position.z).length(), 0.01)
	var reach: float = 1.3 + clampf((p.dfn - 40) / 55.0, 0.0, 1.0) * 0.25 + (0.3 if p.has_ab("mur") else 0.0)
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
	var abk := (0.08 if p.has_ab("mur") else 0.0) - (0.08 if c.has_ab("tryl") else 0.0) - (0.06 if c.has_ab("bamse") else 0.0)
	return 0.14 + (1.0 - dt2 / reach) * 0.3 + expo * 0.38 - shield * (0.35 + 0.3 * clampf((c.phy - 40) / 55.0, 0.0, 1.0)) + ang + setk - lunge * 0.3 + duel - (0.3 if c.skill_t >= 0.0 else 0.0) + abk

# The foot goes in: won clean, knocked loose between the two, or missed. Returns true when the ball changed hands or went loose.
func _poke(p, c, qadj := 0.0) -> bool:
	var q := _tq(p, c) + qadj
	stats["pq"] = int(stats.get("pq", 0)) + 1
	# Your own foot in is trusted: a decent moment wins it. A computer man has to get it right, and when
	# he gets it nearly right it is mostly a clean miss, not a lucky toe that knocks it loose every time.
	var hum_p: bool = _hum_of(p) != null
	var win_q: float = 0.4 if hum_p else 0.44
	var nick_q: float = 0.26 if hum_p else 0.39
	var sk_: String = ("h" if hum_p else "c") + ("pk_win" if q >= win_q else ("pk_nick" if q >= nick_q else "pk_miss"))
	stats[sk_] = int(stats.get(sk_, 0)) + 1
	if q >= win_q:
		c.stun = 0.4
		c.vel *= 0.3
		stats["tackles"] += 1
		snd("win")
		if p.has_ab("mur"):
			_ab_pop(p, "mur")
		_give(p)
		protect_t = 0.7
		return true
	if q >= nick_q:
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
	if q >= 0.0:
		if c.has_ab("tryl"):
			_ab_pop(c, "tryl")
		elif c.has_ab("bamse"):
			_ab_pop(c, "bamse")
	p.stun = 0.3 + (0.25 if q < 0.0 else 0.0)
	p.vel *= 0.3
	stats["pmiss"] = int(stats.get("pmiss", 0)) + 1
	return false

var def_dbg := OS.get_cmdline_user_args().has("--defdbg")
var def_m := [0, 0.0, 0, 0] # frames, sum back-line speed, frames with a defender within 4 m, frames with no defender goal side

func _tackles(dt: float) -> void:
	var c = ball_owner
	if c == null or c.hands() or protect_t > 0.0:
		return
	if _hum_of(c) != null and (autotest or def_dbg):
		# test: how often a man is running at you while you have the ball
		var hc := 0
		for o6 in teams[1 - c.team]:
			if o6.position.distance_to(c.position) < 5.0 and o6.vel.dot((c.position - o6.position).normalized()) > 1.5:
				hc = 1
				stats["hc_" + o6.ai_tag] = int(stats.get("hc_" + o6.ai_tag, 0)) + 1
		stats["hframes"] = int(stats.get("hframes", 0)) + 1
		stats["hchased"] = int(stats.get("hchased", 0)) + hc
	if def_dbg and _hum_of(c) != null:
		# how the back line deals with a man running at goal: do they move, close him down, stay goal side?
		var og5 := Vector3(-HL * side(1 - c.team), 0, 0)
		var cg: float = c.position.distance_to(og5)
		if cg < 35.0:
			def_m[0] += 1
			var spd := 0.0
			var n := 0
			var close := false
			var gside := false
			for o in teams[1 - c.team]:
				if o.role == "DF":
					spd += o.vel.length()
					n += 1
				if o.role != "GK" and o.position.distance_to(c.position) < 4.0:
					close = true
				if o.role != "GK" and o.position.distance_to(og5) < cg - 1.0:
					gside = true
			def_m[1] += spd / maxf(n, 1)
			def_m[2] += 1 if close else 0
			def_m[3] += 0 if gside else 1
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
		if o.commit_t < 0.0 and _cpu_slide(o, c, dt):
			continue
		if o.commit_t >= 0.0:
			# the tackle is already on its way: it lands a moment later, wherever the carrier has turned by then
			o.commit_t -= dt
			if o.commit_t <= 0.0:
				o.commit_t = -1.0
				o.step_t = 0.0
				if front < -0.5 and d < 1.15 and c.vel.length() >= 2.0:
					_foul(o, c)
					return
				# did his foot land where the ball is?
				var dq4: float = clampf((o.dfn - 40) / 50.0, 0.0, 1.0)
				var md: float = Vector2(o.tk_aim.x - ball.position.x, o.tk_aim.z - ball.position.z).length()
				if md > lerpf(0.55, 0.7, dq4):
					# a clean miss you can see: the foot goes through where the ball was and he stumbles past
					var lv: Vector3 = o.tk_aim - o.position
					lv.y = 0.0
					if lv.length() > 0.1:
						o.vel = lv.normalized() * 6.0
					o.stun = lerpf(0.75, 0.5, dq4)
					stats["cwhiff"] = int(stats.get("cwhiff", 0)) + 1
					if def_dbg:
						print("WHIFF at ", snappedf(real_t, 0.01))
						if shot_path != "" and shot_at > real_t + 2.0:
							# test picture of the miss: --shot with --at far ahead, taken just after the first whiff
							shot_at = real_t + float(OS.get_environment("WHIFF_DT") if OS.get_environment("WHIFF_DT") != "" else "0.2")
					if c.has_ab("tryl"):
						_ab_pop(c, "tryl")
					continue
				if _poke(o, c, -md * 0.3):
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
		# Nobody sees the perfect moment: each man reads it with an error that a better defender keeps small.
		# A poor defender also tends to think it is on when it is not (he dives in), and sometimes just goes.
		var dq2: float = clampf((o.dfn - 40) / 50.0, 0.0, 1.0)
		var cpu_man: bool = _hum_of(o) == null
		if cpu_man:
			o.tq_t -= dt
			if o.tq_t <= 0.0:
				o.tq_t = randf_range(0.35, 0.8)
				o.tq_err = randf_range(-1.0, 1.0) * lerpf(0.24, 0.07, dq2) + lerpf(0.1, 0.0, dq2)
		var seen_q: float = _tq(o, c) + (o.tq_err if cpu_man else 0.0)
		var rush := false
		if cpu_man and stepping and d < reach + 0.5 and front > 0.2 and not still:
			o.rush_t += dt * lerpf(0.9, 0.08, dq2) * randf()
			if o.rush_t > 1.0:
				rush = true
				o.rush_t = 0.0
		if rush or (d < reach + 0.25 and (still or front > (0.0 if stepping else 0.3)) and seen_q >= want_q):
			o.press_t += dt
			var need: float = _cpu(o.team)["need"]
			if cpu_man:
				# and his reactions are not a machine's: a little quicker or slower each time
				need *= randf_range(0.8, 1.35)
			if _team_human(o.team):
				need = 0.6
			elif not stepping:
				need *= 1.4
			else:
				# he has decided to step in: now it is only his reaction time
				need *= 0.55
			need *= lerpf(1.15, 0.88, clampf((o.dfn - 40) / 45.0, 0.0, 1.0))
			if rush or o.press_t > need - 0.15:
				o.press_t = 0.0
				o.commit_t = 0.15
				o.start_kick(0.25)
				if cpu_man:
					# He sticks his foot where he thinks the ball will be when it lands. A good defender reads the
					# run well; a poor one goes where it is now, or guesses. Change pace or direction and he hits grass.
					var lead_k: float = lerpf(0.35, 0.95, dq2) * randf_range(0.75, 1.2)
					var err_r: float = lerpf(0.5, 0.12, dq2) * randf() + (0.25 if rush else 0.0)
					var ea: float = randf() * TAU
					o.tk_aim = ball.position + c.vel * 0.2 * lead_k + Vector3(cos(ea), 0, sin(ea)) * err_r
					o.tk_aim.y = 0.0
		else:
			o.press_t = maxf(o.press_t - dt * 2.0, 0.0)

# a skill did its thing: its name rises over the player (now and then, not every touch)
func _ab_pop(p, k: String) -> void:
	if _quiet() or not p.has_ab(k) or not Career.ABIL.has(k):
		return
	if real_t - p.ab_at < 5.0:
		return
	p.ab_at = real_t
	fx("ab", [players.find(p), k])

func _gk_pop(g, close_in: bool) -> void:
	if g.has_ab("straf") and close_in:
		_ab_pop(g, "straf")
	elif g.has_ab("kat"):
		_ab_pop(g, "kat")

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
		# A keeper's own skills, the same rules for both sides: DIVING (his pace slot) sets how far he gets,
		# HANDLING (shooting slot) whether he holds it or pushes it away, REFLEXES (defending slot) how quickly he moves.
		var gdiv: float = clampf((g.pac - 50) / 42.0, 0.0, 1.0)
		var ghan: float = clampf((g.sho - 50) / 42.0, 0.0, 1.0)
		var reach := 0.77 + (lerpf(0.56, 0.84, gdiv) if g.dive_t >= 0.0 else 0.0)
		# skills: the cat reaches further, the penalty killer too from close in; a Cannon shot is harder to get to
		var close_in: bool = pen_shot or Vector2(b.x - gx, b.z).length() < 12.0
		if g.has_ab("kat") and g.dive_t >= 0.0:
			reach += 0.14
		if g.has_ab("straf") and close_in and g.dive_t >= 0.0:
			reach += 0.22
		if shot_live:
			reach -= shot_hard
			if pen_shot:
				# from a standing start on his line he does not get as far as in open play
				reach -= 0.15
			if pen_shot and absf(g.pen_z) > 0.1 and signf(g.pen_z) != signf(b.z) and absf(b.z) > 0.3:
				# he went the wrong way on a penalty: only a trailing leg is left
				reach *= 0.45
		# high balls are harder to reach, so the top corners are open to a good shot
		if shot_live:
			reach -= maxf(b.y - 1.5, 0.0) * 0.45
		var dh := Vector2(b.x - g.position.x, b.z - g.position.z).length()
		if dh < reach and b.y < 2.6:
			# good keepers hold harder shots, the rest push them away
			if hs > lerpf(15.0, 21.0, ghan) and dh > 0.55:
				var sgn := signf(b.z - g.position.z)
				ball_vel = Vector3(-ball_vel.x * 0.3, absf(ball_vel.y) * 0.4 + 2.5, ball_vel.z * 0.4 + sgn * 5.0)
				ball_bs = 0.0
				ball_ignore = g
				ignore_t = 0.5
				ball_last = g
				shot_live = false
				stats["saves"] += 1
				tst[t]["saves"] += 1
				snd("catch", 1.0)
				snd("ooh")
				snd("clap", 0.8)
				fx("shake", 0.3)
				fx("say", "What a save!")
				_gk_pop(g, close_in)
			else:
				if shot_live:
					stats["saves"] += 1
					tst[t]["saves"] += 1
					snd("ooh", 0.8)
					snd("clap", 0.6)
					_gk_pop(g, close_in)
				snd("catch", 0.85 if shot_live else 0.5)
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
				var d2 := Vector2(b.x - p.position.x, b.z - p.position.z).length() - randf() * 0.35 - (0.45 if p.has_ab("luft") else 0.0)
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
		if b.y > 1.15 and ball_last != null and p.team != ball_last.team and not shot_live:
			# A high pass dropping over a defender at chest height is not his: he cannot just take it down
			# like a pass to his feet (Daniel: the high through balls were always taken). Only lower, or with his head.
			continue
		var d := Vector2(b.x - p.position.x, b.z - p.position.z).length()
		# a fast ball that is not meant for you only hits you if it really hits your body
		var rd_k: float = 1.15 if (p.has_ab("laeser") and not shot_live and ball_last != null and ball_last.team != p.team) else (0.42 if shot_live else 0.55)
		if hs > 12.0 and not p.recv and d > rd_k:
			continue
		if d < bd:
			bd = d
			best = p
	if best == null:
		return
	if hs > 24.0 and not best.recv:
		var n := Vector3(b.x - best.position.x, 0, b.z - best.position.z).normalized()
		ball_vel = ball_vel.bounce(n) * 0.35
		ball_bs = 0.0
		ball_ignore = best
		ignore_t = 0.4
		ball_last = best
		shot_live = false
		snd("touch")
		return
	if hs > 6.0:
		snd("touch")
	if best.has_ab("laeser") and ball_last != null and ball_last.team != best.team and not shot_live and hs > 8.0:
		_ab_pop(best, "laeser")
	_give(best)

func _check_lines() -> void:
	var b := ball.position
	if absf(b.x) > HL:
		var sx := signf(b.x)
		var in_mouth := absf(b.z) < GOAL_HW and b.y < GOAL_H
		if absf(b.x) < HL + 0.6 and (absf(absf(b.z) - GOAL_HW) < 0.22 and b.y < GOAL_H + 0.2 or absf(b.z) < GOAL_HW and absf(b.y - GOAL_H) < 0.2) and ball_vel.x * sx > 0.0:
			ball_vel.x *= -0.6
			ball_bs = 0.0
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
				snd("ooh" if randf() < 0.65 else "aww")
			if ball_last != null and ball_last.team == defending:
				_out("corner", Vector3(sx * (HL - 0.6), 0, signf(b.z) * (HW - 0.6)), 1 - defending)
				snd("cheer", 0.55)
			else:
				_out("gk", Vector3(sx * (HL - 5.5), 0, 0), defending)
			return
	if absf(b.z) > HW + 0.3:
		var t: int = 1 - (ball_last.team if ball_last != null else 0)
		_out("throw", Vector3(clampf(b.x, -HL + 1.0, HL - 1.0), 0, signf(b.z) * (HW - 0.3)), t)

# ---------------------------------------------------------------- AI

var own_at := 0.0 # sim_t when the man on the ball got it
var poss_t := 0.0 # sim_t when the ball last changed sides (the losing side presses hard for a moment)
var hold_m := [0, 0.0, 0, 0] # test: AI passes, sum of time on the ball, frames on the ball, frames with an opponent within 4 m

# Does this side press the man on the ball now, or sit in its shape? Like FIFA's balanced defending: you are
# not hunted all over the pitch. They go for the ball in their own half, for a few seconds after losing it,
# and on the triggers: a heavy/first touch, a man facing his own goal, or one trapped at the touchline.
func _press_on(t: int, c) -> bool:
	var s := side(t)
	var cu: float = c.position.x * s
	var pr: int = int(tac_t[t][1])
	if cu < [-24.0, -14.0, 6.0][pr]:
		# the last 38 metres (a low block waits until the box, a high press hunts him in his own half)
		return true
	if sim_t - poss_t < [1.2, 2.5, 4.0][pr] and ball_last != null:
		return true
	if sim_t - own_at < 0.45 and c.vel.length() < c.top_speed * 0.6:
		# his first touch, and it is not running for him: the moment to close him down
		return true
	if c.vel.length() > 1.0 and c.vel.normalized().x * s > 0.6:
		# he is running back towards his own goal: squeeze him
		return true
	if absf(c.position.z) > HW - 5.0:
		return true
	return false


# --- the computer in attack: it plays like FIFA's AI, calm in the build-up but sharp in the last third.
# Everything here goes through the players' own ratings: a poor passer sees and lands fewer through balls,
# a poor finisher shoots less from range and sprays it more (the error is in _pass/_shoot as for you).


# ---------------------------------------------------------------- the managers on the touchline
# Like a real manager the computer changes its plan during the match: behind late on it presses high and
# throws men forward, ahead it sits deeper and sees it out, a man down it tightens up. It also brings on
# fresh legs. For a human side it only suggests a change (tired men); you make it in the pause menu.
const MOOD_TXT := {
	"push": ["PUSHING FOR A GOAL", "%s push up and press higher, they need a goal."],
	"allout": ["ALL OUT ATTACK", "%s are throwing everyone forward now!"],
	"sit": ["SITTING DEEPER", "%s drop off and protect the lead."],
	"bus": ["PARKING THE BUS", "Everyone behind the ball for %s, they want to see this out."],
	"ten": ["TIGHTENING UP", "%s are a man down and tighten up at the back."],
	"ease": ["EASING OFF", "%s are cruising and take the foot off the gas."],
}

func _men_on(t: int) -> int:
	var n := 0
	for p in teams[t]:
		if not p.off:
			n += 1
	return n

func _managers() -> void:
	if state != "play" or screen != "match" or teams[0].size() < 2:
		return
	var mn: float = clock / 60.0
	for t in 2:
		if _team_human(t):
			_sub_hints(t, mn)
			continue
		if humans.is_empty() and not autotest:
			continue
		var b: Array = tac_base[t]
		var m: int = int(b[0])
		var pr: int = int(b[1])
		var w: int = int(b[2])
		var gd: int = score[t] - score[1 - t]
		var mood := ""
		if gd < 0:
			if mn >= 80.0 or (gd <= -2 and mn >= 62.0):
				m = 4
				pr = 2
				w = 2
				mood = "allout"
			elif mn >= 58.0 or gd <= -2:
				m = maxi(m, 3)
				pr = 2
				mood = "push"
		elif gd > 0:
			if mn >= 82.0 and gd == 1:
				m = 0
				pr = 0
				w = mini(w, 1)
				mood = "bus"
			elif mn >= 65.0 and gd <= 2:
				m = mini(m, 1)
				pr = mini(pr, 1)
				mood = "sit"
			elif gd >= 3:
				m = mini(m, 2)
				pr = mini(pr, 1)
				mood = "ease"
		if mood == "" or mood == "push":
			if _men_on(t) < _men_on(1 - t):
				m = maxi(mini(m, int(b[0])) - 1, 0)
				pr = mini(pr, 1)
				mood = "ten"
		var nt := [m, pr, w]
		if nt != tac_t[t]:
			tac_t[t] = nt
		if mood != tac_mood[t]:
			tac_mood[t] = mood
			if mood != "" and not autotest:
				var tx: Array = MOOD_TXT[mood]
				fx("say", str(tx[1]) % str(TEAM_NAMES[t]).capitalize())
				hud.toast("%s  ·  %s" % [str(TEAM_NAMES[t]).to_upper(), tx[0]])
				_net_toast("%s  ·  %s" % [str(TEAM_NAMES[t]).to_upper(), tx[0]], -1)
			stats["mood_" + (mood if mood != "" else "plan")] = int(stats.get("mood_" + (mood if mood != "" else "plan"), 0)) + 1
		_cpu_subs(t, mn, mood)

# The computer's substitutions: tired men off from about the hour, an extra forward when it chases the game.
func _cpu_subs(t: int, mn: float, mood: String) -> void:
	if mn < 55.0 or int(sub_left2[t]) <= 0 or (sub_bench[t] as Array).is_empty() or set_piece != "" or ball_owner == null:
		return
	if clock - float(cpu_sub_at[t]) < 6.0 * 60.0:
		return
	var bl: Array = sub_bench[t]
	var worst = null
	var wf := 0.78 if mn < 70.0 else 0.84
	for p in teams[t]:
		if p.off or p.role == "GK" or p == ball_owner:
			continue
		if p.fit < wf:
			wf = p.fit
			worst = p
	var want_role := ""
	if worst == null and mood in ["push", "allout"] and mn >= 62.0:
		# chasing the game: a fresh forward for a tired midfielder or defender
		for p in teams[t]:
			if not p.off and p.role in ["MF", "DF"] and p != ball_owner and (worst == null or p.fit < worst.fit):
				worst = p
		want_role = "FW"
	if worst == null:
		return
	if want_role == "":
		want_role = worst.role
	var pick := -1
	for i in bl.size():
		if (sub_used[t] as Array).has(i):
			continue
		var pos := str((bl[i] as Dictionary).get("pos", ""))
		if pos == want_role:
			pick = i
			break
		if pick < 0 and pos != "GK" and (want_role != "FW" or pos != "DF"):
			pick = i
	if pick < 0:
		return
	cpu_sub_at[t] = clock
	stats["cpu_subs"] = int(stats.get("cpu_subs", 0)) + 1
	_sub_do(t, teams[t].find(worst), pick)

# A human side gets a tip when a man is out on his feet: who, how tired, and where to change him.
func _sub_hints(t: int, mn: float) -> void:
	if mn < 50.0 or int(sub_left2[t]) <= 0 or (sub_bench[t] as Array).is_empty() or pro_sq >= 0:
		return
	if (sub_used[t] as Array).size() >= (sub_bench[t] as Array).size():
		return
	if clock - float(sub_hint.get("_t%d" % t, -999.0)) < 7.0 * 60.0:
		return
	for p in teams[t]:
		if p.off or p.role == "GK":
			continue
		var id: int = p.get_instance_id()
		if p.fit < 0.72 and not sub_hint.has(id):
			sub_hint["_t%d" % t] = clock
			sub_hint[id] = true
			var tx := "%s IS TIRED (%d%%)  ·  PAUSE  ›  SUBSTITUTIONS" % [p.pname.to_upper(), int(round(p.fit * 100.0))]
			stats["sub_hint"] = int(stats.get("sub_hint", 0)) + 1
			if autotest:
				return
			for h in humans:
				if h.team == t and h.local:
					hud.toast(tx)
			_net_toast(tx, t)
			return

# a short line on the friend's phone too (team -1 = both, else only if his side is that team)
func _net_toast(tx: String, t: int) -> void:
	if net.role != "host" or not net.connected:
		return
	for h in humans:
		if not h.local and (t < 0 or h.team == t):
			net.send({"_": "toast", "s": tx})
			return

var go_run := {} # computer players on a pass-and-go run: instance id -> until (sim_t)
var ai_ev := ["", -1, -99.0, false]
var seq_m := [0, 0] # test numbers: how far this spell on the ball got (1 last third, 2 box), shots in it
func _seq_end(t: int) -> void:
	if seq_m[0] > 0:
		var k: String = "seq" + str(t) + ("_box" if seq_m[0] == 2 else "_3rd")
		stats[k] = int(stats.get(k, 0)) + 1
		if seq_m[1] > 0:
			stats[k + "_sh"] = int(stats.get(k + "_sh", 0)) + 1
	seq_m = [0, 0]
func _ai_mark(kind: String, t: int) -> void:
	stats[kind] = int(stats.get(kind, 0)) + 1
	ai_ev = [kind, t, sim_t, false]

# how well this computer side reads the game (easy level slower and blinder, team mates sharp)
func _ai_vision(t: int) -> float:
	return clampf(1.25 - float(_cpu(t)["think"]), 0.5, 1.0)

# opponents (not the keeper) standing in the line from a to b
func _lane_block(t: int, a: Vector3, b: Vector3, r: float) -> int:
	var to: Vector3 = b - a
	to.y = 0.0
	var l: float = to.length()
	if l < 0.5:
		return 0
	var n: Vector3 = to / l
	var k := 0
	for o in teams[1 - t]:
		if o.off or o.role == "GK":
			continue
		var ap: Vector3 = o.position - a
		ap.y = 0.0
		var tt: float = ap.dot(n)
		if tt < 0.5 or tt > l:
			continue
		if (ap - n * tt).length() < r:
			k += 1
	return k

# A run in behind that is on: a man going forward near their last line, onside, with grass in front of him
# that he gets to before any defender (or the keeper). Returns [man, lofted, lead time] or null.
func _ai_thru(p):
	var s := side(p.team)
	var t: int = p.team
	if p.position.x * s < -20.0:
		return null
	var best = null
	var bs := -1e9
	for m in teams[t]:
		if m == p or m.off or m.role == "GK" or m.stun > 0.0 or (_hum_of(m) != null and not _is_pro_man(m)):
			continue
		var mu: float = m.position.x * s
		if m.vel.x * s < 2.2 or mu < off_line[t] - 7.0 or mu < p.position.x * s + 2.0:
			continue
		if _is_offside(p, m):
			continue
		var d: float = m.position.distance_to(p.position)
		if d < 8.0 or d > 42.0:
			continue
		var rd := Vector3(s, 0, 0) * 0.55
		var mv: Vector3 = m.vel
		mv.y = 0.0
		if mv.length() > 1.5:
			rd += mv.normalized() * 0.65
		if mu > HL - 36.0:
			var tog: Vector3 = Vector3(HL * s, 0, 0) - m.position
			tog.y = 0.0
			rd += tog.normalized() * 0.5
		rd = rd.normalized()
		var lead: float = 1.1 + randf() * 0.4
		var vr: float = m.top_speed * 0.82
		var spot: Vector3 = m.position + rd * vr * lead
		spot.x = clampf(spot.x, -HL + 7.0, HL - 7.0)
		spot.z = clampf(spot.z, -HW + 3.0, HW - 3.0)
		spot.y = 0.0
		var t_me: float = m.position.distance_to(spot) / maxf(vr, 1.0)
		var margin := 9.0
		for o in teams[1 - t]:
			if o.off:
				continue
			var ot: float = o.position.distance_to(spot) / maxf(o.top_speed, 1.0) + (0.55 if o.role == "GK" else 0.3)
			if o.role == "GK" and absf(spot.x * s) < HL - 17.0:
				continue
			margin = minf(margin, ot - t_me)
		if margin < 0.15:
			continue
		var lofted := false
		if _lane_block(t, p.position, spot, 1.7) > 0:
			# the ground is shut: over the top, but only a real passer tries the chip
			if d < 14.0 or p.pas < 62:
				continue
			lofted = true
		var sc: float = (spot.x * s - p.position.x * s) * 0.12 + minf(margin, 1.5) * 2.0 - d * 0.03
		if mu > HL - 30.0:
			sc += 1.5
		# a ball that takes him wide to the corner flag is worth less than one through the middle
		sc -= maxf(absf(spot.z) - 11.0, 0.0) * 0.22
		if _is_pro_man(m):
			sc += 1.4 # the player career: your run in behind is seen and played
		if sc > bs:
			bs = sc
			best = [m, lofted, lead]
	return best

# A team mate in or near the box who is freer than me: the cut back or the square ball for a tap in.
func _ai_better(p, dist: float):
	var s := side(p.team)
	var best = null
	var bd := dist - 4.0
	for m in teams[p.team]:
		if m == p or m.off or m.role == "GK" or m.stun > 0.0:
			continue
		var gd: float = Vector2(HL * s - m.position.x, m.position.z).length()
		if gd > bd or gd > 17.0 or absf(m.position.z) > 12.0:
			continue
		if _is_offside(p, m):
			continue
		var mark := 9.0
		for o in teams[1 - p.team]:
			if o.role != "GK":
				mark = minf(mark, o.position.distance_to(m.position))
		if mark < 2.2:
			continue
		if _lane_block(p.team, p.position, m.position, 1.3) > 0:
			continue
		if _lane_block(p.team, m.position, Vector3(HL * s, 0, 0), 1.0) > 0:
			continue
		bd = gd
		best = m
	return best

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
			var paz: float = 0.0 if (set_piece == "pen" and randf() < 0.1) else (1.0 if randf() < 0.5 else -1.0) * GOAL_HW * (0.5 + randf() * 0.35)
			_shoot(p, 0.45 + randf() * 0.4, paz, cpu["err"])
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
	p.hold_t += dt
	if autotest:
		var fx3: float = p.position.x * s
		var fk: String = "ftb" if fx3 > HL - 16.5 and absf(p.position.z) < 20.0 else ("ft3" if fx3 > HL - 35.0 else ("ftm" if fx3 > -HL + 35.0 else "ft1"))
		stats[fk + str(p.team)] = int(stats.get(fk + str(p.team), 0)) + 1
		if fk == "ft3" or fk == "ftb":
			seq_m[0] = maxi(seq_m[0], 1 if fk == "ft3" else 2)
	if autotest or OS.get_cmdline_user_args().has("--holddbg"):
		hold_m[2] += 1
		for o5 in teams[1 - p.team]:
			if o5.position.distance_to(p.position) < 5.0 and o5.vel.dot((p.position - o5.position).normalized()) > 1.5:
				hold_m[3] += 1
				break
	# Like FIFA's AI: a man on the ball takes a touch, looks up and plays at the pace of the game. He keeps
	# it while he has room, carries it into space, and only moves it on quickly when someone is really on him.
	var pas_q: float = clampf((p.pas - 40) / 55.0, 0.0, 1.0)
	var tight: bool = nd < 2.2 or (nd < 3.2 and near != null and near.vel.dot((p.position - near.position).normalized()) > 2.5)
	if tight and p.ai_cool > 0.12 and p.hold_t > 0.3:
		p.ai_cool = 0.12 # a man is right on me: decide now
	if p.ai_cool <= 0.0 and p.hold_t < 0.3:
		p.ai_cool = 0.05 # first the ball has to be under control
	elif p.ai_cool <= 0.0:
		p.ai_cool = cpu["think"] * (0.8 + randf() * 0.6)
		if dist < 30.0:
			# near their goal the moments come and go fast: he looks up more often
			p.ai_cool *= 0.6
		var angle_ok := absf(p.position.z) < 8.0 + (HL - absf(p.position.x)) * 0.8
		var sho_q: float = clampf((p.sho - 40) / 50.0, 0.0, 1.0)
		var vis: float = _ai_vision(p.team)
		var blk: int = _lane_block(p.team, p.position, Vector3(HL * s, 0, 0), 1.1)
		var take := false
		if dist < 24.0 and angle_ok and (nd > 1.7 or dist < 18.0 or (nd > 1.1 and blk == 0)):
			take = dist < 20.0 or randf() < 0.4 + 0.3 * sho_q * float(blk == 0)
			if take and blk > 0 and dist > 9.0:
				# a defender in the way: a cut back to a free man is the better chance
				var cb = _ai_better(p, dist)
				if cb != null and randf() < 0.45 + 0.4 * vis:
					_ai_mark("ai_cut", p.team)
					_pass(p, cb, false)
					return Vector3.ZERO
		elif dist < 29.0 and absf(p.position.z) < 13.0 and blk == 0 and nd > 3.2 and p.sho >= 70 and randf() < (0.12 + 0.3 * sho_q) * vis:
			# a good shooter with a clear sight of goal just outside the box lets fly
			take = true
			stats["ai_long"] = int(stats.get("ai_long", 0)) + 1
		if take:
			var gk = teams[1 - p.team][0]
			var az := (-1.0 if gk.position.z > 0.0 else 1.0) * GOAL_HW * (0.5 + randf() * 0.28)
			stats["ai_shot"] = int(stats.get("ai_shot", 0)) + 1
			_shoot(p, 0.5 + randf() * 0.4, az, cpu["err"], 0.7 if (p.sho > 74 and randf() < 0.6) else 0.0)
			return Vector3.ZERO
		# A run in behind: a passer with his head up sees it and plays it straight away, he does not
		# wait for the build-up clock. A poor passer or an easy computer side misses more of them.
		if p.hold_t > 0.35 and randf() < (0.3 + 0.55 * pas_q) * vis:
			var th = _ai_thru(p)
			if th != null:
				_ai_mark("ai_thru_lob" if th[1] else "ai_thru", p.team)
				_pass(p, th[0], th[1], false, th[2])
				return Vector3.ZERO
		# Out wide in the last third: whip it in for the men in the box, or pull it back
		var wide_now: bool = absf(p.position.z) > 13.0 and p.position.x * s > HL - 30.0
		if wide_now and p.hold_t > 0.3:
			var deep: bool = p.position.x * s > HL - 17.0
			if deep or tight or nd < 4.5 or p.hold_t > 1.4:
				var cb2 = _ai_better(p, 99.0) if deep else null
				if cb2 != null and randf() < 0.5:
					_ai_mark("ai_cut", p.team)
					_pass(p, cb2, false)
					return Vector3.ZERO
				var cm = _cross_target(p)
				if cm != null and Vector2(HL * s - cm.position.x, cm.position.z).length() < 16.0 and randf() < 0.45 + 0.4 * pas_q:
					_ai_mark("ai_cross", p.team)
					_pass(p, cm, true, true)
					return Vector3.ZERO
		# how long he is happy to keep it: a calm playmaker longer, everybody shorter near their own goal
		var own_d: float = p.position.distance_to(Vector3(-HL * s, 0, 0))
		var keep_t: float = lerpf(1.6, 3.2, randf()) * (0.6 if own_d < 25.0 else 1.0)
		if p.position.x * s > 0.0:
			# calm at the back, but in their half the ball moves quicker
			keep_t *= 0.75
		var closing: bool = nd < 4.5
		var go := false
		var m3 = null
		var behind: bool = near != null and (near.position - p.position).dot(to_goal / maxf(dist, 0.1)) < -0.5
		if tight and behind and p.hold_t < lerpf(0.9, 1.6, clampf((p.ovr - 50) / 40.0, 0.0, 1.0)):
			# a man on his back: he holds him off with his body and waits for a team mate to show
			go = false
		elif tight:
			# someone is right on him from the front: move it on
			go = true
		elif closing:
			# pressure is coming: half the time he plays it, otherwise he keeps it and turns away from it
			go = p.hold_t > 0.9 and randf() < 0.35
		elif p.hold_t > keep_t:
			go = true
		elif p.hold_t > 0.8 and randf() < (0.2 + 0.15 * pas_q) * (1.6 if p.position.x * s > -12.0 else 1.0):
			# room to play: only a real chance makes him pass early (a man free in front, a run in behind)
			m3 = _pass_target(p, Vector3.ZERO, true)
			if m3 != null and (m3.position.x - p.position.x) * s > 10.0:
				go = true
			else:
				m3 = null
		if go:
			if m3 == null:
				m3 = _pass_target(p, Vector3.ZERO, true)
			if m3 != null:
				var gain: float = (m3.position.x - p.position.x) * s
				if tight or closing or p.hold_t > keep_t or gain > 6.0:
					if autotest or OS.get_cmdline_user_args().has("--holddbg"):
						var rk: String = "r_tight" if tight else ("r_close" if closing else ("r_keep" if p.hold_t > keep_t else "r_early"))
						stats[rk] = int(stats.get(rk, 0)) + 1
						hold_m[0] += 1
						hold_m[1] += p.hold_t
					_pass(p, m3, false)
					return Vector3.ZERO
	var dir := to_goal.normalized()
	if dist > 30.0:
		dir = Vector3(s, 0, clampf(-p.position.z * 0.01, -0.3, 0.3)).normalized()
	var ux: float = p.position.x * s
	if absf(p.position.z) > 14.0 and ux > HL - 34.0 and ux < HL - 12.0:
		# a wide man in the last third goes down the line to get the cross in, not into the crowd in the middle
		dir = Vector3(s, 0, -signf(p.position.z) * 0.22).normalized()
	# Take him on: in the last third a quick, good dribbler goes at a lone defender instead of turning back,
	# when there is no second man behind him. Ratings decide who tries it and how often.
	var drb_q: float = clampf(((p.pac + p.ovr) * 0.5 - 55.0) / 35.0, 0.0, 1.0)
	var attack: bool = false
	if near != null and nd < 4.5 and ux > 8.0 and p.skill_t < 0.0 and protect_t <= 0.0:
		var cover := false
		for o6 in teams[1 - p.team]:
			if o6 != near and o6.role != "GK" and o6.position.distance_to(near.position) < 6.0 and (o6.position.x - near.position.x) * s > -1.0:
				cover = true
				break
		if not cover and (near.position - p.position).dot(dir) > 0.0:
			attack = true
			if nd < 2.4 and randf() < dt * (0.6 + 2.2 * drb_q) * _ai_vision(p.team) * (1.4 if p.star else 1.0):
				var sd: float = signf(p.position.z - near.position.z)
				if sd == 0.0:
					sd = 1.0 if randf() < 0.5 else -1.0
				_ai_mark("ai_take", p.team)
				ai_ev[3] = true
				_skill(p, Vector3(s, 0, sd * 0.75))
	if near != null and nd < 5.0:
		var away: Vector3 = (p.position - near.position).normalized()
		var side_step := Vector3(-dir.z, 0, dir.x)
		if side_step.dot(away) < 0.0:
			side_step = -side_step
		# going at him he aims past his shoulder; otherwise he turns away from him
		dir = (dir + side_step * (1.0 - nd / 5.0) * (0.6 if attack else 1.3)).normalized()
	if absf(p.position.z) > HW - 3.0 and signf(dir.z) == signf(p.position.z):
		dir.z *= -0.5
	# Building up he jogs with it, head up, instead of sprinting into the next man; he only runs at
	# full pace into open grass near their goal or on the break.
	var pace_k := 0.99
	var brk: bool = sim_t - poss_t < 4.0 or dist < 30.0
	if not brk:
		pace_k = 0.88
		if ux > -15.0 and (near == null or nd > 9.0 or (near.position - p.position).dot(dir) < 0.0):
			# open grass in front of him past halfway: he drives into it, like FIFA's AI does
			pace_k = 0.96
	if near != null and nd > 3.0 and nd < 9.0 and (near.position - p.position).dot(dir) > 0.0 and dist > 24.0:
		# a man stands off him in the way: no point running into him, he slows down, keeps it and looks up
		pace_k = 0.55
	return dir.normalized() * p.top_speed * p.carry_k * pace_k * cpu["spd"]

func _ai_offball(p, chaser: Array, second: Array, aim: Vector3) -> Vector3:
	var t: int = p.team
	var s := side(t)
	var cpu := _cpu(t)
	var loose: bool = ball_owner == null
	var ours: bool = not loose and ball_owner.team == t
	p.jock = false
	p.ai_tag = "spot"
	if p.recv and loose:
		return _run_to(p, _meet_for(p, aim), p.top_speed)
	if loose and p == chaser[t]:
		var rk := 1.0
		if ball_last != null and ball_last.team != t and ball.position.y > 1.0 and sim_t - loft_at < 0.5:
			# a ball played over him: he first has to see it, turn and set off, the runner is already going
			rk = 0.35
		return _run_to(p, aim, p.top_speed * cpu["spd"] * rk)
	if not loose and not ours and ball_owner.hands():
		# The keeper has it in his hands: like real players, everybody drops out of the box and gives
		# him room to throw or kick it out, nobody stands in front of him.
		var gk = ball_owner
		var gx: float = signf(gk.position.x) * HL
		var spot: Vector3 = p.position
		var away: Vector3 = spot - gk.position
		away.y = 0.0
		if away.length() < 14.0:
			if away.length() < 0.5:
				away = Vector3(-signf(gx), 0, 0.3)
			spot = gk.position + away.normalized() * 14.0
		if absf(spot.x - gx) < 18.0 and absf(spot.z) < 21.5:
			spot.x = gx - signf(gx) * 18.5
		spot.x = clampf(spot.x, -HL + 1.0, HL - 1.0)
		spot.z = clampf(spot.z, -HW + 1.0, HW - 1.0)
		if p.position.distance_to(spot) < 1.0:
			return Vector3.ZERO
		return _run_to(p, spot, p.top_speed * 0.8)
	if not loose and not ours and set_piece == "":
		var c = ball_owner
		var own_goal := Vector3(-HL * s, 0, 0)
		var goal_side: Vector3 = (own_goal - c.position).normalized()
		if p == chaser[t]:
			p.ai_tag = "chase"
			if _team_human(t):
				# your team mate holds the runner up; you make the tackle.
				# But if you are far away, or the runner is close to your goal, he goes in himself.
				var hd := 99.0
				for hm in humans:
					if hm.team == t and hm.ctrl != null:
						hd = minf(hd, hm.ctrl.position.distance_to(c.position))
				if not _press_on(t, c) and hd > 4.5:
					# your mates do not hunt him all over the pitch either: they block the way forward
					return _run_to(p, c.position + c.vel * 0.4 + goal_side * 7.0, p.top_speed * 0.9)
				if hd > 4.5 or c.position.distance_to(own_goal) < 30.0:
					return _run_to(p, c.position + c.vel * 0.25 + goal_side * 0.5, p.top_speed * 0.95)
				return _run_to(p, c.position + goal_side * 2.6, p.top_speed * 0.95)
			# Defending like a real defender: get goal side, hold him up at arm's length and follow,
			# and only step in when he slows down, comes close to goal, or has been held up for a while.
			var dd: float = p.position.distance_to(c.position)
			var gs: bool = (p.position - c.position).dot(goal_side) > 0.25 * dd
			var gd: float = c.position.distance_to(own_goal)
			if p.step_t <= 0.0 and not _press_on(t, c):
				# Not a moment to press: sit off him in the way to goal and shut the pass forward, but let him
				# have the ball. He is closed down when he comes into our half or a trigger comes.
				p.wait_t = 0.0
				p.jock = dd < 12.0
				return _run_to(p, c.position + c.vel * 0.4 + goal_side * 7.5, p.top_speed * 0.85 * cpu["spd"])
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
			p.ai_tag = "second"
			# the cover man shuts the road to goal behind the first defender
			var cvd: float = clampf(c.position.distance_to(own_goal) * 0.22, 3.5, 6.5)
			if not _press_on(t, c):
				cvd = 11.0
			return _run_to(p, c.position + c.vel * 0.3 + goal_side * cvd, p.top_speed * 0.97)
	var bu: float = ball.position.x * s
	var att: bool = att_team == t
	var u: float = -45.0 + p.home.x * 62.0 + bu * 0.6
	var z: float = p.home.y * s * 21.0 + ball.position.z * 0.42
	var hurry := false
	# the manager's plan: how far up the team sits, and how wide it plays
	var tm: float = float(int(tac_t[t][0]) - 2)
	var tw: float = [0.82, 1.0, 1.18][int(tac_t[t][2])]
	u += tm * 3.2
	if att:
		# With the ball the whole team moves up with it, like a real side: the back line squeezes up,
		# the midfield stays close around the ball, full backs overlap and the forwards stretch the line.
		var wide: bool = absf(p.home.y) > 0.6
		var same: bool = p.home.y * s * ball.position.z > 0.0
		z = p.home.y * s * 29.0 * tw + ball.position.z * 0.25
		u = bu + (p.home.x - 0.40) * 50.0 + tm * 2.5
		if p.role == "DF":
			if wide:
				u = clampf(bu - (4.0 if same and bu > 0.0 else 14.0), -40.0, 40.0)
			else:
				u = clampf(bu - 24.0 + tm * 3.5, -42.0, 8.0 + tm * 3.0)
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
		# Without the ball the back four hold a line instead of running back to the six-yard box: they stay
		# around the edge of the box while the ball is out in front, and drop off with it, a few metres goal
		# side, as it comes at them. Close to goal they squeeze in towards the ball.
		var dl: float = minf(-35.5 + (p.home.x - 0.17) * 20.0 + tm * 3.0 + (int(tac_t[t][1]) - 1) * 3.0, bu - 7.0)
		u = clampf(maxf(u, dl), -47.0, 14.0)
		if not loose and ball_owner.team != t:
			u = maxf(minf(u, ball_owner.position.x * s - 2.5), -50.5)
		var near_k: float = clampf((-bu - 15.0) / 25.0, 0.0, 1.0)
		z = p.home.y * s * lerpf(21.0, 14.0, near_k) * tw + ball.position.z * lerpf(0.42, 0.6, near_k)
	else:
		u = clampf(u, -40.0, 47.0)
		z = p.home.y * s * 21.0 * tw + ball.position.z * 0.42
	z = clampf(z, -HW + 1.5, HW - 1.5)
	var spot := Vector3(u * s, 0, z)
	if not ours and not loose and set_piece == "" and p != chaser[t] and p != second[t] and (p.role == "DF" or p.role == "MF"):
		var c4 = ball_owner
		var og4 := Vector3(-HL * s, 0, 0)
		var cu: float = c4.position.x * s
		var dc4: float = p.position.distance_to(c4.position)
		if p.position.x * s > cu + 0.5 and dc4 < (30.0 if p.role == "DF" else 13.0) and absf(p.position.z - c4.position.z) < 22.0:
			# Beaten, or caught up the pitch: turn and sprint back to get goal side of him again,
			# each man to his own lane so they do not all run to the same spot.
			var gsd: Vector3 = (og4 - c4.position).normalized()
			var rec: Vector3 = c4.position + c4.vel * 0.5 + gsd * clampf(c4.position.distance_to(og4) * 0.25, 3.0, 8.0)
			rec.z = lerpf(rec.z, spot.z, 0.45)
			p.ai_tag = "recover"
			return _run_to(p, rec, p.top_speed)
		if p.role == "DF" and c4.position.distance_to(og4) < 40.0 and p.vel.length() < p.top_speed * 0.75:
			# on his toes and watching the ball, not standing there looking at nothing
			p.jock = true
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
					# a forward runs through the middle channels, towards goal, not off to the flag
					gap -= absf(dz) * 0.15 + absf(zz) * (0.05 if absf(zz) < 12.0 else 0.22)
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
			p.ai_tag = "mark"
			var og := Vector3(-HL * s, 0, 0)
			var gs2: Vector3 = (og - mk.position).normalized()
			var tb: Vector3 = (ball.position - mk.position)
			tb.y = 0.0
			# goal side and a touch towards the ball, so a pass to him can be cut out
			# close to the ball tight on him; further away a couple of metres off, ready to step in
			var mgap: float = 2.5 if mk.position.distance_to(ball.position) < 15.0 else 3.2
			var mp: Vector3 = mk.position + gs2 * mgap + tb.normalized() * 0.7
			# a man running in behind the line is tracked all the way, at full speed
			var behind: bool = mk.position.x * s < p.position.x * s + 1.0 and mk.vel.dot(gs2) > 2.0
			spot = spot.lerp(mp, 0.9 if behind else (0.7 if p.role != "DF" else 0.6))
			return _run_to(p, spot, p.top_speed * (1.0 if behind else 0.92))
	return _run_to(p, spot, p.top_speed * (1.0 if hurry else 0.88))

# how long the ball takes to cover dx along the pitch length; in the air it slows with the drag
func _t_to_x(dx: float) -> float:
	if absf(ball_vel.x) < 0.5 or dx * ball_vel.x <= 0.0:
		return -1.0
	if ball.position.y < BALL_R + 0.02 and ball_vel.y <= 0.0:
		return dx / ball_vel.x
	var sp := ball_vel.length()
	var path := absf(dx) * sp / absf(ball_vel.x)
	return (exp(AIR_K * path) - 1.0) / (AIR_K * sp)

func _ai_keeper(p, dt: float) -> Vector3:
	var s := side(p.team)
	var gx := -HL * s
	var goal := Vector3(gx, 0, 0)
	var b := ball.position
	if ball_owner == null and ball_vel.x * -s > 5.0:
		var t := _t_to_x(gx - b.x)
		if t > 0.0 and t < 1.7:
			var zc := b.z + ball_vel.z * t
			if ball_spin != 0.0:
				# the keeper reads most of the bend on a curled shot
				var bent := ball_vel.rotated(Vector3.UP, ball_spin * t * 0.45)
				if absf(bent.x) > 1.0:
					zc = b.z + bent.z * ((gx - b.x) / bent.x)
			if pen_shot and shot_live:
				# a penalty: he has picked his side as it was struck and goes there
				zc = p.pen_z
			if absf(zc) < GOAL_HW + 1.2:
				p.react_t += dt
				if p.react_t < (0.06 if (pen_shot and shot_live) else lerpf(0.33, 0.20, clampf((p.dfn - 50) / 42.0, 0.0, 1.0))):
					return p.vel * 0.5
				var target := Vector3(gx + s * 0.7, 0, clampf(zc, -GOAL_HW + 0.2, GOAL_HW - 0.2))
				# off his line he saves where he stands instead of running back to the goal line
				var tk: float = _t_to_x(p.position.x - b.x)
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
				if absf(dz) > 0.7 and t < 0.6 and p.dive_t < 0.0:
					var right := Vector3(cos(p.yaw), 0, -sin(p.yaw))
					p.start_dive(signf(Vector3(0, 0, dz).dot(right)))
					p.vel = Vector3(0, 0, signf(dz) * DIVE_V)
				if p.dive_t >= 0.0:
					# in the air he keeps his speed all the way to the ball
					var dv: Vector3 = target - p.position
					dv.y = 0.0
					return dv.normalized() * DIVE_V if dv.length() > 0.25 else Vector3.ZERO
				return _run_to(p, target, 3.9)
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
		"_": "s", "st": state, "t": snappedf(state_t, 0.01), "sc": score, "ck": int(clock), "so": [so_g[0], so_g[1], so_win], "p": _pack(),
		"h": hc, "c": ch, "e": out_ev, "sr": players.find(scorer), "rp": hud.replay_on, "rf": [snappedf(ref.position.x, 0.01), snappedf(ref.position.z, 0.01), snappedf(ref.yaw, 0.01), ref.card_up, snappedf(ref.vel.x, 0.1), snappedf(ref.vel.z, 0.1), players.find(book_p) if book_t >= 0.0 else -1] if ref != null else [],
		"ts": tst if state == "full" else null, "co": co_pay if (state == "full" and career_on) else null, "sm": snappedf(humans[1].stam, 0.02) if humans.size() > 1 else 1.0,
		"pq": humans[1].psq if humans.size() > 1 else -1,
		"prt": snappedf(_pro_rating(humans[1], "pro2"), 0.1) if (humans.size() > 1 and humans[1].psq >= 0 and _pro_man(humans[1]) != null and not humans[1].ptrk.is_empty()) else -1.0,
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
		if snap.get("so") != null:
			var sa: Array = snap["so"]
			so_g = [int(sa[0]), int(sa[1])]
			so_win = int(sa[2])
		clock = float(snap["ck"])
		hud.set_score(score[0], score[1])
		hud.replay_on = bool(snap.get("rp", false))
		anim_rate = 0.55 if state == "replay" else 1.0
		var si := int(snap.get("sr", -1))
		scorer = players[si] if si >= 0 else null
		var rf: Array = snap.get("rf", [])
		if rf.size() >= 7:
			_ref_make()
			ref.position = Vector3(float(rf[0]), 0, float(rf[1]))
			ref.yaw = float(rf[2])
			ref.card_up = int(rf[3])
			ref.vel = Vector3(float(rf[4]), 0, float(rf[5]))
			var bi := int(rf[6])
			book_p = players[bi] if bi >= 0 and bi < players.size() else null
			book_t = 1.0 if book_p != null else -1.0
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
			# the player career: the friend's thumb is his own man too (no switch button)
			humans[me].psq = int(snap.get("pq", -1))
			guest_prt = float(snap.get("prt", -1.0))
		if state == "full" and snap.get("co") != null and not co_got:
			# a career match played together pays the guest's own club too
			co_got = true
			var cp: Array = snap["co"]
			if not car.has_save():
				car.new_career(-1)
			car_lines = car.coop_reward(int(cp[0]), bool(cp[1]))
			car_lines.append_array(cp[2])
			if cp.size() > 3 and cp[3] is Dictionary:
				pro_bar = cp[3]
			if prev == "full":
				hud.show_menu("full", _menu_info())
		if state == "full" and prev != "full":
			if rk_on:
				_rk_finish()
			elif not career_on and not co_got and snap.get("co") == null:
				car_lines = _friend_reward()
			_rec_add(false)
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
	_fr_tick(dt)
	if rk_looking and hud.menu_name == "rk_find":
		var was_s := int(rk_t)
		rk_t += dt
		if int(rk_t) != was_s:
			hud.refresh(_menu_info())
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
	var top: bool = cam_mode == 1 and not (state == "dead" and book_t >= 0.0 and book_p != null)
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
		var lnd := _land()
		var t: float = lnd[1]
		if t > 0.25:
			var lp: Vector3 = lnd[0]
			if absf(lp.x) < HL and absf(lp.z) < HW:
				land_ring.position = Vector3(lp.x, 0.05, lp.z)
				show_ring = true
	if not show_ring and state == "play" and set_piece == "corner" and screen == "match" and humans.size() > me and humans[me].ctrl != null and ball_owner == humans[me].ctrl:
		# your corner: the ring shows where your cross will drop, and moves with the stick
		var ca := _corner_aim(humans[me].ctrl, _stick() * view_flip)
		land_ring.position = Vector3(ca.x, 0.05, ca.z)
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
	if ref != null:
		ref.set_top(top)
	if not paused and screen == "match":
		_ref_tick(dt)
		if ref != null:
			ref.animate(dt * anim_rate)
	elif ref != null:
		ref.visible = false
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
			if hm.psq >= 0:
				# the player career: you are one man, so no switching. With the ball at a team mate you call for it
				hud.lab_b = "PASS" if mine2 else ("AUTO ON" if hm.auto_on else ("CALL" if ours else "AUTO"))
				if _pro_man(hm) == null:
					hud.lab_b = "PASS" if mine2 else "SWITCH" # on the bench: you help like in a normal match
			hud.charge = hm.charge
			hud.stam = hm.stam
			hud.ctrl_name = ("%d  %s  %d" % [hm.ctrl.num, hm.ctrl.pname.to_upper(), hm.ctrl.ovr]) if hm.ctrl != null else ""
			# the player career: your match rating, live
			hud.pro_rt = -1.0
			if net.role == "guest":
				hud.pro_rt = guest_prt
			elif hm.psq >= 0 and _pro_man(hm) != null and not hm.ptrk.is_empty():
				hud.pro_rt = _pro_rating(hm, "pro" if me == 0 else "pro2")
			if prbadge:
				hud.pro_rt = 6.0 + floorf(real_t * 0.5) * 0.3
			if state == "play" and hm.ctrl != null and ball_owner == hm.ctrl and set_piece != "pen":
				var st2 := _stick() * view_flip
				# the hint shows the man the ball would go to if you let go now (the hold reaches further)
				var hpw := -1.0
				if hm.pass_hold >= 0.0:
					hpw = maxf(clampf(hm.pass_hold / 0.6, 0.0, 1.0), 0.01)
				elif hm.thru_hold >= 0.0:
					hpw = maxf(clampf(hm.thru_hold / 0.6, 0.0, 1.0), 0.01)
				elif hm.lob_hold >= 0.0:
					hpw = 0.3 + 0.7 * clampf(hm.lob_hold / 0.6, 0.0, 1.0)
				var tgt = _pass_target(hm.ctrl, Vector3(st2.x, 0, st2.y), false, hpw, hm.thru_hold >= 0.0)
				if tgt != null:
					tgt.set_hint(Color(0.55, 0.95, 1.0))
		_minimap()
	_crowd_feed(rdt)
	_camera(rdt)
	if test_drag.size() >= 4 and real_t >= 1.0:
		var a0 := Vector2(test_drag[0], test_drag[1])
		var a1 := Vector2(test_drag[2], test_drag[3])
		var k := clampf((real_t - 1.0) / 0.5, 0.0, 1.0)
		var hold := test_drag.size() > 4
		if not has_meta("drag0"):
			set_meta("drag0", true)
			var e0 := InputEventMouseButton.new()
			e0.button_index = MOUSE_BUTTON_LEFT
			e0.pressed = true
			e0.position = a0
			e0.global_position = a0
			Input.parse_input_event(e0)
		var em := InputEventMouseMotion.new()
		em.position = a0.lerp(a1, k)
		em.global_position = em.position
		em.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(em)
		if k >= 1.0 and not hold:
			var e1 := InputEventMouseButton.new()
			e1.button_index = MOUSE_BUTTON_LEFT
			e1.pressed = false
			e1.position = a1
			e1.global_position = a1
			Input.parse_input_event(e1)
			test_drag = []
	if shot_path != "" and OS.get_environment("STRIP") != "":
		# test pictures of a computer attack: a frame every 0.6 s once team 1 has it in the last 40 m
		if strip_n < 0 and real_t > shot_at and ball_owner != null and ball_owner.team == 1 and ball_owner.position.x * side(1) > HL - 40.0 and state == "play":
			strip_n = 0
			strip_t = real_t
		if strip_n >= 0 and real_t >= strip_t:
			get_viewport().get_texture().get_image().save_png(shot_path.replace(".png", "_%d.png" % strip_n))
			strip_n += 1
			strip_t = real_t + 0.6
			if strip_n >= int(OS.get_environment("STRIP")):
				get_tree().quit()
		return
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
	elif state == "dead" and book_t >= 0.0 and book_p != null and is_instance_valid(book_p) and ref != null:
		# the booking, close up from the side: the referee, the card, the man
		var mid: Vector3 = (ref.position + book_p.position) * 0.5
		var ax: Vector3 = book_p.position - ref.position
		ax.y = 0.0
		var nrm := Vector3(-ax.z, 0, ax.x).normalized() if ax.length() > 0.1 else Vector3(0, 0, 1)
		if nrm.z * view_flip < 0.0:
			nrm = -nrm
		want_look = mid + Vector3(0, 1.5, 0)
		want_pos = mid + nrm * 6.5 + Vector3(0, 2.0, 0)
		want_fov = 40.0
		k = 3.0
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
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--longsho=") and lp != null:
					lp.sho = int(a.substr(10))
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
			if set_piece == "pen" or (so_on and h.charging):
				# a penalty: aim for a corner like a person would
				if not bot_t.has(id + 1):
					bot_t[id + 1] = randf_range(-1.0, 1.0)
					for a in OS.get_cmdline_user_args():
						if a.begins_with("--penaim="):
							bot_t[id + 1] = float(a.substr(9)) * (1.0 if randf() < 0.5 else -1.0)
				h.stick = Vector2(s * 0.3, bot_t[id + 1])
			else:
				bot_t.erase(id + 1)
			var pth := 0.55
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--penpw=") and set_piece == "pen":
					pth = float(a.substr(8))
			if h.charging:
				if h.charge > pth:
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

# ---------------------------------------------------------------- the assistant manager (playing a career together)
# The host's phone sends its career to the friend's phone whenever it changes. The friend can open it and look at
# everything: the squad, the table, the transfers, the club and the office. What he changes there is not done: it goes
# to the manager as a suggestion, and the manager says yes or no.
const AS_LOOK := ["tab", "c_table", "c_squad", "c_board", "c_club", "c_market", "scout", "sc_lg", "sc_club", "sc_pl", "sc_back",
	"c_ab", "c_abback", "c_review", "cup", "how_ok", "how", "as_open", "as_back", "career", "c_trainm", "pause", "resume", "snd_opt", "voice_opt", "mtac", "mtac_set",
	"cab", "cab_tab", "cal", "inbox", "mail", "tnews", "scorers", "eu", "youth", "y_tab", "y_pick", "adv_done", "ct_back", "cset", "ct_open", "ct_w", "ct_y", "p_skills", "ctac", "nat", "nat_tab", "ct_rc", "sc_swp"]
const AS_SUG := ["c_train", "c_abuy", "c_tp", "c_fac", "c_buy", "c_spot", "c_swap", "c_lay0", "c_form", "sc_bid", "c_plan",
	"bid_acc", "bid_rej", "bid_more", "mail_pick", "c_adv", "c_rt", "y_sign", "y_prom", "y_rel", "y_send", "c_focus", "c_sim",
	"cfg_diff", "cfg_len", "c_wb", "y_hire", "y_drop", "c_job", "c_next", "ct_go", "tac_set", "nat_pick", "nat_auto", "nat_quit", "nat_play", "sc_bid_so", "sc_rc", "sc_swap", "bid_son"]

func _cv_tick(dt: float) -> void:
	var src = proc if car == proc else carc
	if net.role != "host" or not net.connected or rk_on or rk_looking or not in_career or not src.has_save():
		return
	cv_t -= dt
	if cv_t > 0.0:
		return
	cv_t = 1.0
	var txt := JSON.stringify(src.d)
	var hh := txt.hash()
	if hh != cv_last:
		cv_last = hh
		net.send({"_": "cv", "d": txt})
	_sug_next()

func _as_open() -> void:
	if not carv.has_save():
		return
	if not assist:
		as_prev = car
	assist = true
	car = carv
	# the player career, the first time: straight to making your own player
	hub_tab = "pro" if car.pro() and not car.pro2() else "career"
	car_sel = -1
	car_sell = -1
	car_msg = ""
	scout_res = {}
	_apply_own()
	_show_hub()

func _as_leave(show: bool) -> void:
	if not assist:
		return
	assist = false
	car = as_prev if as_prev != null else car_main
	as_prev = null
	car_sel = -1
	car_sell = -1
	car_msg = ""
	_apply_own()
	if show:
		if screen == "match":
			hud.show_menu("full" if state == "full" else "", _menu_info())
		elif net.connected:
			hud.show_menu("lobby", _menu_info())
		else:
			_show_hub()

# The assistant's tap: looking is fine, a change becomes a suggestion, the rest is the manager's.
func _as_take(act: String, arg) -> bool:
	if act in ["back", "menu"]:
		# back inside the career's menus: to its home screen, never out of the room
		_show_hub()
		return true
	if act in ["c_play", "cup_play", "eu_play"]:
		if car.pro() and not car.pro2():
			hud.toast("Make your own player first")
			hub_tab = "pro"
			_show_hub()
			return true
		co_rdy[1] = not co_rdy[1]
		net.send({"_": "rdy", "r": co_rdy[1]})
		audio.play("click2")
		hud.refresh(_menu_info())
		return true
	if act in ["co_back", "co_leave"]:
		return false
	if act == "friend":
		hud.toast("You are already in the career together")
		return true
	if act in ["cr_exit", "c_home"]:
		if act == "c_home":
			hub_tab = "career"
			_show_hub()
		else:
			_as_leave(true)
		return true
	if act == "c_pick":
		return false
	if act == "c_sell":
		if car_sel >= 0:
			_as_suggest("c_sell", null)
			return true
		return false
	if act == "p_spend":
		# your own player's points are yours to spend
		net.send({"_": "psp", "si": int(arg)})
		audio.play("click2")
		return false
	if act in ["p_drill", "p_learn"]:
		# your own player's training and skills are yours too: the manager's phone does the same for your man
		net.send({"_": "pdev", "a": act, "x": arg})
		return false
	if act in ["p_pos", "p_name", "p2_make", "p_skills"]:
		return false
	if act == "ct_go":
		var tk: Dictionary = car.talk()
		if tk.is_empty() or str(tk.get("kind", "")) != "renew":
			return true
		_as_suggest("ct_go", [int(tk["i"]), int(tk["offer"]), int(tk["yrs"]), int(tk.get("rc", 0))])
		car.talk_end()
		hud.show_menu("squad", _menu_info())
		return true
	if act in AS_SUG:
		_as_suggest(act, arg)
		return true
	if act in AS_LOOK or act == "key":
		return false
	hud.toast("The manager decides that. Your changes go to him as suggestions.")
	return true

func _as_suggest(act: String, arg) -> void:
	var t := _sug_text(act, arg)
	if t == "":
		return
	net.send({"_": "sug", "act": act, "arg": arg, "ui": {"sel": car_sel, "ab": ab_slot, "sc": scout_c, "si": scout_i}, "t": t})
	hud.toast("SUGGESTION SENT TO THE MANAGER: " + t)
	car_sel = -1
	car_sell = -1
	car_msg = ""
	if act == "c_abuy":
		hud.show_menu("squad", _menu_info())
	else:
		hud.refresh(_menu_info())

func _pn(i: int) -> String:
	var sq: Array = car.d["squad"]
	return str(sq[i]["n"]).to_upper() if i >= 0 and i < sq.size() else ""

# What a suggestion does, in words. The host's phone works it out again: if it does not say the same, it is out of date.
func _sug_text(act: String, arg) -> String:
	match act:
		"bid_acc", "bid_rej", "bid_more", "bid_son":
			var bm: Dictionary = car.mail(int(arg))
			if bm.is_empty() or str(bm.get("st", "")) != "open":
				return ""
			if act == "bid_son":
				return "SELL %s WITH A %d%% SELL-ON" % [str(bm["pn"]), Career.SELLON_PCT]
			return ("SELL %s FOR %s" if act == "bid_acc" else ("SAY NO TO THE BID FOR %s" if act == "bid_rej" else "ASK FOR MORE FOR %s")) % ([str(bm["pn"]), car.money(int(bm["amt"]))] if act == "bid_acc" else [str(bm["pn"])])
		"mail_pick":
			var ma: Array = arg if arg is Array else []
			if ma.size() < 2:
				return ""
			var mm: Dictionary = car.mail(int(ma[0]))
			var mo: Array = mm.get("opts", [])
			if mm.is_empty() or str(mm.get("st", "")) != "open" or int(ma[1]) < 0 or int(ma[1]) >= mo.size():
				return ""
			return "ANSWER: %s" % str(mo[int(ma[1])][0]).to_upper()
		"nat_pick":
			var pk := str(arg)
			var nin: bool = car.nat().get("sq", []).has(pk)
			for pl in car.nat_pool(int(car.nat().get("n", 0))) if car.nat_job() else []:
				if str(pl["key"]) == pk:
					return ("SEND %s HOME" if nin else "CALL UP %s") % str(pl["n"]).to_upper()
			return ""
		"nat_auto":
			return "CALL UP THE BEST 23" if car.nat_job() else ""
		"nat_quit":
			return "LEAVE THE NATIONAL TEAM" if car.nat_job() else ""
		"tac_set":
			var tg: Array = arg if arg is Array else []
			if tg.size() < 2 or int(tg[0]) < 0 or int(tg[0]) > 2:
				return ""
			var tn: Array = Career.TAC_N[int(tg[0])]
			var tv := clampi(int(tg[1]), 0, tn.size() - 1)
			return ["PLAY: %s", "PRESS: %s", "WIDTH: %s"][int(tg[0])] % str(tn[tv]).to_upper()
		"cfg_diff":
			return "PLAY THE MATCHES ON %s" % ["EASY", "NORMAL", "HARD"][clampi(int(arg), 0, 2)]
		"cfg_len":
			return "MAKE THE MATCHES %s" % ["3 MIN", "5 MIN", "8 MIN"][clampi(int(arg), 0, 2)]
		"c_wb":
			return "MOVE MONEY TO THE WAGE BUDGET" if str(arg) == "up" else "MOVE WAGE MONEY TO TRANSFERS"
		"y_hire":
			return "HIRE OR UPGRADE YOUTH SCOUT %d" % ((int(arg) if arg != null else 0) + 1)
		"y_drop":
			return "SAY NO TO YOUTH TALENT %d" % ((int(arg) if arg != null else 0) + 1)
		"c_job":
			var jo: Array = car.offers()
			var ji := int(arg) if arg != null else -1
			if ji < 0 or ji >= jo.size():
				return ""
			return "TAKE THE JOB AT %s" % str(jo[ji]["n"]).to_upper()
		"c_next":
			return "START THE NEXT SEASON" if car.season_over() else ""
		"ct_go":
			var ca: Array = arg if arg is Array else []
			if ca.size() < 3 or int(ca[0]) < 0 or int(ca[0]) >= (car.d["squad"] as Array).size():
				return ""
			return "NEW CONTRACT FOR %s: %s A WEEK FOR %d SEASONS" % [_pn(int(ca[0])), Career.wage_text(int(ca[1])), int(ca[2])]
		"c_sim":
			return "SIMULATE THE NEXT MATCH"
		"c_adv":
			return "GO ON TO THE NEXT DAY"
		"y_sign", "y_prom", "y_rel", "y_send":
			return {"y_sign": "SIGN YOUTH TALENT %d", "y_prom": "PROMOTE ACADEMY PLAYER %d", "y_rel": "RELEASE ACADEMY PLAYER %d", "y_send": "SEND A SCOUT (%d)"}[act] % ((int(arg) if arg != null else 0) + 1)
		"c_focus":
			return "CHANGE %s'S TRAINING FOCUS" % _pn(car_sel) if car_sel >= 0 else ""
		"c_rt":
			return "RETRAIN %s FOR A NEW POSITION" % _pn(car_sel) if car_sel >= 0 else ""
		"c_train":
			return "TRAIN %s" % _pn(car_sel) if car_sel >= 0 else ""
		"c_abuy":
			return "TEACH %s: %s" % [_pn(car_sel), str(Career.ABIL[str(arg)][0]).to_upper()] if car_sel >= 0 and Career.ABIL.has(str(arg)) else ""
		"c_tp":
			return "%s GETS BETTER AT %s" % [_pn(car_sel), Career.stat_name(str(car.d["squad"][car_sel]["pos"]), int(arg))] if car_sel >= 0 else ""
		"c_fac":
			return "BUILD: %s" % str(arg).to_upper()
		"c_buy":
			var m: Array = car.market()
			var i := int(arg)
			if i < 0 or i >= m.size():
				return ""
			return "SIGN %s (%s) FOR %s" % [str(m[i]["n"]).to_upper(), str(m[i]["pos"]), car.money(car.value(m[i]))]
		"c_sell":
			if car_sel < 0:
				return ""
			return ("TAKE %s OFF THE TRANSFER LIST" if Career.listed(car.d["squad"][car_sel]) else "PUT %s ON THE TRANSFER LIST") % _pn(car_sel)
		"c_swap":
			var ws: Array = arg
			return "SWAP %s AND %s" % [_pn(int(ws[0])), _pn(int(ws[1]))]
		"c_spot":
			var sa: Array = arg
			var xi: Array = car.d["xi"]
			var sl := int(sa[0])
			return "MOVE %s TO A NEW SPOT" % _pn(int(xi[sl])) if sl >= 0 and sl < xi.size() else ""
		"c_lay0":
			return "PUT EVERY MAN BACK ON HIS NORMAL SPOT"
		"c_plan":
			var pa2: Array = arg
			var pp: Dictionary = car.plan()
			var f2 := str(pa2[0]) if str(pa2[0]) != "" else str(pp["f"])
			var i2 := int(pa2[1]) if int(pa2[1]) >= 0 else int(pp["i"])
			return "TRAINING: %s, %s" % [Career.FOCI[f2][0], Career.INTENS[i2][0]]
		"c_form":
			return "PLAY %s" % FORM_NAMES[(FORM_NAMES.find(car.form()) + 1) % FORM_NAMES.size()]
		"sc_bid":
			if scout_c < 0 or scout_i < 0:
				return ""
			var cs: Array = car.cpu_squad(scout_c)
			if scout_i >= cs.size():
				return ""
			return "BID %s FOR %s OF %s" % [car.money(int(arg)), str(cs[scout_i]["n"]).to_upper(), str(CLUBS[scout_c]["n"])]
		"sc_bid_so", "sc_rc", "sc_swap":
			if scout_c < 0 or scout_i < 0:
				return ""
			var cs2: Array = car.cpu_squad(scout_c)
			if scout_i >= cs2.size():
				return ""
			var who := str(cs2[scout_i]["n"]).to_upper()
			if act == "sc_rc":
				return "PAY THE RELEASE CLAUSE (%s) FOR %s" % [car.money(car.cpu_clause(scout_c, scout_i)), who]
			if act == "sc_swap":
				return "OFFER %s + MONEY FOR %s" % [str(arg).to_upper(), who]
			return "BID %s WITH A %d%% SELL-ON FOR %s" % [car.money(int(arg)), Career.SELLON_PCT, who]
	return ""

# The manager's phone: one suggestion at a time, on top of whatever menu is open.
func _sug_next() -> void:
	if not sug_cur.is_empty() or sugs.is_empty() or hud.menu_name == "sug" or hud.menu_name == "":
		return
	if not (screen == "menu" or (screen == "match" and state == "full")):
		return
	sug_cur = sugs.pop_front()
	sug_prev = hud.menu_name
	audio.play("click2")
	hud.show_menu("sug", _menu_info())

func _sug_answer(yes: bool) -> void:
	var s := sug_cur
	sug_cur = {}
	if s.is_empty():
		return
	var res := ""
	var ok := false
	if yes and in_career and (car == carc or car == proc):
		var ui: Dictionary = s.get("ui", {}) if s.get("ui", {}) is Dictionary else {}
		var keep := [car_sel, car_sell, ab_slot, scout_c, scout_i, scout_res, car_msg]
		car_sel = int(ui.get("sel", -1))
		car_sell = car_sel
		ab_slot = int(ui.get("ab", 0))
		scout_c = int(ui.get("sc", -1))
		scout_i = int(ui.get("si", -1))
		var act := str(s.get("act", ""))
		if act in AS_SUG or act == "c_sell":
			if _sug_text(act, s.get("arg")) != str(s.get("t", "")):
				res = "(TOO LATE: SOMETHING CHANGED)"
			else:
				car_msg = ""
				scout_res = {}
				_action(act, s.get("arg"))
				ok = true
				res = car_msg if car_msg != "" else str(scout_res.get("msg", scout_res.get("t", "")))
		car_sel = keep[0]
		car_sell = keep[1]
		ab_slot = keep[2]
		scout_c = keep[3]
		scout_i = keep[4]
		scout_res = keep[5]
		car_msg = keep[6]
		if res != "":
			hud.toast(res)
	net.send({"_": "sugr", "ok": yes and ok, "t": str(s.get("t", "")), "r": res})
	cv_t = 0.0
	var pm := sug_prev if sug_prev != "" and sug_prev != "sug" else "main"
	sug_prev = ""
	hud.show_menu(pm, _menu_info())
	_sug_next()

# The career has its own euros, but your club outside earns a few coins from it too (Daniel): a little for a match,
# much more for winning the league or the cup, something for going up.
const CAR_COINS := {"w": 5, "d": 2, "l": 1, "title": 300, "up": 150, "cup": 250}

func _car_coins(league: bool) -> void:
	if (car != carc and car != proc) or cup_mode or not in_career:
		return
	var n := 0
	var why := []
	var won: bool = score[0] > score[1] or (not league and _winner() == 0)
	n += int(CAR_COINS["w"]) if won else (int(CAR_COINS["d"]) if score[0] == score[1] else int(CAR_COINS["l"]))
	if league and car.season_over():
		var pos: int = car.rank_of(int(car.d["club"]))
		if pos == 1:
			n += int(CAR_COINS["title"])
			why.append("THE TITLE")
		elif int(car.d.get("move", 0)) < 0:
			n += int(CAR_COINS["up"])
			why.append("PROMOTION")
	if not league and bool(car.cup().get("won", false)) and won:
		n += int(CAR_COINS["cup"])
		why.append("THE CUP")
	car_main.d["coins"] = int(car_main.d["coins"]) + n
	car_main.save()
	car_lines.append("+%d COINS FOR YOUR CLUB%s" % [n, (" (" + " + ".join(PackedStringArray(why)) + ")") if not why.is_empty() else ""])

# ---------------------------------------------------------------- the career together: both in the career, both start the match
func _co_ready_send() -> void:
	net.send({"_": "rdy", "h": co_rdy})

func _co_go() -> void:
	co_rdy = [false, false]
	_co_ready_send()
	if car == proc and car.pro() and not car.pro2():
		# the player career together: your friend plays his own man, so he makes him first
		hud.toast("Your friend makes his own player first")
		hud.refresh(_menu_info())
		return
	opt_mode = "coop"
	opt_car = true
	opt_cup = false
	_host_start()

# After a match played together: back into the career on both phones, the room stays open.
func _co_back(tell: bool) -> void:
	var host: bool = net.role == "host"
	_to_menu(true)
	co_rdy = [false, false]
	if host:
		if tell:
			net.send({"_": "cob"})
		cv_t = 0.0
		hub_tab = "career"
		_show_hub()
	elif carv.has_save():
		_as_open()
	else:
		hud.show_menu("lobby", _menu_info())


# ---------------------------------------------------------------- the career's own calendar, simulated matches and the days between
# A career match uses the career's own level and length (Office > Match settings).
func _car_opts() -> void:
	if in_career and (car == carc or car == proc):
		opt_diff = int(car.d.get("diff", 1))
		opt_len = int(car.d.get("len", 1))

# Simulate your next match instead of playing it: the score comes from the two squads' strength.
# a career day that is not match day yet: PLAY and SIMULATE wait, the days have to go by first
func _not_match_day() -> bool:
	if not in_career or (car != carc and car != proc) or assist or net.role == "guest":
		return false
	if bool(car.d.get("cupmode", false)):
		return false
	var nd: int = car.next_day()
	return nd >= 0 and car.now() < nd

func _sim_mine() -> void:
	if in_career and car == carc and not assist and net.role != "guest" and not car.cup_due() and not car.eu_due() and car.nat_due():
		# the country plays (even when the club has let you go)
		_sim_nat()
		return
	if not in_career or (car != carc and car != proc) or assist or net.role == "guest" or car.d.has("sacked"):
		return
	var cupt: bool = car.cup_due()
	var eut: bool = not cupt and car.eu_due()
	if not cupt and not eut and car.season_over():
		return
	# the days up to the match go by first (fitness back, the world moves on)
	car.go_match()
	var opp: int = car.cup_opp() if cupt else (int(car.eu_opp()[0]) if eut else int(car.next_match()[0]))
	var home: bool = true if cupt else (bool(car.eu_opp()[1]) if eut else bool(car.next_match()[1]))
	if opp < 0:
		return
	if car.pro() and car.pro2():
		# together: the manager picks you both like anyone else (never the bench for long)
		car.pro_select("pro")
		car.pro_select("pro2")
	var r: Array = car.sim_match(opp, home)
	# the player career: did you play, and how well? (together: both of you, each his own man)
	var pro_l: Array = []
	var pro_l2: Array = []
	if car.pro():
		for k9 in (["pro", "pro2"] if car.pro2() else ["pro"]):
			var me9: int = car.pro_i(k9)
			var st9: bool = car.pro_starts(k9)
			var on9: bool = st9 or randf() < 0.25 + int(car.pro_d(k9).get("trust", 50)) * 0.004
			var g9 := 0
			for x9 in r[2]:
				if int(x9) == me9:
					g9 += 1
			if not st9:
				# a man on the bench can only score if he comes on, and then only now and then
				var r2: Array = []
				for x9 in r[2]:
					if int(x9) != me9:
						r2.append(x9)
				r[2] = r2
				g9 = 0
				if on9 and randf() < 0.12:
					g9 = 1
			var res9: float = 0.4 if int(r[0]) > int(r[1]) else (-0.4 if int(r[0]) < int(r[1]) else 0.0)
			var rt9: float = 6.1 + (Career.ovr_of(car.pro_pl(k9)) - car.my_strength()) * 0.05 + randf_range(-0.6, 0.8) + res9 + g9 * 1.0 - (0.3 if not st9 else 0.0)
			var ls9: Array = car.pro_after(rt9, g9, 1 if randf() < 0.12 and on9 else 0, on9, st9, k9)
			if k9 == "pro":
				pro_l = ls9
			else:
				pro_l2 = ls9
	var keep := [score.duplicate(), so_win]
	score = [int(r[0]), int(r[1])]
	so_win = -1
	var pens := ""
	if (cupt or (eut and car.eu_ko())) and score[0] == score[1]:
		var df: float = (car.my_strength() - car.rating(opp)) / 40.0
		so_win = 0 if randf() < clampf(0.5 + df, 0.2, 0.8) else 1
		pens = "Won on penalties" if so_win == 0 else "Lost on penalties"
	var date: String = car.date_text(car.next_day(), true)
	var what: String = (car.cup_name().capitalize() + ", " + car.cup_round_name().capitalize()) if cupt else ((car.eu_name().capitalize() + ", " + car.eu_round_name().capitalize()) if eut else (car.league_name().capitalize() + ", round %d" % (int(car.d["round"]) + 1)))
	if cupt:
		car_lines = car.cup_finish(score[0], score[1], so_win == 0)
		_car_coins(false)
	elif eut:
		car_lines = car.eu_finish(score[0], score[1], so_win == 0)
		_car_coins(false)
	else:
		car_lines = car.finish_match(score[0], score[1], r[2], [])
		car_lines.append("%s IN THE TABLE" % Career.ordinal(car.rank_of(int(car.d["club"]))))
		_car_coins(true)
	if car.pro():
		car_lines = pro_l + _pro_lines(car_lines)
		car.pro_select("pro")
		if car.pro2():
			car.pro_select("pro2")
		car.save()
	adv_from = car.today()
	var me_c := int(car.d["club"])
	var a := me_c if home else opp
	var b := opp if home else me_c
	sim_res = {"a": CLUBS[a]["n"], "b": CLUBS[b]["n"], "ka": CLUBS[a]["k"], "kb": CLUBS[b]["k"], "home": home, "goals": r[3], "mine": score[0], "theirs": score[1],
		"pens": pens, "date": date, "what": what, "lines": car_lines.duplicate(), "lines2": (pro_l2 + _pro_lines(car_lines.slice(pro_l.size()))) if car.pro() and car.pro2() else []}
	score = keep[0]
	so_win = int(keep[1])
	if net.role == "host" and net.connected:
		# playing together: the friend sees the same result, and the career catches up on his phone
		net.send({"_": "simr", "d": sim_res, "co": [car.last_coins, int(sim_res.get("mine", 0)) > int(sim_res.get("theirs", 0))]})
		cv_last = 0
	hud.show_menu("simres", _menu_info())

# Your national team's match, simulated: the same result page as a club match.
func _sim_nat() -> void:
	car.go_match()
	var o: Array = car.nat_opp()
	var me_n := int(car.nat()["n"])
	var opp := int(o[0])
	if opp < 0:
		return
	var r: Array = car.nat_sim()
	var keep := [score.duplicate(), so_win]
	score = [int(r[0]), int(r[1])]
	so_win = -1
	var pens := ""
	if car.nat_ko() and score[0] == score[1]:
		so_win = 0 if randf() < clampf(0.5 + (car.nat_str(me_n) - car.nat_str(opp)) / 40.0, 0.2, 0.8) else 1
		pens = "Won on penalties" if so_win == 0 else "Lost on penalties"
	var date: String = car.date_text(car.next_day(), true)
	var what: String = "%s, %s" % [(str(car.nat_t().get("name", "")) if not car.nat_t().is_empty() else "Qualifiers").capitalize(), str(o[2]).capitalize()]
	var xi: Array = car.nat_xi()
	var shooters := []
	for pl in xi:
		for k in {"FW": 5, "MF": 2, "DF": 1}.get(str(pl["pos"]), 0):
			shooters.append(str(pl["n"]))
	var goals := []
	for g in score[0]:
		goals.append([randi_range(2, 90), 0, shooters[randi() % shooters.size()] if not shooters.is_empty() else ""])
	for g in score[1]:
		goals.append([randi_range(2, 90), 1, ""])
	goals.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	car_lines = car.nat_finish(score[0], score[1], so_win == 0)
	var home := bool(o[1])
	var ta := me_n if home else opp
	var tb := opp if home else me_n
	sim_res = {"a": Career.nat_name(ta), "b": Career.nat_name(tb), "ka": Career.nat_kit(ta), "kb": Career.nat_kit(tb), "home": home, "goals": goals, "mine": score[0], "theirs": score[1],
		"pens": pens, "date": date, "what": what, "lines": car_lines.duplicate(), "lines2": []}
	score = keep[0]
	so_win = int(keep[1])
	adv_from = car.today()
	if net.role == "host" and net.connected:
		net.send({"_": "simr", "d": sim_res, "co": [0, int(sim_res.get("mine", 0)) > int(sim_res.get("theirs", 0))]})
		cv_last = 0
	hud.show_menu("simres", _menu_info())

func _nat_setup() -> void:
	career_on = false
	eu_on = false
	nat_on = true
	cup_on = car.nat_ko()
	var o: Array = car.nat_opp()
	tov = [car.nat_team(int(car.nat()["n"])), car.nat_team(int(o[0]))]
	ft_on = true
	_apply_own()
	_set_clubs(RKI, RKI + 1, true)

# the next national match for the home card
func _natm_info() -> Dictionary:
	if not car.has_save() or not car.nat_job():
		return {}
	var nj: Dictionary = car.nat()
	var me_n := int(nj["n"])
	var out := {"me": Career.nat_name(me_n), "kit": Career.nat_kit(me_n), "ok": int(nj.get("ok", 50))}
	if car.nat_due():
		var o: Array = car.nat_opp()
		out["opp"] = Career.nat_name(int(o[0])) if int(o[0]) >= 0 else ""
		out["opp_kit"] = Career.nat_kit(int(o[0])) if int(o[0]) >= 0 else ["888888"]
		if _cdist(Color(str(out["kit"][0])), Color(str(out["opp_kit"][0]))) < 0.5:
			# the same colours: the away side wears its second kit, as in the match
			var ak := "1c1c20" if Color(str(out["opp_kit"][0])).get_luminance() > 0.6 else "f4f4f4"
			out["opp_kit"] = [ak, str(out["opp_kit"][0]), ak]
		out["home"] = bool(o[1])
		out["rname"] = str(o[2])
		out["tname"] = str(car.nat_t().get("name", "QUALIFIERS")) if not car.nat_t().is_empty() else "QUALIFIERS"
		out["sub"] = ["Your %d men" % (nj.get("sq", []) as Array).size(), "Rated %d" % int(round(car.nat_str(int(o[0]))))]
	return out

# the national team page: the squad you called up, the men you could call up, the group and the job
func _nat_info() -> Dictionary:
	if not car.has_save() or not car.d.has("leagues") or car.pro():
		return {}
	if not car.nat_job():
		return {"job": false, "off": int(car.d.get("natoff", 0)) == int(car.d.get("season", 1)), "cap": car._nat_cap()}
	var nj: Dictionary = car.nat()
	var me_n := int(nj["n"])
	var sq: Array = car.nat_squad()
	var xi: Array = car.nat_xi(sq)
	var keys := []
	for pl in sq:
		keys.append(str(pl["key"]))
	var row := func(pl: Dictionary) -> Dictionary:
		return {"key": str(pl["key"]), "n": str(pl["n"]).capitalize(), "pos": str(pl["pos"]), "ovr": Career.ovr_of(pl), "age": int(pl.get("age", 25)), "mine": pl.has("mine"),
			"xi": xi.has(pl), "in": keys.has(str(pl["key"])), "inj": car.injured(pl), "num": int(pl.get("num", 0))}
	var rows := []
	for pl in sq:
		rows.append(row.call(pl))
	var others := []
	var pool: Array = car.nat_pool(me_n)
	pool.sort_custom(func(a, b): return Career.ovr_of(a) > Career.ovr_of(b))
	for pl in pool:
		if not keys.has(str(pl["key"])):
			others.append(row.call(pl))
	var grp := []
	var gname := ""
	var t: Dictionary = car.nat_t()
	var tab: Dictionary = {}
	var members := []
	if not t.is_empty():
		tab = t["tab"]
		members = t["grp"][int(t["gi"])]
		gname = "%s, group %s" % [str(t["name"]).capitalize(), "ABCD"[int(t["gi"])]]
	elif not car.nat_q().is_empty():
		tab = car.nat_q()["tab"]
		members = car.nat_q()["grp"]
		gname = "Qualifying group"
	for n in Career._nat_order(tab, members) if not members.is_empty() else []:
		var r: Dictionary = tab[str(n)]
		grp.append({"n": Career.nat_name(int(n)).capitalize(), "k": Career.nat_kit(int(n)), "p": int(r["p"]), "w": int(r["w"]), "d": int(r["d"]), "l": int(r["l"]), "gd": int(r["gf"]) - int(r["ga"]), "pts": int(r["pts"]), "me": int(n) == me_n})
	var res := []
	for e in car._nat_cal():
		res.append({"date": car.date_text(int(e["day"])), "opp": Career.nat_name(int(e["opp"])).capitalize() if int(e["opp"]) >= 0 else "?", "name": str(e["name"]), "res": e["res"], "home": bool(e["home"]), "played": bool(e["played"])})
	var ko := []
	if not t.is_empty() and int(t["md"]) >= 3 and not bool(t.get("out", false)):
		for m in t.get("ko", []):
			ko.append("%s v %s" % [Career.nat_name(int(m[0])).capitalize(), Career.nat_name(int(m[1])).capitalize()])
	return {"job": true, "n": Career.nat_name(me_n), "kit": Career.nat_kit(me_n), "ok": int(nj.get("ok", 50)), "st": nj.get("st", {}), "hist": nj.get("hist", []), "since": int(nj.get("since", 1)),
		"sq": rows, "pool": others.slice(0, 30), "nsq": rows.size(), "nmine": rows.filter(func(x): return bool(x["mine"])).size(), "rating": int(round(car.nat_str(me_n))),
		"grp": grp, "gname": gname, "fix": res, "ko": ko, "tab": nat_tab, "tname": car.tour_name(), "due": car.nat_due()}

# The days between two matches go by on a calendar page, with the news of those days.
func _adv_show(from: int, to := -99) -> void:
	var step := to != -99
	if to == -99:
		to = car.next_day()
	var me_c := int(car.d["club"])
	var news := []
	# results around you in the league
	var ord: Array = car.order()
	var my_r: int = car.rank_of(me_c)
	var near := []
	for r in car.d.get("last", []):
		var aa := int(r[0])
		var bb := int(r[1])
		if aa == me_c or bb == me_c:
			continue
		var ra: int = car.rank_of(aa)
		var rb: int = car.rank_of(bb)
		var close := mini(absi(ra - my_r), absi(rb - my_r))
		near.append([mini(close, mini(ra, rb) + 1), "%s %d - %d %s" % [str(CLUBS[aa]["n"]).capitalize(), int(r[2]), int(r[3]), str(CLUBS[bb]["n"]).capitalize()]])
	near.sort_custom(func(x, y): return int(x[0]) < int(y[0]))
	for k in mini(0 if step else 2, near.size()):
		news.append(["result", str(near[k][1])])
	if (not car.season_over() or car.cup_due()) and not step:
		var lead: int = int(ord[0])
		var pts_me: int = int(car.d["table"][str(me_c)]["pts"])
		if lead == me_c:
			var sec: int = int(ord[1]) if ord.size() > 1 else lead
			news.append(["table", "You are top of %s, %d points clear" % [car.league_name(), pts_me - int(car.d["table"][str(sec)]["pts"])]])
		else:
			news.append(["table", "You are %s, %d points behind %s" % [Career.ordinal(my_r).to_lower(), int(car.d["table"][str(lead)]["pts"]) - pts_me, str(CLUBS[lead]["n"]).capitalize()]])
	var cp: Dictionary = car.cup()
	var lg_log: Array = cp.get("log", [])
	if not lg_log.is_empty():
		var big := ""
		for t in lg_log[lg_log.size() - 1]:
			var ga := int(t[2])
			var gb := int(t[3])
			var wn := int(t[0]) if ga > gb else int(t[1])
			var ls := int(t[1]) if ga > gb else int(t[0])
			if wn != me_c and ls != me_c and car.rating(ls) - car.rating(wn) >= 6:
				big = "Cup shock: %s knock out %s" % [str(CLUBS[wn]["n"]).capitalize(), str(CLUBS[ls]["n"]).capitalize()]
				break
		if big != "" and not step:
			news.append(["cup", big])
	# the world: deals between the clubs in these days, bids for your men, the window
	var nd_deal := 0
	var dl_day := -1
	for wv in car._windows():
		if int(wv[1]) > from and int(wv[1]) <= to:
			dl_day = int(wv[1])
	for m in car.inbox():
		if int(m["day"]) > from and int(m["day"]) <= to and str(m["k"]) in ["deadline", "window", "med"]:
			news.append(["med" if str(m["k"]) == "med" else "window", str(m["t"])])
	for x in car.deals():
		if int(x[0]) > from and int(x[0]) <= to and nd_deal < 2:
			news.append(["deal", ("Deadline day: " if int(x[0]) == dl_day else "") + car.deal_text(x)])
			nd_deal += 1
	for m in car.inbox():
		if int(m["day"]) > from and int(m["day"]) <= to and str(m["k"]) in ["bid", "press", "talk", "pjob", "info", "award"]:
			news.append(["bid", str(m["t"])])
	var mk: Array = car.market()
	if not mk.is_empty() and news.size() < 5 and not step:
		var best: Dictionary = mk[0]
		for pl in mk:
			if Career.ovr_of(pl) > Career.ovr_of(best):
				best = pl
		news.append(["market", "Transfer list: %s (%s, %d) is the best of %d new players" % [str(best["n"]).capitalize(), str(best["pos"]), Career.ovr_of(best), mk.size()]])
	if news.size() < 6 and not step:
		news.append(["board", "The board: %s (%d)" % [str(Career.mood_of(car.conf())).capitalize(), car.conf()]])
	if step:
		var nxt_t := "the match"
		if car.cup_due():
			nxt_t = "%s, %s" % [car.cup_name().capitalize(), car.cup_round_name().capitalize()]
		elif car.eu_due():
			nxt_t = car.eu_name().capitalize()
		elif car.nat_due():
			nxt_t = "%s v %s" % [Career.nat_name(int(car.nat()["n"])).capitalize(), Career.nat_name(int(car.nat_opp()[0])).capitalize()]
		elif not car.season_over():
			nxt_t = "League v %s" % str(CLUBS[int(car.next_match()[0])]["n"]).capitalize()
		# a day at a time: what happened, and how the squad feels after training
		var hurt := 0
		var tired := 0
		for pl in car.d["squad"]:
			if car.injured(pl):
				hurt += 1
			elif car.cond_of(pl) < 80:
				tired += 1
		if to >= car.next_day():
			news.push_front(["table", "Today: " + nxt_t])
		elif news.is_empty():
			news.append(["board", "A quiet day at the training ground"])
		news.append(["med", "Training: %d still tired, %d injured" % [tired, hurt] if tired + hurt > 0 else "Training: the whole squad is fit"])
	news = news.slice(0, 6)
	var nxt := ""
	if car.cup_due():
		var co: int = car.cup_opp()
		nxt = "%s, %s v %s" % [car.cup_name().capitalize(), car.cup_round_name().capitalize(), str(CLUBS[co]["n"]).capitalize() if co >= 0 else "?"]
	elif car.eu_due():
		var eo2: Array = car.eu_opp()
		nxt = "%s v %s, %s" % [car.eu_name().capitalize(), str(CLUBS[int(eo2[0])]["n"]).capitalize() if int(eo2[0]) >= 0 else "?", "home" if bool(eo2[1]) else "away"]
	elif car.nat_due():
		var no2: Array = car.nat_opp()
		nxt = "%s v %s, %s" % [Career.nat_name(int(car.nat()["n"])).capitalize(), Career.nat_name(int(no2[0])).capitalize(), str(no2[2]).capitalize()]
	elif not car.season_over():
		var nm: Array = car.next_match()
		nxt = "League v %s, %s" % [str(CLUBS[int(nm[0])]["n"]).capitalize(), "home" if bool(nm[1]) else "away"]
	var days := []
	for dd in range(from + (1 if step and to > from else 0), to + 1):
		var t: Dictionary = car.date_of(dd)
		days.append([int(t["d"]), Career.WDAYS[int(t["wd"])], Career.MONTHS[int(t["m"]) - 1]])
	adv_info = {"days": days, "news": news, "next": nxt, "ndate": car.date_text(car.next_day(), true) if car.next_day() >= 0 else "", "step": step, "mday": step and to >= car.next_day()}
	hud.show_menu("adv", _menu_info())


# ---------------------------------------------------------------- the referee
func _ref_make() -> void:
	if ref != null:
		return
	ref = PlayerS.new()
	ref.role = "MF"
	ref.num = 0
	ref.build(Color(0.08, 0.08, 0.09), Color(0.06, 0.06, 0.06), Color(0.06, 0.06, 0.06), Color(0.85, 0.66, 0.5), Color(0.15, 0.1, 0.08), Color(0.05, 0.05, 0.05))
	add_child(ref)
	ref.position = Vector3(0, 0, -12)
	# seen from above: a black disc with a yellow rim and no number, so he never looks like a player
	if ref.dot != null:
		var rim: MeshInstance3D = ref.dot.get_child(0)
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.albedo_color = Color(1.0, 0.86, 0.15)
		rim.material_override = rm
		ref.dot_num.text = ""
		ref.dot.scale = Vector3.ONE * 0.8

# he keeps up with play from a diagonal, about 12 m away, and looks at the ball
func _ref_tick(dt: float) -> void:
	_ref_make()
	ref.visible = screen == "match" and state != "intro"
	if net.role == "guest":
		ref.position += ref.vel * dt
		return
	if book_t >= 0.0:
		return
	var f := ball.position
	var want := Vector3(f.x - signf(f.x + 0.01) * 6.0, 0, f.z + (-9.0 if f.z > 0.0 else 9.0))
	want.x = clampf(want.x, -HL + 4.0, HL - 4.0)
	want.z = clampf(want.z, -HW + 3.0, HW - 3.0)
	var to: Vector3 = want - ref.position
	to.y = 0.0
	var sp := clampf(to.length() * 0.9, 0.0, 6.8)
	var vw: Vector3 = to.normalized() * sp if to.length() > 0.3 else Vector3.ZERO
	ref.vel = ref.vel.move_toward(vw, 14.0 * dt)
	ref.position += ref.vel * dt
	var lk: Vector3 = f - ref.position
	lk.y = 0.0
	if lk.length() > 0.5:
		ref.yaw = lerp_angle(ref.yaw, atan2(-lk.x, -lk.z), clampf(dt * 6.0, 0.0, 1.0))

# At a stop in play the referee goes to the man, the card goes up, the game waits for it.
func _booking(dt: float) -> void:
	if ref_card.is_empty() and book_t < 0.0:
		return
	_ref_make()
	if book_t < 0.0:
		var rc: Array = ref_card[0]
		book_p = rc[0]
		if book_p == null or not is_instance_valid(book_p) or book_p.off:
			ref_card.pop_front()
			return
		book_t = 0.0
		ref.card_up = 0
		if OS.get_cmdline_user_args().has("--force=book"):
			print("BOOK start at real_t=", real_t)
		# from far away he comes closer at once, then jogs in for the last bit
		var away: Vector3 = ref.position - book_p.position
		away.y = 0.0
		if away.length() > 12.0:
			ref.position = book_p.position + away.normalized() * 9.0
		dead_info["wait"] = maxf(float(dead_info.get("wait", 0.9)), state_t + 3.4)
	book_t += dt
	var p = book_p
	if p == null or not is_instance_valid(p):
		book_t = -1.0
		ref_card.pop_front()
		return
	var spot: Vector3 = p.position + (ref.position - p.position).normalized() * 1.7
	spot.y = 0.0
	var to: Vector3 = spot - ref.position
	to.y = 0.0
	if to.length() > 0.2 and book_t < 1.2:
		ref.vel = ref.vel.move_toward(to.normalized() * minf(6.5, to.length() * 3.0), 18.0 * dt)
	else:
		ref.vel = ref.vel.move_toward(Vector3.ZERO, 18.0 * dt)
	ref.position += ref.vel * dt
	var lk: Vector3 = p.position - ref.position
	lk.y = 0.0
	if lk.length() > 0.1:
		ref.yaw = lerp_angle(ref.yaw, atan2(-lk.x, -lk.z), clampf(dt * 8.0, 0.0, 1.0))
		p.face(-lk, 6.0, dt)
	p.vel = p.vel.move_toward(Vector3.ZERO, 10.0 * dt)
	if book_t >= 1.2 and ref.card_up == 0:
		p.yellow += 1
		var red: bool = p.yellow >= 2
		ref.card_up = 2 if red else 1
		if red:
			p.off = true
		if not _quiet():
			var who := "%d  %s" % [p.num, p.pname.to_upper()]
			_banner("RED CARD" if red else "YELLOW CARD", Color(0.95, 0.2, 0.2) if red else Color(1.0, 0.9, 0.2), 1.5, who, 56)
			fx("say", "A second yellow, and he is off!" if red else "The referee books him.")
			snd("jeer", 1.0 if red else 0.75)
			if red:
				snd("gasp")
			fx("vib", 60)
	if book_t >= 2.9:
		ref.card_up = 0
		book_t = -1.0
		book_p = null
		ref_card.pop_front()
		if not ref_card.is_empty():
			dead_info["wait"] = maxf(float(dead_info.get("wait", 0.9)), state_t + 0.2)
