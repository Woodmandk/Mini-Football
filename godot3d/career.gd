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
			if not d.has("abv"):
				_ab_start()
				save()

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
	_ab_start()
	_new_season()
	board()
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
	return [0, 2, -3, 4, 1, -2, 3, -4][c % 8] + (4 - div()) * 4

# The career is a ladder of four divisions: you start in Division 4. The top two go up, the bottom two go down.
func div() -> int:
	return clampi(int(d.get("div", 4)), 1, 4)

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
	d["round"] = int(d["round"]) + 1
	var stt: Dictionary = stats()
	stt["p"] = int(stt["p"]) + 1
	stt["w" if mine > theirs else ("d" if mine == theirs else "l")] = int(stt["w" if mine > theirs else ("d" if mine == theirs else "l")]) + 1
	stt["gf"] = int(stt["gf"]) + mine
	stt["ga"] = int(stt["ga"]) + theirs
	d["st"] = stt
	var lines := []
	var coins := 15 + mine * 5 + (40 if mine > theirs else (15 if mine == theirs else 0))
	coins += board_bonus(coins)
	d["coins"] = int(d["coins"]) + coins
	last_coins = coins
	market_refresh()
	lines.append("+%d COINS" % coins)
	lines.append(_board_match(mine, theirs, opp_c, was_home, played if not played.is_empty() else d["xi"]))
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
		var prize: int = int([300, 200, 140, 100, 70, 50, 30, 20][clampi(pos - 1, 0, 7)] * (1.0 + (4 - div()) * 0.5))
		d["coins"] = int(d["coins"]) + prize
		if pos == 1:
			stt["titles"] = int(stt["titles"]) + 1
		var mv := 0
		var what := ""
		if pos <= 2 and div() > 1:
			mv = -1
			what = "  PROMOTED TO DIVISION %d!" % (div() - 1)
		elif pos >= 7 and div() < 4:
			mv = 1
			what = "  RELEGATED TO DIVISION %d." % (div() + 1)
		elif pos == 1:
			what = "  CHAMPIONS OF DIVISION 1!"
		d["move"] = mv
		d["note"] = "DIVISION %d, SEASON %d: YOU FINISHED %s.%s  +%d COINS" % [div(), int(d["season"]), ordinal(pos), what, prize]
		_board_review()
		lines.append("SEASON OVER: THE BOARD'S GRADE IS %s" % str(review().get("grade", "C")))
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
	d["div"] = clampi(div() + int(d.get("move", 0)), 1, 4)
	d["move"] = 0
	d["note"] = ""
	for pl in d["squad"]:
		pl["age"] = int(pl["age"]) + 1
		pl["g"] = 0
		pl["apps"] = 0
	_new_season()
	# a new cup every season, and new goals from the board
	cup_new()
	board()
	(d["board"] as Dictionary).erase("review")
	_board_season()
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
	if rng.randf() < 0.2 + lv * 0.06:
		pl["ab"] = ab_roll(role, 70, rng).slice(0, 1)
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

# ---------------------------------------------------------------- the cup
# A knockout cup for the eight clubs: quarter-final, semi-final, final. It runs beside the league and can be
# started again as soon as you are out or have won it.
const CUP_ROUNDS := ["QUARTER-FINAL", "SEMI-FINAL", "FINAL"]

func cup() -> Dictionary:
	if not d.has("cup"):
		cup_new()
	return d["cup"]

func cup_new() -> void:
	var ids := []
	for i in int(d["n"]):
		ids.append(i)
	ids.shuffle()
	d["cup"] = {"r": 0, "teams": ids, "out": false, "won": false, "log": [], "n": int(d.get("cup", {}).get("n", 0)) + 1}
	save()

func cup_over() -> bool:
	var cp: Dictionary = cup()
	return bool(cp["out"]) or bool(cp["won"])

# The club you meet in this round, or -1 when your cup is over.
func cup_opp() -> int:
	var cp: Dictionary = cup()
	if cup_over():
		return -1
	var t: Array = cp["teams"]
	var i: int = t.find(float(int(d["club"])))
	if i < 0:
		i = t.find(int(d["club"]))
	if i < 0:
		return -1
	return int(t[i + 1]) if i % 2 == 0 else int(t[i - 1])

func cup_round_name() -> String:
	return CUP_ROUNDS[clampi(int(cup()["r"]), 0, 2)]

