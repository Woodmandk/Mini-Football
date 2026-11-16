extends RefCounted
# Ranked online, as in the 2D game: six ranks, the first five with three divisions (III, II, I) of 100 rank
# points each, then Legend with open-ended points. A win gives about +25, a loss about -18 (half in Bronze,
# three quarters in Silver), a stronger opponent gives more, win streaks a bonus. A new rank gives 3 shields:
# a loss that would drop you out of the rank uses a shield instead. Every calendar month is a season: your best
# division pays out when the next month starts and you start one rank lower. Kept on this phone ('bb3d-rank').

const KEY := "bb3d-rank"
# name, colour, dark colour, season coins
const TIERS := [["BRONZE", "d9955a", "6e3f1c", 50], ["SILVER", "d3dbe4", "59636f", 100], ["GOLD", "ffd447", "946a12", 200],
	["PLATINUM", "7fe0d4", "21746b", 350], ["DIAMOND", "86b9ff", "2a4fae", 500], ["LEGEND", "ff7ad9", "7d2470", 800]]
const DIVN := ["III", "II", "I"]
const DIV_RP := 100
const LEG_RP := 1500
const SHIELDS := 3
const WIN_COINS := 60
const DRAW_COINS := 30
const LOSS_COINS := 15

var d := {}
var web := false

func load_save(is_web: bool) -> void:
	web = is_web
	var txt := ""
	if web:
		txt = str(JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % KEY, true))
	elif FileAccess.file_exists("user://rank.json"):
		txt = FileAccess.get_file_as_string("user://rank.json")
	var v = JSON.parse_string(txt) if txt != "" else null
	d = v if v is Dictionary else {}
	for k in ["rp", "sh", "ws", "rr", "bs", "w", "dr", "l", "g"]:
		d[k] = int(d.get(k, 0))
	if not d.has("id") or str(d["id"]).length() < 8:
		# who you are on the leaderboard: made up once, on this phone
		var a := "abcdefghijklmnopqrstuvwxyz0123456789"
		var s := ""
		for i in 12:
			s += a[randi() % a.length()]
		d["id"] = s
		save()

func save() -> void:
	var txt := JSON.stringify(d)
	if web:
		JavaScriptBridge.eval("try{localStorage.setItem('%s',%s)}catch(e){}" % [KEY, JSON.stringify(txt)], true)
	else:
		var f := FileAccess.open("user://rank.json", FileAccess.WRITE)
		if f != null:
			f.store_string(txt)

static func step_name(st: int) -> String:
	if st >= 15:
		return "LEGEND"
	return "%s %s" % [TIERS[st / 3][0], DIVN[st % 3]]

static func rank_of(rp: int) -> Dictionary:
	rp = maxi(rp, 0)
	if rp >= LEG_RP:
		return {"t": 5, "dv": -1, "step": 15, "rp": rp, "n": "LEGEND", "c": TIERS[5][1], "c2": TIERS[5][2], "p": 1.0, "in": rp - LEG_RP, "need": 0, "nn": "", "floor": LEG_RP}
	var step := rp / DIV_RP
	var t := step / 3
	return {"t": t, "dv": step % 3, "step": step, "rp": rp, "n": step_name(step), "c": TIERS[t][1], "c2": TIERS[t][2],
		"p": float(rp % DIV_RP) / DIV_RP, "in": rp % DIV_RP, "need": DIV_RP - rp % DIV_RP, "nn": step_name(step + 1), "floor": t * 3 * DIV_RP}

func rp() -> int:
	return int(d["rp"])

func now() -> Dictionary:
	return rank_of(rp())

# the step reward on the rank road: more coins the higher you climb, a big one for each new rank
static func road_coins(st: int) -> int:
	return (150 + 50 * (st / 3)) if st % 3 == 0 else 25 + 15 * (st / 3)

static func month_key() -> String:
	var t := Time.get_date_dict_from_system()
	return "%04d-%02d" % [int(t["year"]), int(t["month"])]

