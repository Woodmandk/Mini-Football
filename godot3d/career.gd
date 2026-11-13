extends RefCounted
# Career: your own club in a league of eight. Holds the save, the fixtures, the table and the squad.

const KEY := "bb3d-career"
const ROLE_BASE := {"GK": [52, 30, 62, 74], "DF": [68, 46, 64, 76], "MF": [70, 66, 77, 64], "FW": [79, 77, 66, 42]}
const SQUAD_ROLES := ["GK", "DF", "DF", "DF", "DF", "MF", "MF", "MF", "FW", "FW", "FW", "GK", "DF", "MF", "MF", "FW"]
const SQUAD_NUMS := [1, 3, 4, 5, 2, 8, 6, 10, 11, 9, 7, 12, 14, 15, 16, 17]
const STAT_NAMES := ["PACE", "SHOOTING", "PASSING", "DEFENDING"]
const STAT_KEYS := ["pac", "sho", "pas", "dfn"]

var d := {}
var web := false

func has_save() -> bool:
	return not d.is_empty()

func load_save(is_web: bool) -> void:
	web = is_web
	var txt := ""
	if web:
		txt = str(JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % KEY, true))
	elif FileAccess.file_exists("user://career.json"):
		txt = FileAccess.get_file_as_string("user://career.json")
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

func save() -> void:
	var txt := JSON.stringify(d)
	if web:
		JavaScriptBridge.eval("try{localStorage.setItem('%s',%s)}catch(e){}" % [KEY, JSON.stringify(txt)], true)
	else:
		var f := FileAccess.open("user://career.json", FileAccess.WRITE)
		if f != null:
			f.store_string(txt)

func wipe() -> void:
	d = {}
	if web:
		JavaScriptBridge.eval("try{localStorage.removeItem('%s')}catch(e){}" % KEY, true)
	elif FileAccess.file_exists("user://career.json"):
		DirAccess.remove_absolute("user://career.json")

static func ovr_of(p: Dictionary) -> int:
	match str(p["pos"]):
		"GK": return int(round(p["dfn"] * 0.8 + p["pas"] * 0.2))
		"DF": return int(round(p["dfn"] * 0.55 + p["pac"] * 0.25 + p["pas"] * 0.2))
		"MF": return int(round(p["pas"] * 0.45 + p["pac"] * 0.2 + p["sho"] * 0.2 + p["dfn"] * 0.15))
	return int(round(p["sho"] * 0.5 + p["pac"] * 0.35 + p["pas"] * 0.15))

