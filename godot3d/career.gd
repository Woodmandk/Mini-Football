extends RefCounted
# Career: your club in the world of ClubDB (England's four leagues, Denmark's two). Holds the save, the leagues,
# the fixtures, the table, your squad and the other clubs' squads.
const ClubDB := preload("res://clubdb.gd")
const FIRST := 8 # world indices below this are the quick-match clubs

var key := "bb3d-career" # localStorage key (native: user://<key>.json); the cup mode keeps its own
const ROLE_BASE := {"GK": [52, 30, 62, 74], "DF": [68, 46, 64, 76], "MF": [70, 66, 77, 64], "FW": [79, 77, 66, 42]}
const SQUAD_ROLES := ["GK", "DF", "DF", "DF", "DF", "MF", "MF", "MF", "FW", "FW", "FW", "GK", "DF", "MF", "MF", "FW"]
const SQUAD_NUMS := [1, 3, 4, 5, 2, 8, 6, 10, 11, 9, 7, 12, 14, 15, 16, 17]
const STAT_NAMES := ["PACE", "SHOOTING", "PASSING", "DEFENDING"]
const STAT_KEYS := ["pac", "sho", "pas", "dfn"]

var d := {}
var web := false
var ro := false # a copy only to look at (the host's career on the friend's phone): never saved
var eur := false # the career mode counts its own money in euros, not the game's coins

# One unit of club money: coins outside the career, 10 000 euros inside it.
const EUR_PER := 10000

static func eur_text(n: int) -> String:
	var v := float(n) * EUR_PER
	var neg := v < 0.0
	v = absf(v)
	var t := ""
	if v >= 1000000.0:
		t = ("€%.1fM" % (v / 1000000.0)).replace(".0M", "M")
	elif v >= 1000.0:
		t = "€%dK" % int(round(v / 1000.0))
	else:
		t = "€%d" % int(v)
	return ("-" if neg else "") + t

# money as the player reads it: "120 COINS" or "€1.2M"
func money(n: int) -> String:
	return eur_text(n) if eur else "%d COINS" % n

func money_word() -> String:
	return "money" if eur else "coins"

var last_coins := 0
var names := []
var W: Array = ClubDB.clubs([{}, {}, {}, {}, {}, {}, {}, {}]) # every club in the world, by index

func has_save() -> bool:
	return not d.is_empty()

func load_save(is_web: bool) -> void:
	web = is_web
	var txt := ""
	if web:
		txt = str(JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % key, true))
	elif FileAccess.file_exists(_file()):
		txt = FileAccess.get_file_as_string(_file())
	if txt != "":
		var v = JSON.parse_string(txt)
		if v is Dictionary and v.has("squad") and v.has("fix"):
			d = v
			# JSON turns whole numbers into floats: put the ones used as indices back
			d["club"] = int(d["club"])
			d["round"] = int(d["round"])
			d["season"] = int(d["season"])
			d["coins"] = int(d["coins"])
			var xi := []
			for x in d["xi"]:
				xi.append(int(x))
			d["xi"] = xi
			if not d.has("abv"):
				_ab_start()
				save()
			if not d.has("leagues"):
				_migrate()
				save()
			if not d.has("on"):
				# a save from before the career was a choice: it is a running career
				d["on"] = true

# JSON turns whole numbers into floats: put the ones used as indices back
func _ints() -> void:
	var xi := []
	for x in d["xi"]:
		xi.append(int(x))
	d["xi"] = xi
	d["coins"] = int(d["coins"])

func _file() -> String:
	return "user://career.json" if key == "bb3d-career" else "user://%s.json" % key

# ---- your club with or without a career
# The club is always yours; a career (a league season with the board) is something you start.
func on() -> bool:
	return bool(d.get("on", true))

# your own club (made by you), not a club you took over
func is_mine() -> bool:
	return d.has("own")

# what your own club brings into a career: the players and the look, not its coins or buildings
const CLUB_KEYS := ["squad", "xi", "form", "lay", "own", "abv"]

# The first start: your own club, not in a career yet. It waits in the place of England's weakest club.
func new_club() -> void:
	new_career(weakest(3), true)
	d["on"] = false
	d["mode"] = "simple"
	save()

# A career with your own club: it keeps its squad, coins and buildings and starts in the league you picked.
func start_mine(li: int, slen: String, base: Dictionary) -> void:
	var keep := {}
	for k in CLUB_KEYS:
		if base.has(k):
			keep[k] = base[k].duplicate(true) if (base[k] is Array or base[k] is Dictionary) else base[k]
	new_career(weakest(li), true, slen)
	for k in keep:
		d[k] = keep[k]
	_ints()
	d["on"] = true
	d.erase("mode")
	d.erase("board")
	board()
	market_refresh()
	save()

# While you run a club you took over, your own club waits here.
const STASH := "bb3d-myclub"

func stash_put(dd: Dictionary = {}) -> void:
	var txt := JSON.stringify(d if dd.is_empty() else dd)
	if web:
		JavaScriptBridge.eval("try{localStorage.setItem('%s',%s)}catch(e){}" % [STASH, JSON.stringify(txt)], true)
	else:
		var f := FileAccess.open("user://myclub.json", FileAccess.WRITE)
		if f != null:
			f.store_string(txt)

func stash_get() -> Dictionary:
	var txt := ""
	if web:
		txt = str(JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % STASH, true))
	elif FileAccess.file_exists("user://myclub.json"):
		txt = FileAccess.get_file_as_string("user://myclub.json")
	if txt == "" or txt == "null":
		return {}
	var v = JSON.parse_string(txt)
	return v if (v is Dictionary and v.has("squad")) else {}

func stash_clear() -> void:
	if web:
		JavaScriptBridge.eval("try{localStorage.removeItem('%s')}catch(e){}" % STASH, true)
	elif FileAccess.file_exists("user://myclub.json"):
		DirAccess.remove_absolute("user://myclub.json")

# your own club: the running one if it is yours, else the one waiting
func my_club() -> Dictionary:
	if is_mine():
		return d
	return stash_get()

func save() -> void:
	if ro:
		return
	var txt := JSON.stringify(d)
	if web:
		JavaScriptBridge.eval("try{localStorage.setItem('%s',%s)}catch(e){}" % [key, JSON.stringify(txt)], true)
	else:
		var f := FileAccess.open(_file(), FileAccess.WRITE)
		if f != null:
			f.store_string(txt)

func wipe() -> void:
	if ro:
		d = {}
		return
	d = {}
	if web:
		JavaScriptBridge.eval("try{localStorage.removeItem('%s')}catch(e){}" % key, true)
	elif FileAccess.file_exists(_file()):
		DirAccess.remove_absolute(_file())

static func ovr_of(p: Dictionary) -> int:
	match str(p["pos"]):
		"GK": return int(round(p["dfn"] * 0.8 + p["pas"] * 0.2))
		"DF": return int(round(p["dfn"] * 0.55 + p["pac"] * 0.25 + p["pas"] * 0.2))
		"MF": return int(round(p["pas"] * 0.45 + p["pac"] * 0.2 + p["sho"] * 0.2 + p["dfn"] * 0.15))
	return int(round(p["sho"] * 0.5 + p["pac"] * 0.35 + p["pas"] * 0.15))

func form() -> String:
	return str(d.get("form", "4-3-3"))

# New formation: pick the best eleven for the new places, best player first for each role.
func set_form(name: String, roles: Array) -> void:
	d["form"] = name
	# a new formation starts from its own spots again
	d.erase("lay")
	var used := []
	var xi := []
	xi.resize(roles.size())
	for pass_n in 2:
		for s in roles.size():
			if xi[s] != null:
				continue
			var best := -1
			for i in (d["squad"] as Array).size():
				if used.has(i):
					continue
				if pass_n == 0 and str(d["squad"][i]["pos"]) != str(roles[s]):
					continue
				if pass_n == 1 and str(d["squad"][i]["pos"]) == "GK":
					continue
				if best < 0 or ovr_of(d["squad"][i]) > ovr_of(d["squad"][best]):
					best = i
			if best >= 0:
				xi[s] = best
				used.append(best)
	for s in roles.size():
		if xi[s] == null:
			for i in (d["squad"] as Array).size():
				if not used.has(i):
					xi[s] = i
					used.append(i)
					break
	d["xi"] = xi
	save()

# Your own spots on the pitch: slot -> [along 0..1, across -1..1]. Empty = the formation as drawn.
func lay() -> Dictionary:
	var l = d.get("lay", {})
	return l if l is Dictionary else {}

func set_spot(slot: int, along: float, across: float) -> void:
	if slot <= 0 or slot > 10:
		return
	var l := lay()
	l[str(slot)] = [snappedf(clampf(along, 0.08, 0.80), 0.005), snappedf(clampf(across, -0.92, 0.92), 0.005)]
	d["lay"] = l
	save()

func clear_lay() -> void:
	d.erase("lay")
	save()

# Where a moved man plays decides his role: deep = defender, middle = midfielder, high = forward.
static func role_at(along: float) -> String:
	if along < 0.29:
		return "DF"
	if along < 0.60:
		return "MF"
	return "FW"

