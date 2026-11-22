extends RefCounted
# Career: your club in the world of ClubDB (England's four leagues, Denmark's two). Holds the save, the leagues,
# the fixtures, the table, your squad and the other clubs' squads.
const ClubDB := preload("res://clubdb.gd")
const Names := preload("res://names.gd")
const FIRST := 8 # world indices below this are the quick-match clubs

var key := "bb3d-career" # localStorage key (native: user://<key>.json); the cup mode keeps its own
# A keeper's four numbers are keeper skills, like FIFA: diving, handling, kicking and reflexes (they sit in the
# same four slots as pace, shooting, passing and defending, so every screen and save keeps working).
const ROLE_BASE := {"GK": [72, 70, 60, 74], "DF": [68, 46, 64, 76], "MF": [70, 66, 77, 64], "FW": [79, 77, 66, 42]}
const SQUAD_ROLES := ["GK", "DF", "DF", "DF", "DF", "MF", "MF", "MF", "FW", "FW", "FW", "GK", "DF", "MF", "MF", "FW"]
const SQUAD_NUMS := [1, 3, 4, 5, 2, 8, 6, 10, 11, 9, 7, 12, 14, 15, 16, 17]
const STAT_NAMES := ["PACE", "SHOOTING", "PASSING", "DEFENDING"]
const STAT_KEYS := ["pac", "sho", "pas", "dfn"]
const GK_NAMES := ["DIVING", "HANDLING", "KICKING", "REFLEXES"]
const STAT_SHORT := ["PAC", "SHO", "PAS", "DEF"]
const GK_SHORT := ["DIV", "HAN", "KIC", "REF"]

static func stat_name(pos: String, i: int) -> String:
	return (GK_NAMES if pos == "GK" else STAT_NAMES)[clampi(i, 0, 3)]

static func stat_short(pos: String, i: int) -> String:
	return (GK_SHORT if pos == "GK" else STAT_SHORT)[clampi(i, 0, 3)]