func new_career(club: int, n_clubs: int, names: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pool := names.duplicate()
	pool.shuffle()
	var squad := []
	for i in SQUAD_ROLES.size():
		var role: String = SQUAD_ROLES[i]
		var base: Array = ROLE_BASE[role]
		# a young squad that starts a little under the league and grows
		var q := -6 if i < 11 else -10
		var pl := {
			"n": pool[i], "num": SQUAD_NUMS[i], "pos": role, "age": rng.randi_range(18, 29), "xp": 0, "g": 0, "apps": 0,
			"pac": clampi(base[0] + q + rng.randi_range(-4, 4), 30, 95), "sho": clampi(base[1] + q + rng.randi_range(-4, 4), 25, 95),
			"pas": clampi(base[2] + q + rng.randi_range(-4, 4), 30, 95), "dfn": clampi(base[3] + q + rng.randi_range(-4, 4), 25, 95),
		}
		pl["pot"] = clampi(ovr_of(pl) + rng.randi_range(6, 16) - maxi(int(pl["age"]) - 24, 0), 60, 94)
		squad.append(pl)
	d = {"club": club, "season": 1, "round": 0, "coins": 100, "squad": squad, "xi": range(11), "n": n_clubs, "last": [], "note": ""}
	_new_season()
	save()

func _new_season() -> void:
	var n: int = int(d["n"])
	# round robin by the circle method, then the same again with home and away swapped
	var ids := []
	for i in n:
		ids.append(i)
	var rounds := []
	for r in n - 1:
		var rd := []
		for i in n / 2:
			var a: int = ids[i]
			var b: int = ids[n - 1 - i]
			rd.append([a, b] if (r + i) % 2 == 0 else [b, a])
		rounds.append(rd)
		ids.insert(1, ids.pop_back())
	var back := []
	for rd in rounds:
		var rd2 := []
		for m in rd:
			rd2.append([m[1], m[0]])
		back.append(rd2)
	d["fix"] = rounds + back
	var table := []
	for i in n:
		table.append({"p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0})
	d["table"] = table
	d["round"] = 0
	d["last"] = []

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
func club_level(c: int) -> int:
	return [0, 2, -3, 4, 1, -2, 3, -4][c % 8] + (int(d.get("season", 1)) - 1)

func my_strength() -> float:
	var s := 0.0
	for i in d["xi"]:
		s += ovr_of(d["squad"][int(i)])
	return s / 11.0

func _strength(c: int) -> float:
	if c == int(d["club"]):
		return my_strength()
	return 71.0 + club_level(c)

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
	var ta: Dictionary = d["table"][a]
	var tb: Dictionary = d["table"][b]
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

# Books your result, plays the rest of the round, pays out coins and grows the players who played.
# Returns lines for the full-time screen.
func finish_match(mine: int, theirs: int, scorers: Array) -> Array:
	var me: int = int(d["club"])
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
	d["round"] = int(d["round"]) + 1
	var lines := []
	var coins := 15 + mine * 5 + (40 if mine > theirs else (15 if mine == theirs else 0))
	d["coins"] = int(d["coins"]) + coins
	lines.append("+%d COINS" % coins)
	for i in d["xi"]:
		var pl: Dictionary = d["squad"][int(i)]
		pl["apps"] = int(pl["apps"]) + 1
		var xp := 22 + (10 if mine > theirs else 0)
		for s in scorers:
			if int(s) == int(i):
				xp += 14
				pl["g"] = int(pl["g"]) + 1
		pl["xp"] = int(pl["xp"]) + xp
		while int(pl["xp"]) >= 100 and ovr_of(pl) < int(pl["pot"]):
			pl["xp"] = int(pl["xp"]) - 100
			var k := _grow_key(pl, rng)
			pl[k] = int(pl[k]) + 1
			lines.append("%s  +1 %s" % [str(pl["n"]).to_upper(), STAT_NAMES[STAT_KEYS.find(k)]])
		if int(pl["xp"]) > 100:
			pl["xp"] = 100
	if season_over():
		var pos := rank_of(me)
		var prize: int = [300, 200, 140, 100, 70, 50, 30, 20][clampi(pos - 1, 0, 7)]
		d["coins"] = int(d["coins"]) + prize
		d["note"] = "SEASON %d OVER: YOU FINISHED %s.  +%d COINS" % [int(d["season"]), ordinal(pos), prize]
	save()
	return lines

static func ordinal(n: int) -> String:
	return str(n) + (["TH", "ST", "ND", "RD"][n] if n < 4 else "TH")

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
	d["season"] = int(d["season"]) + 1
	d["note"] = ""
	for pl in d["squad"]:
		pl["age"] = int(pl["age"]) + 1
		pl["g"] = 0
		pl["apps"] = 0
	_new_season()
	save()

# Clubs in table order (points, goal difference, goals for).
func order() -> Array:
	var ids := []
	for i in int(d["n"]):
		ids.append(i)
	var t: Array = d["table"]
	ids.sort_custom(func(a, b):
		var ka := [int(t[a]["pts"]), int(t[a]["gf"]) - int(t[a]["ga"]), int(t[a]["gf"])]
		var kb := [int(t[b]["pts"]), int(t[b]["gf"]) - int(t[b]["ga"]), int(t[b]["gf"])]
		return ka > kb if ka != kb else a < b)
	return ids

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

func train_cost(pl: Dictionary) -> int:
	return 40 + maxi(ovr_of(pl) - 60, 0) * 6

# Spend coins on one training session: +1 in a stat that suits the position.
func train(i: int) -> String:
	var pl: Dictionary = d["squad"][i]
	var c := train_cost(pl)
	if int(d["coins"]) < c or ovr_of(pl) >= int(pl["pot"]):
		return ""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var k := _grow_key(pl, rng)
	pl[k] = int(pl[k]) + 1
	d["coins"] = int(d["coins"]) - c
	save()
	return "%s  +1 %s" % [str(pl["n"]).to_upper(), STAT_NAMES[STAT_KEYS.find(k)]]