# Books your cup tie and plays the others. Returns lines for the full-time screen.
func cup_finish(mine: int, theirs: int, won_tie := false) -> Array:
	var cp: Dictionary = cup()
	var me: int = int(d["club"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var t: Array = cp["teams"]
	var r: int = int(cp["r"])
	var next := []
	var res := []
	var lines := []
	# a level tie was settled by the shootout
	var won: bool = mine > theirs or (mine == theirs and won_tie)
	for i in range(0, t.size(), 2):
		var a: int = int(t[i])
		var b: int = int(t[i + 1])
		var ga := 0
		var gb := 0
		if a == me or b == me:
			ga = mine if a == me else theirs
			gb = theirs if a == me else mine
			next.append(me if won else (b if a == me else a))
		else:
			var diff := (_strength(a) - _strength(b)) / 14.0
			ga = _poisson(rng, 1.35 * exp(diff))
			gb = _poisson(rng, 1.35 * exp(-diff))
			if ga == gb:
				if rng.randf() < 0.5:
					ga += 1
				else:
					gb += 1
			next.append(a if ga > gb else b)
		res.append([a, b, ga, gb])
	(cp["log"] as Array).append(res)
	var stt: Dictionary = stats()
	var coins := 10 + mine * 5
	if won:
		coins += [60, 100, 250][clampi(r, 0, 2)]
		if r >= 2:
			cp["won"] = true
			stt["cups"] = int(stt.get("cups", 0)) + 1
			lines.append("YOU WON THE CUP!")
		else:
			cp["r"] = r + 1
			cp["teams"] = next
			lines.append("THROUGH TO THE %s" % CUP_ROUNDS[r + 1])
	else:
		cp["out"] = true
		lines.append("OUT OF THE CUP IN THE %s" % CUP_ROUNDS[clampi(r, 0, 2)])
	d["st"] = stt
	coins += board_bonus(coins)
	d["coins"] = int(d["coins"]) + coins
	last_coins = coins
	lines.insert(0, "+%d COINS" % coins)
	lines.insert(1, _board_cup(won, r))
	# the men who played learn from a cup tie too
	for i in d["xi"]:
		var pl: Dictionary = d["squad"][int(i)]
		pl["xp"] = int(pl["xp"]) + (30 if won else 20)
		while int(pl["xp"]) >= 100 and ovr_of(pl) + int(pl.get("tp", 0)) < int(pl["pot"]):
			pl["xp"] = int(pl["xp"]) - 100
			pl["tp"] = int(pl.get("tp", 0)) + 1
			lines.append("%s  +1 TP" % str(pl["n"]).to_upper())
		if int(pl["xp"]) > 100:
			pl["xp"] = 100
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
		return "You need %d more coins." % (c - int(d["coins"]))
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
const CUP_AT := [3, 7, 11] # league rounds played before each cup round is due: the cup is part of the season
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
	for c in int(d["n"]):
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
	var lg := {}
	if ex <= 1:
		lg = {"k": "pos", "v": 1, "t": "WIN THE LEAGUE"} if dv == 1 else {"k": "pos", "v": 2, "t": "WIN PROMOTION: FINISH IN THE TOP 2"}
	elif ex <= 3:
		lg = {"k": "pos", "v": 3, "t": "FINISH IN THE TOP 3"} if dv == 1 else {"k": "pos", "v": 3, "t": "CHALLENGE FOR PROMOTION: TOP 3"}
	elif ex <= 5:
		lg = {"k": "pos", "v": 4, "t": "FINISH IN THE TOP HALF"}
	else:
		lg = {"k": "pos", "v": 6, "t": "STAY OUT OF THE BOTTOM TWO"}
	var cp := {}
	if ex <= 1 and dv <= 2:
		cp = {"k": "cup", "v": 3, "t": "WIN THE CUP"}
	elif ex <= 3:
		cp = {"k": "cup", "v": 2, "t": "REACH THE CUP FINAL"}
	else:
		cp = {"k": "cup", "v": 1, "t": "REACH THE CUP SEMI-FINAL"}
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
			var g := 30 - ex * 2
			ex3 = {"k": "goals", "v": g, "t": "SCORE %d LEAGUE GOALS" % g}
		"cs":
			var c := 5 if ex <= 3 else (4 if ex <= 5 else 3)
			ex3 = {"k": "cs", "v": c, "t": "KEEP %d CLEAN SHEETS IN THE LEAGUE" % c}
		"build":
			ex3 = {"k": "build", "v": 1, "t": "BUILD ONE NEW LEVEL AT THE CLUB"}
		"home":
			var l := 1 if ex <= 3 else 2
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
			var names := ["QUARTER-FINAL", "SEMI-FINAL", "FINAL", "WON"]
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
	var ids := []
	for c in int(d["n"]):
		if c != me:
			ids.append(c)
	ids.shuffle()
	var offers := []
	var dv := div()
	for i in 3:
		offers.append([int(ids[i]), clampi(dv + (0 if i == 0 else 1), 1, 4)])
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
	d["div"] = int(of[i][1])
	d["move"] = 0
	d.erase("own")
	d.erase("lay")
	d.erase("form")
	d.erase("sacked")
	d.erase("offers")
	d["fac"] = {}
	d["coins"] = 200
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var q := club_level(c) - 2
	d["squad"] = _make_squad(q, q - 5, rng)
	d["xi"] = range(11)
	d["season"] = int(d["season"]) + 1
	d["note"] = ""
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
func cup_due() -> bool:
	if cup_over():
		return false
	var r := clampi(int(cup()["r"]), 0, 2)
	return int(d["round"]) >= CUP_AT[r] or season_over()

func cup_after() -> int:
	return CUP_AT[clampi(int(cup()["r"]), 0, 2)]