# Saves from before keepers had their own stats: a keeper's pace and shooting become diving and handling,
# set close to his reflexes, so his rating stays about what it was.
static func gk_fix(v) -> void:
	if v is Dictionary:
		if str(v.get("pos", "")) == "GK" and v.has("pac") and v.has("sho") and v.has("dfn"):
			var r := int(v["dfn"])
			v["pac"] = clampi(r - 3, 30, 97)
			v["sho"] = clampi(r - 2, 30, 97)
		for k in v.keys():
			gk_fix(v[k])
	elif v is Array:
		for x in v:
			gk_fix(x)

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
			_world_fix()
			if not d.has("on"):
				# a save from before the career was a choice: it is a running career
				d["on"] = true
			if not d.has("gkv"):
				gk_fix(d)
				d["gkv"] = 1
				save()
			if not d.has("nmv"):
				_names_fix()
				d["nmv"] = 1
				save()

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
	d["gkv"] = 1
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
		"GK": return int(round(p["dfn"] * 0.35 + p["pac"] * 0.3 + p["sho"] * 0.25 + p["pas"] * 0.1))
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
				if pass_n == 0 and not plays(d["squad"][i], str(roles[s])):
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
	eu_start(_eu_quals_by_rating(), _eu2_quals_by_rating())
	world_tick([])
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
	# a league with a split (Denmark) plays more rounds after it: the halves meet again among themselves
	var lr: int = (d["fix"] as Array).size()
	var sp := int(league().get("sp", 0))
	if sp > 0 and n == 12:
		lr += 5 if str(d.get("slen", "full")) == "short" else 10
	d["lr"] = lr
	for k in ["spl", "po", "pow", "hh", "final"]:
		d.erase(k)
	var table := {}
	for c in ids0:
		table[str(c)] = {"p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0}
	d["table"] = table
	d["round"] = 0
	d["last"] = []
	d["myres"] = {}
	d["day"] = -4 # pre-season: a few days before the first match
	d["cur"] = -4
	d["gs"] = {}
	d["mg"] = {}
	d["mp"] = {}
	d["mon"] = -1
	d["aw"] = []

# the league rounds of the season (the split rounds of a league like Denmark's count, the play-offs do not)
func rounds_total() -> int:
	return int(d.get("lr", (d["fix"] as Array).size()))

# over when every round is played: the league, a split and any play-off you are in
func season_over() -> bool:
	return int(d["round"]) >= maxi((d["fix"] as Array).size(), rounds_total())

# a play-off round of yours (played after the league rounds)
func po_round(r := -1) -> bool:
	return (r if r >= 0 else int(d["round"])) >= rounds_total()

# the name of a round on the calendar and the match card
func round_name(r: int) -> String:
	if po_round(r):
		var nm: Dictionary = (d.get("po", {}) as Dictionary).get("nm", {})
		return str(nm.get(str(r), "Play-off")).capitalize()
	return "Round %d" % (r + 1)

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

# A save from before the new leagues: they join the world as they are at the start of the game. Their clubs that
# played only in Europe before keep their place in the world list, so nothing in the save points at a wrong club.
func _world_fix() -> void:
	if not d.has("leagues"):
		return
	var lgs: Array = d["leagues"]
	if lgs.size() >= ClubDB.LEAGUES.size():
		return
	var st := ClubDB.start_leagues(FIRST)
	for li in range(lgs.size(), ClubDB.LEAGUES.size()):
		lgs.append((st[li] as Array).duplicate())
	d["leagues"] = lgs
	d.erase("final")

# the clubs in a league now (your league when li is left out)
func ids(li := -1) -> Array:
	_world_fix()
	var out := []
	for x in (d["leagues"] as Array)[lg() if li < 0 else li]:
		out.append(int(x))
	return out

# ---- rivals and derbies: every club has one rival, from the same town if there is one, else the club
# in its league closest to it. A derby is a big day: a full stadium, the board and the fans care, the press ask.
func _town(c: int) -> String:
	var ws: PackedStringArray = str(cname(c)).split(" ")
	return " ".join(ws.slice(0, maxi(ws.size() - 1, 1)))

func rival_of(c: int) -> int:
	if c < FIRST or c >= W.size():
		return -1
	var rv: Dictionary = d.get("rv", {})
	if rv.has(str(c)):
		return int(rv[str(c)])
	var li := league_of(c)
	var ctry := str(ClubDB.LEAGUES[li]["c"]) if li >= 0 else ""
	var best := -1
	var bs := 1e9
	for x in range(FIRST, W.size()):
		if x == c:
			continue
		var lx := league_of(x)
		if lx < 0 or str(ClubDB.LEAGUES[lx]["c"]) != ctry:
			continue
		var s := 0.0
		if _town(x) == _town(c):
			s -= 1000.0
		if lx != li:
			s += 200.0 + absi(lx - li) * 50.0
		s += absf(float(rating(x) - rating(c))) + float(absi(hash(str(c * 31 + x)) % 7)) * 0.1
		if s < bs:
			bs = s
			best = x
	rv[str(c)] = best
	d["rv"] = rv
	return best

func derby(opp: int) -> bool:
	var me := int(d["club"])
	return opp >= 0 and rival_of(me) == opp

func derby_rec() -> Dictionary:
	return d.get("drb", {"w": 0, "d": 0, "l": 0})

# after a derby: the record, the gate, the board and the dressing room
func _derby_after(mine: int, theirs: int, opp: int, lines: Array) -> void:
	if not derby(opp):
		return
	var r := derby_rec()
	var k := "w" if mine > theirs else ("d" if mine == theirs else "l")
	r[k] = int(r.get(k, 0)) + 1
	d["drb"] = r
	var b := board()
	if b.has("trk"):
		var trk: Dictionary = b["trk"]
		trk["dp"] = int(trk.get("dp", 0)) + 1
		if mine > theirs:
			trk["derby"] = int(trk.get("derby", 0)) + 1
	var on := str(cname(opp)).capitalize()
	if mine > theirs:
		_conf_add(4)
		_team_mood(3)
		lines.append("DERBY WON! THE TOWN IS YOURS. THE BOARD +4")
	elif mine < theirs:
		_conf_add(-4)
		_team_mood(-2)
		lines.append("DERBY LOST TO %s. THE FANS ARE FURIOUS. THE BOARD -4" % on.to_upper())
	else:
		lines.append("A DERBY DRAW WITH %s" % on.to_upper())

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
	return int(ClubDB.LEAGUES[clampi(li, 0, ClubDB.LEAGUES.size() - 1)]["sc"])

# how much a league's matches pay, against the bottom league
static func pay_k(li: int) -> float:
	return float(ClubDB.LEAGUES[clampi(li, 0, ClubDB.LEAGUES.size() - 1)]["pk"])

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
	# the games between two clubs, for leagues where they split clubs level on points
	var hh: Dictionary = d.get("hh", {})
	var hk := "%d:%d" % [mini(a, b), maxi(a, b)]
	var hv: Array = hh.get(hk, [0, 0])
	hv = [int(hv[0]) + (ga if a < b else gb), int(hv[1]) + (gb if a < b else ga)]
	hh[hk] = hv
	d["hh"] = hh
	ta["fm"] = (str(ta.get("fm", "")) + ("W" if ga > gb else ("L" if ga < gb else "D"))).right(5)
	tb["fm"] = (str(tb.get("fm", "")) + ("W" if gb > ga else ("L" if gb < ga else "D"))).right(5)

# Books your result, plays the rest of the round, pays out coins and grows the players who played.
# Returns lines for the full-time screen.
func finish_match(mine: int, theirs: int, scorers: Array, played: Array = [], won_tie := -1) -> Array:
	var fit0 := _fit_pre()
	var me: int = int(d["club"])
	var was_home: bool = next_match()[1]
	var opp_c: int = next_match()[0]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var last := []
	var por := po_round()
	for m in d["fix"][int(d["round"])]:
		var a: int = int(m[0])
		var b: int = int(m[1])
		var ga := 0
		var gb := 0
		if por:
			# a play-off leg: no points, it goes to the play-off's own book
			last.append([a, b, mine if a == me else theirs, theirs if a == me else mine])
			continue
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
		_month_pts(a, b, ga, gb)
		if a != me:
			for g in ga:
				_goal_cpu(a, rng)
		if b != me:
			for g in gb:
				_goal_cpu(b, rng)
		last.append([a, b, ga, gb])
	d["last"] = last
	if not d.has("myres"):
		d["myres"] = {}
	d["myres"][str(int(d["round"]))] = [mine, theirs]
	d["day"] = lg_day(int(d["round"]))
	d["cur"] = int(d["day"])
	d["round"] = int(d["round"]) + 1
	var po_lines := []
	if por:
		_po_leg(mine, theirs, won_tie, po_lines)
	_after_round(po_lines)
	var stt: Dictionary = stats()
	stt["p"] = int(stt["p"]) + 1
	stt["w" if mine > theirs else ("d" if mine == theirs else "l")] = int(stt["w" if mine > theirs else ("d" if mine == theirs else "l")]) + 1
	stt["gf"] = int(stt["gf"]) + mine
	stt["ga"] = int(stt["ga"]) + theirs
	d["st"] = stt
	_rec_result(mine, theirs, opp_c, false)
	var lines := po_lines
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
	_derby_after(mine, theirs, opp_c, lines)
	if was_home:
		# the gate: a bigger stadium and a club near the top bring more people in
		var gate := int(round((fac("stadium") * 9 + (6 if rank_of(me) <= 3 else 0)) * pay_k(lg())))
		if eur:
			gate = int(round(gate * 0.5))
		if derby(opp_c):
			# derby day: every seat sold
			gate = int(round(gate * 1.6))
		d["coins"] = int(d["coins"]) + gate
		lines.append("+%s FROM THE GATE" % money(gate))
	var was_on := []
	for i in (played if not played.is_empty() else d["xi"]):
		was_on.append(int(i))
	for i in (d["squad"] as Array).size():
		if not was_on.has(i):
			_form_rest(d["squad"][i])
	for i in (played if not played.is_empty() else d["xi"]):
		var pl: Dictionary = d["squad"][int(i)]
		pl["apps"] = int(pl["apps"]) + 1
		var xp := int(round((22 + (10 if mine > theirs else 0)) * (1.0 + 0.15 * (fac("training") - 1)) * (train_k(pl) if eur else 1.0)))
		for s in scorers:
			if int(s) == int(i):
				xp += 14
				pl["g"] = int(pl["g"]) + 1
				pl["cg"] = int(pl.get("cg", 0)) + 1
				_goal_add(me, pl)
		pl["ca"] = int(pl.get("ca", 0)) + 1
		var ng := 0
		for s2 in scorers:
			if int(s2) == int(i):
				ng += 1
		_form_add(pl, mine, theirs, ng)
		_rec_player(pl)
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
			_honour("lg", "Champions of %s" % league_name().capitalize())
		_sim_others()
		var mv := my_move()
		if mv < 0:
			_honour("up", "Promoted from %s" % league_name().capitalize())
		_season_awards(lines)
		_rec_season(pos)
		var what := ""
		if mv < 0:
			what = "  PROMOTED TO %s!" % league_name(lg() - 1)
		elif mv > 0:
			what = "  RELEGATED TO %s." % league_name(lg() + 1)
		var pw: Dictionary = (d.get("po", {}) as Dictionary)
		if pw.has("li") and bool(pw.get("in", false)):
			what = ("  YOU WON THE PLAY-OFF." if int(pw.get("win", -1)) == me else "  THE PLAY-OFF WAS LOST.") + what
		if pos == 1:
			what = ("  CHAMPIONS OF %s!" % league_name()) + what
		d["move"] = mv
		d["note"] = "%s, SEASON %d: YOU FINISHED %s.%s  +%s" % [league_name(), int(d["season"]), ordinal(pos), what, money(prize)]
		_board_review()
		lines.append("SEASON OVER: THE BOARD'S GRADE IS %s" % str(review().get("grade", "C")))
	_fac_tick(lines)
	if eur:
		_after_match(played if not played.is_empty() else d["xi"], mine > theirs, lines, rng)
	_rt_tick(d["xi"], lines)
	_fit_post(fit0, played, lines, rng)
	world_tick(lines)
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
	var w: Array = {"GK": [3, 3, 1, 4], "DF": [2, 0, 2, 5], "MF": [2, 2, 5, 1], "FW": [3, 5, 2, 0]}[str(pl["pos"])]
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
	# a tournament still running when you go on: the rest of it is played without you watching
	var ng := 0
	while nat_due() and ng < 8:
		var nr := nat_sim()
		nat_finish(int(nr[0]), int(nr[1]), randf() < 0.5)
		ng += 1
	money_init()
	var gone := _contracts_end()
	var mv0 := int(d.get("move", 0))
	var quals := _eu_quals_final()
	var quals2 := _eu2_quals_final(bool(d.get("cup", {}).get("won", false)))
	d["season"] = int(d["season"]) + 1
	_move_clubs()
	d["lg"] = league_of(int(d["club"]))
	d["move"] = 0
	d["note"] = ""
	for pl in d["squad"]:
		pl["age"] = int(pl["age"]) + 1
		# a summer off: everyone starts the new season fit
		pl.erase("inj")
		pl.erase("injn")
		pl["cond"] = 100
		pl["cday"] = -4
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
	eu_start(quals, quals2)
	_nat_season()
	d["wlast"] = -999
	world_tick([])
	save()

# The end of the season everywhere else: every other league plays its season in a blink, with its own rules
# (a split, head-to-head), and every play-off you are not in is played. Done once, when your league ends.
func _sim_others() -> void:
	if d.has("final") and (d["final"] as Array).size() == ClubDB.LEAGUES.size():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var fin := []
	var fp := []
	for li in ClubDB.LEAGUES.size():
		if li == lg():
			fin.append(order())
			var tp := {}
			for c in ids():
				tp[str(c)] = int(d["table"][str(c)]["pts"])
			fp.append(tp)
			continue
		var res := _sim_league(ids(li), rng, ClubDB.LEAGUES[li])
		fin.append(res[0])
		fp.append(res[1])
	d["final"] = fin
	d["fpts"] = fp
	# the play-offs of every other league (yours is played on the pitch)
	var pw: Dictionary = d.get("pow", {})
	for li in ClubDB.LEAGUES.size():
		if str(ClubDB.LEAGUES[li].get("po", "")) == "" or pw.has(str(li)):
			continue
		var po := _po_make(li)
		if po.is_empty():
			continue
		while not bool(po["done"]):
			_po_step(po, rng)
		pw[str(li)] = int(po["win"])
	d["pow"] = pw

# a league played in a blink: home and away, then the split if the league has one. Returns [order, points]
func _sim_league(cl: Array, rng: RandomNumberGenerator, L: Dictionary) -> Array:
	var rows := {}
	var hh := {}
	for c in cl:
		rows[c] = [0, 0, 0]
	_sim_rr(cl, rows, hh, rng)
	var ord := _rank(cl, rows, hh, str(L.get("tb", "gd")))
	if int(L.get("sp", 0)) > 0 and cl.size() == 12:
		var top: Array = ord.slice(0, 6)
		var bot: Array = ord.slice(6)
		_sim_rr(top, rows, hh, rng)
		_sim_rr(bot, rows, hh, rng)
		ord = _rank(top, rows, hh, str(L.get("tb", "gd"))) + _rank(bot, rows, hh, str(L.get("tb", "gd")))
	var pts := {}
	for c in cl:
		pts[str(c)] = int(rows[c][0])
	return [ord, pts]

func _sim_rr(cl: Array, rows: Dictionary, hh: Dictionary, rng: RandomNumberGenerator) -> void:
	for i in cl.size():
		for j in cl.size():
			if i == j:
				continue
			var a: int = cl[i]
			var b: int = cl[j]
			var df := (float(rating(a)) - float(rating(b))) / 14.0
			var ga := _poisson(rng, 1.35 * exp(df) + 0.15)
			var gb := _poisson(rng, 1.35 * exp(-df))
			rows[a][0] += 3 if ga > gb else (1 if ga == gb else 0)
			rows[b][0] += 3 if gb > ga else (1 if ga == gb else 0)
			rows[a][1] += ga
			rows[a][2] += gb
			rows[b][1] += gb
			rows[b][2] += ga
			var hk := "%d:%d" % [mini(a, b), maxi(a, b)]
			var hv: Array = hh.get(hk, [0, 0])
			hh[hk] = [int(hv[0]) + (ga if a < b else gb), int(hv[1]) + (gb if a < b else ga)]

# Table order. rows = {club: [points, for, against]}. Level on points: "gd" = goal difference then goals scored;
# "h2h" (Spain, Italy) = first the games between the clubs that are level (points, then goal difference in them).
func _rank(cl: Array, rows: Dictionary, hh: Dictionary, tb: String) -> Array:
	var ord := cl.duplicate()
	ord.sort_custom(func(x, y):
		var kx := [int(rows[x][0]), int(rows[x][1]) - int(rows[x][2]), int(rows[x][1])]
		var ky := [int(rows[y][0]), int(rows[y][1]) - int(rows[y][2]), int(rows[y][1])]
		return kx > ky if kx != ky else x < y)
	if tb != "h2h":
		return ord
	var out := []
	var i := 0
	while i < ord.size():
		var j := i
		while j + 1 < ord.size() and int(rows[ord[j + 1]][0]) == int(rows[ord[i]][0]):
			j += 1
		var grp: Array = ord.slice(i, j + 1)
		if grp.size() > 1:
			var mini_t := {}
			for c in grp:
				mini_t[c] = [0, 0]
			for x in grp.size():
				for y in range(x + 1, grp.size()):
					var a: int = grp[x]
					var b: int = grp[y]
					var hv: Array = hh.get("%d:%d" % [mini(a, b), maxi(a, b)], [0, 0])
					var ga: int = int(hv[0]) if a < b else int(hv[1])
					var gb: int = int(hv[1]) if a < b else int(hv[0])
					# the goals over both games decide it, as the points over both games mostly do
					mini_t[a][0] += 3 if ga > gb else (1 if ga == gb else 0)
					mini_t[b][0] += 3 if gb > ga else (1 if ga == gb else 0)
					mini_t[a][1] += ga - gb
					mini_t[b][1] += gb - ga
			grp.sort_custom(func(x, y):
				var kx := [int(mini_t[x][0]), int(mini_t[x][1]), int(rows[x][1]) - int(rows[x][2]), int(rows[x][1])]
				var ky := [int(mini_t[y][0]), int(mini_t[y][1]), int(rows[y][1]) - int(rows[y][2]), int(rows[y][1])]
				return kx > ky if kx != ky else x < y)
		out.append_array(grp)
		i = j + 1
	return out

# After each of your rounds: the split comes when its round is reached, and when the league is over the
# play-offs you are in are drawn (your games are added to your season, the others are played in a blink).
func _after_round(lines: Array) -> void:
	var r := int(d["round"])
	var nfix: int = (d["fix"] as Array).size()
	if r == nfix and nfix < rounds_total() and not d.has("spl"):
		_split_now(lines)
		return
	if r == rounds_total() and not d.has("po"):
		_sim_others()
		_po_mine(lines)

# Denmark: after the first rounds the top six play for the title, the bottom six against the drop. Points stay.
func _split_now(lines: Array) -> void:
	var ord := order()
	var top: Array = ord.slice(0, 6)
	var bot: Array = ord.slice(6)
	d["spl"] = top
	var short := str(d.get("slen", "full")) == "short"
	var ra := _rr_rounds(top, short)
	var rb := _rr_rounds(bot, short)
	for k in ra.size():
		(d["fix"] as Array).append((ra[k] as Array) + (rb[k] as Array))
	var me := int(d["club"])
	if top.has(me):
		lines.append("THE SPLIT: YOU ARE IN THE CHAMPIONSHIP GROUP. THE TOP SIX PLAY FOR THE TITLE")
		_mail("split", "The split: the championship group", "The league has split in two. You finished in the top six, so the last rounds are against the other five at the top. The points you have stay with you: win the group and you are champions.")
	else:
		lines.append("THE SPLIT: YOU ARE IN THE RELEGATION GROUP. THE BOTTOM SIX FIGHT TO STAY UP")
		_mail("split", "The split: the relegation group", "The league has split in two. You finished in the bottom six, so the last rounds are against the other five down there. The points you have stay with you: the bottom of the group goes down.")

# a round robin of the clubs: [rounds of [home, away]], each pair once (short) or twice
func _rr_rounds(cl: Array, short: bool) -> Array:
	var ids2 := cl.duplicate()
	var n := ids2.size()
	var rounds := []
	for r in n - 1:
		var rd := []
		for i in n / 2:
			var a: int = ids2[i]
			var b: int = ids2[n - 1 - i]
			rd.append([a, b] if ((i % 2 == 0) if i > 0 else (r % 2 == 0)) else [b, a])
		rounds.append(rd)
		ids2.insert(1, ids2.pop_back())
	if short:
		return rounds
	var back := []
	for rd in rounds:
		var rd2 := []
		for m in rd:
			rd2.append([m[1], m[0]])
		back.append(rd2)
	return rounds + back

# ---------------------------------------------------------------- the play-offs
# Each league's own play-off, as in the real game (ClubDB po). A plan is a list of rounds; a tie names its two
# clubs by their place among the play-off clubs (1 = the highest of them, e.g. 3rd in England's second league), "w0" = the winner of the first tie in the round before, "T" = the
# top league's relegation play-off club. legs: 1 or 2. lvl: what settles a level tie: "pen" extra time and
# penalties, "hs" the club that finished higher goes through (Italy, Spain), "ets" extra time, then the higher one.
const PO_PLANS := {
	"eng": [{"ties": [[1, 4], [2, 3]], "legs": 2, "lvl": "pen", "nm": "PLAY-OFF SEMI-FINAL"}, {"ties": [["w0", "w1"]], "legs": 1, "lvl": "pen", "nm": "PLAY-OFF FINAL", "neutral": true}],
	"esp": [{"ties": [[1, 4], [2, 3]], "legs": 2, "lvl": "hs", "nm": "PLAY-OFF SEMI-FINAL"}, {"ties": [["w0", "w1"]], "legs": 2, "lvl": "hs", "nm": "PLAY-OFF FINAL"}],
	"ita": [{"ties": [[3, 6], [4, 5]], "legs": 1, "lvl": "ets", "nm": "PLAY-OFF FIRST ROUND"}, {"ties": [[1, "w1"], [2, "w0"]], "legs": 2, "lvl": "hs", "nm": "PLAY-OFF SEMI-FINAL"}, {"ties": [["w0", "w1"]], "legs": 2, "lvl": "hs", "nm": "PLAY-OFF FINAL"}],
	"fra": [{"ties": [[2, 3]], "legs": 1, "lvl": "pen", "nm": "PLAY-OFF FIRST ROUND"}, {"ties": [[1, "w0"]], "legs": 1, "lvl": "pen", "nm": "PLAY-OFF SECOND ROUND"}, {"ties": [["T", "w0"]], "legs": 2, "lvl": "pen", "nm": "PLAY-OFF FINAL"}],
	"ger": [{"ties": [["T", 1]], "legs": 2, "lvl": "pen", "nm": "RELEGATION PLAY-OFF"}],
}

# a new play-off for league li (the lower league) from the final tables; {} when there is none this season
func _po_make(li: int) -> Dictionary:
	var L: Dictionary = ClubDB.LEAGUES[li]
	var kind := str(L.get("po", ""))
	if kind == "" or not PO_PLANS.has(kind):
		return {}
	var fin: Array = d.get("final", [])
	if fin.size() != ClubDB.LEAGUES.size():
		return {}
	var ord: Array = fin[li]
	var seeds := {}
	for pos in range(int(L["pf"][0]), int(L["pf"][1]) + 1):
		if pos - 1 < ord.size():
			seeds[str(pos - int(L["pf"][0]) + 1)] = int(ord[pos - 1])
	var top := -1
	if li > 0 and str(ClubDB.LEAGUES[li - 1]["c"]) == str(L["c"]) and int(ClubDB.LEAGUES[li - 1].get("rp", 0)) > 0:
		var rp := int(ClubDB.LEAGUES[li - 1]["rp"])
		top = int((fin[li - 1] as Array)[rp - 1])
		seeds["T"] = top
	var po := {"li": li, "k": kind, "seeds": seeds, "r": 0, "w": [], "done": false, "win": -1, "log": [], "top": top}
	# Italy: a third place 15 points or more clear of fourth goes up without a play-off
	if kind == "ita":
		var fp: Array = d.get("fpts", [])
		if fp.size() > li:
			var p3 := int((fp[li] as Dictionary).get(str(int(ord[2])), 0))
			var p4 := int((fp[li] as Dictionary).get(str(int(ord[3])), 0))
			if p3 - p4 >= 15:
				po["done"] = true
				po["win"] = int(ord[2])
				po["clear"] = true
	return po

# a club's place for "the higher club": the top league's club is above them all
func _po_seed(po: Dictionary, c: int) -> int:
	for k in po["seeds"]:
		if int(po["seeds"][k]) == c:
			return 0 if str(k) == "T" else int(k)
	return 99

# the ties of the round the play-off is in: [[a, b], ...] with a the higher club
func _po_ties(po: Dictionary) -> Array:
	var plan: Array = PO_PLANS[str(po["k"])]
	var rd: Dictionary = plan[int(po["r"])]
	var out := []
	for t in rd["ties"]:
		var pair := []
		for x in t:
			if x is String and str(x).begins_with("w"):
				pair.append(int(po["w"][int(str(x).substr(1))]))
			else:
				pair.append(int(po["seeds"].get(str(x), -1)))
		if _po_seed(po, int(pair[1])) < _po_seed(po, int(pair[0])):
			pair = [pair[1], pair[0]]
		out.append(pair)
	return out

# who goes through a tie on goals ga-gb for the higher club a (over both legs), penalties when needed
func _po_through(po: Dictionary, a: int, b: int, ga: int, gb: int, rng: RandomNumberGenerator, pen_a := -1) -> int:
	if ga != gb:
		return a if ga > gb else b
	var rd: Dictionary = PO_PLANS[str(po["k"])][int(po["r"])]
	if str(rd["lvl"]) == "hs" or str(rd["lvl"]) == "ets":
		return a
	if pen_a >= 0:
		return a if pen_a == 1 else b
	var df := (_strength(a) - _strength(b)) / 30.0
	return a if rng.randf() < 0.5 + df else b

# plays the round the play-off is in, in a blink (no club of yours in it)
func _po_step(po: Dictionary, rng: RandomNumberGenerator) -> void:
	var plan: Array = PO_PLANS[str(po["k"])]
	var rd: Dictionary = plan[int(po["r"])]
	var w := []
	var lg_ := []
	for t in _po_ties(po):
		var a: int = int(t[0])
		var b: int = int(t[1])
		var ga := 0
		var gb := 0
		for leg in int(rd["legs"]):
			var df := (_strength(a) - _strength(b)) / 14.0
			ga += _poisson(rng, 1.25 * exp(df))
			gb += _poisson(rng, 1.25 * exp(-df))
		var win := _po_through(po, a, b, ga, gb, rng)
		w.append(win)
		lg_.append([a, b, ga, gb, win])
	(po["log"] as Array).append(lg_)
	po["w"] = w
	po["r"] = int(po["r"]) + 1
	if int(po["r"]) >= plan.size():
		po["done"] = true
		po["win"] = int(w[0])

# When your league is over: are you in a play-off (your own league's, or as the top league's play-off club
# against the league below)? Then your ties are added to the season and the rest is played in a blink.
func _po_mine(lines: Array) -> void:
	var me := int(d["club"])
	var li := -1
	var pos := rank_of(me)
	var L := league()
	if str(L.get("po", "")) != "" and pos >= int(L["pf"][0]) and pos <= int(L["pf"][1]):
		li = lg()
	elif int(L.get("rp", 0)) > 0 and pos == int(L["rp"]) and lg() + 1 < ClubDB.LEAGUES.size() and str(ClubDB.LEAGUES[lg() + 1]["c"]) == str(L["c"]):
		li = lg() + 1
	if li < 0:
		d["po"] = {}
		return
	var po := _po_make(li)
	if po.is_empty() or bool(po["done"]):
		if not po.is_empty():
			(d["pow"] as Dictionary)[str(li)] = int(po["win"])
			if bool(po.get("clear", false)):
				var cn := str(cname(int(po["win"]))).capitalize()
				lines.append("NO PLAY-OFF: %s WERE 15 POINTS CLEAR IN THIRD AND GO UP" % cn.to_upper())
		d["po"] = {}
		return
	po["in"] = true
	po["nm"] = {}
	d["po"] = po
	(d["pow"] as Dictionary).erase(str(li))
	_po_next(lines, true)

# the play-off goes on: rounds without you are played, your next tie (or leg) is added to your season
func _po_next(lines: Array, first := false) -> void:
	var po: Dictionary = d["po"]
	var me := int(d["club"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while not bool(po["done"]):
		var mine := []
		for t in _po_ties(po):
			if int(t[0]) == me or int(t[1]) == me:
				mine = t
		if mine.is_empty():
			_po_step(po, rng)
			continue
		var rd: Dictionary = PO_PLANS[str(po["k"])][int(po["r"])]
		var opp: int = int(mine[1]) if int(mine[0]) == me else int(mine[0])
		var high: bool = int(mine[0]) == me
		# the higher club is at home in a one-off game and in the second leg
		var legs := int(rd["legs"])
		var leg := 1
		var home := high if legs == 1 else not high
		po["cur"] = {"t": mine, "leg": leg, "legs": legs, "agg": [0, 0]}
		(d["fix"] as Array).append([[me, opp] if home else [opp, me]])
		var nm := str(rd["nm"]) + (", FIRST LEG" if legs == 2 else "")
		(po["nm"] as Dictionary)[str((d["fix"] as Array).size() - 1)] = nm
		var cn := str(cname(opp)).capitalize()
		lines.append("%s: %s %s" % [nm, "AT A NEUTRAL GROUND AGAINST" if bool(rd.get("neutral", false)) else ("AT HOME TO" if home else "AWAY AT"), cn.to_upper()])
		if first:
			_mail("po", "You are in the play-off", "%s is next: %s against %s. %s" % [str(rd["nm"]).capitalize(), "two legs" if legs == 2 else "one game", cn, _po_rule_text(str(po["k"]))])
		return
	d["pow"][str(po["li"])] = int(po["win"])

# for the match: your play-off game must end with a winner (the last leg, with penalties as the rule)
func po_need_winner() -> bool:
	var po: Dictionary = d.get("po", {})
	if not po.has("cur") or not po_round():
		return false
	var cur: Dictionary = po["cur"]
	var rd: Dictionary = PO_PLANS[str(po["k"])][int(po["r"])]
	return int(cur["leg"]) == int(cur["legs"]) and str(rd["lvl"]) == "pen"

# a second leg of a play-off tie
func po_leg2() -> bool:
	var po: Dictionary = d.get("po", {})
	return po.has("cur") and po_round() and int(po["cur"]["leg"]) == 2

# the goals so far in this tie (the first leg), as [yours, theirs]
func po_agg() -> Array:
	var po: Dictionary = d.get("po", {})
	if not po.has("cur") or not po_round():
		return [0, 0]
	return [int(po["cur"]["agg"][0]), int(po["cur"]["agg"][1])]

# the play-off for the screens: the name of your next game and the ties so far
func po_info() -> Dictionary:
	var po: Dictionary = d.get("po", {})
	if not po.has("li"):
		return {}
	var rounds := []
	var plan: Array = PO_PLANS[str(po["k"])]
	for i in (po["log"] as Array).size():
		var ts := []
		for t in po["log"][i]:
			ts.append([int(t[0]), int(t[1]), int(t[2]), int(t[3]), int(t[4])])
		rounds.append({"nm": str(plan[i]["nm"]), "ties": ts})
	var nx := ""
	if po_round() and not season_over():
		nx = round_name(int(d["round"]))
	return {"li": int(po["li"]), "k": str(po["k"]), "rounds": rounds, "next": nx, "agg": po_agg(), "done": bool(po["done"]), "win": int(po["win"]), "rule": _po_rule_text(str(po["k"])), "in": bool(po.get("in", false))}

# a league's rules in one line, for the menus
static func rules_text(li: int) -> String:
	var L: Dictionary = ClubDB.LEAGUES[li]
	var bits := []
	if int(L["up"]) > 0:
		bits.append("%d up" % int(L["up"]))
	if str(L.get("po", "")) != "":
		var pf: Array = L["pf"]
		bits.append(("play-off for %s" % ordinal(int(pf[0])).to_lower()) if int(pf[0]) == int(pf[1]) else ("play-off %s-%s" % [ordinal(int(pf[0])).to_lower(), ordinal(int(pf[1])).to_lower()]))
	if int(L["down"]) > 0:
		bits.append("%d down" % int(L["down"]))
	if int(L.get("rp", 0)) > 0:
		bits.append("%s in a relegation play-off" % ordinal(int(L["rp"])).to_lower())
	if int(L.get("sp", 0)) > 0:
		bits.append("splits in two after %d rounds" % int(L["sp"]))
	if str(L.get("tb", "gd")) == "h2h":
		bits.append("level on points: head-to-head")
	if int(L.get("eu", 0)) > 0:
		bits.append("top %d to the Champions Cup" % int(L["eu"]))
	var t := ", ".join(PackedStringArray(bits))
	return t.left(1).to_upper() + t.substr(1)

func _po_rule_text(k: String) -> String:
	return {"eng": "The semi-finals are over two legs, the final is one game at a neutral ground. Level after extra time: penalties.",
		"esp": "Every round is over two legs. Level after extra time: the club that finished higher goes through.",
		"ita": "The first round is one game at the higher club, then two legs. Level: the club that finished higher goes through.",
		"fra": "One game at the higher club each round, then the final over two legs against the top league's club. Level: penalties.",
		"ger": "Two legs between the top league's 16th and the 3rd of the league below. Level after extra time: penalties."}.get(k, "")

# your play-off leg is played: a second leg comes next, or the tie is settled and the play-off goes on
func _po_leg(mine: int, theirs: int, won_tie: int, lines: Array) -> void:
	var po: Dictionary = d.get("po", {})
	if po.is_empty() or not po.has("cur"):
		return
	var me := int(d["club"])
	var cur: Dictionary = po["cur"]
	var t: Array = cur["t"]
	var high: bool = int(t[0]) == me
	var agg: Array = cur["agg"]
	agg = [int(agg[0]) + mine, int(agg[1]) + theirs]
	cur["agg"] = agg
	var opp: int = int(t[1]) if high else int(t[0])
	var rd: Dictionary = PO_PLANS[str(po["k"])][int(po["r"])]
	if int(cur["leg"]) < int(cur["legs"]):
		cur["leg"] = int(cur["leg"]) + 1
		var home2 := high
		(d["fix"] as Array).append([[me, opp] if home2 else [opp, me]])
		(po["nm"] as Dictionary)[str((d["fix"] as Array).size() - 1)] = str(rd["nm"]) + ", SECOND LEG"
		lines.append("FIRST LEG %d-%d. THE SECOND LEG IS %s" % [mine, theirs, "AT HOME" if home2 else "AWAY"])
		return
	# settled: on aggregate, then by the round's own rule (penalties = the shootout you just played)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var ga: int = agg[0] if high else agg[1]
	var gb: int = agg[1] if high else agg[0]
	var pen_a := -1
	if ga == gb and won_tie >= 0:
		pen_a = 1 if ((won_tie == 1) == high) else 0
	var win := _po_through(po, int(t[0]), int(t[1]), ga, gb, rng, pen_a)
	# the other ties of the round
	var w := []
	var lg_ := []
	for t2 in _po_ties(po):
		if int(t2[0]) == int(t[0]) and int(t2[1]) == int(t[1]):
			w.append(win)
			lg_.append([int(t[0]), int(t[1]), ga, gb, win])
			continue
		var a: int = int(t2[0])
		var b: int = int(t2[1])
		var x := 0
		var y := 0
		for leg in int(rd["legs"]):
			var df := (_strength(a) - _strength(b)) / 14.0
			x += _poisson(rng, 1.25 * exp(df))
			y += _poisson(rng, 1.25 * exp(-df))
		var w2 := _po_through(po, a, b, x, y, rng)
		w.append(w2)
		lg_.append([a, b, x, y, w2])
	(po["log"] as Array).append(lg_)
	po["w"] = w
	po.erase("cur")
	po["r"] = int(po["r"]) + 1
	var plan: Array = PO_PLANS[str(po["k"])]
	var last := int(po["r"]) >= plan.size()
	if last:
		po["done"] = true
		po["win"] = int(w[0])
	var agg_t := ("%d-%d ON AGGREGATE" % [agg[0], agg[1]]) if int(cur["legs"]) == 2 else ("%d-%d" % [agg[0], agg[1]])
	if win == me:
		if last:
			var up_t := "PROMOTED!" if int(po["li"]) == lg() else "YOU STAY UP!"
			lines.append("%s WON, %s %s" % [str(rd["nm"]), agg_t, up_t])
		else:
			lines.append("THROUGH, %s: ON TO THE %s" % [agg_t, str(plan[int(po["r"])]["nm"])])
			_po_next(lines)
	else:
		lines.append("OUT OF THE PLAY-OFF, %s%s" % [agg_t, ". RELEGATED." if int(po["li"]) != lg() else ""])
		# the rest is played without you
		while not bool(po["done"]):
			_po_step(po, rng)
	if bool(po["done"]):
		d["pow"][str(po["li"])] = int(po["win"])

# your club's move this summer: -1 up, 1 down, 0 stays
func my_move() -> int:
	var nl := _moves()
	if nl.is_empty():
		return 0
	var me := int(d["club"])
	for li in nl.size():
		if (nl[li] as Array).has(me):
			return signi(li - lg())
	return 0

# Promotion and relegation in every country, by each league's own rules: the straight places, then the play-off
# winners (up from the league below), and the relegation play-off swap (Germany, France).
func _moves() -> Array:
	var fin: Array = d.get("final", [])
	if fin.size() != ClubDB.LEAGUES.size():
		return []
	var pw: Dictionary = d.get("pow", {})
	var lgs := []
	var fi := []
	for li in fin.size():
		var row := []
		for c in fin[li]:
			row.append(int(c))
		fi.append(row)
		lgs.append(row.duplicate())
	fin = fi
	for li in ClubDB.LEAGUES.size() - 1:
		var a: Dictionary = ClubDB.LEAGUES[li]
		var b: Dictionary = ClubDB.LEAGUES[li + 1]
		if str(a["c"]) != str(b["c"]):
			continue
		var fa: Array = fin[li]
		var fb: Array = fin[li + 1]
		var down_cl: Array = fa.slice(fa.size() - int(a["down"]))
		var up_cl: Array = fb.slice(0, int(b["up"]))
		var pwin := int(pw.get(str(li + 1), -1))
		if str(b.get("po", "")) != "" and pwin >= 0:
			if int(a.get("rp", 0)) > 0:
				# the relegation play-off: the lower club takes the top league's place if it won
				var t := int(fa[int(a["rp"]) - 1])
				if pwin != t:
					down_cl.append(t)
					up_cl.append(pwin)
			elif not up_cl.has(pwin):
				up_cl.append(pwin)
		for c in down_cl:
			lgs[li].erase(c)
			lgs[li + 1].append(c)
		for c in up_cl:
			lgs[li + 1].erase(c)
			lgs[li].append(c)
	return lgs

func _move_clubs() -> void:
	var nl := _moves()
	if nl.is_empty():
		return
	d["leagues"] = nl
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
# By the league's own rule for clubs level on points (head-to-head in Spain and Italy); after a split the
# championship group stays above the relegation group whatever the points.
func order() -> Array:
	var ids0 := ids()
	var t: Dictionary = d["table"]
	var rows := {}
	for c in ids0:
		var r: Dictionary = t[str(c)]
		rows[c] = [int(r["pts"]), int(r["gf"]), int(r["ga"])]
	var tb := str(league().get("tb", "gd"))
	var hh: Dictionary = d.get("hh", {})
	if d.has("spl"):
		var top := []
		var bot := []
		for c in ids0:
			if (d["spl"] as Array).has(c) or (d["spl"] as Array).has(float(c)):
				top.append(c)
			else:
				bot.append(c)
		return _rank(top, rows, hh, tb) + _rank(bot, rows, hh, tb)
	return _rank(ids0, rows, hh, tb)

func rank_of(c: int) -> int:
	return order().find(c) + 1

func swap(a: int, b: int) -> String:
	# a and b are squad indices; either may be in the eleven
	var xi: Array = d["xi"]
	var ia := xi.find(a)
	var ib := xi.find(b)
	var sq: Array = d["squad"]
	for k in [[ia, b], [ib, a]]:
		if int(k[0]) >= 0 and xi.find(int(k[1])) < 0 and int(k[1]) < sq.size() and injured(sq[int(k[1])]):
			return "%s is injured: %s." % [str(sq[int(k[1])]["n"]).capitalize(), inj_text(sq[int(k[1])])]
	if ia >= 0 and ib >= 0:
		xi[ia] = b
		xi[ib] = a
	elif ia >= 0:
		xi[ia] = b
	elif ib >= 0:
		xi[ib] = a
	save()
	return ""

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
	var pool := []
	var tk := _taken()
	for i in 6:
		var nm := new_name(rng, "", 0.45, tk)
		tk[nm] = true
		pool.append(nm)
	var lv := int(round(my_strength()))
	var roles := ["GK", "DF", "DF", "MF", "MF", "FW", "FW"]
	roles.shuffle()
	var out := []
	for i in mini(6, pool.size()):
		var role: String = roles[i]
		var base: Array = ROLE_BASE[role]
		var q: int = lv - 72 + [-3, 0, 2, 4, 6, 9][i] + rng.randi_range(-1, 1)
		var pl := {
			"n": pool[i], "num": 0, "pos": role, "age": rng.randi_range(17, 31), "xp": 0, "g": 0, "apps": 0, "nat": _nat_idx(str(pool[i])),
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
	var pnm := new_name(rng, "", 0.45)
	var role: String = ["GK", "DF", "DF", "DF", "MF", "MF", "MF", "FW", "FW", "FW"][rng.randi_range(0, 9)]
	var base: Array = ROLE_BASE[role]
	var want := clampi(int(round(my_strength())) + rng.randi_range(PACK_Q[tier][0], PACK_Q[tier][1]), 45, 94)
	var pl := {
		"n": pnm, "num": 0, "pos": role, "age": rng.randi_range(17, 30), "xp": 0, "g": 0, "apps": 0, "nat": _nat_idx(pnm),
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
	if window_msg() != "":
		return window_msg()
	if refuses(pl) != "":
		return refuses(pl)
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
	_rec_fee("buy", price, str(pl["n"]))
	save()
	return "%s SIGNED" % str(pl["n"]).to_upper()

# Selling works like real football: you put a man on the transfer list, and he only goes when a club
# makes a bid you accept. Tap again to take him off the list.
static func listed(pl: Dictionary) -> bool:
	return pl.has("tl")

func sell(i: int) -> String:
	var sq: Array = d["squad"]
	if i < 0 or i >= sq.size():
		return ""
	var pl: Dictionary = sq[i]
	if listed(pl):
		pl.erase("tl")
		save()
		return "%s IS OFF THE TRANSFER LIST" % str(pl["n"]).to_upper()
	pl["tl"] = today()
	save()
	var wn := window()
	if bool(wn["open"]):
		return "%s IS ON THE TRANSFER LIST. CLUBS CAN NOW BID FOR HIM" % str(pl["n"]).to_upper()
	return "%s IS ON THE TRANSFER LIST. BIDS CAN COME WHEN THE WINDOW OPENS" % str(pl["n"]).to_upper()

# a man on the list with no open bid for him
func _listed_free() -> Array:
	var open := []
	for m in inbox():
		if str(m["k"]) == "bid" and str(m.get("st", "")) == "open":
			open.append(str(m["pn"]))
	var out := []
	var sq: Array = d["squad"]
	for i in sq.size():
		if listed(sq[i]) and not open.has(str(sq[i]["n"])):
			out.append(i)
	return out

# He goes to club `buyer` (-1 = abroad) for `got`; he takes the place of their weakest man in his position.
func _sell_to(i: int, buyer: int, got: int) -> String:
	var sq: Array = d["squad"]
	var pl: Dictionary = sq[i]
	var cut_t := ""
	if pl.has("sob"):
		# the club you bought him from has a sell-on share
		var cut := int(round(got * SELLON_PCT / 100.0 / 5.0)) * 5
		got -= cut
		cut_t = "  ·  %s TO %s (SELL-ON)" % [money(cut), str(cname(int(pl["sob"])))]
		pl.erase("sob")
	pl.erase("rc")
	d["coins"] = int(d["coins"]) + got
	_rec_fee("sell", got, str(pl["n"]))
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
	return "%s SOLD TO %s FOR %s%s" % [str(pl["n"]).to_upper(), str(cname(buyer)) if buyer >= 0 else "A CLUB ABROAD", money(got), cut_t]

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
	var ynm := new_name(rng, "", 0.08)
	var lv := fac("youth")
	var role: String = ["GK", "DF", "DF", "MF", "MF", "FW", "FW"][rng.randi() % 7]
	var base: Array = ROLE_BASE[role]
	var q := -16 + lv * 2
	var pl := {
		"n": ynm, "num": 0, "pos": role, "age": rng.randi_range(16, 18), "xp": 0, "g": 0, "apps": 0, "nat": _nat_idx(ynm),
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
	return "%s  +1 %s" % [str(pl["n"]).to_upper(), stat_name(str(pl["pos"]), si)]

# ---------------------------------------------------------------- the cup
# Each country's knockout cup with every club in it, one a season, its rounds spread through the league season.
# The strongest clubs wait for the first round to be played (a bye) so the rest is a clean bracket.

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
	return str((ClubDB.CUPS.get(str(cup().get("c", league()["c"])), {}) as Dictionary).get("n", "THE CUP"))

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

func nm_now() -> String:
	return cup_round_name()

func cup_round_name() -> String:
	var nm := cup_names()
	return str(nm[clampi(int(cup()["r"]), 0, nm.size() - 1)])

# Books your cup tie and plays the others. Returns lines for the full-time screen.
# Books your cup tie and plays the others. Returns lines for the full-time screen.
func cup_finish(mine: int, theirs: int, won_tie := false) -> Array:
	var fit0 := _fit_pre()
	var cp: Dictionary = cup()
	var r: int = int(cp["r"])
	var last_r := cup_rounds() - 1
	var lines := []
	# a level tie was settled by the shootout
	var won: bool = mine > theirs or (mine == theirs and won_tie)
	if not bool(d.get("cupmode", false)):
		d["day"] = cup_day(r)
		d["cur"] = int(d["day"])
	var copp := cup_opp()
	if cup_first_leg():
		# the first leg: nothing is settled yet, the second leg comes a week later
		cp["l1"] = [mine, theirs]
		cp["leg"] = 2
		if not bool(d.get("cupmode", false)):
			_rec_result(mine, theirs, copp, true)
		var c1 := int(round((10 + mine * 5) * pay_k(lg()) * (0.3 if eur else 1.0)))
		d["coins"] = int(d["coins"]) + c1
		last_coins = c1
		lines.append("+" + money(c1))
		lines.append("%s, FIRST LEG %d-%d. THE SECOND LEG DECIDES IT" % [str(nm_now()), mine, theirs])
		var rng1 := RandomNumberGenerator.new()
		rng1.randomize()
		_rt_tick(d["xi"], lines)
		_fit_post(fit0, [], lines, rng1)
		world_tick(lines)
		save()
		return lines
	if cup_leg() == 2:
		# the second leg: the goals of both games count; level after extra time = penalties
		var l1: Array = cp.get("l1", [0, 0])
		mine += int(l1[0])
		theirs += int(l1[1])
		cp.erase("l1")
		cp["leg"] = 1
		lines.append("%d-%d ON AGGREGATE" % [mine, theirs])
	won = mine > theirs or (mine == theirs and won_tie)
	if not bool(d.get("cupmode", false)):
		_derby_after(mine + (1 if mine == theirs and won_tie else 0), theirs, copp, lines)
	_cup_round(mine, theirs, won_tie)
	if not bool(d.get("cupmode", false)):
		_rec_result(mine, theirs, copp, true)
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
			if not bool(d.get("cupmode", false)):
				_honour("cup", "Won %s" % cup_name().capitalize())
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
	var rng4 := RandomNumberGenerator.new()
	rng4.randomize()
	_rt_tick(d["xi"], lines)
	_fit_post(fit0, [], lines, rng4)
	world_tick(lines)
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
	var rvl := rival_of(int(d["club"]))
	if rvl >= 0 and league_of(rvl) == league_of(int(d["club"])):
		pool.append("derby")
		pool.append("derby")
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
		"derby":
			ex3 = {"k": "derby", "v": 1, "t": "BEAT %s IN A DERBY" % str(cname(rvl))}
		_:
			# a little more than the young men in the eleven now would get anyway
			var yv := clampi(young * rounds_total() + 6, 8, 60)
			ex3 = {"k": "young", "v": yv, "t": "GIVE %d LEAGUE STARTS TO PLAYERS AGED 21 OR UNDER" % yv}
	b["obj"] = [lg, cp, ex3]
	b["trk"] = {"goals": 0, "cs": 0, "home": 0, "young": 0, "fac0": _fac_sum(), "derby": 0, "dp": 0}
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
		"derby":
			if int(trk.get("derby", 0)) >= v:
				return ["WON", "done"]
			var lg_d := 2 if str(d.get("slen", "full")) != "short" else 1
			if over or int(trk.get("dp", 0)) >= lg_d + 1:
				return ["NOT WON", "failed"]
			return ["%d PLAYED" % int(trk.get("dp", 0)), "behind" if int(trk.get("dp", 0)) >= lg_d else "on"]
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
	var pool := []
	var tk := _taken()
	var sur := {}
	var fs := Names.foreign_share(W[int(d["club"])] if int(d.get("club", -1)) >= 0 and int(d["club"]) < W.size() else {})
	for i in SQUAD_ROLES.size():
		var nm := Names.make(Names.roll_nat(my_ctry(), fs, rng), rng, tk, sur)
		tk[nm] = true
		sur[Names.surname(nm)] = true
		pool.append(nm)
	var squad := []
	for i in SQUAD_ROLES.size():
		var role: String = SQUAD_ROLES[i]
		var base: Array = ROLE_BASE[role]
		var q := q_xi if i < 11 else q_bench
		var pl := {
			"n": pool[i % pool.size()], "num": SQUAD_NUMS[i], "pos": role, "age": rng.randi_range(18, 31), "xp": 0, "g": 0, "apps": 0, "nat": _nat_idx(str(pool[i % pool.size()])),
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
	# the second leg comes a league round after the first
	var due := int(d["round"]) >= cup_after() + (1 if cup_leg() == 2 else 0) or season_over()
	if due and eu_due() and eu_day(int(eu()["md"])) < cup_day(int(cup()["r"])):
		return false
	return due

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
const REGIONS := [["England", 0.0, 1.0], ["Denmark", -1.0, 0.9], ["Spain", 2.0, 1.1], ["Brazil", 3.0, 1.4], ["Netherlands", 1.0, 1.0], ["Germany", 1.0, 0.9], ["France", 2.0, 1.1], ["Argentina", 2.5, 1.3], ["Italy", 1.5, 1.0], ["Portugal", 2.0, 1.2]]

# the scouting region of a country (the academy's local boys come from there)
static func region_of(ctry: String) -> int:
	for i in REGIONS.size():
		if str(REGIONS[i][0]).to_upper() == ctry:
			return i
	return 0
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

func _free_name(rng: RandomNumberGenerator, ctry := "") -> String:
	return new_name(rng, ctry, 0.05)

# ---- names (names.gd): every man has a full made-up name that fits his country, and none repeats
func club_ctry(c: int) -> String:
	if c >= 0 and c < W.size() and str(W[c].get("c", "")) != "":
		return str(W[c]["c"])
	return "ENGLAND"

func my_ctry() -> String:
	return club_ctry(int(d.get("club", -1)))

# every name this career uses already: its own men, the ones it made, and the computer men it changed
func _taken() -> Dictionary:
	var t := {}
	for k in ["squad", "market", "pros", "acad"]:
		for pl in d.get(k, []):
			t[str(pl["n"])] = true
	var cx: Dictionary = d.get("cx", {})
	for k in cx:
		for pl in cx[k]:
			t[str(pl["n"])] = true
	return t

# a new name for a man from this country (or from abroad, `foreign` of the time); no surname twice in your squad
func new_name(rng: RandomNumberGenerator, ctry := "", foreign := 0.25, tk := {}) -> String:
	var home := ctry if ctry != "" else my_ctry()
	var sur := {}
	for pl in d.get("squad", []):
		sur[Names.surname(str(pl["n"]))] = true
	var t := tk if not tk.is_empty() else _taken()
	return Names.make(Names.roll_nat(home, foreign, rng), rng, t, sur)

# A save from before full names (2026-11-22): your men keep their surname and get a first name from your
# club's country, everywhere the save names them; computer men the save changed get new names.
func _names_fix() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.get("club", 0)) * 31 + int(d.get("season", 1)) + 5
	var tk := _taken()
	var ctry := my_ctry()
	var mp := {}
	for k in ["squad", "acad", "pros", "market"]:
		for pl in d.get(k, []):
			var o := str(pl["n"])
			if o == "" or o.find(" ") >= 0 or pl.has("me"):
				continue
			var nm := ""
			if mp.has(o):
				nm = new_name(rng, ctry, 0.1, tk)
			else:
				for t in 30:
					nm = Names.first_for(ctry, rng) + " " + o
					if not tk.has(nm) and not Names.in_world(nm):
						break
				mp[o] = nm
			tk[nm] = true
			pl["n"] = nm
	var cx: Dictionary = d.get("cx", {})
	for k in cx:
		var sur := {}
		for pl in cx[k]:
			var o2 := str(pl["n"])
			if o2.find(" ") < 0 and not pl.has("me"):
				var n2 := Names.make(club_ctry(int(k)), rng, tk, sur)
				tk[n2] = true
				pl["n"] = n2
			sur[Names.surname(str(pl["n"]))] = true
	if mp.is_empty():
		return
	var own := "%d:" % int(d.get("club", -1))
	for k in d.keys():
		if k in ["squad", "acad", "pros", "market", "cx", "pro", "pro2"]:
			continue
		d[k] = _nm_swap(d[k], mp, own)

func _nm_swap(v, mp: Dictionary, own: String):
	if v is String:
		return mp.get(v, v)
	if v is Array:
		var a := []
		for x in v:
			a.append(_nm_swap(x, mp, own))
		return a
	if v is Dictionary:
		var o := {}
		for k in v:
			var k2 = k
			if k is String:
				if mp.has(k):
					k2 = mp[k]
				elif (k as String).begins_with(own) and mp.has((k as String).substr(own.length())):
					k2 = own + str(mp[(k as String).substr(own.length())])
			o[k2] = _nm_swap(v[k], mp, own)
		return o
	return v

# the national team a name belongs to (-1 = not one of NATIONS: nat_of() then picks one)
func _nat_idx(nm: String) -> int:
	var c := Names.nat_of(nm)
	if c == "FRANCE_AF":
		c = "FRANCE"
	for i in NATIONS.size():
		if str(NATIONS[i][0]) == c:
			return i
	return -1

# a young player: real level and potential, and what your scout thinks they are (a range)
func _youth(rng: RandomNumberGenerator, rg: int, stars: int) -> Dictionary:
	var R: Array = REGIONS[clampi(rg, 0, REGIONS.size() - 1)]
	var role: String = ["GK", "DF", "DF", "MF", "MF", "FW", "FW"][rng.randi() % 7]
	var base: Array = ROLE_BASE[role]
	var q := -20 + rng.randi_range(-3, 4)
	var yn := _free_name(rng, str(R[0]).to_upper())
	var pl := {"n": yn, "num": 0, "pos": role, "age": rng.randi_range(15, 17), "xp": 0, "g": 0, "apps": 0, "nat": _nat_idx(yn),
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
	var pl := _youth(rng, region_of(ctry), 1 + fac("youth"))
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
	# after the league: the play-offs, two games a week
	return int(ds[ds.size() - 1]) + 4 * (r - ds.size() + 1)

# a cup tie: the Wednesday after its league round
func cup_day(cr: int) -> int:
	return lg_day(maxi(cup_after_r(cr) - 1, 0)) + 4 + (7 if cr == int(cup().get("r", 0)) and cup_leg() == 2 else 0)

# Two legs, as in the real cups (ClubDB.CUPS two): the rounds before the final that are home and away.
func cup_two_legs(r := -1) -> bool:
	if bool(d.get("cupmode", false)) and not d.has("cup"):
		return false
	var cp: Dictionary = cup()
	var rr := int(cp["r"]) if r < 0 else r
	var two := int((ClubDB.CUPS.get(str(cp.get("c", "")), {}) as Dictionary).get("two", 0))
	var last := cup_rounds() - 1
	return two > 0 and rr < last and rr >= last - two

# 1 or 2: the leg of your tie in this round (always 1 in a one-off round)
func cup_leg() -> int:
	if not d.has("cup"):
		return 1
	return int(d["cup"].get("leg", 1))

# the first leg's goals, as [yours, theirs], in a second leg
func cup_agg() -> Array:
	if cup_leg() != 2:
		return [0, 0]
	var l1: Array = d["cup"].get("l1", [0, 0])
	return [int(l1[0]), int(l1[1])]

# a cup match that may end level: the first leg of a two-legged round
func cup_first_leg() -> bool:
	return d.has("cup") and cup_two_legs() and cup_leg() == 1

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
		out.append({"day": lg_day(r), "kind": "lg", "opp": opp, "home": home, "res": res, "played": r < int(d["round"]), "name": round_name(r), "next": false})
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
	var ee := eu()
	if not ee.is_empty() and bool(ee.get("me", false)):
		var lg_e: Array = ee.get("log", [])
		var me_e := int(d["club"])
		for md in EU_RD.size():
			var e2 := {"day": eu_day(md), "kind": "eu", "opp": -1, "home": true, "res": [], "played": md < int(ee["md"]), "name": eu_round_name(md).capitalize(), "next": false}
			if md < lg_e.size():
				var found2 := false
				for t in lg_e[md]:
					if int(t[0]) == me_e or int(t[1]) == me_e:
						var am := int(t[0]) == me_e
						e2["opp"] = int(t[1]) if am else int(t[0])
						e2["home"] = am
						e2["res"] = [int(t[2]) if am else int(t[3]), int(t[3]) if am else int(t[2])]
						found2 = true
				if not found2:
					continue
			elif md == int(ee["md"]) and eu_due_ever():
				var oh := eu_opp()
				e2["opp"] = int(oh[0])
				e2["home"] = bool(oh[1])
			elif bool(ee.get("out", false)) or bool(ee.get("done", false)):
				continue
			out.append(e2)
	out.append_array(_nat_cal())
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
	if eu_due():
		return maxi(eu_day(int(eu()["md"])), today() + 1)
	if nat_due():
		return maxi(nat_day(), today() + 1)
	if season_over():
		return -1
	return lg_day(int(d["round"]))

# A match you do not play yourself: the score from the two clubs' strength, with a little home edge.
# [mine, theirs, scorers (squad indices), minutes of the goals [[minute, 0 = you / 1 = them, scorer name]]]
func sim_match(opp: int, home: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var df := (match_strength() - _strength(opp)) / 14.0 + (0.12 if home else -0.12)
	if derby(opp):
		df *= 0.6 # form goes out of the window in a derby
	var tk := tac_effect(tac(), cpu_tac(opp), df)
	df += float(tk[2])
	var mine := _poisson(rng, (1.35 * exp(df) + 0.1) * float(tk[0]))
	var theirs := _poisson(rng, 1.35 * exp(-df) * float(tk[1]))
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

# ---------------------------------------------------------------- tactics before the match
# How your team plays: mentality 0-4 (park the bus .. all out attack), pressing 0-2 (low, mid, high) and
# width 0-2 (narrow, normal, wide). It changes how your men move in a match you play, and the score of one you simulate.
const TAC_N := [["Park the bus", "Defensive", "Balanced", "Attacking", "All out attack"], ["Low", "Mid", "High"], ["Narrow", "Normal", "Wide"]]

func tac() -> Array:
	var t: Array = d.get("tac", [2, 1, 1])
	return [clampi(int(t[0]), 0, 4), clampi(int(t[1]), 0, 2), clampi(int(t[2]), 0, 2)] if t.size() >= 3 else [2, 1, 1]

func set_tac(k: int, v: int) -> void:
	var t := tac()
	if k < 0 or k > 2:
		return
	t[k] = clampi(v, 0, 4 if k == 0 else 2)
	d["tac"] = t
	save()

static func tac_text(t: Array) -> String:
	return "%s  ·  %s press  ·  %s" % [TAC_N[0][int(t[0])], TAC_N[1][int(t[1])], TAC_N[2][int(t[2])]]

# The other manager picks his plan by how strong he is against you: a big club comes at you and presses high,
# a small one sits deep and stays narrow. Each club has a bit of its own habit too, and a derby is played high.
func cpu_tac(opp: int) -> Array:
	if opp < 0:
		return [2, 1, 1]
	var gap := _strength(opp) - match_strength()
	return ClubDB.plan_for(cpu_style(opp), gap, derby(opp))

# how a club plays (its own style: see ClubDB.style)
func cpu_style(c: int) -> Dictionary:
	if c < 0 or c >= W.size():
		return ClubDB.style({})
	var cc: Dictionary = (W[c] as Dictionary).duplicate()
	cc["r"] = rating(c)
	return ClubDB.style(cc)

# What two plans do to a simulated match: [your goals x, their goals x, plus to the strength gap].
# Going forward scores more but leaves holes behind; pressing high pays most for the better side;
# width stretches a deep, narrow block but a narrow side is harder to play through.
static func tac_effect(me: Array, op: Array, df: float) -> Array:
	var km := 1.0
	var kt := 1.0
	var add := 0.0
	var m1 := int(me[0]) - 2
	var m2 := int(op[0]) - 2
	km *= 1.0 + 0.14 * m1
	kt *= 1.0 + 0.10 * m1
	kt *= 1.0 + 0.14 * m2
	km *= 1.0 + 0.10 * m2
	var p1 := int(me[1]) - 1
	var p2 := int(op[1]) - 1
	add += p1 * (0.10 if df > 0.0 else 0.04)
	add -= p2 * (0.10 if df < 0.0 else 0.04)
	if int(me[2]) == 2:
		km *= 1.10 if int(op[0]) <= 1 and int(op[2]) == 0 else 1.04
		kt *= 1.03
	elif int(me[2]) == 0:
		km *= 0.95
		kt *= 0.94
	if int(op[2]) == 2:
		kt *= 1.10 if int(me[0]) <= 1 and int(me[2]) == 0 else 1.04
		km *= 1.03
	elif int(op[2]) == 0:
		kt *= 0.95
		km *= 0.94
	return [maxf(km, 0.4), maxf(kt, 0.4), add]

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
	var pool: Array = Names.club(c)
	# the old name shuffle drew 59 numbers: still draw them, so every club keeps the same men as before
	for n in range(59, 0, -1):
		rng.randi_range(0, n)
	var q := rating(c) - 72
	var out := []
	var stars := [9, 6 + c % 2]
	for i in CPU_ROLES.size():
		var role: String = CPU_ROLES[i]
		var base: Array = ROLE_BASE[role]
		var qq := q + (6 if stars.has(i) else 0) - (5 if i >= 11 else 0)
		var pl := {
			"n": pool[i % pool.size()], "num": [1, 3, 4, 5, 2, 8, 6, 10, 11, 9, 7, 13, 15, 16, 14, 18, 19, 20][i], "pos": role, "age": rng.randi_range(18, 33), "xp": 0, "g": 0, "apps": 0, "nat": _nat_idx(str(pool[i % pool.size()])),
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

# A club at the player's level that would buy him: mostly in your country, now and then a top club abroad.
func _buyer_for(pl: Dictionary, rng: RandomNumberGenerator) -> int:
	var o := ovr_of(pl)
	var cand := []
	for li in ClubDB.LEAGUES.size():
		var home: bool = str(ClubDB.LEAGUES[li]["c"]) == str(league()["c"])
		# clubs abroad bid too, for a man good enough for their top league
		if not home and (int(ClubDB.LEAGUES[li]["t"]) != 1 or rng.randf() < 0.6):
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
# Deals as in FIFA: "so" leaves them a sell-on share (they take less now), "swap" puts one of your men in the deal
# (his worth to them comes off the price), "rc" pays his release clause (no talk with the club at all).
# ---------------------------------------------------------------- will he come? A star does not drop down
# As in FIFA a good player looks at where he would play. He will not drop down a level (a regular in a better
# league does not join a club in a lower one) and a star will not join a club far below his own level. A man over 30
# is less fussy, and a club in Europe this season looks bigger.
static func league_prestige(li: int) -> int:
	if li < 0 or li >= ClubDB.LEAGUES.size():
		return 1
	return int(ClubDB.LEAGUES[li]["pr"])

func club_prestige(c: int) -> int:
	if c == int(d["club"]):
		return league_prestige(int(d.get("lg", league_of(c))))
	return league_prestige(league_of(c)) if league_of(c) >= 0 else 1

# why he says no to your club, or "" when he would come
func refuses(pl: Dictionary, from_c := -1, short := false) -> String:
	if bool(d.get("cupmode", false)) or not d.has("leagues") or bool(pl.get("me", false)):
		return ""
	var ovr := ovr_of(pl)
	var age := int(pl.get("age", 25))
	var in_eu := 1 if not eu().is_empty() and bool(eu().get("me", false)) and not bool(eu().get("done", false)) else 0
	var gap := 9 + (4 if age >= 31 else 0) + 3 * in_eu + (2 if in_eu == 1 and eu_k() == 0 else 0)
	if ovr >= my_strength() + gap:
		return "Your club is too small for him" if short else "%s SAYS NO: %s IS NOT BIG ENOUGH FOR A PLAYER OF HIS LEVEL." % [str(pl["n"]).to_upper(), str(cname(int(d["club"])))]
	if from_c >= 0 and age < 31:
		var drop := club_prestige(int(d["club"])) - club_prestige(from_c) - in_eu
		if drop >= 1 and ovr >= rating(from_c) - 2:
			return ("He won't drop down to %s" % league_name().capitalize()) if short else "%s SAYS NO: HE WILL NOT DROP DOWN TO %s." % [str(pl["n"]).to_upper(), league_name()]
	return ""

func bid(c: int, i: int, amount: int, ex := {}) -> Dictionary:
	var sq := cpu_squad(c)
	if i < 0 or i >= sq.size():
		return {"ok": false, "msg": ""}
	if window_msg() != "":
		return {"ok": false, "msg": window_msg()}
	var no := refuses(sq[i], c)
	if no != "":
		return {"ok": false, "msg": no}
	var swap := str(ex.get("swap", ""))
	if (d["squad"] as Array).size() >= SQUAD_MAX and swap == "":
		return {"ok": false, "msg": "Your squad is full. Sell a player first."}
	if int(d["coins"]) < amount:
		return {"ok": false, "msg": "You need %s more." % money(amount - int(d["coins"]))}
	var ask := ask_price(c, i)
	var neg: Dictionary = d.get("neg", {})
	var key := "%d:%s" % [c, str(sq[i]["n"])]
	var pl: Dictionary = sq[i]
	var rc := cpu_clause(c, i)
	var pay_rc := bool(ex.get("rc", false))
	if pay_rc:
		if rc <= 0:
			return {"ok": false, "msg": ""}
		amount = rc
		if int(d["coins"]) < amount:
			return {"ok": false, "msg": "You need %s more." % money(amount - int(d["coins"]))}
	elif rc > 0 and swap == "":
		# one of their best men with a clause in his contract: they will not sell him, only the clause buys him
		return {"ok": false, "msg": "%s WILL NOT SELL HIM. ONLY HIS RELEASE CLAUSE (%s) CAN BUY HIM." % [str(cname(c)), money(rc)]}
	var need := ask
	if bool(ex.get("so", false)):
		need = int(round(ask * SELLON_CUT / 5.0)) * 5
	if swap != "":
		var si := _sq_find(swap)
		if si < 0:
			return {"ok": false, "msg": ""}
		var sv := swap_worth(c, i, si)
		if sv <= 0:
			return {"ok": false, "msg": "%s DO NOT WANT %s." % [str(cname(c)), swap.to_upper()]}
		if (d["squad"] as Array).size() <= SQUAD_MIN:
			return {"ok": false, "msg": "You need at least %d players." % SQUAD_MIN}
		need = maxi(0, need - sv)
		amount = maxi(amount, need)
		if int(d["coins"]) < amount:
			return {"ok": false, "msg": "You need %s more." % money(amount - int(d["coins"]))}
	if pay_rc or amount >= need or (neg.has(key) and amount >= int(neg[key]) and swap == "" and not ex.has("so")):
		neg.erase(key)
		d["neg"] = neg
		var ex2 := {}
		if bool(ex.get("so", false)) and not pay_rc:
			ex2["sob"] = c
		if swap != "":
			ex2["swap"] = swap
		if wages_on():
			# the clubs agree on the fee: now the player himself has to say yes to a contract
			talk_sign(pl, amount, c, i)
			(d["talk"] as Dictionary)["ex"] = ex2
			save()
			return {"ok": true, "talk": true, "msg": "%s WITH %s. NOW TALK TO %s." % ["CLAUSE PAID" if pay_rc else "FEE AGREED", str(cname(c)), str(pl["n"]).to_upper()]}
		return {"ok": true, "msg": _complete_bid(c, i, amount, -1, -1, ex2)}
	if amount >= int(ask * 0.75):
		neg[key] = ask
		d["neg"] = neg
		save()
		return {"ok": false, "counter": ask, "msg": "%s SAY NO, BUT THEY WOULD TAKE %s." % [str(cname(c)), money(ask)]}
	return {"ok": false, "msg": "%s TURN THE BID DOWN FLAT." % str(cname(c))}

# The transfer goes through: he joins you, his club signs a younger, cheaper man for his place.
func _complete_bid(c: int, i: int, amount: int, wk: int, yrs: int, ex := {}) -> String:
	var sq := cpu_squad(c)
	var pl: Dictionary = sq[i]
	var swap := str(ex.get("swap", ""))
	var gone: Dictionary = {}
	if swap != "":
		var si := _sq_find(swap)
		if si < 0:
			return "%s IS NOT AT THE CLUB ANY MORE. THE SWAP IS OFF." % swap.to_upper()
		gone = d["squad"][si]
		_out_of_xi(si)
		_remove_mine(si)
	if true:
		# he leaves: the club signs a younger, cheaper man for his place
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var role := str(pl["pos"])
		var base: Array = ROLE_BASE[role]
		var q := rating(c) - 76
		var nwn := new_name(rng, club_ctry(c), 0.25)
		var nw := {"n": nwn, "nat": _nat_idx(nwn), "num": int(pl["num"]), "pos": role, "age": rng.randi_range(18, 23), "xp": 0, "g": 0, "apps": 0,
			"pac": clampi(base[0] + q + rng.randi_range(-4, 4), 30, 95), "sho": clampi(base[1] + q + rng.randi_range(-4, 4), 25, 95),
			"pas": clampi(base[2] + q + rng.randi_range(-4, 4), 30, 95), "dfn": clampi(base[3] + q + rng.randi_range(-4, 4), 25, 95), "ab": []}
		nw["pot"] = clampi(ovr_of(nw) + rng.randi_range(4, 12), ovr_of(nw), 94)
		var their := sq.duplicate(true)
		if not gone.is_empty():
			# the swap: your man takes his place at their club
			var g2: Dictionary = gone.duplicate(true)
			g2["num"] = int(pl["num"])
			g2["tp"] = 0
			g2["xp"] = 0
			g2.erase("sob")
			g2.erase("rc")
			their[i] = g2
		else:
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
		if ex.has("sob"):
			# they keep a share of what you sell him for one day
			me_pl["sob"] = int(ex["sob"])
		if ex.has("rc"):
			me_pl["rc"] = int(ex["rc"])
		d["coins"] = int(d["coins"]) - amount
		d["squad"].append(me_pl)
		_rec_fee("buy", amount, str(pl["n"]))
		save()
		if not gone.is_empty():
			return "%s SIGNED FROM %s: %s GOES THE OTHER WAY + %s" % [str(pl["n"]).to_upper(), str(cname(c)), str(gone["n"]).to_upper(), money(amount)]
		return "%s SIGNED FROM %s FOR %s%s" % [str(pl["n"]).to_upper(), str(cname(c)), money(amount), ("  ·  %d%% SELL-ON TO THEM" % SELLON_PCT) if ex.has("sob") else ""]
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
	elif what == "rc":
		t["rc"] = (int(t.get("rc", 0)) + step + 3) % 3
	else:
		t["yrs"] = clampi(int(t["yrs"]) + step, 1, 5)
	d["talk"] = t

func talk_force(offer: int, yrs: int, rc := -1) -> void:
	var t := talk()
	if t.is_empty():
		return
	t["offer"] = clampi(offer, 1, int(t["ask"]) * 2)
	t["yrs"] = clampi(yrs, 1, 5)
	if rc >= 0:
		t["rc"] = clampi(rc, 0, 2)
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
	if int(t["offer"]) >= int(round(int(t["min"]) * RC_WAGE[clampi(int(t.get("rc", 0)), 0, 2)])):
		var wk := int(t["offer"])
		var yrs := int(t["yrs"])
		d.erase("talk")
		if signing:
			var ex3: Dictionary = (t.get("ex", {}) as Dictionary).duplicate()
			var rc3 := clause_of_talk(t)
			if rc3 > 0:
				ex3["rc"] = rc3
			var r := _complete_bid(int(t["from"]), int(t["idx"]), int(t["fee"]), wk, yrs, ex3) if int(t["from"]) >= 0 else _complete_buy(int(t["idx"]), wk, yrs)
			if int(t["from"]) < 0 and rc3 > 0 and not d["squad"].is_empty():
				(d["squad"][(d["squad"] as Array).size() - 1] as Dictionary)["rc"] = rc3
			save()
			return "%s  ·  %s A WEEK FOR %d SEASONS" % [r, wage_text(wk), yrs]
		var pl: Dictionary = d["squad"][int(t["i"])]
		pl["wk"] = wk
		pl["ct"] = yrs
		var rc4 := clause_of_talk(t)
		if rc4 > 0:
			pl["rc"] = rc4
		else:
			pl.erase("rc")
		save()
		return "%s SIGNS A NEW CONTRACT: %s A WEEK FOR %d SEASONS%s" % [nm, wage_text(wk), yrs, ("  ·  CLAUSE " + money(rc4)) if rc4 > 0 else ""]
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
	if bool(pl.get("me", false)):
		# a player career's own man grows from his own levels and training (pro_after), never by himself
		pl["xp"] = 0
		return
	var got := []
	while (int(pl["xp"]) >= 100 or int(pl.get("tp", 0)) > 0) and ovr_of(pl) < int(pl["pot"]):
		if int(pl.get("tp", 0)) > 0:
			pl["tp"] = int(pl["tp"]) - 1
		else:
			pl["xp"] = int(pl["xp"]) - 100
		var gk := _grow_pick(pl, rng)
		pl[gk] = mini(int(pl[gk]) + 1, 97)
		got.append(stat_name(str(pl["pos"]), STAT_KEYS.find(gk)))
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

static func focus_name(tf: String, pos := "") -> String:
	var k := STAT_KEYS.find(tf)
	return stat_name(pos, k) if k >= 0 else "AUTO"

# ---------------------------------------------------------------- retraining: a man learns a new position
# Every man has his own position (pl["pos"]) and can learn more (pl["pos2"]). Out of position he plays worse: next
# to his own line (DF-MF, MF-FW) a little, two lines away (DF-FW) more, a keeper outside his goal (or the other way)
# a lot. Pick a new position to work on (pl["rt"]) and he learns it in training and by playing there (pl["rtp"],
# 0-100 for each position). The cost of playing there shrinks while he learns, and at 100 it is his.
const RT_ROLES := ["DF", "MF", "FW"]
const RT_NAMES := {"GK": "KEEPER", "DF": "DEFENDER", "MF": "MIDFIELDER", "FW": "FORWARD"}
const FORM_ROLES := {"4-3-3": [4, 3, 3], "4-4-2": [4, 4, 2], "3-5-2": [3, 5, 2], "5-3-2": [5, 3, 2], "4-2-3-1": [4, 3, 3]}

static func pos2_of(pl: Dictionary) -> Array:
	var a = pl.get("pos2", [])
	return a if a is Array else []

static func plays(pl: Dictionary, role: String) -> bool:
	return str(pl.get("pos", "")) == role or pos2_of(pl).has(role)

static func rt_prog(pl: Dictionary, role: String) -> float:
	var p = pl.get("rtp", {})
	return float((p as Dictionary).get(role, 0.0)) if p is Dictionary else 0.0

# what playing in this role costs him on every stat
static func pos_off(pl: Dictionary, role: String) -> int:
	if role == "" or plays(pl, role):
		return 0
	var own := str(pl.get("pos", "MF"))
	if (own == "GK") != (role == "GK"):
		return -25
	var gap := 2
	for r in [own] + pos2_of(pl):
		if RT_ROLES.has(str(r)):
			gap = mini(gap, absi(RT_ROLES.find(str(r)) - RT_ROLES.find(role)))
	var base := -6.0 if gap <= 1 else -12.0
	return int(round(base * (1.0 - 0.6 * clampf(rt_prog(pl, role), 0.0, 100.0) / 100.0)))

# the role of each of the eleven places: the formation, with the spots you dragged men to
func slot_roles() -> Array:
	var c: Array = FORM_ROLES.get(form(), [4, 3, 3])
	var out := ["GK"]
	for k in 3:
		for j in int(c[k]):
			out.append(RT_ROLES[k])
	var l := lay()
	for s in range(1, mini(out.size(), 11)):
		if l.has(str(s)) and l[str(s)] is Array and (l[str(s)] as Array).size() == 2:
			out[s] = role_at(float(l[str(s)][0]))
	return out

# the positions he can work on, in the order the button goes through them ("" = nothing)
static func rt_options(pl: Dictionary) -> Array:
	var out := [""]
	if str(pl.get("pos", "")) == "GK":
		return out
	for r in RT_ROLES:
		if not plays(pl, r):
			out.append(r)
	return out

func retrain(i: int) -> void:
	var sq: Array = d["squad"]
	if i < 0 or i >= sq.size():
		return
	var opts := rt_options(sq[i])
	var cur := opts.find(str(sq[i].get("rt", "")))
	var nx := str(opts[(maxi(cur, 0) + 1) % opts.size()])
	if nx == "":
		sq[i].erase("rt")
	else:
		sq[i]["rt"] = nx
	save()

# after a match: the men who started learn the role they played in, and what they work on in training
func _rt_tick(xi: Array, lines: Array) -> void:
	var sq: Array = d["squad"]
	var roles := slot_roles()
	var where := {}
	for k in mini(xi.size(), roles.size()):
		where[int(xi[k])] = str(roles[k])
	var tk := 1.0 + 0.08 * fac("training")
	for i in sq.size():
		var pl: Dictionary = sq[i]
		if str(pl.get("pos", "")) == "GK" or bool(pl.get("me", false)):
			continue
		var gain := {}
		var rt := str(pl.get("rt", ""))
		if rt != "" and not plays(pl, rt):
			gain[rt] = 2.6 * train_k(pl) * tk
		var w := str(where.get(i, ""))
		if w != "" and w != "GK" and not plays(pl, w):
			gain[w] = float(gain.get(w, 0.0)) + (4.5 if w == rt else 2.0)
		if gain.is_empty():
			continue
		var rtp: Dictionary = pl.get("rtp", {}) if pl.get("rtp", {}) is Dictionary else {}
		for r in gain:
			var v := minf(rt_prog(pl, r) + float(gain[r]), 100.0)
			if v >= 100.0:
				var p2 := pos2_of(pl).duplicate()
				p2.append(r)
				pl["pos2"] = p2
				rtp.erase(r)
				if rt == r:
					pl.erase("rt")
				lines.append("%s CAN NOW PLAY AS A %s" % [str(pl["n"]).to_upper(), RT_NAMES[r]])
			else:
				rtp[r] = snappedf(v, 0.1)
		if rtp.is_empty():
			pl.erase("rtp")
		else:
			pl["rtp"] = rtp

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
	_streak_add(won)
	_bold_result(won, lines)
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
		_promise_check(pl, lines)
		m = int(pl["mo"])
		var nm := str(pl["n"]).to_upper()
		if m0 >= 35 and m < 35:
			lines.append("%s IS UNHAPPY: HE %s" % [nm, ROLE_WANT[r]])
			if r <= 2 and not pl.has("pr") and not pl.has("tl") and not pl.has("tr") and not pro():
				_talk_mail(pl, r)
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


# ---------------------------------------------------------------- a world that lives
# Transfer windows: summer (until 1 September) and winter (January, to 2 February). In a FULL career you can
# only deal with clubs while one is open; a SIMPLE career never shuts the market. Either way the other clubs
# trade with each other in the windows, clubs bid for your men, and it all lands in your inbox.
const INBOX_MAX := 40
const DEALS_MAX := 60

func _day_at(y: int, m: int, dd: int) -> int:
	var u := int(Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": dd, "hour": 12}))
	return int(round((u - _day0()) / 86400.0))

# [[first day, last day (deadline day), name], ...] for this season
func _windows() -> Array:
	var y := 2026 + int(d.get("season", 1)) - 1
	return [[-90, _day_at(y, 9, 1), "Summer window"], [_day_at(y + 1, 1, 1), _day_at(y + 1, 2, 2), "Winter window"]]

func windows_on() -> bool:
	return full() and not bool(d.get("cupmode", false))

# {open, name, close (deadline day), deadline (this is your last stop before it shuts)} or {open: false, opens}
# where you stand in the world: the eve of your next match (the days up to it have gone by on the calendar)
func now() -> int:
	var nd := next_day()
	if nd < 0:
		return today()
	if not d.has("cur"):
		return nd # an old save: the eve of the next match
	return clampi(int(d["cur"]), today(), nd)

# FIFA's ADVANCE: on to the next day something happens (news, a bid, a man fit again), or to match day.
# Returns the day you came from.
func advance() -> int:
	var nd := next_day()
	var from := now()
	if nd < 0 or from >= nd:
		return from
	var t := from
	while t < nd:
		t += 1
		d["cur"] = t
		var mid := int(d.get("mid", 0))
		world_tick([], false)
		if int(d.get("mid", 0)) != mid:
			break
	save()
	return from

# before a match: the days up to it go by. Returns the day you came from.
func go_match() -> int:
	var nd := next_day()
	var from := now()
	if nd < 0 or from >= nd:
		return from
	d["cur"] = nd
	world_tick([], false)
	save()
	return from

func window() -> Dictionary:
	var t := now()
	for wv in _windows():
		if t >= int(wv[0]) and t <= int(wv[1]):
			return {"open": true, "name": str(wv[2]), "close": int(wv[1]), "deadline": int(wv[1]) - t <= 6, "ctext": date_text(int(wv[1]), true)}
	for wv in _windows():
		if int(wv[0]) > t:
			return {"open": false, "opens": int(wv[0]), "otext": date_text(int(wv[0]), true), "name": str(wv[2])}
	return {"open": false, "opens": -1, "otext": "the summer", "name": "Summer window"}

# "" when you may deal with other clubs now, else why not
func window_msg() -> String:
	if not windows_on():
		return ""
	var wn := window()
	if bool(wn["open"]):
		return ""
	return "The transfer window is shut. It opens on %s." % str(wn["otext"])

# a club's name; your own club (made by you) has your name, not the club it took the place of
func cname(c: int) -> String:
	if c == int(d.get("club", -1)) and d.has("own") and d["own"] is Dictionary:
		return str(d["own"].get("n", W[c]["n"]))
	return str(W[c]["n"]) if c >= 0 and c < W.size() else ""

func inbox() -> Array:
	return d.get("inbox", [])

func unread() -> int:
	var n := 0
	for m in inbox():
		if not bool(m.get("rd", false)):
			n += 1
	return n

func _mail(k: String, t: String, b: String, ex := {}) -> Dictionary:
	var m := {"id": int(d.get("mid", 0)) + 1, "day": now(), "k": k, "t": t, "b": b, "rd": false}
	d["mid"] = int(m["id"])
	m.merge(ex)
	var ib: Array = inbox()
	ib.push_front(m)
	while ib.size() > INBOX_MAX:
		ib.pop_back()
	d["inbox"] = ib
	return m

func mail(id: int) -> Dictionary:
	for m in inbox():
		if int(m["id"]) == id:
			return m
	return {}

func mail_read(id: int) -> void:
	var m := mail(id)
	if not m.is_empty() and not bool(m.get("rd", false)):
		m["rd"] = true
		save()

func deals() -> Array:
	return d.get("deals", [])

# every club in a league anywhere (not yours)
func _world_clubs() -> Array:
	var out := []
	for li in ClubDB.LEAGUES.size():
		for c in ids(li):
			if int(c) != int(d["club"]):
				out.append(int(c))
	return out

func _country_clubs() -> Array:
	var out := []
	var ctry := str(league()["c"])
	for li in ClubDB.LEAGUES.size():
		if str(ClubDB.LEAGUES[li]["c"]) != ctry:
			continue
		for c in ids(li):
			if int(c) != int(d["club"]):
				out.append(int(c))
	return out

# The days from today to your next match go by: the other clubs trade, the window opens or shuts, bids come in.
func world_tick(lines: Array, per_match := true) -> void:
	if ro or bool(d.get("cupmode", false)) or not d.has("leagues"):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var t := now()
	var from := int(d.get("wlast", -999))
	if from > t:
		from = t - 7
	d["wlast"] = t
	var wins := _windows()
	for wv in wins:
		var o := int(wv[0])
		var c := int(wv[1])
		# it shut since the last stop
		if from >= o and from <= c and t > c:
			var nn := 0
			for x in deals():
				if int(x[0]) >= o and int(x[0]) <= c:
					nn += 1
			_mail("window", "The %s has shut" % str(wv[2]).to_lower(), "%d deals between the clubs in your country. The next window opens on %s." % [nn, str(window().get("otext", "the summer"))])
			lines.append("THE TRANSFER WINDOW HAS SHUT")
		# it opened since the last stop (or the season has just begun)
		if t >= o and t <= c and (from < o or from > c):
			_mail("window", "The %s is open" % str(wv[2]).to_lower(), "Clubs can buy and sell until %s. Deadline day is the last day." % date_text(c, true))
		# the clubs traded in the days that went by (a flurry on deadline day)
		var a := maxi(maxi(from + 1, t - 10), o)
		var b := mini(t, c)
		if a <= b:
			# about one deal every five days, so a day at a time gives the same world as a week at once
			var n := 0
			for dday in b - a + 1:
				if rng.randf() < 0.2:
					n += 1
			var dl := c >= a and c <= b
			if dl:
				n += rng.randi_range(3, 5)
			var got := []
			for k in n:
				var on_dl := dl and k >= n - 4
				var x := _cpu_deal(rng, c if on_dl else rng.randi_range(a, b))
				if not x.is_empty():
					got.append(x)
			_deal_mail(got)
	for pl in d["squad"]:
		var bk := int(pl.get("inj", -999))
		if bk > from and bk <= t and from > -999:
			_mail("med", "%s is fit again" % str(pl["n"]).capitalize(), "%s is over %s and can play in your next match." % [str(pl["n"]).capitalize(), str(pl.get("injn", "his injury"))])
			pl.erase("inj")
			pl.erase("injn")
	_month_awards(lines)
	var wn := window()
	if bool(wn["open"]) and bool(wn["deadline"]) and int(d.get("dlw", -1)) != int(wn["close"]) and not pro():
		d["dlw"] = int(wn["close"])
		_mail("deadline", "Deadline day is coming", "The window shuts on %s. Anything you want to do, do it now." % str(wn["ctext"]))
		lines.append("DEADLINE DAY IS COMING")
	_nat_tick(lines)
	if not per_match:
		# a day going by: the rest (bids, offers, the press) comes with the matches
		return
	# bids for your men: only while a window is open for you
	for m in inbox():
		if str(m["k"]) == "bid" and str(m.get("st", "")) == "open":
			m["left"] = int(m.get("left", 2)) - 1
			if not bool(wn["open"]) or int(m["left"]) < 0 or _sq_find(str(m["pn"])) < 0:
				m["st"] = "gone"
	if pro():
		for m in inbox():
			if str(m["k"]) == "pjob" and str(m.get("st", "")) == "open":
				m["left"] = int(m.get("left", 3)) - 1
				if int(m["left"]) < 0:
					m["st"] = "gone"
		_pro_offers(rng, lines)
		return
	if bool(wn["open"]):
		# men on the transfer list: clubs look at them first
		for li in _listed_free():
			var lpl: Dictionary = d["squad"][li]
			var lch := interest(lpl) + (0.15 if bool(wn["deadline"]) else 0.0)
			if rng.randf() < lch:
				_cpu_bid(rng, lines, li)
		var ch := 0.25 + (0.4 if bool(wn["deadline"]) else 0.0)
		if today() < 0:
			ch = 0.0 # the first days of a new career: let the man settle in
		if rng.randf() < ch:
			_cpu_bid(rng, lines)
		if today() >= 0:
			_clause_tick(rng, lines)
	if eur:
		_press_tick(rng, lines)
	_nat_offer(rng, lines)

func _deal_mail(got: Array) -> void:
	if got.is_empty():
		return
	var mine := ids()
	var rows := []
	var near := false
	for x in got:
		rows.append(deal_text(x))
		if mine.has(int(x[5])) or mine.has(int(x[6])):
			near = true
	var head := deal_text(got[0])
	_mail("deal", ("Transfer news: %d deals" % got.size()) if got.size() > 1 else head, "\n".join(PackedStringArray(rows)), {"near": near})

# [day, name, pos, ovr, age, from, to, fee]
func deal_text(x: Array) -> String:
	return "%s sign %s (%s, %d) from %s for %s" % [str(cname(int(x[6]))).capitalize(), str(x[1]).capitalize(), str(x[2]), int(x[3]), str(cname(int(x[5]))).capitalize(), money(int(x[7]))]

# a young man for the place a club just sold
func _fill_in(c: int, role: String, num: int, rng: RandomNumberGenerator) -> Dictionary:
	var base: Array = ROLE_BASE[role]
	var q := rating(c) - 76
	var nwn := new_name(rng, club_ctry(c), 0.25)
	var nw := {"n": nwn, "nat": _nat_idx(nwn), "num": num, "pos": role, "age": rng.randi_range(18, 23), "xp": 0, "g": 0, "apps": 0,
		"pac": clampi(base[0] + q + rng.randi_range(-4, 4), 30, 95), "sho": clampi(base[1] + q + rng.randi_range(-4, 4), 25, 95),
		"pas": clampi(base[2] + q + rng.randi_range(-4, 4), 30, 95), "dfn": clampi(base[3] + q + rng.randi_range(-4, 4), 25, 95), "ab": []}
	nw["pot"] = clampi(ovr_of(nw) + rng.randi_range(4, 12), ovr_of(nw), 94)
	return nw

# A bigger club in your country buys the best man of a smaller one.
func _cpu_deal(rng: RandomNumberGenerator, day: int) -> Array:
	var cl := _country_clubs()
	if cl.size() < 4:
		return []
	for tries in 14:
		var buyer: int = cl[rng.randi() % cl.size()]
		var rb := rating(buyer)
		var sellers := []
		for x in cl:
			if rating(x) < rb and rating(x) >= rb - 12:
				sellers.append(x)
		if sellers.is_empty():
			continue
		if rng.randf() < 0.3:
			# now and then the man comes from a club abroad
			var fs := []
			for x in _world_clubs():
				if rating(x) < rb and rating(x) >= rb - 8 and not cl.has(x):
					fs.append(x)
			if not fs.is_empty():
				sellers = fs
		var seller: int = sellers[rng.randi() % sellers.size()]
		var ssq: Array = cpu_squad(seller).duplicate(true)
		var bsq: Array = cpu_squad(buyer).duplicate(true)
		var top := range(ssq.size())
		top.sort_custom(func(p, q): return ovr_of(ssq[p]) > ovr_of(ssq[q]))
		var i: int = top[rng.randi() % mini(4, top.size())]
		for k2 in ssq.size():
			# a man you sold with a sell-on share is watched by bigger clubs
			if ssq[k2].has("so") and rng.randf() < 0.5:
				i = k2
		var pl: Dictionary = ssq[i]
		if str(pl["pos"]) == "GK" and rng.randf() < 0.7:
			continue
		var j := -1
		for k in bsq.size():
			if str(bsq[k]["pos"]) == str(pl["pos"]) and (j < 0 or ovr_of(bsq[k]) < ovr_of(bsq[j])):
				j = k
		if j < 0 or ovr_of(pl) <= ovr_of(bsq[j]):
			continue
		var fee := int(round(value(pl) * rng.randf_range(1.05, 1.5) / 5.0)) * 5
		var moved: Dictionary = pl.duplicate(true)
		moved["num"] = int(bsq[j]["num"])
		if moved.has("so"):
			var share := int(round(fee * int(moved["so"]) / 100.0 / 5.0)) * 5
			moved.erase("so")
			d["coins"] = int(d["coins"]) + share
			_mail("info", "Sell-on money: %s" % money(share), "%s sold %s to %s for %s. Your %d%% share is %s, and it is in your transfer budget." % [str(cname(seller)).capitalize(), str(pl["n"]).capitalize(), str(cname(buyer)).capitalize(), money(fee), SELLON_PCT, money(share)])
		bsq[j] = moved
		ssq[i] = _fill_in(seller, str(pl["pos"]), int(pl["num"]), rng)
		_set_cpu_squad(buyer, bsq)
		_set_cpu_squad(seller, ssq)
		var x := [day, str(pl["n"]), str(pl["pos"]), ovr_of(pl), int(pl["age"]), seller, buyer, fee]
		var dl: Array = deals()
		dl.push_front(x)
		while dl.size() > DEALS_MAX:
			dl.pop_back()
		d["deals"] = dl
		return x
	return []

func _sq_find(pn: String) -> int:
	var sq: Array = d["squad"]
	for i in sq.size():
		if str(sq[i]["n"]) == pn:
			return i
	return -1

# A club wants one of your men: good men, young men with a future, and above all anyone who asked to leave.
func _cpu_bid(rng: RandomNumberGenerator, lines: Array, force := -1) -> void:
	var sq: Array = d["squad"]
	if sq.size() <= SQUAD_MIN and force < 0:
		return
	var open := []
	for m in inbox():
		if str(m["k"]) == "bid" and str(m.get("st", "")) == "open":
			open.append(str(m["pn"]))
	var best := -1
	var bw := -1.0
	for i in sq.size():
		var pl: Dictionary = sq[i]
		if open.has(str(pl["n"])):
			continue
		var wv := value(pl) * rng.randf_range(0.5, 1.5) * (2.5 if pl.has("tr") else 1.0) * (0.4 + pform(pl) / 70.0)
		if wv > bw:
			bw = wv
			best = i
	if force >= 0:
		best = force
	if best < 0:
		return
	var pl: Dictionary = sq[best]
	var o := ovr_of(pl)
	var cand := []
	for c in _country_clubs():
		if c == int(d["club"]):
			continue
		if force >= 0:
			# a listed man: any club around his level can be the buyer
			if rating(c) >= o - 8 and rating(c) <= o + 6:
				cand.append(c)
		elif rating(c) >= maxi(o - 3, int(my_strength()) - 2) and rating(c) <= maxi(o, int(my_strength())) + 8:
			cand.append(c)
	if cand.is_empty():
		return
	var c: int = cand[rng.randi() % cand.size()]
	# a man you have listed is cheaper: they know you want to sell
	var amt := int(round(value(pl) * (rng.randf_range(0.7, 1.0) if listed(pl) else rng.randf_range(0.8, 1.25)) * (0.85 + pform(pl) * 0.003) / 5.0)) * 5
	_mail("bid", "%s bid for %s" % [str(cname(c)).capitalize(), str(pl["n"]).capitalize()],
		"%s want %s (%s, %d, age %d) and offer %s. Their scouts say his form is %s. The offer stands for two matches." % [str(cname(c)).capitalize(), str(pl["n"]).capitalize(), str(pl["pos"]), o, int(pl["age"]), money(amt), form_name(pform(pl)).to_lower()],
		{"c": c, "pn": str(pl["n"]), "amt": amt, "st": "open", "left": 1, "cnt": 0})
	lines.append("%s HAVE BID %s FOR %s" % [str(cname(c)), money(amt), str(pl["n"]).to_upper()])

# You answer a bid: "acc" sell, "rej" say no, "more" ask for more (once). Returns what happened.
func bid_answer(id: int, what: String) -> String:
	var m := mail(id)
	if m.is_empty() or str(m.get("st", "")) != "open":
		return ""
	m["rd"] = true
	var i := _sq_find(str(m["pn"]))
	if i < 0:
		m["st"] = "gone"
		save()
		return "He is not at the club any more."
	var pl: Dictionary = d["squad"][i]
	var c := int(m["c"])
	var amt := int(m["amt"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if what == "acc":
		if (d["squad"] as Array).size() <= SQUAD_MIN:
			return "You need at least %d players." % SQUAD_MIN
		_out_of_xi(i)
		m["st"] = "acc"
		var r := _sell_to(i, c, amt)
		_mail("info", "Deal done", r.capitalize())
		return r
	if what == "son":
		# sell, but keep a share of his next transfer: they pay a little less now
		if (d["squad"] as Array).size() <= SQUAD_MIN:
			return "You need at least %d players." % SQUAD_MIN
		_out_of_xi(i)
		m["st"] = "acc"
		pl["so"] = SELLON_PCT
		var got := int(round(amt * SELLON_CUT / 5.0)) * 5
		var r2 := _sell_to(i, c, got)
		_mail("info", "Deal done, with a sell-on", "%s. You get %d%% of the fee when %s sell him on." % [r2.capitalize(), SELLON_PCT, str(cname(c)).capitalize()])
		return r2 + "  ·  %d%% SELL-ON" % SELLON_PCT
	if what == "rej":
		m["st"] = "rej"
		if rating(c) > int(my_strength()) + 2 and full():
			# a bigger club wanted him: he is not happy you said no
			pl["mo"] = clampi(int(pl.get("mo", 65)) - 12, 5, 100)
			save()
			return "%s is upset: he wanted the move to %s." % [str(pl["n"]).capitalize(), str(cname(c)).capitalize()]
		save()
		return "You turned the bid down."
	if what == "more":
		if int(m.get("cnt", 0)) >= 1:
			return "They will not go higher."
		m["cnt"] = 1
		var ch := 0.7 if amt < value(pl) * 1.1 else 0.4
		if rng.randf() < ch:
			m["amt"] = int(round(amt * rng.randf_range(1.1, 1.25) / 5.0)) * 5
			save()
			return "%s raise the bid to %s." % [str(cname(c)).capitalize(), money(int(m["amt"]))]
		m["st"] = "gone"
		save()
		return "%s walk away." % str(cname(c)).capitalize()
	return ""

# take a man out of the eleven: the best one on the bench in his position (or any outfield man) takes his place
func _out_of_xi(i: int) -> void:
	var xi: Array = d["xi"]
	var at := -1
	for k in xi.size():
		if int(xi[k]) == i:
			at = k
	if at < 0:
		return
	var sq: Array = d["squad"]
	var sr := slot_roles()
	var pos := str(sr[at]) if at < sr.size() else str(sq[i]["pos"])
	var best := -1
	for pass_n in 2:
		for j in sq.size():
			if j == i or xi.has(j) or injured(sq[j]) or (pass_n == 0 and not plays(sq[j], pos)) or (pass_n == 1 and str(sq[j]["pos"]) == "GK"):
				continue
			if best < 0 or ovr_of(sq[j]) > ovr_of(sq[best]):
				best = j
		if best >= 0:
			break
	if best >= 0:
		xi[at] = best
	d["xi"] = xi


# ---------------------------------------------------------------- fitness, injuries and rotation (the career)
# Every man has a fitness (0-100). A full match takes about a quarter of it, a few days' rest gives it back (faster
# with a better training ground). A tired man plays slower and gets hurt more easily, so in a busy week you rotate.
const INJ := [["a knock", 3, 7, 50], ["a hamstring strain", 10, 21, 30], ["an ankle injury", 14, 35, 15], ["a knee injury", 45, 100, 5]]

func rec_rate() -> float:
	return 4.8 + 0.5 * (fac("training") - 1)

# his fitness on the eve of your next match
func cond_of(pl: Dictionary) -> int:
	var c := float(pl.get("cond", 100))
	var since := int(pl.get("cday", -999))
	if since == -999:
		return int(c)
	return clampi(int(round(c + maxi(now() - since, 0) * rec_rate())), 0, 100)

func injured(pl: Dictionary) -> bool:
	return int(pl.get("inj", -999)) > now()

func inj_text(pl: Dictionary) -> String:
	return "%s, back on %s" % [str(pl.get("injn", "injured")), date_text(int(pl.get("inj", 0)), true)]

# your eleven's strength with tired legs counted (for a simulated match)
func match_strength() -> float:
	var s := 0.0
	var roles := slot_roles()
	for k in (d["xi"] as Array).size():
		var pl: Dictionary = d["squad"][int(d["xi"][k])]
		s += (ovr_of(pl) + pos_off(pl, str(roles[k]) if k < roles.size() else "")) * (0.86 + 0.14 * cond_of(pl) / 100.0) * (0.6 if injured(pl) else 1.0)
	return s / 11.0

# before a match: everyone's fitness as it is on the day; returns {index: fitness}
func _fit_pre() -> Dictionary:
	var out := {}
	if bool(d.get("cupmode", false)):
		return out
	var t := now()
	var sq: Array = d["squad"]
	for i in sq.size():
		var pl: Dictionary = sq[i]
		var c := cond_of(pl)
		pl["cond"] = c
		pl["cday"] = t
		out[i] = c
	return out

# after it: the men who played are tired (a sub less so), and a tired man gets hurt more easily
func _fit_post(fit0: Dictionary, played: Array, lines: Array, rng: RandomNumberGenerator) -> void:
	if fit0.is_empty():
		return
	var sq: Array = d["squad"]
	var xi: Array = (d["xi"] as Array).duplicate()
	var who := []
	for x in (played if not played.is_empty() else xi):
		if not who.has(int(x)) and int(x) < sq.size():
			who.append(int(x))
	for i in who:
		var pl: Dictionary = sq[i]
		var full_m := xi.has(i)
		var drain := (25.0 + maxf(int(pl["age"]) - 28, 0) * 1.2) if full_m else 10.0
		# a high press runs the legs off them, a low block saves a little
		drain *= [0.9, 1.0, 1.22][clampi(int(tac()[1]), 0, 2)]
		if ab_of(pl).has("motor"):
			drain *= 0.75
		if str(pl["pos"]) == "GK":
			drain *= 0.4
		var c0 := int(fit0.get(i, 100))
		pl["cond"] = maxi(int(round(c0 - drain * rng.randf_range(0.85, 1.15))), 15)
		# the risk of an injury: small when fresh, much bigger when he started tired
		var risk := 0.008 + maxf(75 - c0, 0) * 0.0016
		if not full_m:
			risk *= 0.5
		if rng.randf() < risk:
			var tot := 0
			for k in INJ:
				tot += int(k[3])
			var r := rng.randi() % tot
			var kind: Array = INJ[0]
			for k in INJ:
				r -= int(k[3])
				if r < 0:
					kind = k
					break
			var days := rng.randi_range(int(kind[1]), int(kind[2]))
			pl["inj"] = int(pl.get("cday", now())) + days
			pl["injn"] = str(kind[0])
			var wk := int(round(days / 7.0))
			var howlong := ("about %d week%s" % [wk, "" if wk == 1 else "s"]) if wk >= 1 else "a few days"
			lines.append("%s IS INJURED: %s, OUT FOR %s" % [str(pl["n"]).to_upper(), str(kind[0]).to_upper(), howlong.to_upper()])
			_mail("med", "%s is injured" % str(pl["n"]).capitalize(), "The medical team: %s has %s. He is out for %s, until %s." % [str(pl["n"]).capitalize(), str(kind[0]), howlong, date_text(int(pl["inj"]), true)])
	# an injured man leaves the eleven: the best fit man in his position takes his place
	for i in sq.size():
		if injured(sq[i]) and (d["xi"] as Array).has(i):
			_out_of_xi(i)

# ---------------------------------------------------------------- top scorers, awards, the trophy cabinet and records
# Every league goal has a scorer (the computer clubs' too), so there is a real top scorers list. Each month the
# league names a player and a manager of the month; at the end of the season the big awards. What your club wins
# goes in the trophy cabinet, and the club keeps its records.

func _goal_key(c: int, n: String) -> String:
	return "%d:%s" % [c, n]

func _goal_add(c: int, pl: Dictionary) -> void:
	var gs: Dictionary = d.get("gs", {})
	var k := _goal_key(c, str(pl["n"]))
	var e: Array = gs.get(k, [0, c, str(pl["n"]), str(pl["pos"]), int(pl.get("age", 25))])
	e[0] = int(e[0]) + 1
	gs[k] = e
	d["gs"] = gs
	var mg: Dictionary = d.get("mg", {})
	mg[k] = int(mg.get(k, 0)) + 1
	d["mg"] = mg

func _goal_cpu(c: int, rng: RandomNumberGenerator) -> void:
	var sq := cpu_squad(c)
	var pool := []
	var wsum := 0.0
	for i in mini(11, sq.size()):
		var pl: Dictionary = sq[i]
		var wv: float = float({"FW": 6, "MF": 2.5, "DF": 0.7}.get(str(pl["pos"]), 0.0)) * pow(int(pl["sho"]) / 60.0, 2.0)
		pool.append([wv, pl])
		wsum += wv
	var r := rng.randf() * wsum
	for x in pool:
		r -= float(x[0])
		if r <= 0.0:
			_goal_add(c, x[1])
			return

func _month_pts(a: int, b: int, ga: int, gb: int) -> void:
	var mp: Dictionary = d.get("mp", {})
	mp[str(a)] = int(mp.get(str(a), 0)) + (3 if ga > gb else (1 if ga == gb else 0))
	mp[str(b)] = int(mp.get(str(b), 0)) + (3 if gb > ga else (1 if ga == gb else 0))
	d["mp"] = mp
	if int(d.get("mon", -1)) < 0:
		d["mon"] = int(date_of(lg_day(int(d["round"])))["m"])

# [[goals, club, name, pos, age], ...] best first
func scorers_top(n := 20) -> Array:
	var out := []
	for k in (d.get("gs", {}) as Dictionary):
		out.append(d["gs"][k])
	var rk := _ranks()
	out.sort_custom(func(a, b): return int(a[0]) > int(b[0]) if int(a[0]) != int(b[0]) else int(rk.get(int(a[1]), 99)) < int(rk.get(int(b[1]), 99)))
	return out.slice(0, n)

func _ranks() -> Dictionary:
	var rk := {}
	var o := order()
	for i in o.size():
		rk[int(o[i])] = i + 1
	return rk

func awards() -> Array:
	return d.get("aw", [])

func cabinet() -> Array:
	return d.get("cab", [])

func records() -> Dictionary:
	return d.get("rec", {})

func _honour(k: String, t: String) -> void:
	var cb: Array = cabinet()
	cb.append([int(d.get("season", 1)), k, t])
	d["cab"] = cb

func _award(k: String, title: String, c: int, n: String, v: String, lines: Array) -> void:
	var aw: Array = awards()
	aw.append({"k": k, "t": title, "c": c, "n": n, "v": v})
	d["aw"] = aw
	var mine := c == int(d["club"])
	var who := ("%s (%s)" % [n.capitalize(), str(cname(c)).capitalize()]) if n != "" else str(cname(c)).capitalize()
	if mine:
		_honour(k, "%s: %s" % [title, n.capitalize() if n != "" else "you"])
		lines.append("%s: %s!" % [title.to_upper(), (n.to_upper() if n != "" else "YOU")])
	_mail("award", "%s: %s" % [title, who], ("%s. " % v) + ("Well done!" if mine else ""), {"mine": mine})

func _month_awards(lines: Array) -> void:
	var mo := int(d.get("mon", -1))
	if mo < 0:
		return
	var nm := int(date_of(now())["m"])
	if nm == mo and not season_over():
		return
	var mname: String = MONTHS[mo - 1]
	var mg: Dictionary = d.get("mg", {})
	var gs: Dictionary = d.get("gs", {})
	var rk := _ranks()
	var best := ""
	for k in mg:
		if not gs.has(k):
			continue
		if best == "" or int(mg[k]) > int(mg[best]) or (int(mg[k]) == int(mg[best]) and int(rk.get(int(gs[k][1]), 99)) < int(rk.get(int(gs[best][1]), 99))):
			best = k
	if best != "" and int(mg[best]) >= 2:
		var e: Array = gs[best]
		_award("potm", "%s Player of the Month" % mname, int(e[1]), str(e[2]), "%d goals in %s" % [int(mg[best]), mname], lines)
		if int(e[1]) == int(d["club"]):
			var i := _sq_find(str(e[2]))
			if i >= 0:
				d["squad"][i]["mo"] = clampi(int(d["squad"][i].get("mo", 65)) + 10, 5, 100)
	var mp: Dictionary = d.get("mp", {})
	var bc := -1
	for k in mp:
		if not rk.has(int(k)):
			continue
		if bc < 0 or int(mp[k]) > int(mp[str(bc)]) or (int(mp[k]) == int(mp[str(bc)]) and int(rk[int(k)]) < int(rk[bc])):
			bc = int(k)
	if bc >= 0 and int(mp[str(bc)]) >= 6:
		_award("motm", "%s Manager of the Month" % mname, bc, "", "%d points in %s" % [int(mp[str(bc)]), mname], lines)
		if bc == int(d["club"]):
			_conf_add(3)
	d["mg"] = {}
	d["mp"] = {}
	d["mon"] = -1 if season_over() else nm

func _season_awards(lines: Array) -> void:
	_month_awards(lines)
	var top := scorers_top(60)
	if top.is_empty():
		return
	var e: Array = top[0]
	_award("boot", "Golden Boot", int(e[1]), str(e[2]), "%d league goals" % int(e[0]), lines)
	# player of the season: goals, and how high his club finished
	var n := ids().size()
	var rk2 := _ranks()
	var best: Array = []
	var bs := -1.0
	var young: Array = []
	var ys := -1.0
	for x in top:
		var sc := int(x[0]) * 2.0 + float(n - int(rk2.get(int(x[1]), n))) * 0.6 + (2.0 if str(x[3]) != "FW" else 0.0)
		if sc > bs:
			bs = sc
			best = x
	for pass_n in 2:
		for x in top:
			var sc2 := int(x[0]) * 2.0 + float(n - int(rk2.get(int(x[1]), n))) * 0.6 + (2.0 if str(x[3]) != "FW" else 0.0)
			if int(x[4]) <= 21 and sc2 > ys and (pass_n == 1 or x != best):
				ys = sc2
				young = x
		if not young.is_empty():
			break
	if not best.is_empty():
		_award("pots", "Player of the Season", int(best[1]), str(best[2]), "%d goals for the %s-placed club" % [int(best[0]), ordinal(rank_of(int(best[1]))).to_lower()], lines)
	if not young.is_empty():
		_award("ypots", "Young Player of the Season", int(young[1]), str(young[2]), "%d goals at %d" % [int(young[0]), int(young[4])], lines)
	# manager of the season: the club that did most against what was expected of it
	var by_r := ids()
	by_r.sort_custom(func(a, b): return rating(a) > rating(b))
	var mc := -1
	var mv := -99.0
	for c in ids():
		var over := float(by_r.find(c) + 1 - rank_of(c)) + (3.0 if rank_of(c) == 1 else 0.0)
		if c == int(d["club"]):
			over = float(expected_rank() - rank_of(c)) + (3.0 if rank_of(c) == 1 else 0.0)
		if over > mv:
			mv = over
			mc = c
	if mc >= 0:
		_award("mots", "Manager of the Season", mc, "", "%s, expected around %s" % [ordinal(rank_of(mc)).to_lower() + " place", ordinal(by_r.find(mc) + 1).to_lower()], lines)

# ---- records
func _rec_set(k: String, v: Array) -> void:
	var r: Dictionary = records()
	r[k] = v
	d["rec"] = r

func _rec_result(mine: int, theirs: int, opp: int, cup_t: bool) -> void:
	var r: Dictionary = records()
	var gd := mine - theirs
	var txt := "%d-%d v %s, season %d%s" % [mine, theirs, str(cname(opp)).capitalize() if opp >= 0 else "?", int(d.get("season", 1)), " (cup)" if cup_t else ""]
	if gd > 0 and (not r.has("bw") or gd > int(r["bw"][0]) or (gd == int(r["bw"][0]) and mine > int(r["bw"][2]))):
		_rec_set("bw", [gd, txt, mine])
	if gd < 0 and (not r.has("bl") or -gd > int(r["bl"][0])):
		_rec_set("bl", [-gd, txt, theirs])
	var run := (int(r.get("run", 0)) + 1) if gd >= 0 else 0
	r = records()
	r["run"] = run
	d["rec"] = r
	if run > int((records().get("unb", [0]) as Array)[0]):
		_rec_set("unb", [run, "%d matches without a defeat, season %d" % [run, int(d.get("season", 1))]])

func _rec_player(pl: Dictionary) -> void:
	var r: Dictionary = records()
	if int(pl.get("cg", 0)) > 0 and int(pl.get("cg", 0)) > int((r.get("cg", [0]) as Array)[0]):
		_rec_set("cg", [int(pl["cg"]), str(pl["n"])])
	if int(pl.get("ca", 0)) > int((r.get("ca", [0]) as Array)[0]):
		_rec_set("ca", [int(pl["ca"]), str(pl["n"])])
	if int(pl["g"]) > int((r.get("sg", [0]) as Array)[0]):
		_rec_set("sg", [int(pl["g"]), str(pl["n"]), int(d.get("season", 1))])

func _rec_fee(k: String, fee: int, n: String) -> void:
	if fee > int((records().get(k, [0]) as Array)[0]):
		_rec_set(k, [fee, n, int(d.get("season", 1))])

func _rec_season(pos: int) -> void:
	var t := div()
	var r: Dictionary = records()
	var bf: Array = r.get("bf", [99, 99])
	if t < int(bf[0]) or (t == int(bf[0]) and pos < int(bf[1])):
		_rec_set("bf", [t, pos, "%s in %s, season %d" % [ordinal(pos).to_lower(), league_name().capitalize(), int(d.get("season", 1))]])
	var pts := int(d["table"][str(int(d["club"]))]["pts"])
	if pts > int((r.get("pts", [0]) as Array)[0]):
		_rec_set("pts", [pts, "%s, season %d" % [league_name().capitalize(), int(d.get("season", 1))]])


# ---------------------------------------------------------------- the Champions Cup: Europe's big cup
# 32 clubs: England's top four, Denmark's top two and 26 clubs from the rest of Europe. Eight groups of four
# (home and away, top two go through), then the last 16, quarter-finals, semi-finals and a final, one match each,
# with extra time and penalties. The European nights are Tuesdays, never in a week with a domestic cup tie.
const EU_NAME := "THE CHAMPIONS CUP"
# Europe has two cups, as in real life: the Champions Cup for the very best, the Euro Trophy (Thursday nights) for
# the clubs just under them. England's 5th to 7th, Denmark's 3rd to 5th and a club that won its domestic cup go there.
const EU_NAMES := ["THE CHAMPIONS CUP", "THE EURO TROPHY"]
const EU_PAY_K := [1.0, 0.45]
const EU_RD := ["GROUP STAGE", "GROUP STAGE", "GROUP STAGE", "GROUP STAGE", "GROUP STAGE", "GROUP STAGE", "LAST 16", "QUARTER-FINAL", "SEMI-FINAL", "FINAL"]
const EU_FR := [0.10, 0.17, 0.24, 0.31, 0.38, 0.45, 0.60, 0.70, 0.80, 0.93]
const EU_GS := [[[0, 1], [2, 3]], [[2, 0], [1, 3]], [[0, 3], [2, 1]], [[1, 0], [3, 2]], [[0, 2], [3, 1]], [[3, 0], [1, 2]]]
const EU_PAY := {"start": 300, "win": 50, "draw": 20, "ko": [120, 200, 320, 600]}

func eu() -> Dictionary:
	return d.get("eu", {})

# which of the two cups you are in this season (0 = Champions Cup, 1 = Euro Trophy)
func eu_k() -> int:
	return clampi(int(eu().get("k", 0)), 0, 1)

func eu_name() -> String:
	return EU_NAMES[eu_k()]

func eu_round_name(md := -1) -> String:
	var e := eu()
	var m := int(e.get("md", 0)) if md < 0 else md
	if m < 6:
		return "GROUP %s, MATCHDAY %d" % [str(e.get("gl", "A")), m + 1] if md < 0 or m == int(e.get("md", 0)) else "GROUP STAGE, MATCHDAY %d" % (m + 1)
	return EU_RD[clampi(m, 0, EU_RD.size() - 1)]

# which league round each European night comes after (never the same week as a cup tie)
func eu_after(md: int) -> int:
	var n := rounds_total()
	var r := clampi(int(round(n * EU_FR[clampi(md, 0, EU_FR.size() - 1)])), 1, n - 1)
	for k in 3:
		var clash := false
		for cr in cup_rounds():
			if cup_after_r(cr) == r:
				clash = true
		if not clash:
			break
		r = mini(r + 1, n - 1)
	return r

# a Tuesday (Champions Cup) or a Thursday (Euro Trophy) after that league round
func eu_day(md: int) -> int:
	return lg_day(eu_after(md) - 1) + (3 if eu_k() == 0 else 5)

func eu_due_ever() -> bool:
	var e := eu()
	return not e.is_empty() and bool(e.get("me", false)) and not bool(e.get("out", false)) and not bool(e.get("done", false))

func eu_due() -> bool:
	if not eu_due_ever() or bool(d.get("cupmode", false)):
		return false
	return int(d["round"]) >= eu_after(int(eu()["md"]))

func eu_ko() -> bool:
	return int(eu().get("md", 0)) >= 6

# [opponent, you at home]
func eu_opp() -> Array:
	var e := eu()
	var md := int(e.get("md", 0))
	var me := int(d["club"])
	if md < 6:
		for g in e["grp"]:
			for pr in EU_GS[md]:
				if int(g[pr[0]]) == me:
					return [int(g[pr[1]]), true]
				if int(g[pr[1]]) == me:
					return [int(g[pr[0]]), false]
		return [-1, true]
	for t in e.get("ko", []):
		if int(t[0]) == me:
			return [int(t[1]), true]
		if int(t[1]) == me:
			return [int(t[0]), md == 9] # the final is played as our home night
	return [-1, true]

# The places in Europe, by each league's own number (ClubDB eu and eu2): the clubs at the top of each top league
# go to the Champions Cup, the next ones to the Euro Trophy. fin = the final tables (empty = by strength, at the start).
func _eu_lists(fin: Array) -> Array:
	var q1 := []
	var q2 := []
	for li in ClubDB.LEAGUES.size():
		var L: Dictionary = ClubDB.LEAGUES[li]
		var n1 := int(L.get("eu", 0))
		var n2 := int(L.get("eu2", 0))
		if n1 + n2 <= 0:
			continue
		var cl: Array
		if fin.size() == ClubDB.LEAGUES.size():
			cl = []
			for c in fin[li]:
				cl.append(int(c))
		else:
			cl = ids(li)
			cl.sort_custom(func(x, y): return _strength(x) > _strength(y))
		q1.append_array(cl.slice(0, n1))
		q2.append_array(cl.slice(n1, n1 + n2))
	return [q1, q2]

func _eu_quals_by_rating() -> Array:
	return _eu_lists([])[0]

func _eu_quals_final() -> Array:
	return _eu_lists(d.get("final", []))[0]

# the Euro Trophy: the next ones down
func _eu2_quals_by_rating() -> Array:
	return _eu_lists([])[1]

func _eu2_quals_final(cup_won: bool) -> Array:
	var out: Array = _eu_lists(d.get("final", []))[1]
	# the domestic cup winner plays in Europe too, whatever league he is in
	var me := int(d["club"])
	if cup_won and not out.has(me) and not _eu_quals_final().has(me):
		out[out.size() - 1] = me
	return out

# this season's European place: the Champions Cup if you qualified, else the Euro Trophy, else nothing
func eu_start(q1: Array, q2: Array) -> void:
	if q1.has(int(d["club"])):
		eu_new(q1, 0)
	else:
		eu_new(q2, 1, q1)

# a new Champions Cup for this season; it only runs when your club is in it
func eu_new(quals: Array, k := 0, other: Array = []) -> void:
	var me := int(d["club"])
	if bool(d.get("cupmode", false)) or not quals.has(me):
		d.erase("eu")
		return
	var all := quals.duplicate()
	# the best of Europe play in the Champions Cup, the next ones in the Euro Trophy
	var fo := []
	for c in ClubDB.foreign_ids(FIRST):
		if c < W.size():
			fo.append(c)
	fo.sort_custom(func(a, b): return int(W[a]["r"]) > int(W[b]["r"]))
	# the clubs from the smaller countries fill the places left: the best of them in the Champions Cup
	var skip := maxi(32 - other.size(), 0) if k == 1 else 0
	for c in fo.slice(skip):
		if all.size() >= 32:
			break
		if not all.has(c) and not other.has(c):
			all.append(c)
	if all.size() < 32:
		# still room: the next clubs of the top leagues, best first
		var more := []
		for li in ClubDB.LEAGUES.size():
			if int(ClubDB.LEAGUES[li]["t"]) == 1:
				for c in ids(li):
					if not all.has(c) and not other.has(c):
						more.append(c)
		more.sort_custom(func(a, b): return rating(a) > rating(b))
		for c in more:
			if all.size() >= 32:
				break
			all.append(c)
	# four pots by strength; each group gets one club from each pot, never two from the same country
	all.sort_custom(func(a, b): return rating(a) > rating(b))
	var grp := []
	for g in 8:
		grp.append([])
	for pot in 4:
		var pc: Array = all.slice(pot * 8, pot * 8 + 8)
		pc.shuffle()
		for c in pc:
			var placed := false
			var order := range(8)
			order.shuffle()
			for g in order:
				if (grp[g] as Array).size() == pot and not _eu_same_country(grp[g], c):
					grp[g].append(c)
					placed = true
					break
			if not placed:
				for g in order:
					if (grp[g] as Array).size() == pot:
						grp[g].append(c)
						break
	var gt := {}
	for c in all:
		gt[str(int(c))] = [0, 0, 0, 0, 0, 0, 0]
	var gl := "A"
	for g in 8:
		if (grp[g] as Array).has(me):
			gl = "ABCDEFGH"[g]
	d["eu"] = {"grp": grp, "gt": gt, "md": 0, "ko": [], "log": [], "out": false, "done": false, "me": true, "gl": gl, "won": false, "win": -1, "k": k}
	var st0 := int(round(EU_PAY["start"] * EU_PAY_K[k]))
	d["coins"] = int(d["coins"]) + st0
	if k == 0:
		_mail("eu", "You are in %s" % eu_name().capitalize(), "Your club has a place in Europe's big cup: group %s. The European nights are Tuesdays. A start bonus of %s is in your budget." % [gl, money(st0)])
	else:
		_mail("eu", "You are in %s" % eu_name().capitalize(), "Your club plays in Europe's second cup: group %s. The Euro Trophy nights are Thursdays. Finish in the top four of the league for the Champions Cup. A start bonus of %s is in your budget." % [gl, money(st0)])

func _eu_country(c: int) -> String:
	if W[c].has("c"):
		return str(W[c]["c"])
	var li := league_of(c)
	return str(ClubDB.LEAGUES[li]["c"]) if li >= 0 else ""

func _eu_same_country(g: Array, c: int) -> bool:
	for x in g:
		if _eu_country(int(x)) == _eu_country(c):
			return true
	return false

func _eu_sim(rng: RandomNumberGenerator, a: int, b: int, need_winner: bool) -> Array:
	var df := (_strength(a) - _strength(b)) / 14.0 + 0.1
	var ga := _poisson(rng, 1.3 * exp(df))
	var gb := _poisson(rng, 1.3 * exp(-df))
	var w := -1
	if need_winner:
		w = a if ga > gb else (b if gb > ga else (a if rng.randf() < 0.5 + df * 0.1 else b))
	return [ga, gb, w]

func _eu_book(a: int, b: int, ga: int, gb: int) -> void:
	var gt: Dictionary = eu()["gt"]
	for k in [[a, ga, gb], [b, gb, ga]]:
		var r: Array = gt[str(int(k[0]))]
		r[0] += 1
		r[4] += int(k[1])
		r[5] += int(k[2])
		if int(k[1]) > int(k[2]):
			r[1] += 1
			r[6] += 3
		elif int(k[1]) == int(k[2]):
			r[2] += 1
			r[6] += 1
		else:
			r[3] += 1

# one group in table order
func eu_group(g: int) -> Array:
	var e := eu()
	var gt: Dictionary = e["gt"]
	var cl: Array = (e["grp"][g] as Array).duplicate()
	cl.sort_custom(func(a, b):
		var ra: Array = gt[str(int(a))]
		var rb: Array = gt[str(int(b))]
		var ka := [int(ra[6]), int(ra[4]) - int(ra[5]), int(ra[4])]
		var kb := [int(rb[6]), int(rb[4]) - int(rb[5]), int(rb[4])]
		return ka > kb if ka != kb else rating(a) > rating(b))
	return cl

# Play out one European night: your match as given, the rest by strength.
func _eu_night(mine: int, theirs: int, won_tie: bool, rng: RandomNumberGenerator, lines: Array) -> void:
	var e := eu()
	var md := int(e["md"])
	var me := int(d["club"])
	var log := []
	if md < 6:
		for g in e["grp"]:
			for pr in EU_GS[md]:
				var a := int(g[pr[0]])
				var b := int(g[pr[1]])
				var r: Array
				if mine >= 0 and (a == me or b == me):
					r = [mine if a == me else theirs, theirs if a == me else mine, -1]
				else:
					r = _eu_sim(rng, a, b, false)
				_eu_book(a, b, int(r[0]), int(r[1]))
				log.append([a, b, int(r[0]), int(r[1])])
		e["log"].append(log)
		if md == 5:
			# the groups are done: winners meet runners-up from another group, the winner at home
			var w := []
			var ru := []
			for g in 8:
				var o := eu_group(g)
				w.append(o[0])
				ru.append(o[1])
			var ko := []
			for g in 8:
				ko.append([int(w[g]), int(ru[(g + 1) % 8])])
			# no two clubs from the same country in the last 16: swap runners-up between ties
			for i in 8:
				if _eu_country(int(ko[i][0])) == _eu_country(int(ko[i][1])):
					for j in 8:
						if j != i and _eu_country(int(ko[i][0])) != _eu_country(int(ko[j][1])) and _eu_country(int(ko[j][0])) != _eu_country(int(ko[i][1])):
							var tmp := int(ko[i][1])
							ko[i][1] = ko[j][1]
							ko[j][1] = tmp
							break
			e["ko"] = ko
			if bool(e["me"]) and not w.has(me) and not ru.has(me):
				e["out"] = true
				lines.append("OUT OF %s IN THE GROUP STAGE" % eu_name())
			elif bool(e["me"]) and not bool(e["out"]):
				lines.append("THROUGH TO THE LAST 16 OF %s!" % eu_name())
				_eu_pay(0, lines)
	else:
		var nxt := []
		for t in e["ko"]:
			var a := int(t[0])
			var b := int(t[1])
			var r: Array
			if mine >= 0 and (a == me or b == me):
				var gm := mine if a == me else theirs
				var gt2 := theirs if a == me else mine
				var iw := mine > theirs or (mine == theirs and won_tie)
				r = [gm, gt2, me if iw else (b if a == me else a)]
			else:
				r = _eu_sim(rng, a, b, true)
			log.append([a, b, int(r[0]), int(r[1])])
			nxt.append(int(r[2]))
		e["log"].append(log)
		if md == 9:
			e["done"] = true
			e["win"] = int(nxt[0])
			if int(nxt[0]) == me:
				e["won"] = true
				var stt: Dictionary = stats()
				var sk := "eu" if eu_k() == 0 else "eu2"
				stt[sk] = int(stt.get(sk, 0)) + 1
				d["st"] = stt
				_honour("eu" if eu_k() == 0 else "eu2", "Won %s" % eu_name().capitalize())
				lines.append(("CHAMPIONS OF EUROPE! YOU WON %s!" if eu_k() == 0 else "YOU WON %s!") % eu_name())
				_eu_pay(3, lines)
				_conf_add(15)
			else:
				_mail("eu", "%s win %s" % [str(cname(int(nxt[0]))).capitalize(), eu_name().capitalize()], "The final is over.")
		else:
			if mine >= 0 and not nxt.has(me) and bool(e["me"]) and not bool(e["out"]):
				e["out"] = true
				lines.append("OUT OF %s IN THE %s" % [eu_name(), EU_RD[md]])
			elif mine >= 0 and nxt.has(me):
				lines.append("THROUGH TO THE %s OF %s!" % [EU_RD[md + 1], eu_name()])
				_eu_pay(md - 5, lines)
				_conf_add(3)
			var ko2 := []
			for i in range(0, nxt.size() - 1, 2):
				ko2.append([int(nxt[i]), int(nxt[i + 1])])
			e["ko"] = ko2
	e["md"] = md + 1

func _eu_pay(k: int, lines: Array) -> void:
	var p := int(round(EU_PAY["ko"][clampi(k, 0, 3)] * EU_PAY_K[eu_k()]))
	d["coins"] = int(d["coins"]) + p
	lines.append("+%s FROM EUROPE" % money(p))

# once you are out, the rest of the cup is played in a blink and you read who won
func _eu_rest(rng: RandomNumberGenerator, lines: Array) -> void:
	var e := eu()
	while not bool(e.get("done", false)) and int(e["md"]) < EU_RD.size():
		_eu_night(-1, -1, false, rng, lines)

# Your European match is over: book it, pay, grow the men who played, like a cup tie.
func eu_finish(mine: int, theirs: int, won_tie := false) -> Array:
	var fit0 := _fit_pre()
	var e := eu()
	var md := int(e["md"])
	var opp := int(eu_opp()[0])
	d["day"] = eu_day(md)
	d["cur"] = int(d["day"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var lines := []
	var won: bool = mine > theirs or (mine == theirs and won_tie)
	var coins := 0
	if md < 6:
		coins = int(round((EU_PAY["win"] if mine > theirs else (EU_PAY["draw"] if mine == theirs else 0)) * EU_PAY_K[eu_k()]))
	coins += board_bonus(coins)
	d["coins"] = int(d["coins"]) + coins
	last_coins = coins
	lines.append("+" + money(coins))
	_eu_night(mine, theirs, won_tie, rng, lines)
	if md < 6:
		var gi := "ABCDEFGH".find(str(e.get("gl", "A")))
		var o := eu_group(gi)
		lines.append("%s IN GROUP %s" % [ordinal(o.find(int(d["club"])) + 1), str(e.get("gl", "A"))])
	_rec_result(mine, theirs, opp, true)
	for i in d["xi"]:
		var pl: Dictionary = d["squad"][int(i)]
		pl["xp"] = int(pl["xp"]) + (32 if won else 22)
		pl["ca"] = int(pl.get("ca", 0)) + 1
		if eur:
			_grow_auto(pl, rng, lines)
		while int(pl["xp"]) >= 100 and ovr_of(pl) + int(pl.get("tp", 0)) < int(pl["pot"]):
			pl["xp"] = int(pl["xp"]) - 100
			pl["tp"] = int(pl.get("tp", 0)) + 1
			lines.append("%s  +1 TP" % str(pl["n"]).to_upper())
		if int(pl["xp"]) > 100:
			pl["xp"] = 100
	if eur:
		_after_match(d["xi"], won, lines, rng)
	if bool(e.get("out", false)):
		_eu_rest(rng, [])
	_rt_tick(d["xi"], lines)
	_fit_post(fit0, [], lines, rng)
	world_tick(lines)
	save()
	return lines


# ---------------------------------------------------------------- press conferences and promises
# Now and then the press wants a word: after a run of results, before a big night, about your best man or about
# the season. Your answer moves the players' mood, the board's confidence and sometimes one man. A bold answer
# before a big match is remembered: win and the board loves it, lose and it costs. Skip the press and the board
# notices.
# A man who is unhappy about his playing time comes to your office. Promise him matches and you must keep it:
# he has to play in enough of the next matches, or he is angry and asks to leave, and the dressing room sees it.
const PROMISE_N := 5 # matches to keep a promise in
const PROMISE_NEED := 3 # of them he must play

func _team_mood(n: int) -> void:
	for pl in d["squad"]:
		pl["mo"] = clampi(int(pl.get("mo", 65)) + n, 5, 100)

func _streak() -> int:
	return int(d.get("strk", 0))

func _press_tick(rng: RandomNumberGenerator, lines: Array) -> void:
	# an old press conference you did not answer is gone, and the board did not like it
	for m in inbox():
		if str(m["k"]) == "press" and str(m.get("st", "")) == "open":
			m["left"] = int(m.get("left", 1)) - 1
			if int(m["left"]) < 0:
				m["st"] = "gone"
				_conf_add(-1)
	d["pcn"] = int(d.get("pcn", 0)) + 1
	if today() < 0:
		return
	var sk := _streak()
	var q := {}
	var rk := _ranks()
	var last := str(d.get("pclast", ""))
	var gap := int(d["pcn"])
	# the press do not come after every match, and not with the same question twice in a row
	if gap < 2:
		return
	var pos := int(rk.get(int(d["club"]), 0))
	var topic := ""
	if sk <= -3 and last != "bad":
		topic = "bad"
		q = {"t": "Is the job getting to you?", "b": "%d matches without a win. The press want to know if you can turn it round." % (-sk),
			"o": [["We will fight our way out of this. Together.", {"tm": 3}, "The players liked hearing it."],
				["The players have to look at themselves.", {"tm": -5, "bd": 3}, "The board liked it. The dressing room did not."],
				["It is on me. I take full responsibility.", {"tm": 4, "bd": -1}, "The players stand by you. The board is less sure."]]}
	elif sk >= 3 and last != "good":
		topic = "good"
		var aim := "the title" if pos <= 3 else "promotion" if int(league().get("up", 0)) > 0 and pos <= int(league()["up"]) + 2 else "the top half"
		q = {"t": "Are you going for %s?" % aim, "b": "%d wins in a row. The press smell something big." % sk,
			"o": [["Yes. We are going for %s." % aim, {"tm": 4, "bd": 2}, "Big words. The players are fired up."],
				["One match at a time.", {"tm": 1}, "A calm answer. Nothing changes."],
				["The others are still the favourites.", {"tm": -2, "bd": -1}, "The players wanted more belief from you."]]}
	elif _next_derby() and last != "derby":
		topic = "derby"
		var dn := str(cname(_next_opp())).capitalize()
		q = {"t": "Derby week: %s" % dn, "b": "The whole town talks about one match. The press want to hear what the derby against %s means to you." % dn,
			"o": [["We own this town. We will win.", {"tm": 4, "bold": 1, "fan": 1}, "The fans went wild. Now you have to win it."],
				["It is three points like any other.", {"tm": -1}, "Calm, but the fans wanted fire."],
				["The fans deserve a win. We will give everything.", {"tm": 2, "fan": 1}, "The fans and the players loved it."]]}
	elif (eu_due() and eu_ko()) or cup_due():
		topic = "big"
		var what := ("%s, %s" % [eu_name().capitalize(), eu_round_name().capitalize()]) if eu_due() else "the cup tie"
		q = {"t": "A big night: %s" % what, "b": "The press ask what your message is to the players before %s." % what,
			"o": [["We fear nobody. We go there to win.", {"tm": 4, "bold": 1}, "Bold. Win and the board will love it; lose and they remember."],
				["We are the underdogs. No pressure on us.", {"tm": 1, "bd": 1}, "The pressure is off the players."],
				["The other side is very good. Respect.", {"tm": -1}, "Polite, but a bit flat."]]}
	elif gap >= 4 and rng.randf() < 0.55:
		topic = "talk"
		var top := -1
		var sq: Array = d["squad"]
		for i in sq.size():
			if top < 0 or int(sq[i].get("cg", 0)) * 10 + ovr_of(sq[i]) > int(sq[top].get("cg", 0)) * 10 + ovr_of(sq[top]):
				top = i
		if top >= 0 and rng.randf() < 0.5:
			var tn := str(sq[top]["n"]).capitalize()
			q = {"t": "All eyes on %s" % tn, "b": "The press ask about %s: is he the best player in the league?" % tn, "pn": str(sq[top]["n"]),
				"o": [["He is the best. Nobody comes close.", {"pm": 12, "tm": -1}, "%s loved it. A few others felt left out." % tn],
					["He is good, but he must keep working.", {"pm": -3, "tm": 1}, "Fair words. The squad agrees."],
					["I do not talk about one man. We are a team.", {"tm": 2}, "The dressing room liked that."]]}
		else:
			q = {"t": "How is the season going?", "b": "You are %s in %s. The press want your view." % [ordinal(pos).to_lower(), league_name().capitalize()],
				"o": [["We are on track. The plan is working.", {"tm": 2, "bd": 1}, "Calm and sure. Everyone is happy."],
					["We can do much better than this.", {"tm": -2, "bd": 2}, "The board likes the hunger; the players feel the heat."],
					["Thank the fans. They carry us.", {"tm": 1, "fan": 1}, "The fans loved it."]]}
	if q.is_empty():
		return
	d["pcn"] = 0
	d["pclast"] = topic
	for m in inbox():
		if str(m["k"]) == "press" and str(m.get("st", "")) == "open":
			m["st"] = "gone"
	_mail("press", "Press: " + str(q["t"]), str(q["b"]), {"opts": q["o"], "pn": str(q.get("pn", "")), "st": "open", "left": 1})
	lines.append("PRESS CONFERENCE: %s" % str(q["t"]).to_upper())

func _next_opp() -> int:
	if cup_due():
		return cup_opp()
	if eu_due():
		return int(eu_opp()[0])
	if season_over():
		return -1
	return int(next_match()[0])

func _next_derby() -> bool:
	return derby(_next_opp())

# An unhappy man knocks on your door.
func _talk_mail(pl: Dictionary, r: int) -> void:
	var nm := str(pl["n"]).capitalize()
	_mail("talk", "%s wants to talk" % nm, "%s is not happy. He %s, and he is not getting it. What do you tell him?" % [nm, ROLE_WANT[r].to_lower()],
		{"pn": str(pl["n"]), "st": "open", "left": 2, "opts": [
			["I promise you more matches. (%d of the next %d)" % [PROMISE_NEED, PROMISE_N], {"promise": 1, "pm": 15}, "He is happy now. Keep your word: he must play %d of the next %d matches." % [PROMISE_NEED, PROMISE_N]],
			["Fight for your place in training.", {"fight": 1}, ""],
			["If you want to go, I will put you on the transfer list.", {"list": 1, "pm": 5}, "He is on the transfer list. Clubs can bid for him."]]})

# you pick answer `k` in a press conference or a talk
func mail_pick(id: int, k: int) -> String:
	var m := mail(id)
	if m.is_empty() or str(m.get("st", "")) != "open":
		return ""
	var opts: Array = m.get("opts", [])
	if k < 0 or k >= opts.size():
		return ""
	m["rd"] = true
	m["st"] = "done"
	m["ans"] = k
	var fx: Dictionary = opts[k][1]
	var re := str(opts[k][2])
	var i := _sq_find(str(m.get("pn", "")))
	var pl: Dictionary = d["squad"][i] if i >= 0 else {}
	if fx.has("tm"):
		_team_mood(int(fx["tm"]))
	if fx.has("bd"):
		_conf_add(int(fx["bd"]))
	if fx.has("bold"):
		d["bold"] = true
	if fx.has("fan"):
		d["fanbuzz"] = int(d.get("fanbuzz", 0)) + int(fx["fan"])
	if fx.has("join"):
		pro_d()["offer"] = int(m["c"])
		for m2 in inbox():
			if str(m2["k"]) == "pjob" and str(m2.get("st", "")) == "open":
				m2["st"] = "gone"
	if fx.has("nat"):
		nat_take(int(fx["nat"]))
	if fx.has("stay"):
		pro_d()["trust"] = clampi(int(pro_d().get("trust", 50)) + 3, 0, 100)
	if not pl.is_empty():
		if fx.has("pm"):
			pl["mo"] = clampi(int(pl.get("mo", 65)) + int(fx["pm"]), 5, 100)
		if fx.has("promise"):
			pl["pr"] = {"left": PROMISE_N, "a0": int(pl["apps"])}
		if fx.has("list"):
			pl["tl"] = today()
		if fx.has("fight"):
			# a man in good form takes it as a challenge; a man who feels ignored does not
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			if rng.randf() < 0.5 + clampf((65 - int(pl.get("mo", 65))) * -0.01, -0.3, 0.2):
				pl["mo"] = clampi(int(pl.get("mo", 65)) + 6, 5, 100)
				re = "He nods. He will show you in training."
			else:
				pl["mo"] = clampi(int(pl.get("mo", 65)) - 8, 5, 100)
				re = "He walks out without a word. He is angrier than before."
	elif fx.has("pm") or fx.has("promise") or fx.has("list") or fx.has("fight"):
		re = "He is not at the club any more."
	m["re"] = re
	save()
	return re

# after each match: is a promise kept, broken or still running?
func _promise_check(pl: Dictionary, lines: Array) -> void:
	if not pl.has("pr"):
		return
	var pr: Dictionary = pl["pr"]
	pr["left"] = int(pr["left"]) - 1
	var got := int(pl["apps"]) - int(pr["a0"])
	var nm := str(pl["n"]).capitalize()
	if got >= PROMISE_NEED:
		pl.erase("pr")
		pl["mo"] = clampi(int(pl.get("mo", 65)) + 10, 5, 100)
		_mail("info", "You kept your word to %s" % nm, "%s got his matches, as you promised. He trusts you, and the dressing room saw it." % nm)
		_team_mood(1)
		lines.append("PROMISE KEPT: %s GOT HIS MATCHES" % nm.to_upper())
	elif int(pr["left"]) <= 0 or PROMISE_NEED - got > int(pr["left"]):
		pl.erase("pr")
		pl["mo"] = clampi(int(pl.get("mo", 65)) - 30, 5, 100)
		pl["tr"] = true
		_team_mood(-3)
		_mail("info", "You broke your promise to %s" % nm, "You promised %s matches and he did not get them. He has asked to leave, and the other players noticed." % nm)
		lines.append("PROMISE BROKEN: %s HAS ASKED TO LEAVE" % nm.to_upper())

# a bold word before a big night: the result decides if it was smart
func _bold_result(won: bool, lines: Array) -> void:
	if not bool(d.get("bold", false)):
		return
	d.erase("bold")
	if won:
		_conf_add(3)
		_team_mood(2)
		lines.append("YOU SAID YOU WOULD WIN, AND YOU DID")
	else:
		_conf_add(-3)
		lines.append("BIG WORDS BEFORE THE MATCH, NO WIN: THE BOARD NOTICED")

# the run of results the press talk about: + wins in a row, - matches without a win
func _streak_add(won: bool) -> void:
	var sk := _streak()
	if won:
		sk = maxi(sk, 0) + 1
	else:
		sk = mini(sk, 0) - 1
	d["strk"] = sk


# ---------------------------------------------------------------- form: how well a man has played lately
# Form (pl["fm"], 0-100, 50 is normal) rises when he plays, wins and scores, falls in defeats, and fades when he
# sits out. Clubs watch it: a man in good form gets bids, a man who does not play or plays badly gets few or none.
static func pform(pl: Dictionary) -> int:
	return int(pl.get("fm", 50))

static func form_name(f: int) -> String:
	return "SUPERB" if f >= 75 else ("GOOD" if f >= 60 else ("NORMAL" if f >= 42 else ("POOR" if f >= 30 else "AWFUL")))

func _form_add(pl: Dictionary, mine: int, theirs: int, goals: int) -> void:
	var sc := 52.0 + (16.0 if mine > theirs else (0.0 if mine == theirs else -14.0)) + goals * 22.0
	if theirs == 0 and str(pl["pos"]) in ["GK", "DF"]:
		sc += 14.0
	if theirs >= 3 and str(pl["pos"]) in ["GK", "DF"]:
		sc -= 10.0
	pl["fm"] = clampi(int(round(pform(pl) * 0.7 + clampf(sc, 0.0, 100.0) * 0.3)), 5, 99)

func _form_rest(pl: Dictionary) -> void:
	pl["fm"] = clampi(int(round(pform(pl) * 0.9 + 32.0 * 0.1)), 5, 99)

# how likely clubs bid for a listed man at the next stop: his form above all, then his level, age and future
func interest(pl: Dictionary) -> float:
	var f := pform(pl)
	var o := ovr_of(pl)
	var ch := 0.08 + (f - 40) * 0.012
	ch += clampf((o - my_strength()) * 0.02, -0.15, 0.15)
	if int(pl["age"]) <= 22 and int(pl["pot"]) - o >= 6:
		ch += 0.1
	if int(pl["age"]) >= 32:
		ch -= 0.1
	return clampf(ch, 0.0, 0.7)


# ---------------------------------------------------------------- player career (be a pro)
# You are one player at a club. The manager picks the team: your rating in each match builds his trust, and his
# trust (with your form and level) decides if you start, sit on the bench or come on. Ratings give you points to
# spend on your four stats, up to your potential. Play well and bigger clubs want you: their offers come in the
# inbox, and you move when the season ends. Everything else (the table, the cup, Europe, awards) is the career's.
const PRO_START_OVR := 60
const PRO_POT := 88
const PRO_SPOTS := {"DF": [1, 2, 3, 4], "MF": [5, 6, 7], "FW": [8, 9, 10]}

func pro() -> bool:
	return d.has("pro")

# "pro" is you; "pro2" is your friend's player when you play the player career together
func pro_d(k := "pro") -> Dictionary:
	return d.get(k, {})

func pro_i(k := "pro") -> int:
	if not d.has(k):
		return -1
	return _sq_find(str(pro_d(k).get("pn", "")))

func pro_pl(k := "pro") -> Dictionary:
	var i := pro_i(k)
	return d["squad"][i] if i >= 0 else {}

func pro2() -> bool:
	return d.has("pro2")

func _pro_new_d(nm: String) -> Dictionary:
	return {"pn": nm, "trust": 50, "rt": [], "ss": {"apps": 0, "st": 0, "g": 0, "a": 0, "rs": 0.0}, "all": {"apps": 0, "g": 0, "a": 0, "rs": 0.0, "clubs": 1},
		"pxp": 0, "next": "", "offer": -1, "hist": []}

func _pro_make(nm: String, pos: String, num: int) -> Dictionary:
	var base: Array = ROLE_BASE[pos]
	var me := {"n": nm, "num": num, "pos": pos, "age": 18, "xp": 0, "g": 0, "apps": 0, "me": true,
		"pac": int(base[0]), "sho": int(base[1]), "pas": int(base[2]), "dfn": int(base[3]), "fm": 50, "mo": 70}
	var gap := PRO_START_OVR - ovr_of(me)
	for k in STAT_KEYS:
		me[k] = clampi(int(me[k]) + gap, 25, 95)
	me["pot"] = PRO_POT
	return me

static func _pro_clean(pname: String) -> String:
	var nm := pname.strip_edges().to_upper()
	return nm if nm != "" else "ROOKIE"

# your friend joins the player career with a player of his own, at your club
func add_pro2(pname: String, pos: String) -> void:
	if pro2() or not pro():
		return
	var nm := _pro_clean(pname)
	if nm == str(pro_d()["pn"]):
		nm += " JR"
	for pl in d["squad"]:
		if str(pl["n"]) == nm:
			pl["n"] = str(pl["n"]) + "S"
	(d["squad"] as Array).append(_pro_make(nm, pos if PRO_SPOTS.has(pos) else "MF", 23))
	d["pro2"] = _pro_new_d(nm)
	_pro_goals("pro2")
	pro_select("pro2", true)
	save()

func new_pro(c: int, pname: String, pos: String) -> void:
	new_career(c, false)
	d["mode"] = "simple"
	var nm := _pro_clean(pname)
	# nobody else in the squad has your name
	for pl in d["squad"]:
		if str(pl["n"]) == nm:
			pl["n"] = str(pl["n"]) + "S"
	(d["squad"] as Array).append(_pro_make(nm, pos, 22))
	d["pro"] = _pro_new_d(nm)
	_pro_goals()
	pro_select()
	save()

# the manager's view of you before a match: your level, his trust and your form against the man in your place
func _pro_score(pl: Dictionary, mine: bool, k := "pro") -> float:
	var s := float(ovr_of(pl)) + (pform(pl) - 50) * 0.08
	if mine:
		s += (int(pro_d(k).get("trust", 50)) - 50) * 0.25
	if injured(pl):
		s -= 100.0
	s -= maxf(70.0 - cond_of(pl), 0.0) * 0.15
	return s

# Picks the eleven for the next match. You start when you beat the weakest man in your position.
# Together (force) the manager always plays you both.
func pro_select(k := "pro", force := false) -> void:
	if not d.has(k):
		return
	var me := pro_i(k)
	if me < 0:
		return
	if int(pro_d(k).get("bn", 0)) >= 2 and not injured(d["squad"][me]):
		# Never the bench for good (Daniel): after two matches without a start the manager gives you your chance
		force = true
	var other := pro_i("pro2" if k == "pro" else "pro")
	var xi: Array = d["xi"]
	var pl: Dictionary = d["squad"][me]
	var at := xi.find(me)
	var spots: Array = PRO_SPOTS.get(str(pl["pos"]), [9])
	if at >= 0 and spots.has(at):
		# in the side: he stays unless someone on the bench is clearly better now
		var best := -1
		var bs := _pro_score(pl, true, k) + (1e6 if force else 1.5)
		for i in (d["squad"] as Array).size():
			if xi.has(i) or str(d["squad"][i]["pos"]) != str(pl["pos"]):
				continue
			var sc := _pro_score(d["squad"][i], false)
			if sc > bs:
				bs = sc
				best = i
		if best >= 0:
			xi[at] = best
		pro_d(k)["next"] = "start" if xi.has(me) else "bench"
		return
	if at >= 0:
		xi[at] = -1
	# off the bench into the place of the weakest man in his spots
	var wk := -1
	var ws := 1e9
	for s in spots:
		var j := int(xi[s])
		if j == other and other >= 0:
			continue
		var sc := _pro_score(d["squad"][j], false) if j >= 0 else -1e9
		if sc < ws:
			ws = sc
			wk = s
	if wk < 0 and force:
		# his spots are all taken by your friend: any outfield place will do
		for s in [10, 9, 8, 7, 6, 5]:
			if int(xi[s]) != other:
				wk = s
				break
	if wk >= 0 and (force or _pro_score(pl, true, k) >= ws):
		xi[wk] = me
	if xi.has(-1):
		# fill a hole left by the swap with the best man on the bench
		var h := xi.find(-1)
		var bi := -1
		for i in (d["squad"] as Array).size():
			if not xi.has(i) and i != me and i != other and (bi < 0 or ovr_of(d["squad"][i]) > ovr_of(d["squad"][bi])):
				bi = i
		xi[h] = bi
	pro_d(k)["next"] = "start" if xi.has(me) else "bench"

func pro_starts(k := "pro") -> bool:
	return d.has(k) and (d["xi"] as Array).has(pro_i(k))

# a match is over: rating (0 when you did not play), goals, assists. Returns lines for the end screen.
func pro_after(rt: float, g: int, a: int, played: bool, started: bool, k := "pro") -> Array:
	var lines := []
	if not d.has(k):
		return lines
	var p := pro_d(k)
	var pl := pro_pl(k)
	if pl.is_empty():
		return lines
	var ss: Dictionary = p["ss"]
	var al: Dictionary = p["all"]
	# matches in a row without a start: after two the manager starts him (pro_select)
	p["bn"] = 0 if started else int(p.get("bn", 0)) + 1
	if played:
		rt = clampf(rt, 3.0, 10.0)
		ss["apps"] = int(ss["apps"]) + 1
		al["apps"] = int(al["apps"]) + 1
		if started:
			ss["st"] = int(ss.get("st", 0)) + 1
		ss["g"] = int(ss["g"]) + g
		ss["a"] = int(ss["a"]) + a
		al["g"] = int(al["g"]) + g
		al["a"] = int(al["a"]) + a
		ss["rs"] = float(ss["rs"]) + rt
		al["rs"] = float(al["rs"]) + rt
		var rl: Array = p["rt"]
		rl.append(snappedf(rt, 0.1))
		while rl.size() > 10:
			rl.pop_front()
		# the manager's trust: a good match lifts it, a bad one costs, more for a man who started
		var dt := (rt - (6.3 if started else 5.6)) * (3.5 if started else 4.0)
		p["trust"] = clampi(int(round(int(p["trust"]) + dt)), 0, 100)
		pl["fm"] = clampi(int(round(pform(pl) * 0.6 + (rt - 3.0) / 7.0 * 100.0 * 0.4)), 5, 99)
		# experience: for playing, more for a good match, goals and assists
		var xg := 15 + maxi(int(round((rt - 6.0) * 20.0)), 0) + g * 20 + a * 12 + (5 if started else 0)
		_pro_xp(k, xg, lines)
		lines.append("YOUR RATING %.1f%s" % [rt, ("  ·  %d GOAL%s" % [g, "" if g == 1 else "S"] if g > 0 else "") + ("  ·  %d ASSIST%s" % [a, "" if a == 1 else "S"] if a > 0 else "")])
	else:
		# not used: form fades, he keeps training (the club's training gives him experience), and the
		# manager sees him work: a little more trust each week
		p["trust"] = clampi(int(p["trust"]) + 3, 0, 100)
		lines.append("YOU DID NOT PLAY")
		_pro_xp(k, 5, lines)
	# the week's training: the drill you chose fills its bar, more when you sat on the bench
	_pro_train(k, played, lines)
	# a season goal reached: a big lump of experience, once
	var od: Array = p.get("objd", [])
	var ob := pro_obj(k)
	for oi in ob.size():
		if bool(ob[oi][3]) and not od.has(oi):
			od.append(oi)
			lines.append("SEASON GOAL DONE: %s" % str(ob[oi][0]).to_upper())
			_pro_xp(k, PRO_OBJ_XP, lines)
	p["objd"] = od
	lines.append("MANAGER'S TRUST %d" % int(p["trust"]))
	return lines

func pro_avg(season := true, k := "pro") -> float:
	var s: Dictionary = pro_d(k).get("ss" if season else "all", {})
	return float(s.get("rs", 0.0)) / maxf(int(s.get("apps", 0)), 1)

# goals for the season, from your position
func _pro_goals(k := "pro") -> void:
	var pl := pro_pl(k)
	var pos := str(pl.get("pos", "MF"))
	var gl: int = {"DF": 2, "MF": 5, "FW": 10}.get(pos, 5)
	pro_d(k)["obj"] = [["Play in %d matches" % (rounds_total() / 2), "apps", rounds_total() / 2], ["Score %d goals" % gl, "g", gl], ["Average a rating of 6.8", "avg", 6.8]]

func pro_obj(k := "pro") -> Array:
	var out := []
	var ss: Dictionary = pro_d(k).get("ss", {})
	for o in pro_d(k).get("obj", []):
		var ok := str(o[1])
		var v: float = pro_avg(true, k) if ok == "avg" else float(ss.get(ok, 0))
		out.append([str(o[0]), v, float(o[2]), v >= float(o[2])])
	return out

# Clubs watch you: offers come in while a window is open, on your form, ratings and level.
func _pro_offers(rng: RandomNumberGenerator, lines: Array) -> void:
	var p := pro_d()
	var pl := pro_pl()
	if pl.is_empty() or int(p.get("offer", -1)) >= 0:
		return
	var n := int((p["ss"] as Dictionary).get("apps", 0))
	if n < 3:
		return
	var avg := pro_avg()
	var fm := pform(pl)
	var ov := ovr_of(pl)
	var both := pro2() and not pro_pl("pro2").is_empty()
	if both:
		# together you are one deal: a club buys you both or neither, on how you both play
		avg = (avg + pro_avg(true, "pro2")) * 0.5
		fm = (fm + pform(pro_pl("pro2"))) / 2
		ov = (ov + ovr_of(pro_pl("pro2"))) / 2
	var ch := clampf((avg - 6.6) * 0.2 + (fm - 55) * 0.004, 0.0, 0.3)
	if rng.randf() >= ch:
		return
	var lvl := ov + int(round((avg - 6.8) * 4.0))
	var cand := []
	for c in range(FIRST, W.size()):
		if c == int(d["club"]) or int(W[c].get("lg", -1)) < 0:
			continue
		if rating(c) > rating(int(d["club"])) and rating(c) <= lvl + 10:
			cand.append(c)
	for m in inbox():
		if str(m["k"]) == "pjob" and str(m.get("st", "")) == "open":
			return # one offer at a time
	if cand.is_empty():
		return
	var c: int = cand[rng.randi() % cand.size()]
	var cn := str(cname(c)).capitalize()
	if both:
		_mail("pjob", "%s want you both" % cn, "%s (%s) have watched you two: an average rating of %.1f this season. They want you both, together, when the season ends." % [cn, league_name_of(c).capitalize(), avg],
			{"c": c, "st": "open", "left": 3, "opts": [["Yes, we join %s together this summer." % cn, {"join": 1}, "Agreed. You both move to %s when the season is over." % cn], ["No, we stay here.", {"stay": 1}, "You stay. The manager hears about it and likes your loyalty."]]})
		lines.append("%s WANT TO SIGN YOU BOTH" % str(cname(c)))
		return
	_mail("pjob", "%s want you" % cn, "%s (%s) have watched you: an average rating of %.1f this season. They want you to join them when the season ends." % [cn, league_name_of(c).capitalize(), avg],
		{"c": c, "st": "open", "left": 3, "opts": [["Yes, I will join %s this summer." % cn, {"join": 1}, "Agreed. You move to %s when the season is over." % cn], ["No, I stay here.", {"stay": 1}, "You stay. The manager hears about it and likes your loyalty."]]})
	lines.append("%s WANT TO SIGN YOU" % str(cname(c)))

func league_name_of(c: int) -> String:
	var li := league_of(c)
	return str(ClubDB.LEAGUES[li]["n"]) if li >= 0 and li < ClubDB.LEAGUES.size() else ""

# ---- your player's growth, as in FIFA's player career: experience gives levels, a level gives skill points,
# a point raises one stat (dearer the better it is), training raises the stat you drill, points also buy a skill.
const PRO_LV_PTS := 2
const PRO_OBJ_XP := 120
const PRO_AB_PTS := [4, 6]

func pro_lv(k := "pro") -> int:
	return int(pro_d(k).get("lv", 1))

func pro_need(k := "pro") -> int:
	return 100 + 40 * (pro_lv(k) - 1)

static func pro_cost(v: int) -> int:
	return 1 if v < 70 else (2 if v < 80 else 3)

func _pro_xp(k: String, n: int, lines: Array) -> void:
	var p := pro_d(k)
	var pl := pro_pl(k)
	if pl.is_empty() or n <= 0:
		return
	p["pxp"] = int(p.get("pxp", 0)) + n
	lines.append("+%d XP" % n)
	while int(p["pxp"]) >= pro_need(k):
		p["pxp"] = int(p["pxp"]) - pro_need(k)
		p["lv"] = pro_lv(k) + 1
		pl["tp"] = int(pl.get("tp", 0)) + PRO_LV_PTS
		lines.append("LEVEL %d!  +%d SKILL POINTS TO SPEND" % [pro_lv(k), PRO_LV_PTS])

# the drill you train between matches (0 pace, 1 shooting, 2 passing, 3 defending)
func pro_drill(k := "pro") -> int:
	var pl := pro_pl(k)
	var def: int = {"DF": 3, "MF": 2, "FW": 1}.get(str(pl.get("pos", "MF")), 2)
	return int(pro_d(k).get("drill", def))

func pro_set_drill(si: int, k := "pro") -> void:
	if d.has(k) and si >= 0 and si <= 3:
		pro_d(k)["drill"] = si
		save()

func pro_dp(k := "pro") -> Array:
	var a: Array = pro_d(k).get("dp", [0, 0, 0, 0])
	return a if a.size() == 4 else [0, 0, 0, 0]

func _pro_train(k: String, played: bool, lines: Array) -> void:
	var p := pro_d(k)
	var pl := pro_pl(k)
	if pl.is_empty():
		return
	var si := pro_drill(k)
	var dp := pro_dp(k)
	# the club's training ground helps too
	var gain := (22 if played else 36) + fac("training") * 3
	var sk: String = STAT_KEYS[si]
	if ovr_of(pl) >= int(pl["pot"]) or int(pl[sk]) >= 97:
		return
	dp[si] = int(dp[si]) + gain
	if int(dp[si]) >= 100:
		dp[si] = int(dp[si]) - 100
		pl[sk] = int(pl[sk]) + 1
		lines.append("TRAINING PAYS OFF: +1 %s" % stat_name(str(pl["pos"]), si))
	p["dp"] = dp

# spend skill points on one of your stats: one point below 70, two below 80, three above
func pro_spend(si: int, k := "pro") -> String:
	var i := pro_i(k)
	if i < 0 or si < 0 or si > 3:
		return ""
	var pl: Dictionary = d["squad"][i]
	var sk: String = STAT_KEYS[si]
	var cost := pro_cost(int(pl[sk]))
	if int(pl[sk]) >= 97:
		return "You cannot get better at that."
	if ovr_of(pl) >= int(pl["pot"]):
		return "You are at your best: rating %d." % int(pl["pot"])
	if int(pl.get("tp", 0)) < cost:
		return "%s %d to %d costs %d points." % [stat_name(str(pl["pos"]), si).capitalize(), int(pl[sk]), int(pl[sk]) + 1, cost]
	pl[sk] = int(pl[sk]) + 1
	pl["tp"] = int(pl["tp"]) - cost
	save()
	return "+1 %s" % stat_name(str(pl["pos"]), si)

# a skill (evne) for your player, bought with skill points: the second opens at rating 70
func pro_learn(key: String, k := "pro") -> String:
	var pl := pro_pl(k)
	if pl.is_empty() or not ABIL.has(key):
		return ""
	var have := ab_of(pl)
	if have.has(key):
		return "You already have %s." % ABIL[key][0]
	if not (ABIL[key][2] as Array).has(str(pl["pos"])):
		return "A %s cannot learn that." % str(pl["pos"])
	if have.size() >= 2:
		return "You have two skills already."
	if have.size() == 1 and ovr_of(pl) < AB_SLOT2:
		return "The second skill opens at rating %d." % AB_SLOT2
	var cost: int = PRO_AB_PTS[have.size()]
	if int(pl.get("tp", 0)) < cost:
		return "%s costs %d skill points." % [str(ABIL[key][0]).capitalize(), cost]
	have.append(key)
	pl["ab"] = have
	pl["tp"] = int(pl["tp"]) - cost
	save()
	return "YOU LEARNED %s" % ABIL[key][0]

# the season is over: your move (if you agreed one) or a new season at the same club
func pro_next_season() -> void:
	var p := pro_d()
	var me: Dictionary = pro_pl().duplicate(true)
	var me2: Dictionary = pro_pl("pro2").duplicate(true)
	var c := int(p.get("offer", -1))
	if pro2():
		var p2 := pro_d("pro2")
		(p2["hist"] as Array).append([int(d["season"]), int(d["club"]), int(p2["ss"]["apps"]), int(p2["ss"]["g"]), int(p2["ss"]["a"]), snappedf(pro_avg(true, "pro2"), 0.01)])
	(p["hist"] as Array).append([int(d["season"]), int(d["club"]), int(p["ss"]["apps"]), int(p["ss"]["g"]), int(p["ss"]["a"]), snappedf(pro_avg(), 0.01)])
	if c >= 0:
		d["offers"] = [[c]]
		take_job(0)
		me["age"] = int(me["age"]) + 1
		me["g"] = 0
		me["apps"] = 0
		me["cond"] = 100
		me.erase("inj")
		me.erase("injn")
		for m2 in ([me, me2] if not me2.is_empty() else [me]):
			m2["age"] = int(m2["age"]) + (1 if m2 != me else 0)
			m2["g"] = 0
			m2["apps"] = 0
			m2["cond"] = 100
			m2.erase("inj")
			m2.erase("injn")
			for pl in d["squad"]:
				if str(pl["n"]) == str(m2["n"]):
					pl["n"] = str(pl["n"]) + "S"
			(d["squad"] as Array).append(m2)
		if pro2():
			pro_d("pro2")["trust"] = 50
		d["mode"] = "simple"
		p["trust"] = 50
		p["all"]["clubs"] = int(p["all"].get("clubs", 1)) + 1
		_mail("info", "Welcome to %s" % str(cname(c)).capitalize(), "A new club and a new manager. Show him what you can do: his trust starts again.")
	else:
		next_season()
		p["trust"] = clampi(int(p["trust"]) + (6 if pro_avg() >= 7.0 else 0), 0, 100)
	p["offer"] = -1
	for k in (["pro", "pro2"] if pro2() else ["pro"]):
		pro_d(k)["ss"] = {"apps": 0, "st": 0, "g": 0, "a": 0, "rs": 0.0}
		pro_d(k)["objd"] = []
		_pro_goals(k)
	pro_select("pro")
	if pro2():
		pro_select("pro2")
	save()

# ---------------------------------------------------------------- the national team
# As in FIFA: a country asks you to manage its national team next to your club. You call up the squad from that
# country's best players (your own men too, when they are from there), play or simulate the qualifiers in the
# international weeks, and the top two of the group go on to the summer tournament after the season.
const NATIONS := [
	["DENMARK", "DEN", ["c8102e", "ffffff", "c8102e"], 77], ["ENGLAND", "ENG", ["f4f4f4", "1d2a5c", "f4f4f4"], 83],
	["SWEDEN", "SWE", ["fecc02", "1a4fa0", "fecc02"], 75], ["NORWAY", "NOR", ["d81e2c", "ffffff", "1a3a8a"], 74],
	["NETHERLANDS", "NED", ["f36c21", "ffffff", "f36c21"], 82], ["GERMANY", "GER", ["f4f4f4", "111111", "f4f4f4"], 84],
	["SPAIN", "ESP", ["c60b1e", "1d2a5c", "1d2a5c"], 85], ["FRANCE", "FRA", ["1f3e8c", "ffffff", "c8102e"], 86],
	["ITALY", "ITA", ["1f5fbf", "ffffff", "1f5fbf"], 82], ["PORTUGAL", "POR", ["b8122a", "0f6a3a", "b8122a"], 83],
	["BELGIUM", "BEL", ["d4102b", "111111", "d4102b"], 80], ["SCOTLAND", "SCO", ["1b2a5a", "ffffff", "1b2a5a"], 72],
	["WALES", "WAL", ["d3112b", "d3112b", "1a9a4a"], 71], ["IRELAND", "IRL", ["15944a", "ffffff", "15944a"], 70],
	["POLAND", "POL", ["f4f4f4", "d4213d", "f4f4f4"], 75], ["CROATIA", "CRO", ["e8e8e8", "1d3f8a", "1d3f8a"], 79],
	["SWITZERLAND", "SUI", ["d52b1e", "ffffff", "d52b1e"], 77], ["AUSTRIA", "AUT", ["e0202e", "ffffff", "e0202e"], 76],
	["CZECHIA", "CZE", ["d7141a", "1a3c8a", "d7141a"], 74], ["ICELAND", "ISL", ["1a4fa0", "ffffff", "1a4fa0"], 68],
	["FINLAND", "FIN", ["f4f4f4", "1a3c8a", "f4f4f4"], 67], ["SERBIA", "SRB", ["c6363c", "1a3c8a", "f4f4f4"], 75],
	["TURKEY", "TUR", ["e30a17", "ffffff", "e30a17"], 77], ["UKRAINE", "UKR", ["ffd500", "005bbb", "ffd500"], 75],
	["BRAZIL", "BRA", ["ffdf1c", "1a4fa0", "f4f4f4"], 86], ["ARGENTINA", "ARG", ["75aadb", "111111", "f4f4f4"], 86],
	["URUGUAY", "URU", ["6cb4ee", "111111", "111111"], 79], ["USA", "USA", ["f4f4f4", "1d2a5c", "f4f4f4"], 76],
	["MEXICO", "MEX", ["0f6a3a", "ffffff", "c8102e"], 77], ["JAPAN", "JPN", ["1a2f8a", "ffffff", "1a2f8a"], 78],
	["MOROCCO", "MAR", ["c1272d", "0f6a3a", "c1272d"], 79], ["SENEGAL", "SEN", ["f4f4f4", "0f8a3a", "f4f4f4"], 77],
]
const NAT_EU := 24 # the first 24 are European
const NAT_FR := [0.07, 0.14, 0.26, 0.33, 0.45, 0.52, 0.66, 0.73, 0.83, 0.90]
const NAT_KO := ["GROUP, MATCH 1", "GROUP, MATCH 2", "GROUP, MATCH 3", "QUARTER-FINAL", "SEMI-FINAL", "FINAL"]
const NAT_ROLES := {"GK": 3, "DF": 8, "MF": 7, "FW": 5}

func nat() -> Dictionary:
	return d.get("nat", {})

func nat_job() -> bool:
	return not nat().is_empty() and not bool(d.get("cupmode", false)) and not pro() and d.has("leagues")

static func nat_name(n: int) -> String:
	return str(NATIONS[clampi(n, 0, NATIONS.size() - 1)][0])

static func nat_kit(n: int) -> Array:
	return (NATIONS[clampi(n, 0, NATIONS.size() - 1)][2] as Array).duplicate()

func nat_str(n: int) -> float:
	if nat_job() and n == int(nat()["n"]):
		var xi := nat_xi()
		if xi.size() == 11:
			var s := 0.0
			for pl in xi:
				s += ovr_of(pl)
			return s / 11.0
	return float(NATIONS[n][3])

func tour_name() -> String:
	return "WORLD CUP" if int(d.get("season", 1)) % 2 == 0 else "EUROPEAN CHAMPIONSHIP"

# where a man is from: most men come from the country they play in, the rest from all over
func _home_nat() -> int:
	var cn := str(league().get("c", "ENGLAND"))
	for i in NATIONS.size():
		if str(NATIONS[i][0]) == cn:
			return i
	return 1

func nat_of(pl: Dictionary) -> int:
	if pl.has("nat") and int(pl["nat"]) >= 0:
		return int(pl["nat"])
	var h := absi(hash(str(pl.get("n", "")) + "#" + str(pl.get("num", 0))))
	var v := _home_nat() if h % 100 < 72 else (h / 100) % NATIONS.size()
	pl["nat"] = v
	return v

# the men a country can call up: its own players at clubs all over the world, and yours from there
func nat_pool(n: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 4099 + int(d.get("season", 1)) * 131 + 7
	for k in range(59, 0, -1):
		rng.randi_range(0, k)
	# the country's own men, with names from that country (the same on every phone)
	var nrng := RandomNumberGenerator.new()
	nrng.seed = n * 4099 + int(d.get("season", 1)) * 131 + 11
	var pool := []
	var nsur := {}
	for k in 40:
		var nm := Names.make(str(NATIONS[n][0]), nrng, {}, nsur, false)
		nsur[Names.surname(nm)] = true
		pool.append(nm)
	var q := int(NATIONS[n][3]) - 72
	var out := []
	var i := 0
	for role in ["GK", "DF", "MF", "FW"]:
		for k in int(NAT_ROLES[role]) + 2:
			var base: Array = ROLE_BASE[role]
			var qq := q + rng.randi_range(-7, 3) + (4 if k == 0 else 0)
			var pl := {"n": str(pool[i % maxi(pool.size(), 1)]) if not pool.is_empty() else "PLAYER", "nat": n, "pos": role, "age": rng.randi_range(20, 33), "num": 0, "key": "g%d" % i,
				"pac": clampi(base[0] + qq + rng.randi_range(-5, 5), 30, 97), "sho": clampi(base[1] + qq + rng.randi_range(-5, 5), 25, 97),
				"pas": clampi(base[2] + qq + rng.randi_range(-5, 5), 30, 97), "dfn": clampi(base[3] + qq + rng.randi_range(-5, 5), 25, 97)}
			pl["ab"] = ab_roll(role, ovr_of(pl), rng)
			out.append(pl)
			i += 1
	if nat_job() and n == int(nat()["n"]):
		for si in (d["squad"] as Array).size():
			var sp: Dictionary = d["squad"][si]
			if nat_of(sp) == n:
				var c := sp.duplicate()
				c["key"] = "m:" + str(sp["n"])
				c["mine"] = si
				out.append(c)
	return out

func _nat_find(pool: Array, key: String) -> Dictionary:
	for pl in pool:
		if str(pl["key"]) == key:
			return pl
	return {}

# the best 23: three keepers, eight defenders, seven midfielders, five forwards
func nat_call_auto() -> void:
	var nj := nat()
	var pool := nat_pool(int(nj["n"]))
	var sq := []
	for role in NAT_ROLES:
		var by := pool.filter(func(p): return str(p["pos"]) == role and not injured(p))
		by.sort_custom(func(a, b): return ovr_of(a) > ovr_of(b))
		for k in mini(int(NAT_ROLES[role]), by.size()):
			sq.append(str(by[k]["key"]))
	nj["sq"] = sq

# the called-up men, best first per place
func nat_squad() -> Array:
	var nj := nat()
	if nj.is_empty():
		return []
	var pool := nat_pool(int(nj["n"]))
	var out := []
	var keep := []
	for k in nj.get("sq", []):
		var pl := _nat_find(pool, str(k))
		if not pl.is_empty():
			out.append(pl)
			keep.append(str(k))
	nj["sq"] = keep
	out.sort_custom(func(a, b): return ["GK", "DF", "MF", "FW"].find(str(a["pos"])) * 1000 - ovr_of(a) < ["GK", "DF", "MF", "FW"].find(str(b["pos"])) * 1000 - ovr_of(b))
	for i in out.size():
		out[i]["num"] = i + 1
	return out

# call a man up, or send him home (23 at most)
func nat_pick(key: String) -> String:
	var nj := nat()
	if nj.is_empty():
		return ""
	var sq: Array = nj.get("sq", [])
	if sq.has(key):
		if sq.size() <= 16:
			return "You need at least 16 men"
		sq.erase(key)
		save()
		return ""
	if sq.size() >= 23:
		return "The squad is full: send someone home first"
	var pl := _nat_find(nat_pool(int(nj["n"])), key)
	if pl.is_empty():
		return ""
	if injured(pl):
		return "He is injured"
	sq.append(key)
	nj["sq"] = sq
	save()
	return ""

# the eleven: the best keeper, four defenders, three midfielders and three forwards (4-3-3)
func nat_xi(sq := []) -> Array:
	if sq.is_empty():
		sq = nat_squad()
	var used := []
	var out := []
	for r in ["GK", "DF", "DF", "DF", "DF", "MF", "MF", "MF", "FW", "FW", "FW"]:
		var best := -1
		for pass_n in 2:
			for i in sq.size():
				if used.has(i) or (pass_n == 0 and str(sq[i]["pos"]) != r) or (pass_n == 1 and (str(sq[i]["pos"]) == "GK") != (r == "GK")):
					continue
				if best < 0 or ovr_of(sq[i]) > ovr_of(sq[best]):
					best = i
			if best >= 0:
				break
		if best < 0:
			continue
		used.append(best)
		out.append(sq[best])
	return out

# a country's team for the match engine: name, kits, the eleven and a bench of seven
func nat_team(n: int) -> Dictionary:
	var mine := nat_job() and n == int(nat()["n"])
	var sq := nat_squad() if mine else nat_pool(n)
	var xi := nat_xi(sq)
	var row := func(pl: Dictionary, num: int) -> Dictionary:
		return {"n": str(pl["n"]), "num": num, "pos": str(pl["pos"]), "pac": int(pl["pac"]), "sho": int(pl["sho"]), "pas": int(pl["pas"]), "dfn": int(pl["dfn"]), "ab": ab_of(pl)}
	var x2 := []
	var nums := [1, 2, 5, 4, 3, 8, 6, 10, 11, 9, 7]
	for i in xi.size():
		x2.append(row.call(xi[i], int(xi[i].get("num", 0)) if mine and int(xi[i].get("num", 0)) > 0 else nums[i]))
	var bench := []
	for pl in sq:
		if bench.size() >= 7:
			break
		if not xi.has(pl):
			bench.append(row.call(pl, int(pl.get("num", 0)) if mine and int(pl.get("num", 0)) > 0 else 12 + bench.size()))
	var k := nat_kit(n)
	var alt := "1c1c20" if Color(str(k[0])).get_luminance() > 0.6 else "f4f4f4"
	return {"n": nat_name(n), "s": str(NATIONS[n][1]), "k": k, "a": [alt, str(k[0]), alt], "f": "4-3-3", "lay": {}, "xi": x2, "bench": bench, "ov": int(round(nat_str(n)))}

# ---- the job
func _nat_cap() -> int:
	var cap := 66 + (4 - div()) * 4 + mini(cabinet().size(), 6) * 2 + int(d.get("season", 1)) - 1
	if nat_job():
		cap += 4
	return clampi(cap, 66, 86)

func _nat_offer(rng: RandomNumberGenerator, lines: Array) -> void:
	if nat_job() or not full() or pro() or bool(d.get("cupmode", false)) or d.has("sacked"):
		return
	if int(d.get("natoff", 0)) == int(d.get("season", 1)) or int(d["round"]) < 4 or season_over():
		return
	var cap := _nat_cap()
	var cand := []
	for n in NAT_EU:
		if int(NATIONS[n][3]) <= cap and int(NATIONS[n][3]) >= cap - 9:
			cand.append(n)
	if cand.is_empty():
		cand = [19, 20]
	var n: int = cand[rng.randi() % cand.size()]
	d["natoff"] = int(d.get("season", 1))
	var nm := nat_name(n).capitalize()
	_mail("natjob", "%s want you as national manager" % nm, "The %s FA has watched your work. They want you to lead %s next to your club: you pick the squad, play the qualifiers in the international weeks and, if you finish in the top two, go to the %s." % [nm, nm, tour_name().to_lower()],
		{"st": "open", "left": 4, "opts": [["Take the job", {"nat": n}, "You are the new manager of %s. Your first squad is called up on the National team page." % nm], ["Not now", {}, "They will look elsewhere. Maybe next season."]]})
	lines.append("%s WANT YOU AS NATIONAL MANAGER" % nat_name(n))

func nat_take(n: int) -> void:
	d["nat"] = {"n": n, "since": int(d.get("season", 1)), "ok": 60, "st": {"p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0}, "hist": []}
	nat_call_auto()
	_nat_new_q()
	save()

func nat_quit() -> void:
	if nat_job():
		_mail("natend", "You left %s" % nat_name(int(nat()["n"])).capitalize(), "You thanked the players and left the national team.")
		d.erase("nat")
		save()

# ---- the qualifiers: a group of five, home and away, ten rounds (each side rests in two)
func _nat_new_q() -> void:
	var nj := nat()
	var me := int(nj["n"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var others := []
	for n in NAT_EU:
		if n != me:
			others.append(n)
	others.sort_custom(func(a, b): return int(NATIONS[a][3]) > int(NATIONS[b][3]))
	# one from each pot of strength, like a real draw
	var grp := [me]
	var pots := [others.slice(0, 6), others.slice(6, 12), others.slice(12, 18), others.slice(18)]
	for p in pots:
		var pp: Array = (p as Array).filter(func(x): return not grp.has(x))
		if not pp.is_empty():
			grp.append(pp[rng.randi() % pp.size()])
	# a round robin with a rest: six places, the sixth is the rest
	var slots := grp.duplicate()
	slots.append(-1)
	var rounds := []
	for r in 5:
		var pr := []
		for k in 3:
			var a: int = slots[k]
			var b: int = slots[5 - k]
			if a >= 0 and b >= 0:
				pr.append([a, b] if (r + k) % 2 == 0 else [b, a])
		rounds.append(pr)
		var last: int = slots.pop_back()
		slots.insert(1, last)
	for r in 5:
		var back := []
		for m in rounds[r]:
			back.append([m[1], m[0]])
		rounds.append(back)
	var tab := {}
	for n in grp:
		tab[str(n)] = {"p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0}
	nj["q"] = {"grp": grp, "rd": rounds, "i": 0, "tab": tab, "log": [], "season": int(d.get("season", 1))}
	nj.erase("t")

func nat_after(i: int) -> int:
	var n := rounds_total()
	var r := clampi(int(round(n * NAT_FR[clampi(i, 0, NAT_FR.size() - 1)])), 1, n - 1)
	var busy := []
	for cr in cup_rounds():
		busy.append(cup_after_r(cr))
	if eu_due_ever() or not eu().is_empty():
		for md in EU_RD.size():
			busy.append(eu_after(md))
	for k in 4:
		if not busy.has(r):
			break
		r = mini(r + 1, n - 1)
	return r

func _nat_day_q(i: int) -> int:
	var a := nat_after(i)
	return mini(lg_day(a - 1) + 5, maxi(lg_day(a) - 1, lg_day(a - 1) + 1))

func _nat_day_t(md: int) -> int:
	return lg_day(rounds_total() - 1) + 21 + md * 4

func nat_q() -> Dictionary:
	return nat().get("q", {})

func nat_t() -> Dictionary:
	return nat().get("t", {})

# your pair in this qualifying round, or []
func _nat_mine_q(i: int) -> Array:
	var q := nat_q()
	var me := int(nat()["n"])
	if q.is_empty() or i >= (q["rd"] as Array).size():
		return []
	for m in q["rd"][i]:
		if int(m[0]) == me or int(m[1]) == me:
			return m
	return []

func nat_due() -> bool:
	if not nat_job():
		return false
	var t := nat_t()
	if not t.is_empty():
		return season_over() and not bool(t.get("out", false)) and not bool(t.get("done", false))
	var q := nat_q()
	if q.is_empty() or int(q["i"]) >= 10:
		return false
	return not _nat_mine_q(int(q["i"])).is_empty() and int(d["round"]) >= nat_after(int(q["i"]))

func nat_day() -> int:
	var t := nat_t()
	if not t.is_empty():
		return _nat_day_t(int(t["md"]))
	return _nat_day_q(int(nat_q().get("i", 0)))

# [opponent, you at home, what it is]
func nat_opp() -> Array:
	var me := int(nat().get("n", 0))
	var t := nat_t()
	if not t.is_empty():
		var md := int(t["md"])
		if md < 3:
			for m in t["gm"][md]:
				if int(m[0]) == me:
					return [int(m[1]), true, NAT_KO[md]]
				if int(m[1]) == me:
					return [int(m[0]), false, NAT_KO[md]]
		for m in t.get("ko", []):
			if int(m[0]) == me or int(m[1]) == me:
				return [int(m[1]) if int(m[0]) == me else int(m[0]), true, NAT_KO[clampi(md, 0, 5)]]
		return [-1, true, ""]
	var q := nat_q()
	var m2 := _nat_mine_q(int(q.get("i", 0)))
	if m2.is_empty():
		return [-1, true, ""]
	return [int(m2[1]) if int(m2[0]) == me else int(m2[0]), int(m2[0]) == me, "QUALIFIER %d" % (_nat_my_n(int(q["i"])) + 1)]

func _nat_my_n(i: int) -> int:
	var n := 0
	for k in i:
		if not _nat_mine_q(k).is_empty():
			n += 1
	return n

func nat_ko() -> bool:
	return not nat_t().is_empty() and int(nat_t()["md"]) >= 3

static func _nat_sim(a: float, b: float, rng: RandomNumberGenerator, home_a := 0.0) -> Array:
	var df := (a - b) / 12.0 + home_a
	return [_poisson(rng, 1.3 * exp(df)), _poisson(rng, 1.3 * exp(-df))]

func _nat_book(tab: Dictionary, a: int, b: int, ga: int, gb: int) -> void:
	for x in [[a, ga, gb], [b, gb, ga]]:
		var r: Dictionary = tab[str(x[0])]
		r["p"] = int(r["p"]) + 1
		r["gf"] = int(r["gf"]) + int(x[1])
		r["ga"] = int(r["ga"]) + int(x[2])
		if int(x[1]) > int(x[2]):
			r["w"] = int(r["w"]) + 1
			r["pts"] = int(r["pts"]) + 3
		elif int(x[1]) == int(x[2]):
			r["d"] = int(r["d"]) + 1
			r["pts"] = int(r["pts"]) + 1
		else:
			r["l"] = int(r["l"]) + 1

static func _nat_order(tab: Dictionary, grp: Array) -> Array:
	var o := grp.duplicate()
	o.sort_custom(func(a, b):
		var ra: Dictionary = tab[str(a)]
		var rb: Dictionary = tab[str(b)]
		if int(ra["pts"]) != int(rb["pts"]):
			return int(ra["pts"]) > int(rb["pts"])
		var da := int(ra["gf"]) - int(ra["ga"])
		var db := int(rb["gf"]) - int(rb["ga"])
		if da != db:
			return da > db
		return int(ra["gf"]) > int(rb["gf"]))
	return o

# rounds in which you rest are played when their week comes; then the group is decided
func _nat_tick(lines: Array) -> void:
	if not nat_job():
		return
	var q := nat_q()
	if q.is_empty() or not nat_t().is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while int(q["i"]) < 10 and _nat_mine_q(int(q["i"])).is_empty() and int(d["round"]) >= nat_after(int(q["i"])):
		_nat_round_rest(int(q["i"]), [], rng)
		q["i"] = int(q["i"]) + 1
	if int(q["i"]) >= 10 and not bool(q.get("over", false)):
		_nat_q_end(lines)

func _nat_round_rest(i: int, skip: Array, rng: RandomNumberGenerator) -> void:
	var q := nat_q()
	var lg: Array = q["log"]
	for m in q["rd"][i]:
		if m == skip:
			continue
		var r := _nat_sim(nat_str(int(m[0])), nat_str(int(m[1])), rng, 0.1)
		_nat_book(q["tab"], int(m[0]), int(m[1]), int(r[0]), int(r[1]))
		lg.append([i, int(m[0]), int(m[1]), int(r[0]), int(r[1])])

func _nat_q_end(lines: Array) -> void:
	var nj := nat()
	var q := nat_q()
	q["over"] = true
	var me := int(nj["n"])
	var o := _nat_order(q["tab"], q["grp"])
	var pos := o.find(me) + 1
	var nm := nat_name(me).capitalize()
	(nj["hist"] as Array).append([int(d.get("season", 1)), "Qualifiers: %s in the group" % ordinal(pos).to_lower()])
	if pos <= 2:
		nj["ok"] = clampi(int(nj["ok"]) + 10, 0, 100)
		_nat_new_t()
		_mail("natq", "%s are going to the %s!" % [nm, tour_name().to_lower()], "%s in the group. The %s is played in the summer, after the league season. Pick your 23 before it starts." % [ordinal(pos).capitalize(), tour_name().to_lower()])
		lines.append("%s ARE GOING TO THE %s!" % [nat_name(me), tour_name()])
	else:
		nj["ok"] = clampi(int(nj["ok"]) - 30, 0, 100)
		if int(nj["ok"]) < 35:
			_mail("natend", "%s let you go" % nm, "%s in the group is not good enough. The FA thanks you for your work and looks for a new manager." % ordinal(pos).capitalize())
			lines.append("%s HAVE LET YOU GO" % nat_name(me))
			d.erase("nat")
		else:
			_mail("natq", "%s miss the %s" % [nm, tour_name().to_lower()], "%s in the group. The FA keeps faith in you, but the next qualifiers must go better." % ordinal(pos).capitalize())
			lines.append("%s MISS THE %s" % [nat_name(me), tour_name()])

# ---- the tournament: sixteen countries, four groups of four, then the knockouts
func _nat_new_t() -> void:
	var nj := nat()
	var me := int(nj["n"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var field := []
	for n in (NATIONS.size() if tour_name() == "WORLD CUP" else NAT_EU):
		if n != me:
			field.append(n)
	var luck := {}
	for n in field:
		luck[n] = int(NATIONS[n][3]) + rng.randi_range(-4, 4)
	field.sort_custom(func(a, b): return int(luck[a]) > int(luck[b]))
	var teams := [me]
	teams.append_array(field.slice(0, 15))
	var by := teams.duplicate()
	by.sort_custom(func(a, b): return int(NATIONS[a][3]) > int(NATIONS[b][3]))
	var grps := [[], [], [], []]
	for p in 4:
		var pot: Array = by.slice(p * 4, p * 4 + 4)
		pot.shuffle()
		for g in 4:
			grps[g].append(pot[g])
	var gi := 0
	for g in 4:
		if (grps[g] as Array).has(me):
			gi = g
	var tab := {}
	for n in teams:
		tab[str(n)] = {"p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0}
	# matchdays: 1v2 3v4, 1v3 2v4, 1v4 2v3 in every group
	var gm := [[], [], []]
	for g in 4:
		var x: Array = grps[g]
		gm[0].append_array([[x[0], x[1]], [x[2], x[3]]])
		gm[1].append_array([[x[0], x[2]], [x[1], x[3]]])
		gm[2].append_array([[x[0], x[3]], [x[1], x[2]]])
	nj["t"] = {"name": tour_name(), "grp": grps, "gi": gi, "tab": tab, "gm": gm, "md": 0, "ko": [], "log": []}

func _nat_t_round(mine: Array, rng: RandomNumberGenerator, lines: Array) -> void:
	# everybody else's matches of this round, and the next round drawn
	var nj := nat()
	var t := nat_t()
	var me := int(nj["n"])
	var md := int(t["md"])
	var lg: Array = t["log"]
	if md < 3:
		for m in t["gm"][md]:
			if int(m[0]) == me or int(m[1]) == me:
				var a_me := int(m[0]) == me
				var ga := int(mine[0]) if a_me else int(mine[1])
				var gb := int(mine[1]) if a_me else int(mine[0])
				_nat_book(t["tab"], int(m[0]), int(m[1]), ga, gb)
				lg.append([md, int(m[0]), int(m[1]), ga, gb])
				continue
			var r := _nat_sim(nat_str(int(m[0])), nat_str(int(m[1])), rng)
			_nat_book(t["tab"], int(m[0]), int(m[1]), int(r[0]), int(r[1]))
			lg.append([md, int(m[0]), int(m[1]), int(r[0]), int(r[1])])
		if md == 2:
			var w := []
			for g in 4:
				w.append(_nat_order(t["tab"], t["grp"][g]))
			if not (w[int(t["gi"])] as Array).slice(0, 2).has(me):
				t["out"] = true
				var ps: int = (w[int(t["gi"])] as Array).find(me) + 1
				_nat_t_end("Out in the group (%s)" % ordinal(ps).to_lower(), -12, lines)
				return
			t["ko"] = [[w[0][0], w[1][1]], [w[1][0], w[0][1]], [w[2][0], w[3][1]], [w[3][0], w[2][1]]]
		t["md"] = md + 1
		return
	# a knockout round: you won yours (or you would be out), the rest are played
	var nxt := []
	for m in t["ko"]:
		var a := int(m[0])
		var b := int(m[1])
		var win := -1
		var ga := 0
		var gb := 0
		if a == me or b == me:
			win = me if bool(mine[2]) else (b if a == me else a)
			ga = int(mine[0]) if a == me else int(mine[1])
			gb = int(mine[1]) if a == me else int(mine[0])
		else:
			var r := _nat_sim(nat_str(a), nat_str(b), rng)
			ga = int(r[0])
			gb = int(r[1])
			win = a if ga > gb or (ga == gb and rng.randf() < 0.5) else b
		lg.append([md, a, b, ga, gb])
		nxt.append(win)
	if not nxt.has(me):
		t["out"] = true
		_nat_t_end("Out in the %s" % NAT_KO[md].to_lower(), (0 if md == 3 else 8), lines)
		return
	if md == 5:
		t["done"] = true
		_honour("nat", "%s: %s winners" % [str(t["name"]).capitalize(), nat_name(me).capitalize()])
		_nat_t_end("Winners!", 30, lines)
		return
	var ko := []
	for k in range(0, nxt.size(), 2):
		ko.append([nxt[k], nxt[k + 1]])
	t["ko"] = ko
	t["md"] = md + 1

func _nat_t_end(what: String, ok: int, lines: Array) -> void:
	var nj := nat()
	var t := nat_t()
	t["done"] = true
	var nm := nat_name(int(nj["n"])).capitalize()
	(nj["hist"] as Array).append([int(d.get("season", 1)), "%s: %s" % [str(t["name"]).capitalize(), what.to_lower()]])
	nj["ok"] = clampi(int(nj["ok"]) + ok, 0, 100)
	if what == "Winners!":
		_mail("natend", "%s win the %s!" % [nm, str(t["name"]).to_lower()], "You have made a whole country happy. Your name is in the trophy cabinet.")
		lines.append("%s WIN THE %s!" % [nat_name(int(nj["n"])), str(t["name"])])
		_conf_add(6)
	else:
		_mail("natend", "%s: %s" % [nm, what.to_lower()], "The %s is over for %s." % [str(t["name"]).to_lower(), nm])
		lines.append("%s: %s" % [str(t["name"]), what.to_upper()])

# A national match is over (played or simulated). Returns the lines for the end screen.
func nat_finish(mine: int, theirs: int, won_tie := false) -> Array:
	var lines := []
	if not nat_due():
		return lines
	var nj := nat()
	var me := int(nj["n"])
	var o := nat_opp()
	var opp := int(o[0])
	d["day"] = maxi(nat_day(), today() + 1)
	d["cur"] = int(d["day"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var st: Dictionary = nj["st"]
	st["p"] = int(st["p"]) + 1
	st["gf"] = int(st["gf"]) + mine
	st["ga"] = int(st["ga"]) + theirs
	var won: bool = mine > theirs or (mine == theirs and won_tie)
	var k := "w" if mine > theirs else ("d" if mine == theirs else "l")
	st[k] = int(st[k]) + 1
	nj["ok"] = clampi(int(nj["ok"]) + (4 if mine > theirs else (1 if mine == theirs else -4)), 0, 100)
	lines.append("%s %d-%d %s" % [nat_name(me), mine, theirs, nat_name(opp)])
	# your own men who played come back to the club a little tired, and proud
	var xi := nat_xi()
	var mine_n := 0
	for pl in xi:
		if pl.has("mine") and int(pl["mine"]) < (d["squad"] as Array).size():
			var sp: Dictionary = d["squad"][int(pl["mine"])]
			sp["cond"] = maxi(cond_of(sp) - 14, 30)
			sp["cday"] = int(d["day"])
			sp["mo"] = clampi(int(sp.get("mo", 65)) + 3, 5, 100)
			sp["caps"] = int(sp.get("caps", 0)) + 1
			mine_n += 1
	if mine_n > 0:
		lines.append("%d OF YOUR CLUB'S MEN PLAYED" % mine_n)
	var t := nat_t()
	if not t.is_empty():
		_nat_t_round([mine, theirs, won], rng, lines)
		var t2 := nat_t()
		if not bool(t2.get("out", false)) and not bool(t2.get("done", false)):
			if int(t2["md"]) < 3:
				var gi := int(t2["gi"])
				lines.append("%s IN GROUP %s" % [ordinal(_nat_order(t2["tab"], t2["grp"][gi]).find(me) + 1), "ABCD"[gi]])
			else:
				lines.append("THROUGH TO THE %s!" % NAT_KO[int(t2["md"])])
	else:
		var q := nat_q()
		var i := int(q["i"])
		var m := _nat_mine_q(i)
		_nat_book(q["tab"], int(m[0]), int(m[1]), mine if int(m[0]) == me else theirs, theirs if int(m[0]) == me else mine)
		(q["log"] as Array).append([i, int(m[0]), int(m[1]), mine if int(m[0]) == me else theirs, theirs if int(m[0]) == me else mine])
		_nat_round_rest(i, m, rng)
		q["i"] = i + 1
		lines.append("%s IN THE GROUP" % ordinal(_nat_order(q["tab"], q["grp"]).find(me) + 1))
		_nat_tick(lines)
	if nat_job() and int(nat()["ok"]) < 15:
		_mail("natend", "%s let you go" % nat_name(me).capitalize(), "Too many bad results. The FA looks for a new manager.")
		lines.append("%s HAVE LET YOU GO" % nat_name(me))
		d.erase("nat")
	save()
	return lines

# a national match you do not play: the score from the two elevens and your tactics
func nat_sim() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var o := nat_opp()
	var me := int(nat()["n"])
	var df := (nat_str(me) - nat_str(int(o[0]))) / 12.0 + (0.1 if bool(o[1]) else -0.1)
	var op_t := [2, 1, 1]
	var tk := tac_effect(tac(), op_t, df)
	df += float(tk[2])
	return [_poisson(rng, 1.3 * exp(df) * float(tk[0])), _poisson(rng, 1.3 * exp(-df) * float(tk[1]))]

# a new season: new qualifiers when the summer is done
func _nat_season() -> void:
	if not nat_job():
		return
	nat_call_auto()
	_nat_new_q()

# your national matches in the calendar ("opp" is a country)
func _nat_cal() -> Array:
	var out := []
	if not nat_job():
		return out
	var me := int(nat()["n"])
	var q := nat_q()
	if not q.is_empty() and int(q.get("season", 0)) == int(d.get("season", 1)):
		for i in 10:
			var m := _nat_mine_q(i)
			if m.is_empty():
				continue
			var e := {"day": _nat_day_q(i), "kind": "nat", "opp": int(m[1]) if int(m[0]) == me else int(m[0]), "home": int(m[0]) == me, "res": [], "played": i < int(q["i"]), "name": "Qualifier %d" % (_nat_my_n(i) + 1), "next": false}
			for l in q["log"]:
				if int(l[0]) == i and (int(l[1]) == me or int(l[2]) == me):
					var am := int(l[1]) == me
					e["res"] = [int(l[3]) if am else int(l[4]), int(l[4]) if am else int(l[3])]
			out.append(e)
	var t := nat_t()
	if not t.is_empty():
		for l in t["log"]:
			if int(l[1]) == me or int(l[2]) == me:
				var am2 := int(l[1]) == me
				out.append({"day": _nat_day_t(int(l[0])), "kind": "nat", "opp": int(l[2]) if am2 else int(l[1]), "home": true, "res": [int(l[3]) if am2 else int(l[4]), int(l[4]) if am2 else int(l[3])], "played": true, "name": NAT_KO[int(l[0])].capitalize(), "next": false})
		if nat_due():
			var o := nat_opp()
			out.append({"day": _nat_day_t(int(t["md"])), "kind": "nat", "opp": int(o[0]), "home": bool(o[1]), "res": [], "played": false, "name": str(o[2]).capitalize(), "next": false})
	return out

# ---------------------------------------------------------------- smarter deals
const SELLON_PCT := 20 # the share of the next fee
const SELLON_CUT := 0.88 # what a sell-on costs on today's fee
const RC_WAGE := [1.0, 0.92, 0.85] # a release clause in his contract: he takes a little less
const RC_K := [0.0, 2.5, 1.6] # the clause as a part of what he is worth: high, low

func clause_of_talk(t: Dictionary) -> int:
	var r := clampi(int(t.get("rc", 0)), 0, 2)
	if r == 0:
		return 0
	var o := int(t.get("ovr", 60))
	var v := maxi(20, int(round((30.0 + pow(maxf(o - 55.0, 0.0), 2.0) * 0.9 + maxf(int(t.get("pot", o)) - o, 0.0) * 6.0 - maxf(int(t.get("age", 25)) - 29.0, 0.0) * 15.0) / 5.0)) * 5)
	return int(round(v * RC_K[r] / 5.0)) * 5

# A computer club's best men: some have a release clause, and then only the clause buys them.
func cpu_clause(c: int, i: int) -> int:
	var sq := cpu_squad(c)
	if i < 0 or i >= sq.size():
		return 0
	var pl: Dictionary = sq[i]
	if pl.has("rc"):
		return int(pl["rc"])
	var ovs := []
	for x in sq:
		ovs.append(ovr_of(x))
	ovs.sort()
	ovs.reverse()
	if ovr_of(pl) < int(ovs[mini(2, ovs.size() - 1)]) or _nh(str(pl["n"]) + str(c)) % 3 != 0:
		return 0
	return int(round(value(pl) * 2.2 / 5.0)) * 5

# what your man is worth to them in a swap: only a man who would play for them, and a bit under his worth
func swap_worth(c: int, i: int, mine: int) -> int:
	var sq := cpu_squad(c)
	if mine < 0 or mine >= (d["squad"] as Array).size() or i < 0 or i >= sq.size():
		return 0
	var pl: Dictionary = d["squad"][mine]
	if injured(pl):
		return 0
	var worst := 99
	for x in sq:
		if str(x["pos"]) == str(pl["pos"]):
			worst = mini(worst, ovr_of(x))
	if ovr_of(pl) < worst - 2:
		return 0
	return int(round(value(pl) * 0.85 / 5.0)) * 5

# a man of yours leaves the squad (the eleven is fixed up first by the caller)
func _remove_mine(i: int) -> void:
	var sq: Array = d["squad"]
	sq.remove_at(i)
	var xi := []
	for x in d["xi"]:
		xi.append(int(x) - 1 if int(x) > i else int(x))
	d["xi"] = xi

# in an open window a club can pay the release clause of one of your men: he goes, you cannot stop it
func _clause_tick(rng: RandomNumberGenerator, lines: Array) -> void:
	var sq: Array = d["squad"]
	if sq.size() <= SQUAD_MIN:
		return
	for i in sq.size():
		var pl: Dictionary = sq[i]
		if not pl.has("rc"):
			continue
		var cheap := float(value(pl)) / maxf(float(pl["rc"]), 1.0)
		if rng.randf() > interest(pl) * 0.35 * clampf(cheap * 1.4, 0.3, 1.2):
			continue
		var o := ovr_of(pl)
		var cand := []
		for c in _country_clubs():
			if c != int(d["club"]) and rating(c) >= o - 3 and rating(c) >= int(my_strength()):
				cand.append(c)
		if cand.is_empty():
			continue
		var c: int = cand[rng.randi() % cand.size()]
		var fee := int(pl["rc"])
		var nm := str(pl["n"])
		_out_of_xi(i)
		var r := _sell_to(i, c, fee)
		_mail("info", "%s paid the clause for %s" % [str(cname(c)).capitalize(), nm.capitalize()], "%s paid his release clause of %s. He has gone, there was nothing you could do. %s" % [str(cname(c)).capitalize(), money(fee), r.capitalize()])
		lines.append("%s PAID %s'S RELEASE CLAUSE" % [str(cname(c)), nm.to_upper()])
		return