static func days_left() -> int:
	var t := Time.get_date_dict_from_system()
	var m := int(t["month"])
	var y := int(t["year"])
	var dim: int = [31, 29 if (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]
	return dim - int(t["day"]) + 1

# A ranked result: res 1 = win, 0.5 = draw, 0 = loss. Returns what the full-time screen shows and the coins it pays.
func match_result(opp_rp: int, res: float, gd: int, gf: int) -> Dictionary:
	var me := rp()
	var k0 := rank_of(me)
	var diff := clampi(int(round((opp_rp - me) / 25.0)), -10, 10)
	var parts := []
	var ws := int(d["ws"])
	if res >= 1.0:
		ws += 1
		parts.append(["WIN", 25])
		if diff != 0:
			parts.append(["STRONGER OPPONENT" if diff > 0 else "WEAKER OPPONENT", diff])
		if ws >= 2:
			parts.append(["%d WINS IN A ROW" % ws, mini(15, 5 * (ws - 1))])
		if gd >= 3:
			parts.append(["BIG WIN", 3])
		d["w"] = int(d["w"]) + 1
	elif res >= 0.5:
		ws = 0
		parts.append(["DRAW", 5])
		if diff > 0:
			parts.append(["STRONGER OPPONENT", ceili(diff / 2.0)])
		d["dr"] = int(d["dr"]) + 1
	else:
		ws = 0
		parts.append(["LOSS", -18])
		if diff != 0:
			parts.append(["STRONGER OPPONENT" if diff > 0 else "WEAKER OPPONENT", int(round(diff / 2.0))])
		var sum := 0
		for q in parts:
			sum += int(q[1])
		if k0["t"] == 0:
			parts.append(["BRONZE: ONLY HALF", -int(round(sum / 2.0))])
		elif k0["t"] == 1:
			parts.append(["SILVER: ONLY THREE QUARTERS", -int(round(sum / 4.0))])
		d["l"] = int(d["l"]) + 1
	d["g"] = int(d["g"]) + gf
	var tot := 0
	for q in parts:
		tot += int(q[1])
	var nrp := maxi(0, me + tot)
	var shield := false
	var sh := int(d["sh"])
	if nrp < int(k0["floor"]) and int(k0["t"]) > 0 and sh > 0:
		sh -= 1
		shield = true
		nrp = int(k0["floor"])
	var k1 := rank_of(nrp)
	if int(k1["t"]) > int(k0["t"]):
		sh = SHIELDS
	var coins := WIN_COINS if res >= 1.0 else (DRAW_COINS if res >= 0.5 else LOSS_COINS)
	var road := []
	var rr := int(d.get("rr", k0["step"]))
	for st in range(rr + 1, int(k1["step"]) + 1):
		var c := road_coins(st)
		coins += c
		road.append("%s: +%d COINS" % [step_name(st), c])
	d["rr"] = maxi(rr, int(k1["step"]))
	d["rp"] = nrp
	d["sh"] = sh
	d["ws"] = ws
	d["bs"] = maxi(int(d["bs"]), int(k1["step"]))
	if not d.has("sm"):
		d["sm"] = month_key()
	save()
	return {"k0": k0, "k1": k1, "delta": nrp - me, "parts": parts, "shield": shield, "sh": sh, "ws": ws, "road": road, "coins": coins,
		"up": int(k1["step"]) > int(k0["step"]), "down": int(k1["step"]) < int(k0["step"]), "tier_up": int(k1["t"]) > int(k0["t"])}

# A new month = a new rank season. Returns [message, coins] for the season that ended (or ["", 0]).
func season() -> Array:
	var mk := month_key()
	if str(d.get("sm", "")) == mk:
		return ["", 0]
	var played := int(d["w"]) + int(d["dr"]) + int(d["l"]) > 0
	var msg := ""
	var coins := 0
	if d.has("sm") and played:
		var best := maxi(int(d["bs"]), int(now()["step"]))
		var t := mini(5, best / 3)
		coins = int(TIERS[t][3])
		msg = "LAST MONTH'S RANK SEASON IS OVER. YOU REACHED %s: +%d COINS. THE NEW SEASON STARTS YOU ONE RANK LOWER." % [step_name(best), coins]
		var t0 := int(now()["t"])
		d["rp"] = (t0 - 1) * 3 * DIV_RP if t0 >= 1 else 0
		d["sh"] = 0
		d["ws"] = 0
		d["rr"] = int(rank_of(int(d["rp"]))["step"])
		d["bs"] = d["rr"]
	d["sm"] = mk
	save()
	return [msg, coins]
