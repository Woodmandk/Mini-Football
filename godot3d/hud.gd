extends Control
# Everything drawn on top of the 3D view: touch controls, score bug, banners, minimap and all menus.

var stick := Vector2.ZERO
var shoot_down := false
var pass_down := false
var sprint_down := false
var lob_down := false
var thru_down := false
var hi_btn := ""
var _starts := {}
var ev := [] # queued events: "shoot_down", "shoot_up", "pass_down", "pass_up", "cam", "pause", "tap"
var charge := 0.0
var stam := 1.0
var ctrl_name := ""
var pro_rt := -1.0 # the player career: your match rating, live (-1 = not shown)
var _prt_prev := -1.0
var _prt_t := 9.0
var _prt_dir := 0.0
var lab_a := "SHOOT"
var lab_b := "PASS"
var show_controls := false
var in_match := false
var replay_on := false
var cam_name := "TV"
var mm_pts := PackedVector3Array()
var mm_ball := Vector2.ZERO
var on_action: Callable

var _stick_id := -1
var _stick_base := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _ids := {}
var font: Font
var font2: Font
var font3: Font # body text, bold
var _t := 0.0

var score_lbl: Label
var clock_lbl: Label
var banner: Label
var sub: Label
var flash: ColorRect
var bug: Panel
var menu: Control
var menu_name := ""
var _info := {}
var _banner_tw: Tween
var _toast: Label
var _toast_tw: Tween
var _code := ""
var vs_t := -1.0
var vs_len := 0.0
var vs_names := ["", ""]
var vs_stars := ["", ""]
var vs_swap := false
var t_names := ["RED BISON", "HARBOUR SHARKS"]
var t_short := ["BIS", "SHA"]
var t_cols := [Color(0.86, 0.14, 0.14), Color(0.16, 0.38, 0.92)]
var _c1: ColorRect
var _c2: ColorRect

const STICK_R := 62.0
const SPRINT_R := 1.42
const GREEN := Color(0.2, 0.78, 0.38)
const GOLD := Color(1.0, 0.84, 0.25)
const WRONG := Color(1.0, 0.55, 0.18) # a man out of position
const DARK := Color(0.04, 0.08, 0.06)
const RankC := preload("res://rank.gd")
const Career := preload("res://career.gd")

var _last_size := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	font2 = font
	if ResourceLoader.exists("res://fonts/ChakraPetch-Bold.ttf"):
		font = load("res://fonts/ChakraPetch-Bold.ttf")
		font2 = load("res://fonts/ChakraPetch-SemiBold.ttf")
	font3 = font2
	# body text: Barlow Semi Condensed reads better small than the display face, and fits more in a line
	if ResourceLoader.exists("res://fonts/BarlowSemiCondensed-SemiBold.woff2"):
		font2 = load("res://fonts/BarlowSemiCondensed-SemiBold.woff2")
		font3 = load("res://fonts/BarlowSemiCondensed-Bold.woff2")
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	# score bug
	bug = Panel.new()
	bug.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.85), 10, Color(1, 1, 1, 0.14)))
	bug.position = Vector2(18, 14)
	bug.size = Vector2(292, 44)
	bug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bug)
	var c1 := ColorRect.new()
	_c1 = c1
	c1.color = Color(0.86, 0.16, 0.16)
	c1.position = Vector2(10, 10)
	c1.size = Vector2(6, 24)
	bug.add_child(c1)
	var c2 := ColorRect.new()
	_c2 = c2
	c2.color = Color(0.2, 0.42, 0.95)
	c2.position = Vector2(206, 10)
	c2.size = Vector2(6, 24)
	bug.add_child(c2)
	score_lbl = _label("BIS  0 - 0  SHA", 22, Color.WHITE)
	score_lbl.position = Vector2(22, 6)
	score_lbl.size = Vector2(184, 32)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bug.add_child(score_lbl)
	clock_lbl = _label("0'", 20, GOLD)
	clock_lbl.position = Vector2(220, 7)
	clock_lbl.size = Vector2(64, 32)
	clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bug.add_child(clock_lbl)
	# banners
	banner = _label("", 96, Color.WHITE)
	banner.add_theme_constant_override("outline_size", 18)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0
	add_child(banner)
	sub = _label("", 28, Color.WHITE)
	sub.add_theme_constant_override("outline_size", 8)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.modulate.a = 0.0
	add_child(sub)
	_toast = _label("", 20, Color.WHITE)
	_toast.add_theme_stylebox_override("normal", _box(Color(DARK.r, DARK.g, DARK.b, 0.92), 12, Color(1, 1, 1, 0.2), 16))
	_toast.modulate.a = 0.0
	add_child(_toast)

# ---------------------------------------------------------------- small builders

func _box(bg: Color, radius := 12, border := Color(0, 0, 0, 0), pad := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(2)
	if pad > 0:
		s.content_margin_left = pad
		s.content_margin_right = pad
		s.content_margin_top = pad * 0.5
		s.content_margin_bottom = pad * 0.5
	return s

func _label(text: String, fs: int, col: Color, f: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f if f != null else font)
	l.add_theme_font_size_override("font_size", maxi(fs, _min_fs))
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _btn(text: String, act: String, arg, kind: String, pos: Vector2, sz: Vector2, fs := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.pivot_offset = sz * 0.5
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", maxi(fs, _min_fs))
	var bg := GREEN
	var fg := Color(0.02, 0.1, 0.04)
	var border := Color(0, 0, 0, 0)
	if kind == "alt":
		bg = Color(0.082, 0.188, 0.122, 0.97)
		fg = Color.WHITE
		border = Color(0.918, 0.949, 0.925, 0.16)
	elif kind == "ghost":
		bg = Color(0.04, 0.09, 0.06, 0.55)
		fg = Color(1, 1, 1, 0.92)
		border = Color(0.918, 0.949, 0.925, 0.2)
	elif kind == "off":
		bg = Color(0.2, 0.22, 0.21, 0.8)
		fg = Color(1, 1, 1, 0.4)
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, _box(bg, 14, border))
	b.add_theme_stylebox_override("pressed", _box(bg.lightened(0.18), 14, border))
	b.add_theme_stylebox_override("disabled", _box(bg, 14, border))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, fg)
	if kind == "off":
		b.disabled = true
	b.button_down.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.93, 0.93), 0.06))
	b.button_up.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.pressed.connect(func():
		if b.has_meta("dragged"):
			# the finger moved the button: that was a drag, not a tap
			b.remove_meta("dragged")
			return
		if on_action.is_valid():
			on_action.call(act, arg))
	return b

# Every sub-page: the same back button top left (chevron + "Back").
func _back(act: String, arg) -> Button:
	var b := _btn("Back", act, arg, "ghost", Vector2(16, 14), Vector2(116, 48), 20)
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_theme_constant_override("h_separation", 0)
	for st in ["normal", "hover", "focus", "pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(st)
		sb.content_margin_right = 20
	var ch := Control.new()
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.position = Vector2(18, 14)
	ch.size = Vector2(14, 20)
	ch.draw.connect(func():
		ch.draw_polyline(PackedVector2Array([Vector2(11, 1), Vector2(3, 10), Vector2(11, 19)]), Color(1, 1, 1, 0.92), 3.0, true))
	b.add_child(ch)
	return b

# Team screen: a player plate you can pick up and move. ctx holds the pitch rect and every plate.
# Drop on the grass = his new spot (pitch plates only), drop on another plate = swap the two men.
func _drag_plate(b: Button, sq_i: int, slot: int, ctx: Dictionary) -> void:
	var st := {"on": false, "down": false, "from": Vector2.ZERO, "start": Vector2.ZERO, "tag": null}
	b.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				st["down"] = true
				st["on"] = false
				st["from"] = b.get_global_transform() * e.position
				st["start"] = b.position
			elif st["down"]:
				st["down"] = false
				if not st["on"]:
					return
				b.set_meta("dragged", true)
				b.z_index = 0
				ctx["pc"].set_meta("drag", false)
				ctx["pc"].queue_redraw()
				var c: Vector2 = b.position + b.size * 0.5
				# on top of a team mate (or a bench man)?
				for pl in ctx["plates"]:
					var ob: Button = pl[0]
					if ob == b or not is_instance_valid(ob):
						continue
					if slot < 0 and int(pl[2]) < 0:
						continue
					if Rect2(ob.position, ob.size).grow(4.0).has_point(c):
						on_action.call("c_swap", [sq_i, int(pl[1])])
						return
				var pr := Rect2(ctx["px"], ctx["py"], ctx["pw"], ctx["ph"])
				if slot > 0 and pr.has_point(c):
					var sp: Array = _plate_spot(b.position, ctx)
					on_action.call("c_spot", [slot, sp[0], sp[1]])
					return
				# nowhere useful: back where he was
				var tw := b.create_tween()
				tw.tween_property(b, "position", st["start"], 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				if st["tag"] != null and is_instance_valid(st["tag"]):
					st["tag"].queue_free()
					st["tag"] = null
		elif e is InputEventMouseMotion and st["down"]:
			var mp: Vector2 = b.get_global_transform() * e.position
			if not st["on"] and mp.distance_to(st["from"]) > 12.0:
				st["on"] = true
				b.z_index = 20
				ctx["pc"].set_meta("drag", slot > 0)
				ctx["pc"].queue_redraw()
				if slot > 0:
					var tg := _label("", 13, Color(0.03, 0.06, 0.03))
					tg.position = Vector2(b.size.x * 0.5 - 22, -22)
					tg.size = Vector2(44, 19)
					tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
					b.add_child(tg)
					st["tag"] = tg
			if st["on"]:
				var np: Vector2 = st["start"] + (mp - st["from"])
				if slot > 0:
					# a pitch man stays on the pitch
					np.x = clampf(np.x, ctx["px"] + 4.0, ctx["px"] + ctx["pw"] - b.size.x - 4.0)
					np.y = clampf(np.y, ctx["py"] + 4.0, ctx["py"] + ctx["ph"] - b.size.y - 4.0)
				b.position = np
				if st["tag"] != null and is_instance_valid(st["tag"]):
					var role := _role_at(float(_plate_spot(np, ctx)[0]))
					st["tag"].text = role
					st["tag"].add_theme_stylebox_override("normal", _box(ctx["pcol"].get(role, Color.WHITE), 6))
	)

# Plate top-left on the upright pitch -> [along 0..1, across -1..1] (inverse of the squad layout).
func _plate_spot(tl: Vector2, ctx: Dictionary) -> Array:
	var px: float = ctx["px"]
	var py: float = ctx["py"]
	var pw: float = ctx["pw"]
	var ph: float = ctx["ph"]
	var bw: float = ctx["bw"]
	var ax := clampf((tl.x - px - 14.0) / maxf(pw - 28.0 - bw, 1.0), 0.0, 1.0)
	var up := (py + ph - 60.0 - tl.y) / maxf(ph - 74.0, 1.0)
	var along := clampf(0.15 + (up - 0.17) / 0.72 * 0.59, 0.08, 0.80)
	return [along, ax * 2.0 - 1.0]

static func _role_at(along: float) -> String:
	if along < 0.29:
		return "DF"
	if along < 0.60:
		return "MF"
	return "FW"

# club money as the player reads it: coins outside, euros inside the career mode
func _m(n: int) -> String:
	return Career.eur_text(n) if bool(_info.get("eur", false)) else "%d COINS" % n

func _mp(n: int) -> String:
	return Career.eur_text(n) if bool(_info.get("eur", false)) else str(n)

func _mb(n: int) -> String:
	return ("BUDGET  " + Career.eur_text(n)) if bool(_info.get("eur", false)) else "COINS  %d" % n

func _mw() -> String:
	return "money" if bool(_info.get("eur", false)) else "coins"

func _ord(n: int) -> String:
	return Career.ordinal(n)

func _fit_col(c: int) -> Color:
	return GREEN if c >= 80 else (GOLD if c >= 60 else Color(0.92, 0.35, 0.3))

# One squad player as a button: position stripe, name, rating.
func _player_btn(pl: Dictionary, idx: int, pos: Vector2, sz: Vector2, pcol: Dictionary, chosen: bool, wrong_at: String) -> Button:
	var nm := str(pl["n"])
	if nm.length() > 9:
		nm = nm.substr(0, 9)
	var b := _btn("", "c_pick", idx, "alt", pos, sz, 15)
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, _box(Color(0.20, 0.25, 0.22, 0.97) if chosen else Color(0.06, 0.10, 0.08, 0.94), 10, GOLD if chosen else Color(1, 1, 1, 0.2)))
	var chip := ColorRect.new()
	chip.color = pcol.get(str(pl["pos"]), Color.WHITE)
	chip.position = Vector2(6, 7)
	chip.size = Vector2(6, sz.y - 14)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(chip)
	var n1 := _label(nm.capitalize(), 19, Color.WHITE, font3)
	n1.position = Vector2(18, 1)
	n1.clip_text = true
	n1.size = Vector2(sz.x - 22, 24)
	b.add_child(n1)
	# his own position, and where he stands when that is another place (orange: he plays out of position)
	var n2 := _label(("%s › %s  %d" % [str(pl["pos"]), wrong_at, int(pl["ovr"])]) if wrong_at != "" else ("%s  %d" % [str(pl["pos"]), int(pl["ovr"])]), 17, WRONG if wrong_at != "" else (GOLD if chosen else Color(1, 1, 1, 0.75)), font3)
	n2.position = Vector2(18, sz.y - 24)
	b.add_child(n2)
	if wrong_at != "" and not chosen:
		for st in ["normal", "hover", "focus", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, _box(Color(0.12, 0.08, 0.04, 0.95), 10, WRONG))
	if int(pl.get("tp", 0)) > 0:
		var tpd := _label("TP", 11, Color(0.05, 0.08, 0.02))
		tpd.add_theme_stylebox_override("normal", _box(GOLD, 6))
		tpd.position = Vector2(sz.x - 26, sz.y - 20)
		tpd.size = Vector2(22, 15)
		tpd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(tpd)
	# the career: how fit he is (a thin bar along the bottom) and a red cross when he is hurt
	var cnd := int(pl.get("cond", -1))
	if cnd >= 0:
		var fb0 := ColorRect.new()
		fb0.color = Color(1, 1, 1, 0.12)
		fb0.position = Vector2(18, sz.y - 5)
		fb0.size = Vector2(sz.x - 26, 3)
		fb0.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(fb0)
		var fb1 := ColorRect.new()
		fb1.color = _fit_col(cnd)
		fb1.position = Vector2(18, sz.y - 5)
		fb1.size = Vector2((sz.x - 26) * cnd / 100.0, 3)
		fb1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(fb1)
	if bool(pl.get("inj", false)):
		b.modulate = Color(1, 1, 1, 0.75)
		var cr := _label("+", 22, Color.WHITE, font)
		cr.add_theme_stylebox_override("normal", _box(Color(0.86, 0.22, 0.2), 6))
		cr.position = Vector2(sz.x - 26, 4)
		cr.size = Vector2(22, 22)
		cr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(cr)
	if bool(pl.get("tl", false)):
		# on the transfer list: a small blue tag in the corner
		var tlb := _label("TL", 11, Color.WHITE)
		tlb.add_theme_stylebox_override("normal", _box(Color(0.25, 0.5, 0.95), 6))
		tlb.position = Vector2(sz.x - (52 if int(pl.get("tp", 0)) > 0 else 26), sz.y - 20)
		tlb.size = Vector2(22, 15)
		tlb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(tlb)
	return b

# A button in a club's colours: the name, with a kit stripe on the left.
func _club_btn(info: Dictionary, ci: int, act: String, arg, pos: Vector2, sz: Vector2, prefix: String) -> Button:
	var cl: Array = info.get("clubs", [])
	var c: Dictionary = cl[ci] if ci < cl.size() else {"n": "?", "k": ["888888", "888888", "888888"]}
	var b := _btn(prefix + str(c["n"]), act, arg, "alt", pos, sz, 17 if sz.y < 80 else 20)
	var shirt := Color(str(c["k"][0]))
	var shorts := Color(str(c["k"][1]))
	var big := sz.y >= 80
	var chosen: bool = big and ci == int(info.get("club", -1)) and not (str(info.get("from", "")) == "lobby" and bool(info.get("own_ft", false)))
	if big:
		for st in ["normal", "hover", "focus", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, _box(Color(0.22, 0.27, 0.25, 0.96), 14, GOLD if chosen else Color(1, 1, 1, 0.18)))
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_BOTTOM
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("outline_size", 0)
		# a little shirt drawn from boxes
		var body := ColorRect.new()
		body.color = shirt
		body.size = Vector2(54, 58)
		body.position = Vector2(sz.x * 0.5 - 27, 14)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(body)
		for sx in [-1, 1]:
			var sl := ColorRect.new()
			sl.color = shirt
			sl.size = Vector2(20, 26)
			sl.position = Vector2(sz.x * 0.5 - 10 + sx * 36, 14)
			sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(sl)
		var sr := ColorRect.new()
		sr.color = shorts
		sr.size = Vector2(54, 18)
		sr.position = Vector2(sz.x * 0.5 - 27, 76)
		sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(sr)
		b.text = ""
		var nl := _label(str(c["n"]), 19, GOLD if chosen else Color.WHITE)
		nl.position = Vector2(0, sz.y - 46)
		nl.size = Vector2(sz.x, 30)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(nl)
	else:
		var chip := ColorRect.new()
		chip.color = shirt
		chip.size = Vector2(10, sz.y - 20)
		chip.position = Vector2(12, 10)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(chip)
		var chip2 := ColorRect.new()
		chip2.color = shorts
		chip2.size = Vector2(10, (sz.y - 20) * 0.35)
		chip2.position = Vector2(12, 10 + (sz.y - 20) * 0.65)
		chip2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(chip2)
	return b

func _slide_in(c: Control, from: Vector2, delay: float) -> void:
	var to := c.position
	c.position = to + from
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "position", to, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tw.tween_property(c, "modulate:a", 1.0, 0.25).set_delay(delay)

func _pulse(c: Control) -> void:
	var tw := c.create_tween()
	tw.set_loops()
	tw.tween_property(c, "scale", Vector2(1.04, 1.04), 0.7).set_trans(Tween.TRANS_SINE).set_delay(0.6)
	tw.tween_property(c, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)

# ---------------------------------------------------------------- score, banners, toast

func set_teams(names: Array, shorts: Array, cols: Array) -> void:
	t_names = names
	t_short = shorts
	t_cols = cols
	_c1.color = _seen(cols[0])
	_c2.color = _seen(cols[1])

# dark kit colours are lifted a little so they show on dark panels
func _seen(c: Color) -> Color:
	return c.lightened(0.38) if c.get_luminance() < 0.2 else c

func set_score(a: int, b: int) -> void:
	score_lbl.text = "%s  %d - %d  %s" % [t_short[0], a, b, t_short[1]]

func set_clock(minute: int) -> void:
	clock_lbl.text = "%d'" % minute

func pop_score() -> void:
	bug.pivot_offset = bug.size * 0.5
	var tw := create_tween()
	tw.tween_property(bug, "scale", Vector2(1.35, 1.35), 0.12)
	tw.tween_property(bug, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func show_banner(text: String, col: Color, hold := 1.6, small := "", fs := 96) -> void:
	if _banner_tw:
		_banner_tw.kill()
	banner.text = text
	banner.add_theme_font_size_override("font_size", fs)
	banner.add_theme_color_override("font_color", col)
	banner.pivot_offset = size * 0.5
	# small words during live play sit up under the scoreboard, so they never cover the game
	banner.position.y = -size.y * 0.33 if fs <= 48 else 0.0
	banner.scale = Vector2(3.2, 3.2) if fs > 48 else Vector2(1.6, 1.6)
	banner.modulate.a = 0.0
	banner.rotation = -0.08
	sub.text = small
	sub.position.y = fs * 0.5 + 34.0
	sub.modulate.a = 0.0
	_banner_tw = create_tween()
	_banner_tw.set_ignore_time_scale(true)
	_banner_tw.set_parallel(true)
	_banner_tw.tween_property(banner, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.tween_property(banner, "rotation", 0.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.tween_property(banner, "modulate:a", 1.0, 0.15)
	_banner_tw.tween_property(sub, "modulate:a", 1.0, 0.3).set_delay(0.35)
	if hold > 0.0:
		_banner_tw.tween_property(banner, "modulate:a", 0.0, 0.4).set_delay(hold)
		_banner_tw.tween_property(banner, "scale", Vector2(1.25, 1.25), 0.4).set_delay(hold)
		_banner_tw.tween_property(sub, "modulate:a", 0.0, 0.4).set_delay(hold)

func show_vs(length: float, names: Array, stars: Array, swap: bool) -> void:
	vs_len = length
	vs_t = 0.0 if length > 0.0 else -1.0
	vs_names = names
	vs_stars = stars
	vs_swap = swap

func _vs() -> void:
	var o := minf(vs_t / 0.45, 1.0)
	var out := clampf((vs_t - (vs_len - 0.4)) / 0.4, 0.0, 1.0)
	var e := (1.0 - pow(1.0 - o, 3.0)) * (1.0 - out * out)
	var w := size.x * 0.44
	var hgt := 112.0
	var y := size.y * 0.5 - hgt * 0.5 + 30.0
	var cols := t_cols
	for i in 2:
		var t := (1 - i) if vs_swap else i
		var x := (-w + e * w) if i == 0 else (size.x - e * w)
		var r := Rect2(x, y, w, hgt)
		draw_rect(r, Color(DARK.r, DARK.g, DARK.b, 0.86))
		var bar := Rect2(x + (w - 14.0 if i == 0 else 0.0), y, 14.0, hgt)
		draw_rect(bar, cols[t])
		draw_rect(Rect2(x, y + hgt - 5.0, w, 5.0), Color(cols[t].r, cols[t].g, cols[t].b, 0.8))
		var cx := x + w * 0.5 + (-20.0 if i == 0 else 20.0)
		var nm: String = vs_names[t]
		var fs := 40
		while fs > 20 and font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w - 90.0:
			fs -= 2
		_text(nm, Vector2(cx, y + 52.0), fs, Color.WHITE)
		_text("STAR PLAYER   " + vs_stars[t], Vector2(cx, y + 88.0), 17, GOLD)
	var pop := clampf((vs_t - 0.3) / 0.25, 0.0, 1.0) * (1.0 - out)
	if pop > 0.0:
		var c := Vector2(size.x * 0.5, y + hgt * 0.5)
		var rad := 44.0 * (1.0 + (1.0 - pop) * 0.8)
		draw_circle(c, rad, Color(GOLD.r, GOLD.g, GOLD.b, pop))
		draw_arc(c, rad, 0, TAU, 48, Color(DARK.r, DARK.g, DARK.b, pop), 4.0, true)
		var s := "VS"
		var sw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		draw_string(font, c + Vector2(-sw * 0.5, 14), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(DARK.r, DARK.g, DARK.b, pop))
		_text("KICK-OFF", Vector2(size.x * 0.5, y - 26.0), 22, Color(1, 1, 1, pop))
		if vs_t > 1.0:
			_text("tap to skip", Vector2(size.x * 0.5, size.y - 26.0), 15, Color(1, 1, 1, 0.6 * pop))

func hide_banner() -> void:
	if _banner_tw:
		_banner_tw.kill()
	banner.modulate.a = 0.0
	sub.modulate.a = 0.0

func do_flash(a := 0.7) -> void:
	flash.color = Color(1, 1, 1, a)
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(flash, "color:a", 0.0, 0.5)

func toast(text: String) -> void:
	if _toast_tw:
		_toast_tw.kill()
	_toast.text = text
	_toast.reset_size()
	_toast.position = Vector2((size.x - _toast.size.x) * 0.5, size.y - 86.0)
	_toast.move_to_front()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.5).set_delay(3.0)

# ---------------------------------------------------------------- menus

func refresh(info: Dictionary) -> void:
	if menu_name != "":
		_build_menu(menu_name, info, false)

func show_menu(n: String, info: Dictionary) -> void:
	_build_menu(n, info, true)

# Every menu: no text smaller than this, so it reads on a phone.
var _min_fs := 0

func _build_menu(n: String, info: Dictionary, anim: bool) -> void:
	_min_fs = 16
	_build_menu2(n, info, anim)
	_min_fs = 0

func _build_menu2(n: String, info: Dictionary, anim: bool) -> void:
	if menu != null:
		menu.queue_free()
		menu = null
	menu_name = n
	_info = info
	if n == "":
		return
	_release_all()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(menu)
	_toast.move_to_front()
	var w := size.x
	var h := size.y
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# a calm, dark pitch-green behind every menu so the words read; the match only shows through a little.
	# In the match (pause, subs, full time) it stays lighter so you can still see the pitch.
	shade.color = Color(0.051, 0.114, 0.082, 0.62) if n in ["full", "pause", "subs", "so", "mtac"] else Color(0.051, 0.114, 0.082, 0.9)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(shade)
	var items := [] # [control, slide-from, delay]
	match n:
		"main":
			_hub(info, w, h, items, anim)
		"myclub":
			var c9: Dictionary = info.get("car", {})
			var isnew := bool(info.get("own_new", false))
			_title("Create your club" if isnew else "Your club", "")
			var k9: Array = c9.get("kit", ["888888", "ffffff", "888888"])
			var lw9 := minf(w * 0.34, 400.0)
			var ph9 := h - 84.0 - 70.0
			var kp := _panel(Vector2(32, 72), Vector2(lw9, ph9), 0.9)
			var kd := Control.new()
			kd.size = Vector2(lw9, ph9)
			kd.mouse_filter = Control.MOUSE_FILTER_IGNORE
			kd.draw.connect(func():
				var cx := lw9 * 0.5
				var u := minf(ph9 / 9.2, lw9 / 6.0)
				var c0 := Color(str(k9[0]))
				var c1 := Color(str(k9[1]))
				var c2 := Color(str(k9[2]))
				var ol := Color(1, 1, 1, 0.5)
				var ty := u * 0.6
				# shirt with sleeves
				var shirt := PackedVector2Array([Vector2(cx - u * 1.1, ty), Vector2(cx + u * 1.1, ty), Vector2(cx + u * 2.3, ty + u * 0.9), Vector2(cx + u * 1.8, ty + u * 1.7), Vector2(cx + u * 1.3, ty + u * 1.35), Vector2(cx + u * 1.3, ty + u * 3.9), Vector2(cx - u * 1.3, ty + u * 3.9), Vector2(cx - u * 1.3, ty + u * 1.35), Vector2(cx - u * 1.8, ty + u * 1.7), Vector2(cx - u * 2.3, ty + u * 0.9)])
				kd.draw_colored_polygon(shirt, c0)
				shirt.append(shirt[0])
				kd.draw_polyline(shirt, ol, 2.0, true)
				kd.draw_arc(Vector2(cx, ty), u * 0.5, 0, PI, 16, c1, 4.0, true)
				# shorts
				var sy9 := ty + u * 4.2
				var sh9 := PackedVector2Array([Vector2(cx - u * 1.3, sy9), Vector2(cx + u * 1.3, sy9), Vector2(cx + u * 1.5, sy9 + u * 1.7), Vector2(cx + u * 0.2, sy9 + u * 1.7), Vector2(cx, sy9 + u * 0.8), Vector2(cx - u * 0.2, sy9 + u * 1.7), Vector2(cx - u * 1.5, sy9 + u * 1.7)])
				kd.draw_colored_polygon(sh9, c1)
				sh9.append(sh9[0])
				kd.draw_polyline(sh9, ol, 2.0, true)
				# socks
				for sd9 in [-1.0, 1.0]:
					var rr := Rect2(cx + sd9 * u * 0.85 - u * 0.4, sy9 + u * 2.1, u * 0.8, u * 2.0)
					kd.draw_rect(rr, c2)
					kd.draw_rect(rr, ol, false, 2.0)
			)
			kp.add_child(kd)
			var nb9 := _btn("NAME:  " + str(c9.get("name", "")), "own_name", null, "alt", Vector2(32, 72 + ph9 + 10.0), Vector2(lw9, 56), 20)
			menu.add_child(nb9)
			var rx9 := 32.0 + lw9 + 24.0
			var rw9 := w - rx9 - 32.0
			var cols9: Array = info.get("own_cols", [])
			var sw9 := minf(56.0, (rw9 - 11.0 * 8.0) / 12.0)
			var rowh := (h - 84.0 - 74.0) / 3.0
			var parts := ["SHIRT", "SHORTS", "SOCKS"]
			for pi9 in 3:
				var ry := 72.0 + pi9 * rowh
				var pl9 := _label(parts[pi9], 18, GOLD, font2)
				pl9.position = Vector2(rx9, ry)
				menu.add_child(pl9)
				var s9 := minf(sw9, rowh - 40.0)
				for ci9 in cols9.size():
					var on9: bool = str(k9[pi9]).to_lower() == str(cols9[ci9])
					var cb9 := _btn("", "own_col", [pi9, cols9[ci9]], "alt", Vector2(rx9 + ci9 * (s9 + 8.0), ry + 28.0), Vector2(s9, s9), 12)
					for st9 in ["normal", "hover", "focus", "pressed"]:
						cb9.add_theme_stylebox_override(st9, _box(Color(str(cols9[ci9])), 10, GOLD if on9 else Color(1, 1, 1, 0.35)))
					menu.add_child(cb9)
			var ok9 := _btn("START" if isnew else "DONE", "own_ok", null, "primary", Vector2(w - 32.0 - 260.0, h - 70.0), Vector2(260, 56), 26)
			menu.add_child(ok9)
			var hn9 := _label("Tap the name to change it.", 17, Color(1, 1, 1, 0.65), font2)
			hn9.position = Vector2(rx9, h - 52.0)
			menu.add_child(hn9)
		"quick":
			_title("Quick match", "A friendly against the computer. Nothing is at stake.")
			var qx := w * 0.5 - 190.0
			var qy := maxf(104.0, h * 0.5 - 150.0)
			var tb := _club_btn(info, int(info.get("club", 0)), "teams", null, Vector2(qx, qy), Vector2(380, 60), "TEAM:  ")
			menu.add_child(tb)
			items.append([tb, Vector2(0, 40), 0.0])
			var d := _btn("LEVEL: " + str(info.get("diff", "")), "diff", null, "alt", Vector2(qx, qy + 72), Vector2(185, 58), 19)
			menu.add_child(d)
			var l := _btn("MATCH: " + str(info.get("len", "")), "len", null, "alt", Vector2(qx + 195, qy + 72), Vector2(185, 58), 19)
			menu.add_child(l)
			var play := _btn("PLAY", "play", null, "primary", Vector2(qx, qy + 150), Vector2(380, 88), 42)
			menu.add_child(play)
			items.append([play, Vector2(0, 60), 0.08])
			if anim:
				play.ready.connect(func(): _pulse(play))
			else:
				_pulse(play)
			menu.add_child(_back("tab", "career"))
		"pack":
			var pk: Dictionary = info.get("pack", {})
			var pw := 460.0
			var ph := minf(h - 60.0, 420.0)
			var pp := Panel.new()
			pp.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.96), 22, GOLD))
			pp.position = Vector2(w * 0.5 - pw * 0.5, h * 0.5 - ph * 0.5)
			pp.size = Vector2(pw, ph)
			pp.pivot_offset = pp.size * 0.5
			menu.add_child(pp)
			var k1 := _label("NEW PLAYER", 18, GOLD, font2)
			k1.position = Vector2(0, 18)
			k1.size = Vector2(pw, 26)
			k1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pp.add_child(k1)
			var k2 := _label(str(pk.get("ovr", 0)), 84, Color.WHITE)
			k2.position = Vector2(0, 44)
			k2.size = Vector2(pw, 96)
			k2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pp.add_child(k2)
			var k3 := _label(str(pk.get("n", "")), 34, Color.WHITE)
			k3.position = Vector2(0, 142)
			k3.size = Vector2(pw, 42)
			k3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pp.add_child(k3)
			var k4 := _label("%s   ·   AGE %d   ·   CAN REACH %d" % [str(pk.get("pos", "")), int(pk.get("age", 0)), int(pk.get("pot", 0))], 18, Color(1, 1, 1, 0.8), font2)
			k4.position = Vector2(0, 188)
			k4.size = Vector2(pw, 24)
			k4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pp.add_child(k4)
			var sn2 := Career.GK_NAMES if str(pk.get("pos", "")) == "GK" else Career.STAT_NAMES
			var sv: Array = pk.get("st", [0, 0, 0, 0])
			for si3 in 4:
				var sx := 40.0 + (si3 % 2) * (pw * 0.5 - 20.0)
				var sy := 226.0 + (si3 / 2) * 34.0
				var s1 := _label(sn2[si3], 17, Color(1, 1, 1, 0.75), font2)
				s1.position = Vector2(sx, sy + 4)
				pp.add_child(s1)
				var s2 := _label(str(int(sv[si3])), 24, Color.WHITE)
				s2.position = Vector2(sx + 120, sy)
				pp.add_child(s2)
			menu.add_child(_btn("GREAT", "career", null, "primary", Vector2(w * 0.5 - 150, h * 0.5 + ph * 0.5 - 76), Vector2(300, 58), 26))
			if anim:
				# the card pops in
				pp.scale = Vector2(0.2, 0.2)
				pp.modulate.a = 0.0
				var ptw := pp.create_tween()
				ptw.set_parallel(true)
				ptw.tween_property(pp, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				ptw.tween_property(pp, "modulate:a", 1.0, 0.2)
		"career":
			var c: Dictionary = info.get("car", {})
			var t0 := _label(str(c.get("name", "")), 40, Color.WHITE)
			t0.position = Vector2(160, 10)
			menu.add_child(t0)
			var sub0 := _label("DIVISION %d   ·   SEASON %d   ·   ROUND %d OF %d   ·   %s PLACE   ·   TEAM RATING %d" % [int(c.get("div", 4)), int(c.get("season", 1)), mini(int(c.get("round", 0)) + 1, int(c.get("rounds", 14))), int(c.get("rounds", 14)), _ord(int(c.get("rank", 1))), int(c.get("str", 0))], 18, Color(1, 1, 1, 0.8), font2)
			sub0.position = Vector2(162, 58)
			menu.add_child(sub0)
			var co := _label(_mb(int(c.get("coins", 0))), 24, GOLD)
			co.position = Vector2(w - 260, 20)
			co.size = Vector2(230, 34)
			co.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(co)
			var lw := w * 0.56 - 60.0
			var card := Panel.new()
			card.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.86), 18, Color(1, 1, 1, 0.14)))
			card.position = Vector2(40, 100)
			card.size = Vector2(lw, 230)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu.add_child(card)
			items.append([card, Vector2(-60, 0), 0.0])
			if bool(c.get("over", false)):
				var nt := _label(str(c.get("note", "SEASON OVER")), 24, GOLD)
				nt.autowrap_mode = TextServer.AUTOWRAP_WORD
				nt.position = Vector2(20, 60)
				nt.size = Vector2(lw - 40, 90)
				nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				card.add_child(nt)
				var ns := _btn("NEXT SEASON", "c_next", null, "primary", Vector2(40, 346), Vector2(lw, 92), 40)
				menu.add_child(ns)
				items.append([ns, Vector2(0, 60), 0.1])
			else:
				var nx := _label("NEXT MATCH   ·   " + ("HOME" if bool(c.get("home", true)) else "AWAY"), 18, GOLD, font2)
				nx.position = Vector2(0, 16)
				nx.size = Vector2(lw, 26)
				nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				card.add_child(nx)
				var kits := [c.get("kit", ["888888"]), c.get("opp_kit", ["888888"])]
				var nms := [str(c.get("name", "")), str(c.get("opp", ""))]
				var rks := [int(c.get("rank", 1)), int(c.get("opp_rank", 1))]
				for si in 2:
					var cx := lw * (0.25 if si == 0 else 0.75)
					var sh2 := Panel.new()
					sh2.add_theme_stylebox_override("panel", _box(Color(str(kits[si][0])), 10, Color(1, 1, 1, 0.55)))
					sh2.mouse_filter = Control.MOUSE_FILTER_IGNORE
					sh2.size = Vector2(64, 64)
					sh2.position = Vector2(cx - 32, 58)
					card.add_child(sh2)
					var fs2 := 26
					while fs2 > 14 and font.get_string_size(nms[si], HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x > lw * 0.5 - 30.0:
						fs2 -= 2
					var nl2 := _label(nms[si], fs2, Color.WHITE)
					nl2.position = Vector2(cx - lw * 0.25, 132)
					nl2.size = Vector2(lw * 0.5, 34)
					nl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					card.add_child(nl2)
					var rl := _label(_ord(rks[si]) + " in the table", 17, Color(1, 1, 1, 0.7), font2)
					rl.position = Vector2(cx - lw * 0.25, 170)
					rl.size = Vector2(lw * 0.5, 24)
					rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					card.add_child(rl)
				var vv := _label("V", 34, GOLD)
				vv.position = Vector2(0, 76)
				vv.size = Vector2(lw, 40)
				vv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				card.add_child(vv)
				var pm := _btn("PLAY MATCH", "c_play", null, "primary", Vector2(40, 346), Vector2(lw, 92), 40)
				menu.add_child(pm)
				items.append([pm, Vector2(0, 60), 0.1])
				if anim:
					pm.ready.connect(func(): _pulse(pm))
				else:
					_pulse(pm)
			var rx2 := w * 0.56 + 10.0
			var rw := w - rx2 - 40.0
			var sq := _btn("SQUAD", "c_squad", null, "alt", Vector2(rx2, 100), Vector2(rw * 0.5 - 5, 56), 22)
			var mkb := _btn("TRANSFERS", "c_market", null, "alt", Vector2(rx2 + rw * 0.5 + 5, 100), Vector2(rw * 0.5 - 5, 56), 22)
			var tbn := _btn("TABLE", "c_table", null, "alt", Vector2(rx2, 164), Vector2(rw * 0.5 - 5, 56), 22)
			var clb := _btn("CLUB", "c_club", null, "alt", Vector2(rx2 + rw * 0.5 + 5, 164), Vector2(rw * 0.5 - 5, 56), 22)
			menu.add_child(clb)
			items.append([clb, Vector2(80, 0), 0.12])
			menu.add_child(sq)
			menu.add_child(mkb)
			items.append([mkb, Vector2(80, 0), 0.08])
			menu.add_child(tbn)
			items.append([sq, Vector2(80, 0), 0.05])
			items.append([tbn, Vector2(80, 0), 0.1])
			var lp := Panel.new()
			lp.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.8), 14))
			lp.position = Vector2(rx2, 230)
			lp.size = Vector2(rw, 156)
			lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu.add_child(lp)
			var lh := _label("Last round", 18, GOLD, font2)
			lh.position = Vector2(16, 10)
			lp.add_child(lh)
			var lst: Array = c.get("last", [])
			if lst.is_empty():
				var le := _label("The season starts now. Win matches to earn coins, and your players grow as they play.", 18, Color(1, 1, 1, 0.8), font2)
				le.autowrap_mode = TextServer.AUTOWRAP_WORD
				le.position = Vector2(16, 38)
				le.size = Vector2(rw - 32, 100)
				lp.add_child(le)
			for li in lst.size():
				var ll := _label(str(lst[li]), 19, Color.WHITE)
				ll.position = Vector2(16, 34 + li * 29)
				ll.size = Vector2(rw - 32, 30)
				ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lp.add_child(ll)
			var nw2 := _btn("SURE? TAP AGAIN" if bool(c.get("sure", false)) else "START OVER", "c_new", null, "ghost", Vector2(rx2 + rw - 190, 396), Vector2(190, 42), 15)
			menu.add_child(nw2)
			var bk0 := _back("back", null)
			menu.add_child(bk0)
		"table":
			var c7: Dictionary = info.get("car", {})
			var up7 := int(c7.get("up", 0))
			var dn7 := int(c7.get("down", 0))
			var rows2: Array = c7.get("table", [])
			_title(str(c7.get("lgname", "The league")), "")
			# a key for the coloured edges: who goes up, who goes down
			var keys7 := []
			if up7 > 0:
				keys7.append([GREEN, "TOP %d GO UP" % up7])
			else:
				keys7.append([GOLD, "1ST WINS THE LEAGUE"])
			if dn7 > 0:
				keys7.append([Color(0.92, 0.3, 0.3), "BOTTOM %d GO DOWN" % dn7])
			var kx7 := w * 0.5 - 200.0 * keys7.size() * 0.5
			for kk in keys7:
				var kc := ColorRect.new()
				kc.color = kk[0]
				kc.position = Vector2(kx7, 72)
				kc.size = Vector2(6, 20)
				menu.add_child(kc)
				var kl := _label(str(kk[1]), 18, Color(1, 1, 1, 0.8), font2)
				kl.position = Vector2(kx7 + 14, 69)
				menu.add_child(kl)
				kx7 += 200.0
			var tw2 := minf(w - 64.0, 1000.0)
			var tx := (w - tw2) * 0.5
			var rh2 := 48.0
			# columns: place, club, played, won, drawn, lost, goal difference, points, form (last five)
			var cols2 := [0.0, 0.06, 0.45, 0.51, 0.57, 0.63, 0.69, 0.765, 0.84]
			var heads := ["#", "CLUB", "P", "W", "D", "L", "GD", "PTS", "FORM"]
			var hb7 := Panel.new()
			hb7.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.7), 8))
			hb7.position = Vector2(tx, 96)
			hb7.size = Vector2(tw2, 26)
			hb7.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu.add_child(hb7)
			for ci2 in heads.size():
				var hl := _label(heads[ci2], 17, Color(1, 1, 1, 0.6), font2)
				hl.position = Vector2(tx + 18 + cols2[ci2] * tw2, 100)
				menu.add_child(hl)
			var sc7 := ScrollContainer.new()
			sc7.position = Vector2(tx, 126)
			sc7.size = Vector2(tw2, h - 132.0)
			sc7.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			sc7.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
			menu.add_child(sc7)
			var box7 := Control.new()
			box7.custom_minimum_size = Vector2(tw2, rows2.size() * rh2)
			box7.mouse_filter = Control.MOUSE_FILTER_PASS
			sc7.add_child(box7)
			var mine7 := 0
			var n7 := rows2.size()
			for ri in n7:
				var r: Array = rows2[ri]
				var me7 := bool(r[8])
				if me7:
					mine7 = ri
				var rp := Panel.new()
				rp.add_theme_stylebox_override("panel", _box(Color(0.16, 0.2, 0.12, 0.96) if me7 else Color(DARK.r, DARK.g, DARK.b, 0.84), 10, GOLD if me7 else Color(0, 0, 0, 0)))
				rp.position = Vector2(0, ri * rh2)
				rp.size = Vector2(tw2, rh2 - 6)
				rp.mouse_filter = Control.MOUSE_FILTER_PASS
				box7.add_child(rp)
				# the zone edge: up (green) or the title (gold), down (red)
				var zc := Color(0, 0, 0, 0)
				if up7 > 0 and ri < up7:
					zc = GREEN
				elif up7 == 0 and ri == 0:
					zc = GOLD
				elif dn7 > 0 and ri >= n7 - dn7:
					zc = Color(0.92, 0.3, 0.3)
				if zc.a > 0.0:
					var ze := ColorRect.new()
					ze.color = zc
					ze.position = Vector2(0, 6)
					ze.size = Vector2(5, rh2 - 18)
					ze.mouse_filter = Control.MOUSE_FILTER_IGNORE
					rp.add_child(ze)
				var chip3 := ColorRect.new()
				chip3.color = _seen(Color(str(r[9])))
				chip3.position = Vector2(cols2[1] * tw2 + 4, 10)
				chip3.size = Vector2(8, rh2 - 26)
				chip3.mouse_filter = Control.MOUSE_FILTER_IGNORE
				rp.add_child(chip3)
				var vals := [str(r[0]), str(r[1]), str(r[2]), str(r[3]), str(r[4]), str(r[5]), ("+" if int(r[6]) > 0 else "") + str(r[6]), str(r[7])]
				for ci3 in vals.size():
					var vl := _label(vals[ci3], 20 if ci3 in [1, 7] else 18, GOLD if me7 and ci3 in [1, 7] else Color.WHITE, font if ci3 in [0, 1, 7] else font2)
					vl.position = Vector2(18 + cols2[ci3] * tw2 + (12 if ci3 == 1 else 0), (rh2 - 6) * 0.5 - 14)
					vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
					rp.add_child(vl)
				# form: the last five results as small squares, newest on the right
				var fm7 := str(r[10]) if r.size() > 10 else ""
				for fi in fm7.length():
					var ch7 := fm7[fi]
					var fb := Panel.new()
					fb.add_theme_stylebox_override("panel", _box(GREEN if ch7 == "W" else (Color(0.92, 0.3, 0.3) if ch7 == "L" else Color(0.55, 0.58, 0.6)), 5))
					fb.position = Vector2(18 + cols2[8] * tw2 + fi * 26.0, (rh2 - 6) * 0.5 - 11)
					fb.size = Vector2(22, 22)
					fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
					rp.add_child(fb)
					var fl := _label(ch7, 17, Color(0.05, 0.08, 0.06), font)
					fl.position = Vector2(0, 0)
					fl.size = Vector2(22, 22)
					fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					fl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					fb.add_child(fl)
			# open with your own club in view
			var vis7 := sc7.size.y
			sc7.set_deferred("scroll_vertical", int(clampf(mine7 * rh2 - vis7 * 0.5 + rh2 * 0.5, 0.0, maxf(n7 * rh2 - vis7, 0.0))))
			if not (c7.get("hon", {}) as Dictionary).is_empty():
				menu.add_child(_btn("TABLE", "c_table", null, "primary", Vector2(w - 330, 14), Vector2(130, 44), 17))
				menu.add_child(_btn("TOP SCORERS", "scorers", null, "alt", Vector2(w - 192, 14), Vector2(170, 44), 17))
			var bk2 := _back("career", null)
			menu.add_child(bk2)
		"car_start":
			var my: Dictionary = info.get("my", {})
			_title("Start a career", ("This replaces your career now. " if bool(info.get("car_on", false)) else "") + "Three ways in. The career is its own world with its own money, until you exit it.")
			var cw := (w - 64.0 - 2 * 16.0) / 3.0
			var ph := h - 100.0 - 108.0
			var sure := bool(info.get("new_sure", false))
			var defs := [
				["cs_mine", "YOUR OWN CLUB", ("%s   ·   TEAM RATING %d" % [str(my.get("n", "")), int(my.get("r", 0))]) if not my.is_empty() else "YOU HAVE NO CLUB YET", [
					"Your players, name and kit go into the career",
					"You pick the league it starts in",
					"Your club outside the career is not touched",
				], "PLAY WITH MY CLUB" if not my.is_empty() else "MAKE MY CLUB"],
				["cs_new", "A NEW CLUB", "NAME, CITY AND COLOURS OF YOUR OWN", [
					"A fresh squad of young players",
					"Starts at the bottom: League Two or Denmark's second league",
					"Climb all the way to the top",
				], "MAKE A NEW CLUB"],
				["cs_club", "AN EXISTING CLUB", "ANY OF THE 116 CLUBS", [
					"Take over a club as it is, with its squad and its strength",
					"From the top of England to Denmark's second league",
					"The career has its own money, in euros",
				], "PICK A CLUB"],
			]
			for i in 3:
				var dd: Array = defs[i]
				var px := 32.0 + i * (cw + 16.0)
				var pn := _panel(Vector2(px, 100), Vector2(cw, ph), 0.9)
				items.append([pn, Vector2(0, 50), 0.05 * i])
				var tl := _label(dd[1], 26, GOLD if i == 0 else Color.WHITE)
				tl.position = Vector2(20, 16)
				pn.add_child(tl)
				var sl := _label(str(dd[2]), 16, Color(1, 1, 1, 0.65), font2)
				sl.position = Vector2(21, 52)
				sl.clip_text = true
				sl.size = Vector2(cw - 40, 20)
				pn.add_child(sl)
				var yy := 84.0
				for ln in dd[3]:
					var dot := ColorRect.new()
					dot.color = GREEN
					dot.position = Vector2(22, yy + 8)
					dot.size = Vector2(7, 7)
					pn.add_child(dot)
					var bl := _label(str(ln), 18, Color(1, 1, 1, 0.9), font2)
					bl.autowrap_mode = TextServer.AUTOWRAP_WORD
					bl.position = Vector2(38, yy)
					bl.size = Vector2(cw - 58.0, 24)
					pn.add_child(bl)
					yy += 24.0 * ceilf(font2.get_string_size(str(ln), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x / (cw - 66.0)) + 8.0
				var pb := _btn(dd[4], dd[0], null, "primary" if i == 0 else "alt", Vector2(px, h - 96.0), Vector2(cw, 68), 22)
				menu.add_child(pb)
				items.append([pb, Vector2(0, 60), 0.1 + 0.05 * i])
			menu.add_child(_back("tab", "career"))
		"cm_pick":
			var my2: Dictionary = info.get("my", {})
			_title("The cup", "A cup on its own: every club in the country, lose once and you are out. Your coins go to your club.")
			var cw2 := (w - 64.0 - 20.0) * 0.5
			var cups := [["ENGLAND", "THE ENGLISH CUP", "92 clubs from the top league to League Two. Seven rounds to the final."], ["DENMARK", "THE DANISH CUP", "24 clubs from both Danish leagues. Five rounds to the final."]]
			for i in 2:
				var px2 := 32.0 + i * (cw2 + 20.0)
				var pn2 := _panel(Vector2(px2, 100), Vector2(cw2, minf(h - 100.0 - 190.0, 150.0)), 0.9)
				items.append([pn2, Vector2(0, 50), 0.06 * i])
				var t1 := _label(cups[i][1], 30, GOLD)
				t1.position = Vector2(24, 18)
				pn2.add_child(t1)
				var t2 := _label(cups[i][2], 18, Color(1, 1, 1, 0.85), font2)
				t2.autowrap_mode = TextServer.AUTOWRAP_WORD
				t2.position = Vector2(26, 64)
				t2.size = Vector2(cw2 - 52, 60)
				pn2.add_child(t2)
				var by2 := 100.0 + pn2.size.y + 14.0
				var b1 := _btn(("WITH %s" % str(my2.get("n", "MY CLUB"))) if not my2.is_empty() else "WITH MY CLUB", "cm_mine", cups[i][0], "primary" if not my2.is_empty() else "off", Vector2(px2, by2), Vector2(cw2, 70), 22)
				menu.add_child(b1)
				var b2 := _btn("WITH ANOTHER CLUB", "cm_club", cups[i][0], "alt", Vector2(px2, by2 + 80.0), Vector2(cw2, 62), 20)
				menu.add_child(b2)
				items.append([b1, Vector2(0, 60), 0.1 + 0.05 * i])
				items.append([b2, Vector2(0, 60), 0.14 + 0.05 * i])
			menu.add_child(_back("tab", "play"))
		"online":
			var rk: Dictionary = info.get("rank", {})
			_title("Ranked online", "Your club against another player's club. Win to climb from Bronze to Legend.")
			var lw3 := w * 0.5 - 40.0
			var pn3 := _panel(Vector2(32, 96), Vector2(lw3, h - 96.0 - 112.0), 0.9)
			items.append([pn3, Vector2(-60, 0), 0.0])
			var bs := minf(120.0, pn3.size.y - 70.0)
			_rk_badge(pn3, Vector2(24, 18), bs, rk)
			var rn := _label(str(rk.get("n", "")), 38, Color(str(rk.get("c", "ffffff"))))
			rn.position = Vector2(bs + 44, 22)
			pn3.add_child(rn)
			var rp3 := _label(("%d RANK POINTS" % int(rk.get("rp", 0))) + (("   ·   %d TO %s" % [int(rk.get("need", 0)), str(rk.get("nn", ""))]) if str(rk.get("nn", "")) != "" else ""), 17, Color(1, 1, 1, 0.8), font2)
			rp3.position = Vector2(bs + 46, 72)
			pn3.add_child(rp3)
			var bw3 := lw3 - bs - 70.0
			var bg3 := ColorRect.new()
			bg3.color = Color(1, 1, 1, 0.12)
			bg3.position = Vector2(bs + 46, 102)
			bg3.size = Vector2(bw3, 12)
			pn3.add_child(bg3)
			var fg3 := ColorRect.new()
			fg3.color = Color(str(rk.get("c", "ffffff")))
			fg3.position = Vector2(bs + 46, 102)
			fg3.size = Vector2(maxf(bw3 * float(rk.get("p", 0.0)), 3.0), 12)
			pn3.add_child(fg3)
			var tiers: Array = rk.get("tiers", [])
			var tw4 := (lw3 - 52.0 - 5 * 6.0) / 6.0
			var ty4 := 168.0
			var trl := _label("Season reward by your best rank this month", 16, Color(1, 1, 1, 0.55), font2)
			trl.position = Vector2(26, ty4)
			pn3.add_child(trl)
			for ti4 in tiers.size():
				var cur4: bool = ti4 == int(rk.get("t", 0))
				var tp4 := Panel.new()
				tp4.add_theme_stylebox_override("panel", _box(Color(str(tiers[ti4][1])) if cur4 else Color(1, 1, 1, 0.06), 8, Color(str(tiers[ti4][1])).darkened(0.1)))
				tp4.position = Vector2(26 + ti4 * (tw4 + 6.0), ty4 + 22)
				tp4.size = Vector2(tw4, 46)
				tp4.mouse_filter = Control.MOUSE_FILTER_IGNORE
				pn3.add_child(tp4)
				var tn4 := _label(str(tiers[ti4][0]), 12 if tw4 > 70 else 10, Color(0.05, 0.05, 0.05) if cur4 else Color(str(tiers[ti4][1])), font2)
				tn4.position = Vector2(0, 5)
				tn4.size = Vector2(tw4, 16)
				tn4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				tp4.add_child(tn4)
				var tc4 := _label(str(int(tiers[ti4][3])), 17, Color(0.05, 0.05, 0.05) if cur4 else Color.WHITE)
				tc4.position = Vector2(0, 21)
				tc4.size = Vector2(tw4, 20)
				tc4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				tp4.add_child(tc4)
			var stl := "WON %d   ·   DRAWN %d   ·   LOST %d" % [int(rk.get("w", 0)), int(rk.get("dr", 0)), int(rk.get("l", 0))]
			if int(rk.get("ws", 0)) >= 2:
				stl += "   ·   %d WINS IN A ROW" % int(rk.get("ws", 0))
			var st3 := _label(stl, 17, Color.WHITE, font2)
			st3.position = Vector2(26, pn3.size.y - 62)
			pn3.add_child(st3)
			var sh3 := _label(("SHIELDS %d   ·   " % int(rk.get("sh", 0)) if int(rk.get("sh", 0)) > 0 else "") + "THE RANK SEASON ENDS IN %d DAYS" % int(rk.get("days", 0)), 17, Color(1, 1, 1, 0.65), font2)
			sh3.position = Vector2(26, pn3.size.y - 36)
			pn3.add_child(sh3)
			var fb := _btn("FIND OPPONENT", "rk_find", null, "primary", Vector2(32, h - 100.0), Vector2(lw3, 76), 34)
			menu.add_child(fb)
			items.append([fb, Vector2(0, 60), 0.08])
			_pulse(fb)
			var rx3 := w * 0.5 + 8.0
			var rw3 := w - rx3 - 32.0
			var th3 := (h - 96.0 - 24.0 - 20.0) / 3.0
			var t3a := _tile("HOW IT WORKS", "Win +25, lose -18 (half in Bronze). Stronger opponents and win streaks give more. A new rank gives 3 shields.", "", null, Vector2(rx3, 96), Vector2(rw3, th3), GOLD, 20)
			t3a.disabled = true
			t3a.get_child(t3a.get_child_count() - 1).visible = false
			menu.add_child(t3a)
			var t3b := _tile("Leaderboard", "The best players in the game", "rk_lb", null, Vector2(rx3, 96 + th3 + 10.0), Vector2(rw3, th3), Color.WHITE, 22)
			menu.add_child(t3b)
			var t3c := _tile("Play with a friend", "Room code or invite link, not ranked", "friend", null, Vector2(rx3, 96 + 2 * (th3 + 10.0)), Vector2(rw3, th3), Color.WHITE, 22)
			menu.add_child(t3c)
			for ti3 in 3:
				items.append([[t3a, t3b, t3c][ti3], Vector2(80, 0), 0.04 * ti3])
			menu.add_child(_back("tab", "play"))
		"rk_find":
			var rk4: Dictionary = info.get("rank", {})
			var ts := int(rk4.get("t_s", 0))
			_title("Ranked online", "%s   ·   %d rank points" % [str(rk4.get("n", "")), int(rk4.get("rp", 0))])
			_rk_badge(menu, Vector2(w * 0.5 - 60, h * 0.5 - 150), 120.0, rk4)
			var m4 := _label(str(rk4.get("msg", "")), 30, Color.WHITE)
			m4.autowrap_mode = TextServer.AUTOWRAP_WORD
			m4.position = Vector2(60, h * 0.5 + 0)
			m4.size = Vector2(w - 120, 80)
			m4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			menu.add_child(m4)
			var tm := _label("%d:%02d" % [ts / 60, ts % 60], 22, GOLD, font2)
			tm.position = Vector2(0, h * 0.5 + 84)
			tm.size = Vector2(w, 30)
			tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			menu.add_child(tm)
			var hint := _label("The match starts by itself when someone is found. Keep the game open.", 17, Color(1, 1, 1, 0.65), font2)
			hint.position = Vector2(0, h * 0.5 + 120)
			hint.size = Vector2(w, 24)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			menu.add_child(hint)
			var stopped := str(rk4.get("msg", "")).contains("TRY AGAIN")
			menu.add_child(_btn("TRY AGAIN" if stopped else "STOP", "rk_find" if stopped else "rk_stop", null, "primary" if stopped else "alt", Vector2(w * 0.5 - 150, h - 96.0), Vector2(300, 66), 26))
			if stopped:
				menu.add_child(_back("online", null))
		"rk_lb":
			var rk5: Dictionary = info.get("rank", {})
			_title("Leaderboard", "Everyone's rank points in ranked online.")
			var ls := str(rk5.get("lb_state", ""))
			var rows: Array = rk5.get("lb", [])
			if ls != "ok" or rows.is_empty():
				var t5 := "LOADING..." if ls == "loading" else ("THE LEADERBOARD IS NOT SWITCHED ON YET" if ls == "off" else ("COULD NOT LOAD THE LEADERBOARD. TRY AGAIN LATER" if ls == "err" else "NOBODY HAS PLAYED RANKED YET. BE THE FIRST!"))
				var l5 := _label(t5, 24, Color(1, 1, 1, 0.8))
				l5.position = Vector2(0, h * 0.5 - 20)
				l5.size = Vector2(w, 40)
				l5.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				menu.add_child(l5)
			else:
				var cols5 := 2
				var per := int((h - 110.0 - 20.0) / 34.0)
				var cw5 := (w - 64.0 - 20.0) / cols5
				for ri in mini(rows.size(), per * cols5):
					var r5: Dictionary = rows[ri]
					var x5 := 32.0 + (ri / per) * (cw5 + 20.0)
					var y5 := 104.0 + (ri % per) * 34.0
					var bg5 := Panel.new()
					bg5.add_theme_stylebox_override("panel", _box(Color(0.16, 0.2, 0.12, 0.95) if bool(r5["me"]) else Color(DARK.r, DARK.g, DARK.b, 0.78), 8, GOLD if bool(r5["me"]) else Color(0, 0, 0, 0)))
					bg5.position = Vector2(x5, y5)
					bg5.size = Vector2(cw5, 30)
					bg5.mouse_filter = Control.MOUSE_FILTER_IGNORE
					menu.add_child(bg5)
					var a5 := _label("%d.   %s" % [ri + 1, str(r5["n"])], 18, Color.WHITE)
					a5.position = Vector2(12, 3)
					bg5.add_child(a5)
					var rkn: Dictionary = RankC.rank_of(int(r5["rp"]))
					var b5 := _label("%s   ·   %d" % [str(rkn["n"]), int(r5["rp"])], 17, Color(str(rkn["c"])), font2)
					b5.position = Vector2(cw5 - 232, 5)
					b5.size = Vector2(220, 22)
					b5.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					bg5.add_child(b5)
			menu.add_child(_back("online", null))
		"start_lg":
			var wl: Array = info.get("world", [])
			var sk := str(info.get("start_kind", ""))
			var only_c := str(info.get("cup_ctry", "")) if sk == "cup" else ""
			_title("Where do you start?" if sk != "cup" else "Pick your club", {"mine": "Pick the league your own club starts in. It takes the place of the league's weakest club.", "new": "A new club starts at the bottom. Pick the country.", "cup": "Pick a league, then the club you play the cup with."}.get(sk, "Pick a league, then the club you will run. The clubs are made up but remind you of the real ones."))
			var cwl := (w - 64.0 - 20.0) * 0.5
			var ctry := ["ENGLAND", "DENMARK"]
			for ci in 2:
				var hx := 32.0 + ci * (cwl + 20.0)
				var hl := _label(ctry[ci], 18, GOLD, font2)
				hl.position = Vector2(hx + 4, 100)
				menu.add_child(hl)
				var row := 0
				for li in wl.size():
					var L: Dictionary = wl[li]
					if str(L["c"]) != ctry[ci] or (only_c != "" and only_c != ctry[ci]) or (sk == "new" and int(L.get("down", 0)) != 0):
						continue
					var cls: Array = L["clubs"]
					var lo := 99
					var hi := 0
					for cc in cls:
						lo = mini(lo, int(cc["r"]))
						hi = maxi(hi, int(cc["r"]))
					var th := (h - 130.0 - 110.0) / 4.0 - 8.0
					var sub := "%d clubs   ·   team ratings %d to %d" % [cls.size(), lo, hi]
					if int(L["t"]) == 1:
						sub += "   ·   the top league"
					var tl := _tile(str(L["n"]), sub, "st_lg", li, Vector2(hx, 128.0 + row * (th + 8.0)), Vector2(cwl, th), Color.WHITE, 22)
					menu.add_child(tl)
					items.append([tl, Vector2(0, 40), 0.04 * li])
					row += 1
			var short := str(info.get("slen", "full")) == "short"
			if sk == "cup":
				menu.add_child(_back("cupm", null))
				short = false
			var sl := _label("Season length", 17, Color(1, 1, 1, 0.6), font2)
			sl.visible = sk != "cup"
			sl.position = Vector2(32 + cwl + 24, h - 104)
			menu.add_child(sl)
			var sb := _btn("SHORT: EACH CLUB ONCE" if short else "FULL: HOME AND AWAY", "st_len", null, "alt", Vector2(32 + cwl + 20, h - 82), Vector2(cwl, 60), 22)
			var sn := _label("A 20-club league: %d league matches a season." % (19 if short else 38), 17, Color(1, 1, 1, 0.6), font2)
			sn.position = Vector2(32 + cwl + 24, h - 18)
			if sk != "cup":
				menu.add_child(sb)
				menu.add_child(sn)
				menu.add_child(_back("c_start" if sk != "" else "career", null))
		"start_club", "scout":
			var wl2: Array = info.get("world", [])
			var sc0: Dictionary = info.get("scout", {})
			var li2: int = int(info.get("start_li", 3)) if n == "start_club" else int(sc0.get("li", 0))
			li2 = clampi(li2, 0, wl2.size() - 1)
			var L2: Dictionary = wl2[li2]
			var cls2: Array = L2["clubs"]
			var top2 := 100.0
			if n == "start_club":
				_title(str(L2["n"]), "Play the cup with a club as it is." if str(info.get("start_kind", "")) == "cup" else "Take over a club as it is: its squad, its strength and its board.")
			else:
				_title("Other clubs", "See any club's squad and bid for its players.")
				# the six leagues as tabs
				var tw2 := (w - 64.0 - 5 * 8.0) / 6.0
				for lj in wl2.size():
					var on2 := lj == li2
					var tb2 := _btn(str(wl2[lj]["n"]).replace("DIVISION ", "").replace("ENGLAND", "ENG").replace("DENMARK", "DEN"), "sc_lg", lj, "ghost", Vector2(32 + lj * (tw2 + 8.0), 96), Vector2(tw2, 40), 16)
					if on2:
						for st in ["normal", "hover", "focus", "pressed"]:
							tb2.add_theme_stylebox_override(st, _box(Color(0.94, 0.95, 0.92), 12))
						for cc2 in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
							tb2.add_theme_color_override(cc2, Color(0.03, 0.08, 0.05))
					menu.add_child(tb2)
				top2 = 146.0
			var tiles := []
			tiles.append_array(cls2)
			var cols2 := 5 if tiles.size() > 20 else 4
			var rows2 := int(ceil(tiles.size() / float(cols2)))
			var gw2 := (w - 64.0 - (cols2 - 1) * 8.0) / cols2
			var gh2 := minf(70.0, (h - top2 - 14.0) / rows2 - 6.0)
			for ti in tiles.size():
				var cl2: Dictionary = tiles[ti]
				var pos2 := Vector2(32 + (ti % cols2) * (gw2 + 8.0), top2 + (ti / cols2) * (gh2 + 6.0))
				var own2 := bool(cl2.get("own", false))
				var me2 := bool(cl2.get("me", false))
				var bt := _btn("", "st_club" if n == "start_club" else "sc_club", int(cl2["i"]), "alt", pos2, Vector2(gw2, gh2), 16)
				if own2 or me2:
					for st in ["normal", "hover", "focus"]:
						bt.add_theme_stylebox_override(st, _box(Color(0.16, 0.2, 0.12, 0.95), 14, GOLD))
				menu.add_child(bt)
				items.append([bt, Vector2(0, 30), 0.01 * ti])
				if not own2:
					var kb2 := ColorRect.new()
					kb2.color = Color(str(cl2["k"][0]))
					kb2.position = Vector2(8, 8)
					kb2.size = Vector2(8, gh2 - 16)
					bt.add_child(kb2)
					var kb3 := ColorRect.new()
					kb3.color = Color(str(cl2["k"][1]))
					kb3.position = Vector2(16, 8)
					kb3.size = Vector2(4, gh2 - 16)
					bt.add_child(kb3)
				var fs2 := 16
				var nm2 := str(cl2["n"])
				while fs2 > 11 and font.get_string_size(nm2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x > gw2 - 74.0:
					fs2 -= 1
				var nl := _label(nm2, fs2, GOLD if own2 else Color.WHITE)
				nl.position = Vector2(28 if not own2 else 14, gh2 * 0.5 - fs2 * 0.7)
				nl.size = Vector2(gw2 - 70.0, fs2 + 8)
				bt.add_child(nl)
				var rl2 := _label("NEW" if own2 else str(int(cl2["r"])), 18 if not own2 else 14, GOLD if not own2 else GOLD, font if not own2 else font2)
				rl2.position = Vector2(gw2 - 48.0, gh2 * 0.5 - 13)
				rl2.size = Vector2(40, 26)
				rl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				bt.add_child(rl2)
			menu.add_child(_back("st_back" if n == "start_club" else "c_market", null))
		"scout_sq":
			var sc1: Dictionary = info.get("scout", {})
			var c6: Dictionary = info.get("car", {})
			_title(str(sc1.get("cn", "")), "%s   ·   team rating %d   ·   tap a player" % [str(sc1.get("clg", "")), int(sc1.get("cr", 0))])
			var sq6: Array = sc1.get("sq", [])
			var sel6 := int(sc1.get("i", -1))
			var lw6 := w * 0.6
			var cw6 := (lw6 - 32.0 - 8.0) * 0.5
			var rh6 := minf(46.0, (h - 100.0 - 16.0) / 9.0)
			var pc6 := {"GK": Color(0.95, 0.6, 0.1), "DF": Color(0.3, 0.6, 1.0), "MF": Color(0.3, 0.85, 0.45), "FW": Color(0.95, 0.3, 0.3)}
			for pi in sq6.size():
				var pl6: Dictionary = sq6[pi]
				var pos6 := Vector2(32 + (pi / 9) * (cw6 + 8.0), 100 + (pi % 9) * rh6)
				var pb := _btn("", "sc_pl", pi, "alt", pos6, Vector2(cw6, rh6 - 5), 16)
				if pi == sel6:
					for st in ["normal", "hover", "focus"]:
						pb.add_theme_stylebox_override(st, _box(Color(0.16, 0.2, 0.12, 0.95), 12, GOLD))
				menu.add_child(pb)
				var ch6 := ColorRect.new()
				ch6.color = pc6.get(str(pl6["pos"]), Color.WHITE)
				ch6.position = Vector2(8, 7)
				ch6.size = Vector2(5, rh6 - 19)
				pb.add_child(ch6)
				var nl6 := _label("%s   %s" % [str(pl6["pos"]), str(pl6["n"])], 17, Color.WHITE)
				nl6.position = Vector2(20, rh6 * 0.5 - 14)
				pb.add_child(nl6)
				var ol6 := _label(str(int(pl6["ovr"])), 18, GOLD)
				ol6.position = Vector2(cw6 - 46, rh6 * 0.5 - 15)
				pb.add_child(ol6)
			var rx6 := lw6 + 8.0
			var rw6 := w - rx6 - 32.0
			var rp6 := _panel(Vector2(rx6, 100), Vector2(rw6, h - 116.0))
			items.append([rp6, Vector2(80, 0), 0.05])
			var res6: Dictionary = sc1.get("res", {})
			if sel6 >= 0 and sel6 < sq6.size():
				var pl7: Dictionary = sq6[sel6]
				var n7 := _label(str(pl7["n"]), 26, Color.WHITE)
				n7.position = Vector2(18, 12)
				rp6.add_child(n7)
				var s7 := _label("%s   ·   AGE %d   ·   CAN REACH %d" % [{"GK": "Goalkeeper", "DF": "Defender", "MF": "Midfielder", "FW": "Forward"}[str(pl7["pos"])], int(pl7["age"]), int(pl7["pot"])], 16, Color(1, 1, 1, 0.7), font2)
				s7.position = Vector2(20, 48)
				rp6.add_child(s7)
				var o7 := _label(str(int(pl7["ovr"])), 48, GOLD)
				o7.position = Vector2(rw6 - 90, 4)
				rp6.add_child(o7)
				var stn := Career.GK_SHORT if str(pl7["pos"]) == "GK" else Career.STAT_SHORT
				for k7 in 4:
					var sl7 := _label("%s  %d" % [stn[k7], int(pl7["st"][k7])], 18, Color.WHITE, font2)
					sl7.position = Vector2(20 + (k7 % 2) * (rw6 * 0.45), 76 + (k7 / 2) * 24)
					rp6.add_child(sl7)
				var abl := ""
				for ab in pl7.get("ab", []):
					abl += ("" if abl == "" else ", ") + str(ab[1])
				var ab7 := _label(("Skills: " + abl) if abl != "" else "No skills", 16, GOLD if abl != "" else Color(1, 1, 1, 0.5), font2)
				ab7.position = Vector2(20, 128)
				ab7.clip_text = true
				ab7.size = Vector2(rw6 - 40, 20)
				rp6.add_child(ab7)
				var ask := int(pl7["ask"])
				var al := _label("THEY WANT ABOUT  %s" % _m(ask), 18, Color.WHITE)
				al.position = Vector2(20, 156)
				rp6.add_child(al)
				var ctr := int(res6.get("counter", 0))
				var rc6 := int(pl7.get("rc", 0))
				var bids := [[int(round(ask * 0.8 / 5.0)) * 5, "LOW BID", "sc_bid"], [ask, "THEIR PRICE", "sc_bid"], [int(round(ask * Career.SELLON_CUT / 5.0)) * 5, "+%d%% SELL-ON" % Career.SELLON_PCT, "sc_bid_so"]]
				if ctr > 0:
					bids = [[ctr, "PAY WHAT THEY ASK", "sc_bid"]]
				if rc6 > 0:
					# one of their best men: not for sale, only his release clause buys him
					al.text = "NOT FOR SALE  ·  RELEASE CLAUSE  %s" % _m(rc6)
					bids = [[rc6, "PAY THE CLAUSE", "sc_rc"]]
				var no6 := str(pl7.get("no", ""))
				if no6 != "":
					# he will not come: no bids, only why
					al.text = "HE WILL NOT JOIN YOU"
					al.add_theme_color_override("font_color", Color(0.95, 0.5, 0.4))
					var nl6 := _label(_trim(no6, font2, 18, rw6 - 40), 18, Color.WHITE, font2)
					nl6.position = Vector2(20, 184)
					rp6.add_child(nl6)
					bids = []
				var bw6 := (rw6 - 36.0 - 8.0 * maxi(bids.size() - 1, 0)) / maxi(bids.size(), 1)
				for bi in bids.size():
					var amt: int = bids[bi][0]
					var can6: bool = int(c6.get("coins", 0)) >= amt
					var bb6 := _btn("%s\n%s" % [bids[bi][1], _mp(amt)], str(bids[bi][2]), amt if str(bids[bi][2]) != "sc_rc" else null, "primary" if can6 else "off", Vector2(rx6 + 18 + bi * (bw6 + 8.0), 100 + 190), Vector2(bw6, 64), 16)
					menu.add_child(bb6)
				# a swap: one of your men plus money
				var sw6: Dictionary = sc1.get("sw", {})
				if not sw6.is_empty() and ctr <= 0 and no6 == "":
					var sy := 100 + 190 + 76
					var swl := _label("SWAP", 16, GOLD, font2)
					swl.position = Vector2(20, sy - 100 + 4)
					rp6.add_child(swl)
					menu.add_child(_btn("‹", "sc_swp", -1, "alt", Vector2(rx6 + 18, sy + 24), Vector2(44, 48), 22))
					menu.add_child(_btn("›", "sc_swp", 1, "alt", Vector2(rx6 + 18 + 50, sy + 24), Vector2(44, 48), 22))
					var swn := _label(_trim("%s  %s %d" % [str(sw6["n"]), str(sw6["pos"]), int(sw6["ovr"])], font2, 18, rw6 - 124 - 196), 18, Color.WHITE, font2)
					swn.position = Vector2(124, sy - 100 + 28)
					rp6.add_child(swn)
					var swv := _label(_trim(("Worth %s to them" % str(sw6["worth_t"])) if bool(sw6["ok"]) else "They do not want him", font2, 15, rw6 - 124 - 196), 15, MUT if bool(sw6["ok"]) else Color(0.95, 0.5, 0.4), font2)
					swv.position = Vector2(124, sy - 100 + 50)
					rp6.add_child(swv)
					var can7: bool = bool(sw6["ok"]) and int(c6.get("coins", 0)) >= int(sw6["cash"])
					menu.add_child(_btn("HIM + %s" % _mp(int(sw6["cash"])), "sc_swap", str(sw6["key"]), "primary" if can7 else "off", Vector2(rx6 + rw6 - 18 - 170, sy + 24), Vector2(170, 48), 15))
			else:
				var hint := _label("Tap a player to see him and make a bid. Their best men cost more, and a big club sells to a smaller one only for a lot.", 18, Color(1, 1, 1, 0.75), font2)
				hint.autowrap_mode = TextServer.AUTOWRAP_WORD
				hint.position = Vector2(20, 20)
				hint.size = Vector2(rw6 - 40, 120)
				rp6.add_child(hint)
			var rm := str(res6.get("msg", ""))
			if rm != "":
				var rl6 := _label(rm, 17, GREEN.lightened(0.3) if bool(res6.get("ok", false)) else GOLD, font2)
				rl6.autowrap_mode = TextServer.AUTOWRAP_WORD
				rl6.position = Vector2(20, rp6.size.y - 110)
				rl6.size = Vector2(rw6 - 40, 60)
				rp6.add_child(rl6)
			var co6 := _label(_mb(int(c6.get("coins", 0))), 20, GOLD)
			co6.position = Vector2(20, rp6.size.y - 40)
			rp6.add_child(co6)
			menu.add_child(_back("sc_back", null))
		"training":
			var c10: Dictionary = info.get("car", {})
			var pl10: Dictionary = c10.get("plan", {})
			var f10 := str(pl10.get("f", "balanced"))
			var i10 := int(pl10.get("i", 1))
			_title("Training", "What the squad works on between matches. Every man grows from it, the ones who play the most.")
			var fl := _label("Focus", 17, GOLD, font2)
			fl.position = Vector2(40, 96)
			menu.add_child(fl)
			var fw10 := (w - 80.0 - 5 * 10.0) / 6.0
			for fi in Career.FOCUS_ORDER.size():
				var fk: String = Career.FOCUS_ORDER[fi]
				var fb10 := _btn(str(Career.FOCI[fk][0]), "c_plan", [fk, -1], "primary" if fk == f10 else "alt", Vector2(40 + fi * (fw10 + 10.0), 118), Vector2(fw10, 56), 18)
				menu.add_child(fb10)
			var fd := _label(str(Career.FOCI[f10][2]), 17, Color(1, 1, 1, 0.8), font2)
			fd.position = Vector2(40, 182)
			menu.add_child(fd)
			var il := _label("How hard", 17, GOLD, font2)
			il.position = Vector2(40, 220)
			menu.add_child(il)
			var idesc := ["Slower growth, the players like it.", "Normal growth.", "Faster growth, but the players feel it: their mood drops a little every match."]
			for ii in 3:
				var ib := _btn(str(Career.INTENS[ii][0]), "c_plan", ["", ii], "primary" if ii == i10 else "alt", Vector2(40 + ii * (fw10 + 10.0), 242), Vector2(fw10, 56), 18)
				menu.add_child(ib)
			var idl := _label(idesc[i10], 17, Color(1, 1, 1, 0.8), font2)
			idl.position = Vector2(40, 306)
			menu.add_child(idl)
			# who is unhappy, and why
			var up := _panel(Vector2(40, 344), Vector2(w - 80.0, h - 360.0))
			var ut := _label("The squad's mood", 17, GOLD, font2)
			ut.position = Vector2(18, 10)
			up.add_child(ut)
			var sq10: Array = c10.get("squad", [])
			var bad := []
			var happy := 0
			for p10 in sq10:
				var m10 := int((p10 as Dictionary).get("mo", 65))
				if m10 < 40:
					bad.append("%s (%s, %s)" % [str(p10["n"]), Career.mood_name(m10), Career.ROLE_WANT[int(p10.get("role", 2))]])
				elif m10 >= 60:
					happy += 1
			var ub10 := _label(("%d HAPPY   ·   %d OKAY   ·   %d UNHAPPY" % [happy, sq10.size() - happy - bad.size(), bad.size()]) + ("" if bad.is_empty() else ":   " + ",   ".join(PackedStringArray(bad))), 17, Color.WHITE if bad.is_empty() else Color(1, 0.7, 0.55), font2)
			ub10.position = Vector2(18, 34)
			ub10.size = Vector2(w - 80.0 - 36.0, h - 360.0 - 44.0)
			ub10.autowrap_mode = TextServer.AUTOWRAP_WORD
			up.add_child(ub10)
			var bk10 := _back("career", null)
			menu.add_child(bk10)
		"contract":
			var c9: Dictionary = info.get("car", {})
			var t9: Dictionary = c9.get("talk", {})
			var sign9 := str(t9.get("kind", "")) == "sign"
			_title("Contract talks", "%s   ·   %s   ·   age %d   ·   rating %d (can reach %d)" % [str(t9.get("n", "")), str(t9.get("pos", "")), int(t9.get("age", 0)), int(t9.get("ovr", 0)), int(t9.get("pot", 0))])
			var pw9 := (w - 64.0 - 20.0) * 0.5
			var lp9 := _panel(Vector2(32, 100), Vector2(pw9, h - 200))
			var rp9 := _panel(Vector2(32 + pw9 + 20, 100), Vector2(pw9, h - 200))
			var rows9 := []
			if bool(t9.get("unhappy", false)):
				rows9.append(["HE IS UNHAPPY", "HE WANTS MORE MONEY TO STAY"])
			if sign9:
				rows9.append(["TRANSFER FEE", _mp(int(t9.get("fee", 0))) + ("   ·   AGREED WITH %s" % str(c9.get("club_n", "")) if str(c9.get("club_n", "")) != "" else "   ·   FOR HIS RIGHTS")])
			else:
				rows9.append(["NOW", "%s A WEEK   ·   %s" % [Career.wage_text(int(t9.get("cur", 0))), "LAST SEASON" if int(t9.get("ct", 1)) <= 1 else "%d SEASONS LEFT" % int(t9.get("ct", 1))]])
			rows9.append(["HE ASKS FOR", "%s A WEEK" % Career.wage_text(int(t9.get("ask", 0)))])
			rows9.append(["SEASONS", "UP TO %d AT HIS AGE" % int(t9.get("maxy", 3))])
			rows9.append(["TRIES LEFT", str(int(t9.get("tries", 3)))])
			for ri9 in rows9.size():
				var k9 := _label(str(rows9[ri9][0]), 16, GOLD, font2)
				k9.position = Vector2(20, 16 + ri9 * 58)
				lp9.add_child(k9)
				var v9 := _label(str(rows9[ri9][1]), 22 if ri9 == 1 else 18, Color.WHITE)
				v9.position = Vector2(20, 34 + ri9 * 58)
				lp9.add_child(v9)
			var ol9 := _label("Your offer", 16, GOLD, font2)
			ol9.position = Vector2(20, 16)
			rp9.add_child(ol9)
			var rx9 := 32 + pw9 + 20
			for li9 in 2:
				var yy9 := 100 + 44 + li9 * 70
				var mn9 := _btn("–", "ct_w" if li9 == 0 else "ct_y", -1, "alt", Vector2(rx9 + 20, yy9), Vector2(60, 54), 28)
				var pl9 := _btn("+", "ct_w" if li9 == 0 else "ct_y", 1, "alt", Vector2(rx9 + pw9 - 80, yy9), Vector2(60, 54), 28)
				menu.add_child(mn9)
				menu.add_child(pl9)
				var vt9 := ("%s A WEEK" % Career.wage_text(int(t9.get("offer", 0)))) if li9 == 0 else ("%d SEASON%s" % [int(t9.get("yrs", 1)), "" if int(t9.get("yrs", 1)) == 1 else "S"])
				var vl9 := _label(vt9, 26, Color.WHITE)
				vl9.position = Vector2(90, 44 + li9 * 70 + 10)
				vl9.size = Vector2(pw9 - 180, 34)
				vl9.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				rp9.add_child(vl9)
			# a release clause: he takes a little less, but a club can pay it and take him
			var rcv: Array = c9.get("talk_rc", [0, 0, 0])
			var rci := clampi(int(t9.get("rc", 0)), 0, 2)
			var yy10 := 100 + 44 + 2 * 70
			menu.add_child(_btn("–", "ct_rc", -1, "alt", Vector2(rx9 + 20, yy10), Vector2(60, 54), 28))
			menu.add_child(_btn("+", "ct_rc", 1, "alt", Vector2(rx9 + pw9 - 80, yy10), Vector2(60, 54), 28))
			var rct := "NO RELEASE CLAUSE" if rci == 0 else ("CLAUSE %s" % _m(int(rcv[rci])))
			var rcl := _label(rct, 22, Color.WHITE)
			rcl.position = Vector2(90, 44 + 2 * 70 + 12)
			rcl.size = Vector2(pw9 - 180, 30)
			rcl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rp9.add_child(rcl)
			var rch := _label(("He takes %d%% less a week, but a club can pay it and take him" % int(round((1.0 - [1.0, 0.92, 0.85][rci]) * 100))) if rci > 0 else "Add one and he takes less a week", 15, MUT, font2)
			rch.position = Vector2(20, 44 + 2 * 70 + 60)
			rch.size = Vector2(pw9 - 40, 22)
			rch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rp9.add_child(rch)
			var after9 := int(c9.get("wages", 0)) - int(t9.get("cur", 0)) + int(t9.get("offer", 0))
			var wb9 := int(c9.get("wb", 0))
			var wt9 := _label("WAGES AFTER:  %s  OF  %s A WEEK" % [Career.wage_text(after9), Career.wage_text(wb9)], 17, Color(1, 0.55, 0.45) if after9 > wb9 else Color(1, 1, 1, 0.75), font2)
			wt9.position = Vector2(20, 296)
			rp9.add_child(wt9)
			var go9 := _btn("MAKE THE OFFER", "ct_go", null, "primary", Vector2(rx9, h - 88), Vector2(pw9, 66), 26)
			menu.add_child(go9)
			var bk9 := _btn("WALK AWAY", "ct_back", null, "ghost", Vector2(32, h - 88), Vector2(pw9, 66), 22)
			menu.add_child(bk9)
			if str(c9.get("msg", "")) != "":
				var ms9 := _label(str(c9.get("msg", "")), 17, GOLD, font2)
				ms9.position = Vector2(20, h - 200 - 40)
				ms9.clip_text = true
				ms9.size = Vector2(pw9 * 2 + 20 - 40, 24)
				lp9.add_child(ms9)
			var co9 := _label(_mb(int(c9.get("coins", 0))), 22, GOLD)
			co9.position = Vector2(w - 260, 20)
			co9.size = Vector2(230, 34)
			co9.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(co9)
		"sug":
			var sg: Dictionary = info.get("sug", {})
			var dm := ColorRect.new()
			dm.color = Color(0.0, 0.03, 0.02, 0.72)
			dm.size = Vector2(w, h)
			menu.add_child(dm)
			var pw := minf(w - 80.0, 760.0)
			var ph := 300.0
			var sp := Panel.new()
			sp.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.97), 20, Color(GOLD.r, GOLD.g, GOLD.b, 0.6)))
			sp.position = Vector2((w - pw) * 0.5, (h - ph) * 0.5)
			sp.size = Vector2(pw, ph)
			menu.add_child(sp)
			items.append([sp, Vector2(0, 40), 0.0])
			var st1 := _label("YOUR ASSISTANT MANAGER SUGGESTS", 18, Color(1, 1, 1, 0.7), font2)
			st1.position = Vector2(0, 26)
			st1.size = Vector2(pw, 26)
			st1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sp.add_child(st1)
			var st2 := _label(str(sg.get("t", "")), 30, GOLD)
			st2.position = Vector2(24, 64)
			st2.size = Vector2(pw - 48, 110)
			st2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			st2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			st2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sp.add_child(st2)
			var yb := _btn("YES, DO IT", "sug_yes", null, "primary", Vector2(28, ph - 96), Vector2(pw * 0.5 - 40, 70), 28)
			var nb2 := _btn("NO THANKS", "sug_no", null, "alt", Vector2(pw * 0.5 + 12, ph - 96), Vector2(pw * 0.5 - 40, 70), 24)
			sp.add_child(yb)
			sp.add_child(nb2)
		"cmode":
			var cm: Dictionary = info.get("car", {})
			var cur := str(cm.get("mode", ""))
			_title("What kind of career?", "You can change it later in the career's Office.")
			var cw0 := (w - 64.0 - 24.0) * 0.5
			var defs0 := [
				["simple", "SIMPLE CAREER", "Just play and climb", [
					"The board sets three goals every season",
					"Its confidence rises and falls with your results",
					"A grade and a bonus when the season ends",
					"The cup is part of the season",
					"No sacking: the board only grumbles",
					"No wages or contracts: just buy, sell and play",
				]],
				["full", "FULL CAREER", "Like a real manager", [
					"Everything in the simple career",
					"The board CAN SACK YOU. Then you take a job at another club",
					"Wages and a wage budget, contract talks, contracts that run out",
				]],
			]
			for i0 in 2:
				var dd: Array = defs0[i0]
				var px0 := 32.0 + i0 * (cw0 + 24.0)
				var on0: bool = cur == dd[0]
				var pn0 := _panel(Vector2(px0, 100), Vector2(cw0, h - 100.0 - 116.0), 0.9)
				if on0:
					pn0.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.92), 18, GOLD))
				items.append([pn0, Vector2(0, 50), 0.06 * i0])
				var tl0 := _label(dd[1], 30, GOLD if i0 == 1 else Color.WHITE)
				tl0.position = Vector2(24, 16)
				pn0.add_child(tl0)
				var sl0 := _label(str(dd[2]), 17, Color(1, 1, 1, 0.65), font2)
				sl0.position = Vector2(26, 56)
				pn0.add_child(sl0)
				var yy0 := 90.0
				for ln0 in dd[3]:
					var dot := ColorRect.new()
					dot.color = GOLD if i0 == 1 else GREEN
					dot.position = Vector2(26, yy0 + 9)
					dot.size = Vector2(7, 7)
					pn0.add_child(dot)
					var bl := _label(str(ln0), 18, Color(1, 1, 1, 0.9), font2)
					bl.autowrap_mode = TextServer.AUTOWRAP_WORD
					bl.position = Vector2(44, yy0)
					bl.size = Vector2(cw0 - 70.0, 24)
					pn0.add_child(bl)
					yy0 += 26.0 * ceilf(font2.get_string_size(str(ln0), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x / (cw0 - 76.0)) + 6.0
				var pb0 := _btn(("PLAYING " if on0 else "PLAY ") + str(dd[1]).split(" ")[0], "cmode_set", dd[0], "alt" if on0 else "primary", Vector2(px0, h - 100.0), Vector2(cw0, 72), 26)
				menu.add_child(pb0)
				items.append([pb0, Vector2(0, 60), 0.1 + 0.06 * i0])
			if cur != "":
				menu.add_child(_back("tab", "career"))
		"board":
			var cb: Dictionary = info.get("car", {})
			var bd: Dictionary = cb.get("board", {})
			var full0 := bool(bd.get("full", false))
			_title("The board", ("Full career: at confidence %d or less when the season ends, you are sacked." % int(bd.get("sack_at", 20))) if full0 else "Simple career: the board cannot sack you, but it pays a bonus for a good season.")
			var lw4 := w * 0.36
			var lp4 := _panel(Vector2(32, 104), Vector2(lw4, h - 104.0 - 24.0))
			items.append([lp4, Vector2(-60, 0), 0.0])
			_board_meter(lp4, bd, lw4)
			var rx4 := 32.0 + lw4 + 16.0
			var rw4 := w - rx4 - 32.0
			var gl4 := _label("This season's goals", 17, GOLD, font2)
			gl4.position = Vector2(rx4 + 4, 102)
			menu.add_child(gl4)
			var objs: Array = bd.get("obj", [])
			var tags := ["MAIN GOAL", "THE CUP", "EXTRA GOAL"]
			var hist4: Array = bd.get("hist", [])
			var oh := (h - 132.0 - 24.0 - (64.0 if not hist4.is_empty() else 0.0)) / 3.0 - 8.0
			for i4 in objs.size():
				var ob: Dictionary = objs[i4]
				var rp := _panel(Vector2(rx4, 130.0 + i4 * (oh + 8.0)), Vector2(rw4, oh))
				items.append([rp, Vector2(80, 0), 0.05 * i4])
				_obj_row(rp, tags[i4], str(ob["t"]), str(ob["now"]), str(ob["st"]), rw4, oh)
			if not hist4.is_empty():
				var hy := h - 24.0 - 56.0
				var hl := _label("Past seasons", 17, Color(1, 1, 1, 0.6), font2)
				hl.position = Vector2(rx4 + 4, hy)
				menu.add_child(hl)
				var hx := rx4
				for hh in hist4.slice(maxi(hist4.size() - 6, 0)):
					var chip := Panel.new()
					chip.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.85), 10, _grade_col(str(hh["g"]))))
					chip.position = Vector2(hx, hy + 22)
					chip.size = Vector2(118, 34)
					chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
					menu.add_child(chip)
					var ct := _label("SEASON %d  %s" % [int(hh["s"]), _ord(int(hh["pos"]))], 16, Color.WHITE, font2)
					ct.position = Vector2(10, 7)
					chip.add_child(ct)
					var cg := _label(str(hh["g"]), 20, _grade_col(str(hh["g"])))
					cg.position = Vector2(92, 2)
					chip.add_child(cg)
					hx += 126.0
			menu.add_child(_back("tab", "career"))
		"review":
			var cr: Dictionary = info.get("car", {})
			var br: Dictionary = cr.get("board", {})
			var rv: Dictionary = br.get("review", {})
			var sacked := bool(rv.get("sacked", false))
			_title("Season %d: the board's verdict" % int(rv.get("season", cr.get("season", 1))), "%s   ·   you finished %s" % [str(cr.get("lgname", "")).capitalize(), _ord(int(rv.get("pos", 1)))])
			var bot := 108.0 if sacked else 100.0
			var lw5 := w * 0.34
			var lp5 := _panel(Vector2(32, 104), Vector2(lw5, h - 104.0 - bot))
			items.append([lp5, Vector2(-60, 0), 0.0])
			var gr := str(rv.get("grade", "C"))
			var gb := Panel.new()
			gb.add_theme_stylebox_override("panel", _box(Color(0.03, 0.06, 0.05, 1.0), 60, _grade_col(gr)))
			gb.size = Vector2(110, 110)
			gb.position = Vector2(lw5 * 0.5 - 55, 18)
			gb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lp5.add_child(gb)
			var gt := _label(gr, 72, _grade_col(gr))
			gt.position = Vector2(0, 4)
			gt.size = Vector2(110, 96)
			gt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			gb.add_child(gt)
			gb.pivot_offset = Vector2(55, 55)
			if anim:
				gb.scale = Vector2(2.2, 2.2)
				gb.modulate.a = 0.0
				var tw5 := gb.create_tween()
				tw5.set_parallel(true)
				tw5.tween_property(gb, "scale", Vector2.ONE, 0.5).set_delay(0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw5.tween_property(gb, "modulate:a", 1.0, 0.2).set_delay(0.35)
			var wd := _label(str(rv.get("words", "")), 18, Color(0.95, 0.4, 0.35) if sacked else Color.WHITE)
			wd.autowrap_mode = TextServer.AUTOWRAP_WORD
			wd.position = Vector2(18, 140)
			wd.size = Vector2(lw5 - 36.0, 70)
			wd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lp5.add_child(wd)
			var ch5 := int(rv.get("ch", 0))
			var cl5 := _label("CONFIDENCE  %d   (%s%d)" % [int(rv.get("conf", 50)), "+" if ch5 >= 0 else "", ch5], 18, GOLD, font2)
			cl5.position = Vector2(0, lp5.size.y - 62)
			cl5.size = Vector2(lw5, 24)
			cl5.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lp5.add_child(cl5)
			var bn5 := _label("BOARD BONUS  +%s" % _m(int(rv.get("bonus", 0))), 18, Color.WHITE if int(rv.get("bonus", 0)) > 0 else Color(1, 1, 1, 0.5), font2)
			bn5.position = Vector2(0, lp5.size.y - 34)
			bn5.size = Vector2(lw5, 24)
			bn5.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lp5.add_child(bn5)
			var rx5 := 32.0 + lw5 + 16.0
			var rw5 := w - rx5 - 32.0
			var rows5: Array = rv.get("rows", [])
			var tags5 := ["MAIN GOAL", "THE CUP", "EXTRA GOAL"]
			var oh5 := (h - 104.0 - bot) / 3.0 - 8.0
			for i5 in rows5.size():
				var rr: Array = rows5[i5]
				var rp5 := _panel(Vector2(rx5, 104.0 + i5 * (oh5 + 8.0)), Vector2(rw5, oh5))
				items.append([rp5, Vector2(80, 0), 0.1 + 0.08 * i5])
				_obj_row(rp5, tags5[i5], str(rr[0]), str(rr[1]), "done" if bool(rr[2]) else "missed", rw5, oh5)
			if sacked:
				var offs: Array = br.get("offers", [])
				var ol := _label("Three clubs want you. Pick your new job:", 17, GOLD, font2)
				ol.position = Vector2(34, h - bot + 2)
				menu.add_child(ol)
				var ow := (w - 64.0 - 20.0) / 3.0
				for i6 in offs.size():
					var of6: Dictionary = offs[i6]
					var tb6 := _tile(str(of6["n"]), "%s   ·   team rating %d" % [str(of6["lgname"]).capitalize(), int(of6["lv"])], "c_job", i6, Vector2(32 + i6 * (ow + 10.0), h - bot + 26.0), Vector2(ow, 72), Color.WHITE, 20)
					var kb := ColorRect.new()
					kb.color = Color(str((of6["k"] as Array)[0]))
					kb.position = Vector2(0, 8)
					kb.size = Vector2(6, 56)
					tb6.add_child(kb)
					menu.add_child(tb6)
					items.append([tb6, Vector2(0, 60), 0.4 + 0.06 * i6])
			else:
				var nb5 := _btn("NEXT SEASON", "c_next", null, "primary", Vector2(w - 32.0 - 360.0, h - 84.0), Vector2(360, 68), 30)
				menu.add_child(nb5)
				items.append([nb5, Vector2(0, 60), 0.4])
				var mv := _label(str(cr.get("note", "")), 17, Color(1, 1, 1, 0.75), font2)
				mv.autowrap_mode = TextServer.AUTOWRAP_WORD
				mv.position = Vector2(34, h - 84.0)
				mv.size = Vector2(w - 32.0 - 360.0 - 60.0, 68)
				mv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				menu.add_child(mv)
				menu.add_child(_back("tab", "career"))
		"cup":
			var c8: Dictionary = (info.get("car", {}) as Dictionary).get("cup", {})
			var cm8 := bool(info.get("cupm", false))
			_title(str(c8.get("cname", "The cup")), ("%s   ·   every club in the country. Lose and you are out." % str((info.get("car", {}) as Dictionary).get("name", ""))) if cm8 else "Every club in the country, one cup a season, played between league rounds. Lose and you are out.")
			# the rounds so far, left to right: your own tie on top in gold, a few of the others under it
			var rds: Array = c8.get("rounds", [])
			var shown: Array = rds.slice(maxi(rds.size() - 4, 0))
			var cw8 := (w - 64.0 - 3 * 10.0) / 4.0
			for ci8 in shown.size():
				var rd: Dictionary = shown[ci8]
				var x8 := 32.0 + ci8 * (cw8 + 10.0)
				var now8 := bool(rd.get("now", false))
				var hl8 := _label("%s   ·   %d TIES" % [str(rd["name"]), int(rd["n"])], 17, GOLD if now8 else Color(1, 1, 1, 0.65), font2)
				hl8.position = Vector2(x8 + 4, 92)
				menu.add_child(hl8)
				var ties: Array = rd["ties"]
				var th8 := minf(54.0, (h - 230.0) / maxf(ties.size(), 1.0) - 6.0)
				for ti8 in ties.size():
					var tt: Array = ties[ti8]
					var mine8: bool = bool(tt[4])
					var rp8 := Panel.new()
					rp8.add_theme_stylebox_override("panel", _box(Color(0.16, 0.2, 0.12, 0.95) if mine8 else Color(DARK.r, DARK.g, DARK.b, 0.82), 10, GOLD if mine8 else Color(0, 0, 0, 0)))
					rp8.position = Vector2(x8, 116 + ti8 * (th8 + 6.0) + (8.0 if ti8 > 0 else 0.0))
					rp8.size = Vector2(cw8, th8)
					rp8.mouse_filter = Control.MOUSE_FILTER_IGNORE
					menu.add_child(rp8)
					items.append([rp8, Vector2(0, 30), 0.03 * ti8 + 0.08 * ci8])
					for k8 in 2:
						var sc8: int = int(tt[2 + k8])
						var win8: bool = sc8 >= 0 and sc8 > int(tt[3 - k8])
						var fs8 := 14
						while fs8 > 10 and font.get_string_size(str(tt[k8]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs8).x > cw8 - 50.0:
							fs8 -= 1
						var nl8 := _label(str(tt[k8]), fs8, Color.WHITE if (sc8 < 0 or win8) else Color(1, 1, 1, 0.45), font)
						nl8.position = Vector2(10, 3 + k8 * (th8 * 0.5 - 2))
						rp8.add_child(nl8)
						if sc8 >= 0:
							var sl8 := _label(str(sc8), 17, GOLD if win8 else Color(1, 1, 1, 0.45), font)
							sl8.position = Vector2(cw8 - 28.0, 3 + k8 * (th8 * 0.5 - 2))
							rp8.add_child(sl8)
			var left8 := _label("%d CLUBS STILL IN" % int(c8.get("left", 0)), 17, Color(1, 1, 1, 0.6), font2)
			left8.position = Vector2(w - 332, 92)
			left8.size = Vector2(300, 20)
			left8.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(left8)
			var by8 := h - 96.0
			if bool(c8.get("won", false)) or bool(c8.get("out", false)):
				var rs8 := _label(("YOU WON %s!" % str(c8.get("cname", "The cup"))) if bool(c8.get("won", false)) else "YOU ARE OUT OF THIS CUP", 22, GOLD)
				rs8.position = Vector2(40, by8 + 18)
				menu.add_child(rs8)
				if cm8:
					var nc8 := _btn("NEW CUP", "cm_new", null, "primary", Vector2(w - 400.0, by8), Vector2(360, 76), 30)
					menu.add_child(nc8)
					_pulse(nc8)
				else:
					var nb8 := _label("A NEW CUP STARTS NEXT SEASON", 18, Color(1, 1, 1, 0.7), font2)
					nb8.position = Vector2(w - 400.0, by8 + 26)
					nb8.size = Vector2(360, 30)
					nb8.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					menu.add_child(nb8)
			else:
				var ol8 := _label("%s   ·   AGAINST %s" % [str(c8.get("name", "")), str(c8.get("opp", "")).to_upper()], 20, Color.WHITE)
				ol8.position = Vector2(40, by8 + 20)
				menu.add_child(ol8)
				var due8 := bool((info.get("car", {}) as Dictionary).get("cup_due", false))
				var pb8 := _btn("PLAY CUP MATCH" if due8 else "AFTER LEAGUE ROUND %d" % int((info.get("car", {}) as Dictionary).get("cup_after", 0)), "cup_play", null, "primary" if due8 else "off", Vector2(w - 400.0, by8), Vector2(360, 76), 30 if due8 else 24)
				menu.add_child(pb8)
				if due8:
					_pulse(pb8)
			var bk8 := _back("cm_back" if cm8 else "career", null)
			menu.add_child(bk8)
			if not cm8 and not ((info.get("car", {}) as Dictionary).get("eu", {}) as Dictionary).is_empty():
				menu.add_child(_btn(str(((info.get("car", {}) as Dictionary).get("eu", {}) as Dictionary).get("name", "EUROPE")).trim_prefix("THE ") + "  ›", "eu", null, "alt", Vector2(w - 250, 14), Vector2(226, 44), 17))
			if cm8:
				menu.add_child(_btn("THE TEAM", "cm_team", null, "alt", Vector2(w - 200, 14), Vector2(170, 48), 18))
		"squad":
			_title("The team", "")
			var c3: Dictionary = info.get("car", {})
			var sqd: Array = c3.get("squad", [])
			var xi: Array = c3.get("xi", [])
			var sel: int = int(c3.get("sel", -1))
			var form: Array = c3.get("form", [])
			# the pitch stands upright: your own goal at the bottom, the attack at the top
			var ph := h - 84.0
			var pw := minf(w * 0.44, ph * 1.12)
			var px := 24.0
			var py := 72.0
			var pc := Control.new()
			pc.position = Vector2(px, py)
			pc.size = Vector2(pw, ph)
			pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pc.clip_contents = true
			var ctx := {"pc": pc, "px": px, "py": py, "pw": pw, "ph": ph, "plates": []}
			pc.draw.connect(func():
				var ln := Color(1, 1, 1, 0.55)
				var nb8 := 8
				for i in nb8:
					pc.draw_rect(Rect2(0, ph * i / nb8, pw, ph / nb8 + 1.0), Color(0.11, 0.42, 0.19, 0.97) if i % 2 == 0 else Color(0.09, 0.36, 0.16, 0.97))
				var m := 10.0
				pc.draw_rect(Rect2(m, m, pw - 2 * m, ph - 2 * m), ln, false, 2.0)
				pc.draw_line(Vector2(m, ph * 0.5), Vector2(pw - m, ph * 0.5), ln, 2.0)
				pc.draw_arc(Vector2(pw * 0.5, ph * 0.5), pw * 0.13, 0, TAU, 48, ln, 2.0, true)
				pc.draw_circle(Vector2(pw * 0.5, ph * 0.5), 3.0, ln)
				var bw0 := pw * 0.56
				var bh0 := ph * 0.15
				var gw0 := pw * 0.26
				var gh0 := ph * 0.055
				for sd in 2:
					var yb := (ph - m - bh0) if sd == 0 else m
					pc.draw_rect(Rect2(pw * 0.5 - bw0 * 0.5, yb, bw0, bh0), ln, false, 2.0)
					pc.draw_rect(Rect2(pw * 0.5 - gw0 * 0.5, (ph - m - gh0) if sd == 0 else m, gw0, gh0), ln, false, 2.0)
					var ay := (ph - m - bh0) if sd == 0 else (m + bh0)
					pc.draw_arc(Vector2(pw * 0.5, ay), pw * 0.1, PI if sd == 0 else 0.0, TAU if sd == 0 else PI, 24, ln, 2.0, true)
					pc.draw_circle(Vector2(pw * 0.5, (ph - m - bh0 * 0.68) if sd == 0 else (m + bh0 * 0.68)), 2.5, ln)
					# the goal itself
					pc.draw_rect(Rect2(pw * 0.5 - pw * 0.07, (ph - m) if sd == 0 else (m - 6.0), pw * 0.14, 6.0), Color(1, 1, 1, 0.8))
				if pc.get_meta("drag", false):
					# while a man is carried: where defence, midfield and attack begin
					var zl := ["DEFENCE", "MIDFIELD", "ATTACK"]
					var ys := [ph + 10.0]
					for a0 in [0.29, 0.60]:
						var u0: float = 0.17 + (float(a0) - 0.15) / 0.59 * 0.72
						ys.append(ph - 60.0 - u0 * (ph - 74.0) + 23.0)
					ys.append(-10.0)
					for zi in 3:
						pc.draw_rect(Rect2(0, ys[zi + 1], pw, ys[zi] - ys[zi + 1]), Color(1, 1, 1, 0.05 if zi % 2 == 0 else 0.0))
					for zi in [1, 2]:
						# on each line: the zone above and the zone below, at the right edge
						var yl: float = ys[zi]
						pc.draw_string(font2, Vector2(pw - 120.0, yl - 6.0), zl[zi], HORIZONTAL_ALIGNMENT_RIGHT, 106, 13, Color(1, 1, 1, 0.7))
						pc.draw_string(font2, Vector2(pw - 120.0, yl + 16.0), zl[zi - 1], HORIZONTAL_ALIGNMENT_RIGHT, 106, 13, Color(1, 1, 1, 0.7))
					for zi in [1, 2]:
						var yy: float = ys[zi]
						var xx := 0.0
						while xx < pw:
							pc.draw_line(Vector2(xx, yy), Vector2(minf(xx + 12.0, pw), yy), Color(1, 1, 1, 0.6), 2.0)
							xx += 22.0
			)
			menu.add_child(pc)
			var pcol := {"GK": Color(0.95, 0.6, 0.1), "DF": Color(0.3, 0.6, 1.0), "MF": Color(0.3, 0.85, 0.45), "FW": Color(0.95, 0.3, 0.3)}
			var bw := minf(96.0, (pw - 28.0) / 4.0 - 4.0)
			ctx["bw"] = bw
			ctx["pcol"] = pcol
			var tp := []
			for si2 in xi.size():
				# depth in the formation runs up the screen, width runs across it
				var up: float = 0.035 if si2 == 0 else clampf(0.17 + (float(form[si2][1]) - 0.15) / 0.59 * 0.72, 0.0, 1.0)
				var ax: float = 0.5 + float(form[si2][2]) * 0.5
				tp.append(Vector2(px + 14.0 + ax * (pw - 28.0 - bw), py + ph - 14.0 - 46.0 - up * (ph - 28.0 - 46.0)))
			# no two name plates on top of each other: the higher one moves up, the lower one down
			for pass_i in 8:
				for i in range(0, tp.size()):
					for j in range(i + 1, tp.size()):
						var dv: Vector2 = tp[j] - tp[i]
						if absf(dv.x) < bw + 3.0 and absf(dv.y) < 49.0:
							var push := (49.0 - absf(dv.y)) * 0.5
							var sgn := 1.0 if dv.y >= 0.0 else -1.0
							if i == 0:
								# the keeper stays on his line: the other man moves up
								tp[j].y -= push * 2.0
							else:
								tp[j].y += push * sgn
								tp[i].y -= push * sgn
			for j in range(1, tp.size()):
				if absf(tp[j].x - tp[0].x) < bw + 3.0 and tp[0].y - tp[j].y < 49.0:
					tp[j].y = tp[0].y - 49.0
			for si2 in xi.size():
				var pl: Dictionary = sqd[int(xi[si2])]
				tp[si2].y = clampf(tp[si2].y, py + 12.0, py + ph - 12.0 - 46.0)
				var pb := _player_btn(pl, int(xi[si2]), tp[si2], Vector2(bw, 46), pcol, int(xi[si2]) == sel, str(form[si2][0]) if str(form[si2][0]) != str(pl["pos"]) and not (pl.get("pos2", []) as Array).has(str(form[si2][0])) else "")
				menu.add_child(pb)
				ctx["plates"].append([pb, int(xi[si2]), si2])
				_drag_plate(pb, int(xi[si2]), si2, ctx)
			var bx3 := px + pw + 18.0
			var bw3 := w - bx3 - 24.0
			var bn := 0
			var bcols := 4
			var on_sel := sel >= 0 and sel < sqd.size()
			var bench_y := 100.0
			if not on_sel:
				# nobody picked: the bench to drag onto the pitch, and how it works
				var bl := _label("Bench: drag a man onto the pitch", 20, MUT, font3)
				bl.position = Vector2(bx3, 70)
				menu.add_child(bl)
				for qi in sqd.size():
					if xi.has(qi) or xi.has(float(qi)):
						continue
					var bb := _player_btn(sqd[qi], qi, Vector2(bx3 + (bn % bcols) * (bw3 / bcols), bench_y + (bn / bcols) * 58), Vector2(bw3 / bcols - 8, 52), pcol, false, "")
					menu.add_child(bb)
					ctx["plates"].append([bb, qi, -1])
					_drag_plate(bb, qi, -1, ctx)
					bn += 1
			var dy := (bench_y + maxi((bn + bcols - 1) / bcols, 1) * 58.0 + 8.0) if not on_sel else 70.0
			var dp := Panel.new()
			dp.add_theme_stylebox_override("panel", _box(Color(S1.r, S1.g, S1.b, 0.97), 16, LINE))
			dp.position = Vector2(bx3, dy)
			dp.size = Vector2(bw3, h - dy - 14)
			dp.mouse_filter = Control.MOUSE_FILTER_PASS
			menu.add_child(dp)
			if on_sel:
				var sp2: Dictionary = sqd[sel]
				var eur3 := bool(c3.get("eur", false))
				# wages and contracts: only in a FULL career
				var wg3 := bool(c3.get("wg", eur3))
				var dph := dp.size.y
				# the big number, his name and one line about him
				var rv := _label(str(int(sp2["ovr"])), 56, GOLD)
				rv.position = Vector2(18, 6)
				dp.add_child(rv)
				var dn := _label("%d  %s" % [int(sp2["num"]), str(sp2["n"]).capitalize()], 30, CHALK)
				dn.position = Vector2(104, 8)
				dp.add_child(dn)
				var pnm: String = {"GK": "Keeper", "DF": "Defender", "MF": "Midfielder", "FW": "Forward"}.get(str(sp2["pos"]), str(sp2["pos"]))
				var meta := "%s  ·  %d  ·  can reach %d" % [pnm, int(sp2["age"]), int(sp2["pot"])]
				if wg3:
					meta += "  ·  %s a week  ·  %s" % [Career.wage_text(int(sp2.get("wk", 0))), "last season" if int(sp2.get("ct", 1)) <= 1 else "%d seasons" % int(sp2.get("ct", 1))]
				elif not eur3:
					meta += "  ·  %d goals" % int(sp2["g"])
				if eur3 and sp2.has("fm"):
					meta = "Form %s  ·  " % Career.form_name(int(sp2["fm"])).to_lower() + meta
				var sr3 := str(sp2.get("sr", ""))
				var wrong3 := sr3 != "" and sr3 != str(sp2["pos"]) and not (sp2.get("pos2", []) as Array).has(sr3)
				if wrong3:
					# out of position: where he stands and what it costs him, first on the line
					meta = "Out of position: plays %s, %d on every stat  ·  " % [{"GK": "in goal", "DF": "in defence", "MF": "in midfield", "FW": "up front"}.get(sr3, sr3), int(sp2.get("po", 0))] + meta
				var fit_t := ""
				if int(sp2.get("cond", -1)) >= 0:
					fit_t = ("Injured: " + str(sp2.get("injt", ""))) if bool(sp2.get("inj", false)) else "Fitness %d%%" % int(sp2["cond"])
				var hurt := bool(sp2.get("inj", false))
				var dd := _label(_trim(fit_t if hurt else meta, font3, 20, bw3 - 130), 20, Color(0.95, 0.45, 0.4) if hurt else (WRONG if wrong3 else (GOLD if wg3 and int(sp2.get("ct", 1)) <= 1 else MUT)), font3)
				if fit_t != "" and not hurt:
					var ftl := _label(fit_t, 20, _fit_col(int(sp2["cond"])), font3)
					ftl.position = Vector2(bw3 - 250, 16)
					ftl.size = Vector2(180, 28)
					ftl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					dp.add_child(ftl)
				dd.position = Vector2(104, 46)
				dd.clip_text = true
				dd.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				dd.size = Vector2(bw3 - 120, 28)
				dp.add_child(dd)
				var xc := _btn("✕", "c_pick", sel, "ghost", Vector2(bx3 + bw3 - 54, dy + 10), Vector2(44, 40), 20)
				menu.add_child(xc)
				var tpn := 0 if eur3 else int(sp2.get("tp", 0))
				if tpn > 0:
					var tpl := _label("TP %d" % tpn, 24, GOLD)
					tpl.position = Vector2(bw3 - 160, 12)
					tpl.size = Vector2(96, 32)
					tpl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					dp.add_child(tpl)
				# four stats with bars; a training point gives a +1 next to each
				var sn := (["Diving", "Handling", "Kicking", "Reflexes"] if str(sp2.get("pos", "")) == "GK" else ["Pace", "Shooting", "Passing", "Defending"])
				var cw3 := (bw3 - 48) * 0.5
				for sti in 4:
					var sx := 18 + (sti % 2) * (cw3 + 12)
					var sy := 86 + (sti / 2) * 52
					var v := int(sp2["st"][sti])
					var sl := _label("%s  %d" % [sn[sti], v], 22, CHALK, font3)
					sl.position = Vector2(sx, sy)
					dp.add_child(sl)
					var bgr := ColorRect.new()
					bgr.color = Color(1, 1, 1, 0.1)
					bgr.position = Vector2(sx, sy + 30)
					bgr.size = Vector2(cw3, 8)
					dp.add_child(bgr)
					var fil := ColorRect.new()
					fil.color = GREEN if v >= 50 else (GOLD if v >= 35 else Color(0.92, 0.35, 0.3))
					fil.position = Vector2(sx, sy + 30)
					fil.size = Vector2(cw3 * clampf(v / 99.0, 0.0, 1.0), 8)
					dp.add_child(fil)
					if tpn > 0:
						var plus := _btn("+1", "c_tp", sti, "primary", Vector2(bx3 + sx + cw3 - 58, dy + sy - 4), Vector2(58, 32), 18)
						menu.add_child(plus)
				var ly := 194.0
				if eur3:
					# his mood and what he expects; what he works on in training
					var mo3 := int(sp2.get("mo", 65))
					var ml := _label("%s  ·  %s%s" % [Career.mood_name(mo3).capitalize(), Career.ROLE_WANT[int(sp2.get("role", 2))].capitalize(), "  ·  wants to leave" if bool(sp2.get("tr", false)) else ""], 19, _mood_col(mo3), font3)
					ml.position = Vector2(18, ly)
					ml.clip_text = true
					ml.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
					ml.size = Vector2(bw3 - 250, 26)
					dp.add_child(ml)
					var fcb := _btn("Trains: %s  ›" % Career.focus_name(str(sp2.get("tf", "")), str(sp2.get("pos", ""))).capitalize(), "c_focus", null, "alt", Vector2(bx3 + bw3 - 18 - 220, dy + ly - 6), Vector2(220, 38), 17)
					fcb.add_theme_font_override("font", font3)
					menu.add_child(fcb)
					ly += 38.0
				# the bar that fills by playing
				var xb := ColorRect.new()
				xb.color = Color(1, 1, 1, 0.12)
				xb.position = Vector2(18, ly + 4)
				xb.size = Vector2(bw3 - 36, 6)
				dp.add_child(xb)
				var xf := ColorRect.new()
				xf.color = Color(0.55, 0.8, 1.0)
				xf.position = Vector2(18, ly + 4)
				xf.size = Vector2((bw3 - 36) * clampf(float(sp2["xp"]) / 100.0, 0.0, 1.0), 6)
				dp.add_child(xf)
				var xl := _label(("Playing fills the bar; full = he gets better" if int(sp2["ovr"]) < int(sp2["pot"]) else "At his best") if eur3 else (("Tap +1 on what he should learn" if tpn > 0 else "Playing fills the bar; full = 1 training point") if int(sp2["ovr"]) < int(sp2["pot"]) else "At his best"), 18, GOLD if tpn > 0 else MUT, font3)
				xl.position = Vector2(18, ly + 14)
				dp.add_child(xl)
				# his skills: two places, the second opens at rating 70
				var abl: Array = sp2.get("ab", [])
				var abw := (bw3 - 46) * 0.5
				var aby := dy + ly + 46
				for ai in 2:
					var atx := ""
					var akind := "alt"
					if ai < abl.size():
						atx = str(abl[ai][1]).capitalize()
					elif ai == 1 and bool(sp2.get("ab_lock2", true)):
						atx = "Skill 2 at rating 70"
						akind = "off"
					else:
						atx = "+ Learn a skill  (%s)" % _mp(int(sp2["ab_cost"][ai]))
						akind = "primary" if ai == abl.size() else "off"
					var abb := _btn(atx, "c_ab", ai, akind, Vector2(bx3 + 18 + ai * (abw + 10), aby), Vector2(abw, 44), 18)
					abb.add_theme_font_override("font", font3)
					if ai < abl.size():
						abb.add_theme_color_override("font_color", GOLD)
						abb.tooltip_text = str(abl[ai][2])
					menu.add_child(abb)
				# a new position: what else he plays, and what he is learning
				if bool(sp2.get("rto", false)) or not (sp2.get("pos2", []) as Array).is_empty():
					var rty := ly + 104.0
					var p2a: Array = sp2.get("pos2", [])
					var rt3 := str(sp2.get("rt", ""))
					var rtx := ("Also plays %s" % ", ".join(p2a)) if not p2a.is_empty() else "Only plays %s" % str(sp2.get("pos", ""))
					if rt3 != "":
						rtx += "  ·  learning %s %d%%" % [rt3, int(sp2.get("rtp", 0))]
					var rtl := _label(rtx, 19, GOLD if rt3 != "" else MUT, font3)
					rtl.position = Vector2(18, rty)
					rtl.size = Vector2(bw3 - 270, 26)
					rtl.clip_text = true
					rtl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
					dp.add_child(rtl)
					if rt3 != "":
						var rbg := ColorRect.new()
						rbg.color = Color(1, 1, 1, 0.12)
						rbg.position = Vector2(18, rty + 30)
						rbg.size = Vector2(bw3 - 290, 5)
						dp.add_child(rbg)
						var rfl := ColorRect.new()
						rfl.color = GOLD
						rfl.position = Vector2(18, rty + 30)
						rfl.size = Vector2((bw3 - 290) * clampf(float(sp2.get("rtp", 0)) / 100.0, 0.0, 1.0), 5)
						dp.add_child(rfl)
					if bool(sp2.get("rto", false)):
						var rtb := _btn(("Retrain: %s  ›" % rt3) if rt3 != "" else "Retrain  ›", "c_rt", null, "alt", Vector2(bx3 + bw3 - 18 - 220, dy + rty - 6), Vector2(220, 38), 17)
						rtb.add_theme_font_override("font", font3)
						menu.add_child(rtb)
				var can: bool = int(c3.get("coins", 0)) >= int(sp2["cost"]) and int(sp2["ovr"]) + int(sp2.get("tp", 0)) < int(sp2["pot"])
				# the transfer list button is there for every man, in the eleven or not
				var on_bench := true
				var tw3 := (bw3 - 36) * (0.58 if on_bench else 1.0)
				if eur3 and not wg3:
					# a simple career: no contracts, so only selling (from the bench)
					tw3 = -10.0
				var trb := _btn(("NEW CONTRACT" if int(sp2.get("ct", 1)) > 1 else "RENEW CONTRACT") if eur3 else "TRAIN +1  ·  %s" % _m(int(sp2["cost"])), "ct_open" if eur3 else "c_train", null, "primary" if (can or eur3) else "off", Vector2(bx3 + 18, dy + dph - 70), Vector2(tw3, 56), 22)
				if tw3 > 0.0:
					menu.add_child(trb)
				if on_bench:
					var lst2: bool = bool(sp2.get("tl", false))
					var slb := _btn("TAKE OFF LIST" if lst2 else "TRANSFER LIST", "c_sell", null, "alt" if lst2 else "ghost", Vector2(bx3 + 18 + tw3 + 10, dy + dph - 70), Vector2(bw3 - 36 - tw3 - 10, 56), 20)
					menu.add_child(slb)
			else:
				var fit_on := not sqd.is_empty() and int((sqd[0] as Dictionary).get("cond", -1)) >= 0
				var hint2 := _label("Tap a player to see him.\nDrag a player to move him, or onto a team mate to swap.\nOrange DF › FW: a defender playing up front (out of position)." + ("\nThe bar under a name: his fitness. A red cross: injured." if fit_on else ""), 20, MUT, font3)
				hint2.position = Vector2(18, 14)
				hint2.autowrap_mode = TextServer.AUTOWRAP_WORD
				hint2.size = Vector2(bw3 - 36, dp.size.y - 28 - (96 if fit_on else 0))
				dp.add_child(hint2)
				if fit_on:
					# tired men in the eleven: resting them is your call, man by man, and legs only come back day by day
					var tired := []
					for ti in xi:
						var tpl2: Dictionary = sqd[int(ti)]
						if int(tpl2.get("cond", 100)) < 75 and not bool(tpl2.get("inj", false)):
							tired.append([int(tpl2["cond"]), str(tpl2["n"]).capitalize()])
					tired.sort()
					var tnm := []
					for tz in mini(tired.size(), 3):
						tnm.append("%s %d%%" % [tired[tz][1], tired[tz][0]])
					var trt := ("Tired in your eleven: " + ", ".join(tnm) + ((" and %d more" % (tired.size() - 3)) if tired.size() > 3 else "") + ".\nRest a man by bringing a fresher one in.") if not tired.is_empty() else "Your eleven is fit."
					var trl := _label(trt, 19, GOLD if not tired.is_empty() else MUT, font3)
					trl.position = Vector2(18, dp.size.y - 92)
					trl.autowrap_mode = TextServer.AUTOWRAP_WORD
					trl.size = Vector2(bw3 - 36, 80)
					dp.add_child(trl)
			if str(c3.get("msg", "")) != "":
				var ms := _label(str(c3.get("msg", "")), 19, GOLD, font3)
				ms.position = Vector2(bx3 + 18, dy + dp.size.y - 100)
				ms.clip_text = true
				ms.size = Vector2(bw3 - 36, 26)
				menu.add_child(ms)
			var co3 := _label(_mb(int(c3.get("coins", 0))), 22, GOLD)
			co3.position = Vector2(w - 260, 20)
			co3.size = Vector2(230, 34)
			co3.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(co3)
			var bk3 := _back("career", null)
			var fb := _btn("FORMATION:  " + str(c3.get("fname", "4-3-3")) + ("*" if bool(c3.get("moved", false)) else ""), "c_form", null, "alt", Vector2(158, 14), Vector2(230, 48), 17)
			menu.add_child(fb)
			if bool(c3.get("moved", false)):
				# your own spots: one tap puts the formation back as drawn
				var rb := _btn("RESET SPOTS", "c_lay0", null, "ghost", Vector2(px + pw - 128.0, py + ph - 44.0), Vector2(120, 36), 13)
				menu.add_child(rb)
			menu.add_child(bk3)
		"abil":
			var c9: Dictionary = info.get("car", {})
			var ap: Dictionary = c9.get("ab_pick", {})
			var opts9: Array = ap.get("opts", [])
			var head9 := "%s  ·  %s" % [str(ap.get("n", "")), str(ap.get("pos", ""))]
			if bool(ap.get("swap", false)):
				head9 += "  ·  SWAP %s FOR %s" % [str(ap.get("cur", "")), _m(int(ap.get("price", 0)))]
			else:
				head9 += "  ·  " + _m(int(ap.get("price", 0)))
			_title("Learn a skill", head9)
			var cols9 := 2 if opts9.size() > 3 else 1
			var gw9 := minf(w - 80.0, 980.0)
			var gx9 := (w - gw9) * 0.5
			var rows9 := int(ceil(opts9.size() / float(cols9)))
			var rh9 := minf(74.0, (h - 190.0) / maxf(rows9, 1))
			for oi9 in opts9.size():
				var op9: Dictionary = opts9[oi9]
				var cw9 := gw9 / cols9
				var ob9 := _btn("", "c_abuy", str(op9["k"]), "off" if bool(op9["has"]) else "alt", Vector2(gx9 + (oi9 % cols9) * cw9, 104 + (oi9 / cols9) * rh9), Vector2(cw9 - 10, rh9 - 8), 15)
				var on9 := _label(str(op9["n"]) + ("   (HAS IT)" if bool(op9["has"]) else ""), 19, GOLD if not bool(op9["has"]) else Color(1, 1, 1, 0.45))
				on9.position = Vector2(16, 6)
				on9.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ob9.add_child(on9)
				var od9 := _label(str(op9["d"]), 16, Color(1, 1, 1, 0.8), font2)
				od9.position = Vector2(16, 34)
				od9.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ob9.add_child(od9)
				menu.add_child(ob9)
			if str(c9.get("msg", "")) != "":
				var ms9 := _label(str(c9.get("msg", "")), 18, GOLD, font2)
				ms9.position = Vector2(0, h - 84)
				ms9.size = Vector2(w, 26)
				ms9.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				menu.add_child(ms9)
			var co9 := _label(_mb(int(c9.get("coins", 0))), 22, GOLD)
			co9.position = Vector2(w - 260, 20)
			co9.size = Vector2(230, 34)
			co9.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(co9)
			menu.add_child(_back("c_abback", null))
		"subs":
			var sb: Dictionary = info.get("subs", {})
			var left := int(sb.get("left", 0))
			_title("Substitutions", ("%d left. Tap a player on the pitch, then the man who comes on." % left) if left > 0 else "You have used all three.")
			var dim6 := ColorRect.new()
			dim6.color = Color(0.0, 0.03, 0.02, 0.72)
			dim6.size = Vector2(w, h)
			dim6.mouse_filter = Control.MOUSE_FILTER_STOP
			menu.add_child(dim6)
			menu.move_child(dim6, 0)
			var pcol6 := {"GK": Color(0.95, 0.6, 0.1), "DF": Color(0.3, 0.6, 1.0), "MF": Color(0.3, 0.85, 0.45), "FW": Color(0.95, 0.3, 0.3)}
			var on6: Array = sb.get("on", [])
			var sel6 := int(sb.get("sel", -1))
			var lw6 := w * 0.6 - 50.0
			var lh6 := _label("On the pitch", 17, Color(1, 1, 1, 0.65), font2)
			lh6.position = Vector2(40, 94)
			menu.add_child(lh6)
			var rh6 := minf(66.0, (h - 126.0) / 6.0)
			for oi in on6.size():
				var op: Dictionary = on6[oi]
				var colx := 40 + (oi / 6) * (lw6 * 0.5 + 6)
				var chosen6: bool = int(op["slot"]) == sel6
				var ob := _btn("", "sub_pick", int(op["slot"]), "alt", Vector2(colx, 116 + (oi % 6) * rh6), Vector2(lw6 * 0.5 - 6, rh6 - 8), 15)
				for st6 in ["normal", "hover", "focus", "pressed", "disabled"]:
					ob.add_theme_stylebox_override(st6, _box(Color(0.20, 0.25, 0.22, 0.97) if chosen6 else Color(0.06, 0.10, 0.08, 0.94), 10, GOLD if chosen6 else Color(1, 1, 1, 0.2)))
				ob.disabled = bool(op["off"]) or left <= 0
				var ch6 := ColorRect.new()
				ch6.color = pcol6.get(str(op["role"]), Color.WHITE)
				ch6.position = Vector2(8, 8)
				ch6.size = Vector2(6, rh6 - 24)
				ch6.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ob.add_child(ch6)
				var on1 := _label("%d  %s" % [int(op["num"]), str(op["n"])], 18, Color.WHITE if not bool(op["off"]) else Color(1, 1, 1, 0.4))
				on1.position = Vector2(22, 4)
				ob.add_child(on1)
				var on2 := _label("%s  %d" % [str(op["role"]), int(op["ovr"])], 16, Color(1, 1, 1, 0.7), font2)
				on2.position = Vector2(22, rh6 - 36)
				ob.add_child(on2)
				# fitness bar: green when fresh, yellow, then red
				var fit6 := clampf(float(op["fit"]), 0.0, 1.0)
				var bwf := lw6 * 0.5 - 6 - 120.0
				var fb0 := ColorRect.new()
				fb0.color = Color(1, 1, 1, 0.14)
				fb0.position = Vector2(100, rh6 - 28)
				fb0.size = Vector2(bwf, 7)
				fb0.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ob.add_child(fb0)
				var fb1 := ColorRect.new()
				fb1.color = GREEN if fit6 > 0.75 else (Color(0.95, 0.8, 0.15) if fit6 > 0.55 else Color(0.95, 0.3, 0.25))
				fb1.position = Vector2(100, rh6 - 28)
				fb1.size = Vector2(bwf * fit6, 7)
				fb1.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ob.add_child(fb1)
				menu.add_child(ob)
			var bx6 := w * 0.6 + 10.0
			var bw6 := w - bx6 - 40.0
			var bh6 := _label("Bench", 17, Color(1, 1, 1, 0.65), font2)
			bh6.position = Vector2(bx6, 94)
			menu.add_child(bh6)
			var bench6: Array = sb.get("bench", [])
			var rb6 := minf(54.0, (h - 126.0) / maxf(ceilf(bench6.size() / 2.0), 1.0))
			for bi6 in bench6.size():
				var bp: Dictionary = bench6[bi6]
				var bb6 := _btn("", "sub_in", int(bp["sq"]), "alt", Vector2(bx6 + (bi6 % 2) * (bw6 * 0.5), 116 + (bi6 / 2) * rb6), Vector2(bw6 * 0.5 - 6, rb6 - 6), 15)
				for st7 in ["normal", "hover", "focus", "pressed", "disabled"]:
					bb6.add_theme_stylebox_override(st7, _box(Color(0.10, 0.22, 0.14, 0.97) if sel6 >= 0 else Color(0.06, 0.10, 0.08, 0.94), 10, GREEN if sel6 >= 0 else Color(1, 1, 1, 0.2)))
				bb6.disabled = sel6 < 0
				var ch7 := ColorRect.new()
				ch7.color = pcol6.get(str(bp["pos"]), Color.WHITE)
				ch7.position = Vector2(8, 7)
				ch7.size = Vector2(6, rb6 - 20)
				ch7.mouse_filter = Control.MOUSE_FILTER_IGNORE
				bb6.add_child(ch7)
				var bn1 := _label(str(bp["n"]).substr(0, 9), 17, Color.WHITE)
				bn1.position = Vector2(22, 2)
				bb6.add_child(bn1)
				var bn2 := _label("%s  %d" % [str(bp["pos"]), int(bp["ovr"])], 16, Color(1, 1, 1, 0.7), font2)
				bn2.position = Vector2(22, rb6 - 30)
				bb6.add_child(bn2)
				menu.add_child(bb6)
			var bk6 := _back("pause", null)
			menu.add_child(bk6)
		"mtac":
			# change how your side plays without leaving the match (like the pause menu in FIFA)
			var mt: Dictionary = info.get("mtac", {})
			var dim8 := ColorRect.new()
			dim8.color = Color(0.0, 0.03, 0.02, 0.72)
			dim8.size = Vector2(w, h)
			dim8.mouse_filter = Control.MOUSE_FILTER_STOP
			menu.add_child(dim8)
			menu.move_child(dim8, 0)
			_title("Tactics", str(mt.get("sub", "")))
			var t8: Array = mt.get("tac", [2, 1, 1])
			var rows8 := [
				["Mentality", ["Bus", "Defend", "Balanced", "Attack", "All out"], ["Everyone behind the ball", "Sit deeper, hit them on the break",
					"A bit of both", "Push up and get men forward", "Throw everything forward"]],
				["Pressing", ["Low", "Mid", "High"], ["Wait in your own half. Saves legs", "Close them down in your half",
					"Hunt the ball everywhere. It tires your men"]],
				["Width", ["Narrow", "Normal", "Wide"], ["Compact through the middle", "The usual shape", "Stretch the pitch"]]]
			var y8 := 100.0
			var ph8 := minf(118.0, (h - 200.0) / 3.0)
			for ri in 3:
				var r8: Array = rows8[ri]
				var cur8 := clampi(int(t8[ri]), 0, (r8[1] as Array).size() - 1)
				var pn8 := _card_panel(Vector2(48, y8), Vector2(w - 96, ph8 - 10))
				items.append([pn8, Vector2(0, 30), 0.04 * ri])
				var tl8 := _label(str(r8[0]), 22, CHALK)
				tl8.position = Vector2(24, 8)
				pn8.add_child(tl8)
				var dl8 := _label(_trim(str(r8[2][cur8]), font3, 18, w - 96 - 220), 18, MUT, font3)
				dl8.position = Vector2(200, 12)
				dl8.size = Vector2(w - 96 - 220, 26)
				pn8.add_child(dl8)
				var n8: int = (r8[1] as Array).size()
				var bw8 := (w - 96 - 48 - 12 * (n8 - 1)) / float(n8)
				for k in n8:
					menu.add_child(_btn(str(r8[1][k]).to_upper(), "mtac_set", [ri, k], "primary" if k == cur8 else "alt", Vector2(48 + 24 + k * (bw8 + 12), y8 + 46), Vector2(bw8, 48), 18))
				y8 += ph8
			var op8 := str(mt.get("opp", ""))
			if op8 != "":
				var ol8 := _label(_trim(op8, font3, 19, w - 140), 19, GOLD, font3)
				ol8.position = Vector2(64, y8 + 2)
				menu.add_child(ol8)
			menu.add_child(_back("pause", null))
		"club":
			var c7: Dictionary = info.get("car", {})
			var eur7 := bool(c7.get("eur", false))
			var fb7: Dictionary = c7.get("fbuild", {})
			_title("Your club", ("The club's buildings. Ask the board for better ones: once a season, and they want to believe in you (confidence %d)." % int(c7.get("conf", 50))) if eur7 else "Build the club with the %s you earn" % _mw())
			var fcs: Array = c7.get("fac", [])
			var cw7 := minf((w - 80.0 - 2 * 16.0) / 3.0, 370.0)
			var x07 := (w - (cw7 * 3 + 32.0)) * 0.5
			var ch7b := h - 150.0
			var fcol := [Color(0.95, 0.75, 0.2), Color(0.3, 0.85, 0.45), Color(0.4, 0.7, 1.0)]
			for fi7 in fcs.size():
				var fc: Dictionary = fcs[fi7]
				var cp7 := Panel.new()
				cp7.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.9), 18, Color(1, 1, 1, 0.14)))
				cp7.position = Vector2(x07 + fi7 * (cw7 + 16.0), 104)
				cp7.size = Vector2(cw7, ch7b)
				cp7.mouse_filter = Control.MOUSE_FILTER_PASS
				menu.add_child(cp7)
				items.append([cp7, Vector2(0, 40), 0.06 * fi7])
				var bar7 := ColorRect.new()
				bar7.color = fcol[fi7]
				bar7.position = Vector2(18, 16)
				bar7.size = Vector2(44, 5)
				cp7.add_child(bar7)
				var fn7 := _label(str(fc["n"]), 24, Color.WHITE)
				fn7.position = Vector2(18, 26)
				cp7.add_child(fn7)
				var fw7 := _label(str(fc["what"]), 17, Color(1, 1, 1, 0.7), font2)
				fw7.autowrap_mode = TextServer.AUTOWRAP_WORD
				fw7.position = Vector2(18, 60)
				fw7.size = Vector2(cw7 - 36, 44)
				cp7.add_child(fw7)
				# level pips
				for pi7 in int(fc["max"]):
					var pip := Panel.new()
					pip.add_theme_stylebox_override("panel", _box(fcol[fi7] if pi7 < int(fc["lv"]) else Color(1, 1, 1, 0.12), 5))
					pip.position = Vector2(18 + pi7 * ((cw7 - 36) / float(fc["max"])), 112)
					pip.size = Vector2((cw7 - 36) / float(fc["max"]) - 6, 12)
					pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
					cp7.add_child(pip)
				var lv7 := _label("LEVEL %d OF %d" % [int(fc["lv"]), int(fc["max"])], 16, Color(1, 1, 1, 0.65), font2)
				lv7.position = Vector2(18, 130)
				cp7.add_child(lv7)
				var nw7 := _label("Now:  " + str(fc["now"]), 17, Color.WHITE, font2)
				nw7.autowrap_mode = TextServer.AUTOWRAP_WORD
				nw7.position = Vector2(18, 158)
				nw7.size = Vector2(cw7 - 36, 40)
				cp7.add_child(nw7)
				if str(fc["next"]) != "":
					var nx7 := _label("Next:  " + str(fc["next"]), 17, GREEN.lightened(0.3), font2)
					nx7.autowrap_mode = TextServer.AUTOWRAP_WORD
					nx7.position = Vector2(18, 200)
					nx7.size = Vector2(cw7 - 36, 40)
					cp7.add_child(nx7)
					var can7: bool = int(c7.get("coins", 0)) >= int(fc["cost"])
					if eur7 and str(fb7.get("k", "")) == str(fc["k"]):
						var bl7 := _label("BEING BUILT:  READY IN %d MATCHES" % int(fb7.get("left", 0)), 18, GOLD)
						bl7.position = Vector2(18, ch7b - 52)
						cp7.add_child(bl7)
					elif eur7:
						var nd7 := _label("THE BOARD WANTS CONFIDENCE %d  ·  COSTS %s" % [int(fc.get("need", 50)), _mp(int(fc["cost"]))], 16, Color(1, 1, 1, 0.7), font2)
						nd7.position = Vector2(18, ch7b - 96)
						cp7.add_child(nd7)
						var ub2 := _btn("ASK THE BOARD", "c_fac", str(fc["k"]), "primary" if fb7.is_empty() and int(c7.get("conf", 0)) >= int(fc.get("need", 50)) else "alt", Vector2(x07 + fi7 * (cw7 + 16.0) + 18, 104 + ch7b - 70), Vector2(cw7 - 36, 54), 20)
						menu.add_child(ub2)
					else:
						var ub := _btn("BUILD   %s" % _mp(int(fc["cost"])), "c_fac", str(fc["k"]), "primary" if can7 else "alt", Vector2(x07 + fi7 * (cw7 + 16.0) + 18, 104 + ch7b - 70), Vector2(cw7 - 36, 54), 20)
						menu.add_child(ub)
				else:
					var mx7 := _label("FULLY BUILT", 18, GOLD)
					mx7.position = Vector2(18, ch7b - 52)
					cp7.add_child(mx7)
			if str(c7.get("msg", "")) != "":
				var ms7 := _label(str(c7.get("msg", "")), 18, GOLD)
				ms7.position = Vector2(0, h - 36)
				ms7.size = Vector2(w, 26)
				ms7.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				menu.add_child(ms7)
			var co7 := _label(_mb(int(c7.get("coins", 0))), 22, GOLD)
			co7.position = Vector2(w - 260, 20)
			co7.size = Vector2(230, 34)
			co7.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(co7)
			var bk7 := _back("career", null)
			menu.add_child(bk7)
		"market":
			_title("Transfers", "Free agents, new ones after every match. Or buy from the other clubs.")
			var c5: Dictionary = info.get("car", {})
			var mk: Array = c5.get("market", [])
			var pcol5 := {"GK": Color(0.95, 0.6, 0.1), "DF": Color(0.3, 0.6, 1.0), "MF": Color(0.3, 0.85, 0.45), "FW": Color(0.95, 0.3, 0.3)}
			var tw5 := minf(w - 80.0, 1060.0)
			var tx5 := (w - tw5) * 0.5
			var rh5 := minf(66.0, (h - 150.0) / 6.0)
			var heads5 := [["PLAYER", 0.04], ["AGE", 0.27], ["RATING", 0.35], ["CAN REACH", 0.44], ["PAC", 0.56], ["SHO", 0.62], ["PAS", 0.68], ["DEF", 0.74]]
			for hd in heads5:
				var hl5 := _label(str(hd[0]), 16, Color(1, 1, 1, 0.6), font2)
				hl5.position = Vector2(tx5 + float(hd[1]) * tw5, 94)
				menu.add_child(hl5)
			for mi in mk.size():
				var mp: Dictionary = mk[mi]
				var rp5 := Panel.new()
				rp5.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.88), 12, Color(1, 1, 1, 0.12)))
				rp5.position = Vector2(tx5, 114 + mi * rh5)
				rp5.size = Vector2(tw5, rh5 - 6)
				rp5.mouse_filter = Control.MOUSE_FILTER_PASS
				menu.add_child(rp5)
				items.append([rp5, Vector2(0, 30), 0.04 * mi])
				var chip5 := ColorRect.new()
				chip5.color = pcol5.get(str(mp["pos"]), Color.WHITE)
				chip5.position = Vector2(12, 9)
				chip5.size = Vector2(7, rh5 - 24)
				rp5.add_child(chip5)
				var cy5 := (rh5 - 6) * 0.5
				var n5 := _label(str(mp["n"]), 20, Color.WHITE)
				n5.position = Vector2(0.04 * tw5, cy5 - 24)
				rp5.add_child(n5)
				var p5 := _label({"GK": "Goalkeeper", "DF": "Defender", "MF": "Midfielder", "FW": "Forward"}[str(mp["pos"])] + (("   ·   WANTS ABOUT %s A WEEK" % Career.wage_text(int(round(int(mp.get("wk", 1)) * 1.2)))) if bool(c5.get("wg", c5.get("eur", false))) else ""), 16, pcol5.get(str(mp["pos"]), Color.WHITE), font2)
				p5.position = Vector2(0.04 * tw5, cy5 + 2)
				rp5.add_child(p5)
				var vals5 := [[str(mp["age"]), 0.27, 18, Color(1, 1, 1, 0.85)], [str(mp["ovr"]), 0.35, 26, GOLD], [str(mp["pot"]), 0.44, 20, GREEN.lightened(0.3)],
					[str(mp["st"][0]), 0.56, 17, Color.WHITE], [str(mp["st"][1]), 0.62, 17, Color.WHITE], [str(mp["st"][2]), 0.68, 17, Color.WHITE], [str(mp["st"][3]), 0.74, 17, Color.WHITE]]
				for v5 in vals5:
					var vl5 := _label(str(v5[0]), int(v5[2]), v5[3])
					vl5.position = Vector2(float(v5[1]) * tw5, cy5 - int(v5[2]) * 0.72)
					rp5.add_child(vl5)
				if str(mp["pos"]) == "GK":
					# a keeper's numbers are keeper skills: say which under each one
					for gi5 in 4:
						var gl5 := _label(Career.GK_SHORT[gi5], 16, Color(0.95, 0.6, 0.1), font2)
						gl5.position = Vector2([0.56, 0.62, 0.68, 0.74][gi5] * tw5, cy5 + 6)
						rp5.add_child(gl5)
				var can5: bool = int(c5.get("coins", 0)) >= int(mp["price"])
				var bb5 := _btn("BUY   %s" % _mp(int(mp["price"])), "c_buy", mi, "primary" if can5 else "alt", Vector2(tx5 + tw5 * 0.81, 114 + mi * rh5 + 6), Vector2(tw5 * 0.19 - 8, rh5 - 18), 18)
				menu.add_child(bb5)
			if mk.is_empty():
				var em5 := _label("You have signed everyone. New players come after the next match.", 18, Color(1, 1, 1, 0.8), font2)
				em5.position = Vector2(0, h * 0.45)
				em5.size = Vector2(w, 30)
				em5.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				menu.add_child(em5)
			if str(c5.get("msg", "")) != "":
				var ms5 := _label(str(c5.get("msg", "")), 18, GOLD)
				ms5.position = Vector2(0, h - 34)
				ms5.size = Vector2(w, 26)
				ms5.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				menu.add_child(ms5)
			var co5 := _label(_mb(int(c5.get("coins", 0))), 22, GOLD)
			co5.position = Vector2(w - 260, 20)
			co5.size = Vector2(230, 34)
			co5.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(co5)
			var bk5 := _back("career", null)
			menu.add_child(bk5)
			if bool(info.get("incar", false)):
				# buying from other clubs belongs to the career only
				var sc5 := _btn("OTHER CLUBS  >", "scout", null, "primary", Vector2(w - 260 - 230, 14), Vector2(220, 48), 18)
				menu.add_child(sc5)
		"teams":
			if str(info.get("from", "")) == "new":
				_title("Pick your club", "This is the club you will run and play for.")
			elif str(info.get("from", "")) == "lobby" and int(info.get("own_i", -1)) >= 0:
				_title("Pick your team", "Your own club plays with your own squad, formation and spots.")
			else:
				_title("Pick your team", "")
			var cl: Array = info.get("clubs", [])
			var gw := minf(250.0, (w - 100.0) / 4.0 - 12.0)
			var gx := (w - (gw + 12.0) * 4.0 + 12.0) * 0.5
			for ci in mini(cl.size(), 8):
				var cb := _club_btn(info, ci, "club", ci, Vector2(gx + (ci % 4) * (gw + 12.0), 96 + (ci / 4) * 172.0), Vector2(gw, 156), "")
				menu.add_child(cb)
				items.append([cb, Vector2(0, 50), 0.03 * ci])
			var oi := int(info.get("own_i", -1))
			if str(info.get("from", "")) == "lobby" and oi >= 0 and oi < cl.size():
				# in a friend's room: your own club, with your own squad, formation and spots
				var ob := _club_btn(info, oi, "club_own", null, Vector2(w * 0.5 - 240, 96 + 2 * 172.0 - 4), Vector2(480, 58), "YOUR OWN CLUB:  ")
				if bool(info.get("own_ft", false)):
					for st in ["normal", "hover", "focus", "pressed"]:
						ob.add_theme_stylebox_override(st, _box(Color(0.22, 0.27, 0.25, 0.96), 14, GOLD))
				menu.add_child(ob)
				items.append([ob, Vector2(0, 50), 0.26])
			var bk := _back("teams_back", null)
			menu.add_child(bk)
		"friend":
			_title("Play with a friend", "Two phones, one match. One of you creates a room, the other joins.")
			var cw := minf(300.0, (w - 140.0) * 0.5)
			var cy := h * 0.5 - 50.0
			var a := _btn("CREATE A ROOM", "host", null, "primary", Vector2(w * 0.5 - cw - 12, cy), Vector2(cw, 120), 28)
			var b := _btn("JOIN A ROOM", "joinmenu", null, "alt", Vector2(w * 0.5 + 12, cy), Vector2(cw, 120), 28)
			menu.add_child(a)
			menu.add_child(b)
			items.append([a, Vector2(0, 80), 0.05])
			items.append([b, Vector2(0, 80), 0.12])
			if not bool(info.get("web", true)):
				var nw := _label("Online play needs the web version.", 18, GOLD, font2)
				nw.position = Vector2(w * 0.5 - 150, cy + 136)
				menu.add_child(nw)
		"join":
			_title("Enter the room code", "")
			_code = ""
			var slots := _label("_  _  _  _", 54, GOLD)
			slots.name = "slots"
			slots.position = Vector2(60, h * 0.5 - 40)
			slots.size = Vector2(w * 0.5 - 80, 70)
			slots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			menu.add_child(slots)
			var hint := _label("Ask your friend for the 4 digits", 18, Color(1, 1, 1, 0.75), font2)
			hint.position = Vector2(60, h * 0.5 + 40)
			hint.size = Vector2(w * 0.5 - 80, 30)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			menu.add_child(hint)
			var keys := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", ""]
			var ks := minf(72.0, (h - 110.0) / 4.0 - 8.0)
			var kx := w * 0.5 + 40.0
			var ky := 84.0
			for i in keys.size():
				if keys[i] == "":
					continue
				var kb := _btn(keys[i], "key", keys[i], "alt", Vector2(kx + (i % 3) * (ks + 28.0), ky + (i / 3) * (ks + 8.0)), Vector2(ks + 20.0, ks), 30)
				kb.pressed.disconnect(kb.pressed.get_connections()[0]["callable"])
				var kv: String = keys[i]
				kb.pressed.connect(func(): _key(kv))
				menu.add_child(kb)
				items.append([kb, Vector2(0, 40), 0.02 * i])
		"lobby":
			var host: bool = str(info.get("role", "")) == "host"
			var conn: bool = bool(info.get("connected", false))
			_title("Room  " + str(info.get("code", "")), "")
			var col_w := w * 0.5 - 60.0
			if host:
				var cl := _label("ROOM CODE", 20, Color(1, 1, 1, 0.75), font2)
				cl.position = Vector2(48, 92)
				menu.add_child(cl)
				var code := _label(" ".join(str(info.get("code", "")).split("")), 84, GOLD)
				code.position = Vector2(44, 108)
				menu.add_child(code)
				items.append([code, Vector2(-60, 0), 0.0])
				var stt := _label("Friend connected!" if conn else "Waiting for your friend to join...", 22, GREEN.lightened(0.3) if conn else Color.WHITE, font2)
				stt.position = Vector2(48, 214)
				menu.add_child(stt)
				var sh := _btn("SHARE INVITE LINK", "share", null, "ghost", Vector2(48, 256), Vector2(260, 50), 18)
				menu.add_child(sh)
				if str(info.get("co_text", "")) == "":
					# in a career together you play as the career's club: no other team to pick
					var tb2 := _club_btn(info, int(info.get("lclub", info.get("club", 0))), "teams", null, Vector2(48, 318), Vector2(260, 50), "TEAM:  ")
					menu.add_child(tb2)
				var rx := w - col_w - 40.0
				var cot := str(info.get("co_text", ""))
				var md := _btn(((("CUP TOGETHER" if bool(info.get("co_cup", false)) else "CAREER TOGETHER") if cot != "" else "SAME TEAM") if str(info.get("mode", "")) == "coop" else "AGAINST EACH OTHER") + "  ›", "mode", null, "alt", Vector2(rx, 92), Vector2(col_w, 62), 22)
				var mt := _label("Mode  ·  tap to change", 17, Color(1, 1, 1, 0.7), font2)
				mt.position = Vector2(rx + 4, 68)
				menu.add_child(mt)
				menu.add_child(md)
				items.append([md, Vector2(80, 0), 0.05])
				var mh := _label((cot if cot != "" else "You two against the computer") if str(info.get("mode", "")) == "coop" else "Your team against your friend's: " + str(info.get("gname", "")), 18, Color(1, 1, 1, 0.75), font2)
				mh.position = Vector2(rx + 4, 158)
				mh.clip_text = true
				mh.size = Vector2(col_w - 8, 24)
				menu.add_child(mh)
				var d2 := _btn("LEVEL: " + str(info.get("diff", "")), "diff", null, "ghost", Vector2(rx, 190), Vector2(col_w * 0.5 - 6, 50), 17)
				var l2 := _btn("MATCH: " + str(info.get("len", "")), "len", null, "ghost", Vector2(rx + col_w * 0.5 + 6, 190), Vector2(col_w * 0.5 - 6, 50), 17)
				menu.add_child(d2)
				menu.add_child(l2)
				var go := _btn("START MATCH" if conn else "WAITING...", "start", null, "primary" if conn else "off", Vector2(rx, h - 104), Vector2(col_w, 80), 32)
				menu.add_child(go)
				items.append([go, Vector2(0, 60), 0.1])
				if conn:
					if anim:
						go.ready.connect(func(): _pulse(go))
					else:
						_pulse(go)
			else:
				var s2 := _label("Connected!" if conn else "Connecting...", 54, GREEN.lightened(0.3) if conn else Color.WHITE)
				s2.position = Vector2(0, h * 0.5 - 70)
				s2.size = Vector2(w, 70)
				s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				menu.add_child(s2)
				items.append([s2, Vector2(0, 40), 0.0])
				var txt := "Looking for the room"
				if conn:
					txt = "Waiting for the host to start.   Mode: " + ("SAME TEAM" if str(info.get("mode", "")) == "coop" else "AGAINST EACH OTHER")
					if str(info.get("co_text", "")) != "":
						txt = ("" if str(info.get("co_text", "")).begins_with("CUP") else "CAREER TOGETHER:   ") + str(info.get("co_text", ""))
				var s3 := _label(txt, 20, Color(1, 1, 1, 0.8), font2)
				s3.position = Vector2(0, h * 0.5 + 10)
				s3.size = Vector2(w, 30)
				s3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				menu.add_child(s3)
				if conn and str(info.get("co_text", "")) == "" and not bool(info.get("has_cv", false)):
					var tb3 := _club_btn(info, int(info.get("lclub", info.get("club", 0))), "teams", null, Vector2(w * 0.5 - 170, h * 0.5 + 60), Vector2(340, 56), "YOUR TEAM:  ")
					menu.add_child(tb3)
				if conn:
					if bool(info.get("has_cv", false)):
						# the host's career, to look around in as the assistant manager
						var av := _btn("THE PLAYER CAREER TOGETHER  ›" if bool(info.get("cv_pro", false)) else "THE CAREER  ·  ASSISTANT MANAGER  ›", "as_open", null, "primary", Vector2(w * 0.5 - 250, h * 0.5 + 128), Vector2(500, 64), 24)
						menu.add_child(av)
						items.append([av, Vector2(0, 40), 0.1])
		"cal":
			_cal_page(info, w, h, items)
		"cset":
			var c3: Dictionary = info.get("car", {})
			_title("Match settings", "For the career's matches. A quick match keeps its own.")
			var rows3 := [["Level", "cfg_diff", int(c3.get("cdiff", 1)), ["Easy", "Normal", "Hard"], ["The computer gives you time on the ball", "As it comes", "Quicker, sharper and harder to beat"]],
				["Match length", "cfg_len", int(c3.get("clen", 1)), ["3 min", "5 min", "8 min"], ["Quick", "The usual", "A long match: more chances, more drama"]]]
			for ri in 2:
				var r3: Array = rows3[ri]
				var y3 := 116.0 + ri * 170.0
				var pn3 := _card_panel(Vector2(48, y3), Vector2(w - 96, 150))
				items.append([pn3, Vector2(0, 40), 0.05 * ri])
				var t3 := _label(str(r3[0]), 26, CHALK)
				t3.position = Vector2(24, 16)
				pn3.add_child(t3)
				var d3 := _label(str(r3[4][int(r3[2])]), 19, MUT, font3)
				d3.position = Vector2(24, 52)
				d3.size = Vector2(w - 140, 26)
				pn3.add_child(d3)
				var bw3 := (w - 96 - 48 - 24) / 3.0
				for k in 3:
					var b3 := _btn(str(r3[3][k]).to_upper(), str(r3[1]), k, "primary" if k == int(r3[2]) else "alt", Vector2(48 + 24 + k * (bw3 + 12), y3 + 86), Vector2(bw3, 50), 20)
					menu.add_child(b3)
			menu.add_child(_back("tab", "office"))
		"ctac":
			_tac_page(info, w, h, items)
		"nat":
			_nat_page(info, w, h, items)
		"simres":
			_sim_page(info, w, h, items, anim)
		"youth":
			_youth_page(info, w, h, items)
		"pro_start":
			_pro_start_page(info, w, h, items)
		"pro_ab":
			_pro_ab_page(info, w, h, items)
		"inbox":
			_inbox_page(info, w, h, items)
		"scorers":
			_scorers_page(info, w, h, items)
		"eu":
			_eu_page(info, w, h, items)
		"cab":
			_cab_page(info, w, h, items)
		"tnews":
			_tnews_page(info, w, h, items)
		"adv":
			_adv_page(info, w, h, anim)
		"how":
			var hw := minf(w - 80.0, 860.0)
			var hp := Panel.new()
			hp.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.95), 20, Color(1, 1, 1, 0.16)))
			hp.position = Vector2((w - hw) * 0.5, 22)
			hp.size = Vector2(hw, h - 44)
			menu.add_child(hp)
			var ht := _label("HOW TO PLAY", 32, GOLD)
			ht.position = Vector2(0, 12)
			ht.size = Vector2(hw, 40)
			ht.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hp.add_child(ht)
			var rows := [
				["MOVE", "Slide your left thumb anywhere on the left side."],
				["SHOOT", "Hold to load power, let go to shoot. Short taps curl. At a corner kick: cross."],
				["PASS", "To a man's feet, the way the stick points. Hold longer for a man further away."],
				["THROUGH", "Into space in front of a runner. Thumb up on PASS or THROUGH: high ball."],
				["TACKLE", "A fast slide along the grass. From behind it is a foul. Hold: he closes down himself."],
				["SWITCH", "Without the ball: change to the player nearest the ball."],
				["SPRINT", "Pull your thumb further out, past the outer ring. The ring shows your breath."],
			]
			var ry := 62.0
			var rh := minf(46.0, (h - 44.0 - 62.0 - 84.0) / rows.size())
			for r in rows:
				var k1 := _label(r[0], 20, GREEN.lightened(0.25))
				k1.position = Vector2(34, ry)
				hp.add_child(k1)
				var k2 := _label(r[1], 18, Color(1, 1, 1, 0.9), font2)
				k2.position = Vector2(150, ry + 1)
				hp.add_child(k2)
				ry += rh
			var ok := _btn("LET'S PLAY", "how_ok", null, "primary", Vector2((hw - 300) * 0.5, h - 44 - 76), Vector2(300, 60), 26)
			hp.add_child(ok)
			items.append([hp, Vector2(0, 60), 0.0])
		"pause":
			var pw := 340.0
			var panel := Panel.new()
			panel.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.94), 20, Color(1, 1, 1, 0.16)))
			var can_sub := bool(info.get("can_sub", false))
			var can_tac := not (info.get("mtac", {}) as Dictionary).is_empty()
			var ph0 := (394.0 if can_sub else 322.0) + (68.0 if can_tac else 0.0)
			panel.position = Vector2((w - pw) * 0.5, h * 0.5 - ph0 * 0.5)
			panel.size = Vector2(pw, ph0)
			menu.add_child(panel)
			var pt := _label("PAUSED" if not bool(info.get("online", false)) else "MENU", 34, Color.WHITE)
			pt.position = Vector2(0, 16)
			pt.size = Vector2(pw, 44)
			pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			panel.add_child(pt)
			var pby := str(info.get("paused_by", ""))
			if pby != "":
				var pbl := _label("Paused by %s" % pby, 16, Color(1, 1, 1, 0.6), font2)
				pbl.position = Vector2(0, 54)
				pbl.size = Vector2(pw, 20)
				pbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				panel.add_child(pbl)
			panel.add_child(_btn("RESUME", "resume", null, "primary", Vector2(30, 76), Vector2(pw - 60, 72), 30))
			var ty := 160.0
			if can_tac:
				panel.add_child(_btn("TACTICS", "mtac", null, "alt", Vector2(30, ty), Vector2(pw - 60, 60), 19))
				ty += 68.0
			if can_sub:
				panel.add_child(_btn("SUBSTITUTIONS  (%d LEFT)" % int((info.get("subs", {}) as Dictionary).get("left", 0)), "subs", null, "alt", Vector2(30, ty), Vector2(pw - 60, 60), 19))
				ty += 76.0
			var sy := ty if can_sub else ty + 4.0
			panel.add_child(_btn("SOUND: " + str(info.get("snd", "")), "snd_opt", null, "ghost", Vector2(30, sy), Vector2((pw - 72) * 0.5, 50), 15))
			panel.add_child(_btn("VOICE: " + ("ON" if bool(info.get("voice", true)) else "OFF"), "voice_opt", null, "ghost", Vector2(30 + (pw - 72) * 0.5 + 12, sy), Vector2((pw - 72) * 0.5, 50), 15))
			panel.add_child(_btn("LEAVE MATCH", "menu", null, "alt" if not can_sub else "ghost", Vector2(30, sy + 62), Vector2(pw - 60, 60), 22))
			items.append([panel, Vector2(0, 60), 0.0])
		"full":
			var dim := ColorRect.new()
			dim.color = Color(0.0, 0.03, 0.02, 0.5)
			dim.position = Vector2.ZERO
			dim.size = Vector2(w, h)
			dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu.add_child(dim)
			var ft := _label("FULL TIME", 30, GOLD)
			ft.position = Vector2(0, h * 0.5 - 216)
			ft.size = Vector2(w, 40)
			ft.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			menu.add_child(ft)
			var sc := _label(str(info.get("score", "")), 120, Color.WHITE)
			sc.add_theme_constant_override("outline_size", 16)
			sc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
			sc.position = Vector2(0, h * 0.5 - 188)
			sc.size = Vector2(w, 130)
			sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sc.pivot_offset = Vector2(w * 0.5, 65)
			menu.add_child(sc)
			var tn := _label(t_names[0], 22, t_cols[0].lightened(0.45), font2)
			tn.position = Vector2(0, h * 0.5 - 142)
			tn.size = Vector2(w * 0.5 - 190, 30)
			tn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(tn)
			var tn2 := _label(t_names[1], 22, t_cols[1].lightened(0.45), font2)
			tn2.position = Vector2(w * 0.5 + 190, h * 0.5 - 142)
			menu.add_child(tn2)
			for gi in 2:
				var gl := _label(str(info.get("g%d" % gi, "")), 17, Color(1, 1, 1, 0.85), font2)
				gl.position = Vector2(0 if gi == 0 else w * 0.5 + 190, h * 0.5 - 114)
				gl.clip_text = true
				gl.size = Vector2(w * 0.5 - 190, 22)
				gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if gi == 0 else HORIZONTAL_ALIGNMENT_LEFT
				menu.add_child(gl)
			var rs := _label(str(info.get("result", "")), 40, GREEN.lightened(0.35) if str(info.get("result", "")).begins_with("YOU WIN") else Color.WHITE)
			rs.position = Vector2(0, h * 0.5 - 56)
			rs.size = Vector2(w, 50)
			rs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			menu.add_child(rs)
			var srows: Array = info.get("stats", [])
			var sy := h * 0.5 + 62.0
			var sp := Panel.new()
			sp.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.72), 14))
			sp.position = Vector2(w * 0.5 - 230, sy - 8)
			sp.size = Vector2(460, srows.size() * 24.0 + 18)
			sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu.add_child(sp)
			for r in srows:
				var l1 := _label(str(r[1]), 18, Color.WHITE)
				l1.position = Vector2(w * 0.5 - 200, sy)
				l1.size = Vector2(80, 24)
				l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				menu.add_child(l1)
				var l2 := _label(str(r[0]), 17, Color(1, 1, 1, 0.7), font2)
				l2.position = Vector2(w * 0.5 - 100, sy + 2)
				l2.size = Vector2(200, 24)
				l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				menu.add_child(l2)
				var l3 := _label(str(r[2]), 18, Color.WHITE)
				l3.position = Vector2(w * 0.5 + 120, sy)
				menu.add_child(l3)
				sy += 24.0
			var pxb: Dictionary = info.get("pxp", {})
			if not pxb.is_empty():
				_xp_panel(pxb, Vector2(24, h * 0.5 + 54), anim)
			if anim:
				sc.scale = Vector2(2.6, 2.6)
				sc.modulate.a = 0.0
				var tw := sc.create_tween()
				tw.set_parallel(true)
				tw.tween_property(sc, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(sc, "modulate:a", 1.0, 0.2)
			items.append([rs, Vector2(0, 40), 0.35])
			var by2 := h - 84.0
			var cls: Array = info.get("car_lines", [])
			var co_car := bool(info.get("career", false)) and bool(info.get("online", false))
			if bool(info.get("rk", false)):
				var nr := _btn("NEXT OPPONENT", "rk_next", null, "primary", Vector2(w * 0.5 - 320, by2), Vector2(300, 70), 28)
				var mr := _btn("MAIN MENU", "menu", null, "alt", Vector2(w * 0.5 + 20, by2), Vector2(300, 70), 24)
				menu.add_child(nr)
				menu.add_child(mr)
				items.append([nr, Vector2(0, 60), 0.5])
				items.append([mr, Vector2(0, 60), 0.58])
			elif str(info.get("role", "")) == "guest":
				if bool(info.get("has_cv", false)):
					var avb := _btn("BACK TO THE CAREER", "co_back", null, "primary", Vector2(w * 0.5 - 320, by2), Vector2(300, 70), 24)
					menu.add_child(avb)
					items.append([avb, Vector2(0, 60), 0.45])
				else:
					var wt := _label("Waiting for the host...", 20, Color(1, 1, 1, 0.8), font2)
					wt.position = Vector2(w * 0.5 - 330, by2 + 22)
					menu.add_child(wt)
				var mb := _btn("MAIN MENU", "menu", null, "alt", Vector2(w * 0.5 + 20, by2), Vector2(300, 70), 24)
				menu.add_child(mb)
				items.append([mb, Vector2(0, 60), 0.5])
			elif bool(info.get("career", false)) and not co_car:
				var cn := _btn("CONTINUE", "career", null, "primary", Vector2(w * 0.5 - 170, by2), Vector2(340, 70), 30)
				menu.add_child(cn)
				items.append([cn, Vector2(0, 60), 0.5])
			else:
				var ag := _btn("BACK TO THE CAREER" if co_car and bool(info.get("co_car", false)) else ("NEXT MATCH" if co_car else "PLAY AGAIN"), "co_back" if co_car and bool(info.get("co_car", false)) else "again", null, "primary", Vector2(w * 0.5 - 320, by2), Vector2(300, 70), 24 if co_car else 30)
				var mb2 := _btn("MAIN MENU", "menu", null, "alt", Vector2(w * 0.5 + 20, by2), Vector2(300, 70), 24)
				menu.add_child(ag)
				menu.add_child(mb2)
				items.append([ag, Vector2(0, 60), 0.5])
				items.append([mb2, Vector2(0, 60), 0.58])
			if not cls.is_empty():
				# the most important news first: coins, the gate, a youth talent, the table, then who grew
				var pri := []
				for pass2 in 4:
					for cl2 in cls:
						var t2 := str(cl2)
						var kind2 := 0 if t2.begins_with("+") else (1 if t2.begins_with("YOUTH") else (2 if t2.contains("IN THE TABLE") or t2.begins_with("SEASON") or t2.begins_with("THE BOARD") else 3))
						if kind2 == pass2:
							pri.append(t2)
				var rows3 := [[], []]
				var widths := [0.0, 0.0]
				var more := 0
				for t3 in pri:
					var tw3: float = font.get_string_size(t3 + "     ·     ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
					var put := false
					for ri3 in 2:
						if widths[ri3] + tw3 < w - 120.0:
							rows3[ri3].append(t3)
							widths[ri3] += tw3
							put = true
							break
					if not put:
						more += 1
				if more > 0:
					rows3[1].append("+%d MORE" % more)
				for ri4 in 2:
					if rows3[ri4].is_empty():
						continue
					var cll := _label("     ·     ".join(PackedStringArray(rows3[ri4])), 18, GOLD)
					cll.position = Vector2(0, h * 0.5 + 10 + ri4 * 22)
					cll.size = Vector2(w, 22)
					cll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					menu.add_child(cll)
	if n in ["friend", "join", "lobby"]:
		var back := _back("back", null)
		menu.add_child(back)
	if anim:
		for it in items:
			_slide_in(it[0], it[1], it[2])

# The player career at full time: your rating, and the XP bar filling up. A new level gets a little party.
func _xp_panel(xb: Dictionary, at: Vector2, anim: bool) -> void:
	var pw := 320.0
	var ph := 118.0
	var pn := Panel.new()
	pn.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.82), 14, Color(1, 1, 1, 0.14)))
	pn.position = at
	pn.size = Vector2(pw, ph)
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(pn)
	var lv0 := int(xb.get("lv0", 1))
	var lv1 := int(xb.get("lv1", lv0))
	var f0 := clampf(float(xb.get("x0", 0)) / maxf(float(xb.get("n0", 100)), 1.0), 0.0, 1.0)
	var f1 := clampf(float(xb.get("x1", 0)) / maxf(float(xb.get("n1", 100)), 1.0), 0.0, 1.0)
	var rt := float(xb.get("rt", -1.0))
	var rl := _label(("MY RATING  %.1f" % rt) if rt >= 0.0 else "DID NOT PLAY", 18, (GREEN if rt >= 7.0 else (GOLD if rt >= 6.0 else Color(0.95, 0.45, 0.35))) if rt >= 0.0 else Color(1, 1, 1, 0.6), font3)
	rl.position = Vector2(16, 10)
	pn.add_child(rl)
	var lvl := _label("LEVEL %d" % lv0, 22, Color.WHITE)
	lvl.position = Vector2(16, 38)
	pn.add_child(lvl)
	var gain := _label("", 18, GOLD, font3)
	gain.position = Vector2(pw - 140, 42)
	gain.size = Vector2(124, 24)
	gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pn.add_child(gain)
	var bw := pw - 32.0
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.12)
	bg.position = Vector2(16, 78)
	bg.size = Vector2(bw, 14)
	pn.add_child(bg)
	var fill := ColorRect.new()
	fill.color = GOLD
	fill.position = Vector2(16, 78)
	fill.size = Vector2(bw * (f0 if anim else f1), 14)
	pn.add_child(fill)
	var nx := _label("%d / %d XP" % [int(xb.get("x1", 0)), int(xb.get("n1", 100))], 16, Color(1, 1, 1, 0.65), font2)
	nx.position = Vector2(16, 94)
	pn.add_child(nx)
	var xp_gain := (int(xb.get("x1", 0)) - int(xb.get("x0", 0))) if lv1 == lv0 else (int(xb.get("n0", 100)) - int(xb.get("x0", 0)) + int(xb.get("x1", 0)))
	gain.text = "+%d XP" % maxi(xp_gain, 0)
	if not anim:
		lvl.text = "LEVEL %d" % lv1
		return
	var tw := fill.create_tween()
	tw.tween_interval(0.9)
	if lv1 > lv0:
		tw.tween_property(fill, "size:x", bw, 0.7).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func():
			_level_party(pn, lvl, lv1, pw)
			fill.size.x = 0.0)
		tw.tween_interval(0.35)
	tw.tween_property(fill, "size:x", bw * f1, 0.8).set_ease(Tween.EASE_OUT)

func _level_party(pn: Panel, lvl: Label, lv: int, pw: float) -> void:
	lvl.text = "LEVEL %d" % lv
	lvl.add_theme_color_override("font_color", GOLD)
	pn.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.9), 14, GOLD))
	var up := _label("LEVEL UP!", 34, GOLD)
	up.add_theme_constant_override("outline_size", 10)
	up.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	up.position = Vector2(0, 26)
	up.size = Vector2(pw, 44)
	up.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up.pivot_offset = Vector2(pw * 0.5, 22)
	up.scale = Vector2(0.2, 0.2)
	pn.add_child(up)
	var t1 := up.create_tween()
	t1.tween_property(up, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t1.tween_interval(1.6)
	t1.tween_property(up, "modulate:a", 0.0, 0.4)
	var cols := [GOLD, GREEN, Color.WHITE, Color(0.4, 0.75, 1.0)]
	for i in 18:
		# a little burst of confetti from the bar
		var cf := ColorRect.new()
		cf.color = cols[i % cols.size()]
		cf.size = Vector2(7, 7)
		cf.position = Vector2(pw * 0.5 + randf_range(-40, 40), 80)
		cf.rotation = randf() * TAU
		cf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pn.add_child(cf)
		var t2 := cf.create_tween()
		t2.set_parallel(true)
		var to := cf.position + Vector2(randf_range(-170, 170), randf_range(-150, -60))
		t2.tween_property(cf, "position", to, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		t2.tween_property(cf, "rotation", cf.rotation + randf_range(-6, 6), 0.9)
		t2.tween_property(cf, "modulate:a", 0.0, 0.9).set_delay(0.4)
	if get_parent() != null and get_parent().has_method("snd"):
		get_parent().snd("cheer")

# ---------------------------------------------------------------- scouting and the youth academy
func _youth_page(info: Dictionary, w: float, h: float, items: Array) -> void:
	var c: Dictionary = info.get("car", {})
	var y: Dictionary = c.get("yth", {})
	_title("Youth academy", "Scouts find young players. Their real level is hidden: a better scout tells you more.")
	menu.add_child(_back("tab", "club"))
	if y.is_empty():
		return
	var tab := int(y.get("tab", 0))
	var pr: Array = y.get("pros", [])
	var ac: Array = y.get("acad", [])
	var names3 := ["Scouts", "Reports (%d)" % pr.size(), "Academy (%d/%d)" % [ac.size(), int(y.get("amax", 6))]]
	var tw := 220.0
	var tx := w * 0.5 - (tw * 3 + 20) * 0.5
	for k in 3:
		menu.add_child(_btn(names3[k].to_upper(), "y_tab", k, "primary" if k == tab else "alt", Vector2(tx + k * (tw + 10), 100), Vector2(tw, 46), 18))
	var y0 := 160.0
	var msg := str(c.get("msg", ""))
	if msg != "":
		var ml := _label(msg, 18, GOLD, font3)
		ml.position = Vector2(24, h - 34)
		ml.size = Vector2(w - 48, 26)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu.add_child(ml)
	if tab == 0:
		var sc: Array = y.get("scouts", [])
		var hire: Array = y.get("hire", [])
		var cw := (w - 48 - 16) * 0.5
		for i in sc.size():
			var e: Dictionary = sc[i]
			var x := 24.0 + i * (cw + 16)
			var pn := _card_panel(Vector2(x, y0), Vector2(cw, h - y0 - 44))
			items.append([pn, Vector2(0, 40), 0.05 * i])
			if e.is_empty():
				var el := _label("No scout here yet", 24, MUT)
				el.position = Vector2(22, 20)
				pn.add_child(el)
				var eh := _label("Hire a 1-star scout and send him abroad.", 19, MUT, font3)
				eh.position = Vector2(22, 58)
				pn.add_child(eh)
				menu.add_child(_btn("HIRE A SCOUT  ·  %s" % _m(int(hire[i])), "y_hire", i, "primary", Vector2(x + 20, h - 44 - 76), Vector2(cw - 40, 56), 20))
				continue
			var nl := _label(str(e["n"]), 26, CHALK)
			nl.position = Vector2(22, 16)
			pn.add_child(nl)
			var stl := _label("★".repeat(int(e["st"])) + "☆".repeat(5 - int(e["st"])), 24, GOLD, font3)
			stl.position = Vector2(cw - 160, 18)
			stl.size = Vector2(140, 30)
			stl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pn.add_child(stl)
			var away := int(e["away"])
			var st_t := ("In %s: back in %d match%s" % [str(e["rg"]), away, "" if away == 1 else "es"]) if away > 0 else "At home, ready to travel"
			var sl := _label(st_t, 20, GREEN if away > 0 else MUT, font3)
			sl.position = Vector2(22, 56)
			pn.add_child(sl)
			var hint := _label("A better scout finds better boys and sees their potential more clearly. Brazil and Argentina have the biggest talents, and the biggest surprises.", 18, MUT, font3)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD
			hint.position = Vector2(22, 92)
			hint.size = Vector2(cw - 44, 80)
			pn.add_child(hint)
			if away == 0:
				menu.add_child(_btn("Country: %s  ›" % str(e["pick"]), "y_pick", i, "alt", Vector2(x + 20, h - 44 - 146), Vector2(cw - 40, 54), 20))
				var hw := (cw - 50) * 0.5
				menu.add_child(_btn("SEND", "y_send", i, "primary", Vector2(x + 20, h - 44 - 80), Vector2(hw, 58), 22))
				menu.add_child(_btn("%d STARS  ·  %s" % [int(e["st"]) + 1, _m(int(hire[i]))] if int(e["st"]) < 5 else "THE BEST", "y_hire", i, "alt" if int(e["st"]) < 5 else "off", Vector2(x + 30 + hw, h - 44 - 80), Vector2(hw, 58), 17))
		return
	var rows: Array = pr if tab == 1 else ac
	if rows.is_empty():
		var el2 := _label("No reports yet: send a scout abroad. He reports after every match." if tab == 1 else "The academy is empty. Sign boys from the reports, and the youth facility sends a local talent twice a season.", 22, MUT, font3)
		el2.autowrap_mode = TextServer.AUTOWRAP_WORD
		el2.position = Vector2(80, y0 + 60)
		el2.size = Vector2(w - 160, 100)
		el2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu.add_child(el2)
		return
	var sc2 := ScrollContainer.new()
	sc2.position = Vector2(24, y0)
	sc2.size = Vector2(w - 48, h - y0 - 40)
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(sc2)
	var box := Control.new()
	var rh := 70.0
	box.custom_minimum_size = Vector2(w - 60, rows.size() * (rh + 8))
	sc2.add_child(box)
	for i in rows.size():
		var r: Dictionary = rows[i]
		var ry := i * (rh + 8)
		var pn2 := Panel.new()
		pn2.add_theme_stylebox_override("panel", _box(Color(S1.r, S1.g, S1.b, 0.95), 12, GOLD if int(r["phi"]) >= 86 else LINE))
		pn2.position = Vector2(0, ry)
		pn2.size = Vector2(w - 60, rh)
		pn2.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(pn2)
		var n1 := _label("%s  %s" % [r["pos"], r["n"]], 22, CHALK)
		n1.position = Vector2(18, 8)
		n1.clip_text = true
		n1.size = Vector2(300, 30)
		pn2.add_child(n1)
		var ab3: Array = r.get("ab", [])
		var sub := "Age %d  ·  %s" % [int(r["age"]), r["rg"]] + (("  ·  " + str(ab3[0][1]).capitalize()) if not ab3.is_empty() else "")
		if tab == 1:
			sub += "  ·  gone in %d" % int(r["exp"])
		var n2 := _label(sub, 17, MUT, font3)
		n2.position = Vector2(18, 40)
		n2.clip_text = true
		n2.size = Vector2(320, 24)
		pn2.add_child(n2)
		var ov := _label(("Rating %d" % int(r["olo"])) if int(r["olo"]) == int(r["ohi"]) else ("Rating %d-%d" % [int(r["olo"]), int(r["ohi"])]), 20, CHALK, font3)
		ov.position = Vector2(340, 22)
		pn2.add_child(ov)
		var known := int(r["plo"]) == int(r["phi"])
		var pt := ("Can reach %d" % int(r["phi"])) if known else ("Can reach %d-%d" % [int(r["plo"]), int(r["phi"])])
		var pl2 := _label(pt, 22, GOLD if int(r["phi"]) >= 86 else GREEN, font3)
		pl2.position = Vector2(500, 20)
		pn2.add_child(pl2)
		if int(r["phi"]) >= 86:
			var wk := _label("Wonderkid?" if not known else "Wonderkid", 17, GOLD, font3)
			wk.position = Vector2(500, 46)
			pn2.add_child(wk)
		var bx := w - 60 - 330.0
		if tab == 1:
			box.add_child(_btn("SIGN  ·  %s" % _m(int(r["fee"])), "y_sign", i, "primary", Vector2(bx, ry + 10), Vector2(200, rh - 20), 18))
			box.add_child(_btn("NO", "y_drop", i, "ghost", Vector2(bx + 210, ry + 10), Vector2(110, rh - 20), 18))
		else:
			var full := int(y.get("sq", 0)) >= int(y.get("sqmax", 19))
			box.add_child(_btn("PROMOTE", "y_prom", i, "alt" if full else "primary", Vector2(bx, ry + 10), Vector2(200, rh - 20), 18))
			box.add_child(_btn("RELEASE", "y_rel", i, "ghost", Vector2(bx + 210, ry + 10), Vector2(110, rh - 20), 18))

# ---------------------------------------------------------------- the career's calendar, a simulated match, the days between matches
const MONTHS3 := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

func _cal_page(info: Dictionary, w: float, h: float, items: Array) -> void:
	var c: Dictionary = info.get("car", {})
	var cal: Array = c.get("cal", [])
	_title("Calendar", "Season %d  ·  %s" % [int(c.get("season", 1)), str(c.get("lgname", "")).capitalize()])
	menu.add_child(_back("tab", "career"))
	if cal.is_empty():
		return
	# the month of your next match (or the last one), moved by the arrows
	var base: Dictionary = cal[cal.size() - 1]
	for e in cal:
		if bool(e["next"]):
			base = e
			break
	var mi := int(base["y"]) * 12 + int(base["m"]) - 1 + int(c.get("cal_m", 0))
	var yy := mi / 12
	var mm := mi % 12 + 1
	var by_day := {}
	for e in cal:
		by_day["%d-%d-%d" % [int(e["y"]), int(e["m"]), int(e["d"])]] = e
	var gw := w * 0.62
	var gx := 24.0
	var hy := 96.0
	var prev := _btn("", "cal", -1, "ghost", Vector2(gx, hy), Vector2(48, 40), 18)
	var nextb := _btn("", "cal", 1, "ghost", Vector2(gx + gw - 48, hy), Vector2(48, 40), 18)
	for k in 2:
		var bb: Button = [prev, nextb][k]
		var ch2 := Control.new()
		ch2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ch2.position = Vector2(18, 10)
		ch2.size = Vector2(12, 20)
		var flip := k == 1
		ch2.draw.connect(func():
			var pts := PackedVector2Array([Vector2(10, 1), Vector2(2, 10), Vector2(10, 19)]) if not flip else PackedVector2Array([Vector2(2, 1), Vector2(10, 10), Vector2(2, 19)])
			ch2.draw_polyline(pts, CHALK, 3.0, true))
		bb.add_child(ch2)
		menu.add_child(bb)
	var ml := _label("%s %d" % [MONTHS3[mm - 1], yy], 26, CHALK)
	ml.position = Vector2(gx, hy + 2)
	ml.size = Vector2(gw, 36)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(ml)
	var u0 := int(Time.get_unix_time_from_datetime_dict({"year": yy, "month": mm, "day": 1, "hour": 12}))
	var wd0 := (int(Time.get_datetime_dict_from_unix_time(u0)["weekday"]) + 6) % 7 # Monday = 0
	var ndays := 0
	for dd in range(28, 32):
		var t := Time.get_datetime_dict_from_unix_time(u0 + (dd - 1) * 86400)
		if int(t["month"]) == mm:
			ndays = dd
	var nrows := int(ceil((wd0 + ndays) / 7.0))
	var gy := hy + 48.0
	for k in 7:
		var wl := _label(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][k], 17, MUT, font3)
		wl.position = Vector2(gx + k * gw / 7.0, gy)
		wl.size = Vector2(gw / 7.0, 22)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu.add_child(wl)
	gy += 26.0
	var cw := gw / 7.0
	var chh := minf((h - gy - 16.0) / nrows, 76.0)
	var td: Array = c.get("tdate", [0, 0, 0])
	for dd in range(1, ndays + 1):
		var slot := wd0 + dd - 1
		var cx := gx + (slot % 7) * cw
		var cy := gy + (slot / 7) * chh
		var e: Dictionary = by_day.get("%d-%d-%d" % [yy, mm, dd], {})
		var is_today: bool = int(td[0]) == yy and int(td[1]) == mm and int(td[2]) == dd
		var bg := Color(S1.r, S1.g, S1.b, 0.9)
		var bc := LINE
		if not e.is_empty():
			bg = Color(0.16, 0.14, 0.05, 0.95) if str(e["kind"]) == "cup" else (Color(0.06, 0.1, 0.2, 0.95) if str(e["kind"]) == "eu" else (Color(0.2, 0.07, 0.07, 0.95) if str(e["kind"]) == "nat" else S2))
			if bool(e["next"]):
				bc = GOLD
		var cell := Panel.new()
		cell.add_theme_stylebox_override("panel", _box(bg, 8, bc))
		cell.position = Vector2(cx + 2, cy + 2)
		cell.size = Vector2(cw - 4, chh - 4)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu.add_child(cell)
		var dl := _label(str(dd), 16, GOLD if is_today else (CHALK if not e.is_empty() else MUT), font3)
		dl.position = Vector2(7, 3)
		cell.add_child(dl)
		if is_today and (e.is_empty() or (e["res"] as Array).is_empty()):
			var tdl := _label("today", 16, GOLD, font3)
			tdl.position = Vector2(0, 3)
			tdl.size = Vector2(cw - 12, 20)
			tdl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cell.add_child(tdl)
		if e.is_empty():
			continue
		var kit: Array = e["ok"]
		var strip := ColorRect.new()
		strip.color = Color("#" + str(kit[0])) if kit.size() > 0 else Color.GRAY
		strip.position = Vector2(6, chh - 30)
		strip.size = Vector2(4, 20)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(strip)
		var ol := _label(("" if bool(e["home"]) or str(e["kind"]) in ["cup", "nat"] else "@") + str(e["os"]), 18, CHALK)
		ol.position = Vector2(14, chh - 34)
		ol.clip_text = true
		ol.size = Vector2(cw - 18, 26)
		cell.add_child(ol)
		var res: Array = e["res"]
		if res.size() == 2:
			var rc := GREEN if int(res[0]) > int(res[1]) else (Color(0.92, 0.36, 0.33) if int(res[0]) < int(res[1]) else MUT)
			var rl := _label("%d-%d" % [int(res[0]), int(res[1])], 17, rc, font3)
			rl.position = Vector2(0, 3)
			rl.size = Vector2(cw - 12, 20)
			rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cell.add_child(rl)
		elif str(e["kind"]) in ["cup", "eu"]:
			var ci := _icon("cup", 18, GOLD if str(e["kind"]) == "cup" else EUBLUE)
			ci.position = Vector2(cw - 28, 4)
			cell.add_child(ci)
	# the right column: what comes next
	var rx := gx + gw + 18.0
	var rw := w - rx - 24.0
	var pn := _card_panel(Vector2(rx, hy), Vector2(rw, h - hy - 16.0))
	items.append([pn, Vector2(60, 0), 0.05])
	var hl := _label("Coming up", 22, GOLD, font3)
	hl.position = Vector2(18, 12)
	pn.add_child(hl)
	var y2 := 48.0
	var shown := 0
	for e in cal:
		if bool(e["played"]) or shown >= 6:
			continue
		var l1 := _label(str(e["date"]) + "  ·  " + ("Cup, " + str(e["name"]).to_lower() if str(e["kind"]) == "cup" else (("Europe, " + str(e["name"]).to_lower()) if str(e["kind"]) == "eu" else (("Country v %s, " % str(e["os"]) + str(e["name"]).to_lower()) if str(e["kind"]) == "nat" else ("Home" if bool(e["home"]) else "Away")))), 17, GOLD if bool(e["next"]) else MUT, font3)
		l1.position = Vector2(18, y2)
		l1.clip_text = true
		l1.size = Vector2(rw - 36, 22)
		pn.add_child(l1)
		var l2 := _label(str(e["opp"]).capitalize() if str(e["opp"]) != "" else "Drawn after the last round", 20, CHALK, font3)
		l2.position = Vector2(18, y2 + 21)
		l2.clip_text = true
		l2.size = Vector2(rw - 36, 26)
		pn.add_child(l2)
		y2 += 56.0
		shown += 1
	if shown == 0:
		var nl := _label("The season is over.", 20, CHALK, font3)
		nl.position = Vector2(18, y2)
		pn.add_child(nl)

func _sim_page(info: Dictionary, w: float, h: float, items: Array, anim: bool) -> void:
	var sr: Dictionary = (info.get("car", {}) as Dictionary).get("sim", {})
	if sr.is_empty():
		return
	_title(str(sr.get("what", "")), str(sr.get("date", "")) + "  ·  simulated")
	var goals: Array = sr.get("goals", [])
	var home := bool(sr.get("home", true))
	var ks := 92.0
	var cy := 120.0
	for si in 2:
		var cx := w * (0.28 if si == 0 else 0.72)
		var sh := _shirt(sr.get("ka" if si == 0 else "kb", ["888888"]), ks)
		sh.position = Vector2(cx - ks * 0.5, cy)
		menu.add_child(sh)
		var nl := _label(str(sr.get("a" if si == 0 else "b", "")).capitalize(), 26, CHALK)
		nl.position = Vector2(cx - 220, cy + ks + 6)
		nl.size = Vector2(440, 34)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu.add_child(nl)
	var sc := _label("0 - 0", 84, Color.WHITE)
	sc.position = Vector2(w * 0.5 - 160, cy - 4)
	sc.size = Vector2(320, 100)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(sc)
	var mn := _label("0'", 28, GOLD)
	mn.position = Vector2(w * 0.5 - 100, cy + 96)
	mn.size = Vector2(200, 36)
	mn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(mn)
	# who scored, under each club, in the order they come
	var gl := [_label("", 19, MUT, font3), _label("", 19, MUT, font3)]
	for si in 2:
		var lb: Label = gl[si]
		lb.position = Vector2(w * (0.28 if si == 0 else 0.72) - 220, cy + ks + 42)
		lb.size = Vector2(440, 90)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD
		menu.add_child(lb)
	var tail := _label("", 22, CHALK, font3)
	tail.position = Vector2(60, h - 168)
	tail.size = Vector2(w - 120, 64)
	tail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tail.autowrap_mode = TextServer.AUTOWRAP_WORD
	menu.add_child(tail)
	var lines: Array = sr.get("lines", [])
	var lt := ""
	for k in mini(3, lines.size()):
		lt += ("" if lt == "" else "   ·   ") + str(lines[k])
	var mine := int(sr.get("mine", 0))
	var theirs := int(sr.get("theirs", 0))
	var pens := str(sr.get("pens", ""))
	var show_at := func(v: float):
		var g := [0, 0]
		var txt := ["", ""]
		for gg in goals:
			if float(gg[0]) <= v:
				var side := int(gg[1]) # 0 = you
				var col := side if home else 1 - side
				g[col] += 1
				var who := str(gg[2]).capitalize() if side == 0 and str(gg[2]) != "" else "Goal"
				txt[col] += ("" if txt[col] == "" else ", ") + "%s %d'" % [who, int(gg[0])]
		sc.text = "%d - %d" % [g[0], g[1]]
		mn.text = ("%d'" % int(v)) if v < 90.0 else "Full time"
		gl[0].text = txt[0]
		gl[1].text = txt[1]
		if v >= 90.0:
			var verdict := "You won" if mine > theirs else ("You lost" if mine < theirs else "A draw")
			if pens != "":
				verdict = pens
			tail.text = verdict + ("   ·   " + lt if lt != "" else "")
	var cb := _btn("CONTINUE", "career", null, "primary", Vector2(w * 0.5 - 170, h - 92), Vector2(340, 70), 30)
	menu.add_child(cb)
	if anim:
		cb.modulate.a = 0.0
		var tw := menu.create_tween()
		tw.tween_method(show_at, 0.0, 90.0, 3.4)
		tw.tween_property(cb, "modulate:a", 1.0, 0.25)
	else:
		show_at.call(90.0)

func _adv_page(info: Dictionary, w: float, h: float, anim: bool) -> void:
	var av: Dictionary = (info.get("car", {}) as Dictionary).get("adv", {})
	if av.is_empty():
		return
	var days: Array = av.get("days", [])
	var news: Array = av.get("news", [])
	# a tear-off calendar page that runs through the days
	var pw := 300.0
	var pg := _card_panel(Vector2(48, 60), Vector2(pw, h - 200))
	var top := ColorRect.new()
	top.color = Color(0.86, 0.22, 0.2)
	top.position = Vector2(0, 0)
	top.size = Vector2(pw, 54)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pg.add_child(top)
	var mo := _label("", 26, Color.WHITE)
	mo.position = Vector2(0, 8)
	mo.size = Vector2(pw, 40)
	mo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pg.add_child(mo)
	var dn := _label("", 140, CHALK)
	dn.position = Vector2(0, 60)
	dn.size = Vector2(pw, 170)
	dn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pg.add_child(dn)
	var wd := _label("", 30, MUT)
	wd.position = Vector2(0, h - 200 - 60)
	wd.size = Vector2(pw, 40)
	wd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pg.add_child(wd)
	var full_wd := {"Sun": "Sunday", "Mon": "Monday", "Tue": "Tuesday", "Wed": "Wednesday", "Thu": "Thursday", "Fri": "Friday", "Sat": "Saturday"}
	var show_day := func(v: float):
		if days.is_empty():
			return
		var dd: Array = days[clampi(int(v), 0, days.size() - 1)]
		mo.text = str(dd[2])
		dn.text = str(dd[0])
		wd.text = str(full_wd.get(str(dd[1]), dd[1]))
	# the news of those days, one by one
	var nx := 48.0 + pw + 32.0
	var nw := w - nx - 48.0
	var step := bool(av.get("step", false))
	var hl := _label(("Match day" if bool(av.get("mday", false)) else "Today") if step else "While the days go by", 26, CHALK)
	hl.position = Vector2(nx, 60)
	menu.add_child(hl)
	var icons := {"result": "play", "table": "table", "cup": "cup", "market": "swap", "board": "board", "deal": "swap", "bid": "mail", "window": "cal", "med": "plus"}
	var rows := []
	for k in news.size():
		var it: Array = news[k]
		var ry := 104.0 + k * 50.0
		var row := _card_panel(Vector2(nx, ry), Vector2(nw, 44))
		var ic := _icon(str(icons.get(str(it[0]), "play")), 24, GOLD if str(it[0]) in ["cup", "bid", "window"] else (Color(0.95, 0.45, 0.4) if str(it[0]) == "med" else MUT))
		ic.position = Vector2(14, 10)
		row.add_child(ic)
		var tl := _label(str(it[1]), 20, CHALK, font3)
		tl.position = Vector2(52, 8)
		tl.clip_text = true
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tl.size = Vector2(nw - 66, 28)
		row.add_child(tl)
		rows.append(row)
	var nl := _label("Next: " + str(av.get("ndate", "")) + "  ·  " + str(av.get("next", "")), 22, GOLD, font3)
	nl.position = Vector2(48, h - 118)
	nl.clip_text = true
	nl.size = Vector2(w - 96, 30)
	menu.add_child(nl)
	var cb := _btn("CONTINUE", "adv_done", null, "primary", Vector2(w * 0.5 - 170, h - 86), Vector2(340, 70), 30)
	if step:
		# FIFA: tap on through the days, or go back to the club
		cb = _btn("BACK TO THE CLUB", "adv_done", null, "alt", Vector2(w * 0.5 - 360, h - 86), Vector2(340, 70), 24)
		if not bool(av.get("mday", false)):
			var ab := _btn("ADVANCE  ›", "c_adv", null, "primary", Vector2(w * 0.5 + 20, h - 86), Vector2(340, 70), 30)
			menu.add_child(ab)
		else:
			cb = _btn("MATCH DAY  ›", "adv_done", null, "primary", Vector2(w * 0.5 - 170, h - 86), Vector2(340, 70), 30)
	menu.add_child(cb)
	if anim and days.size() > 1:
		var dur := clampf(days.size() * 0.16, 0.8, 2.6)
		show_day.call(0.0)
		var tw := menu.create_tween()
		tw.tween_method(show_day, 0.0, float(days.size() - 1), dur)
		for k in rows.size():
			var r: Control = rows[k]
			r.modulate.a = 0.0
			var t2 := menu.create_tween()
			t2.tween_interval(0.2 + dur * (k + 1.0) / (rows.size() + 1.0))
			t2.tween_property(r, "modulate:a", 1.0, 0.25)
		nl.modulate.a = 0.0
		var t3 := menu.create_tween()
		t3.tween_interval(dur)
		t3.tween_property(nl, "modulate:a", 1.0, 0.3)
	else:
		show_day.call(float(days.size() - 1))

# ---------------------------------------------------------------- the hub: one home screen with five tabs

# A big button with a title and a line of small text under it.
# The Play tab: the ways to play, side by side and all the same size. The career is one of them.
# A rank badge: a shield in the rank's colours with the division on it.
func _rk_badge(parent: Control, pos: Vector2, sz: float, rk: Dictionary) -> void:
	var c := Color(str(rk.get("c", "d9955a")))
	var c2 := Color(str(rk.get("c2", "6e3f1c")))
	var dv := int(rk.get("dv", 0))
	var t := int(rk.get("t", 0))
	var dc := Control.new()
	dc.position = pos
	dc.size = Vector2(sz, sz * 1.16)
	dc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dc.draw.connect(func():
		var u := sz / 100.0
		var outer := PackedVector2Array([Vector2(50, 8), Vector2(92, 22), Vector2(88, 64), Vector2(76, 88), Vector2(50, 108), Vector2(24, 88), Vector2(12, 64), Vector2(8, 22)])
		var inner := PackedVector2Array([Vector2(50, 17), Vector2(83, 28), Vector2(80, 62), Vector2(70, 82), Vector2(50, 97), Vector2(30, 82), Vector2(20, 62), Vector2(17, 28)])
		for i in outer.size():
			outer[i] *= u
			inner[i] *= u
		dc.draw_colored_polygon(outer, c2)
		dc.draw_colored_polygon(inner, c)
		var hi := PackedVector2Array([inner[0], inner[1], Vector2(81, 48) * u, Vector2(19, 48) * u, inner[7]])
		dc.draw_colored_polygon(hi, Color(1, 1, 1, 0.18))
		# stars for the higher ranks
		var ns := 0 if t >= 5 else t
		for si in ns:
			var sx := 50.0 + (si - (ns - 1) * 0.5) * 15.0
			var sp := PackedVector2Array()
			for k in 10:
				var an := -PI * 0.5 + k * PI / 5.0
				var rr := (7.0 if k % 2 == 0 else 3.2) * u
				sp.append(Vector2(sx * u + cos(an) * rr, 32.0 * u + sin(an) * rr))
			dc.draw_colored_polygon(sp, Color(1.0, 0.97, 0.84))
			sp.append(sp[0])
			dc.draw_polyline(sp, c2, maxf(1.0, 1.4 * u), true)
		var txt := "I".repeat(3 - dv) if dv >= 0 else "L"
		var fs := int(30 * u)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		dc.draw_string(font, Vector2(50 * u - tw * 0.5, 74 * u), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c2)
	)
	parent.add_child(dc)

func _tile(title: String, sub: String, act: String, arg, pos: Vector2, sz: Vector2, col := Color.WHITE, fs := 26) -> Button:
	var b := _btn("", act, arg, "alt", pos, sz, fs)
	var t := _label(title, fs, col)
	t.position = Vector2(20, sz.y * 0.5 - (fs * 0.5 + (13 if sub != "" else 0)) - 4)
	t.size = Vector2(sz.x - 40, fs + 10)
	b.add_child(t)
	if sub != "":
		var s := _label(sub, 17, Color(1, 1, 1, 0.72), font2)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD
		s.position = Vector2(20, sz.y * 0.5 + fs * 0.5 - 8)
		s.size = Vector2(sz.x - 40, 40)
		b.add_child(s)
	var ar := _label(">", 24, Color(1, 1, 1, 0.45))
	ar.position = Vector2(sz.x - 34, sz.y * 0.5 - 18)
	b.add_child(ar)
	return b

func _panel(pos: Vector2, sz: Vector2, a := 0.86) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _box(Color(0.082, 0.188, 0.122, maxf(a, 0.92)), 16, Color(0.918, 0.949, 0.925, 0.13)))
	p.position = pos
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(p)
	return p

# ---------------------------------------------------------------- the hub (front page and the career's menus)
# One layout everywhere: a rail on the left with the five places, a header with the place's name and your
# money, and big cards with at most one short line each. One green button per screen: the thing you came for.
const RAIL_W := 112.0
const S1 := Color(0.082, 0.188, 0.122)
const EUBLUE := Color(0.42, 0.66, 1.0)
const S2 := Color(0.114, 0.239, 0.161)
const CHALK := Color(0.918, 0.949, 0.925)
const MUT := Color(0.576, 0.671, 0.616)
const LINE := Color(0.918, 0.949, 0.925, 0.13)

# a card you can tap: the surface colour, a soft edge, and a coloured strip on the left when it has a colour
func _card(act: String, arg, pos: Vector2, sz: Vector2, edge := Color(0, 0, 0, 0)) -> Button:
	var b := _btn("", act, arg, "alt", pos, sz, 20)
	for st in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, _box(Color(S1.r, S1.g, S1.b, 0.97), 16, LINE))
	b.add_theme_stylebox_override("pressed", _box(S2, 16, LINE))
	if edge.a > 0.0:
		var e := ColorRect.new()
		e.color = edge
		e.position = Vector2(0, 16)
		e.size = Vector2(5, sz.y - 32)
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(e)
	return b

func _card_panel(pos: Vector2, sz: Vector2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _box(Color(S1.r, S1.g, S1.b, 0.97), 16, LINE))
	p.position = pos
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(p)
	return p

# A line icon, drawn in code (24 x 24 grid, like an svg): play, team, club, shop, me, cup, shield, duo, ladder, office, swap, board, table, plus
func _icon(kind: String, sz: float, col: Color) -> Control:
	var c := Control.new()
	c.size = Vector2(sz, sz)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var u := sz / 24.0
		var wdt := maxf(1.6, 2.1 * u)
		var pl := func(pts: Array, closed := false):
			var a := PackedVector2Array()
			for p in pts:
				a.append(Vector2(p[0], p[1]) * u)
			if closed:
				a.append(a[0])
			c.draw_polyline(a, col, wdt, true)
		var circ := func(x: float, y: float, r: float):
			c.draw_arc(Vector2(x, y) * u, r * u, 0, TAU, 28, col, wdt, true)
		match kind:
			"play":
				circ.call(12, 12, 9)
				pl.call([[10, 8], [16, 12], [10, 16]], true)
			"cal":
				pl.call([[4, 6], [20, 6], [20, 20], [4, 20]], true)
				pl.call([[4, 10], [20, 10]])
				pl.call([[8, 3], [8, 7]])
				pl.call([[16, 3], [16, 7]])
				pl.call([[8, 14], [10, 14]])
				pl.call([[14, 14], [16, 14]])
				pl.call([[8, 17], [10, 17]])
			"flag":
				pl.call([[6, 21], [6, 3]])
				pl.call([[6, 4], [19, 4], [16, 8.5], [19, 13], [6, 13]])
			"sim":
				pl.call([[4, 6], [12, 12], [4, 18]], true)
				pl.call([[12, 6], [20, 12], [12, 18]], true)
			"sliders":
				pl.call([[4, 7], [20, 7]])
				pl.call([[4, 17], [20, 17]])
				circ.call(9, 7, 2.5)
				circ.call(15, 17, 2.5)
			"team":
				pl.call([[8, 4], [4, 7], [6, 10], [8, 9], [8, 20], [16, 20], [16, 9], [18, 10], [20, 7], [16, 4], [14, 6], [10, 6]], true)
			"club":
				pl.call([[3, 20], [21, 20]])
				pl.call([[5, 20], [5, 10], [12, 5], [19, 10], [19, 20]])
				pl.call([[10, 20], [10, 15], [14, 15], [14, 20]])
			"shop":
				pl.call([[5, 9], [19, 9], [18, 20], [6, 20]], true)
				c.draw_arc(Vector2(12, 9) * u, 3.5 * u, PI, TAU, 12, col, wdt, true)
			"me":
				circ.call(12, 8, 4)
				c.draw_arc(Vector2(12, 22) * u, 8 * u, PI * 1.08, PI * 1.92, 16, col, wdt, true)
			"cup":
				pl.call([[7, 4], [17, 4], [17, 9]])
				c.draw_arc(Vector2(12, 9) * u, 5 * u, 0, PI, 12, col, wdt, true)
				pl.call([[7, 4], [7, 9]])
				pl.call([[7, 6], [4, 6], [5, 9], [7, 10]])
				pl.call([[17, 6], [20, 6], [19, 9], [17, 10]])
				pl.call([[12, 14], [12, 18]])
				pl.call([[8, 20], [16, 20]])
			"shield":
				pl.call([[12, 3], [20, 6], [20, 12], [16, 18], [12, 21], [8, 18], [4, 12], [4, 6]], true)
			"duo":
				circ.call(8, 8, 3)
				circ.call(16, 8, 3)
				c.draw_arc(Vector2(8, 20) * u, 6 * u, PI * 1.1, PI * 1.9, 12, col, wdt, true)
				c.draw_arc(Vector2(16, 20) * u, 6 * u, PI * 1.1, PI * 1.9, 12, col, wdt, true)
			"ladder":
				pl.call([[4, 20], [4, 14], [8, 14], [8, 20]], true)
				pl.call([[10, 20], [10, 9], [14, 9], [14, 20]], true)
				pl.call([[16, 20], [16, 4], [20, 4], [20, 20]], true)
			"office":
				pl.call([[5, 4], [19, 4], [19, 20], [5, 20]], true)
				pl.call([[8, 9], [16, 9]])
				pl.call([[8, 13], [16, 13]])
				pl.call([[8, 17], [13, 17]])
			"mail":
				pl.call([[3, 6], [21, 6], [21, 18], [3, 18]], true)
				pl.call([[3, 6], [12, 13], [21, 6]])
			"swap":
				pl.call([[4, 8], [19, 8]])
				pl.call([[15, 4], [19, 8], [15, 12]])
				pl.call([[20, 16], [5, 16]])
				pl.call([[9, 12], [5, 16], [9, 20]])
			"table":
				pl.call([[4, 5], [20, 5], [20, 19], [4, 19]], true)
				pl.call([[4, 10], [20, 10]])
				pl.call([[4, 14.5], [20, 14.5]])
				pl.call([[9, 5], [9, 19]])
			"board":
				pl.call([[3, 17], [21, 17]])
				circ.call(12, 9, 4)
				pl.call([[6, 17], [6, 20]])
				pl.call([[18, 17], [18, 20]])
			"plus":
				circ.call(12, 12, 9)
				pl.call([[12, 7], [12, 17]])
				pl.call([[7, 12], [17, 12]])
			"build":
				pl.call([[4, 20], [20, 20]])
				pl.call([[6, 20], [6, 11], [12, 7], [18, 11], [18, 20]])
				pl.call([[12, 11], [12, 16]])
				pl.call([[9.5, 13.5], [14.5, 13.5]])
			"kit":
				pl.call([[8, 4], [4, 7], [6, 10], [8, 9], [8, 20], [16, 20], [16, 9], [18, 10], [20, 7], [16, 4], [14, 6], [10, 6]], true)
				pl.call([[8, 13], [16, 13]])
			"train":
				pl.call([[3, 12], [21, 12]])
				pl.call([[6, 8], [6, 16]])
				pl.call([[18, 8], [18, 16]])
				pl.call([[3, 10], [3, 14]])
				pl.call([[21, 10], [21, 14]])
	)
	return c

# A shirt in a club's colours (shirt, with the sleeves in the same colour; shorts colour as a trim)
func _shirt(k: Array, sz: float) -> Control:
	var c := Control.new()
	c.size = Vector2(sz, sz)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c0 := Color(str(k[0])) if k.size() > 0 else Color(0.6, 0.6, 0.6)
	var c1 := Color(str(k[1])) if k.size() > 1 else c0
	c.draw.connect(func():
		var u := sz / 40.0
		var pts := PackedVector2Array()
		for p in [[13, 4], [4, 10], [8, 17], [12, 15], [12, 36], [28, 36], [28, 15], [32, 17], [36, 10], [27, 4], [24, 7], [16, 7]]:
			pts.append(Vector2(p[0], p[1]) * u)
		c.draw_colored_polygon(pts, c0)
		var out := pts.duplicate()
		out.append(pts[0])
		c.draw_polyline(out, Color(0, 0, 0, 0.35), maxf(1.0, 1.4 * u), true)
		# the collar in the second colour
		c.draw_arc(Vector2(20, 6.5) * u, 4.2 * u, 0.15, PI - 0.15, 10, c1, maxf(1.5, 2.2 * u), true)
	)
	return c

func _hub(info: Dictionary, w: float, h: float, items: Array, anim: bool) -> void:
	var c: Dictionary = info.get("car", {})
	var tab := str(info.get("tab", "play"))
	var incar := bool(info.get("incar", false))
	var assist := bool(info.get("assist", false))
	# --- the rail: where you are and the five places
	var rail := ColorRect.new()
	rail.color = Color(0.0, 0.0, 0.0, 0.38)
	rail.position = Vector2.ZERO
	rail.size = Vector2(RAIL_W, h)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(rail)
	if incar:
		# inside the career the rail turns gold, with your club's shirt on top: you always know where you are
		var gl := ColorRect.new()
		gl.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.08)
		gl.size = Vector2(RAIL_W, h)
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu.add_child(gl)
		var sh := _shirt(c.get("kit", ["888888", "ffffff"]), 50)
		sh.position = Vector2(RAIL_W * 0.5 - 25, 10)
		menu.add_child(sh)
	else:
		var l1 := _label("PITCH", 21, CHALK)
		l1.position = Vector2(0, 10)
		l1.size = Vector2(RAIL_W, 24)
		l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu.add_child(l1)
		var slab := Panel.new()
		slab.add_theme_stylebox_override("panel", _box(GREEN, 4))
		slab.position = Vector2(RAIL_W * 0.5 - 38, 35)
		slab.size = Vector2(76, 24)
		slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu.add_child(slab)
		var l2 := _label("BOSS", 21, Color(0.02, 0.13, 0.06))
		l2.position = Vector2(0, -2)
		l2.size = Vector2(76, 26)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slab.add_child(l2)
	var tabs := [["play", "Play", "play"], ["team", "Team", "team"], ["club", "Club", "club"], ["shop", "Shop", "shop"], ["profile", "Me", "me"]]
	if incar:
		tabs = [["career", "Home", "play"], ["team", "Squad", "team"], ["transfers", "Transfers", "swap"], ["club", "Club", "club"], ["office", "Office", "office"]]
		if not (info.get("pro", {}) as Dictionary).is_empty():
			tabs = [["career", "Home", "play"], ["pro", "Player", "me"], ["league", "League", "table"], ["office", "Office", "office"]]
	var ty := 74.0
	var th := minf(84.0, (h - ty - 10.0) / 5.0)
	for i in tabs.size():
		var on: bool = tabs[i][0] == tab
		var tb := _btn("", "tab", tabs[i][0], "ghost", Vector2(10, ty + i * th), Vector2(RAIL_W - 20, th - 8), 18)
		var bgc := (GOLD if incar else CHALK) if on else Color(0, 0, 0, 0)
		var fgc := Color(0.04, 0.1, 0.06) if on else MUT
		for st in ["normal", "hover", "focus", "pressed"]:
			tb.add_theme_stylebox_override(st, _box(bgc, 14))
		var ic := _icon(str(tabs[i][2]), 30, fgc)
		ic.position = Vector2((RAIL_W - 20) * 0.5 - 15, (th - 8) * 0.5 - 27)
		tb.add_child(ic)
		var tl := _label(str(tabs[i][1]), 19, fgc, font3)
		tl.position = Vector2(0, (th - 8) * 0.5 + 6)
		tl.size = Vector2(RAIL_W - 20, 24)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tb.add_child(tl)
		menu.add_child(tb)
	# --- the content: everything to the right of the rail
	var root := menu
	var box := Control.new()
	box.position = Vector2(RAIL_W, 0)
	box.size = Vector2(w - RAIL_W, h)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(box)
	menu = box
	w -= RAIL_W
	# header: the place's name, one chip of facts, your money (and in the career the way out)
	var names := {"pro": "My player", "league": "League", "play": "Play", "team": "Squad" if incar else "Team", "club": "Club", "shop": "Shop", "profile": "Me", "career": str(c.get("name", "Career")).capitalize(), "transfers": "Transfers", "office": "Office"}
	var ttl := _label(str(names.get(tab, "")), 34, CHALK)
	ttl.position = Vector2(24, 10)
	menu.add_child(ttl)
	var tx := 24.0 + font.get_string_size(ttl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x + 16.0
	var chip_t := ""
	if incar:
		chip_t = ("Together  ·  " if assist else "") + "%s  ·  round %d of %d  ·  %s" % [str(c.get("lgname", "")).capitalize(), mini(int(c.get("round", 0)) + 1, int(c.get("rounds", 14))), int(c.get("rounds", 14)), _ord(int(c.get("rank", 1))).to_lower()]
	else:
		chip_t = "%s  ·  rating %d" % [str(c.get("name", "")).capitalize(), int(c.get("str", 0))]
	var money := _label(_mp(int(c.get("coins", 0))) if (info.get("pro", {}) as Dictionary).is_empty() else "", 30, GOLD)
	money.size = Vector2(260, 40)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var rx := w - 20.0
	if incar:
		var xb := _btn("Leave" if assist else "Exit", "co_leave" if assist else "cr_exit", null, "ghost", Vector2(rx - 96, 12), Vector2(96, 44), 20)
		menu.add_child(xb)
		rx -= 108.0
		var cor := str(info.get("co_room", ""))
		if cor != "":
			var con := bool(info.get("co_conn", false))
			var rb := _btn("Room %s  ·  %s" % [cor, "friend is here" if con else "share link"], "share" if not con else "co_close", null, "ghost", Vector2(rx - 250, 12), Vector2(240, 44), 17)
			if con:
				rb.add_theme_color_override("font_color", GREEN.lightened(0.3))
			menu.add_child(rb)
			rx -= 260.0
	if bool(info.get("upd", false)):
		var ub := _btn("UPDATE", "update", null, "primary", Vector2(rx - 130, 12), Vector2(124, 44), 18)
		for st in ["normal", "hover", "focus"]:
			ub.add_theme_stylebox_override(st, _box(GOLD, 12))
		menu.add_child(ub)
		_pulse(ub)
		rx -= 140.0
	money.position = Vector2(rx - 260, 12)
	menu.add_child(money)
	var mw := font.get_string_size(money.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	if not bool(info.get("eur", false)):
		# a coin in front of the number
		var coin := Panel.new()
		var cbx := _box(GOLD, 12, Color(0.78, 0.6, 0.06))
		cbx.set_border_width_all(4)
		coin.add_theme_stylebox_override("panel", cbx)
		coin.size = Vector2(24, 24)
		coin.position = Vector2(rx - mw - 34, 20)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu.add_child(coin)
		mw += 34.0
	var room := rx - mw - 20.0 - tx
	if room > 120.0:
		var chip := Label.new()
		chip.text = _trim(chip_t, font3, 19, room - 34.0)
		chip.add_theme_font_override("font", font3)
		chip.add_theme_font_size_override("font_size", 19)
		chip.add_theme_color_override("font_color", CHALK)
		chip.add_theme_stylebox_override("normal", _box(Color(1, 1, 1, 0.07), 16, Color(0, 0, 0, 0), 14))
		chip.position = Vector2(tx, 15)
		chip.clip_text = true
		chip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		chip.custom_minimum_size = Vector2(0, 34)
		chip.size = Vector2(minf(room, font3.get_string_size(chip_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 32.0), 34)
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu.add_child(chip)
	var ver2 := _label(str(info.get("version", "")), 16, Color(1, 1, 1, 0.45), font2)
	ver2.position = Vector2(w - 220, h - 22)
	ver2.size = Vector2(200, 18)
	ver2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu.add_child(ver2)
	var y0 := 70.0
	var ch := h - y0 - 24.0
	match tab:
		"play":
			_tab_play(info, w, y0, ch, items)
		"career":
			_tab_career(info, w, y0, ch, items, anim)
		"transfers":
			_tab_transfers(info, w, y0, ch, items)
		"office":
			_tab_office(info, w, y0, ch, items)
		"pro":
			_tab_pro(info, w, y0, ch, items)
		"league":
			_tab_league(info, w, y0, ch, items)
		"team":
			_tab_team(info, w, y0, ch, items)
		"club":
			_tab_club(info, w, y0, ch, items)
		"shop":
			_tab_shop(info, w, y0, ch, items)
		"profile":
			_tab_profile(info, w, y0, ch, items)
	menu = root

# title + one short line inside a card, at the bottom (the way the play tiles read)
func _card_text(b: Control, title: String, sub: String, sz: Vector2, fs := 28, col := CHALK) -> void:
	var t := _label(title, fs, col)
	t.position = Vector2(22, sz.y - (fs + 14) - (30 if sub != "" else 0) - 10)
	t.clip_text = true
	t.size = Vector2(sz.x - 40, fs + 10)
	b.add_child(t)
	if sub != "":
		var s := _label(sub, 20, MUT, font3)
		s.position = Vector2(22, sz.y - 40)
		s.clip_text = true
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		s.size = Vector2(sz.x - 40, 28)
		b.add_child(s)

func _tab_play(info: Dictionary, w: float, y0: float, ch: float, items: Array) -> void:
	var c: Dictionary = info.get("car", {})
	var on := bool(info.get("car_on", false))
	var cr: Dictionary = info.get("cr", {})
	var car_s := "Start one: your club or any of 116"
	if on and not cr.is_empty():
		car_s = "%s  ·  %s" % [str(cr["lg"]).capitalize(), _ord(int(cr["rank"])).to_lower()]
	var cp: Dictionary = info.get("cupc", {})
	var cs := "English or Danish"
	if not cp.is_empty():
		cs = "You won it!" if bool(cp["won"]) else ("You are out" if bool(cp["out"]) else "%s next" % str(cp["round"]).capitalize())
	var rki: Dictionary = info.get("rank", {})
	var gap := 14.0
	# the quick match: the biggest thing, one tap from playing
	var hw := (w - 48.0 - 2 * gap) * 0.38
	var hero := _card("quick", null, Vector2(24, y0), Vector2(hw, ch))
	menu.add_child(hero)
	items.append([hero, Vector2(-60, 0), 0.0])
	var qt := _label("Quick match", 34, CHALK)
	qt.position = Vector2(22, 18)
	hero.add_child(qt)
	var qs := _label("Against the computer  ·  %s  ·  %s" % [str(info.get("len", "")).to_lower(), str(info.get("diff", "")).capitalize()], 20, MUT, font3)
	qs.position = Vector2(22, 62)
	qs.clip_text = true
	qs.size = Vector2(hw - 40, 28)
	hero.add_child(qs)
	var clubs: Array = info.get("clubs", [])
	var oc := int(info.get("club", 0))
	var myk: Array = c.get("kit", ["f5a623", "1c1c20"])
	var mynm := str(c.get("name", "My club")).capitalize()
	if not bool(info.get("own_ft", false)) and oc >= 0 and oc < clubs.size() and oc < 8:
		myk = clubs[oc]["k"]
		mynm = str(clubs[oc]["n"]).capitalize()
	var ks := clampf(ch - 260.0, 70.0, 120.0)
	var ky := 100.0 + (ch - 100.0 - 96.0 - ks - 30.0) * 0.5
	var s1 := _shirt(myk, ks)
	s1.position = Vector2(hw * 0.5 - ks - 26, ky)
	hero.add_child(s1)
	var s2 := _shirt(["5d6b63", "8b968f"], ks)
	s2.position = Vector2(hw * 0.5 + 26, ky)
	hero.add_child(s2)
	var vv := _label("v", 26, MUT)
	vv.position = Vector2(0, ky + ks * 0.5 - 18)
	vv.size = Vector2(hw, 30)
	vv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(vv)
	var n1 := _label(mynm, 21, CHALK, font3)
	n1.position = Vector2(hw * 0.5 - ks * 0.5 - 26 - 70, ky + ks + 4)
	n1.size = Vector2(140, 26)
	n1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n1.clip_text = true
	hero.add_child(n1)
	var n2 := _label("Pick a side", 21, MUT, font3)
	n2.position = Vector2(hw * 0.5 + ks * 0.5 + 26 - 70, ky + ks + 4)
	n2.size = Vector2(140, 26)
	n2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(n2)
	var go := _btn("PLAY", "quick", null, "primary", Vector2(24 + 20, y0 + ch - 86), Vector2(hw - 40, 66), 32)
	menu.add_child(go)
	items.append([go, Vector2(0, 50), 0.1])
	_pulse(go)
	# the four other ways to play: icon, name, one line of what is going on
	var tw := (w - 48.0 - hw - 2 * gap) * 0.5
	var tl := (ch - 2 * gap) / 3.0
	var defs := [
		["Career", car_s, "c_home" if on else "c_start", GREEN, "ladder"],
		["Player career", str(info.get("pro_tile", "")), "p_home", Color(0.62, 0.45, 0.95), "me"],
		["Ranked", "%s  ·  %d pts" % [_rk_name(str(rki.get("n", ""))), int(rki.get("rp", 0))], "online", Color(str(rki.get("c", "e8954a"))), "shield"],
		["The cup", cs, "cupm", GOLD, "cup"],
		["With a friend", "Together or against", "friend", Color(0.36, 0.6, 1.0), "duo"],
	]
	for i in 5:
		var pos := Vector2(24 + hw + gap + (i % 2) * (tw + gap), y0 + (i / 2) * (tl + gap))
		var sz := Vector2(tw if i < 4 else tw * 2 + gap, tl)
		var b := _card(str(defs[i][2]), null, pos, sz, defs[i][3])
		menu.add_child(b)
		items.append([b, Vector2(0, 40), 0.05 + 0.04 * i])
		if i == 2:
			_rk_badge(b, Vector2(16, 12), 36.0, rki)
		else:
			var ic := _icon(str(defs[i][4]), 34, CHALK)
			ic.position = Vector2(18, 14)
			b.add_child(ic)
		_card_text(b, str(defs[i][0]), str(defs[i][1]), sz, 24)

# "BRONZE III" -> "Bronze III"
func _rk_name(n: String) -> String:
	var p := n.split(" ")
	if p.is_empty():
		return n
	p[0] = p[0].capitalize()
	return " ".join(p)

func _tab_career(info: Dictionary, w: float, y0: float, ch: float, items: Array, anim: bool) -> void:
	var c: Dictionary = info.get("car", {})
	var gap := 14.0
	var lw := (w - 48.0 - gap) * 0.56
	# the next-match card opens the calendar
	var card := _card("cal", null, Vector2(24, y0), Vector2(lw, ch))
	menu.add_child(card)
	items.append([card, Vector2(-60, 0), 0.0])
	var cic := _icon("cal", 26, MUT)
	cic.position = Vector2(lw - 46, 16)
	card.add_child(cic)
	var bh := 72.0
	if bool(c.get("over", false)) and not bool(c.get("nat_due", false)):
		var nt := _label(str(c.get("note", "SEASON OVER")), 26, GOLD)
		nt.autowrap_mode = TextServer.AUTOWRAP_WORD
		nt.position = Vector2(24, 40)
		nt.size = Vector2(lw - 48, ch - 160)
		nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(nt)
		if bool(c.get("sacked", false)):
			nt.text = "The board has sacked you. Three clubs want you as their manager."
			nt.add_theme_color_override("font_color", Color(0.95, 0.4, 0.35))
		var pro_o: Dictionary = info.get("pro", {})
		if bool(pro_o.get("need2", false)):
			pro_o = {}
		if not pro_o.is_empty():
			nt.text = "Season over. %d matches, %d goals, %d assists, average rating %.1f." % [int(pro_o["ss"]["apps"]), int(pro_o["ss"]["g"]), int(pro_o["ss"]["a"]), float(pro_o["avg"])] + (("\nYou move to %s." % str(pro_o["offer"])) if str(pro_o["offer"]) != "" else "")
		var ns := _btn("THE BOARD'S VERDICT", "c_review", null, "primary", Vector2(44, y0 + ch - bh - 20), Vector2(lw - 40, bh), 30)
		if not pro_o.is_empty():
			ns = _btn("NEXT SEASON", "c_next", null, "primary", Vector2(44, y0 + ch - bh - 20), Vector2(lw - 40, bh), 30)
		menu.add_child(ns)
		items.append([ns, Vector2(0, 60), 0.1])
	else:
		var cdue := bool(c.get("cup_due", false))
		var cpn: Dictionary = c.get("cup", {})
		var edue := not cdue and bool(c.get("eu_due", false))
		var what := ("The cup, " + str(cpn.get("name", "")).to_lower()) if cdue else ("League, " + ("home" if bool(c.get("home", true)) else "away"))
		if edue:
			# a European night: the card shows the Champions Cup opponent the same way
			cpn = c.get("eu", {})
			cdue = true
			what = "%s, %s" % [str(cpn.get("name", "Europe")).capitalize().trim_prefix("The "), str(cpn.get("rname", "")).capitalize()]
		var ndue := not cdue and not edue and bool(c.get("nat_due", false))
		if ndue:
			# your country plays: its kit and name on the card, the club waits
			cpn = c.get("natm", {})
			cdue = true
			what = "%s, %s" % [str(cpn.get("tname", "")).capitalize(), str(cpn.get("rname", "")).to_lower()]
		var dtx := str(c.get("ndate", ""))
		if bool(c.get("derby", false)):
			# derby day: the card says it in red
			var drb: Dictionary = c.get("drb", {})
			var dn := int(drb.get("w", 0)) + int(drb.get("d", 0)) + int(drb.get("l", 0))
			what = ("DERBY (W%d D%d L%d)  ·  " % [int(drb.get("w", 0)), int(drb.get("d", 0)), int(drb.get("l", 0))] if dn > 0 else "DERBY  ·  ") + what
		var nx := _label((dtx + "  ·  " if dtx != "" else "") + what, 22, EUBLUE if edue else (Color(1.0, 0.42, 0.36) if bool(c.get("derby", false)) else GOLD), font3)
		nx.position = Vector2(22, 16)
		nx.clip_text = true
		nx.size = Vector2(lw - 80, 30)
		card.add_child(nx)
		var kits := [cpn.get("kit", ["888888"]) if ndue else c.get("kit", ["888888"]), cpn.get("opp_kit", ["888888"]) if cdue else c.get("opp_kit", ["888888"])]
		var nms := [str(cpn.get("me", "")) if ndue else str(c.get("name", "")), str(cpn.get("opp", "")) if cdue else str(c.get("opp", ""))]
		var rks := [int(c.get("rank", 1)), int(cpn.get("opp_rank", 1)) if cdue else int(c.get("opp_rank", 1))]
		var ks := minf(96.0, ch - bh - 190.0)
		var my := 60.0 + (ch - bh - 60.0 - ks - 90.0) * 0.5
		for si in 2:
			var cx := lw * (0.27 if si == 0 else 0.73)
			var sh := _shirt(kits[si], ks)
			sh.position = Vector2(cx - ks * 0.5, my)
			card.add_child(sh)
			var fs2 := 26
			while fs2 > 18 and font.get_string_size(nms[si].capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x > lw * 0.46:
				fs2 -= 2
			var nl := _label(nms[si].capitalize(), fs2, CHALK)
			nl.position = Vector2(cx - lw * 0.24, my + ks + 6)
			nl.size = Vector2(lw * 0.48, 34)
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nl.clip_text = true
			card.add_child(nl)
			var other_lg: bool = cdue and si == 1 and str(cpn.get("opp_lg", "")) != str(c.get("lgname", ""))
			var rl := _label(str((cpn.get("sub", ["", ""]) as Array)[si]) if ndue else (str(cpn.get("opp_lg", "")).capitalize() if other_lg else _ord(rks[si]).to_lower() + " in the table"), 20, MUT, font3)
			rl.position = Vector2(cx - lw * 0.24, my + ks + 40)
			rl.size = Vector2(lw * 0.48, 26)
			rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.add_child(rl)
		var vv := _label("v", 30, MUT)
		vv.position = Vector2(0, my + ks * 0.5 - 20)
		vv.size = Vector2(lw, 40)
		vv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(vv)
		# simulate works together too: the manager's tap simulates on both phones, the friend's tap asks him
		var can_sim := not bool(c.get("sacked", false))
		var pw := (lw - 40) * (0.64 if can_sim else 1.0)
		var ptx := "PLAY EUROPE" if edue else ("PLAY FOR %s" % str(cpn.get("me", "")) if ndue else ("PLAY CUP MATCH" if cdue else "PLAY MATCH"))
		var pro_i: Dictionary = info.get("pro", {})
		if bool(pro_i.get("need2", false)):
			pro_i = {}
			var mk := _label("Make your own player on the Player tab", 20, GOLD, font3)
			mk.position = Vector2(22, 48)
			mk.size = Vector2(lw - 44, 26)
			card.add_child(mk)
		if not pro_i.is_empty():
			var st_on := str(pro_i.get("next", "")) == "start"
			ptx = "PLAY" if st_on else "WATCH FROM THE BENCH"
			var sl := _label(("You start, as %s" % str(pro_i["pos"])) if st_on else ("Injured: you miss this one" if bool(pro_i.get("inj", false)) else "The manager has you on the bench"), 20, GREEN if st_on else MUT, font3)
			sl.position = Vector2(22, 48)
			sl.size = Vector2(lw - 44, 26)
			card.add_child(sl)
			if not st_on:
				can_sim = false
				pw = lw - 40
		# the plan for the match, one tap from the card (not in a player career: there the manager decides)
		if (info.get("pro", {}) as Dictionary).is_empty() and c.has("tac"):
			var tt: Array = c.get("tac", [2, 1, 1])
			var tcb := _btn("Tactics:  " + _tac_short(tt) + "  ›", "ctac", null, "ghost", Vector2(24 + 22, y0 + 52), Vector2(lw - 44 - 50, 40), 17)
			menu.add_child(tcb)
			items.append([tcb, Vector2(0, 30), 0.1])
		# FIFA's ADVANCE: today, how long to the match, and a day at a time
		var dleft := int(c.get("dleft", 0))
		var tdl := _label(("Today: %s  ·  %s" % [str(c.get("cdate", "")), ("match in %d day%s" % [dleft, "" if dleft == 1 else "s"]) if dleft > 0 else "match day"]), 19, MUT if dleft > 0 else GREEN, font3)
		tdl.position = Vector2(22, ch - bh - 66)
		tdl.size = Vector2(lw - 44 - (190 if dleft > 0 else 0), 26)
		card.add_child(tdl)
		tdl.size = Vector2(lw - 44, 26)
		# no match before match day: until then the big button lets the days go by (to news, or to the match)
		var pm: Button
		if dleft > 0:
			pm = _btn("SIMULATE  ›", "c_adv", null, "primary", Vector2(44, y0 + ch - bh - 20), Vector2(lw - 40, bh), 32)
			can_sim = false
		else:
			pm = _btn(_co_play_text(info, ptx), "c_play", null, "primary", Vector2(44, y0 + ch - bh - 20), Vector2(pw, bh), 30 if can_sim else 32)
		menu.add_child(pm)
		items.append([pm, Vector2(0, 60), 0.1])
		if can_sim:
			var sb := _btn("SIMULATE", "c_sim", null, "alt", Vector2(44 + pw + 12, y0 + ch - bh - 20), Vector2(lw - 40 - pw - 12, bh), 22)
			menu.add_child(sb)
			items.append([sb, Vector2(0, 60), 0.14])
		if anim:
			pm.ready.connect(func(): _pulse(pm))
		else:
			_pulse(pm)
	# the right column: the table around you, the board, the cup, playing together
	var rx := 24.0 + lw + gap
	var rw := w - rx - 24.0
	var rows: Array = c.get("table", [])
	var me_i := 0
	for i in rows.size():
		if bool(rows[i][8]):
			me_i = i
	var r0 := clampi(me_i - 1, 0, maxi(rows.size() - 3, 0))
	var nrow := mini(3, rows.size())
	var tt := _card("c_table", null, Vector2(rx, y0), Vector2(rw, 30 + nrow * 34.0), Color(0, 0, 0, 0))
	menu.add_child(tt)
	items.append([tt, Vector2(80, 0), 0.0])
	for k in nrow:
		var r: Array = rows[r0 + k]
		var me := bool(r[8])
		var col := GOLD if me else CHALK
		var a := _label(str(r[0]), 21, col, font3)
		a.position = Vector2(20, 14 + k * 34.0)
		tt.add_child(a)
		var b := _label(str(r[1]).capitalize(), 21, col, font3)
		b.position = Vector2(64, 14 + k * 34.0)
		b.clip_text = true
		b.size = Vector2(rw - 150, 28)
		tt.add_child(b)
		var p := _label(str(r[7]), 21, col)
		p.position = Vector2(rw - 70, 14 + k * 34.0)
		p.size = Vector2(50, 28)
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tt.add_child(p)
	var yy := y0 + tt.size.y + gap
	var left_h := y0 + ch - yy
	var bd: Dictionary = c.get("board", {})
	var wd0: Dictionary = c.get("live", {})
	# the same screen for both of you when you play together: board, cup and inbox
	var together := not bool(info.get("assist", false)) or not wd0.is_empty()
	var each := (left_h - gap * (2 if together else 1)) / (3.0 if together else 2.0)
	var bc := int(bd.get("conf", 50))
	var pro_r: Dictionary = info.get("pro", {})
	if bool(pro_r.get("need2", false)):
		pro_r = {}
	if not pro_r.is_empty():
		bc = int(pro_r["trust"])
	var bb := _card("tab" if not pro_r.is_empty() else "c_board", "pro" if not pro_r.is_empty() else null, Vector2(rx, yy), Vector2(rw, each))
	menu.add_child(bb)
	items.append([bb, Vector2(80, 0), 0.04])
	var bl := _label("Manager's trust" if not pro_r.is_empty() else "Board", 22, CHALK, font3)
	bl.position = Vector2(20, 10)
	bb.add_child(bl)
	var bm := _label(("%d" % bc) if not pro_r.is_empty() else "%s %d" % [str(bd.get("mood", "")).capitalize(), bc], 22, _conf_col(bc), font3)
	bm.position = Vector2(rw - 220, 10)
	bm.size = Vector2(200, 28)
	bm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bb.add_child(bm)
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.1)
	bg.position = Vector2(20, 44)
	bg.size = Vector2(rw - 40, 10)
	bb.add_child(bg)
	var bf := ColorRect.new()
	bf.color = _conf_col(bc)
	bf.position = Vector2(20, 44)
	bf.size = Vector2((rw - 40) * bc / 100.0, 10)
	bb.add_child(bf)
	var cpi: Dictionary = c.get("cup", {})
	var cps := "You won it!" if bool(cpi.get("won", false)) else ("You are out" if bool(cpi.get("out", false)) else ("%s v %s: next!" % [str(cpi.get("name", "")).capitalize(), str(cpi.get("opp", "")).capitalize()] if bool(c.get("cup_due", false)) else "%s v %s, after round %d" % [str(cpi.get("name", "")).capitalize(), str(cpi.get("opp", "")).capitalize(), int(c.get("cup_after", 0))]))
	var eui: Dictionary = c.get("eu", {})
	var show_eu := not eui.is_empty() and (bool(c.get("eu_due", false)) or bool(cpi.get("won", false)) or bool(cpi.get("out", false)))
	if show_eu:
		var eun := str(eui.get("name", "Europe")).capitalize().trim_prefix("The ")
		if bool(eui.get("won", false)):
			cps = "Champions of Europe!" if int(eui.get("k", 0)) == 0 else "You won the %s!" % eun
		elif bool(eui.get("done", false)):
			cps = "%s: %s won it" % [eun, str(eui.get("win", ""))]
		elif bool(eui.get("out", false)):
			cps = "%s: you are out" % eun
		else:
			cps = "%s v %s, %s" % [eun, str(eui.get("opp", "?")).capitalize(), str(eui.get("day", ""))]
	var cb := _card("eu" if show_eu else "cup", null, Vector2(rx, yy + each + gap), Vector2(rw, each))
	menu.add_child(cb)
	items.append([cb, Vector2(80, 0), 0.08])
	var ci := _icon("cup", 34, EUBLUE if show_eu else GOLD)
	ci.position = Vector2(18, each * 0.5 - 17)
	cb.add_child(ci)
	var ct := _label(cps, 21, CHALK, font3)
	ct.position = Vector2(64, each * 0.5 - 14)
	ct.clip_text = true
	ct.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ct.size = Vector2(rw - 84, 28)
	cb.add_child(ct)
	var wd: Dictionary = c.get("live", {})
	if not wd.is_empty():
		var ib: Array = wd.get("inbox", [])
		var un := int(wd.get("unread", 0))
		var wn: Dictionary = wd.get("win", {})
		var ibc := _card("inbox", null, Vector2(rx, yy + 2 * (each + gap)), Vector2(rw, each))
		menu.add_child(ibc)
		items.append([ibc, Vector2(80, 0), 0.12])
		var mi := _icon("mail", 34, GOLD if un > 0 else MUT)
		mi.position = Vector2(18, each * 0.5 - 17)
		ibc.add_child(mi)
		var it2 := "Inbox"
		var col2 := CHALK
		if bool(wn.get("open", false)) and bool(wn.get("deadline", false)):
			it2 = "Deadline day! The window shuts %s" % str(wn.get("ctext", ""))
			col2 = GOLD
		elif un > 0 and not ib.is_empty():
			for m in ib:
				if not bool(m.get("rd", false)):
					it2 = str(m["t"])
					break
		elif not ib.is_empty():
			it2 = "Inbox: " + str(ib[0]["t"])
		var ilt := _label(_trim(it2, font3, 21, rw - 92 - (44 if un > 0 else 0)), 21, col2, font3)
		ilt.position = Vector2(64, each * 0.5 - 14)
		ilt.clip_text = true
		ilt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		ilt.size = Vector2(rw - 84 - (44 if un > 0 else 0), 28)
		ibc.add_child(ilt)
		if un > 0:
			var dot := Panel.new()
			dot.add_theme_stylebox_override("panel", _box(Color(0.86, 0.22, 0.2), 14))
			dot.position = Vector2(rw - 52, each * 0.5 - 14)
			dot.size = Vector2(34, 28)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ibc.add_child(dot)
			var dl2 := _label(str(un), 18, Color.WHITE, font3)
			dl2.position = Vector2(0, 0)
			dl2.size = Vector2(34, 28)
			dl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dl2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			dot.add_child(dl2)
	elif together:
		var cor := str(info.get("co_room", ""))
		var fb := _card("friend", null, Vector2(rx, yy + 2 * (each + gap)), Vector2(rw, each))
		menu.add_child(fb)
		items.append([fb, Vector2(80, 0), 0.12])
		var fi := _icon("duo", 34, Color(0.55, 0.75, 1.0))
		fi.position = Vector2(18, each * 0.5 - 17)
		fb.add_child(fi)
		var ft := _label(("Room %s: your friend joins with this code" % cor) if cor != "" else "Play it together with a friend", 21, CHALK, font3)
		ft.position = Vector2(64, each * 0.5 - 14)
		ft.clip_text = true
		ft.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		ft.size = Vector2(rw - 84, 28)
		fb.add_child(ft)

# a row of big tiles: icon top left, name and one short line at the bottom
func _tiles(defs: Array, x: float, y: float, w: float, h: float, cols: int, items: Array) -> void:
	var gap := 14.0
	var rows := int(ceil(defs.size() / float(cols)))
	var tw := (w - gap * (cols - 1)) / cols
	var th := (h - gap * (rows - 1)) / rows
	for i in defs.size():
		var d: Array = defs[i]
		var pos := Vector2(x + (i % cols) * (tw + gap), y + (i / cols) * (th + gap))
		var b := _card(str(d[2]), d[5] if d.size() > 5 else null, pos, Vector2(tw, th), d[4] if d.size() > 4 else Color(0, 0, 0, 0))
		menu.add_child(b)
		items.append([b, Vector2(0, 40), 0.04 * i])
		var ic := _icon(str(d[3]), 40 if th > 140 else 32, CHALK)
		ic.position = Vector2(22, 18)
		b.add_child(ic)
		_card_text(b, str(d[0]), str(d[1]), Vector2(tw, th), 28 if th > 140 else 24)

func _tab_transfers(info: Dictionary, w: float, y0: float, ch: float, items: Array) -> void:
	var c: Dictionary = info.get("car", {})
	var mk: Array = c.get("market", [])
	var top_h := ch * 0.6
	var wd: Dictionary = c.get("live", {})
	var nd := (wd.get("deals", []) as Array).size()
	_tiles([
		["For sale", "%d free players" % mk.size(), "c_market", "shop"],
		["Other clubs", "Bid for their men", "scout", "club"],
		["Sell", "From your bench", "c_squad", "swap"],
		["Transfer news", ("%d deals so far" % nd) if nd > 0 else "Who buys whom", "tnews", "mail", Color(0.36, 0.6, 1.0)],
	], 24, y0, w - 48, top_h, 4, items)
	var bp := _card_panel(Vector2(24, y0 + top_h + 14), Vector2(w - 48, ch - top_h - 14))
	if not wd.is_empty():
		var wn: Dictionary = wd.get("win", {})
		var wt := ""
		var wcol := GREEN
		if bool(wn.get("open", false)):
			wt = ("Deadline day: the %s shuts %s" if bool(wn.get("deadline", false)) else "The %s is open until %s") % [str(wn.get("name", "")).to_lower(), str(wn.get("ctext", ""))]
			wcol = GOLD if bool(wn.get("deadline", false)) else GREEN
		elif bool(wd.get("won", false)):
			wt = "The window is shut: it opens on %s" % str(wn.get("otext", ""))
			wcol = MUT
		else:
			wt = "Simple career: you can deal all season"
			wcol = MUT
		var wl2 := _label(wt, 19, wcol, font3)
		wl2.position = Vector2(22, ch - top_h - 14 - 36)
		wl2.clip_text = true
		wl2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		wl2.size = Vector2(w - 48 - 44 - (320 if bool(c.get("wg", c.get("eur", false))) else 0), 26)
		bp.add_child(wl2)
	var bl := _label("Transfer budget", 20, MUT, font3)
	bl.position = Vector2(22, 14)
	bp.add_child(bl)
	var bv := _label(_mp(int(c.get("coins", 0))), 44, GOLD)
	bv.position = Vector2(22, 40)
	bp.add_child(bv)
	if bool(c.get("wg", c.get("eur", false))):
		var wl := _label("Wages a week", 20, MUT, font3)
		wl.position = Vector2(300, 14)
		bp.add_child(wl)
		var wv := _label("%s of %s" % [Career.wage_text(int(c.get("wages", 0))), Career.wage_text(int(c.get("wb", 0)))], 34, CHALK)
		wv.position = Vector2(300, 46)
		bp.add_child(wv)
		var bx := w - 24.0 - 300.0
		var by := y0 + top_h + 14
		menu.add_child(_btn("+ %s wages  (– %s)" % [Career.wage_text(Career.WB_STEP), _mp(Career.WB_STEP * Career.WB_RATE)], "c_wb", "up", "alt", Vector2(bx, by + 12), Vector2(284, 48), 18))
		menu.add_child(_btn("– %s wages  (+ %s)" % [Career.wage_text(Career.WB_STEP), _mp(Career.WB_STEP * Career.WB_RATE)], "c_wb", "down", "ghost", Vector2(bx, by + 68), Vector2(284, 48), 18))
		if str(c.get("msg", "")) != "":
			var ms := _label(str(c.get("msg", "")), 18, GOLD, font3)
			ms.position = Vector2(300, 92)
			ms.clip_text = true
			ms.size = Vector2(w - 48 - 300 - 320, 26)
			bp.add_child(ms)

func _tab_office(info: Dictionary, w: float, y0: float, ch: float, items: Array) -> void:
	var c: Dictionary = info.get("car", {})
	if not (info.get("pro", {}) as Dictionary).is_empty():
		_tiles([
			["Inbox", "Offers and news", "inbox", "mail", GOLD],
			["Calendar", ("Next: " + str(c.get("ndate", ""))) if str(c.get("ndate", "")) != "" else "The season", "cal", "cal", Color(0.36, 0.6, 1.0)],
			["Play together", ("Together now" if bool(info.get("assist", false)) or bool(info.get("co_conn", false)) else "Your friend makes his own player"), "friend", "duo", Color(0.36, 0.6, 1.0)],
			["Match settings", "%s  ·  %s" % [["Easy", "Normal", "Hard"][clampi(int(c.get("cdiff", 1)), 0, 2)], ["3 min", "5 min", "8 min"][clampi(int(c.get("clen", 1)), 0, 2)]], "cset", "sliders"],
			["New player", "Start a new player career", "p_new", "plus"],
		], 24, y0, w - 48, ch, 3, items)
		return
	var bd: Dictionary = c.get("board", {})
	var cp: Dictionary = c.get("cup", {})
	_tiles([
		["The board", "Confidence %d: %s" % [int(bd.get("conf", 50)), str(bd.get("mood", "")).to_lower()], "c_board", "board", GOLD],
		["The table", "%s  ·  %s" % [str(c.get("lgname", "")).capitalize(), _ord(int(c.get("rank", 1))).to_lower()], "c_table", "table"],
		["The cup", str(cp.get("cname", "The cup")).capitalize(), "cup", "cup"],
		["Play together", ("Together now" if bool(info.get("assist", false)) or bool(info.get("co_conn", false)) else "Your friend joins on his phone"), "friend", "duo", Color(0.36, 0.6, 1.0)],
		["Calendar", ("Next: " + str(c.get("ndate", ""))) if str(c.get("ndate", "")) != "" else "The season", "cal", "cal", Color(0.36, 0.6, 1.0)],
		["Match settings", "%s  ·  %s" % [["Easy", "Normal", "Hard"][clampi(int(c.get("cdiff", 1)), 0, 2)], ["3 min", "5 min", "8 min"][clampi(int(c.get("clen", 1)), 0, 2)]], "cset", "sliders"],
		["Career: " + ("full" if str(c.get("mode", "")) == "full" else "simple"), "Can the board sack you?", "cmode", "office"],
		["New career", "Start again", "c_new", "plus"],
	], 24, y0, w - 48, ch, 4, items)

func _tab_team(info: Dictionary, w: float, y0: float, ch: float, items: Array) -> void:
	var c: Dictionary = info.get("car", {})
	var sq: Array = c.get("squad", [])
	var xi: Array = c.get("xi", [])
	var gap := 14.0
	var lw := (w - 48.0 - gap) * 0.5
	var tp := int(c.get("tp", 0))
	var big := _card("c_squad", null, Vector2(24, y0), Vector2(lw, ch * 0.58), GREEN)
	menu.add_child(big)
	items.append([big, Vector2(-60, 0), 0.0])
	var ic := _icon("team", 48, CHALK)
	ic.position = Vector2(22, 18)
	big.add_child(ic)
	_card_text(big, "Line-up", ("%d training points to use" % tp) if tp > 0 else "Formation, players, training, selling", Vector2(lw, ch * 0.58), 34)
	var bh := ch - ch * 0.58 - gap
	var hw := (lw - gap) * 0.5
	var rp := _card_panel(Vector2(24, y0 + ch * 0.58 + gap), Vector2(hw, bh))
	var rl := _label("Team rating", 20, MUT, font3)
	rl.position = Vector2(0, 14)
	rl.size = Vector2(hw, 26)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rp.add_child(rl)
	var rv := _label(str(int(c.get("str", 0))), 56, CHALK)
	rv.position = Vector2(0, bh * 0.5 - 22)
	rv.size = Vector2(hw, 64)
	rv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rp.add_child(rv)
	var eur := bool(c.get("eur", false))
	var pln: Dictionary = c.get("plan", {})
	var unh := 0
	for sq0 in sq:
		if int((sq0 as Dictionary).get("mo", 65)) < 35:
			unh += 1
	var ob := _card("c_trainm" if eur else "own", null, Vector2(24 + hw + gap, y0 + ch * 0.58 + gap), Vector2(hw, bh))
	menu.add_child(ob)
	items.append([ob, Vector2(0, 40), 0.05])
	var oi := _icon("train" if eur else "kit", 32, CHALK)
	oi.position = Vector2(20, 16)
	ob.add_child(oi)
	if eur:
		_card_text(ob, "Training", "%s%s" % [Career.FOCI[str(pln.get("f", "balanced"))][0].capitalize(), ("  ·  %d unhappy" % unh) if unh > 0 else ""], Vector2(hw, bh), 24)
	else:
		_card_text(ob, "Name and kit", "Your club's colours", Vector2(hw, bh), 24)
	# the best players, with where they play and their rating
	var rx := 24.0 + lw + gap
	var rw := w - rx - 24.0
	var lp := _card_panel(Vector2(rx, y0), Vector2(rw, ch))
	items.append([lp, Vector2(80, 0), 0.05])
	var lh := _label("Best players", 22, CHALK, font3)
	lh.position = Vector2(20, 12)
	lp.add_child(lh)
	var idx := []
	for i in sq.size():
		idx.append(i)
	idx.sort_custom(func(a3, b3): return int(sq[a3]["ovr"]) > int(sq[b3]["ovr"]))
	var rh := 42.0
	var rows := mini(idx.size(), int((ch - 56.0) / rh))
	var pc := {"GK": Color(1.0, 0.65, 0.15), "DF": Color(0.3, 0.6, 1.0), "MF": Color(0.3, 0.85, 0.45), "FW": Color(0.95, 0.35, 0.3)}
	for r in rows:
		var pl: Dictionary = sq[idx[r]]
		var yy := 50.0 + r * rh
		var pp := Panel.new()
		pp.add_theme_stylebox_override("panel", _box(pc.get(str(pl["pos"]), Color.WHITE), 6))
		pp.position = Vector2(20, yy + 6)
		pp.size = Vector2(44, 26)
		lp.add_child(pp)
		var pt := _label(str(pl["pos"]), 18, Color(0.03, 0.08, 0.05), font3)
		pt.size = Vector2(44, 26)
		pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pp.add_child(pt)
		var on_xi: bool = xi.has(idx[r]) or xi.has(float(idx[r]))
		var n1 := _label(str(pl["n"]).capitalize(), 23, CHALK if on_xi else MUT, font3)
		n1.position = Vector2(78, yy + 3)
		lp.add_child(n1)
		if not on_xi:
			var bn := _label("bench", 18, MUT, font2)
			bn.position = Vector2(rw - 190, yy + 7)
			lp.add_child(bn)
		var n2 := _label(str(int(pl["ovr"])), 26, GOLD if on_xi else MUT)
		n2.position = Vector2(rw - 100, yy + 1)
		n2.size = Vector2(80, 32)
		n2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lp.add_child(n2)

func _tab_club(info: Dictionary, w: float, y0: float, ch: float, items: Array) -> void:
	var c: Dictionary = info.get("car", {})
	var incar := bool(info.get("incar", false))
	var fcs: Array = c.get("fac", [])
	var ft := ""
	for f in fcs:
		ft += ("" if ft == "" else " · ") + "%s %d" % [str((f as Dictionary).get("n", "")).capitalize().get_slice(" ", 0), int((f as Dictionary).get("lv", 1))]
	var top_h := ch * 0.66
	_tiles([
		["Buildings", ft if ft != "" else "Stadium, training, youth", "c_club", "build", GREEN],
		(["Trophy cabinet", _cab_line(c), "cab", "cup", GOLD] if incar else ["Transfers", "%d players for sale" % (c.get("market", []) as Array).size(), "c_market", "swap"]),
		(["Youth academy", "Scouts, reports and your boys", "youth", "me", GOLD] if incar else ["Name and kit", "Your club's colours", "own", "kit"]),
	] + ([["National team", (str(((info.get("car", {}) as Dictionary).get("natp", {}) as Dictionary).get("n", "")).capitalize() + ": your country") if bool(((info.get("car", {}) as Dictionary).get("natp", {}) as Dictionary).get("job", false)) else "No job yet", "nat", "flag", Color(0.95, 0.36, 0.33)]] if incar and not ((info.get("car", {}) as Dictionary).get("natp", {}) as Dictionary).is_empty() else []), 24, y0, w - 48, top_h, 4 if incar and not ((info.get("car", {}) as Dictionary).get("natp", {}) as Dictionary).is_empty() else 3, items)
	var ip := _card_panel(Vector2(24, y0 + top_h + 14), Vector2(w - 48, ch - top_h - 14))
	var i2 := _label("A bigger stadium brings %s at home. A better training ground makes players grow faster." % _mw(), 21, MUT, font3)
	i2.autowrap_mode = TextServer.AUTOWRAP_WORD
	i2.position = Vector2(22, 0)
	i2.size = Vector2(w - 48 - 44, ch - top_h - 14)
	i2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ip.add_child(i2)

func _tab_shop(info: Dictionary, w: float, y0: float, ch: float, items: Array) -> void:
	var c: Dictionary = info.get("car", {})
	var msg := str(c.get("msg", ""))
	var packs: Array = info.get("packs", [])
	var gap := 14.0
	var cw := (w - 48.0 - 2 * gap) / 3.0
	var pcol := [Color(0.85, 0.55, 0.32), Color(0.82, 0.86, 0.9), GOLD]
	var ph := ch - 34.0
	for i in packs.size():
		var pk: Dictionary = packs[i]
		var pn := _card_panel(Vector2(24 + i * (cw + gap), y0), Vector2(cw, ph))
		items.append([pn, Vector2(0, 50), 0.05 * i])
		var top := ColorRect.new()
		top.color = pcol[i]
		top.position = Vector2(20, 18)
		top.size = Vector2(cw - 40.0, 6)
		pn.add_child(top)
		var pt := _label(str(pk["n"]).capitalize(), 30, pcol[i])
		pt.position = Vector2(0, 36)
		pt.size = Vector2(cw, 40)
		pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pn.add_child(pt)
		var pd := _label("One new player", 20, MUT, font3)
		pd.position = Vector2(0, 78)
		pd.size = Vector2(cw, 26)
		pd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pn.add_child(pd)
		var pr := _label("%d – %d" % [int(pk["lo"]), int(pk["hi"])], 52, CHALK)
		pr.position = Vector2(0, ph * 0.5 - 30.0)
		pr.size = Vector2(cw, 60)
		pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pn.add_child(pr)
		var rt := _label("rating", 20, MUT, font3)
		rt.position = Vector2(0, ph * 0.5 + 30.0)
		rt.size = Vector2(cw, 26)
		rt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pn.add_child(rt)
		var can: bool = int(c.get("coins", 0)) >= int(pk["cost"])
		var bb := _btn("OPEN  ·  %d" % int(pk["cost"]), "pack", i, "primary" if can else "off", Vector2(24 + i * (cw + gap) + 18.0, y0 + ph - 18.0 - 60.0), Vector2(cw - 36.0, 60), 24)
		menu.add_child(bb)
		items.append([bb, Vector2(0, 50), 0.05 * i])
	var sm := _label(msg if msg != "" else "You earn coins in ranked online, the cup, your career and against friends.", 19, GOLD if msg != "" else MUT, font3)
	sm.position = Vector2(0, y0 + ch - 26.0)
	sm.size = Vector2(w, 26)
	sm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(sm)

func _tab_profile(info: Dictionary, w: float, y0: float, ch: float, items: Array) -> void:
	var ps: Dictionary = info.get("pstats", {})
	var gap := 14.0
	var lw := (w - 48.0 - gap) * 0.5
	var sp := _card_panel(Vector2(24, y0), Vector2(lw, ch))
	items.append([sp, Vector2(-60, 0), 0.0])
	var sh := _label("Your record", 22, CHALK, font3)
	sh.position = Vector2(20, 12)
	sp.add_child(sh)
	# the three big numbers first, then the rest
	var big := [["Played", int(ps.get("p", 0))], ["Won", int(ps.get("w", 0))], ["Titles", int(ps.get("titles", 0))]]
	var bw := (lw - 40.0) / 3.0
	for i in 3:
		var v := _label(str(big[i][1]), 46, GOLD if i == 2 else CHALK)
		v.position = Vector2(20 + i * bw, 46)
		v.size = Vector2(bw, 54)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sp.add_child(v)
		var l := _label(str(big[i][0]), 20, MUT, font3)
		l.position = Vector2(20 + i * bw, 100)
		l.size = Vector2(bw, 26)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sp.add_child(l)
	var rws := [["Drawn", int(ps.get("d", 0))], ["Lost", int(ps.get("l", 0))], ["Goals scored", int(ps.get("gf", 0))], ["Goals against", int(ps.get("ga", 0))]]
	var rh := minf(40.0, (ch - 150.0) / rws.size())
	for i in rws.size():
		var a := _label(str(rws[i][0]), 22, MUT, font3)
		a.position = Vector2(24, 146 + i * rh)
		sp.add_child(a)
		var b := _label(str(rws[i][1]), 24, CHALK)
		b.position = Vector2(lw - 144, 144 + i * rh)
		b.size = Vector2(120, 30)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sp.add_child(b)
	var rx := 24.0 + lw + gap
	var rw := w - rx - 24.0
	var bw2 := (rw - 12.0) * 0.5
	var sets := [
		["Sound: " + str(info.get("snd", "")).to_lower(), "snd_opt"], ["Voice: " + ("on" if bool(info.get("voice", true)) else "off"), "voice_opt"],
		["Level: " + str(info.get("diff", "")).to_lower(), "diff"], ["Match: " + str(info.get("len", "")).to_lower(), "len"],
		["How to play", "how"], ["Update the game", "update"],
		["Installed" if bool(info.get("inst", false)) else "Install the game", "install"],
	]
	var sbh := minf(64.0, (ch - 36.0) / 4.0 - 10.0)
	for i in sets.size():
		var sb := _btn(str(sets[i][0]), str(sets[i][1]), null, "alt", Vector2(rx + (i % 2) * (bw2 + 12.0), y0 + (i / 2) * (sbh + 10.0)), Vector2(bw2, sbh), 21)
		sb.add_theme_font_override("font", font3)
		for st in ["normal", "hover", "focus"]:
			sb.add_theme_stylebox_override(st, _box(Color(S1.r, S1.g, S1.b, 0.97), 14, LINE))
		menu.add_child(sb)
		items.append([sb, Vector2(80, 0), 0.03 * i])
	var ver := _label("Version  " + str(info.get("version", "")), 18, MUT, font3)
	ver.position = Vector2(rx + 4, y0 + ch - 26.0)
	menu.add_child(ver)

static func _grade_col(g: String) -> Color:
	return {"A": Color(1.0, 0.84, 0.25), "B": Color(0.45, 0.9, 0.5), "C": Color(0.85, 0.9, 0.88), "D": Color(1.0, 0.62, 0.25), "E": Color(0.95, 0.4, 0.35), "F": Color(0.95, 0.3, 0.3)}.get(g, Color.WHITE)

static func _conf_col(c: int) -> Color:
	if c >= 68:
		return Color(0.4, 0.88, 0.5)
	if c >= 50:
		return Color(0.85, 0.92, 0.6)
	if c >= 35:
		return Color(1.0, 0.75, 0.3)
	return Color(0.95, 0.35, 0.3)

# The board's confidence: the number, the mood, a bar with the sack line in a FULL career, and what the board said.
func _board_meter(p: Panel, bd: Dictionary, pw: float) -> void:
	var c := int(bd.get("conf", 50))
	var cl := _label("Confidence", 17, GOLD, font2)
	cl.position = Vector2(20, 14)
	p.add_child(cl)
	var big := _label(str(c), 64, _conf_col(c))
	big.position = Vector2(18, 30)
	p.add_child(big)
	var md := _label(str(bd.get("mood", "")), 24, _conf_col(c))
	md.position = Vector2(110, 52)
	p.add_child(md)
	var chg := int(bd.get("chg", 0))
	var cg := _label(("%s%d AFTER THE LAST MATCH" % ["+" if chg >= 0 else "", chg]) if chg != 0 else "No change after the last match", 16, Color(1, 1, 1, 0.6), font2)
	cg.position = Vector2(112, 82)
	p.add_child(cg)
	var bw := pw - 40.0
	var bar := ColorRect.new()
	bar.color = Color(1, 1, 1, 0.12)
	bar.position = Vector2(20, 116)
	bar.size = Vector2(bw, 14)
	p.add_child(bar)
	var fill := ColorRect.new()
	fill.color = _conf_col(c)
	fill.position = Vector2(20, 116)
	fill.size = Vector2(bw * c / 100.0, 14)
	p.add_child(fill)
	if bool(bd.get("full", false)):
		var sx := 20.0 + bw * int(bd.get("sack_at", 20)) / 100.0
		var sl := ColorRect.new()
		sl.color = Color(0.95, 0.3, 0.3)
		sl.position = Vector2(sx - 1, 110)
		sl.size = Vector2(3, 26)
		p.add_child(sl)
		var st := _label("Sack", 16, Color(0.95, 0.4, 0.35), font2)
		st.position = Vector2(sx - 14, 136)
		p.add_child(st)
	var bl := ColorRect.new()
	bl.color = Color(1, 0.84, 0.25, 0.7)
	bl.position = Vector2(20.0 + bw * 0.8 - 1, 110)
	bl.size = Vector2(2, 26)
	p.add_child(bl)
	var bt := _label("Bonus", 16, GOLD, font2)
	bt.position = Vector2(20.0 + bw * 0.8 - 16, 136)
	p.add_child(bt)
	var exl := _label("THE BOARD EXPECTED YOU TO FINISH ABOUT %s THIS SEASON" % _ord(int(bd.get("ex", 4))), 16, Color(1, 1, 1, 0.6), font2)
	exl.autowrap_mode = TextServer.AUTOWRAP_WORD
	exl.position = Vector2(20, p.size.y - 104)
	exl.size = Vector2(pw - 40.0, 40)
	p.add_child(exl)
	var msg := _label(str(bd.get("msg", "")), 18, Color.WHITE)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.position = Vector2(20, 164)
	msg.size = Vector2(pw - 40.0, 80)
	p.add_child(msg)
	var bn := _label("At 80 or more the board adds 20%% to the %s you win in matches." % _mw() + ("  It does now!" if bool(bd.get("bonus", false)) else ""), 17, GOLD if bool(bd.get("bonus", false)) else Color(1, 1, 1, 0.6), font2)
	bn.autowrap_mode = TextServer.AUTOWRAP_WORD
	bn.position = Vector2(20, p.size.y - 58)
	bn.size = Vector2(pw - 40.0, 44)
	p.add_child(bn)

# One goal from the board: what it is, where it stands now, and a coloured tag.
func _obj_row(p: Panel, tag: String, what: String, now: String, st: String, pw: float, ph: float) -> void:
	var tg := _label(tag, 16, GOLD, font2)
	tg.position = Vector2(20, 10)
	p.add_child(tg)
	var fs := 20
	while fs > 14 and font.get_string_size(what, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > pw - 220.0:
		fs -= 1
	var wl := _label(what, fs, Color.WHITE)
	wl.position = Vector2(20, 28)
	wl.clip_text = true
	wl.size = Vector2(pw - 210.0, 30)
	p.add_child(wl)
	var nl := _label(now, 17, Color(1, 1, 1, 0.7), font2)
	nl.position = Vector2(20, minf(ph - 28.0, 60.0))
	p.add_child(nl)
	var names := {"on": "ON TRACK", "behind": "BEHIND", "done": "DONE", "failed": "FAILED", "missed": "MISSED"}
	var cols := {"on": Color(0.4, 0.88, 0.5), "behind": Color(1.0, 0.65, 0.25), "done": GOLD, "failed": Color(0.95, 0.35, 0.3), "missed": Color(0.95, 0.35, 0.3)}
	var col: Color = cols.get(st, Color.WHITE)
	var chip := Panel.new()
	chip.add_theme_stylebox_override("panel", _box(Color(col.r, col.g, col.b, 0.18), 12, col))
	chip.position = Vector2(pw - 170.0, ph * 0.5 - 20.0)
	chip.size = Vector2(150, 40)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(chip)
	var ct := _label(str(names.get(st, st)), 18, col)
	ct.position = Vector2(0, 8)
	ct.size = Vector2(150, 28)
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(ct)

func _title(text: String, small: String) -> void:
	var t := _label(text, 34, Color.WHITE)
	t.position = Vector2(0, 16)
	t.size = Vector2(size.x, 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(t)
	if small != "":
		var s := _label(small, 20, MUT, font3)
		s.position = Vector2(0, 64)
		s.size = Vector2(size.x, 28)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu.add_child(s)

func _key(k: String) -> void:
	if k == "<":
		_code = _code.substr(0, maxi(_code.length() - 1, 0))
	elif _code.length() < 4:
		_code += k
	if on_action.is_valid():
		on_action.call("key", null)
	var slots := menu.get_node_or_null("slots")
	if slots != null:
		var parts := []
		for i in 4:
			parts.append(_code[i] if i < _code.length() else "_")
		slots.text = "  ".join(parts)
	if _code.length() == 4 and on_action.is_valid():
		on_action.call("code", _code)

# ---------------------------------------------------------------- touch input

func _btn_pos() -> Dictionary:
	var s := size
	return {
		"shoot": [Vector2(s.x - 92, s.y - 92), 56.0],
		"pass": [Vector2(s.x - 218, s.y - 66), 46.0],
		"thru": [Vector2(s.x - 196, s.y - 176), 42.0],
	}

func _cam_rect() -> Rect2:
	return Rect2(size.x - 128, 14, 110, 40)

func _pause_rect() -> Rect2:
	return Rect2(size.x - 124, 14, 44, 40)

func _release_all() -> void:
	_stick_id = -1
	stick = Vector2.ZERO
	for k in _ids.values():
		_set_btn(k, false)
	_ids.clear()

func _input(e: InputEvent) -> void:
	if menu_name != "" or not in_match:
		return
	if e is InputEventScreenTouch:
		var p: Vector2 = e.position
		if e.pressed:
			if _pause_rect().has_point(p):
				ev.append("pause")
				return
			ev.append("tap")
			if not show_controls:
				return
			var b := _btn_pos()
			for k in b:
				if p.distance_to(b[k][0]) < b[k][1] + 14.0:
					_ids[e.index] = k
					_starts[e.index] = p
					if k != "shoot":
						hi_btn = ""
					_set_btn(k, true)
					return
			if p.x < size.x * 0.5 and _stick_id == -1:
				_stick_id = e.index
				_stick_base = p
				_stick_pos = p
				stick = Vector2.ZERO
		else:
			if e.index == _stick_id:
				_stick_id = -1
				stick = Vector2.ZERO
				sprint_down = false
			elif _ids.has(e.index):
				_set_btn(_ids[e.index], false)
				if hi_btn == _ids[e.index]:
					hi_btn = ""
				_ids.erase(e.index)
	elif e is InputEventScreenDrag:
		if _ids.has(e.index) and _ids[e.index] in ["pass", "thru"] and hi_btn == "" and lab_a == "SHOOT":
			# slide the thumb up from PASS or THROUGH: the ball goes high
			var sd: Vector2 = _starts.get(e.index, e.position) - e.position
			if sd.y > 30.0:
				hi_btn = _ids[e.index]
				ev.append("hi")
		if e.index == _stick_id:
			_stick_pos = e.position
			var d := _stick_pos - _stick_base
			if d.length() > STICK_R * SPRINT_R + 26.0:
				# the base follows the thumb so the stick never gets stuck at the edge
				_stick_base = _stick_pos - d.normalized() * (STICK_R * SPRINT_R + 26.0)
				d = _stick_pos - _stick_base
			stick = (d / STICK_R).limit_length(1.0)
			# sprint: pull the thumb out past the outer ring
			sprint_down = d.length() > STICK_R * SPRINT_R
			if stick.length() < 0.16:
				stick = Vector2.ZERO

func _set_btn(k: String, down: bool) -> void:
	if k == "shoot":
		if shoot_down != down:
			ev.append("shoot_down" if down else "shoot_up")
		shoot_down = down
	elif k == "pass":
		if pass_down != down:
			ev.append("pass_down" if down else "pass_up")
		pass_down = down
	elif k == "thru":
		if thru_down != down:
			ev.append("thru_down" if down else "thru_up")
		thru_down = down

# ---------------------------------------------------------------- drawing

func _process(dt: float) -> void:
	_t += dt / maxf(Engine.time_scale, 0.05)
	# the screen changed shape (the phone was turned, the browser bar went away): lay the menu out again
	if size != _last_size:
		_last_size = size
		if menu_name != "":
			_build_menu(menu_name, _info, false)
	bug.visible = in_match and not replay_on and vs_t < 0.0
	if vs_t >= 0.0:
		vs_t += dt / maxf(Engine.time_scale, 0.05)
		if vs_t > vs_len or not in_match:
			vs_t = -1.0
	queue_redraw()

func _draw() -> void:
	if size.y > size.x:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.04, 0.96))
		_text("TURN YOUR PHONE", size * 0.5 - Vector2(0, 10), 30, Color.WHITE)
		_text("The game is played sideways", size * 0.5 + Vector2(0, 28), 18, Color(1, 1, 1, 0.75))
		return
	if not in_match:
		return
	if replay_on:
		var bar := size.y * 0.1
		draw_rect(Rect2(0, 0, size.x, bar), Color(0, 0, 0, 0.9))
		draw_rect(Rect2(0, size.y - bar, size.x, bar), Color(0, 0, 0, 0.9))
		if fmod(_t, 1.0) < 0.65:
			draw_circle(Vector2(34, bar * 0.5), 8.0, Color(0.95, 0.2, 0.2))
		_text("REPLAY", Vector2(92, bar * 0.5 + 9), 24, Color.WHITE)
		_text("tap to skip", Vector2(size.x - 80, size.y - bar * 0.5 + 6), 16, Color(1, 1, 1, 0.7))
		return
	if menu_name != "":
		return
	if vs_t >= 0.0:
		_vs()
		return
	# camera + pause buttons
	var pr := _pause_rect()
	draw_style_box(_box(Color(DARK.r, DARK.g, DARK.b, 0.7), 10), pr)
	draw_rect(Rect2(pr.position + Vector2(14, 11), Vector2(5, 18)), Color(1, 1, 1, 0.9))
	draw_rect(Rect2(pr.position + Vector2(25, 11), Vector2(5, 18)), Color(1, 1, 1, 0.9))
	if not show_controls:
		return
	_minimap()
	var b := _btn_pos()
	if lab_a != "":
		_button(b["shoot"][0], b["shoot"][1], lab_a, shoot_down, Color(0.25, 0.85, 0.4))
	if lab_b != "":
		_button(b["pass"][0], b["pass"][1], lab_b, pass_down, Color(0.95, 0.95, 0.95))
	if lab_a == "SHOOT":
		_button(b["thru"][0], b["thru"][1], "THROUGH", thru_down, Color(0.55, 0.8, 1.0))
		for hk in ["pass", "thru"]:
			# the little arrow says: slide up for a high ball
			var hc: Vector2 = b[hk][0] - Vector2(0, b[hk][1] + 9.0)
			var on: bool = hi_btn == hk
			var hcol := Color(1.0, 0.85, 0.2, 1.0) if on else Color(1, 1, 1, 0.45)
			draw_polyline(PackedVector2Array([hc + Vector2(-9, 5), hc + Vector2(0, -4), hc + Vector2(9, 5)]), hcol, 3.0, true)
			if on:
				draw_arc(b[hk][0], b[hk][1] + 4.0, 0, TAU, 48, hcol, 3.0, true)
				_text("HIGH", hc - Vector2(0, 10), 14, hcol)
	if ctrl_name != "":
		_text(ctrl_name, Vector2(size.x * 0.5, size.y - 138.0 * 68.0 / 105.0 - 20.0), 16, Color(1, 1, 1, 0.9))
	if pro_rt >= 0.0:
		_pro_badge()
	if charge > 0.0:
		var c: Vector2 = b["shoot"][0]
		var col := Color(1.0, 0.9, 0.2).lerp(Color(1.0, 0.25, 0.15), clampf((charge - 0.6) / 0.4, 0.0, 1.0))
		draw_arc(c, b["shoot"][1] + 9.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, col, 7.0, true)
	if _stick_id != -1:
		draw_circle(_stick_base, STICK_R + 8.0, Color(1, 1, 1, 0.10))
		draw_arc(_stick_base, STICK_R + 8.0, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
		# outer ring = sprint. It also shows how much breath is left.
		var sr := STICK_R * SPRINT_R + 12.0
		var scol := (GOLD if stam > 0.3 else Color(0.95, 0.3, 0.2))
		draw_arc(_stick_base, sr, 0, TAU, 56, Color(1, 1, 1, 0.14), 2.0, true)
		draw_arc(_stick_base, sr, -PI * 0.5, -PI * 0.5 + TAU * stam, 56, Color(scol.r, scol.g, scol.b, 0.95 if sprint_down else 0.5), 5.0 if sprint_down else 3.0, true)
		var knob := _stick_base + (_stick_pos - _stick_base).limit_length(STICK_R * SPRINT_R + 12.0) if sprint_down else _stick_base + stick * STICK_R
		draw_circle(knob, 30.0, Color(1.0, 0.86, 0.3, 0.75) if sprint_down else Color(1, 1, 1, 0.55))
	else:
		var hint := Vector2(120, size.y - 110)
		draw_arc(hint, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.16), 2.0, true)
		draw_arc(hint, STICK_R * SPRINT_R + 12.0, -PI * 0.5, -PI * 0.5 + TAU * stam, 56, Color(1.0, 0.84, 0.25, 0.3), 3.0, true)
		draw_circle(hint, 24.0, Color(1, 1, 1, 0.12))

func _minimap() -> void:
	if mm_pts.is_empty():
		return
	var mw := 138.0
	var mh := mw * 68.0 / 105.0
	var o := Vector2((size.x - mw) * 0.5, size.y - mh - 10.0)
	draw_rect(Rect2(o, Vector2(mw, mh)), Color(0.03, 0.12, 0.06, 0.55))
	draw_rect(Rect2(o, Vector2(mw, mh)), Color(1, 1, 1, 0.35), false, 1.0)
	draw_line(o + Vector2(mw * 0.5, 0), o + Vector2(mw * 0.5, mh), Color(1, 1, 1, 0.3), 1.0)
	draw_arc(o + Vector2(mw, mh) * 0.5, mh * 0.14, 0, TAU, 20, Color(1, 1, 1, 0.3), 1.0)
	for p in mm_pts:
		var q := o + Vector2((p.x + 52.5) / 105.0 * mw, (p.y + 34.0) / 68.0 * mh)
		if p.z > 1.5:
			draw_circle(q, 4.2, GOLD)
		else:
			draw_circle(q, 3.4, Color(0, 0, 0, 0.55))
			draw_circle(q, 2.6, _seen(t_cols[0]) if p.z < 0.5 else _seen(t_cols[1]))
	draw_circle(o + Vector2((mm_ball.x + 52.5) / 105.0 * mw, (mm_ball.y + 34.0) / 68.0 * mh), 2.2, Color.WHITE)

func _button(c: Vector2, rad: float, text: String, down: bool, col: Color) -> void:
	var k := 0.92 if down else 1.0
	draw_circle(c, rad * k, Color(col.r, col.g, col.b, 0.5 if down else 0.2))
	draw_arc(c, rad * k, 0, TAU, 48, Color(col.r, col.g, col.b, 0.9), 3.0, true)
	_text(text, c + Vector2(0, 6), 18 if rad > 50.0 else 14, Color(1, 1, 1, 0.95))

# The player career: your rating for this match, live under the score. It glows and shows an arrow when it moves.
func _pro_badge() -> void:
	var r := snappedf(pro_rt, 0.1)
	if _prt_prev < 0.0:
		_prt_prev = r
	elif absf(r - _prt_prev) >= 0.1:
		_prt_dir = signf(r - _prt_prev)
		_prt_prev = r
		_prt_t = 0.0
	_prt_t += get_process_delta_time()
	var col := GREEN if r >= 7.0 else (GOLD if r >= 6.0 else Color(0.95, 0.35, 0.25))
	var rc := Rect2(Vector2(22, 64), Vector2(176, 36))
	var glow := clampf(1.0 - _prt_t / 1.4, 0.0, 1.0)
	draw_style_box(_box(Color(DARK.r, DARK.g, DARK.b, 0.78), 10, col.lerp(Color.WHITE, glow * 0.5) if glow > 0.0 else Color(1, 1, 1, 0.12)), rc)
	draw_string(font2, rc.position + Vector2(12, 25), "MY RATING", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.75))
	var big := 22 + int(round(6.0 * glow))
	draw_string_outline(font, rc.position + Vector2(108, 27), "%.1f" % r, HORIZONTAL_ALIGNMENT_LEFT, -1, big, 4, Color(0, 0, 0, 0.6))
	draw_string(font, rc.position + Vector2(108, 27), "%.1f" % r, HORIZONTAL_ALIGNMENT_LEFT, -1, big, col)
	if glow > 0.0 and _prt_dir != 0.0:
		var c := rc.position + Vector2(162, 18)
		var up := _prt_dir > 0.0
		var ac := Color(GREEN.r, GREEN.g, GREEN.b, glow) if up else Color(0.95, 0.35, 0.25, glow)
		var pts := PackedVector2Array([c + Vector2(-7, 4), c + Vector2(7, 4), c + Vector2(0, -7)]) if up else PackedVector2Array([c + Vector2(-7, -4), c + Vector2(7, -4), c + Vector2(0, 7)])
		draw_colored_polygon(pts, ac)

func _text(t: String, at: Vector2, fs: int, col: Color) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, at - Vector2(w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
	draw_string(font, at - Vector2(w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

# The big PLAY button in the career when two play it together: both tap it, then the match starts.
func _co_play_text(info: Dictionary, solo: String) -> String:
	var r: Array = info.get("co_rdy", [false, false])
	if bool(info.get("assist", false)):
		if bool(r[1]):
			return "READY  ·  WAITING FOR THE MANAGER"
		return "READY  ·  THE MANAGER IS WAITING" if bool(r[0]) else "I AM READY"
	if str(info.get("co_room", "")) != "" and bool(info.get("co_conn", false)):
		if bool(r[0]):
			return "WAITING FOR YOUR FRIEND..."
		return "PLAY  ·  YOUR FRIEND IS READY" if bool(r[1]) else "PLAY TOGETHER"
	return solo

static func _mood_col(m: int) -> Color:
	return Color(0.45, 0.95, 0.55) if m >= 60 else (Color(1, 1, 1, 0.75) if m >= 40 else (Color(1.0, 0.75, 0.3) if m >= 25 else Color(1.0, 0.45, 0.4)))


# ---------------------------------------------------------------- the inbox and the transfer news
func _inbox_page(info: Dictionary, w: float, h: float, items: Array) -> void:
	var c: Dictionary = info.get("car", {})
	var wd: Dictionary = c.get("live", {})
	var wn: Dictionary = wd.get("win", {})
	var sub := "Bids, transfer news and the window"
	if bool(wn.get("open", false)):
		sub = ("Deadline day: the window shuts %s" if bool(wn.get("deadline", false)) else "The window is open until %s") % str(wn.get("ctext", ""))
	elif bool(wd.get("won", false)):
		sub = "The window is shut: it opens on %s" % str(wn.get("otext", ""))
	_title("Inbox", sub)
	menu.add_child(_back("tab", "career"))
	var ib: Array = wd.get("inbox", [])
	if ib.is_empty():
		var el := _label("Nothing yet. News comes in as the days go by.", 22, MUT, font3)
		el.position = Vector2(0, 220)
		el.size = Vector2(w, 30)
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu.add_child(el)
		return
	var sel := int(wd.get("sel", -1))
	var lw := 400.0
	var y0 := 104.0
	var sc := ScrollContainer.new()
	sc.position = Vector2(24, y0)
	sc.size = Vector2(lw, h - y0 - 20)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(sc)
	var box := Control.new()
	var rh := 64.0
	box.custom_minimum_size = Vector2(lw - 12, ib.size() * (rh + 6))
	sc.add_child(box)
	var cur: Dictionary = {}
	for i in ib.size():
		var m: Dictionary = ib[i]
		var on := int(m["id"]) == sel
		if on:
			cur = m
		var open_bid := str(m["k"]) in ["bid", "press", "talk"] and str(m.get("st", "")) == "open"
		var b := _btn("", "mail", int(m["id"]), "alt", Vector2(0, i * (rh + 6)), Vector2(lw - 12, rh), 16)
		b.add_theme_stylebox_override("normal", _box(Color(S1.r, S1.g, S1.b, 0.95) if not on else Color(0.2, 0.32, 0.24, 0.98), 12, GOLD if open_bid else (GREEN if on else LINE)))
		box.add_child(b)
		var ic: Control = _icon({"bid": "mail", "deal": "swap", "window": "cal", "deadline": "cal", "info": "office", "med": "plus", "award": "cup", "press": "mail", "talk": "office"}.get(str(m["k"]), "mail"), 24, GOLD if open_bid or str(m["k"]) == "deadline" else MUT)
		ic.position = Vector2(12, 20)
		b.add_child(ic)
		var tf: Font = font2 if bool(m.get("rd", false)) else font3
		var t := _label(_trim(str(m["t"]), tf, 19, lw - 12 - 60 - (14 if not bool(m.get("rd", false)) else 0)), 19, CHALK if on or not bool(m.get("rd", false)) else MUT, tf)
		t.position = Vector2(48, 6)
		t.clip_text = true
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.size = Vector2(lw - 12 - 60 - (14 if not bool(m.get("rd", false)) else 0), 28)
		b.add_child(t)
		var st := str(m.get("st", ""))
		var stt: String = {"open": "Waiting for your answer", "acc": "You sold him", "rej": "You said no", "gone": "The offer is gone"}.get(st, "") if str(m["k"]) == "bid" else ({"open": "Waiting for your answer", "done": "Answered", "gone": "You did not answer"}.get(st, "") if str(m["k"]) in ["press", "talk"] else "")
		var dl := _label(str(m["date"]) + (("  ·  " + stt) if stt != "" else ""), 16, GOLD if st == "open" else MUT, font3)
		dl.position = Vector2(48, 34)
		dl.clip_text = true
		dl.size = Vector2(lw - 72, 22)
		b.add_child(dl)
		if not bool(m.get("rd", false)):
			var dot := ColorRect.new()
			dot.color = Color(0.86, 0.22, 0.2)
			dot.position = Vector2(lw - 30, 14)
			dot.size = Vector2(10, 10)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(dot)
	# the open mail
	var px := 24.0 + lw + 16.0
	var pw := w - px - 24.0
	var pn := _card_panel(Vector2(px, y0), Vector2(pw, h - y0 - 20))
	items.append([pn, Vector2(40, 0), 0.0])
	if cur.is_empty():
		return
	var hl := _label(str(cur["t"]), 26, CHALK)
	hl.position = Vector2(24, 18)
	hl.clip_text = true
	hl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hl.size = Vector2(pw - 48, 34)
	pn.add_child(hl)
	var dt := _label(str(cur["date"]), 17, MUT, font3)
	dt.position = Vector2(24, 54)
	pn.add_child(dt)
	var ph := h - y0 - 20
	if str(cur["k"]) == "bid":
		var shirt := _shirt(cur.get("ck", []), 64)
		shirt.position = Vector2(24, 88)
		pn.add_child(shirt)
		var cl := _label(str(cur.get("cn", "")), 22, CHALK, font3)
		cl.position = Vector2(104, 92)
		cl.clip_text = true
		cl.size = Vector2(pw - 128, 28)
		pn.add_child(cl)
		var who := "%s  ·  %s %d" % [str(cur["pn"]).capitalize(), str(cur.get("pos", "")), int(cur.get("ovr", 0))] + ("  ·  in your eleven" if bool(cur.get("xi", false)) else "")
		var wl := _label(who, 19, MUT, font3)
		wl.position = Vector2(104, 122)
		wl.clip_text = true
		wl.size = Vector2(pw - 128, 26)
		pn.add_child(wl)
		var ol := _label("They offer", 18, MUT, font3)
		ol.position = Vector2(24, 172)
		pn.add_child(ol)
		var ov := _label(str(cur.get("amt_t", "")), 44, GOLD)
		ov.position = Vector2(24, 194)
		pn.add_child(ov)
		if cur.has("val_t"):
			var vl := _label("His value: " + str(cur["val_t"]), 19, MUT, font3)
			vl.position = Vector2(pw * 0.5, 214)
			pn.add_child(vl)
		var msg := str(c.get("msg", ""))
		if msg != "":
			var ml := _label(msg, 18, GOLD, font3)
			ml.position = Vector2(24, ph - 120)
			ml.clip_text = true
			ml.size = Vector2(pw - 48, 26)
			pn.add_child(ml)
		if str(cur.get("st", "")) == "open":
			var bw := (pw - 48 - 20) / 3.0
			var by := y0 + ph - 84
			var bw4 := (pw - 48 - 30) / 4.0
			menu.add_child(_btn("SELL", "bid_acc", int(cur["id"]), "primary", Vector2(px + 24, by), Vector2(bw4, 62), 22))
			menu.add_child(_btn("SELL + %d%%\nSELL-ON" % Career.SELLON_PCT, "bid_son", int(cur["id"]), "alt", Vector2(px + 34 + bw4, by), Vector2(bw4, 62), 16))
			menu.add_child(_btn("ASK FOR\nMORE", "bid_more", int(cur["id"]), "alt" if int(cur.get("cnt", 0)) == 0 else "off", Vector2(px + 44 + bw4 * 2, by), Vector2(bw4, 62), 16))
			menu.add_child(_btn("SAY NO", "bid_rej", int(cur["id"]), "ghost", Vector2(px + 54 + bw4 * 3, by), Vector2(bw4, 62), 20))
		return
	if str(cur["k"]) in ["press", "talk", "natjob"]:
		var qb := _label(str(cur["b"]), 20, CHALK, font3)
		qb.autowrap_mode = TextServer.AUTOWRAP_WORD
		qb.position = Vector2(24, 88)
		qb.size = Vector2(pw - 48, 56)
		pn.add_child(qb)
		var opts: Array = cur.get("opts", [])
		var oy := 156.0
		var oh := minf(62.0, (ph - oy - 70) / maxf(opts.size(), 1) - 8)
		var stq := str(cur.get("st", ""))
		for k in opts.size():
			var picked := stq == "done" and int(cur.get("ans", -1)) == k
			var kind := "alt" if stq == "open" else ("primary" if picked else "off")
			var ob := _btn(str(opts[k][0]), "mail_pick", [int(cur["id"]), k], kind, Vector2(px + 24, y0 + oy + k * (oh + 8)), Vector2(pw - 48, oh), 18)
			if stq != "open":
				ob.disabled = true
			menu.add_child(ob)
		var rt := ""
		if stq == "done":
			rt = str(cur.get("re", ""))
		elif stq == "gone":
			rt = "You did not answer in time. The board noticed." if str(cur["k"]) == "press" else "You never answered him."
		elif stq == "open":
			rt = "Pick an answer." if str(cur["k"]) == "natjob" else "Pick an answer. Your words matter to the players and the board."
		var rl := _label(rt, 19, GOLD if stq == "done" else MUT, font3)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD
		rl.position = Vector2(24, oy + opts.size() * (oh + 8) + 6)
		rl.size = Vector2(pw - 48, 56)
		pn.add_child(rl)
		return
	var body := _label(str(cur["b"]), 20, CHALK, font3)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.position = Vector2(24, 92)
	body.clip_text = true
	body.size = Vector2(pw - 48, ph - 110)
	pn.add_child(body)

func _tnews_page(info: Dictionary, w: float, h: float, items: Array) -> void:
	var c: Dictionary = info.get("car", {})
	var wd: Dictionary = c.get("live", {})
	var dl: Array = wd.get("deals", [])
	_title("Transfer news", "Deals between the clubs in your country. Your league's clubs are marked.")
	menu.add_child(_back("tab", "transfers"))
	if dl.is_empty():
		var el := _label("No deals yet. The clubs trade while a transfer window is open.", 22, MUT, font3)
		el.position = Vector2(0, 220)
		el.size = Vector2(w, 30)
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu.add_child(el)
		return
	var y0 := 104.0
	var sc := ScrollContainer.new()
	sc.position = Vector2(24, y0)
	sc.size = Vector2(w - 48, h - y0 - 20)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(sc)
	var box := Control.new()
	var rh := 60.0
	box.custom_minimum_size = Vector2(w - 60, dl.size() * (rh + 6))
	sc.add_child(box)
	for i in dl.size():
		var x: Dictionary = dl[i]
		var pn := Panel.new()
		pn.add_theme_stylebox_override("panel", _box(Color(S1.r, S1.g, S1.b, 0.95), 12, GREEN if bool(x["near"]) else LINE))
		pn.position = Vector2(0, i * (rh + 6))
		pn.size = Vector2(w - 60, rh)
		pn.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(pn)
		var shirt := _shirt(x.get("kt", []), 40)
		shirt.position = Vector2(14, 10)
		pn.add_child(shirt)
		var n1 := _label("%s  %s  %d" % [str(x["pos"]), str(x["n"]), int(x["ovr"])], 21, CHALK)
		n1.position = Vector2(68, 4)
		n1.clip_text = true
		n1.size = Vector2(330, 28)
		pn.add_child(n1)
		var n2 := _label("%s  ·  age %d" % [str(x["date"]), int(x["age"])], 16, MUT, font3)
		n2.position = Vector2(68, 32)
		pn.add_child(n2)
		var mv := _label(_trim("%s  ›  %s" % [str(x["from"]), str(x["to"])], font3, 19, w - 60 - 410 - 180), 19, CHALK, font3)
		mv.position = Vector2(410, 16)
		mv.clip_text = true
		mv.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		mv.size = Vector2(w - 60 - 410 - 180, 28)
		pn.add_child(mv)
		var fe := _label(str(x["fee"]), 24, GOLD)
		fe.position = Vector2(w - 60 - 170, 14)
		fe.size = Vector2(150, 30)
		fe.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pn.add_child(fe)


# text cut to fit a width, with an ellipsis (a label's own clipping does not work inside a scroll list)
func _trim(text: String, f: Font, fs: int, maxw: float) -> String:
	var sz := maxi(fs, _min_fs)
	if f == null or f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x <= maxw:
		return text
	var t := text
	while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > maxw:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "…"


# ---------------------------------------------------------------- top scorers and the trophy cabinet
func _cab_line(c: Dictionary) -> String:
	var hn: Dictionary = c.get("hon", {})
	var cab: Array = hn.get("cab", [])
	if cab.is_empty():
		return "Trophies, awards and records"
	return "%d honour%s so far" % [cab.size(), "" if cab.size() == 1 else "s"]

func _scorers_page(info: Dictionary, w: float, h: float, items: Array) -> void:
	var c: Dictionary = info.get("car", {})
	var hn: Dictionary = c.get("hon", {})
	_title(str(c.get("lgname", "The league")).capitalize(), "Top scorers this season")
	menu.add_child(_btn("TABLE", "c_table", null, "alt", Vector2(w - 330, 14), Vector2(130, 44), 17))
	menu.add_child(_btn("TOP SCORERS", "scorers", null, "primary", Vector2(w - 192, 14), Vector2(170, 44), 17))
	menu.add_child(_back("tab", "career"))
	var top: Array = hn.get("top", [])
	if top.is_empty():
		var el := _label("No goals yet. The list fills up as the season goes.", 22, MUT, font3)
		el.position = Vector2(0, 220)
		el.size = Vector2(w, 30)
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu.add_child(el)
		return
	var tw := minf(w - 64.0, 900.0)
	var tx := (w - tw) * 0.5
	var y0 := 104.0
	var sc := ScrollContainer.new()
	sc.position = Vector2(tx, y0)
	sc.size = Vector2(tw, h - y0 - 16)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(sc)
	var box := Control.new()
	var rh := 46.0
	box.custom_minimum_size = Vector2(tw - 12, top.size() * (rh + 4))
	sc.add_child(box)
	var place := 0
	var last_g := -1
	for i in top.size():
		var x: Dictionary = top[i]
		if int(x["g"]) != last_g:
			place = i + 1
			last_g = int(x["g"])
		var mine := bool(x["mine"])
		var pn := Panel.new()
		pn.add_theme_stylebox_override("panel", _box(Color(0.2, 0.3, 0.22, 0.95) if mine else Color(S1.r, S1.g, S1.b, 0.92), 10, GOLD if mine else LINE))
		pn.position = Vector2(0, i * (rh + 4))
		pn.size = Vector2(tw - 12, rh)
		pn.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(pn)
		var col := GOLD if mine else CHALK
		var pl := _label(str(place), 21, col, font3)
		pl.position = Vector2(16, 10)
		pn.add_child(pl)
		var sh := _shirt(x.get("k", []), 30)
		sh.position = Vector2(56, 8)
		pn.add_child(sh)
		var nl := _label(_trim("%s  %s" % [str(x["pos"]), str(x["n"])], font3, 21, 260), 21, col, font3)
		nl.position = Vector2(100, 10)
		pn.add_child(nl)
		var cl := _label(_trim(str(x["club"]), font3, 19, tw - 12 - 380 - 110), 19, MUT, font3)
		cl.position = Vector2(380, 12)
		pn.add_child(cl)
		var gl := _label(str(int(x["g"])), 26, col)
		gl.position = Vector2(tw - 12 - 100, 6)
		gl.size = Vector2(80, 34)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pn.add_child(gl)

func _cab_page(info: Dictionary, w: float, h: float, items: Array) -> void:
	var c: Dictionary = info.get("car", {})
	var hn: Dictionary = c.get("hon", {})
	_title("Trophy cabinet", str(c.get("name", "")).capitalize())
	menu.add_child(_back("tab", "club"))
	if hn.is_empty():
		return
	var tab := int(hn.get("tab", 0))
	var nm := ["Trophies", "Awards this season", "Records"]
	var tw := 240.0
	var tx := w * 0.5 - (tw * 3 + 20) * 0.5
	for k in 3:
		menu.add_child(_btn(nm[k].to_upper(), "cab_tab", k, "primary" if k == tab else "alt", Vector2(tx + k * (tw + 10), 100), Vector2(tw, 46), 17))
	var y0 := 160.0
	if tab == 0:
		# the shelf: one cup for each kind of honour, with how many
		var cnt: Dictionary = hn.get("cnt", {})
		var kinds := [["lg", "League titles", GOLD], ["cup", "Cups", GOLD], ["up", "Promotions", GREEN], ["boot", "Golden Boots", GOLD], ["pots", "Player of the Season", CHALK], ["mots", "Manager of the Season", CHALK]]
		var sw := (w - 48 - 5 * 10) / 6.0
		for k in kinds.size():
			var kd: Array = kinds[k]
			var n := int(cnt.get(str(kd[0]), 0))
			var pn := _card_panel(Vector2(24 + k * (sw + 10), y0), Vector2(sw, 150))
			items.append([pn, Vector2(0, 30), 0.04 * k])
			var ic := _icon("cup", 48, kd[2] if n > 0 else Color(1, 1, 1, 0.18))
			ic.position = Vector2(sw * 0.5 - 24, 14)
			pn.add_child(ic)
			var nl := _label(str(n), 34, kd[2] if n > 0 else MUT)
			nl.position = Vector2(0, 62)
			nl.size = Vector2(sw, 40)
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pn.add_child(nl)
			var tl := _label(_trim(str(kd[1]), font3, 16, sw - 12), 16, MUT, font3)
			tl.position = Vector2(0, 108)
			tl.size = Vector2(sw, 24)
			tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pn.add_child(tl)
		var cab: Array = hn.get("cab", [])
		var ly := y0 + 166.0
		if cab.is_empty():
			var el := _label("Nothing in the cabinet yet. Win the league, a cup or an award and it goes here.", 21, MUT, font3)
			el.position = Vector2(24, ly + 20)
			el.size = Vector2(w - 48, 30)
			el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			menu.add_child(el)
			return
		var sc := ScrollContainer.new()
		sc.position = Vector2(24, ly)
		sc.size = Vector2(w - 48, h - ly - 16)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		menu.add_child(sc)
		var box := Control.new()
		box.custom_minimum_size = Vector2(w - 60, cab.size() * 40)
		sc.add_child(box)
		for i in cab.size():
			var e: Dictionary = cab[cab.size() - 1 - i]
			var sl := _label("Season %d" % int(e["s"]), 19, MUT, font3)
			sl.position = Vector2(8, i * 40 + 6)
			box.add_child(sl)
			var hl := _label(_trim(str(e["t"]), font3, 21, w - 60 - 140), 21, GOLD if str(e["k"]) in ["lg", "cup"] else CHALK, font3)
			hl.position = Vector2(130, i * 40 + 4)
			box.add_child(hl)
		return
	if tab == 1:
		var aw: Array = hn.get("aw", [])
		if aw.is_empty():
			var el2 := _label("The first awards come at the end of the month: Player and Manager of the Month.", 21, MUT, font3)
			el2.position = Vector2(24, y0 + 60)
			el2.size = Vector2(w - 48, 30)
			el2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			menu.add_child(el2)
			return
		var sc2 := ScrollContainer.new()
		sc2.position = Vector2(24, y0)
		sc2.size = Vector2(w - 48, h - y0 - 16)
		sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		menu.add_child(sc2)
		var box2 := Control.new()
		var rh := 58.0
		box2.custom_minimum_size = Vector2(w - 60, aw.size() * (rh + 6))
		sc2.add_child(box2)
		for i in aw.size():
			var a: Dictionary = aw[aw.size() - 1 - i]
			var mine := bool(a["mine"])
			var pn2 := Panel.new()
			pn2.add_theme_stylebox_override("panel", _box(Color(0.2, 0.3, 0.22, 0.95) if mine else Color(S1.r, S1.g, S1.b, 0.92), 12, GOLD if mine else LINE))
			pn2.position = Vector2(0, i * (rh + 6))
			pn2.size = Vector2(w - 60, rh)
			pn2.mouse_filter = Control.MOUSE_FILTER_PASS
			box2.add_child(pn2)
			var ic2 := _icon("cup", 30, GOLD if mine else MUT)
			ic2.position = Vector2(14, 14)
			pn2.add_child(ic2)
			var t1 := _label(_trim(str(a["t"]), font3, 21, 380), 21, GOLD if mine else CHALK, font3)
			t1.position = Vector2(58, 4)
			pn2.add_child(t1)
			var t2 := _label(_trim(str(a["v"]), font3, 17, 380), 17, MUT, font3)
			t2.position = Vector2(58, 31)
			pn2.add_child(t2)
			var sh2 := _shirt(a.get("kit", []), 30)
			sh2.position = Vector2(460, 14)
			pn2.add_child(sh2)
			var t3 := _label(_trim(str(a["who"]), font3, 20, w - 60 - 520), 20, CHALK, font3)
			t3.position = Vector2(504, 16)
			pn2.add_child(t3)
		return
	var rec: Array = hn.get("rec", [])
	var cw := (w - 48 - 14) * 0.5
	var rh3 := 56.0
	for i in rec.size():
		var r: Array = rec[i]
		var col_i := i % 2
		var row_i := i / 2
		var pn3 := _card_panel(Vector2(24 + col_i * (cw + 14), y0 + row_i * (rh3 + 8)), Vector2(cw, rh3))
		items.append([pn3, Vector2(0, 20), 0.03 * i])
		var l1 := _label(str(r[0]), 16, MUT, font3)
		l1.position = Vector2(16, 4)
		pn3.add_child(l1)
		var none := str(r[1]) == "None yet"
		var l2 := _label(_trim(str(r[1]), font3, 20, cw - 32), 20, MUT if none else CHALK, font3)
		l2.position = Vector2(16, 26)
		pn3.add_child(l2)


# ---------------------------------------------------------------- the Champions Cup
func _eu_page(info: Dictionary, w: float, h: float, items: Array) -> void:
	var c: Dictionary = info.get("car", {})
	var e: Dictionary = c.get("eu", {})
	var sub := ""
	if bool(e.get("won", false)):
		sub = "You won it: champions of Europe!" if int(e.get("k", 0)) == 0 else "You won it!"
	elif bool(e.get("done", false)):
		sub = "%s won it this season" % str(e.get("win", ""))
	elif bool(e.get("out", false)):
		sub = "You are out. The cup goes on without you."
	elif e.has("opp"):
		sub = "Next: %s v %s, %s" % [str(e.get("rname", "")).capitalize(), str(e["opp"]).capitalize(), str(e.get("day", ""))]
	_title(str(e.get("name", "THE CHAMPIONS CUP")).capitalize(), sub)
	menu.add_child(_back("tab", "career"))
	if e.is_empty():
		return
	var y0 := 100.0
	var rounds: Array = e.get("rounds", [])
	if int(e.get("md", 0)) < 6 or rounds.is_empty():
		# the eight groups, four on each row
		var groups: Array = e.get("groups", [])
		var gw := (w - 48 - 3 * 12) / 4.0
		var gh := (h - y0 - 20 - 12) / 2.0
		for g in groups.size():
			var gx := 24.0 + (g % 4) * (gw + 12)
			var gy := y0 + (g / 4) * (gh + 12)
			var rows: Array = groups[g]
			var mine_g := false
			for r in rows:
				if bool(r[4]):
					mine_g = true
			var pn := Panel.new()
			pn.add_theme_stylebox_override("panel", _box(Color(S1.r, S1.g, S1.b, 0.94), 12, EUBLUE if mine_g else LINE))
			pn.position = Vector2(gx, gy)
			pn.size = Vector2(gw, gh)
			pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu.add_child(pn)
			items.append([pn, Vector2(0, 30), 0.03 * g])
			var gl := _label("Group " + "ABCDEFGH"[g], 18, EUBLUE if mine_g else MUT, font3)
			gl.position = Vector2(12, 6)
			pn.add_child(gl)
			var ph := _label("P   PTS", 16, MUT, font3)
			ph.position = Vector2(gw - 84, 8)
			pn.add_child(ph)
			var rh := (gh - 36) / 4.0
			for k in rows.size():
				var r: Array = rows[k]
				var ry := 32.0 + k * rh
				if k == 2:
					var ln := ColorRect.new()
					ln.color = Color(1, 1, 1, 0.12)
					ln.position = Vector2(10, ry - 2)
					ln.size = Vector2(gw - 20, 1)
					pn.add_child(ln)
				var col := GOLD if bool(r[4]) else CHALK
				var sh := _shirt(r[5], 20)
				sh.position = Vector2(10, ry + rh * 0.5 - 10)
				pn.add_child(sh)
				var nl := _label(_trim(str(r[0]), font3, 17, gw - 130), 17, col, font3)
				nl.position = Vector2(36, ry + rh * 0.5 - 12)
				pn.add_child(nl)
				var pl := _label("%d" % int(r[1]), 17, MUT, font3)
				pl.position = Vector2(gw - 84, ry + rh * 0.5 - 12)
				pn.add_child(pl)
				var pt := _label("%d" % int(r[3]), 18, col, font3)
				pt.position = Vector2(gw - 52, ry + rh * 0.5 - 12)
				pt.size = Vector2(36, 24)
				pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				pn.add_child(pt)
		return
	# the knockout rounds, left to right
	var cw := (w - 48 - 3 * 12) / 4.0
	for k in rounds.size():
		var rd: Dictionary = rounds[k]
		var x := 24.0 + k * (cw + 12)
		var now := bool(rd.get("now", false))
		var hl := _label(str(rd["name"]).capitalize(), 18, EUBLUE if now else MUT, font3)
		hl.position = Vector2(x + 4, y0)
		menu.add_child(hl)
		var ties: Array = rd["ties"]
		var th := minf(56.0, (h - y0 - 40 - ties.size() * 6) / maxf(ties.size(), 1))
		for i in ties.size():
			var t: Array = ties[i]
			var ty := y0 + 30 + i * (th + 6)
			var pn2 := Panel.new()
			pn2.add_theme_stylebox_override("panel", _box(Color(S1.r, S1.g, S1.b, 0.94), 10, GOLD if bool(t[4]) else LINE))
			pn2.position = Vector2(x, ty)
			pn2.size = Vector2(cw, th)
			pn2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu.add_child(pn2)
			for side in 2:
				var nm := _label(_trim(str(t[side]), font3, 16, cw - 50), 16, GOLD if bool(t[4]) else CHALK, font3)
				nm.position = Vector2(10, 4 + side * (th * 0.5 - 2))
				pn2.add_child(nm)
				if int(t[2]) >= 0:
					var sc := _label(str(int(t[2 + side])), 17, CHALK, font3)
					sc.position = Vector2(cw - 34, 4 + side * (th * 0.5 - 2))
					sc.size = Vector2(24, 22)
					sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					pn2.add_child(sc)

# ---------------------------------------------------------------- the player career
func _tab_league(info: Dictionary, w: float, y0: float, ch: float, items: Array) -> void:
	var c: Dictionary = info.get("car", {})
	var cp: Dictionary = c.get("cup", {})
	var eu: Dictionary = c.get("eu", {})
	var defs := [
		["The table", "%s  ·  %s" % [str(c.get("lgname", "")).capitalize(), _ord(int(c.get("rank", 1))).to_lower()], "c_table", "table", GREEN],
		["Top scorers", "Who has the most goals", "scorers", "play"],
		["The cup", str(cp.get("cname", "The cup")).capitalize(), "cup", "cup", GOLD],
		["Trophy cabinet", "Trophies, awards and records", "cab", "cup"],
	]
	if not eu.is_empty():
		defs.append([str(eu.get("name", "THE CHAMPIONS CUP")).capitalize().trim_prefix("The "), "Europe's big cup" if int(eu.get("k", 0)) == 0 else "Europe's second cup, Thursdays", "eu", "cup", EUBLUE])
	defs.append(["Calendar", ("Next: " + str(c.get("ndate", ""))) if str(c.get("ndate", "")) != "" else "The season", "cal", "cal"])
	_tiles(defs, 24, y0, w - 48, ch, 3, items)

func _pro_bar(parent: Control, pos: Vector2, wd: float, v: float, col: Color) -> void:
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.1)
	bg.position = pos
	bg.size = Vector2(wd, 10)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var fg := ColorRect.new()
	fg.color = col
	fg.position = pos
	fg.size = Vector2(wd * clampf(v, 0.0, 1.0), 10)
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fg)

func _tab_pro(info: Dictionary, w: float, y0: float, ch: float, items: Array) -> void:
	var p: Dictionary = info.get("pro", {})
	if p.is_empty():
		return
	if bool(p.get("need2", false)):
		# the friend's phone, the first time: make your own player for this club
		var pnl := _card_panel(Vector2(24, y0), Vector2(w - 48, ch))
		items.append([pnl, Vector2(0, 40), 0.0])
		var t1 := _label("Make your player", 30, CHALK)
		t1.position = Vector2(24, 16)
		pnl.add_child(t1)
		var t2 := _label("You play this career together: each of you is one player at the club.", 19, MUT, font3)
		t2.position = Vector2(24, 58)
		t2.size = Vector2(w - 96, 26)
		pnl.add_child(t2)
		var bw := (w - 48 - 48 - 24) / 3.0
		menu.add_child(_btn("NAME:  " + (str(p["n2"]) if str(p["n2"]) != "" else "tap to choose"), "p_name", null, "alt", Vector2(48, y0 + 104), Vector2(w - 96, 60), 20))
		var poss := [["DF", "DEFENDER"], ["MF", "MIDFIELDER"], ["FW", "FORWARD"]]
		for i in 3:
			var on := str(p["pos2"]) == str(poss[i][0])
			menu.add_child(_btn(str(poss[i][1]), "p_pos", poss[i][0], "primary" if on else "alt", Vector2(48 + i * (bw + 12), y0 + 180), Vector2(bw, 58), 22))
		var ok := str(p["n2"]) != ""
		menu.add_child(_btn("JOIN THE CLUB" if ok else "CHOOSE A NAME FIRST", "p2_make" if ok else "p_name", null, "primary" if ok else "off", Vector2(48, y0 + ch - 92), Vector2(w - 96, 70), 28))
		return
	var gap := 14.0
	var lw := (w - 48.0 - gap) * 0.48
	var lp := _card_panel(Vector2(24, y0), Vector2(lw, ch))
	items.append([lp, Vector2(-60, 0), 0.0])
	var ov := _label(str(int(p["ovr"])), 64, GOLD)
	ov.position = Vector2(22, 4)
	lp.add_child(ov)
	var nm := _label(str(p["n"]).capitalize(), 30, CHALK)
	nm.position = Vector2(118, 12)
	nm.clip_text = true
	nm.size = Vector2(lw - 140, 38)
	lp.add_child(nm)
	var pnm: String = {"DF": "Defender", "MF": "Midfielder", "FW": "Forward"}.get(str(p["pos"]), str(p["pos"]))
	var meta := _label("%s  ·  %d  ·  can reach %d" % [pnm, int(p["age"]), int(p["pot"])], 19, MUT, font3)
	meta.position = Vector2(118, 52)
	meta.size = Vector2(lw - 140, 26)
	meta.clip_text = true
	lp.add_child(meta)
	var flt := "Form %s  ·  Fitness %d%%  ·  %s" % [Career.form_name(int(p["fm"])).to_lower(), int(p["cond"]), str(p["club"])] + (("  ·  with " + str(p["mate"])) if bool(p.get("together", false)) else "")
	var fl := _label(_trim(flt, font3, 19, lw - 44), 19, MUT, font3)
	fl.position = Vector2(22, 92)
	fl.size = Vector2(lw - 44, 26)
	fl.clip_text = true
	lp.add_child(fl)
	var tp := int(p["tp"])
	var sn := (["Diving", "Handling", "Kicking", "Reflexes"] if str(p.get("pos", "")) == "GK" else ["Pace", "Shooting", "Passing", "Defending"])
	var st: Array = p["st"]
	var cost: Array = p.get("cost", [1, 1, 1, 1])
	var dp: Array = p.get("dp", [0, 0, 0, 0])
	var drill := int(p.get("drill", -1))
	var top := bool(p.get("top", false))
	var sy := 126.0
	var rowh := minf(56.0, (ch - sy - 128.0) / 4.0)
	for i in 4:
		var y := sy + i * rowh
		var lb := _label("%s  %d" % [sn[i], int(st[i])], 21, CHALK, font3)
		lb.position = Vector2(22, y)
		lp.add_child(lb)
		var bw := lw - 44 - 172
		_pro_bar(lp, Vector2(22, y + 30), bw, int(st[i]) / 99.0, GREEN if int(st[i]) >= 70 else GOLD)
		if i == drill:
			# the drill you train: its bar fills after every match
			_pro_bar(lp, Vector2(22, y + 40), bw, int(dp[i]) / 100.0, Color(0.62, 0.45, 0.95))
		var on := i == drill
		var trb := _btn("TRAINING" if on else "TRAIN", "p_drill", i, "alt" if on else "ghost", Vector2(24 + lw - 22 - 166, y0 + y + 4), Vector2(104, 40), 15)
		if on:
			trb.add_theme_color_override("font_color", Color(0.78, 0.66, 1.0))
		menu.add_child(trb)
		var can := tp >= int(cost[i]) and not top and int(st[i]) < 97
		var pb := _btn("+%d" % int(cost[i]) if tp > 0 else "+", "p_spend", i, "primary" if can else "off", Vector2(24 + lw - 22 - 56, y0 + y + 4), Vector2(54, 40), 18)
		menu.add_child(pb)
	var xy := sy + 4 * rowh + 4
	var need := maxi(int(p.get("need", 100)), 1)
	var lvl := _label("Level %d" % int(p.get("lv", 1)), 21, CHALK, font3)
	lvl.position = Vector2(22, xy)
	lp.add_child(lvl)
	var xpl := _label("%d / %d XP" % [int(p["pxp"]), need], 17, MUT, font3)
	xpl.position = Vector2(lw - 22 - 200, xy + 2)
	xpl.size = Vector2(200, 24)
	xpl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lp.add_child(xpl)
	_pro_bar(lp, Vector2(22, xy + 30), lw - 44, int(p["pxp"]) / float(need), Color(0.62, 0.45, 0.95))
	var hint := ""
	if str(p.get("msg", "")) != "":
		hint = str(p["msg"])
	elif top:
		hint = "You are at your best. Train and play to keep it."
	elif tp > 0:
		hint = "%d skill point%s: tap + (costs more above 70 and 80)" % [tp, "" if tp == 1 else "s"]
	else:
		hint = "Play well, score and reach your goals for XP. A level gives %d points." % 2
	var xl := _label(_trim(hint, font3, 18, lw - 44), 18, GOLD if (tp > 0 or str(p.get("msg", "")) != "") else MUT, font3)
	xl.position = Vector2(22, xy + 42)
	xl.size = Vector2(lw - 44, 24)
	lp.add_child(xl)
	var abn: Array = p.get("ab", [])
	var abt := "Skills: " + (", ".join(PackedStringArray(abn)) if not abn.is_empty() else "none yet")
	var sb := _btn(_trim(abt, font3, 18, lw - 44 - 40), "p_skills", null, "ghost", Vector2(46, y0 + xy + 72), Vector2(lw - 44, 44), 18)
	menu.add_child(sb)
	# right: the manager, the season, the goals
	var rx := 24.0 + lw + gap
	var rw := w - rx - 24.0
	var th := 92.0
	var tc := _card_panel(Vector2(rx, y0), Vector2(rw, th))
	items.append([tc, Vector2(80, 0), 0.04])
	var tr := int(p["trust"])
	var tl := _label("Manager's trust", 22, CHALK, font3)
	tl.position = Vector2(20, 12)
	tc.add_child(tl)
	var tv := _label("%d" % tr, 22, _conf_col(tr), font3)
	tv.position = Vector2(rw - 120, 12)
	tv.size = Vector2(100, 28)
	tv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tc.add_child(tv)
	_pro_bar(tc, Vector2(20, 48), rw - 40, tr / 100.0, _conf_col(tr))
	var tx := _label("He picks the team: good ratings make him trust you", 16, MUT, font3)
	tx.position = Vector2(20, 64)
	tx.size = Vector2(rw - 40, 22)
	tx.clip_text = true
	tc.add_child(tx)
	var ss: Dictionary = p["ss"]
	var sy2 := y0 + th + gap
	var sh := 104.0
	var sc := _card_panel(Vector2(rx, sy2), Vector2(rw, sh))
	items.append([sc, Vector2(80, 0), 0.08])
	var cells := [["Matches", str(int(ss["apps"]))], ["Goals", str(int(ss["g"]))], ["Assists", str(int(ss["a"]))], ["Rating", "%.1f" % float(p["avg"]) if int(ss["apps"]) > 0 else "-"]]
	var cw := (rw - 20) / 4.0
	for i in 4:
		var v := _label(str(cells[i][1]), 34, CHALK)
		v.position = Vector2(10 + i * cw, 10)
		v.size = Vector2(cw, 40)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sc.add_child(v)
		var k := _label(str(cells[i][0]), 17, MUT, font3)
		k.position = Vector2(10 + i * cw, 52)
		k.size = Vector2(cw, 22)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sc.add_child(k)
	var rl: Array = p.get("rt", [])
	var rtx := "Last ratings:  " + ("  ".join(rl.slice(maxi(rl.size() - 6, 0)).map(func(x): return "%.1f" % float(x))) if not rl.is_empty() else "none yet")
	var rlt := _label(rtx, 17, MUT, font3)
	rlt.position = Vector2(14, 76)
	rlt.size = Vector2(rw - 28, 22)
	rlt.clip_text = true
	sc.add_child(rlt)
	var oy := sy2 + sh + gap
	var oh := y0 + ch - oy
	var oc := _card_panel(Vector2(rx, oy), Vector2(rw, oh))
	items.append([oc, Vector2(80, 0), 0.12])
	var ot := _label("This season's goals", 21, CHALK, font3)
	ot.position = Vector2(20, 10)
	oc.add_child(ot)
	var obj: Array = p.get("obj", [])
	for i in obj.size():
		var o: Array = obj[i]
		var done := bool(o[3])
		var vt := ("%.1f" % float(o[1])) if float(o[2]) < 20.0 and float(o[2]) != floor(float(o[2])) else str(int(o[1]))
		var ol := _label(("Done:  " if done else "") + "%s  (%s)" % [str(o[0]), vt], 19, GREEN if done else CHALK, font3)
		ol.position = Vector2(20, 42 + i * 30)
		ol.size = Vector2(rw - 40, 26)
		ol.clip_text = true
		oc.add_child(ol)
	if str(p.get("offer", "")) != "":
		var of := _label("You join %s when the season ends" % str(p["offer"]), 19, GOLD, font3)
		of.position = Vector2(20, oh - 34)
		of.size = Vector2(rw - 40, 26)
		of.clip_text = true
		oc.add_child(of)


# your player's skills: bought with skill points, two at most, the second from rating 70
func _pro_ab_page(info: Dictionary, w: float, h: float, items: Array) -> void:
	var p: Dictionary = info.get("pro", {})
	_title("Your skills", "Spend skill points on what makes you special. Two at most, the second opens at rating 70.")
	menu.add_child(_back("tab", "pro"))
	var tpl := _label("%d skill point%s" % [int(p.get("tp", 0)), "" if int(p.get("tp", 0)) == 1 else "s"], 26, GOLD)
	tpl.position = Vector2(w - 300, 14)
	tpl.size = Vector2(276, 34)
	tpl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu.add_child(tpl)
	var lst: Array = p.get("abl", [])
	var y0 := 104.0
	var cols := 2
	var gap := 12.0
	var cw := (w - 48 - gap) / cols
	var rows := int(ceil(lst.size() / float(cols)))
	var rh := minf(96.0, (h - y0 - 56 - gap * (rows - 1)) / maxf(rows, 1))
	for i in lst.size():
		var a: Dictionary = lst[i]
		var x := 24.0 + (i % cols) * (cw + gap)
		var y := y0 + (i / cols) * (rh + gap)
		var pn := _card_panel(Vector2(x, y), Vector2(cw, rh))
		items.append([pn, Vector2(0, 30), 0.03 * i])
		var nl := _label(str(a["n"]), 22, GOLD if str(a["why"]) == "yours" else CHALK, font3)
		nl.position = Vector2(18, 10)
		pn.add_child(nl)
		var tl := _label(_trim(str(a["t"]), font3, 17, cw - 190), 17, MUT, font3)
		tl.position = Vector2(18, 42)
		tl.size = Vector2(cw - 190, 24)
		pn.add_child(tl)
		var why := str(a["why"])
		var bt := "YOURS" if why == "yours" else ("TWO ALREADY" if why == "full" else (why.to_upper() if why != "" else "%d POINTS" % int(a["cost"])))
		menu.add_child(_btn(bt, "p_learn", str(a["k"]), "primary" if bool(a["ok"]) else "off", Vector2(x + cw - 160, y + rh * 0.5 - 24), Vector2(144, 48), 17))
	if str(p.get("msg", "")) != "":
		var ml := _label(str(p["msg"]), 19, GOLD, font3)
		ml.position = Vector2(24, h - 44)
		ml.size = Vector2(w - 48, 26)
		menu.add_child(ml)

# a new player career: your name, your position and the club you start at
func _pro_start_page(info: Dictionary, w: float, h: float, items: Array) -> void:
	var pn: Dictionary = info.get("pro_new", {})
	_title("Player career", "Be one player. Start at a small club and earn your place in the team.")
	menu.add_child(_back("tab", "play"))
	var y0 := 104.0
	var lw := 340.0
	var nb := _btn("NAME:  " + (str(pn.get("n", "")) if str(pn.get("n", "")) != "" else "tap to choose"), "p_name", null, "alt", Vector2(24, y0), Vector2(lw, 60), 20)
	menu.add_child(nb)
	var pl := _label("Your position", 20, MUT, font3)
	pl.position = Vector2(24, y0 + 76)
	menu.add_child(pl)
	var poss := [["DF", "Defender"], ["MF", "Midfielder"], ["FW", "Forward"]]
	for i in 3:
		var on := str(pn.get("pos", "FW")) == str(poss[i][0])
		var b := _btn(str(poss[i][1]).to_upper(), "p_pos", poss[i][0], "primary" if on else "alt", Vector2(24, y0 + 108 + i * 66), Vector2(lw, 58), 22)
		menu.add_child(b)
	var hint := _label("You start at 18, rated 60, and can reach 88.", 18, MUT, font3)
	hint.position = Vector2(24, y0 + 312)
	hint.size = Vector2(lw, 50)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	menu.add_child(hint)
	# the clubs
	var rx := 24.0 + lw + 24.0
	var rw := w - rx - 24.0
	var cl := _label("Your first club", 20, MUT, font3)
	cl.position = Vector2(rx, y0 - 4)
	menu.add_child(cl)
	var picks: Array = pn.get("picks", [])
	var gap := 12.0
	var cw := (rw - gap) * 0.5
	var chh := 74.0
	for i in picks.size():
		var pk: Dictionary = picks[i]
		var on := int(pn.get("c", -1)) == int(pk["c"])
		var pos := Vector2(rx + (i % 2) * (cw + gap), y0 + 26 + (i / 2) * (chh + gap))
		var b := _btn("", "p_club", int(pk["c"]), "primary" if on else "alt", pos, Vector2(cw, chh), 18)
		menu.add_child(b)
		var sh := _shirt(pk["k"], 50)
		sh.position = Vector2(12, 12)
		b.add_child(sh)
		var n1 := _label(str(pk["n"]), 21, Color(0.04, 0.1, 0.06) if on else CHALK, font3)
		n1.position = Vector2(74, 10)
		n1.size = Vector2(cw - 84, 28)
		n1.clip_text = true
		b.add_child(n1)
		var n2 := _label(str(pk["lg"]), 17, Color(0.04, 0.1, 0.06) if on else MUT, font3)
		n2.position = Vector2(74, 40)
		n2.size = Vector2(cw - 84, 24)
		n2.clip_text = true
		b.add_child(n2)
	var by := h - 86.0
	menu.add_child(_btn("OTHER CLUBS", "p_more", null, "ghost", Vector2(rx, by), Vector2(cw, 66), 20))
	var ok := int(pn.get("c", -1)) >= 0 and str(pn.get("n", "")) != ""
	var gb := _btn("START" if ok else ("PICK A CLUB" if str(pn.get("n", "")) != "" else "CHOOSE A NAME"), "p_go" if ok else "p_name" if str(pn.get("n", "")) == "" else "p_more", null, "primary" if ok else "off", Vector2(rx + cw + gap, by), Vector2(cw, 66), 26)
	menu.add_child(gb)


# ---------------------------------------------------------------- tactics before the match
const TAC_N := [["Park the bus", "Defensive", "Balanced", "Attacking", "All out attack"], ["Low", "Mid", "High"], ["Narrow", "Normal", "Wide"]]

func _tac_short(t: Array) -> String:
	return "%s  ·  %s press  ·  %s" % [TAC_N[0][clampi(int(t[0]), 0, 4)], TAC_N[1][clampi(int(t[1]), 0, 2)], TAC_N[2][clampi(int(t[2]), 0, 2)]]

func _tac_page(info: Dictionary, w: float, h: float, items: Array) -> void:
	var c: Dictionary = info.get("car", {})
	var t: Array = c.get("tac", [2, 1, 1])
	var o: Array = c.get("otac", [2, 1, 1])
	var opp := str(c.get("opp", "")).capitalize()
	_title("Tactics", "How your team plays. It counts when you play the match and when you simulate it.")
	var rows := [
		["Mentality", ["Bus", "Defend", "Balanced", "Attack", "All out"], ["Everyone behind the ball: few goals either way", "Sit a bit deeper, hit them on the break",
			"A bit of both", "Push up and get men forward, but it leaves room behind", "Throw everything forward: goals at both ends"]],
		["Pressing", ["Low", "Mid", "High"], ["Wait in your own half and keep your shape. Saves legs", "Close them down in your half and after you lose it",
			"Hunt the ball all over the pitch. Best for the better side, and it tires your men"]],
		["Width", ["Narrow", "Normal", "Wide"], ["Stay compact through the middle: hard to play through", "The usual shape",
			"Stretch the pitch: good against a deep, narrow side"]]]
	var y := 112.0
	var ph := 128.0
	for ri in 3:
		var r: Array = rows[ri]
		var cur := clampi(int(t[ri]), 0, (r[1] as Array).size() - 1)
		var pn := _card_panel(Vector2(48, y), Vector2(w - 96, ph - 10))
		items.append([pn, Vector2(0, 40), 0.05 * ri])
		var tl := _label(str(r[0]), 24, CHALK)
		tl.position = Vector2(24, 10)
		pn.add_child(tl)
		var dl := _label(_trim(str(r[2][cur]), font3, 18, w - 96 - 220), 18, MUT, font3)
		dl.position = Vector2(200, 14)
		dl.size = Vector2(w - 96 - 220, 26)
		pn.add_child(dl)
		var n: int = (r[1] as Array).size()
		var bw := (w - 96 - 48 - 12 * (n - 1)) / float(n)
		for k in n:
			var b := _btn(str(r[1][k]).to_upper(), "tac_set", [ri, k], "primary" if k == cur else "alt", Vector2(48 + 24 + k * (bw + 12), y + 52), Vector2(bw, 50), 19)
			menu.add_child(b)
		y += ph
	if opp != "":
		var sc := _label(_trim("Scout:  %s will most likely play %s" % [opp, _tac_short(o).to_lower()], font3, 19, w - 140), 19, GOLD, font3)
		sc.position = Vector2(64, y + 4)
		sc.size = Vector2(w - 128, 28)
		menu.add_child(sc)
	menu.add_child(_back("tab", "career"))


# ---------------------------------------------------------------- the national team
func _nat_page(info: Dictionary, w: float, h: float, items: Array) -> void:
	var np: Dictionary = (info.get("car", {}) as Dictionary).get("natp", {})
	menu.add_child(_back("tab", "club"))
	if np.is_empty() or not bool(np.get("job", false)):
		_title("National team", "No country has asked you yet")
		var pn0 := _card_panel(Vector2(w * 0.5 - 380, 140), Vector2(760, 230))
		items.append([pn0, Vector2(0, 30), 0.0])
		var ic0 := _icon("flag", 64, Color(0.95, 0.36, 0.33))
		ic0.position = Vector2(348, 24)
		pn0.add_child(ic0)
		var tx0 := _label("Countries look for a manager who wins. Win matches and trophies, and an offer comes to your inbox during the season. You can manage a country next to your club." + ("\nThis season's offer is in your inbox." if bool(np.get("off", false)) else ""), 21, MUT, font3)
		tx0.autowrap_mode = TextServer.AUTOWRAP_WORD
		tx0.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tx0.position = Vector2(30, 100)
		tx0.size = Vector2(700, 120)
		pn0.add_child(tx0)
		return
	var st: Dictionary = np.get("st", {})
	_title(str(np["n"]).capitalize(), "Rated %d  ·  played %d, won %d, drew %d, lost %d" % [int(np["rating"]), int(st.get("p", 0)), int(st.get("w", 0)), int(st.get("d", 0)), int(st.get("l", 0))])
	var sh := _shirt(np.get("kit", ["888888"]), 52)
	sh.position = Vector2(w - 96, 22)
	menu.add_child(sh)
	var tab := int(np.get("tab", 0))
	var nm := ["Squad", "Group and matches", "The job"]
	var tw := 240.0
	var tx := w * 0.5 - (tw * 3 + 20) * 0.5
	for k in 3:
		menu.add_child(_btn(nm[k].to_upper(), "nat_tab", k, "primary" if k == tab else "alt", Vector2(tx + k * (tw + 10), 100), Vector2(tw, 46), 17))
	var y0 := 160.0
	if tab == 0:
		# left: the 23 you called up (tap to send home); right: the men you could call up (tap to call)
		var lw := (w - 48 - 14) * 0.5
		var hl := _label("Called up: %d of 23  ·  %d from your club" % [int(np["nsq"]), int(np["nmine"])], 19, GOLD, font3)
		hl.position = Vector2(28, y0)
		menu.add_child(hl)
		var hr := _label("Also available", 19, MUT, font3)
		hr.position = Vector2(24 + lw + 18, y0)
		menu.add_child(hr)
		var ab := _btn("BEST 23", "nat_auto", null, "ghost", Vector2(24 + lw - 130, y0 - 6), Vector2(130, 36), 15)
		menu.add_child(ab)
		for side in 2:
			var rows: Array = np.get("sq" if side == 0 else "pool", [])
			var sc := ScrollContainer.new()
			sc.position = Vector2(24 + side * (lw + 14), y0 + 34)
			sc.size = Vector2(lw, h - y0 - 34 - 14)
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			menu.add_child(sc)
			var box := Control.new()
			var rh := 46.0
			box.custom_minimum_size = Vector2(lw - 12, rows.size() * (rh + 6))
			sc.add_child(box)
			for i in rows.size():
				var r: Dictionary = rows[i]
				var b := _btn("", "nat_pick", str(r["key"]), "alt", Vector2(0, i * (rh + 6)), Vector2(lw - 12, rh), 16)
				var bc := GREEN if bool(r["xi"]) and side == 0 else (GOLD if bool(r["mine"]) else LINE)
				b.add_theme_stylebox_override("normal", _box(Color(S1.r, S1.g, S1.b, 0.95), 10, bc))
				box.add_child(b)
				var pl := _label(str(r["pos"]), 17, MUT, font3)
				pl.position = Vector2(12, 11)
				b.add_child(pl)
				var nl := _label(_trim(str(r["n"]) + ("  (your club)" if bool(r["mine"]) else ""), font3, 18, lw - 12 - 170), 18, GOLD if bool(r["mine"]) else CHALK, font3)
				nl.position = Vector2(56, 10)
				b.add_child(nl)
				var ol := _label(("inj" if bool(r["inj"]) else str(int(r["ovr"]))), 20, Color(0.92, 0.36, 0.33) if bool(r["inj"]) else CHALK)
				ol.position = Vector2(lw - 12 - 100, 8)
				ol.size = Vector2(44, 28)
				ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				b.add_child(ol)
				var sg := _label("−" if side == 0 else "+", 24, MUT if side == 0 else GREEN)
				sg.position = Vector2(lw - 12 - 40, 4)
				b.add_child(sg)
		return
	if tab == 1:
		var lw2 := (w - 48 - 14) * 0.55
		var pn := _card_panel(Vector2(24, y0), Vector2(lw2, h - y0 - 14))
		items.append([pn, Vector2(0, 30), 0.0])
		var gl := _label(str(np.get("gname", "")), 20, GOLD, font3)
		gl.position = Vector2(18, 10)
		pn.add_child(gl)
		var cols := [["P", "p"], ["W", "w"], ["D", "d"], ["L", "l"], ["+/-", "gd"], ["Pts", "pts"]]
		for k in cols.size():
			var hlb := _label(str(cols[k][0]), 16, MUT, font3)
			hlb.position = Vector2(lw2 - 330 + k * 52, 42)
			hlb.size = Vector2(46, 22)
			hlb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pn.add_child(hlb)
		var grp: Array = np.get("grp", [])
		for i in grp.size():
			var g: Dictionary = grp[i]
			var yy := 70.0 + i * 40.0
			var strip := ColorRect.new()
			strip.color = Color("#" + str((g["k"] as Array)[0]))
			strip.position = Vector2(18, yy + 6)
			strip.size = Vector2(6, 22)
			pn.add_child(strip)
			var nl2 := _label("%d  %s" % [i + 1, str(g["n"])], 20, GOLD if bool(g["me"]) else CHALK, font3)
			nl2.position = Vector2(32, yy)
			pn.add_child(nl2)
			for k in cols.size():
				var v := _label(str(int(g[str(cols[k][1])])), 19, GOLD if bool(g["me"]) else CHALK, font3)
				v.position = Vector2(lw2 - 330 + k * 52, yy + 2)
				v.size = Vector2(46, 26)
				v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				pn.add_child(v)
		var ko: Array = np.get("ko", [])
		if not ko.is_empty():
			var kl := _label("Knockouts: " + "  ·  ".join(PackedStringArray(ko)), 17, MUT, font3)
			kl.autowrap_mode = TextServer.AUTOWRAP_WORD
			kl.position = Vector2(18, 80 + grp.size() * 40)
			kl.size = Vector2(lw2 - 36, 90)
			pn.add_child(kl)
		var rx := 24 + lw2 + 14
		var rw := w - rx - 24
		var pn2 := _card_panel(Vector2(rx, y0), Vector2(rw, h - y0 - 14))
		items.append([pn2, Vector2(0, 30), 0.05])
		var fl := _label("Your matches", 20, GOLD, font3)
		fl.position = Vector2(18, 10)
		pn2.add_child(fl)
		var fx: Array = np.get("fix", [])
		var shown := 0
		var start := maxi(0, fx.size() - 8)
		for i in range(start, fx.size()):
			var e: Dictionary = fx[i]
			var rs: Array = e["res"]
			var t := "%s  ·  %s %s" % [str(e["date"]), ("" if bool(e["home"]) else "@ "), str(e["opp"])]
			var el := _label(_trim(t, font3, 18, rw - 100), 18, CHALK if bool(e["played"]) else MUT, font3)
			el.position = Vector2(18, 46 + shown * 36)
			pn2.add_child(el)
			var rl := _label("%d-%d" % [int(rs[0]), int(rs[1])] if rs.size() == 2 else "", 18, GREEN if rs.size() == 2 and int(rs[0]) > int(rs[1]) else (Color(0.92, 0.36, 0.33) if rs.size() == 2 and int(rs[0]) < int(rs[1]) else MUT), font3)
			rl.position = Vector2(rw - 80, 46 + shown * 36)
			rl.size = Vector2(62, 24)
			rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pn2.add_child(rl)
			shown += 1
		return
	# the job: how the FA sees you, what you have done, and the way out
	var ok := int(np.get("ok", 50))
	var pn3 := _card_panel(Vector2(24, y0), Vector2(w - 48, h - y0 - 14))
	items.append([pn3, Vector2(0, 30), 0.0])
	var mood := "Delighted" if ok >= 80 else ("Happy" if ok >= 60 else ("Patient" if ok >= 40 else "Worried"))
	var jl := _label("The FA: %s (%d)" % [mood, ok], 24, GOLD if ok >= 40 else Color(0.92, 0.36, 0.33))
	jl.position = Vector2(24, 18)
	pn3.add_child(jl)
	var bar := _bar(Vector2(24, 60), Vector2(w - 96, 10), ok / 100.0, GOLD if ok >= 40 else Color(0.92, 0.36, 0.33))
	pn3.add_child(bar)
	var wl := _label("Manager since season %d. Top two in the qualifying group goes to the %s; a bad campaign costs you the job." % [int(np.get("since", 1)), str(np.get("tname", "")).capitalize()], 19, MUT, font3)
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD
	wl.position = Vector2(24, 84)
	wl.size = Vector2(w - 96, 56)
	pn3.add_child(wl)
	var hs: Array = np.get("hist", [])
	for i in mini(hs.size(), 4):
		var e2: Array = hs[hs.size() - 1 - i]
		var hl2 := _label("Season %d:  %s" % [int(e2[0]), str(e2[1])], 19, CHALK, font3)
		hl2.position = Vector2(24, 148 + i * 32)
		pn3.add_child(hl2)
	var qb := _btn("LEAVE THE JOB", "nat_quit", null, "ghost", Vector2(w - 24 - 24 - 220, h - 14 - 24 - 50), Vector2(220, 50), 17)
	menu.add_child(qb)

func _bar(pos: Vector2, sz: Vector2, v: float, col: Color) -> Control:
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.08), int(sz.y * 0.5), Color(0, 0, 0, 0)))
	bg.position = pos
	bg.size = sz
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fg := Panel.new()
	fg.add_theme_stylebox_override("panel", _box(col, int(sz.y * 0.5), Color(0, 0, 0, 0)))
	fg.size = Vector2(maxf(sz.x * clampf(v, 0.0, 1.0), sz.y), sz.y)
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fg)
	return bg
