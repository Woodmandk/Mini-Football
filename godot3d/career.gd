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

var last_coins := 0
var names := []

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

func form() -> String:
	return str(d.get("form", "4-3-3"))

# New formation: pick the best eleven for the new places, best player first for each role.
func set_form(name: String, roles: Array) -> void:
	d["form"] = name
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

# A career match played together on a friend's career: your own club gets the same coins and your starters grow too.
func coop_reward(coins: int, won: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	d["coins"] = int(d["coins"]) + coins
	var lines := ["+%d COINS FOR YOUR OWN CLUB" % coins]
	for i in d["xi"]:
		var pl: Dictionary = d["squad"][int(i)]
		pl["xp"] = int(pl["xp"]) + 22 + (10 if won else 0)
		# a full bar gives a training point: you choose what he learns
		while int(pl["xp"]) >= 100 and ovr_of(pl) + int(pl.get("tp", 0)) < int(pl["pot"]):
			pl["xp"] = int(pl["xp"]) - 100
			pl["tp"] = int(pl.get("tp", 0)) + 1
			lines.append("%s  +1 TP" % str(pl["n"]).to_upper())
		if int(pl["xp"]) > 100:
			pl["xp"] = 100
	save()
	return lines

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
func finish_match(mine: int, theirs: int, scorers: Array, played: Array = []) -> Array:
	var me: int = int(d["club"])
	var was_home: bool = next_match()[1]
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
	var stt: Dictionary = stats()
	stt["p"] = int(stt["p"]) + 1
	stt["w" if mine > theirs else ("d" if mine == theirs else "l")] = int(stt["w" if mine > theirs else ("d" if mine == theirs else "l")]) + 1
	stt["gf"] = int(stt["gf"]) + mine
	stt["ga"] = int(stt["ga"]) + theirs
	d["st"] = stt
	var lines := []
	var coins := 15 + mine * 5 + (40 if mine > theirs else (15 if mine == theirs else 0))
	d["coins"] = int(d["coins"]) + coins
	last_coins = coins
	market_refresh()
	lines.append("+%d COINS" % coins)
	if was_home:
		# the gate: a bigger stadium and a club near the top bring more people in
		var gate := fac("stadium") * 9 + (6 if rank_of(me) <= 3 else 0)
		d["coins"] = int(d["coins"]) + gate
		lines.append("+%d FROM THE GATE" % gate)
	for i in (played if not played.is_empty() else d["xi"]):
		var pl: Dictionary = d["squad"][int(i)]
		pl["apps"] = int(pl["apps"]) + 1
		var xp := int(round((22 + (10 if mine > theirs else 0)) * (1.0 + 0.15 * (fac("training") - 1))))
		for s in scorers:
			if int(s) == int(i):
				xp += 14
				pl["g"] = int(pl["g"]) + 1
		pl["xp"] = int(pl["xp"]) + xp
		# a full bar gives a training point: you choose what he learns
		while int(pl["xp"]) >= 100 and ovr_of(pl) + int(pl.get("tp", 0)) < int(pl["pot"]):
			pl["xp"] = int(pl["xp"]) - 100
			pl["tp"] = int(pl.get("tp", 0)) + 1
			lines.append("%s  +1 TP" % str(pl["n"]).to_upper())
		if int(pl["xp"]) > 100:
			pl["xp"] = 100
	# the youth academy sends a talent up twice a season
	if int(d["round"]) == rounds_total() / 2 or season_over():
		var yn := youth_arrives(rng)
		if yn != "":
			lines.append(yn)
	if season_over():
		var pos := rank_of(me)
		var prize: int = [300, 200, 140, 100, 70, 50, 30, 20][clampi(pos - 1, 0, 7)]
		d["coins"] = int(d["coins"]) + prize
		if pos == 1:
			stt["titles"] = int(stt["titles"]) + 1
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
		return {"err": "You need %d more coins." % (PACK_COST[tier] - int(d["coins"]))}
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
	var t: Dictionary = d["table"][int(d["club"])]
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
		return "You need %d more coins." % (price - int(d["coins"]))
	var used := []
	for s in d["squad"]:
		used.append(int(s["num"]))
	for n in range(2, 99):
		if not used.has(n):
			pl["num"] = n
			break
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
	var got := sell_value(pl)
	d["coins"] = int(d["coins"]) + got
	sq.remove_at(i)
	var xi := []
	for x in d["xi"]:
		xi.append(int(x) - 1 if int(x) > i else int(x))
	d["xi"] = xi
	save()
	return "%s SOLD FOR %d COINS" % [str(pl["n"]).to_upper(), got]

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
		return "You need %d more coins." % (c - int(d["coins"]))
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
	var used := []
	for s in d["squad"]:
		used.append(int(s["num"]))
	for n in range(20, 99):
		if not used.has(n):
			pl["num"] = n
			break
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