# A career match played together on a friend's career: your own club gets the same coins and your starters grow too.
func coop_reward(coins: int, won: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	d["coins"] = int(d["coins"]) + coins
	var lines := ["+%s FOR YOUR CLUB" % money(coins)]
	for i in d["xi"]:
		var pl: Dictionary = d["squad"][int(i)]
		pl["xp"] = int(pl["xp"]) + 22 + (10 if won else 0)
		if eur:
			_grow_auto(pl, rng, lines)
		# a full bar gives a training point: you choose what he learns
		while int(pl["xp"]) >= 100 and ovr_of(pl) + int(pl.get("tp", 0)) < int(pl["pot"]):
			pl["xp"] = int(pl["xp"]) - 100
			pl["tp"] = int(pl.get("tp", 0)) + 1
			lines.append("%s  +1 TP" % str(pl["n"]).to_upper())
		if int(pl["xp"]) > 100:
			pl["xp"] = 100
	save()
	return lines

# A new career at club c (a world index). own = you made your own club: it takes c's place in c's league.
func new_career(c: int, own := false, slen := "full") -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if c < FIRST or c >= W.size():
		c = weakest(3)
	var r := rating(c)
	# your own club starts a little under the league and grows; a club you take over is as good as it is
	var q := r - 71 - (2 if own else 0)
	var squad := _make_squad(q, q - 5, rng)
	var lgs := ClubDB.start_leagues(FIRST)
	d = {"club": c, "season": 1, "round": 0, "coins": start_coins(int(W[c]["lg"])), "squad": squad, "xi": range(11), "last": [], "note": "",
		"leagues": lgs, "lg": int(W[c]["lg"]), "slen": slen, "cx": {}}
	_ab_start()
	_new_season()
	cup_new()
	board()
	market_refresh()
	save()

func _new_season() -> void:
	var ids0: Array = ids()
	var n: int = ids0.size()
	# round robin by the circle method, then the same again with home and away swapped (a FULL season)
	var ids := ids0.duplicate()
	ids.shuffle()
	var rounds := []
	for r in n - 1:
		var rd := []
		for i in n / 2:
			var a: int = ids[i]
			var b: int = ids[n - 1 - i]
			# home and away take turns (the circle method's own pattern: at most one break in a row)
			rd.append([a, b] if ((i % 2 == 0) if i > 0 else (r % 2 == 0)) else [b, a])
		rounds.append(rd)
		ids.insert(1, ids.pop_back())
	var back := []
	for rd in rounds:
		var rd2 := []
		for m in rd:
			rd2.append([m[1], m[0]])
		back.append(rd2)
	d["fix"] = rounds + ([] if str(d.get("slen", "full")) == "short" else back)
	var table := {}
	for c in ids0:
		table[str(c)] = {"p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0}
	d["table"] = table
	d["round"] = 0
	d["last"] = []
	d["myres"] = {}
	d["day"] = -4 # pre-season: a few days before the first match

func rounds_total() -> int:
	return (d["fix"] as Array).size()

func season_over() -> bool:
	return int(d["round"]) >= rounds_total()

# The other club in your next match, and whether you are at home.
func next_match() -> Array:
	if season_over():
		return [-1, true]
	for m in d["fix"][int(d["round"])]:
		if int(m[0]) == int(d["club"]):
			return [int(m[1]), true]
		if int(m[1]) == int(d["club"]):
			return [int(m[0]), false]
	return [-1, true]

# How strong a computer club is: a fixed spread, rising a little each season.
# How strong a computer club is, against the 71 the player numbers are built around.
func club_level(c: int) -> int:
	return rating(c) - 71

func rating(c: int) -> int:
	if c < FIRST or c >= W.size():
		return 71
	return int(W[c]["r"]) + int((d.get("rb", {}) as Dictionary).get(str(c), 0))

# ---- the leagues

func lg() -> int:
	return clampi(int(d.get("lg", 3)), 0, ClubDB.LEAGUES.size() - 1)

func league(li := -1) -> Dictionary:
	return ClubDB.LEAGUES[lg() if li < 0 else li]

func league_name(li := -1) -> String:
	return str(league(li)["n"])

# the clubs in a league now (your league when li is left out)
func ids(li := -1) -> Array:
	var out := []
	for x in (d["leagues"] as Array)[lg() if li < 0 else li]:
		out.append(int(x))
	return out

func league_of(c: int) -> int:
	var lgs: Array = d.get("leagues", [])
	for li in lgs.size():
		for x in lgs[li]:
			if int(x) == c:
				return li
	return -1

func weakest(li: int) -> int:
	var src: Array = ids(li) if d.has("leagues") else ClubDB.start_leagues(FIRST)[li]
	var best := -1
	for c in src:
		if best < 0 or int(W[int(c)]["r"]) < int(W[best]["r"]):
			best = int(c)
	return best

static func start_coins(li: int) -> int:
	return [2500, 1000, 450, 200, 700, 250][clampi(li, 0, 5)]

# how much a league's matches pay, against the bottom league
static func pay_k(li: int) -> float:
	return [3.0, 2.0, 1.4, 1.0, 1.8, 1.1][clampi(li, 0, 5)]

# The career is a ladder of four divisions: you start in Division 4. The top two go up, the bottom two go down.
# the level inside the country: 1 = the top league
func div() -> int:
	return int(league()["t"])

func my_strength() -> float:
	var s := 0.0
	for i in d["xi"]:
		s += ovr_of(d["squad"][int(i)])
	return s / 11.0

func _strength(c: int) -> float:
	if c == int(d["club"]):
		return my_strength()
	return float(rating(c))

static func _poisson(rng: RandomNumberGenerator, lam: float) -> int:
	var l := exp(-lam)
	var k := 0
	var p := 1.0
	while true:
		p *= rng.randf()
		if p <= l:
			return k
		k += 1
	return k

func _book(a: int, b: int, ga: int, gb: int) -> void:
	var ta: Dictionary = d["table"][str(a)]
	var tb: Dictionary = d["table"][str(b)]
	ta["p"] = int(ta["p"]) + 1
	tb["p"] = int(tb["p"]) + 1
	ta["gf"] = int(ta["gf"]) + ga
	ta["ga"] = int(ta["ga"]) + gb
	tb["gf"] = int(tb["gf"]) + gb
	tb["ga"] = int(tb["ga"]) + ga
	if ga > gb:
		ta["w"] = int(ta["w"]) + 1
		tb["l"] = int(tb["l"]) + 1
		ta["pts"] = int(ta["pts"]) + 3
	elif gb > ga:
		tb["w"] = int(tb["w"]) + 1
		ta["l"] = int(ta["l"]) + 1
		tb["pts"] = int(tb["pts"]) + 3
	else:
		ta["d"] = int(ta["d"]) + 1
		tb["d"] = int(tb["d"]) + 1
		ta["pts"] = int(ta["pts"]) + 1
		tb["pts"] = int(tb["pts"]) + 1
	# the last five results, newest last: W, D or L
	ta["fm"] = (str(ta.get("fm", "")) + ("W" if ga > gb else ("L" if ga < gb else "D"))).right(5)
	tb["fm"] = (str(tb.get("fm", "")) + ("W" if gb > ga else ("L" if gb < ga else "D"))).right(5)

# Books your result, plays the rest of the round, pays out coins and grows the players who played.
# Returns lines for the full-time screen.
func finish_match(mine: int, theirs: int, scorers: Array, played: Array = []) -> Array:
	var me: int = int(d["club"])
	var was_home: bool = next_match()[1]
	var opp_c: int = next_match()[0]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var last := []
	for m in d["fix"][int(d["round"])]:
		var a: int = int(m[0])
		var b: int = int(m[1])
		var ga := 0
		var gb := 0
		if a == me:
			ga = mine
			gb = theirs
		elif b == me:
			ga = theirs
			gb = mine
		else:
			var diff := (_strength(a) - _strength(b)) / 14.0
			ga = _poisson(rng, 1.35 * exp(diff) + 0.15)
			gb = _poisson(rng, 1.35 * exp(-diff))
		_book(a, b, ga, gb)
		last.append([a, b, ga, gb])
	d["last"] = last
	if not d.has("myres"):
		d["myres"] = {}
	d["myres"][str(int(d["round"]))] = [mine, theirs]
	d["day"] = lg_day(int(d["round"]))
	d["round"] = int(d["round"]) + 1
	var stt: Dictionary = stats()
	stt["p"] = int(stt["p"]) + 1
	stt["w" if mine > theirs else ("d" if mine == theirs else "l")] = int(stt["w" if mine > theirs else ("d" if mine == theirs else "l")]) + 1
	stt["gf"] = int(stt["gf"]) + mine
	stt["ga"] = int(stt["ga"]) + theirs
	d["st"] = stt
	var lines := []
	var coins := int(round((15 + mine * 5 + (40 if mine > theirs else (15 if mine == theirs else 0))) * pay_k(lg())))
	if eur:
		# a real club does not get rich from one match: the money is in the season (prize, board, sales)
		coins = int(round(coins * 0.3))
	coins += board_bonus(coins)
	d["coins"] = int(d["coins"]) + coins
	last_coins = coins
	market_refresh()
	lines.append("+" + money(coins))
	lines.append(_board_match(mine, theirs, opp_c, was_home, played if not played.is_empty() else d["xi"]))
	if was_home:
		# the gate: a bigger stadium and a club near the top bring more people in
		var gate := int(round((fac("stadium") * 9 + (6 if rank_of(me) <= 3 else 0)) * pay_k(lg())))
		if eur:
			gate = int(round(gate * 0.5))
		d["coins"] = int(d["coins"]) + gate
		lines.append("+%s FROM THE GATE" % money(gate))
	for i in (played if not played.is_empty() else d["xi"]):
		var pl: Dictionary = d["squad"][int(i)]
		pl["apps"] = int(pl["apps"]) + 1
		var xp := int(round((22 + (10 if mine > theirs else 0)) * (1.0 + 0.15 * (fac("training") - 1)) * (train_k(pl) if eur else 1.0)))
		for s in scorers:
			if int(s) == int(i):
				xp += 14
				pl["g"] = int(pl["g"]) + 1
		pl["xp"] = int(pl["xp"]) + xp
		if eur:
			_grow_auto(pl, rng, lines)
		# a full bar gives a training point: you choose what he learns
		while int(pl["xp"]) >= 100 and ovr_of(pl) + int(pl.get("tp", 0)) < int(pl["pot"]):
			pl["xp"] = int(pl["xp"]) - 100
			pl["tp"] = int(pl.get("tp", 0)) + 1
			lines.append("%s  +1 TP" % str(pl["n"]).to_upper())
		if int(pl["xp"]) > 100:
			pl["xp"] = 100
	# the youth academy brings a local talent in twice a season; the scouts report every round
	if int(d["round"]) == rounds_total() / 2 or season_over():
		var yn := youth_local(rng)
		if yn != "":
			lines.append(yn)
	_scout_tick(rng, lines)
	_acad_tick(rng, lines)
	if season_over():
		var pos := rank_of(me)
		var n := ids().size()
		var prize: int = int(round((20.0 + 280.0 * pow(float(n - pos) / float(n - 1), 1.6)) * pay_k(lg())))
		d["coins"] = int(d["coins"]) + prize
		if pos == 1:
			stt["titles"] = int(stt["titles"]) + 1
		var mv := 0
		var what := ""
		var lgd := league()
		if pos <= int(lgd["up"]):
			mv = -1
			what = "  PROMOTED TO %s!" % league_name(lg() - 1)
		elif int(lgd["down"]) > 0 and pos > n - int(lgd["down"]):
			mv = 1
			what = "  RELEGATED TO %s." % league_name(lg() + 1)
		if pos == 1:
			what = ("  CHAMPIONS OF %s!" % league_name()) + what
		d["move"] = mv
		d["note"] = "%s, SEASON %d: YOU FINISHED %s.%s  +%s" % [league_name(), int(d["season"]), ordinal(pos), what, money(prize)]
		_sim_others()
		_board_review()
		lines.append("SEASON OVER: THE BOARD'S GRADE IS %s" % str(review().get("grade", "C")))
	_fac_tick(lines)
	if eur:
		_after_match(played if not played.is_empty() else d["xi"], mine > theirs, lines, rng)
	save()
	return lines

static func ordinal(n: int) -> String:
	# 1ST 2ND 3RD 4TH ... 11TH 12TH 13TH ... 21ST 22ND 23RD
	var k := n % 10
	if (n % 100) / 10 == 1 or k == 0 or k > 3:
		return str(n) + "TH"
	return str(n) + ["", "ST", "ND", "RD"][k]

# The stat that grows: mostly the ones that matter for the player's position.
func _grow_key(pl: Dictionary, rng: RandomNumberGenerator) -> String:
	var w: Array = {"GK": [0, 0, 2, 6], "DF": [2, 0, 2, 5], "MF": [2, 2, 5, 1], "FW": [3, 5, 2, 0]}[str(pl["pos"])]
	var tot := 0
	for x in w:
		tot += int(x)
	var r := rng.randi_range(0, tot - 1)
	for i in 4:
		r -= int(w[i])
		if r < 0:
			return STAT_KEYS[i]
	return "pas"

func next_season() -> void:
	money_init()
	var gone := _contracts_end()
	var mv0 := int(d.get("move", 0))
	d["season"] = int(d["season"]) + 1
	_move_clubs()
	d["lg"] = league_of(int(d["club"]))
	d["move"] = 0
	d["note"] = ""
	for pl in d["squad"]:
		pl["age"] = int(pl["age"]) + 1
		if eur and int(pl["age"]) >= 31:
			# past 30 the legs go first
			_decline(pl)
		pl["g"] = 0
		pl["apps"] = 0
	_age_world()
	_new_season()
	# a new cup every season, and new goals from the board
	cup_new()
	board()
	(d["board"] as Dictionary).erase("review")
	_board_season()
	if eur and d.has("wb"):
		# the board sets the wage budget again: more after going up, less after going down
		if mv0 < 0:
			d["wb"] = int(round(int(d["wb"]) * 1.3))
		elif mv0 > 0:
			d["wb"] = maxi(wages(), int(round(int(d["wb"]) * 0.85)))
	if not gone.is_empty():
		d["note"] = "CONTRACTS RAN OUT: %s LEFT ON A FREE." % ", ".join(PackedStringArray(gone))
	save()

# The end of the season everywhere else: every other league plays its season in a blink.
func _sim_others() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var fin := []
	for li in ClubDB.LEAGUES.size():
		if li == lg():
			fin.append(order())
			continue
		var cl: Array = ids(li)
		var pts := {}
		for c in cl:
			pts[c] = [0, 0, 0]
		for i in cl.size():
			for j in cl.size():
				if i == j:
					continue
				var a: int = cl[i]
				var b: int = cl[j]
				var df := (float(rating(a)) - float(rating(b))) / 14.0
				var ga := _poisson(rng, 1.35 * exp(df) + 0.15)
				var gb := _poisson(rng, 1.35 * exp(-df))
				pts[a][0] += 3 if ga > gb else (1 if ga == gb else 0)
				pts[b][0] += 3 if gb > ga else (1 if ga == gb else 0)
				pts[a][1] += ga - gb
				pts[b][1] += gb - ga
				pts[a][2] += ga
				pts[b][2] += gb
		var ord := cl.duplicate()
		ord.sort_custom(func(x, y): return pts[x] > pts[y] if pts[x] != pts[y] else x < y)
		fin.append(ord)
	d["final"] = fin

# Promotion and relegation in every country, by each league's own rules.
func _move_clubs() -> void:
	var fin: Array = d.get("final", [])
	if fin.size() != ClubDB.LEAGUES.size():
		return
	var lgs := []
	for li in fin.size():
		lgs.append((fin[li] as Array).duplicate())
	for li in ClubDB.LEAGUES.size() - 1:
		var a: Dictionary = ClubDB.LEAGUES[li]
		var b: Dictionary = ClubDB.LEAGUES[li + 1]
		if str(a["c"]) != str(b["c"]):
			continue
		var dn := int(a["down"])
		var up := int(b["up"])
		var down_cl: Array = (fin[li] as Array).slice((fin[li] as Array).size() - dn)
		var up_cl: Array = (fin[li + 1] as Array).slice(0, up)
		for c in down_cl:
			lgs[li].erase(c)
			lgs[li + 1].append(c)
		for c in up_cl:
			lgs[li + 1].erase(c)
			lgs[li].append(c)
	d["leagues"] = lgs
	d.erase("final")

# A year on for the other clubs: their ratings drift a little, so the world does not stand still.
func _age_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rb: Dictionary = d.get("rb", {})
	for c in range(FIRST, W.size()):
		var k := str(c)
		var v := int(rb.get(k, 0)) + rng.randi_range(-1, 1)
		# a club promoted gets a little stronger, one relegated a little weaker, but never far from what it is
		var li := league_of(c)
		if li >= 0 and li != int(W[c]["lg"]):
			v += 1 if li < int(W[c]["lg"]) else -1
		rb[k] = clampi(v, -5, 5)
	d["rb"] = rb

# Clubs in table order (points, goal difference, goals for).
# Clubs in table order (points, goal difference, goals for).
func order() -> Array:
	var ids0 := ids()
	var t: Dictionary = d["table"]
	ids0.sort_custom(func(a, b):
		var ra: Dictionary = t[str(a)]
		var rb2: Dictionary = t[str(b)]
		var ka := [int(ra["pts"]), int(ra["gf"]) - int(ra["ga"]), int(ra["gf"])]
		var kb := [int(rb2["pts"]), int(rb2["gf"]) - int(rb2["ga"]), int(rb2["gf"])]
		return ka > kb if ka != kb else a < b)
	return ids0

func rank_of(c: int) -> int:
	return order().find(c) + 1

func swap(a: int, b: int) -> void:
	# a and b are squad indices; either may be in the eleven
	var xi: Array = d["xi"]
	var ia := xi.find(a)
	var ib := xi.find(b)
	if ia >= 0 and ib >= 0:
		xi[ia] = b
		xi[ib] = a
	elif ia >= 0:
		xi[ia] = b
	elif ib >= 0:
		xi[ib] = a
	save()

# ---- transfer market

const SQUAD_MAX := 19
const SQUAD_MIN := 14

static func value(pl: Dictionary) -> int:
	var o := ovr_of(pl)
	var v := 30.0 + pow(maxf(o - 55.0, 0.0), 2.0) * 0.9 + maxf(int(pl["pot"]) - o, 0.0) * 6.0 - maxf(int(pl["age"]) - 29.0, 0.0) * 15.0
	return maxi(int(round(v / 5.0)) * 5, 20)

static func sell_value(pl: Dictionary) -> int:
	return int(round(value(pl) * 0.7 / 5.0)) * 5

# Six new players for sale, around your own level, a few clearly better.
func market_refresh() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var taken := []
	for pl in d["squad"]:
		taken.append(str(pl["n"]))
	var pool := []
	for n in names:
		if not taken.has(str(n)):
			pool.append(n)
	pool.shuffle()
	var lv := int(round(my_strength()))
	var roles := ["GK", "DF", "DF", "MF", "MF", "FW", "FW"]
	roles.shuffle()
	var out := []
	for i in mini(6, pool.size()):
		var role: String = roles[i]
		var base: Array = ROLE_BASE[role]
		var q: int = lv - 72 + [-3, 0, 2, 4, 6, 9][i] + rng.randi_range(-1, 1)
		var pl := {
			"n": pool[i], "num": 0, "pos": role, "age": rng.randi_range(17, 31), "xp": 0, "g": 0, "apps": 0,
			"pac": clampi(base[0] + q + rng.randi_range(-4, 4), 30, 95), "sho": clampi(base[1] + q + rng.randi_range(-4, 4), 25, 95),
			"pas": clampi(base[2] + q + rng.randi_range(-4, 4), 30, 95), "dfn": clampi(base[3] + q + rng.randi_range(-4, 4), 25, 95),
		}
		pl["pot"] = clampi(ovr_of(pl) + rng.randi_range(2, 14) - maxi(int(pl["age"]) - 23, 0) * 2, ovr_of(pl), 95)
		pl["ab"] = ab_roll(role, ovr_of(pl), rng)
		out.append(pl)
	out.sort_custom(func(a, b): return ovr_of(a) > ovr_of(b))
	d["market"] = out
	save()

const PACK_NAMES := ["BRONZE PACK", "SILVER PACK", "GOLD PACK"]
const PACK_COST := [120, 300, 650]
const PACK_Q := [[-7, 0], [0, 6], [6, 12]]

# What the shop shows: name, price and the rating range you can pull, measured against your own team.
func packs() -> Array:
	var lv := int(round(my_strength()))
	var out := []
	for i in 3:
		out.append({"n": PACK_NAMES[i], "cost": PACK_COST[i], "lo": clampi(lv + PACK_Q[i][0], 45, 92), "hi": clampi(lv + PACK_Q[i][1], 50, 94)})
	return out

# Open a pack: one random player joins the squad.
func open_pack(tier: int) -> Dictionary:
	if tier < 0 or tier > 2:
		return {"err": ""}
	if (d["squad"] as Array).size() >= SQUAD_MAX:
		return {"err": "Your squad is full. Sell a player from the bench first."}
	if int(d["coins"]) < PACK_COST[tier]:
		return {"err": "You need %s more." % money(PACK_COST[tier] - int(d["coins"]))}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var taken := []
	var used := []
	for s in d["squad"]:
		taken.append(str(s["n"]))
		used.append(int(s["num"]))
	var pool := []
	for n in names:
		if not taken.has(str(n)):
			pool.append(n)
	if pool.is_empty():
		return {"err": "No players left to sign."}
	var role: String = ["GK", "DF", "DF", "DF", "MF", "MF", "MF", "FW", "FW", "FW"][rng.randi_range(0, 9)]
	var base: Array = ROLE_BASE[role]
	var want := clampi(int(round(my_strength())) + rng.randi_range(PACK_Q[tier][0], PACK_Q[tier][1]), 45, 94)
	var pl := {
		"n": pool[rng.randi_range(0, pool.size() - 1)], "num": 0, "pos": role, "age": rng.randi_range(17, 30), "xp": 0, "g": 0, "apps": 0,
		"pac": clampi(base[0] - 8 + rng.randi_range(-4, 4), 30, 95), "sho": clampi(base[1] - 8 + rng.randi_range(-4, 4), 25, 95),
		"pas": clampi(base[2] - 8 + rng.randi_range(-4, 4), 30, 95), "dfn": clampi(base[3] - 8 + rng.randi_range(-4, 4), 25, 95),
	}
	# lift or lower all four numbers together until the rating is the one the pack rolled
	for step in 60:
		var o := ovr_of(pl)
		if o == want:
			break
		for k in STAT_KEYS:
			pl[k] = clampi(int(pl[k]) + (1 if o < want else -1), 25, 97)
	pl["pot"] = clampi(ovr_of(pl) + rng.randi_range(2, 12) - maxi(int(pl["age"]) - 23, 0) * 2, ovr_of(pl), 96)
	# a gold pack always brings a skill
	pl["ab"] = ab_roll(role, ovr_of(pl) + (8 if tier == 2 else 0), rng)
	for n in range(2, 99):
		if not used.has(n):
			pl["num"] = n
			break
	d["coins"] = int(d["coins"]) - PACK_COST[tier]
	d["squad"].append(pl)
	save()
	return {"pl": pl}

func stats() -> Dictionary:
	if d.has("st"):
		return d["st"]
	# an older save: start from this season's row in the table
	var t: Dictionary = d["table"][str(int(d["club"]))]
	return {"p": int(t["p"]), "w": int(t["w"]), "d": int(t["d"]), "l": int(t["l"]), "gf": int(t["gf"]), "ga": int(t["ga"]), "titles": 0}

func market() -> Array:
	if not d.has("market"):
		market_refresh()
	return d["market"]

func buy(i: int) -> String:
	var m: Array = market()
	if i < 0 or i >= m.size():
		return ""
	var pl: Dictionary = m[i]
	var price := value(pl)
	if (d["squad"] as Array).size() >= SQUAD_MAX:
		return "Your squad is full. Sell a player from the bench first."
	if int(d["coins"]) < price:
		return "You need %s more." % money(price - int(d["coins"]))
	if wages_on():
		# a free agent with a fee for his rights: first he has to agree a contract
		talk_sign(pl, price, -1, i)
		return ""
	return _complete_buy(i, -1, -1)

func _complete_buy(i: int, wk: int, yrs: int) -> String:
	var m: Array = market()
	var pl: Dictionary = m[i]
	var price := value(pl)
	var used := []
	for s in d["squad"]:
		used.append(int(s["num"]))
	for n in range(2, 99):
		if not used.has(n):
			pl["num"] = n
			break
	if wk >= 0:
		pl["wk"] = wk
		pl["ct"] = yrs
	d["coins"] = int(d["coins"]) - price
	d["squad"].append(pl)
	m.remove_at(i)
	save()
	return "%s SIGNED" % str(pl["n"]).to_upper()

func sell(i: int) -> String:
	var sq: Array = d["squad"]
	if i < 0 or i >= sq.size():
		return ""
	for x in d["xi"]:
		if int(x) == i:
			return "Move him to the bench before you sell him."
	if sq.size() <= SQUAD_MIN:
		return "You need at least %d players." % SQUAD_MIN
	var pl: Dictionary = sq[i]
	# a club at his level in your country buys him and he plays for them from now on
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var buyer := _buyer_for(pl, rng)
	var got := int(round(sell_value(pl) * rng.randf_range(1.0, 1.25) / 5.0)) * 5
	d["coins"] = int(d["coins"]) + got
	sq.remove_at(i)
	if buyer >= 0:
		var their: Array = cpu_squad(buyer)
		var wk := -1
		for k in their.size():
			if str(their[k]["pos"]) == str(pl["pos"]) and (wk < 0 or ovr_of(their[k]) < ovr_of(their[wk])):
				wk = k
		pl["tp"] = 0
		pl["xp"] = 0
		if wk >= 0:
			their[wk] = pl
		_set_cpu_squad(buyer, their)
	var xi := []
	for x in d["xi"]:
		xi.append(int(x) - 1 if int(x) > i else int(x))
	d["xi"] = xi
	save()
	return "%s SOLD TO %s FOR %s" % [str(pl["n"]).to_upper(), str(W[buyer]["n"]) if buyer >= 0 else "A CLUB ABROAD", money(got)]

# ---- the club: three things to build

const FAC_KEYS := ["stadium", "training", "youth"]
const FAC_COST := [150, 300, 500, 800]
const FAC_MAX := 5

func fac(k: String) -> int:
	return clampi(int((d.get("fac", {}) as Dictionary).get(k, 1)), 1, FAC_MAX)

func fac_cost(k: String) -> int:
	return FAC_COST[fac(k) - 1] if fac(k) < FAC_MAX else 0

func fac_up(k: String) -> String:
	if fac(k) >= FAC_MAX:
		return ""
	var c := fac_cost(k)
	if int(d["coins"]) < c:
		return "You need %s more." % money(c - int(d["coins"]))
	if not d.has("fac"):
		d["fac"] = {}
	d["coins"] = int(d["coins"]) - c
	d["fac"][k] = fac(k) + 1
	save()
	return "BUILT"

func youth_arrives(rng: RandomNumberGenerator) -> String:
	if (d["squad"] as Array).size() >= SQUAD_MAX:
		return "YOUTH: NO ROOM IN THE SQUAD FOR A NEW TALENT"
	var taken := []
	for pl in d["squad"]:
		taken.append(str(pl["n"]))
	for pl in d.get("market", []):
		taken.append(str(pl["n"]))
	var pool := []
	for n in names:
		if not taken.has(str(n)):
			pool.append(n)
	if pool.is_empty():
		return ""
	var lv := fac("youth")
	var role: String = ["GK", "DF", "DF", "MF", "MF", "FW", "FW"][rng.randi() % 7]
	var base: Array = ROLE_BASE[role]
	var q := -16 + lv * 2
	var pl := {
		"n": pool[rng.randi() % pool.size()], "num": 0, "pos": role, "age": rng.randi_range(16, 18), "xp": 0, "g": 0, "apps": 0,
		"pac": clampi(base[0] + q + rng.randi_range(-4, 4), 30, 95), "sho": clampi(base[1] + q + rng.randi_range(-4, 4), 25, 95),
		"pas": clampi(base[2] + q + rng.randi_range(-4, 4), 30, 95), "dfn": clampi(base[3] + q + rng.randi_range(-4, 4), 25, 95),
	}
	pl["pot"] = clampi(66 + lv * 4 + rng.randi_range(-3, 5), ovr_of(pl) + 4, 95)
	if rng.randf() < 0.2 + lv * 0.06:
		pl["ab"] = ab_roll(role, 70, rng).slice(0, 1)
	var used := []
	for s in d["squad"]:
		used.append(int(s["num"]))
	for n in range(20, 99):
		if not used.has(n):
			pl["num"] = n
			break
	if eur:
		pl["wk"] = 1
		pl["ct"] = 3
	d["squad"].append(pl)
	return "YOUTH: %s (%d, %s) JOINS, CAN REACH %d" % [str(pl["n"]).to_upper(), int(pl["age"]), role, int(pl["pot"])]

func train_cost(pl: Dictionary) -> int:
	return int(round((40 + maxi(ovr_of(pl) - 60, 0) * 6) * (1.0 - 0.07 * (fac("training") - 1))))

# Spend coins on one training session: one training point for this player.
func train(i: int) -> String:
	var pl: Dictionary = d["squad"][i]
	var c := train_cost(pl)
	if int(d["coins"]) < c or ovr_of(pl) + int(pl.get("tp", 0)) >= int(pl["pot"]):
		return ""
	pl["tp"] = int(pl.get("tp", 0)) + 1
	d["coins"] = int(d["coins"]) - c
	save()
	return "%s  +1 TP" % str(pl["n"]).to_upper()

# Use one training point on the stat you pick.
func spend_tp(i: int, si: int) -> String:
	var pl: Dictionary = d["squad"][i]
	if int(pl.get("tp", 0)) <= 0 or si < 0 or si > 3:
		return ""
	var k: String = STAT_KEYS[si]
	if int(pl[k]) >= 97:
		return "He cannot get better at that."
	pl[k] = int(pl[k]) + 1
	pl["tp"] = int(pl["tp"]) - 1
	save()
	return "%s  +1 %s" % [str(pl["n"]).to_upper(), STAT_NAMES[si]]

# ---------------------------------------------------------------- the cup
# Each country's knockout cup with every club in it, one a season, its rounds spread through the league season.
# The strongest clubs wait for the first round to be played (a bye) so the rest is a clean bracket.
const CUP_NAMES := {"ENGLAND": "THE ENGLISH CUP", "DENMARK": "THE DANISH CUP"}

func cup() -> Dictionary:
	if not d.has("cup"):
		cup_new()
	return d["cup"]

func cup_new() -> void:
	var cn := str(league()["c"])
	var all := []
	for li in ClubDB.LEAGUES.size():
		if str(ClubDB.LEAGUES[li]["c"]) == cn:
			all.append_array(ids(li))
	all.sort_custom(func(a, b): return _strength(a) > _strength(b))
	var p := 1
	while p < all.size():
		p *= 2
	var nb := p - all.size()
	var byes: Array = all.slice(0, nb)
	var first: Array = all.slice(nb)
	first.shuffle()
	var rn := 0
	var q := p
	while q > 1:
		q /= 2
		rn += 1
	var nm := []
	for i in rn:
		var left := rn - i
		nm.append(["FINAL", "SEMI-FINAL", "QUARTER-FINAL", "ROUND OF 16", "ROUND OF 32", "ROUND OF 64"][left - 1] if left <= 6 else "FIRST ROUND")
	if nm.size() >= 7:
		nm[0] = "FIRST ROUND"
	d["cup"] = {"r": 0, "teams": first, "byes": byes, "names": nm, "out": false, "won": false, "log": [], "c": cn, "n": int(d.get("cup", {}).get("n", 0)) + 1}
	# your club has a bye: the first round is played without you
	if byes.has(int(d["club"])):
		_cup_round(-1, -1, false)
		d["cup"]["r0"] = 1
	save()

func cup_name() -> String:
	return str(CUP_NAMES.get(str(cup().get("c", league()["c"])), "THE CUP"))

func cup_names() -> Array:
	return cup().get("names", ["QUARTER-FINAL", "SEMI-FINAL", "FINAL"])

func cup_rounds() -> int:
	return cup_names().size()

# Plays one cup round: your tie with your score (mine/theirs, -1 = you are not in it), the others by strength.
func _cup_round(mine: int, theirs: int, won_tie: bool) -> void:
	var cp: Dictionary = cup()
	var me: int = int(d["club"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var t: Array = cp["teams"]
	var next := []
	var res := []
	var won: bool = mine > theirs or (mine == theirs and won_tie)
	for i in range(0, t.size() - 1, 2):
		var a: int = int(t[i])
		var b: int = int(t[i + 1])
		var ga := 0
		var gb := 0
		if mine >= 0 and (a == me or b == me):
			ga = mine if a == me else theirs
			gb = theirs if a == me else mine
			next.append(me if won else (b if a == me else a))
		else:
			var df := (_strength(a) - _strength(b)) / 14.0
			ga = _poisson(rng, 1.35 * exp(df))
			gb = _poisson(rng, 1.35 * exp(-df))
			if ga == gb:
				if rng.randf() < 0.5:
					ga += 1
				else:
					gb += 1
			next.append(a if ga > gb else b)
		res.append([a, b, ga, gb])
	(cp["log"] as Array).append(res)
	if int(cp["r"]) == 0:
		next.append_array(cp.get("byes", []))
		cp["byes"] = []
	next.shuffle()
	cp["teams"] = next
	cp["r"] = int(cp["r"]) + 1

func cup_over() -> bool:
	var cp: Dictionary = cup()
	return bool(cp["out"]) or bool(cp["won"])

# The club you meet in this round, or -1 when your cup is over.
# The club you meet in this round, or -1 when your cup is over.
func cup_opp() -> int:
	var cp: Dictionary = cup()
	if cup_over():
		return -1
	var t: Array = cp["teams"]
	var i: int = -1
	for k in t.size():
		if int(t[k]) == int(d["club"]):
			i = k
	if i < 0 or i + (1 if i % 2 == 0 else -1) >= t.size():
		return -1
	return int(t[i + 1]) if i % 2 == 0 else int(t[i - 1])

func cup_round_name() -> String:
	var nm := cup_names()
	return str(nm[clampi(int(cup()["r"]), 0, nm.size() - 1)])

# Books your cup tie and plays the others. Returns lines for the full-time screen.
# Books your cup tie and plays the others. Returns lines for the full-time screen.
func cup_finish(mine: int, theirs: int, won_tie := false) -> Array:
	var cp: Dictionary = cup()
	var r: int = int(cp["r"])
	var last_r := cup_rounds() - 1
	var lines := []
	# a level tie was settled by the shootout
	var won: bool = mine > theirs or (mine == theirs and won_tie)
	if not bool(d.get("cupmode", false)):
		d["day"] = cup_day(r)
	_cup_round(mine, theirs, won_tie)
	var stt: Dictionary = stats()
	var nm := cup_names()
	var coins := int(round((10 + mine * 5) * pay_k(lg())))
	if eur:
		coins = int(round(coins * 0.3))
	if won:
		coins += int(round([40, 60, 80, 120, 160, 250, 400][clampi(6 - (last_r - r), 0, 6)] * pay_k(lg())))
		if r >= last_r:
			cp["won"] = true
			stt["cups"] = int(stt.get("cups", 0)) + 1
			lines.append("YOU WON %s!" % cup_name())
		else:
			lines.append("THROUGH TO THE %s" % nm[r + 1])
	else:
		cp["out"] = true
		lines.append("OUT OF THE CUP IN THE %s" % nm[clampi(r, 0, last_r)])
	d["st"] = stt
	coins += board_bonus(coins)
	d["coins"] = int(d["coins"]) + coins
	last_coins = coins
	lines.insert(0, "+" + money(coins))
	lines.insert(1, _board_cup(won, r))
	# the men who played learn from a cup tie too
	for i in d["xi"]:
		var pl: Dictionary = d["squad"][int(i)]
		pl["xp"] = int(pl["xp"]) + (30 if won else 20)
		if eur:
			var rng2 := RandomNumberGenerator.new()
			rng2.randomize()
			_grow_auto(pl, rng2, lines)
		while int(pl["xp"]) >= 100 and ovr_of(pl) + int(pl.get("tp", 0)) < int(pl["pot"]):
			pl["xp"] = int(pl["xp"]) - 100
			pl["tp"] = int(pl.get("tp", 0)) + 1
			lines.append("%s  +1 TP" % str(pl["n"]).to_upper())
		if int(pl["xp"]) > 100:
			pl["xp"] = 100
	if eur:
		var rng3 := RandomNumberGenerator.new()
		rng3.randomize()
		_after_match(d["xi"], won, lines, rng3)
	save()
	return lines

# ---------------------------------------------------------------- skills (evner, as in the 2D game)
# What makes a player special beyond his numbers. Up to two; the second place opens at rating 70.
# They come with players from packs, the market and the youth academy, or you teach him one for coins.
const ABIL := {
	"kanon": ["CANNON", "Shoots harder, and keepers reach fewer of his shots.", ["FW", "MF"]],
	"skrue": ["CURLER", "Placed shots bend much more round the keeper.", ["FW", "MF"]],
	"raket": ["ROCKET", "Faster top speed when he sprints.", ["FW", "MF", "DF"]],
	"tryl": ["MAGICIAN", "Defenders find it harder to take the ball off him.", ["FW", "MF"]],
	"luft": ["KING OF THE AIR", "Gets to more high balls and heads harder.", ["FW", "DF"]],
	"dirigent": ["CONDUCTOR", "Pinpoint passes, long ones too.", ["MF", "DF"]],
	"motor": ["MOTOR", "Tires more slowly.", ["MF", "DF", "FW"]],
	"mur": ["THE WALL", "Longer reach in the tackle, wins more of them.", ["DF", "MF"]],
	"laeser": ["READER", "Cuts out the other side's passes that go close by him.", ["DF", "MF"]],
	"bamse": ["TANK", "Strong on the ball: hard to push off it.", ["DF", "MF", "FW"]],
	"kat": ["THE CAT", "Lightning reflexes: reaches more shots.", ["GK"]],
	"straf": ["PENALTY KILLER", "Saves more penalties and shots from close in.", ["GK"]],
}
const AB_SLOT2 := 70
const AB_COST := [150, 400]
const AB_SWAP := 100

static func ab_for(pos: String) -> Array:
	var out := []
	for k in ABIL:
		if (ABIL[k][2] as Array).has(pos):
			out.append(k)
	return out

static func ab_of(pl: Dictionary) -> Array:
	var out := []
	for a in pl.get("ab", []):
		if ABIL.has(str(a)) and out.size() < 2:
			out.append(str(a))
	return out

# the skills a new player comes with: better players more often have one, the best two
static func ab_roll(pos: String, o: int, rng: RandomNumberGenerator) -> Array:
	var n := 0
	var r := rng.randf()
	if o >= 76:
		n = 2 if r < 0.35 else 1
	elif o >= 66:
		n = 1 if r < 0.65 else 0
	else:
		n = 1 if r < 0.25 else 0
	var pool := ab_for(pos)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))

# old saves: your best keeper, defender, midfielder and forward each get a skill, and some of the good ones too
func _ab_start() -> void:
	d["abv"] = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(d.get("club", 0)) + "ab")
	for pos in ["GK", "DF", "MF", "FW"]:
		var best = null
		for pl in d["squad"]:
			if str(pl["pos"]) == pos and ab_of(pl).is_empty() and (best == null or ovr_of(pl) > ovr_of(best)):
				best = pl
		if best != null:
			var pool := ab_for(pos)
			best["ab"] = [pool[rng.randi() % pool.size()]]
	for pl in d["squad"]:
		if ab_of(pl).is_empty() and ovr_of(pl) >= 66 and rng.randf() < 0.4:
			pl["ab"] = ab_roll(str(pl["pos"]), ovr_of(pl), rng).slice(0, 1)

func ab_price(pl: Dictionary, slot: int) -> int:
	var have := ab_of(pl)
	if slot < have.size():
		return AB_SWAP
	return AB_COST[clampi(slot, 0, 1)]

# teach him a skill in this place (or swap the one he has there)
func learn_ab(i: int, slot: int, key: String) -> String:
	if i < 0 or i >= (d["squad"] as Array).size() or not ABIL.has(key):
		return ""
	var pl: Dictionary = d["squad"][i]
	var have := ab_of(pl)
	if not (ABIL[key][2] as Array).has(str(pl["pos"])):
		return "A %s cannot learn that." % str(pl["pos"])
	if slot == 1 and ovr_of(pl) < AB_SLOT2:
		return "The second skill opens at rating %d." % AB_SLOT2
	if have.has(key):
		return "He already has %s." % ABIL[key][0]
	slot = mini(slot, have.size())
	var c := ab_price(pl, slot)
	if int(d["coins"]) < c:
		return "You need %s more." % money(c - int(d["coins"]))
	if slot < have.size():
		have[slot] = key
	else:
		have.append(key)
	pl["ab"] = have
	d["coins"] = int(d["coins"]) - c
	save()
	return "%s LEARNED %s" % [str(pl["n"]).to_upper(), ABIL[key][0]]

# ---------------------------------------------------------------- the board
# Every season the board sets three goals: one for the league, one for the cup and one more (young players,
# goals, clean sheets, building the club, home form). Its confidence in you moves after every match: a win the
# board did not expect lifts it a lot, a defeat against a weaker side costs. At the end of the season it gives
# you a grade and a bonus. In a FULL career it can also sack you; in a SIMPLE career it only grumbles.
const MOODS := [[85, "DELIGHTED"], [68, "HAPPY"], [50, "SATISFIED"], [35, "UNEASY"], [20, "WORRIED"], [0, "FURIOUS"]]
const GRADES := [[88, "A"], [72, "B"], [55, "C"], [38, "D"], [20, "E"], [0, "F"]]
const GRADE_BONUS := {"A": 400, "B": 260, "C": 150, "D": 60, "E": 0, "F": 0}
const SACK_AT := 20 # a FULL career: at or under this when the season ends, you are out

# "" = not chosen yet (an old save): the hub asks once
func mode() -> String:
	return str(d.get("mode", ""))

func full() -> bool:
	return mode() == "full"

func set_mode(m: String) -> void:
	d["mode"] = "full" if m == "full" else "simple"
	save()

func board() -> Dictionary:
	if not d.has("board"):
		d["board"] = {"conf": 55, "hist": [], "msg": "", "chg": 0}
		_board_season()
	return d["board"]

func conf() -> int:
	return clampi(int(board()["conf"]), 0, 100)

static func mood_of(c: int) -> String:
	for m in MOODS:
		if c >= int(m[0]):
			return str(m[1])
	return "FURIOUS"

# Where the board thinks you will finish: one place for every club with a stronger team than yours.
func expected_rank() -> int:
	var me := int(d["club"])
	var mine := my_strength()
	var r := 1
	for c in ids():
		if c != me and _strength(c) > mine + 0.5:
			r += 1
	return r

func _fac_sum() -> int:
	var s := 0
	for k in FAC_KEYS:
		s += fac(k)
	return s

# The three goals for a new season, measured against how good your team is now.
func _board_season() -> void:
	var b: Dictionary = d["board"]
	var ex := expected_rank()
	var dv := div()
	var n := ids().size()
	var lgd := league()
	var up := int(lgd["up"])
	var dn := int(lgd["down"])
	var lg := {}
	if ex <= 1:
		lg = {"k": "pos", "v": 1, "t": "WIN THE LEAGUE"} if dv == 1 else {"k": "pos", "v": up, "t": "WIN PROMOTION: FINISH IN THE TOP %d" % up}
	elif ex <= maxi(up + 2, 4):
		lg = {"k": "pos", "v": 4, "t": "FINISH IN THE TOP 4"} if dv == 1 else {"k": "pos", "v": up + 3, "t": "CHALLENGE FOR PROMOTION: TOP %d" % (up + 3)}
	elif ex <= n / 2 + 1:
		lg = {"k": "pos", "v": n / 2, "t": "FINISH IN THE TOP HALF"}
	elif dn > 0:
		lg = {"k": "pos", "v": n - dn, "t": "AVOID RELEGATION"}
	else:
		lg = {"k": "pos", "v": n - 3, "t": "STAY OUT OF THE BOTTOM THREE"}
	# the cup: measured against every club in the country
	var cr := cup_rounds()
	var cp_r0 := int(cup().get("r0", 0))
	var exc := 1
	var mine := my_strength()
	for li in ClubDB.LEAGUES.size():
		if str(ClubDB.LEAGUES[li]["c"]) == str(lgd["c"]):
			for c in ids(li):
				if c != int(d["club"]) and _strength(c) > mine + 0.5:
					exc += 1
	var nm := cup_names()
	var cp := {}
	if exc <= 2:
		cp = {"k": "cup", "v": cr, "t": "WIN THE CUP"}
	elif exc <= 4:
		cp = {"k": "cup", "v": cr - 1, "t": "REACH THE CUP FINAL"}
	elif exc <= 8:
		cp = {"k": "cup", "v": cr - 2, "t": "REACH THE CUP SEMI-FINAL"}
	elif exc <= 16:
		cp = {"k": "cup", "v": cr - 3, "t": "REACH THE CUP QUARTER-FINAL"}
	else:
		cp = {"k": "cup", "v": cp_r0 + 1, "t": "WIN A CUP TIE: REACH THE %s" % str(nm[clampi(cp_r0 + 1, 0, cr - 1)])}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var young := 0
	for i in d["xi"]:
		if int(d["squad"][int(i)]["age"]) <= 21:
			young += 1
	var pool := ["goals", "cs", "build", "home"]
	if young >= 1 or fac("youth") >= 2:
		pool.append("young")
	var k: String = pool[rng.randi() % pool.size()]
	var ex3 := {}
	match k:
		"goals":
			var g := int(round(rounds_total() * clampf(2.2 - ex * 0.1, 0.9, 2.1)))
			ex3 = {"k": "goals", "v": g, "t": "SCORE %d LEAGUE GOALS" % g}
		"cs":
			var c := int(round(rounds_total() * (0.36 if ex <= 3 else (0.28 if ex <= n / 2 else 0.2))))
			ex3 = {"k": "cs", "v": c, "t": "KEEP %d CLEAN SHEETS IN THE LEAGUE" % c}
		"build":
			ex3 = {"k": "build", "v": 1, "t": "BUILD ONE NEW LEVEL AT THE CLUB"}
		"home":
			var l := int(round(rounds_total() / 2.0 * (0.12 if ex <= 3 else 0.25)))
			ex3 = {"k": "home", "v": l, "t": "LOSE NO MORE THAN %d HOME MATCHES" % l}
		_:
			# a little more than the young men in the eleven now would get anyway
			var yv := clampi(young * rounds_total() + 6, 8, 60)
			ex3 = {"k": "young", "v": yv, "t": "GIVE %d LEAGUE STARTS TO PLAYERS AGED 21 OR UNDER" % yv}
	b["obj"] = [lg, cp, ex3]
	b["trk"] = {"goals": 0, "cs": 0, "home": 0, "young": 0, "fac0": _fac_sum()}
	b["ex"] = ex
	b["seen"] = false
	b["msg"] = "A NEW SEASON. THE BOARD HAS SET YOUR GOALS: THE MAIN ONE IS TO %s." % str(lg["t"]).split(":")[0]

# How far one goal has come: [text now, state] with state "done", "on", "behind" or "failed".
func obj_state(o: Dictionary) -> Array:
	var b := board()
	var trk: Dictionary = b.get("trk", {})
	var v := int(o["v"])
	var half_way := int(d["round"]) >= rounds_total() / 2
	var over := season_over() and not cup_due()
	match str(o["k"]):
		"pos":
			var r := rank_of(int(d["club"]))
			var now := "%s NOW" % ordinal(r) if int(d["round"]) > 0 else "SEASON NOT STARTED"
			if over:
				return ["FINISHED %s" % ordinal(r), "done" if r <= v else "failed"]
			return [now, "on" if r <= v or int(d["round"]) == 0 else "behind"]
		"cup":
			var cp: Dictionary = cup()
			var reached := int(cp["r"]) + (1 if bool(cp["won"]) else 0)
			var names: Array = cup_names() + ["WON"]
			if reached >= v:
				return ["WON THE CUP" if bool(cp["won"]) else "IN THE %s" % names[reached], "done"]
			if bool(cp["out"]):
				return ["OUT IN THE %s" % names[reached], "failed"]
			return ["%s NEXT" % names[reached], "on"]
		"goals", "cs", "young":
			var n := int(trk.get(str(o["k"]), 0))
			var left := rounds_total() - int(d["round"])
			var need := v - n
			if n >= v:
				return ["%d OF %d" % [n, v], "done"]
			if over:
				return ["%d OF %d" % [n, v], "failed"]
			var pace := float(n) / maxf(float(d["round"]), 1.0) * rounds_total()
			return ["%d OF %d" % [n, v], "on" if (int(d["round"]) < 3 or pace >= v * 0.9) and need <= left * (11 if str(o["k"]) == "young" else 3) else "behind"]
		"build":
			var built := _fac_sum() - int(trk.get("fac0", _fac_sum()))
			if built >= v:
				return ["DONE", "done"]
			return ["NOT YET" if not over else "NOTHING BUILT", "failed" if over else ("behind" if half_way else "on")]
		"home":
			var l := int(trk.get("home", 0))
			if l > v:
				return ["%d HOME DEFEATS" % l, "failed"]
			return ["%d HOME DEFEAT%s" % [l, "" if l == 1 else "S"], "done" if over else "on"]
	return ["", "on"]

func _conf_add(n: int) -> void:
	var b := board()
	b["conf"] = clampi(int(b["conf"]) + n, 0, 100)

# After a league match: the result against what the board expected, and whether the season is on course.
func _board_match(mine: int, theirs: int, opp: int, was_home: bool, starters: Array) -> String:
	var b := board()
	var trk: Dictionary = b["trk"]
	trk["goals"] = int(trk.get("goals", 0)) + mine
	if theirs == 0:
		trk["cs"] = int(trk.get("cs", 0)) + 1
	if was_home and mine < theirs:
		trk["home"] = int(trk.get("home", 0)) + 1
	for i in starters:
		if int(i) < (d["squad"] as Array).size() and int(d["squad"][int(i)]["age"]) <= 21:
			trk["young"] = int(trk.get("young", 0)) + 1
	var before := conf()
	var diff := clampf((my_strength() - _strength(opp)) / 6.0, -1.0, 1.0)
	var exp_pts := 1.35 + diff
	var pts := 3 if mine > theirs else (1 if mine == theirs else 0)
	var ch := int(round((pts - exp_pts) * 2.4))
	if mine - theirs >= 3:
		ch += 1
	elif theirs - mine >= 3:
		ch -= 2
	var lg: Dictionary = b["obj"][0]
	var r := rank_of(int(d["club"]))
	if int(d["round"]) >= 4:
		if r <= int(lg["v"]):
			ch += 1
		elif r > int(lg["v"]) + 2:
			ch -= 1
	_conf_add(ch)
	b["chg"] = conf() - before
	return _board_line(before)

func _board_cup(won: bool, r: int) -> String:
	var b := board()
	var before := conf()
	var goal := int(b["obj"][1]["v"])
	if won:
		_conf_add(3 + r)
	elif r < goal:
		_conf_add(-4 - (goal - r) * 2)
	b["chg"] = conf() - before
	return _board_line(before)

# The full-time line, and the board's word when it is getting worried.
func _board_line(before: int) -> String:
	var b := board()
	var c := conf()
	var ch := c - before
	if before >= 35 and c < 35:
		b["msg"] = "THE BOARD IS UNEASY. RESULTS MUST IMPROVE."
	elif before >= SACK_AT + 5 and c < SACK_AT + 5:
		b["msg"] = "FINAL WARNING: THE BOARD WILL SACK YOU IF THIS GOES ON." if full() else "THE BOARD IS VERY UNHAPPY WITH THE RESULTS."
	elif before < 68 and c >= 68:
		b["msg"] = "THE BOARD IS HAPPY WITH HOW THE SEASON IS GOING."
	elif before < 85 and c >= 85:
		b["msg"] = "THE BOARD IS DELIGHTED. KEEP IT UP!"
	return "THE BOARD %s%d  ·  %s" % ["+" if ch >= 0 else "", ch, mood_of(c)]

# The match bonus a happy board pays: +20% on coins from matches at confidence 80 or more.
func board_bonus(coins: int) -> int:
	return int(round(coins * 0.2)) if conf() >= 80 else 0

# The end of the season: how each goal went, a grade, the bonus, and in a FULL career maybe the sack.
func _board_review() -> void:
	var b := board()
	var before := conf()
	var rows := []
	var score := 0.0
	var wts := [50.0, 25.0, 25.0]
	var ch := 0
	for i in 3:
		var o: Dictionary = b["obj"][i]
		var st := obj_state(o)
		var ok: bool = st[1] == "done" or (st[1] == "on" and str(o["k"]) == "home")
		var part := 1.0 if ok else 0.0
		if not ok and str(o["k"]) == "pos":
			# close counts for something: one place off is half
			var miss := rank_of(int(d["club"])) - int(o["v"])
			part = clampf(1.0 - miss * 0.5, 0.0, 1.0)
			if rank_of(int(d["club"])) <= int(b.get("ex", 8)) - 2:
				part = maxf(part, 0.5)
		elif not ok and str(o["k"]) in ["goals", "cs", "young"]:
			part = clampf(float(int(b["trk"].get(str(o["k"]), 0))) / maxf(float(int(o["v"])), 1.0) - 0.2, 0.0, 0.8)
		score += wts[i] * part
		if i == 0:
			ch += 12 if ok else int(round(-18.0 * (1.0 - part)))
		else:
			ch += 5 if ok else -4
		rows.append([str(o["t"]), str(st[0]), ok])
	# beating the expectation by a lot is worth more than the goal itself
	var r := rank_of(int(d["club"]))
	if r < int(b.get("ex", 8)) - 1:
		score += 10.0
		ch += 5
	var grade := "F"
	for g in GRADES:
		if score >= float(g[0]):
			grade = str(g[1])
			break
	_conf_add(ch)
	var bonus := int(GRADE_BONUS[grade] * (1.0 + (4 - div()) * 0.5))
	d["coins"] = int(d["coins"]) + bonus
	var sacked := full() and conf() <= SACK_AT
	var c := conf()
	var words := ""
	if sacked:
		words = "THE BOARD HAS LOST ALL FAITH IN YOU. YOU ARE SACKED."
	elif grade in ["A", "B"]:
		words = "A SUPERB SEASON. THE BOARD IS BEHIND YOU ALL THE WAY." if grade == "A" else "A GOOD SEASON. THE BOARD IS PLEASED."
	elif grade == "C":
		words = "AN OK SEASON. THE BOARD WANTS MORE NEXT YEAR."
	elif c <= SACK_AT + 10:
		words = "A POOR SEASON. ONE MORE LIKE THIS AND YOU ARE OUT." if full() else "A POOR SEASON. THE BOARD IS VERY DISAPPOINTED."
	else:
		words = "A DISAPPOINTING SEASON. THE BOARD EXPECTS BETTER."
	var hist: Array = b["hist"]
	hist.append({"s": int(d["season"]), "div": div(), "pos": r, "g": grade})
	if hist.size() > 12:
		hist.pop_front()
	b["review"] = {"rows": rows, "grade": grade, "score": int(score), "ch": c - before, "conf": c, "bonus": bonus, "words": words, "sacked": sacked, "pos": r, "season": int(d["season"]), "div": div()}
	b["msg"] = words
	if sacked:
		d["sacked"] = true
		_job_offers()

func review() -> Dictionary:
	return board().get("review", {})

# ---- the sack (FULL career only): three clubs want you, in your division or one lower

func _job_offers() -> void:
	var me := int(d["club"])
	var dv := div()
	var cand := [[], []]
	for li in ClubDB.LEAGUES.size():
		var t := int(ClubDB.LEAGUES[li]["t"])
		var same: bool = str(ClubDB.LEAGUES[li]["c"]) == str(league()["c"])
		# a sacked manager gets offers from his own level or the one below, in either country
		if t == dv or t == dv + 1 or (not same and t >= dv):
			for c in ids(li):
				if c != me:
					cand[0 if t == dv and same else 1].append(c)
	cand[0].shuffle()
	cand[1].shuffle()
	var pick: Array = cand[0].slice(0, 1) + cand[1].slice(0, 2)
	var offers := []
	for c in pick:
		offers.append([int(c), league_of(int(c))])
	d["offers"] = offers

func offers() -> Array:
	return d.get("offers", [])

# Take the job: a new club with its own squad. Your record as a manager comes with you; the club's things do not.
func take_job(i: int) -> void:
	var of: Array = offers()
	if i < 0 or i >= of.size():
		return
	var c := int(of[i][0])
	var st: Dictionary = stats()
	st["jobs"] = int(st.get("jobs", 1)) + 1
	d["st"] = st
	d["club"] = c
	d["move"] = 0
	d.erase("own")
	d.erase("lay")
	d.erase("form")
	d.erase("sacked")
	d.erase("offers")
	d["fac"] = {}
	for k0 in ["wb", "facb", "fbuild", "freq", "talk"]:
		d.erase(k0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var q := club_level(c)
	d["squad"] = _make_squad(q, q - 5, rng)
	d["xi"] = range(11)
	d["season"] = int(d["season"]) + 1
	d["note"] = ""
	_move_clubs()
	d["lg"] = league_of(c)
	d["coins"] = start_coins(lg())
	_age_world()
	_ab_start()
	_new_season()
	cup_new()
	market_refresh()
	d["board"] = {"conf": 50, "hist": [], "msg": "", "chg": 0}
	_board_season()
	save()

func _make_squad(q_xi: int, q_bench: int, rng: RandomNumberGenerator) -> Array:
	var pool := names.duplicate()
	pool.shuffle()
	var squad := []
	for i in SQUAD_ROLES.size():
		var role: String = SQUAD_ROLES[i]
		var base: Array = ROLE_BASE[role]
		var q := q_xi if i < 11 else q_bench
		var pl := {
			"n": pool[i % pool.size()], "num": SQUAD_NUMS[i], "pos": role, "age": rng.randi_range(18, 31), "xp": 0, "g": 0, "apps": 0,
			"pac": clampi(base[0] + q + rng.randi_range(-4, 4), 30, 95), "sho": clampi(base[1] + q + rng.randi_range(-4, 4), 25, 95),
			"pas": clampi(base[2] + q + rng.randi_range(-4, 4), 30, 95), "dfn": clampi(base[3] + q + rng.randi_range(-4, 4), 25, 95),
		}
		pl["pot"] = clampi(ovr_of(pl) + rng.randi_range(3, 12) - maxi(int(pl["age"]) - 24, 0), ovr_of(pl), 94)
		squad.append(pl)
	return squad

# ---- the cup inside the season

# Your cup tie is the next match: its round is due once enough league rounds are played.
# Your cup tie is the next match: its round is due once enough league rounds are played.
func cup_due() -> bool:
	if cup_over():
		return false
	if bool(d.get("cupmode", false)):
		return true
	return int(d["round"]) >= cup_after() or season_over()

# the league round after which this cup round is played: the rounds are spread evenly through the season
func cup_after() -> int:
	return cup_after_r(int(cup()["r"]))

func cup_after_r(cr: int) -> int:
	var r := clampi(cr, 0, cup_rounds() - 1)
	return int(round(rounds_total() * (r + 1.0) / (cup_rounds() + 1.0)))

# ---------------------------------------------------------------- scouting and the youth academy
# As in FIFA: youth scouts go to a country and come back with young players whose real level is hidden.
# You see a range ("can reach 74-86"); a better scout gives a narrower one, and it narrows while the boy is in
# your academy. Now and then a scout finds a wonderkid. You sign the ones you like into the academy, where they
# grow, and promote them to the squad when they are ready.
const REGIONS := [["England", 0.0, 1.0], ["Denmark", -1.0, 0.9], ["Spain", 2.0, 1.1], ["Brazil", 3.0, 1.4], ["Netherlands", 1.0, 1.0], ["Germany", 1.0, 0.9], ["France", 2.0, 1.1], ["Argentina", 2.5, 1.3]]
const SCOUT_NAMES := ["Pete Harlow", "Jens Mogensen", "Rui Alves", "Marta Diaz", "Tom Becker", "Ole Krag", "Sam Okafor", "Luis Pardo"]
const ACAD_MAX := 6
const PROS_MAX := 8
const SCOUT_ROUNDS := 4

func scouts() -> Array:
	if not d.has("scouts"):
		d["scouts"] = [{"n": SCOUT_NAMES[int(d["club"]) % SCOUT_NAMES.size()], "st": 2, "rg": -1, "left": 0, "pick": 0}, {}]
	return d["scouts"]

func scout_cost(stars: int) -> int:
	return 40 * stars

# hire a scout in an empty place, or swap the scout for one with one more star
func scout_hire(slot: int) -> String:
	var sc: Array = scouts()
	if slot < 0 or slot >= sc.size():
		return ""
	var cur: Dictionary = sc[slot]
	var st: int = 1 if cur.is_empty() else int(cur["st"]) + 1
	if st > 5:
		return "HE IS THE BEST THERE IS"
	if not cur.is_empty() and int(cur.get("left", 0)) > 0:
		return "HE IS AWAY ON A TRIP"
	var cost := scout_cost(st)
	if int(d["coins"]) < cost:
		return "NOT ENOUGH MONEY: A %d-STAR SCOUT COSTS %s" % [st, money(cost)]
	d["coins"] = int(d["coins"]) - cost
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	sc[slot] = {"n": SCOUT_NAMES[rng.randi() % SCOUT_NAMES.size()], "st": st, "rg": -1, "left": 0, "pick": int(cur.get("pick", 0))}
	save()
	return "%s (%d STARS) JOINS YOUR STAFF" % [str(sc[slot]["n"]).to_upper(), st]

func scout_pick(slot: int) -> void:
	var sc: Dictionary = scouts()[slot]
	if sc.is_empty() or int(sc.get("left", 0)) > 0:
		return
	sc["pick"] = (int(sc.get("pick", 0)) + 1) % REGIONS.size()
	save()

func scout_send(slot: int) -> String:
	var sc: Dictionary = scouts()[slot]
	if sc.is_empty() or int(sc.get("left", 0)) > 0:
		return ""
	sc["rg"] = int(sc.get("pick", 0))
	sc["left"] = SCOUT_ROUNDS
	save()
	return "%s IS OFF TO %s FOR %d MATCHES" % [str(sc["n"]).to_upper(), str(REGIONS[int(sc["rg"])][0]).to_upper(), SCOUT_ROUNDS]

func prospects() -> Array:
	if not d.has("pros"):
		d["pros"] = []
	return d["pros"]

func academy() -> Array:
	if not d.has("acad"):
		d["acad"] = []
	return d["acad"]

func _free_name(rng: RandomNumberGenerator) -> String:
	var taken := {}
	for l in [d["squad"], d.get("market", []), prospects(), academy()]:
		for pl in l:
			taken[str(pl["n"])] = true
	var pool := []
	for n in names:
		if not taken.has(str(n)):
			pool.append(n)
	if pool.is_empty():
		return str(names[rng.randi() % names.size()]) if not names.is_empty() else "KID"
	return str(pool[rng.randi() % pool.size()])

# a young player: real level and potential, and what your scout thinks they are (a range)
func _youth(rng: RandomNumberGenerator, rg: int, stars: int) -> Dictionary:
	var R: Array = REGIONS[clampi(rg, 0, REGIONS.size() - 1)]
	var role: String = ["GK", "DF", "DF", "MF", "MF", "FW", "FW"][rng.randi() % 7]
	var base: Array = ROLE_BASE[role]
	var q := -20 + rng.randi_range(-3, 4)
	var pl := {"n": _free_name(rng), "num": 0, "pos": role, "age": rng.randi_range(15, 17), "xp": 0, "g": 0, "apps": 0,
		"pac": clampi(base[0] + q + rng.randi_range(-4, 4), 30, 95), "sho": clampi(base[1] + q + rng.randi_range(-4, 4), 25, 95),
		"pas": clampi(base[2] + q + rng.randi_range(-4, 4), 30, 95), "dfn": clampi(base[3] + q + rng.randi_range(-4, 4), 25, 95), "rg": rg}
	# a better scout finds better boys, and some countries have more of them
	var pot := 62.0 + stars * 2.5 + float(R[1]) + rng.randfn(0.0, 6.0 * float(R[2]))
	var wonder := rng.randf() < 0.02 + stars * 0.015
	if wonder:
		pot = rng.randf_range(86.0, 94.0)
	pl["pot"] = clampi(int(round(pot)), ovr_of(pl) + 6, 95)
	if rng.randf() < 0.15 + stars * 0.04:
		pl["ab"] = ab_roll(role, 70, rng).slice(0, 1)
	# what the scout reports: the wider, the worse the scout
	var w := (6 - stars) * 2 + 2
	var lo := int(pl["pot"]) - rng.randi_range(0, w)
	pl["plo"] = clampi(lo, ovr_of(pl) + 2, 95)
	pl["phi"] = clampi(lo + w + rng.randi_range(0, 2), int(pl["pot"]), 97)
	var ow := maxi(1, 5 - stars)
	pl["olo"] = ovr_of(pl) - rng.randi_range(0, ow)
	pl["ohi"] = int(pl["olo"]) + ow + 1
	pl["exp"] = 8 # rounds before another club signs him
	pl["fee"] = maxi(10, 8 + (int(pl["phi"]) - 60) * 2)
	return pl

func _scout_tick(rng: RandomNumberGenerator, lines: Array) -> void:
	var pr: Array = prospects()
	for p in pr:
		p["exp"] = int(p["exp"]) - 1
	var gone := pr.filter(func(p): return int(p["exp"]) <= 0)
	if not gone.is_empty():
		lines.append("SCOUTING: ANOTHER CLUB SIGNED %s" % str(gone[0]["n"]).to_upper())
	d["pros"] = pr.filter(func(p): return int(p["exp"]) > 0)
	for sc in scouts():
		if sc.is_empty() or int(sc.get("left", 0)) <= 0:
			continue
		sc["left"] = int(sc["left"]) - 1
		if rng.randf() < 0.55 + int(sc["st"]) * 0.07 or int(sc["left"]) == 0:
			var yp := _youth(rng, int(sc["rg"]), int(sc["st"]))
			prospects().append(yp)
			while prospects().size() > PROS_MAX:
				prospects().pop_front()
			lines.append("SCOUT REPORT: %s (%d, %s) IN %s, CAN REACH %d-%d" % [str(yp["n"]).to_upper(), int(yp["age"]), str(yp["pos"]), str(REGIONS[int(yp["rg"])][0]).to_upper(), int(yp["plo"]), int(yp["phi"])])
		if int(sc["left"]) == 0:
			sc["rg"] = -1

func youth_sign(i: int) -> String:
	var pr: Array = prospects()
	if i < 0 or i >= pr.size():
		return ""
	if academy().size() >= ACAD_MAX:
		return "THE ACADEMY IS FULL (%d): PROMOTE OR RELEASE A BOY FIRST" % ACAD_MAX
	var pl: Dictionary = pr[i]
	var fee := int(pl["fee"])
	if int(d["coins"]) < fee:
		return "NOT ENOUGH MONEY: HE COSTS %s" % money(fee)
	d["coins"] = int(d["coins"]) - fee
	pr.remove_at(i)
	pl.erase("exp")
	# in your own academy you see his level at once; the potential still takes time
	pl["olo"] = ovr_of(pl)
	pl["ohi"] = ovr_of(pl)
	academy().append(pl)
	save()
	return "%s JOINS YOUR ACADEMY" % str(pl["n"]).to_upper()

func youth_drop(i: int) -> void:
	if i >= 0 and i < prospects().size():
		prospects().remove_at(i)
		save()

# the boys grow in the academy, and you learn more about them each round
func _acad_tick(rng: RandomNumberGenerator, lines: Array) -> void:
	for pl in academy():
		if rng.randf() < 0.45 + 0.05 * fac("youth") and ovr_of(pl) < int(pl["pot"]) - 4:
			var k: String = _grow_key(pl, rng)
			pl[k] = mini(int(pl[k]) + 1, 95)
		if int(pl["plo"]) < int(pl["pot"]):
			pl["plo"] = int(pl["plo"]) + 1
		if int(pl["phi"]) > int(pl["pot"]):
			pl["phi"] = int(pl["phi"]) - 1
		pl["olo"] = ovr_of(pl)
		pl["ohi"] = ovr_of(pl)
		if int(pl["plo"]) == int(pl["phi"]) and not pl.get("known", false):
			pl["known"] = true
			lines.append("ACADEMY: NOW WE KNOW, %s CAN REACH %d" % [str(pl["n"]).to_upper(), int(pl["pot"])])

func youth_promote(i: int) -> String:
	var ac: Array = academy()
	if i < 0 or i >= ac.size():
		return ""
	if (d["squad"] as Array).size() >= SQUAD_MAX:
		return "NO ROOM IN THE SQUAD (%d): SELL SOMEONE FIRST" % SQUAD_MAX
	var pl: Dictionary = ac[i]
	ac.remove_at(i)
	for k in ["plo", "phi", "olo", "ohi", "rg", "fee", "known"]:
		pl.erase(k)
	var used := []
	for s2 in d["squad"]:
		used.append(int(s2["num"]))
	for n in range(20, 99):
		if not used.has(n):
			pl["num"] = n
			break
	if eur:
		pl["wk"] = 1
		pl["ct"] = 3
	d["squad"].append(pl)
	save()
	return "%s IS PROMOTED TO THE SQUAD" % str(pl["n"]).to_upper()

func youth_release(i: int) -> void:
	if i >= 0 and i < academy().size():
		academy().remove_at(i)
		save()

# the academy's own local talent (twice a season): a better youth facility, a better boy
func youth_local(rng: RandomNumberGenerator) -> String:
	if academy().size() >= ACAD_MAX:
		return ""
	var ctry := str(league()["c"])
	var pl := _youth(rng, 1 if ctry == "DENMARK" else 0, 1 + fac("youth"))
	pl.erase("exp")
	pl["olo"] = ovr_of(pl)
	pl["ohi"] = ovr_of(pl)
	academy().append(pl)
	return "ACADEMY: A LOCAL TALENT, %s (%d, %s), CAN REACH %d-%d" % [str(pl["n"]).to_upper(), int(pl["age"]), str(pl["pos"]), int(pl["plo"]), int(pl["phi"])]

# ---------------------------------------------------------------- the calendar
# The season has dates, like a real one: league matches at the weekend from early August, a cup tie in the
# middle of the week after its league round. Days count from the first match day (day 0).
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const WDAYS := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

# The league's match days: Saturdays from early August, and when a league has more rounds than weekends a
# Tuesday round now and then (never in a week with a cup tie). A short season plays every other weekend.
var _dcache := []
var _dkey := ""

func _lg_days() -> Array:
	var n := rounds_total()
	var cr_n := cup_rounds() if d.has("cup") else 0
	var key := "%d/%d" % [n, cr_n]
	if key == _dkey:
		return _dcache
	var cup_a := {}
	for cr in cr_n:
		cup_a[cup_after_r(cr) - 1] = true
	var step_w := 2 if n <= 20 else 1
	var extra := maxi(0, n - 40)
	var every := maxi(1, int(40.0 / maxf(extra, 1.0)))
	var out := []
	var w := 0
	while out.size() < n:
		var r := out.size()
		out.append(w * 7 * step_w)
		if extra > 0 and out.size() < n and w % every == 1 % every and not cup_a.has(r) and not cup_a.has(r + 1):
			out.append(w * 7 * step_w + 3)
			extra -= 1
		w += 1
	_dcache = out
	_dkey = key
	return out

func lg_day(r: int) -> int:
	var ds := _lg_days()
	if ds.is_empty():
		return 0
	if r < ds.size():
		return int(ds[maxi(r, 0)])
	return int(ds[ds.size() - 1]) + 7 * (r - ds.size() + 1)

# a cup tie: the Wednesday after its league round
func cup_day(cr: int) -> int:
	return lg_day(maxi(cup_after_r(cr) - 1, 0)) + 4

# the first match day: the first Saturday from the 8th of August, one year on for each season
func _day0() -> int:
	var u := int(Time.get_unix_time_from_datetime_dict({"year": 2026 + int(d.get("season", 1)) - 1, "month": 8, "day": 8, "hour": 12}))
	var wd := int(Time.get_datetime_dict_from_unix_time(u)["weekday"])
	return u + ((6 - wd + 7) % 7) * 86400

# a day as {y, m (1-12), d, wd (0 = Sunday)}
func date_of(day: int) -> Dictionary:
	var t := Time.get_datetime_dict_from_unix_time(_day0() + day * 86400)
	return {"y": int(t["year"]), "m": int(t["month"]), "d": int(t["day"]), "wd": int(t["weekday"])}

func date_text(day: int, long := false) -> String:
	var t := date_of(day)
	if long:
		return "%s %d %s" % [WDAYS[int(t["wd"])], int(t["d"]), MONTHS[int(t["m"]) - 1]]
	return "%s %d %s" % [WDAYS[int(t["wd"])], int(t["d"]), MONTHS[int(t["m"]) - 1].substr(0, 3)]

# today: the day of the last match you played (or a few days before the season)
func today() -> int:
	return int(d.get("day", -4))

# Every match of your season, in date order: league rounds and your cup ties.
# {day, kind "lg"/"cup", opp (-1 = not known yet), home, res [mine, theirs] or [], name, next}
func calendar() -> Array:
	var out := []
	var me := int(d["club"])
	var fx: Array = d.get("fix", [])
	var mr: Dictionary = d.get("myres", {})
	for r in fx.size():
		var opp := -1
		var home := true
		for m in fx[r]:
			if int(m[0]) == me:
				opp = int(m[1])
			elif int(m[1]) == me:
				opp = int(m[0])
				home = false
		var res: Array = mr.get(str(r), [])
		out.append({"day": lg_day(r), "kind": "lg", "opp": opp, "home": home, "res": res, "played": r < int(d["round"]), "name": "Round %d" % (r + 1), "next": false})
	if not bool(d.get("cupmode", false)) and d.has("cup"):
		var cp: Dictionary = cup()
		var nm := cup_names()
		var lg_log: Array = cp.get("log", [])
		for cr in nm.size():
			if cr == 0 and int(cp.get("r0", 0)) == 1:
				continue # a bye
			var e := {"day": cup_day(cr), "kind": "cup", "opp": -1, "home": true, "res": [], "played": false, "name": str(nm[cr]).capitalize(), "next": false}
			if cr < lg_log.size():
				var found := false
				for t in lg_log[cr]:
					if int(t[0]) == me or int(t[1]) == me:
						var a_me := int(t[0]) == me
						e["opp"] = int(t[1]) if a_me else int(t[0])
						e["res"] = [int(t[2]) if a_me else int(t[3]), int(t[3]) if a_me else int(t[2])]
						e["played"] = true
						found = true
				if not found:
					continue
			elif cr == int(cp["r"]) and not cup_over():
				e["opp"] = cup_opp()
			elif cup_over():
				continue
			out.append(e)
	out.sort_custom(func(a, b): return int(a["day"]) < int(b["day"]))
	for e in out:
		if not bool(e["played"]):
			e["next"] = true
			break
	return out

# the day of your next match, or -1 when the season is over
func next_day() -> int:
	if cup_due():
		return maxi(cup_day(int(cup()["r"])), today() + 1)
	if season_over():
		return -1
	return lg_day(int(d["round"]))

# A match you do not play yourself: the score from the two clubs' strength, with a little home edge.
# [mine, theirs, scorers (squad indices), minutes of the goals [[minute, 0 = you / 1 = them, scorer name]]]
func sim_match(opp: int, home: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var df := (my_strength() - _strength(opp)) / 14.0 + (0.12 if home else -0.12)
	var mine := _poisson(rng, 1.35 * exp(df) + 0.1)
	var theirs := _poisson(rng, 1.35 * exp(-df))
	var pool := []
	for i in d["xi"]:
		var pl: Dictionary = d["squad"][int(i)]
		var wgt: int = {"FW": 6, "MF": 3, "DF": 1}.get(str(pl["pos"]), 0)
		for k in wgt:
			pool.append(int(i))
	var scorers := []
	var goals := []
	for g in mine:
		var who: int = pool[rng.randi() % pool.size()] if not pool.is_empty() else -1
		if who >= 0:
			scorers.append(who)
		goals.append([rng.randi_range(2, 90), 0, str(d["squad"][who]["n"]) if who >= 0 else ""])
	for g in theirs:
		goals.append([rng.randi_range(2, 90), 1, ""])
	goals.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	return [mine, theirs, scorers, goals]

# match settings for the career's own matches: level 0-2, length 0-2
func set_cfg(k: String, v: int) -> void:
	d[k] = clampi(v, 0, 2)
	save()

# ---------------------------------------------------------------- old saves
# A career from before the world of leagues: your club joins the English league of its old division, in the
# place of that league's weakest club, and starts the season again with its squad, coins and buildings.
func _migrate() -> void:
	var old_div := clampi(int(d.get("div", 4)), 1, 4)
	var li := old_div - 1
	d["mig"] = int(d["club"])
	d["leagues"] = ClubDB.start_leagues(FIRST)
	var c := weakest(li)
	d["club"] = c
	d["lg"] = li
	d["slen"] = "full"
	d["cx"] = {}
	d.erase("n")
	d.erase("div")
	d.erase("cup")
	d.erase("board")
	d.erase("sacked")
	d.erase("offers")
	d["move"] = 0
	_new_season()
	cup_new()
	board()
	market_refresh()
	d["note"] = ""
	(d["board"] as Dictionary)["msg"] = "YOUR CLUB HAS JOINED %s. A NEW SEASON STARTS." % league_name()

# ---------------------------------------------------------------- the other clubs' squads
# Every club has its own eighteen men, made from the club's number so they are the same every time,
# until you buy one of them (or sell them one): then that club's squad is kept in the save.
const CPU_ROLES := ["GK", "DF", "DF", "DF", "DF", "MF", "MF", "MF", "FW", "FW", "FW", "GK", "DF", "DF", "MF", "MF", "FW", "FW"]

func cpu_squad(c: int) -> Array:
	var cx: Dictionary = d.get("cx", {})
	if cx.has(str(c)):
		return cx[str(c)]
	var rng := RandomNumberGenerator.new()
	rng.seed = c * 7919 + 13
	var pool := names.duplicate()
	for n in range(pool.size() - 1, 0, -1):
		var sw := rng.randi_range(0, n)
		var tmp = pool[n]
		pool[n] = pool[sw]
		pool[sw] = tmp
	var q := rating(c) - 72
	var out := []
	var stars := [9, 6 + c % 2]
	for i in CPU_ROLES.size():
		var role: String = CPU_ROLES[i]
		var base: Array = ROLE_BASE[role]
		var qq := q + (6 if stars.has(i) else 0) - (5 if i >= 11 else 0)
		var pl := {
			"n": pool[i % pool.size()], "num": [1, 3, 4, 5, 2, 8, 6, 10, 11, 9, 7, 13, 15, 16, 14, 18, 19, 20][i], "pos": role, "age": rng.randi_range(18, 33), "xp": 0, "g": 0, "apps": 0,
			"pac": clampi(base[0] + qq + rng.randi_range(-5, 5), 30, 97), "sho": clampi(base[1] + qq + rng.randi_range(-5, 5), 25, 97),
			"pas": clampi(base[2] + qq + rng.randi_range(-5, 5), 30, 97), "dfn": clampi(base[3] + qq + rng.randi_range(-5, 5), 25, 97),
		}
		pl["pot"] = clampi(ovr_of(pl) + maxi(26 - int(pl["age"]), 0) * 2 + rng.randi_range(0, 4), ovr_of(pl), 96)
		pl["ab"] = ab_roll(role, ovr_of(pl), rng)
		out.append(pl)
	return out

func _set_cpu_squad(c: int, sq: Array) -> void:
	if not d.has("cx"):
		d["cx"] = {}
	d["cx"][str(c)] = sq

# The eleven a computer club puts out for these roles: the best man for each place.
func cpu_xi(c: int, roles: Array) -> Array:
	var sq := cpu_squad(c)
	var used := []
	var out := []
	for r in roles:
		var best := -1
		for pass_n in 2:
			for i in sq.size():
				if used.has(i) or (pass_n == 0 and str(sq[i]["pos"]) != str(r)) or (pass_n == 1 and str(sq[i]["pos"]) == "GK"):
					continue
				if best < 0 or ovr_of(sq[i]) > ovr_of(sq[best]):
					best = i
			if best >= 0:
				break
		if best < 0:
			best = 0
		used.append(best)
		out.append(sq[best])
	return out

# A club in your country at the player's level that would buy him.
func _buyer_for(pl: Dictionary, rng: RandomNumberGenerator) -> int:
	var o := ovr_of(pl)
	var cand := []
	for li in ClubDB.LEAGUES.size():
		if str(ClubDB.LEAGUES[li]["c"]) != str(league()["c"]):
			continue
		for c in ids(li):
			if c != int(d["club"]) and absi(rating(c) - o) <= 5:
				cand.append(c)
	if cand.is_empty():
		return -1
	return int(cand[rng.randi() % cand.size()])

# What a club wants for one of its men: more for a starter, much more for its best, more again when a big club
# would sell to a smaller one.
func ask_price(c: int, i: int) -> int:
	var sq := cpu_squad(c)
	if i < 0 or i >= sq.size():
		return 0
	var pl: Dictionary = sq[i]
	var ovs := []
	for x in sq:
		ovs.append(ovr_of(x))
	ovs.sort()
	ovs.reverse()
	var k := 1.0
	var o := ovr_of(pl)
	if o >= int(ovs[min(2, ovs.size() - 1)]):
		k = 1.6
	elif o >= int(ovs[min(10, ovs.size() - 1)]):
		k = 1.25
	if rating(c) > my_strength() + 5.0:
		k *= 1.2
	return int(round(value(pl) * k / 5.0)) * 5

# You bid for player i of club c. Returns {ok, msg, counter}.
func bid(c: int, i: int, amount: int) -> Dictionary:
	var sq := cpu_squad(c)
	if i < 0 or i >= sq.size():
		return {"ok": false, "msg": ""}
	if (d["squad"] as Array).size() >= SQUAD_MAX:
		return {"ok": false, "msg": "Your squad is full. Sell a player first."}
	if int(d["coins"]) < amount:
		return {"ok": false, "msg": "You need %s more." % money(amount - int(d["coins"]))}
	var ask := ask_price(c, i)
	var neg: Dictionary = d.get("neg", {})
	var key := "%d:%s" % [c, str(sq[i]["n"])]
	var pl: Dictionary = sq[i]
	if amount >= ask or (neg.has(key) and amount >= int(neg[key])):
		neg.erase(key)
		d["neg"] = neg
		if wages_on():
			# the clubs agree on the fee: now the player himself has to say yes to a contract
			talk_sign(pl, amount, c, i)
			save()
			return {"ok": true, "talk": true, "msg": "FEE AGREED WITH %s. NOW TALK TO %s." % [str(W[c]["n"]), str(pl["n"]).to_upper()]}
		return {"ok": true, "msg": _complete_bid(c, i, amount, -1, -1)}
	if amount >= int(ask * 0.75):
		neg[key] = ask
		d["neg"] = neg
		save()
		return {"ok": false, "counter": ask, "msg": "%s SAY NO, BUT THEY WOULD TAKE %s." % [str(W[c]["n"]), money(ask)]}
	return {"ok": false, "msg": "%s TURN THE BID DOWN FLAT." % str(W[c]["n"])}

# The transfer goes through: he joins you, his club signs a younger, cheaper man for his place.
func _complete_bid(c: int, i: int, amount: int, wk: int, yrs: int) -> String:
	var sq := cpu_squad(c)
	var pl: Dictionary = sq[i]
	if true:
		# he leaves: the club signs a younger, cheaper man for his place
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var role := str(pl["pos"])
		var base: Array = ROLE_BASE[role]
		var q := rating(c) - 76
		var nw := {"n": names[rng.randi() % names.size()], "num": int(pl["num"]), "pos": role, "age": rng.randi_range(18, 23), "xp": 0, "g": 0, "apps": 0,
			"pac": clampi(base[0] + q + rng.randi_range(-4, 4), 30, 95), "sho": clampi(base[1] + q + rng.randi_range(-4, 4), 25, 95),
			"pas": clampi(base[2] + q + rng.randi_range(-4, 4), 30, 95), "dfn": clampi(base[3] + q + rng.randi_range(-4, 4), 25, 95), "ab": []}
		nw["pot"] = clampi(ovr_of(nw) + rng.randi_range(4, 12), ovr_of(nw), 94)
		var their := sq.duplicate(true)
		their[i] = nw
		_set_cpu_squad(c, their)
		var used := []
		for x in d["squad"]:
			used.append(int(x["num"]))
		var me_pl: Dictionary = pl.duplicate(true)
		for n in range(2, 99):
			if not used.has(n):
				me_pl["num"] = n
				break
		me_pl["xp"] = 0
		me_pl["tp"] = 0
		me_pl["g"] = 0
		me_pl["apps"] = 0
		if wk >= 0:
			me_pl["wk"] = wk
			me_pl["ct"] = yrs
		d["coins"] = int(d["coins"]) - amount
		d["squad"].append(me_pl)
		save()
		return "%s SIGNED FROM %s FOR %s" % [str(pl["n"]).to_upper(), str(W[c]["n"]), money(amount)]
	return ""

# ---------------------------------------------------------------- the career's money, like a real club (euros only)
# Two budgets: the transfer budget (d["coins"]) and a wage budget a week (d["wb"], in thousands of euros).
# Every player has a wage (pl["wk"], thousands a week) and a contract (pl["ct"], seasons left, this one counted).
# A new man or a new contract is a talk with the player: he asks for a wage, you offer a wage and the seasons.
# The club's buildings come with the club; better ones you ask the board for.
const WB_STEP := 5 # thousands a week moved at a time
const WB_RATE := 4 # transfer budget units (10K) for every 1K a week
const FAC_BUILD := 8 # league matches a new building takes

static func _nh(s: String) -> int:
	return absi(s.hash())

static func wage_of(pl: Dictionary) -> int:
	var o := ovr_of(pl)
	return maxi(1, int(round(1.0 + pow(maxf(o - 50.0, 0.0), 2.0) * 0.05 + maxf(int(pl["pot"]) - o, 0.0) * 0.1)))

static func wage_text(k: int) -> String:
	if k >= 1000:
		return "€%sM" % String.num(k / 1000.0, 1).trim_suffix(".0")
	return "€%dK" % k

# Wages and contracts are part of a FULL career only; a simple career just buys, sells and plays.
func wages_on() -> bool:
	return eur and full()

func wages() -> int:
	var t := 0
	for pl in d["squad"]:
		t += int(pl.get("wk", 0))
	return t

func wb() -> int:
	money_init()
	return int(d.get("wb", 0))

func money_init() -> void:
	if not eur or d.is_empty() or not d.has("squad"):
		return
	var ch := false
	for pl in d["squad"]:
		if not pl.has("wk"):
			pl["wk"] = wage_of(pl)
			pl["ct"] = 2 + _nh(str(pl["n"])) % 3
			ch = true
	if not d.has("wb"):
		d["wb"] = int(ceil(wages() * 1.3)) + 5
		ch = true
	if not d.has("facb"):
		d["facb"] = true
		if int(d["season"]) == 1 and int(d["round"]) == 0:
			# a new club comes with the buildings that fit its size
			var lv := clampi(1 + (rating(int(d["club"])) - 62) / 5, 1, FAC_MAX)
			d["fac"] = {"stadium": lv, "training": lv, "youth": maxi(1, lv - 1)}
		ch = true
	if ch:
		save()

func wb_move(up: bool) -> String:
	money_init()
	var cost := WB_STEP * WB_RATE
	if up:
		if int(d["coins"]) < cost:
			return "You need %s in the transfer budget for that." % money(cost)
		d["coins"] = int(d["coins"]) - cost
		d["wb"] = int(d["wb"]) + WB_STEP
	else:
		if int(d["wb"]) - WB_STEP < wages():
			return "Your players' wages already use that money."
		d["wb"] = int(d["wb"]) - WB_STEP
		d["coins"] = int(d["coins"]) + cost
	save()
	return ""

# ---- contract talks
func talk() -> Dictionary:
	return d.get("talk", {})

func talk_end() -> void:
	d.erase("talk")
	save()

func _talk_fill(t: Dictionary, pl: Dictionary, ask: int) -> void:
	var h := _nh(str(pl["n"]))
	var age := int(pl["age"])
	t["n"] = str(pl["n"])
	t["pos"] = str(pl["pos"])
	t["age"] = age
	t["ovr"] = ovr_of(pl)
	t["pot"] = int(pl["pot"])
	t["ask"] = ask
	# what he would take in the end: a little under what he asks, different for every man
	t["min"] = maxi(1, int(round(ask * (0.84 + (h % 11) * 0.012))))
	t["maxy"] = 5 if age <= 26 else (4 if age <= 29 else (3 if age <= 31 else 2))
	t["offer"] = ask
	t["yrs"] = mini(3, int(t["maxy"]))
	t["tries"] = 3
	t["hint"] = ""

func talk_renew(i: int) -> String:
	money_init()
	var sq: Array = d["squad"]
	if i < 0 or i >= sq.size():
		return ""
	var pl: Dictionary = sq[i]
	if int(pl.get("nt", 0)) == int(d["season"]):
		return "%s WILL NOT TALK AGAIN BEFORE NEXT SEASON." % str(pl["n"]).to_upper()
	var starter: bool = (d["xi"] as Array).has(i)
	var ask := maxi(int(pl.get("wk", 1)), int(round(wage_of(pl) * (1.15 if starter else 1.0))))
	var unhappy := int(pl.get("mo", 65)) < 35
	if unhappy:
		# an unhappy man wants a lot more to stay
		ask = int(round(ask * 1.3)) + 1
	var t := {"kind": "renew", "i": i, "cur": int(pl.get("wk", 0)), "ct": int(pl.get("ct", 1)), "unhappy": unhappy}
	_talk_fill(t, pl, ask)
	if unhappy:
		t["maxy"] = mini(int(t["maxy"]), 2)
		t["yrs"] = mini(int(t["yrs"]), 2)
	d["talk"] = t
	save()
	return ""

func talk_sign(pl: Dictionary, fee: int, from: int, idx: int) -> void:
	money_init()
	var t := {"kind": "sign", "fee": fee, "from": from, "idx": idx, "cur": 0}
	_talk_fill(t, pl, maxi(1, int(round(wage_of(pl) * 1.2))))
	d["talk"] = t
	save()

func talk_set(what: String, step: int) -> void:
	var t := talk()
	if t.is_empty():
		return
	if what == "w":
		var st := maxi(1, int(round(int(t["ask"]) * 0.04)))
		t["offer"] = clampi(int(t["offer"]) + step * st, 1, int(t["ask"]) * 2)
	else:
		t["yrs"] = clampi(int(t["yrs"]) + step, 1, 5)
	d["talk"] = t

# You make the offer. Returns what happened; when the talk is over, talk() is empty.
func talk_offer() -> String:
	var t := talk()
	if t.is_empty():
		return ""
	var nm := str(t["n"]).to_upper()
	var after := wages() - int(t["cur"]) + int(t["offer"])
	if after > wb():
		return "THAT GOES OVER YOUR WAGE BUDGET (%s OF %s A WEEK). SELL SOMEONE OR MOVE MONEY TO WAGES." % [wage_text(after), wage_text(wb())]
	if int(t["yrs"]) > int(t["maxy"]):
		return "AT %d HE ONLY SIGNS FOR UP TO %d SEASONS." % [int(t["age"]), int(t["maxy"])]
	var signing := str(t["kind"]) == "sign"
	if signing:
		if int(d["coins"]) < int(t["fee"]):
			return "YOU NEED %s MORE FOR THE FEE." % money(int(t["fee"]) - int(d["coins"]))
		if (d["squad"] as Array).size() >= SQUAD_MAX:
			return "YOUR SQUAD IS FULL. SELL A PLAYER FIRST."
		# is he still there?
		var still := false
		var fr := int(t["from"])
		var ix := int(t["idx"])
		if fr >= 0:
			var cs := cpu_squad(fr)
			still = ix < cs.size() and str(cs[ix]["n"]) == str(t["n"])
		else:
			var mk := market()
			still = ix < mk.size() and str(mk[ix]["n"]) == str(t["n"])
		if not still:
			talk_end()
			return "%s HAS GONE ELSEWHERE. THE DEAL IS OFF." % nm
	if int(t["offer"]) >= int(t["min"]):
		var wk := int(t["offer"])
		var yrs := int(t["yrs"])
		d.erase("talk")
		if signing:
			var r := _complete_bid(int(t["from"]), int(t["idx"]), int(t["fee"]), wk, yrs) if int(t["from"]) >= 0 else _complete_buy(int(t["idx"]), wk, yrs)
			save()
			return "%s  ·  %s A WEEK FOR %d SEASONS" % [r, wage_text(wk), yrs]
		var pl: Dictionary = d["squad"][int(t["i"])]
		pl["wk"] = wk
		pl["ct"] = yrs
		save()
		return "%s SIGNS A NEW CONTRACT: %s A WEEK FOR %d SEASONS" % [nm, wage_text(wk), yrs]
	t["tries"] = int(t["tries"]) - 1
	if int(t["tries"]) <= 0:
		d.erase("talk")
		if not signing:
			(d["squad"][int(t["i"])] as Dictionary)["nt"] = int(d["season"])
		save()
		return ("%s HAS HAD ENOUGH. HE WILL NOT TALK AGAIN BEFORE NEXT SEASON." % nm) if not signing else ("%s SAYS NO. THE DEAL IS OFF." % nm)
	# how far off you are, the way an agent would say it
	t["hint"] = "CLOSE. HE WANTS A LITTLE MORE." if int(t["offer"]) >= int(t["min"]) * 0.93 else "HE SAYS NO. THAT IS FAR FROM WHAT HE WANTS."
	d["talk"] = t
	save()
	return "%s  %d %s LEFT." % [str(t["hint"]), int(t["tries"]), "TRY" if int(t["tries"]) == 1 else "TRIES"]

# The season ends: every contract has one season less. Who has none left goes on a free.
func _contracts_end() -> Array:
	var gone := []
	if not wages_on() or not d.has("wb"):
		return gone
	var sq: Array = d["squad"]
	for pl in sq:
		pl["ct"] = int(pl.get("ct", 1)) - 1
	var i := sq.size() - 1
	while i >= 0:
		if int(sq[i]["ct"]) <= 0:
			var nm0 := str(sq[i]["n"]).to_upper()
			if sq.size() > SQUAD_MIN and _drop(i):
				gone.append(nm0)
			else:
				# too few men: he stays one more season on the same wage
				sq[i]["ct"] = 1
		i -= 1
	return gone

# A man leaves the squad: if he was in the eleven, the best bench man in his place takes it.
func _drop(i: int) -> bool:
	var sq: Array = d["squad"]
	var xi: Array = d["xi"]
	var slot := xi.find(i)
	if slot >= 0:
		var best := -1
		for k in sq.size():
			if xi.has(k) or k == i or int(sq[k].get("ct", 1)) <= 0:
				continue
			var sc := ovr_of(sq[k]) + (20 if str(sq[k]["pos"]) == str(sq[i]["pos"]) else 0)
			if best < 0 or sc > ovr_of(sq[best]) + (20 if str(sq[best]["pos"]) == str(sq[i]["pos"]) else 0):
				best = k
		if best < 0:
			return false
		xi[slot] = best
	sq.remove_at(i)
	var nx := []
	for x in xi:
		nx.append(int(x) - 1 if int(x) > i else int(x))
	d["xi"] = nx
	return true

# ---- buildings: ask the board
func fac_build_cost(k: String) -> int:
	if fac(k) >= FAC_MAX:
		return 0
	return int(round(FAC_COST[fac(k) - 1] * pay_k(lg()) * 0.6 / 5.0)) * 5

func fac_need(k: String) -> int:
	return 45 + 8 * fac(k)

func fac_ask(k: String) -> String:
	money_init()
	if fac(k) >= FAC_MAX:
		return "IT IS ALREADY THE BEST THERE IS."
	var fb: Dictionary = d.get("fbuild", {})
	if not fb.is_empty():
		return "THE BOARD IS ALREADY BUILDING. ONE THING AT A TIME."
	if int(d.get("freq", 0)) == int(d["season"]):
		return "YOU HAVE ASKED THE BOARD THIS SEASON. ASK AGAIN NEXT SEASON."
	var need := fac_need(k)
	if conf() < need:
		d["freq"] = int(d["season"])
		save()
		return "THE BOARD SAYS NO: THEY WANT MORE FAITH IN YOU FIRST (CONFIDENCE %d, THEY WANT %d)." % [conf(), need]
	var cost := fac_build_cost(k)
	if int(d["coins"]) < cost:
		return "THE BOARD SAYS YES, BUT %s MUST COME FROM YOUR TRANSFER BUDGET." % money(cost)
	d["coins"] = int(d["coins"]) - cost
	d["fbuild"] = {"k": k, "left": FAC_BUILD}
	d["freq"] = int(d["season"])
	save()
	return "THE BOARD SAYS YES! %s FROM YOUR BUDGET. READY IN %d MATCHES." % [money(cost), FAC_BUILD]

func _fac_tick(lines: Array) -> void:
	var fb: Dictionary = d.get("fbuild", {})
	if fb.is_empty():
		return
	fb["left"] = int(fb["left"]) - 1
	if int(fb["left"]) <= 0:
		var k := str(fb["k"])
		if not d.has("fac"):
			d["fac"] = {}
		d["fac"][k] = fac(k) + 1
		d.erase("fbuild")
		lines.append("THE NEW %s IS READY: LEVEL %d" % [{"stadium": "STADIUM", "training": "TRAINING GROUND", "youth": "YOUTH ACADEMY"}.get(k, k.to_upper()), fac(k)])
	else:
		d["fbuild"] = fb

# The career grows players by itself, as in FIFA: a full bar makes him better where his position needs it.
func _grow_auto(pl: Dictionary, rng: RandomNumberGenerator, lines: Array) -> void:
	var got := []
	while (int(pl["xp"]) >= 100 or int(pl.get("tp", 0)) > 0) and ovr_of(pl) < int(pl["pot"]):
		if int(pl.get("tp", 0)) > 0:
			pl["tp"] = int(pl["tp"]) - 1
		else:
			pl["xp"] = int(pl["xp"]) - 100
		var gk := _grow_pick(pl, rng)
		pl[gk] = mini(int(pl[gk]) + 1, 97)
		got.append(STAT_NAMES[STAT_KEYS.find(gk)])
	if not got.is_empty():
		lines.append("%s  +1 %s" % [str(pl["n"]).to_upper(), got[0]] if got.size() == 1 else "%s  +%d" % [str(pl["n"]).to_upper(), got.size()])

# ---------------------------------------------------------------- mood and training (the career only)
# Every man has a mood (pl["mo"], 0-100) and a role he expects from his level in the squad. Playing makes him
# happy, sitting out when he expects to play makes him unhappy. Mood changes how well he plays (a little), and an
# unhappy man wants more money to stay and in the end asks to leave.
# The team trains between matches: a focus (what the players work on) and how hard (more growth, worse mood).
const ROLE_NAMES := ["CRUCIAL", "IMPORTANT", "ROTATION", "SPORADIC", "PROSPECT"]
const ROLE_WANT := ["WANTS TO PLAY EVERY MATCH", "WANTS TO START", "WANTS SOME MATCHES", "HAPPY TO WAIT", "HERE TO LEARN"]
const ROLE_LOSS := [6, 4, 2, 0, 0] # mood lost for a match he sits out
const FOCI := {"balanced": ["BALANCED", "", "A bit of everything."], "attack": ["ATTACK", "sho", "Finishing and movement: the forwards and midfielders gain shooting."],
	"passing": ["PASSING", "pas", "Possession and vision: passing grows."], "defence": ["DEFENCE", "dfn", "Shape and tackling: defending grows."],
	"fitness": ["FITNESS", "pac", "Running and strength: pace grows."], "rest": ["REST", "", "No hard work: little growth, better mood."]}
const FOCUS_ORDER := ["balanced", "attack", "passing", "defence", "fitness", "rest"]
const INTENS := [["LIGHT", 0.75, 1], ["NORMAL", 1.0, 0], ["HARD", 1.35, -1]] # name, growth, mood a match

func plan() -> Dictionary:
	var p: Dictionary = d.get("plan", {})
	if not p.has("f"):
		p = {"f": "balanced", "i": 1}
	return p

func set_plan(f: String, i: int) -> void:
	var p := plan()
	if f != "" and FOCI.has(f):
		p["f"] = f
	if i >= 0:
		p["i"] = clampi(i, 0, 2)
	d["plan"] = p
	save()

# how fast he grows: the plan, how hard, and his age (young men grow fast, old men slowly)
func train_k(pl: Dictionary) -> float:
	var p := plan()
	var k: float = float(INTENS[int(p["i"])][1])
	if str(p["f"]) == "rest":
		k *= 0.5
	var age := int(pl["age"])
	k *= 1.4 if age <= 21 else (1.2 if age <= 24 else (1.0 if age <= 28 else (0.8 if age <= 31 else 0.5)))
	return k

# what grows: his own focus first, then the team's focus, then what his position needs
func _grow_pick(pl: Dictionary, rng: RandomNumberGenerator) -> String:
	var tf := str(pl.get("tf", ""))
	if STAT_KEYS.has(tf) and rng.randf() < 0.6:
		return tf
	var ff := str(FOCI[str(plan()["f"])][1])
	if ff != "" and rng.randf() < 0.4:
		return ff
	return _grow_key(pl, rng)

func set_focus(i: int) -> void:
	var sq: Array = d["squad"]
	if i < 0 or i >= sq.size():
		return
	var order := ["", "pac", "sho", "pas", "dfn"]
	var cur := order.find(str(sq[i].get("tf", "")))
	sq[i]["tf"] = order[(maxi(cur, 0) + 1) % order.size()]
	save()

static func focus_name(tf: String) -> String:
	var k := STAT_KEYS.find(tf)
	return STAT_NAMES[k] if k >= 0 else "AUTO"

# the role each man expects, from where he stands in the squad
func roles() -> Dictionary:
	var sq: Array = d["squad"]
	var idx := []
	for i in sq.size():
		idx.append(i)
	idx.sort_custom(func(a, b): return ovr_of(sq[a]) > ovr_of(sq[b]))
	var out := {}
	for r in idx.size():
		var i: int = idx[r]
		var ro := 0 if r < 4 else (1 if r < 11 else (2 if r < 15 else 3))
		if ro >= 2 and int(sq[i]["age"]) <= 20:
			ro = 4
		out[i] = ro
	return out

static func mood_name(m: int) -> String:
	return "VERY HAPPY" if m >= 80 else ("HAPPY" if m >= 60 else ("OKAY" if m >= 40 else ("UNHAPPY" if m >= 25 else "ANGRY")))

# a happy man plays a little better, an angry one a lot worse
func mood_off(pl: Dictionary) -> int:
	if not eur:
		return 0
	var m := int(pl.get("mo", 65))
	return 2 if m >= 80 else (1 if m >= 60 else (0 if m >= 40 else (-2 if m >= 25 else -4)))

func _after_match(played: Array, won: bool, lines: Array, rng: RandomNumberGenerator) -> void:
	var sq: Array = d["squad"]
	var ro := roles()
	var p := plan()
	var pm: int = int(INTENS[int(p["i"])][2]) + (2 if str(p["f"]) == "rest" else 0)
	var pl_set := []
	for x in played:
		pl_set.append(int(x))
	for i in sq.size():
		var pl: Dictionary = sq[i]
		var r: int = int(ro.get(i, 2))
		var m0 := int(pl.get("mo", 65))
		var m := m0 + pm + (1 if won else 0)
		# time softens everything: a mood drifts back a little towards normal every match
		m += int(round((65 - m0) * 0.08))
		if pl_set.has(i):
			m += 2 if r <= 1 else 3
		else:
			m -= ROLE_LOSS[r]
			# the men who did not play train: they grow too, slower
			pl["xp"] = int(pl["xp"]) + int(round(10.0 * train_k(pl)))
			_grow_auto(pl, rng, lines)
			if int(pl["xp"]) > 100:
				pl["xp"] = 100
		m = clampi(m, 5, 100)
		pl["mo"] = m
		var nm := str(pl["n"]).to_upper()
		if m0 >= 35 and m < 35:
			lines.append("%s IS UNHAPPY: HE %s" % [nm, ROLE_WANT[r]])
		if m < 20 and not pl.has("tr"):
			pl["tr"] = true
			lines.append("%s HAS ASKED TO LEAVE THE CLUB" % nm)
		elif m >= 45 and pl.has("tr"):
			pl.erase("tr")
			lines.append("%s IS HAPPY AGAIN AND WANTS TO STAY" % nm)

func _decline(pl: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for k in mini(int(pl["age"]) - 30, 3):
		var key: String = "pac" if rng.randf() < 0.5 else STAT_KEYS[rng.randi() % 4]
		pl[key] = maxi(int(pl[key]) - 1, 20)
	pl["pot"] = mini(int(pl["pot"]), ovr_of(pl))
