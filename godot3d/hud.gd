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
	l.add_theme_font_size_override("font_size", fs)
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
	b.add_theme_font_size_override("font_size", fs)
	var bg := GREEN
	var fg := Color(0.02, 0.1, 0.04)
	var border := Color(0, 0, 0, 0)
	if kind == "alt":
		bg = Color(0.12, 0.17, 0.15, 0.92)
		fg = Color.WHITE
		border = Color(1, 1, 1, 0.22)
	elif kind == "ghost":
		bg = Color(0.05, 0.09, 0.07, 0.7)
		fg = Color(1, 1, 1, 0.92)
		border = Color(1, 1, 1, 0.16)
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

# One squad player as a button: position stripe, name, rating.
func _player_btn(pl: Dictionary, idx: int, pos: Vector2, sz: Vector2, pcol: Dictionary, chosen: bool, wrong: bool) -> Button:
	var nm := str(pl["n"])
	if nm.length() > 8:
		nm = nm.substr(0, 8)
	var b := _btn("", "c_pick", idx, "alt", pos, sz, 15)
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, _box(Color(0.20, 0.25, 0.22, 0.97) if chosen else Color(0.06, 0.10, 0.08, 0.94), 10, GOLD if chosen else Color(1, 1, 1, 0.2)))
	var chip := ColorRect.new()
	chip.color = pcol.get(str(pl["pos"]), Color.WHITE)
	chip.position = Vector2(6, 7)
	chip.size = Vector2(6, sz.y - 14)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(chip)
	var n1 := _label(nm, 15, Color.WHITE)
	n1.position = Vector2(18, 3)
	b.add_child(n1)
	var n2 := _label("%s  %d" % [str(pl["pos"]), int(pl["ovr"])], 13, GOLD if chosen else Color(1, 1, 1, 0.75), font2)
	n2.position = Vector2(18, 24)
	b.add_child(n2)
	if int(pl.get("tp", 0)) > 0:
		var tpd := _label("TP", 11, Color(0.05, 0.08, 0.02))
		tpd.add_theme_stylebox_override("normal", _box(GOLD, 6))
		tpd.position = Vector2(sz.x - 26, sz.y - 20)
		tpd.size = Vector2(22, 15)
		tpd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(tpd)
	if wrong:
		var wr := ColorRect.new()
		wr.color = Color(1.0, 0.85, 0.1)
		wr.position = Vector2(sz.x - 14, 6)
		wr.size = Vector2(8, 8)
		wr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(wr)
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

func _build_menu(n: String, info: Dictionary, anim: bool) -> void:
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
	shade.color = Color(0.0, 0.03, 0.02, 0.5 if n in ["main", "full"] else 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(shade)
	var items := [] # [control, slide-from, delay]
	match n:
		"main":
			_hub(info, w, h, items, anim)
		"myclub":
			var c9: Dictionary = info.get("car", {})
			var isnew := bool(info.get("own_new", false))
			_title("CREATE YOUR CLUB" if isnew else "YOUR CLUB", "")
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
				var pl9 := _label(parts[pi9], 16, GOLD, font2)
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
			var hn9 := _label("Tap the name to change it.", 14, Color(1, 1, 1, 0.65), font2)
			hn9.position = Vector2(rx9, h - 52.0)
			menu.add_child(hn9)
		"quick":
			_title("QUICK MATCH", "A friendly against the computer. Nothing is at stake.")
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
			menu.add_child(_btn("<  BACK", "career", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18))
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
			var k4 := _label("%s   ·   AGE %d   ·   CAN REACH %d" % [str(pk.get("pos", "")), int(pk.get("age", 0)), int(pk.get("pot", 0))], 16, Color(1, 1, 1, 0.8), font2)
			k4.position = Vector2(0, 188)
			k4.size = Vector2(pw, 24)
			k4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pp.add_child(k4)
			var sn2 := ["PACE", "SHOOTING", "PASSING", "DEFENDING"]
			var sv: Array = pk.get("st", [0, 0, 0, 0])
			for si3 in 4:
				var sx := 40.0 + (si3 % 2) * (pw * 0.5 - 20.0)
				var sy := 226.0 + (si3 / 2) * 34.0
				var s1 := _label(sn2[si3], 15, Color(1, 1, 1, 0.75), font2)
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
			var sub0 := _label("DIVISION %d   ·   SEASON %d   ·   ROUND %d OF %d   ·   %s PLACE   ·   TEAM RATING %d" % [int(c.get("div", 4)), int(c.get("season", 1)), mini(int(c.get("round", 0)) + 1, int(c.get("rounds", 14))), int(c.get("rounds", 14)), _ord(int(c.get("rank", 1))), int(c.get("str", 0))], 16, Color(1, 1, 1, 0.8), font2)
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
					var rl := _label(_ord(rks[si]) + " IN THE TABLE", 15, Color(1, 1, 1, 0.7), font2)
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
			var lh := _label("LAST ROUND", 16, GOLD, font2)
			lh.position = Vector2(16, 10)
			lp.add_child(lh)
			var lst: Array = c.get("last", [])
			if lst.is_empty():
				var le := _label("The season starts now. Win matches to earn coins, and your players grow as they play.", 16, Color(1, 1, 1, 0.8), font2)
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
			var bk0 := _btn("<  BACK", "back", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18)
			menu.add_child(bk0)
		"table":
			var c7: Dictionary = info.get("car", {})
			_title(str(c7.get("lgname", "THE LEAGUE")), "Top %d go up.   Bottom %d go down." % [int(c7.get("up", 0)), int(c7.get("down", 0))] if int(c7.get("up", 0)) > 0 and int(c7.get("down", 0)) > 0 else ("The champions win the league.   Bottom %d go down." % int(c7.get("down", 0)) if int(c7.get("down", 0)) > 0 else "Top %d go up." % int(c7.get("up", 0))))
			var c2: Dictionary = info.get("car", {})
			var rows2: Array = c2.get("table", [])
			var tw2 := minf(w - 120.0, 860.0)
			var tx := (w - tw2) * 0.5
			var rh2 := minf(46.0, (h - 110.0) / (rows2.size() + 1.0))
			var cols2 := [0.0, 0.07, 0.52, 0.60, 0.68, 0.76, 0.85, 0.93]
			var heads := ["#", "CLUB", "P", "W", "D", "L", "GD", "PTS"]
			for ci2 in heads.size():
				var hl := _label(heads[ci2], 15, Color(1, 1, 1, 0.65), font2)
				hl.position = Vector2(tx + 16 + cols2[ci2] * tw2, 76)
				menu.add_child(hl)
			for ri in rows2.size():
				var r: Array = rows2[ri]
				var rp := Panel.new()
				rp.add_theme_stylebox_override("panel", _box(Color(0.16, 0.2, 0.12, 0.95) if bool(r[8]) else Color(DARK.r, DARK.g, DARK.b, 0.82), 10, GOLD if bool(r[8]) else Color(0, 0, 0, 0)))
				rp.position = Vector2(tx, 100 + ri * rh2)
				rp.size = Vector2(tw2, rh2 - 5)
				rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
				menu.add_child(rp)
				items.append([rp, Vector2(0, 30), 0.03 * ri])
				var chip3 := ColorRect.new()
				chip3.color = _seen(Color(str(r[9])))
				chip3.position = Vector2(cols2[1] * tw2 - 2, 8)
				chip3.size = Vector2(8, rh2 - 21)
				rp.add_child(chip3)
				var vals := [str(r[0]), str(r[1]), str(r[2]), str(r[3]), str(r[4]), str(r[5]), ("+" if int(r[6]) > 0 else "") + str(r[6]), str(r[7])]
				for ci3 in vals.size():
					var vl := _label(vals[ci3], 19 if ci3 in [1, 7] else 17, GOLD if bool(r[8]) and ci3 in [1, 7] else Color.WHITE, font if ci3 in [0, 1, 7] else font2)
					vl.position = Vector2(16 + cols2[ci3] * tw2, (rh2 - 5) * 0.5 - 14)
					rp.add_child(vl)
			var bk2 := _btn("<  BACK", "career", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18)
			menu.add_child(bk2)
		"car_start":
			var my: Dictionary = info.get("my", {})
			_title("START A CAREER", ("This replaces your career now. " if bool(info.get("car_on", false)) else "") + "Three ways in. The career is its own world with its own money, until you exit it.")
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
				var sl := _label(str(dd[2]), 13, Color(1, 1, 1, 0.65), font2)
				sl.position = Vector2(21, 52)
				sl.size = Vector2(cw - 40, 20)
				sl.clip_text = true
				pn.add_child(sl)
				var yy := 84.0
				for ln in dd[3]:
					var dot := ColorRect.new()
					dot.color = GREEN
					dot.position = Vector2(22, yy + 8)
					dot.size = Vector2(7, 7)
					pn.add_child(dot)
					var bl := _label(str(ln), 16, Color(1, 1, 1, 0.9), font2)
					bl.autowrap_mode = TextServer.AUTOWRAP_WORD
					bl.position = Vector2(38, yy)
					bl.size = Vector2(cw - 58.0, 24)
					pn.add_child(bl)
					yy += 24.0 * ceilf(font2.get_string_size(str(ln), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x / (cw - 64.0)) + 8.0
				var pb := _btn(dd[4], dd[0], null, "primary" if i == 0 else "alt", Vector2(px, h - 96.0), Vector2(cw, 68), 22)
				menu.add_child(pb)
				items.append([pb, Vector2(0, 60), 0.1 + 0.05 * i])
			menu.add_child(_btn("<  BACK", "career", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18))
		"cm_pick":
			var my2: Dictionary = info.get("my", {})
			_title("THE CUP", "A cup on its own: every club in the country, lose once and you are out. Your coins go to your club.")
			var cw2 := (w - 64.0 - 20.0) * 0.5
			var cups := [["ENGLAND", "THE ENGLISH CUP", "92 clubs from the top league to League Two. Seven rounds to the final."], ["DENMARK", "THE DANISH CUP", "24 clubs from both Danish leagues. Five rounds to the final."]]
			for i in 2:
				var px2 := 32.0 + i * (cw2 + 20.0)
				var pn2 := _panel(Vector2(px2, 100), Vector2(cw2, minf(h - 100.0 - 190.0, 150.0)), 0.9)
				items.append([pn2, Vector2(0, 50), 0.06 * i])
				var t1 := _label(cups[i][1], 30, GOLD)
				t1.position = Vector2(24, 18)
				pn2.add_child(t1)
				var t2 := _label(cups[i][2], 17, Color(1, 1, 1, 0.85), font2)
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
			menu.add_child(_btn("<  BACK", "tab", "play", "ghost", Vector2(16, 14), Vector2(130, 48), 18))
		"online":
			var rk: Dictionary = info.get("rank", {})
			_title("RANKED ONLINE", "Your club against another player's club. Win to climb from Bronze to Legend.")
			var lw3 := w * 0.5 - 40.0
			var pn3 := _panel(Vector2(32, 96), Vector2(lw3, h - 96.0 - 112.0), 0.9)
			items.append([pn3, Vector2(-60, 0), 0.0])
			var bs := minf(120.0, pn3.size.y - 70.0)
			_rk_badge(pn3, Vector2(24, 18), bs, rk)
			var rn := _label(str(rk.get("n", "")), 38, Color(str(rk.get("c", "ffffff"))))
			rn.position = Vector2(bs + 44, 22)
			pn3.add_child(rn)
			var rp3 := _label(("%d RANK POINTS" % int(rk.get("rp", 0))) + (("   ·   %d TO %s" % [int(rk.get("need", 0)), str(rk.get("nn", ""))]) if str(rk.get("nn", "")) != "" else ""), 15, Color(1, 1, 1, 0.8), font2)
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
			var trl := _label("SEASON REWARD BY YOUR BEST RANK THIS MONTH", 12, Color(1, 1, 1, 0.55), font2)
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
				var tc4 := _label(str(int(tiers[ti4][3])), 15, Color(0.05, 0.05, 0.05) if cur4 else Color.WHITE)
				tc4.position = Vector2(0, 21)
				tc4.size = Vector2(tw4, 20)
				tc4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				tp4.add_child(tc4)
			var stl := "WON %d   ·   DRAWN %d   ·   LOST %d" % [int(rk.get("w", 0)), int(rk.get("dr", 0)), int(rk.get("l", 0))]
			if int(rk.get("ws", 0)) >= 2:
				stl += "   ·   %d WINS IN A ROW" % int(rk.get("ws", 0))
			var st3 := _label(stl, 15, Color.WHITE, font2)
			st3.position = Vector2(26, pn3.size.y - 62)
			pn3.add_child(st3)
			var sh3 := _label(("SHIELDS %d   ·   " % int(rk.get("sh", 0)) if int(rk.get("sh", 0)) > 0 else "") + "THE RANK SEASON ENDS IN %d DAYS" % int(rk.get("days", 0)), 14, Color(1, 1, 1, 0.65), font2)
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
			var t3b := _tile("LEADERBOARD", "The best players in the game", "rk_lb", null, Vector2(rx3, 96 + th3 + 10.0), Vector2(rw3, th3), Color.WHITE, 22)
			menu.add_child(t3b)
			var t3c := _tile("PLAY WITH A FRIEND", "Room code or invite link, not ranked", "friend", null, Vector2(rx3, 96 + 2 * (th3 + 10.0)), Vector2(rw3, th3), Color.WHITE, 22)
			menu.add_child(t3c)
			for ti3 in 3:
				items.append([[t3a, t3b, t3c][ti3], Vector2(80, 0), 0.04 * ti3])
			menu.add_child(_btn("<  BACK", "tab", "play", "ghost", Vector2(16, 14), Vector2(130, 48), 18))
		"rk_find":
			var rk4: Dictionary = info.get("rank", {})
			var ts := int(rk4.get("t_s", 0))
			_title("RANKED ONLINE", "%s   ·   %d RANK POINTS" % [str(rk4.get("n", "")), int(rk4.get("rp", 0))])
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
			var hint := _label("The match starts by itself when someone is found. Keep the game open.", 15, Color(1, 1, 1, 0.65), font2)
			hint.position = Vector2(0, h * 0.5 + 120)
			hint.size = Vector2(w, 24)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			menu.add_child(hint)
			var stopped := str(rk4.get("msg", "")).contains("TRY AGAIN")
			menu.add_child(_btn("TRY AGAIN" if stopped else "STOP", "rk_find" if stopped else "rk_stop", null, "primary" if stopped else "alt", Vector2(w * 0.5 - 150, h - 96.0), Vector2(300, 66), 26))
			if stopped:
				menu.add_child(_btn("<  BACK", "online", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18))
		"rk_lb":
			var rk5: Dictionary = info.get("rank", {})
			_title("LEADERBOARD", "Everyone's rank points in ranked online.")
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
					var a5 := _label("%d.   %s" % [ri + 1, str(r5["n"])], 16, Color.WHITE)
					a5.position = Vector2(12, 3)
					bg5.add_child(a5)
					var rkn: Dictionary = RankC.rank_of(int(r5["rp"]))
					var b5 := _label("%s   ·   %d" % [str(rkn["n"]), int(r5["rp"])], 15, Color(str(rkn["c"])), font2)
					b5.position = Vector2(cw5 - 232, 5)
					b5.size = Vector2(220, 22)
					b5.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					bg5.add_child(b5)
			menu.add_child(_btn("<  BACK", "online", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18))
		"start_lg":
			var wl: Array = info.get("world", [])
			var sk := str(info.get("start_kind", ""))
			var only_c := str(info.get("cup_ctry", "")) if sk == "cup" else ""
			_title("WHERE DO YOU START?" if sk != "cup" else "PICK YOUR CLUB", {"mine": "Pick the league your own club starts in. It takes the place of the league's weakest club.", "new": "A new club starts at the bottom. Pick the country.", "cup": "Pick a league, then the club you play the cup with."}.get(sk, "Pick a league, then the club you will run. The clubs are made up but remind you of the real ones."))
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
				menu.add_child(_btn("<  BACK", "cupm", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18))
				short = false
			var sl := _label("SEASON LENGTH", 14, Color(1, 1, 1, 0.6), font2)
			sl.visible = sk != "cup"
			sl.position = Vector2(32 + cwl + 24, h - 104)
			menu.add_child(sl)
			var sb := _btn("SHORT: EACH CLUB ONCE" if short else "FULL: HOME AND AWAY", "st_len", null, "alt", Vector2(32 + cwl + 20, h - 82), Vector2(cwl, 60), 22)
			var sn := _label("A 20-club league: %d league matches a season." % (19 if short else 38), 14, Color(1, 1, 1, 0.6), font2)
			sn.position = Vector2(32 + cwl + 24, h - 18)
			if sk != "cup":
				menu.add_child(sb)
				menu.add_child(sn)
				menu.add_child(_btn("<  BACK", "c_start" if sk != "" else "career", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18))
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
				_title("OTHER CLUBS", "See any club's squad and bid for its players.")
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
			menu.add_child(_btn("<  BACK", "st_back" if n == "start_club" else "c_market", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18))
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
				var nl6 := _label("%s   %s" % [str(pl6["pos"]), str(pl6["n"])], 15, Color.WHITE)
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
				var s7 := _label("%s   ·   AGE %d   ·   CAN REACH %d" % [{"GK": "GOALKEEPER", "DF": "DEFENDER", "MF": "MIDFIELDER", "FW": "FORWARD"}[str(pl7["pos"])], int(pl7["age"]), int(pl7["pot"])], 13, Color(1, 1, 1, 0.7), font2)
				s7.position = Vector2(20, 48)
				rp6.add_child(s7)
				var o7 := _label(str(int(pl7["ovr"])), 48, GOLD)
				o7.position = Vector2(rw6 - 90, 4)
				rp6.add_child(o7)
				var stn := ["PAC", "SHO", "PAS", "DEF"]
				for k7 in 4:
					var sl7 := _label("%s  %d" % [stn[k7], int(pl7["st"][k7])], 16, Color.WHITE, font2)
					sl7.position = Vector2(20 + (k7 % 2) * (rw6 * 0.45), 76 + (k7 / 2) * 24)
					rp6.add_child(sl7)
				var abl := ""
				for ab in pl7.get("ab", []):
					abl += ("" if abl == "" else ", ") + str(ab[1])
				var ab7 := _label(("SKILLS: " + abl) if abl != "" else "NO SKILLS", 13, GOLD if abl != "" else Color(1, 1, 1, 0.5), font2)
				ab7.position = Vector2(20, 128)
				ab7.size = Vector2(rw6 - 40, 20)
				ab7.clip_text = true
				rp6.add_child(ab7)
				var ask := int(pl7["ask"])
				var al := _label("THEY WANT ABOUT  %s" % _m(ask), 17, Color.WHITE)
				al.position = Vector2(20, 156)
				rp6.add_child(al)
				var ctr := int(res6.get("counter", 0))
				var bids := [[int(round(ask * 0.8 / 5.0)) * 5, "LOW BID"], [ask, "THEIR PRICE"]]
				if ctr > 0:
					bids = [[ctr, "PAY WHAT THEY ASK"]]
				var bw6 := (rw6 - 36.0 - 8.0 * (bids.size() - 1)) / bids.size()
				for bi in bids.size():
					var amt: int = bids[bi][0]
					var can6: bool = int(c6.get("coins", 0)) >= amt
					var bb6 := _btn("%s\n%s" % [bids[bi][1], _mp(amt)], "sc_bid", amt, "primary" if can6 else "off", Vector2(rx6 + 18 + bi * (bw6 + 8.0), 100 + 190), Vector2(bw6, 64), 17)
					menu.add_child(bb6)
			else:
				var hint := _label("Tap a player to see him and make a bid. Their best men cost more, and a big club sells to a smaller one only for a lot.", 16, Color(1, 1, 1, 0.75), font2)
				hint.autowrap_mode = TextServer.AUTOWRAP_WORD
				hint.position = Vector2(20, 20)
				hint.size = Vector2(rw6 - 40, 120)
				rp6.add_child(hint)
			var rm := str(res6.get("msg", ""))
			if rm != "":
				var rl6 := _label(rm, 15, GREEN.lightened(0.3) if bool(res6.get("ok", false)) else GOLD, font2)
				rl6.autowrap_mode = TextServer.AUTOWRAP_WORD
				rl6.position = Vector2(20, rp6.size.y - 110)
				rl6.size = Vector2(rw6 - 40, 60)
				rp6.add_child(rl6)
			var co6 := _label(_mb(int(c6.get("coins", 0))), 20, GOLD)
			co6.position = Vector2(20, rp6.size.y - 40)
			rp6.add_child(co6)
			menu.add_child(_btn("<  BACK", "sc_back", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18))
		"training":
			var c10: Dictionary = info.get("car", {})
			var pl10: Dictionary = c10.get("plan", {})
			var f10 := str(pl10.get("f", "balanced"))
			var i10 := int(pl10.get("i", 1))
			_title("TRAINING", "What the squad works on between matches. Every man grows from it, the ones who play the most.")
			var fl := _label("FOCUS", 14, GOLD, font2)
			fl.position = Vector2(40, 96)
			menu.add_child(fl)
			var fw10 := (w - 80.0 - 5 * 10.0) / 6.0
			for fi in Career.FOCUS_ORDER.size():
				var fk: String = Career.FOCUS_ORDER[fi]
				var fb10 := _btn(str(Career.FOCI[fk][0]), "c_plan", [fk, -1], "primary" if fk == f10 else "alt", Vector2(40 + fi * (fw10 + 10.0), 118), Vector2(fw10, 56), 18)
				menu.add_child(fb10)
			var fd := _label(str(Career.FOCI[f10][2]), 15, Color(1, 1, 1, 0.8), font2)
			fd.position = Vector2(40, 182)
			menu.add_child(fd)
			var il := _label("HOW HARD", 14, GOLD, font2)
			il.position = Vector2(40, 220)
			menu.add_child(il)
			var idesc := ["Slower growth, the players like it.", "Normal growth.", "Faster growth, but the players feel it: their mood drops a little every match."]
			for ii in 3:
				var ib := _btn(str(Career.INTENS[ii][0]), "c_plan", ["", ii], "primary" if ii == i10 else "alt", Vector2(40 + ii * (fw10 + 10.0), 242), Vector2(fw10, 56), 18)
				menu.add_child(ib)
			var idl := _label(idesc[i10], 15, Color(1, 1, 1, 0.8), font2)
			idl.position = Vector2(40, 306)
			menu.add_child(idl)
			# who is unhappy, and why
			var up := _panel(Vector2(40, 344), Vector2(w - 80.0, h - 360.0))
			var ut := _label("THE SQUAD'S MOOD", 14, GOLD, font2)
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
			var ub10 := _label(("%d HAPPY   ·   %d OKAY   ·   %d UNHAPPY" % [happy, sq10.size() - happy - bad.size(), bad.size()]) + ("" if bad.is_empty() else ":   " + ",   ".join(PackedStringArray(bad))), 15, Color.WHITE if bad.is_empty() else Color(1, 0.7, 0.55), font2)
			ub10.position = Vector2(18, 34)
			ub10.size = Vector2(w - 80.0 - 36.0, h - 360.0 - 44.0)
			ub10.autowrap_mode = TextServer.AUTOWRAP_WORD
			up.add_child(ub10)
			var bk10 := _btn("<  BACK", "career", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18)
			menu.add_child(bk10)
		"contract":
			var c9: Dictionary = info.get("car", {})
			var t9: Dictionary = c9.get("talk", {})
			var sign9 := str(t9.get("kind", "")) == "sign"
			_title("CONTRACT TALKS", "%s   ·   %s   ·   AGE %d   ·   RATING %d  (CAN REACH %d)" % [str(t9.get("n", "")).to_upper(), str(t9.get("pos", "")), int(t9.get("age", 0)), int(t9.get("ovr", 0)), int(t9.get("pot", 0))])
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
				var k9 := _label(str(rows9[ri9][0]), 13, GOLD, font2)
				k9.position = Vector2(20, 16 + ri9 * 58)
				lp9.add_child(k9)
				var v9 := _label(str(rows9[ri9][1]), 22 if ri9 == 1 else 18, Color.WHITE)
				v9.position = Vector2(20, 34 + ri9 * 58)
				lp9.add_child(v9)
			var ol9 := _label("YOUR OFFER", 13, GOLD, font2)
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
			var after9 := int(c9.get("wages", 0)) - int(t9.get("cur", 0)) + int(t9.get("offer", 0))
			var wb9 := int(c9.get("wb", 0))
			var wt9 := _label("WAGES AFTER:  %s  OF  %s A WEEK" % [Career.wage_text(after9), Career.wage_text(wb9)], 15, Color(1, 0.55, 0.45) if after9 > wb9 else Color(1, 1, 1, 0.75), font2)
			wt9.position = Vector2(20, 190)
			rp9.add_child(wt9)
			var go9 := _btn("MAKE THE OFFER", "ct_go", null, "primary", Vector2(rx9, h - 88), Vector2(pw9, 66), 26)
			menu.add_child(go9)
			var bk9 := _btn("WALK AWAY", "ct_back", null, "ghost", Vector2(32, h - 88), Vector2(pw9, 66), 22)
			menu.add_child(bk9)
			if str(c9.get("msg", "")) != "":
				var ms9 := _label(str(c9.get("msg", "")), 15, GOLD, font2)
				ms9.position = Vector2(20, h - 200 - 40)
				ms9.size = Vector2(pw9 * 2 + 20 - 40, 24)
				ms9.clip_text = true
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
			_title("WHAT KIND OF CAREER?", "You can change it later in the career's Office.")
			var cw0 := (w - 64.0 - 24.0) * 0.5
			var defs0 := [
				["simple", "SIMPLE CAREER", "Just play and climb", [
					"The board sets three goals every season",
					"Its confidence rises and falls with your results",
					"A grade and a bonus when the season ends",
					"The cup is part of the season",
					"No sacking: the board only grumbles",
				]],
				["full", "FULL CAREER", "Like a real manager", [
					"Everything in the simple career",
					"The board CAN SACK YOU. Then you take a job at another club",
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
				var sl0 := _label(str(dd[2]).to_upper(), 14, Color(1, 1, 1, 0.65), font2)
				sl0.position = Vector2(26, 56)
				pn0.add_child(sl0)
				var yy0 := 90.0
				for ln0 in dd[3]:
					var dot := ColorRect.new()
					dot.color = GOLD if i0 == 1 else GREEN
					dot.position = Vector2(26, yy0 + 9)
					dot.size = Vector2(7, 7)
					pn0.add_child(dot)
					var bl := _label(str(ln0), 17, Color(1, 1, 1, 0.9), font2)
					bl.autowrap_mode = TextServer.AUTOWRAP_WORD
					bl.position = Vector2(44, yy0)
					bl.size = Vector2(cw0 - 70.0, 24)
					pn0.add_child(bl)
					yy0 += 26.0 * ceilf(font2.get_string_size(str(ln0), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x / (cw0 - 76.0)) + 6.0
				var pb0 := _btn(("PLAYING " if on0 else "PLAY ") + str(dd[1]).split(" ")[0], "cmode_set", dd[0], "alt" if on0 else "primary", Vector2(px0, h - 100.0), Vector2(cw0, 72), 26)
				menu.add_child(pb0)
				items.append([pb0, Vector2(0, 60), 0.1 + 0.06 * i0])
			if cur != "":
				menu.add_child(_btn("<  BACK", "career", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18))
		"board":
			var cb: Dictionary = info.get("car", {})
			var bd: Dictionary = cb.get("board", {})
			var full0 := bool(bd.get("full", false))
			_title("THE BOARD", ("FULL CAREER: at confidence %d or less when the season ends, you are sacked." % int(bd.get("sack_at", 20))) if full0 else "SIMPLE CAREER: the board cannot sack you, but it pays a bonus for a good season.")
			var lw4 := w * 0.36
			var lp4 := _panel(Vector2(32, 104), Vector2(lw4, h - 104.0 - 24.0))
			items.append([lp4, Vector2(-60, 0), 0.0])
			_board_meter(lp4, bd, lw4)
			var rx4 := 32.0 + lw4 + 16.0
			var rw4 := w - rx4 - 32.0
			var gl4 := _label("THIS SEASON'S GOALS", 15, GOLD, font2)
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
				var hl := _label("PAST SEASONS", 14, Color(1, 1, 1, 0.6), font2)
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
					var ct := _label("SEASON %d  %s" % [int(hh["s"]), _ord(int(hh["pos"]))], 13, Color.WHITE, font2)
					ct.position = Vector2(10, 7)
					chip.add_child(ct)
					var cg := _label(str(hh["g"]), 20, _grade_col(str(hh["g"])))
					cg.position = Vector2(92, 2)
					chip.add_child(cg)
					hx += 126.0
			menu.add_child(_btn("<  BACK", "career", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18))
		"review":
			var cr: Dictionary = info.get("car", {})
			var br: Dictionary = cr.get("board", {})
			var rv: Dictionary = br.get("review", {})
			var sacked := bool(rv.get("sacked", false))
			_title("SEASON %d: THE BOARD'S VERDICT" % int(rv.get("season", cr.get("season", 1))), "%s   ·   you finished %s" % [str(cr.get("lgname", "")).capitalize(), _ord(int(rv.get("pos", 1)))])
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
			var cl5 := _label("CONFIDENCE  %d   (%s%d)" % [int(rv.get("conf", 50)), "+" if ch5 >= 0 else "", ch5], 17, GOLD, font2)
			cl5.position = Vector2(0, lp5.size.y - 62)
			cl5.size = Vector2(lw5, 24)
			cl5.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lp5.add_child(cl5)
			var bn5 := _label("BOARD BONUS  +%s" % _m(int(rv.get("bonus", 0))), 17, Color.WHITE if int(rv.get("bonus", 0)) > 0 else Color(1, 1, 1, 0.5), font2)
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
				var ol := _label("THREE CLUBS WANT YOU. PICK YOUR NEW JOB:", 15, GOLD, font2)
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
				var mv := _label(str(cr.get("note", "")), 15, Color(1, 1, 1, 0.75), font2)
				mv.autowrap_mode = TextServer.AUTOWRAP_WORD
				mv.position = Vector2(34, h - 84.0)
				mv.size = Vector2(w - 32.0 - 360.0 - 60.0, 68)
				mv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				menu.add_child(mv)
				menu.add_child(_btn("<  BACK", "career", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18))
		"cup":
			var c8: Dictionary = (info.get("car", {}) as Dictionary).get("cup", {})
			var cm8 := bool(info.get("cupm", false))
			_title(str(c8.get("cname", "THE CUP")), ("%s   ·   EVERY CLUB IN THE COUNTRY. LOSE AND YOU ARE OUT." % str((info.get("car", {}) as Dictionary).get("name", ""))) if cm8 else "Every club in the country, one cup a season, played between league rounds. Lose and you are out.")
			# the rounds so far, left to right: your own tie on top in gold, a few of the others under it
			var rds: Array = c8.get("rounds", [])
			var shown: Array = rds.slice(maxi(rds.size() - 4, 0))
			var cw8 := (w - 64.0 - 3 * 10.0) / 4.0
			for ci8 in shown.size():
				var rd: Dictionary = shown[ci8]
				var x8 := 32.0 + ci8 * (cw8 + 10.0)
				var now8 := bool(rd.get("now", false))
				var hl8 := _label("%s   ·   %d TIES" % [str(rd["name"]), int(rd["n"])], 14, GOLD if now8 else Color(1, 1, 1, 0.65), font2)
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
							var sl8 := _label(str(sc8), 14, GOLD if win8 else Color(1, 1, 1, 0.45), font)
							sl8.position = Vector2(cw8 - 28.0, 3 + k8 * (th8 * 0.5 - 2))
							rp8.add_child(sl8)
			var left8 := _label("%d CLUBS STILL IN" % int(c8.get("left", 0)), 14, Color(1, 1, 1, 0.6), font2)
			left8.position = Vector2(w - 332, 92)
			left8.size = Vector2(300, 20)
			left8.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(left8)
			var by8 := h - 96.0
			if bool(c8.get("won", false)) or bool(c8.get("out", false)):
				var rs8 := _label(("YOU WON %s!" % str(c8.get("cname", "THE CUP"))) if bool(c8.get("won", false)) else "YOU ARE OUT OF THIS CUP", 22, GOLD)
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
			var bk8 := _btn("<  BACK", "cm_back" if cm8 else "career", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18)
			menu.add_child(bk8)
			if cm8:
				menu.add_child(_btn("THE TEAM", "cm_team", null, "alt", Vector2(w - 200, 14), Vector2(170, 48), 18))
		"squad":
			_title("THE TEAM", "")
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
			var bw := minf(90.0, (pw - 28.0) / 4.0 - 4.0)
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
				var pb := _player_btn(pl, int(xi[si2]), tp[si2], Vector2(bw, 46), pcol, int(xi[si2]) == sel, str(form[si2][0]) != str(pl["pos"]))
				menu.add_child(pb)
				ctx["plates"].append([pb, int(xi[si2]), si2])
				_drag_plate(pb, int(xi[si2]), si2, ctx)
			var bx3 := px + pw + 18.0
			var bw3 := w - bx3 - 24.0
			var bl := _label("BENCH", 15, Color(1, 1, 1, 0.7), font2)
			bl.position = Vector2(bx3, 70)
			menu.add_child(bl)
			var bn := 0
			var bcols := 4
			for qi in sqd.size():
				if xi.has(qi) or xi.has(float(qi)):
					continue
				var bb := _player_btn(sqd[qi], qi, Vector2(bx3 + (bn % bcols) * (bw3 / bcols), 94 + (bn / bcols) * 52), Vector2(bw3 / bcols - 6, 46), pcol, qi == sel, false)
				menu.add_child(bb)
				ctx["plates"].append([bb, qi, -1])
				_drag_plate(bb, qi, -1, ctx)
				bn += 1
			var dy := 94.0 + maxi((bn + bcols - 1) / bcols, 2) * 52.0 + 6.0
			var dp := Panel.new()
			dp.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.9), 14, Color(1, 1, 1, 0.14)))
			dp.position = Vector2(bx3, dy)
			dp.size = Vector2(bw3, h - dy - 12)
			dp.mouse_filter = Control.MOUSE_FILTER_PASS
			menu.add_child(dp)
			if sel >= 0 and sel < sqd.size():
				var sp2: Dictionary = sqd[sel]
				var dn := _label("%d  %s" % [int(sp2["num"]), str(sp2["n"])], 26, Color.WHITE)
				dn.position = Vector2(16, 8)
				dp.add_child(dn)
				var eur3 := bool(c3.get("eur", false))
				var dd := _label(("%s   ·   AGE %d   ·   RATING %d  (CAN REACH %d)   ·   %s A WEEK   ·   %s" % [str(sp2["pos"]), int(sp2["age"]), int(sp2["ovr"]), int(sp2["pot"]), Career.wage_text(int(sp2.get("wk", 0))), "LAST SEASON OF HIS CONTRACT" if int(sp2.get("ct", 1)) <= 1 else "CONTRACT: %d SEASONS" % int(sp2.get("ct", 1))]) if eur3 else ("%s   ·   AGE %d   ·   RATING %d  (CAN REACH %d)   ·   %d GOALS" % [str(sp2["pos"]), int(sp2["age"]), int(sp2["ovr"]), int(sp2["pot"]), int(sp2["g"])]), 13, (GOLD if eur3 and int(sp2.get("ct", 1)) <= 1 else Color(1, 1, 1, 0.75)), font2)
				dd.position = Vector2(16, 44)
				dp.add_child(dd)
				var sn := ["PACE", "SHOOTING", "PASSING", "DEFENDING"]
				for sti in 4:
					var sl := _label(sn[sti], 13, Color(1, 1, 1, 0.7), font2)
					sl.position = Vector2(16 + (sti % 2) * (bw3 * 0.5 - 8), 70 + (sti / 2) * 40)
					dp.add_child(sl)
					var sv := _label(str(sp2["st"][sti]), 22, Color.WHITE)
					sv.position = Vector2(16 + (sti % 2) * (bw3 * 0.5 - 8) + 104, 62 + (sti / 2) * 40)
					dp.add_child(sv)
					if int(sp2.get("tp", 0)) > 0 and not eur3:
						# a training point to use: you pick what he gets better at
						var plus := _btn("+1", "c_tp", sti, "primary", Vector2(bx3 + 16 + (sti % 2) * (bw3 * 0.5 - 8) + 150, dy + 60 + (sti / 2) * 40), Vector2(64, 34), 17)
						menu.add_child(plus)
				var xb := ColorRect.new()
				xb.color = Color(1, 1, 1, 0.15)
				xb.position = Vector2(16, 152)
				xb.size = Vector2(bw3 - 32, 8)
				dp.add_child(xb)
				var xf := ColorRect.new()
				xf.color = GREEN
				xf.position = Vector2(16, 152)
				xf.size = Vector2((bw3 - 32) * clampf(float(sp2["xp"]) / 100.0, 0.0, 1.0), 8)
				dp.add_child(xf)
				if eur3:
					# his mood and what he expects, and what he works on
					var mo3 := int(sp2.get("mo", 65))
					var ml := _label("MOOD: %s   ·   %s: %s%s" % [Career.mood_name(mo3), Career.ROLE_NAMES[int(sp2.get("role", 2))], Career.ROLE_WANT[int(sp2.get("role", 2))], "   ·   WANTS TO LEAVE" if bool(sp2.get("tr", false)) else ""], 12, _mood_col(mo3), font2)
					ml.position = Vector2(16, 128)
					dp.add_child(ml)
					var fcb := _btn("TRAINS: %s  ›" % Career.focus_name(str(sp2.get("tf", ""))), "c_focus", null, "alt", Vector2(bx3 + bw3 - 16 - 190, dy + 8), Vector2(190, 34), 13)
					menu.add_child(fcb)
				var tpn := 0 if eur3 else int(sp2.get("tp", 0))
				var tpl := _label("" if eur3 else "TP  %d" % tpn, 24, GOLD if tpn > 0 else Color(1, 1, 1, 0.45))
				tpl.position = Vector2(bw3 - 136, 8)
				tpl.size = Vector2(120, 32)
				tpl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				dp.add_child(tpl)
				var xl := _label(("HE GETS BETTER BY HIMSELF WHEN THE BAR IS FULL. HE FILLS IT BY PLAYING." if int(sp2["ovr"]) < int(sp2["pot"]) else "AT HIS BEST") if eur3 else ("YOU HAVE TRAINING POINTS: TAP +1 ON WHAT HE SHOULD LEARN" if tpn > 0 else "A FULL BAR GIVES 1 TRAINING POINT (TP). HE FILLS IT BY PLAYING.") if int(sp2["ovr"]) < int(sp2["pot"]) else "AT HIS BEST", 11, GOLD if tpn > 0 else Color(1, 1, 1, 0.6), font2)
				xl.position = Vector2(16, 162)
				dp.add_child(xl)
				# his skills: two places, the second opens at rating 70
				var abl: Array = sp2.get("ab", [])
				var abw := (bw3 - 40) * 0.5
				for ai in 2:
					var atx := ""
					var akind := "alt"
					if ai < abl.size():
						atx = str(abl[ai][1])
					elif ai == 1 and bool(sp2.get("ab_lock2", true)):
						atx = "SKILL 2: AT RATING 70"
						akind = "off"
					else:
						atx = "+ LEARN A SKILL  (%s)" % _mp(int(sp2["ab_cost"][ai]))
						akind = "primary" if ai == abl.size() else "off"
					var abb := _btn(atx, "c_ab", ai, akind, Vector2(bx3 + 16 + ai * (abw + 8), dy + 182), Vector2(abw, 40), 14)
					if ai < abl.size():
						abb.add_theme_color_override("font_color", GOLD)
						abb.tooltip_text = str(abl[ai][2])
					menu.add_child(abb)
				var can: bool = int(c3.get("coins", 0)) >= int(sp2["cost"]) and int(sp2["ovr"]) + int(sp2.get("tp", 0)) < int(sp2["pot"])
				var on_bench: bool = not (xi.has(sel) or xi.has(float(sel)))
				var tw3 := (bw3 - 32) * (0.6 if on_bench else 1.0)
				var trb := _btn(("NEW CONTRACT  ›" if int(sp2.get("ct", 1)) > 1 else "RENEW HIS CONTRACT  ›") if eur3 else "BUY 1 TP   (%s)" % _m(int(sp2["cost"])), "ct_open" if eur3 else "c_train", null, "primary" if (can or eur3) else "off", Vector2(bx3 + 16, dy + dp.size.y - 62), Vector2(tw3, 48), 17)
				menu.add_child(trb)
				if on_bench:
					var sure2: bool = int(c3.get("sell_sure", -1)) == sel
					var slb := _btn("SURE? TAP AGAIN" if sure2 else "SELL  (%s)" % _mp(int(sp2["sell"])), "c_sell", null, "ghost", Vector2(bx3 + 16 + tw3 + 8, dy + dp.size.y - 62), Vector2(bw3 - 32 - tw3 - 8, 48), 14)
					menu.add_child(slb)
			else:
				var hint2 := _label("Drag a player on the pitch to put him where you want him.
Drop him on a team mate, or drag a bench man onto him, to swap them.
Tap a player to see him. A yellow mark means he is out of position.", 15, Color(1, 1, 1, 0.75), font2)
				hint2.position = Vector2(16, 14)
				hint2.size = Vector2(bw3 - 32, 120)
				hint2.autowrap_mode = TextServer.AUTOWRAP_WORD
				dp.add_child(hint2)
			if str(c3.get("msg", "")) != "":
				var ms := _label(str(c3.get("msg", "")), 15, GOLD, font2)
				ms.position = Vector2(bx3 + 16, dy + dp.size.y - 90)
				menu.add_child(ms)
			var co3 := _label(_mb(int(c3.get("coins", 0))), 22, GOLD)
			co3.position = Vector2(w - 260, 20)
			co3.size = Vector2(230, 34)
			co3.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(co3)
			var bk3 := _btn("<  BACK", "career", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18)
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
			_title("LEARN A SKILL", head9)
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
				var od9 := _label(str(op9["d"]), 13, Color(1, 1, 1, 0.8), font2)
				od9.position = Vector2(16, 34)
				od9.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ob9.add_child(od9)
				menu.add_child(ob9)
			if str(c9.get("msg", "")) != "":
				var ms9 := _label(str(c9.get("msg", "")), 16, GOLD, font2)
				ms9.position = Vector2(0, h - 84)
				ms9.size = Vector2(w, 26)
				ms9.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				menu.add_child(ms9)
			var co9 := _label(_mb(int(c9.get("coins", 0))), 22, GOLD)
			co9.position = Vector2(w - 260, 20)
			co9.size = Vector2(230, 34)
			co9.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(co9)
			menu.add_child(_btn("<  BACK", "c_abback", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18))
		"subs":
			var sb: Dictionary = info.get("subs", {})
			var left := int(sb.get("left", 0))
			_title("SUBSTITUTIONS", ("%d LEFT.  Tap a player on the pitch, then the man who comes on." % left) if left > 0 else "You have used all three.")
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
			var lh6 := _label("ON THE PITCH", 14, Color(1, 1, 1, 0.65), font2)
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
				var on1 := _label("%d  %s" % [int(op["num"]), str(op["n"])], 17, Color.WHITE if not bool(op["off"]) else Color(1, 1, 1, 0.4))
				on1.position = Vector2(22, 4)
				ob.add_child(on1)
				var on2 := _label("%s  %d" % [str(op["role"]), int(op["ovr"])], 13, Color(1, 1, 1, 0.7), font2)
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
			var bh6 := _label("BENCH", 14, Color(1, 1, 1, 0.65), font2)
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
				var bn1 := _label(str(bp["n"]).substr(0, 9), 15, Color.WHITE)
				bn1.position = Vector2(22, 2)
				bb6.add_child(bn1)
				var bn2 := _label("%s  %d" % [str(bp["pos"]), int(bp["ovr"])], 12, Color(1, 1, 1, 0.7), font2)
				bn2.position = Vector2(22, rb6 - 30)
				bb6.add_child(bn2)
				menu.add_child(bb6)
			var bk6 := _btn("<  BACK", "pause", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18)
			menu.add_child(bk6)
		"club":
			var c7: Dictionary = info.get("car", {})
			var eur7 := bool(c7.get("eur", false))
			var fb7: Dictionary = c7.get("fbuild", {})
			_title("YOUR CLUB", ("The club's buildings. Ask the board for better ones: once a season, and they want to believe in you (confidence %d)." % int(c7.get("conf", 50))) if eur7 else "Build the club with the %s you earn" % _mw())
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
				var fw7 := _label(str(fc["what"]), 14, Color(1, 1, 1, 0.7), font2)
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
				var lv7 := _label("LEVEL %d OF %d" % [int(fc["lv"]), int(fc["max"])], 13, Color(1, 1, 1, 0.65), font2)
				lv7.position = Vector2(18, 130)
				cp7.add_child(lv7)
				var nw7 := _label("NOW:  " + str(fc["now"]), 15, Color.WHITE, font2)
				nw7.autowrap_mode = TextServer.AUTOWRAP_WORD
				nw7.position = Vector2(18, 158)
				nw7.size = Vector2(cw7 - 36, 40)
				cp7.add_child(nw7)
				if str(fc["next"]) != "":
					var nx7 := _label("NEXT:  " + str(fc["next"]), 15, GREEN.lightened(0.3), font2)
					nx7.autowrap_mode = TextServer.AUTOWRAP_WORD
					nx7.position = Vector2(18, 200)
					nx7.size = Vector2(cw7 - 36, 40)
					cp7.add_child(nx7)
					var can7: bool = int(c7.get("coins", 0)) >= int(fc["cost"])
					if eur7 and str(fb7.get("k", "")) == str(fc["k"]):
						var bl7 := _label("BEING BUILT:  READY IN %d MATCHES" % int(fb7.get("left", 0)), 17, GOLD)
						bl7.position = Vector2(18, ch7b - 52)
						cp7.add_child(bl7)
					elif eur7:
						var nd7 := _label("THE BOARD WANTS CONFIDENCE %d  ·  COSTS %s" % [int(fc.get("need", 50)), _mp(int(fc["cost"]))], 12, Color(1, 1, 1, 0.7), font2)
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
				var ms7 := _label(str(c7.get("msg", "")), 17, GOLD)
				ms7.position = Vector2(0, h - 36)
				ms7.size = Vector2(w, 26)
				ms7.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				menu.add_child(ms7)
			var co7 := _label(_mb(int(c7.get("coins", 0))), 22, GOLD)
			co7.position = Vector2(w - 260, 20)
			co7.size = Vector2(230, 34)
			co7.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(co7)
			var bk7 := _btn("<  BACK", "career", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18)
			menu.add_child(bk7)
		"market":
			_title("TRANSFERS", "Free agents, new ones after every match. Or buy from the other clubs.")
			var c5: Dictionary = info.get("car", {})
			var mk: Array = c5.get("market", [])
			var pcol5 := {"GK": Color(0.95, 0.6, 0.1), "DF": Color(0.3, 0.6, 1.0), "MF": Color(0.3, 0.85, 0.45), "FW": Color(0.95, 0.3, 0.3)}
			var tw5 := minf(w - 80.0, 1060.0)
			var tx5 := (w - tw5) * 0.5
			var rh5 := minf(66.0, (h - 150.0) / 6.0)
			var heads5 := [["PLAYER", 0.04], ["AGE", 0.27], ["RATING", 0.35], ["CAN REACH", 0.44], ["PAC", 0.56], ["SHO", 0.62], ["PAS", 0.68], ["DEF", 0.74]]
			for hd in heads5:
				var hl5 := _label(str(hd[0]), 13, Color(1, 1, 1, 0.6), font2)
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
				var p5 := _label({"GK": "GOALKEEPER", "DF": "DEFENDER", "MF": "MIDFIELDER", "FW": "FORWARD"}[str(mp["pos"])] + (("   ·   WANTS ABOUT %s A WEEK" % Career.wage_text(int(round(int(mp.get("wk", 1)) * 1.2)))) if bool(c5.get("eur", false)) else ""), 12, pcol5.get(str(mp["pos"]), Color.WHITE), font2)
				p5.position = Vector2(0.04 * tw5, cy5 + 2)
				rp5.add_child(p5)
				var vals5 := [[str(mp["age"]), 0.27, 18, Color(1, 1, 1, 0.85)], [str(mp["ovr"]), 0.35, 26, GOLD], [str(mp["pot"]), 0.44, 20, GREEN.lightened(0.3)],
					[str(mp["st"][0]), 0.56, 17, Color.WHITE], [str(mp["st"][1]), 0.62, 17, Color.WHITE], [str(mp["st"][2]), 0.68, 17, Color.WHITE], [str(mp["st"][3]), 0.74, 17, Color.WHITE]]
				for v5 in vals5:
					var vl5 := _label(str(v5[0]), int(v5[2]), v5[3])
					vl5.position = Vector2(float(v5[1]) * tw5, cy5 - int(v5[2]) * 0.72)
					rp5.add_child(vl5)
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
				var ms5 := _label(str(c5.get("msg", "")), 17, GOLD)
				ms5.position = Vector2(0, h - 34)
				ms5.size = Vector2(w, 26)
				ms5.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				menu.add_child(ms5)
			var co5 := _label(_mb(int(c5.get("coins", 0))), 22, GOLD)
			co5.position = Vector2(w - 260, 20)
			co5.size = Vector2(230, 34)
			co5.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(co5)
			var bk5 := _btn("<  BACK", "career", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18)
			menu.add_child(bk5)
			if bool(info.get("incar", false)):
				# buying from other clubs belongs to the career only
				var sc5 := _btn("OTHER CLUBS  >", "scout", null, "primary", Vector2(w - 260 - 230, 14), Vector2(220, 48), 18)
				menu.add_child(sc5)
		"teams":
			if str(info.get("from", "")) == "new":
				_title("PICK YOUR CLUB", "This is the club you will run and play for.")
			elif str(info.get("from", "")) == "lobby" and int(info.get("own_i", -1)) >= 0:
				_title("PICK YOUR TEAM", "Your own club plays with your own squad, formation and spots.")
			else:
				_title("PICK YOUR TEAM", "")
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
			var bk := _btn("<  BACK", "teams_back", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18)
			menu.add_child(bk)
		"friend":
			_title("PLAY WITH A FRIEND", "Two phones, one match. One of you creates a room, the other joins.")
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
			_title("ENTER ROOM CODE", "")
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
			_title("ROOM  " + str(info.get("code", "")), "")
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
				var mt := _label("MODE  ·  TAP TO CHANGE", 14, Color(1, 1, 1, 0.7), font2)
				mt.position = Vector2(rx + 4, 68)
				menu.add_child(mt)
				menu.add_child(md)
				items.append([md, Vector2(80, 0), 0.05])
				var mh := _label((cot if cot != "" else "You two against the computer") if str(info.get("mode", "")) == "coop" else "Your team against your friend's: " + str(info.get("gname", "")), 16, Color(1, 1, 1, 0.75), font2)
				mh.position = Vector2(rx + 4, 158)
				mh.size = Vector2(col_w - 8, 24)
				mh.clip_text = true
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
						var av := _btn("THE CAREER  ·  ASSISTANT MANAGER  ›", "as_open", null, "primary", Vector2(w * 0.5 - 250, h * 0.5 + 128), Vector2(500, 64), 24)
						menu.add_child(av)
						items.append([av, Vector2(0, 40), 0.1])
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
			var ph0 := 394.0 if can_sub else 322.0
			panel.position = Vector2((w - pw) * 0.5, h * 0.5 - ph0 * 0.5)
			panel.size = Vector2(pw, ph0)
			menu.add_child(panel)
			var pt := _label("PAUSED" if not bool(info.get("online", false)) else "MENU", 34, Color.WHITE)
			pt.position = Vector2(0, 16)
			pt.size = Vector2(pw, 44)
			pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			panel.add_child(pt)
			panel.add_child(_btn("RESUME", "resume", null, "primary", Vector2(30, 76), Vector2(pw - 60, 72), 30))
			if can_sub:
				panel.add_child(_btn("SUBSTITUTIONS  (%d LEFT)" % int((info.get("subs", {}) as Dictionary).get("left", 0)), "subs", null, "alt", Vector2(30, 160), Vector2(pw - 60, 60), 19))
			var sy := 236.0 if can_sub else 164.0
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
				var gl := _label(str(info.get("g%d" % gi, "")), 15, Color(1, 1, 1, 0.85), font2)
				gl.position = Vector2(0 if gi == 0 else w * 0.5 + 190, h * 0.5 - 114)
				gl.size = Vector2(w * 0.5 - 190, 22)
				gl.clip_text = true
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
				var l2 := _label(str(r[0]), 15, Color(1, 1, 1, 0.7), font2)
				l2.position = Vector2(w * 0.5 - 100, sy + 2)
				l2.size = Vector2(200, 24)
				l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				menu.add_child(l2)
				var l3 := _label(str(r[2]), 18, Color.WHITE)
				l3.position = Vector2(w * 0.5 + 120, sy)
				menu.add_child(l3)
				sy += 24.0
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
					var cll := _label("     ·     ".join(PackedStringArray(rows3[ri4])), 16, GOLD)
					cll.position = Vector2(0, h * 0.5 + 10 + ri4 * 22)
					cll.size = Vector2(w, 22)
					cll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					menu.add_child(cll)
	if n in ["friend", "join", "lobby"]:
		var back := _btn("<  BACK", "back", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18)
		menu.add_child(back)
	if anim:
		for it in items:
			_slide_in(it[0], it[1], it[2])

# ---------------------------------------------------------------- the hub: one home screen with five tabs

# A big button with a title and a line of small text under it.
# The Play tab: the ways to play, side by side and all the same size. The career is one of them.
func _play_tab(info: Dictionary, w: float, y0: float, ch: float, items: Array, anim: bool) -> void:
	var c: Dictionary = info.get("car", {})
	var on := bool(info.get("car_on", false))
	var car_s := "Your club, a new club or one of 116 real-like clubs. The board, the table, promotion."
	var cr: Dictionary = info.get("cr", {})
	if on and not cr.is_empty():
		car_s = "%s   ·   %s   ·   season %d   ·   %s place" % [str(cr["name"]), str(cr["lg"]).capitalize(), int(cr["season"]), _ord(int(cr["rank"])).to_lower()]
	var cp: Dictionary = info.get("cupc", {})
	var cs := "The English or the Danish cup, with your club or any club. Lose once and you are out."
	if not cp.is_empty():
		cs = ("%s: you won it!" % str(cp["cname"]).capitalize()) if bool(cp["won"]) else (("%s: you are out" % str(cp["cname"]).capitalize()) if bool(cp["out"]) else "%s   ·   %s   ·   %s next" % [str(cp["cname"]).capitalize(), str(cp["club"]), str(cp["round"]).to_lower()])
	var rki: Dictionary = info.get("rank", {})
	var defs := [
		["CAREER", car_s, "c_home" if on else "c_start", GREEN.lightened(0.2)],
		["THE CUP", cs, "cupm", GOLD],
		["RANKED ONLINE", "%s   ·   %d points. Your club against other players' clubs." % [str(rki.get("n", "")), int(rki.get("rp", 0))], "online", Color(str(rki.get("c", "ffffff")))],
		["PLAY WITH A FRIEND", "Same team or against each other. A career together: from inside the career", "friend", Color(0.55, 0.8, 1.0)],
		["QUICK MATCH", "A friendly against the computer", "quick", Color.WHITE],
	]
	var gap := 12.0
	var h1 := (ch - gap) * 0.6
	var h2 := ch - gap - h1
	var w3 := (w - 64.0 - 2 * gap) / 3.0
	var w2 := (w - 64.0 - gap) / 2.0
	for i in defs.size():
		var top := i < 3
		var pos := Vector2(32 + i * (w3 + gap), y0) if top else Vector2(32 + (i - 3) * (w2 + gap), y0 + h1 + gap)
		var sz := Vector2(w3, h1) if top else Vector2(w2, h2)
		var b := _btn("", defs[i][2], null, "alt", pos, sz, 20)
		menu.add_child(b)
		items.append([b, Vector2(0, 40), 0.04 * i])
		var bar := ColorRect.new()
		bar.color = defs[i][3]
		bar.position = Vector2(0, 14)
		bar.size = Vector2(6, sz.y - 28)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bar)
		var fs := 30 if top else 26
		var t := _label(defs[i][0], fs, defs[i][3])
		t.position = Vector2(24, 16 if top else sz.y * 0.5 - fs - 2)
		t.size = Vector2(sz.x - 48, fs + 10)
		b.add_child(t)
		var s := _label(defs[i][1], 15, Color(1, 1, 1, 0.75), font2)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD
		s.position = Vector2(24, 16 + fs + 12 if top else sz.y * 0.5 + 4)
		s.size = Vector2(sz.x - 48, 60)
		b.add_child(s)
		if i == 2:
			_rk_badge(b, Vector2(sz.x - 84, sz.y - 98), 64.0, rki)
		var ar := _label(">", 26, Color(1, 1, 1, 0.45))
		ar.position = Vector2(sz.x - 36, sz.y - 44 if top else sz.y * 0.5 - 18)
		b.add_child(ar)
		if i == 2:
			ar.visible = false

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
		var s := _label(sub, 15, Color(1, 1, 1, 0.72), font2)
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
	p.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, a), 18, Color(1, 1, 1, 0.14)))
	p.position = pos
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(p)
	return p

func _hub(info: Dictionary, w: float, h: float, items: Array, anim: bool) -> void:
	var c: Dictionary = info.get("car", {})
	var tab := str(info.get("tab", "play"))
	# --- top bar: your club, where the season stands, your coins
	var bar := ColorRect.new()
	bar.color = Color(0.02, 0.05, 0.04, 0.82)
	bar.position = Vector2.ZERO
	bar.size = Vector2(w, 64)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(bar)
	var kit: Array = c.get("kit", ["888888", "ffffff"])
	var badge := Panel.new()
	badge.add_theme_stylebox_override("panel", _box(Color(str(kit[0])), 9, Color(1, 1, 1, 0.6)))
	badge.position = Vector2(18, 11)
	badge.size = Vector2(42, 42)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(badge)
	var nm := _label(str(c.get("name", "PITCH BOSS")), 26, Color.WHITE)
	nm.position = Vector2(72, 4)
	menu.add_child(nm)
	var sub := _label(("ASSISTANT MANAGER   ·   YOUR CHANGES BECOME SUGGESTIONS   ·   %s PLACE" % _ord(int(c.get("rank", 1)))) if bool(info.get("assist", false)) else ("%s   ·   SEASON %d   ·   ROUND %d OF %d   ·   %s PLACE   ·   TEAM RATING %d" % [str(c.get("lgname", "")), int(c.get("season", 1)), mini(int(c.get("round", 0)) + 1, int(c.get("rounds", 14))), int(c.get("rounds", 14)), _ord(int(c.get("rank", 1))), int(c.get("str", 0))]) if bool(info.get("incar", false)) else ("YOUR CLUB   ·   TEAM RATING %d" % int(c.get("str", 0))), 14, Color(1, 1, 1, 0.75), font2)
	sub.position = Vector2(73, 37)
	if str(info.get("co_room", "")) != "":
		# the room button needs the space: a shorter line
		sub.text = "SEASON %d   ·   ROUND %d OF %d   ·   %s PLACE" % [int(c.get("season", 1)), mini(int(c.get("round", 0)) + 1, int(c.get("rounds", 14))), int(c.get("rounds", 14)), _ord(int(c.get("rank", 1)))]
	menu.add_child(sub)
	var co := _label(_mb(int(c.get("coins", 0))), 24, GOLD)
	co.position = Vector2(w - 270, 8)
	co.size = Vector2(250, 34)
	co.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu.add_child(co)
	var incar := bool(info.get("incar", false))
	if incar:
		# inside the career: the way out is always in sight
		var xb := _btn("LEAVE" if bool(info.get("assist", false)) else "EXIT CAREER", "co_leave" if bool(info.get("assist", false)) else "cr_exit", null, "alt", Vector2(w - 270.0 - 190.0, 10), Vector2(176, 44), 17)
		menu.add_child(xb)
		var cor := str(info.get("co_room", ""))
		if cor != "":
			# the room for the career together, always in sight while it is open
			var con := bool(info.get("co_conn", false))
			var rb := _btn("ROOM %s  ·  %s" % [cor, "FRIEND IS HERE" if con else "SHARE LINK"], "share" if not con else "co_close", null, "ghost", Vector2(w - 270.0 - 190.0 - 290.0, 10), Vector2(280, 44), 15)
			if con:
				rb.add_theme_color_override("font_color", GREEN.lightened(0.3))
			menu.add_child(rb)
	# the game's logo, between the season line and the coins (left out when the UPDATE button needs the room)
	elif not bool(info.get("upd", false)) and w >= 900.0:
		var lg := TextureRect.new()
		lg.texture = load("res://logo.png")
		lg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lg.size = Vector2(193, 37)
		lg.position = Vector2(w - 270.0 - 178.0, 13)
		lg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu.add_child(lg)
	if bool(info.get("upd", false)):
		var ub := _btn("UPDATE", "update", null, "primary", Vector2(w - 420, 10), Vector2(140, 44), 18)
		for st in ["normal", "hover", "focus"]:
			ub.add_theme_stylebox_override(st, _box(GOLD, 12))
		menu.add_child(ub)
		_pulse(ub)
	# --- bottom bar: the five places
	var nh := 62.0
	var nb := ColorRect.new()
	nb.color = Color(0.02, 0.05, 0.04, 0.9)
	nb.position = Vector2(0, h - nh - 8)
	nb.size = Vector2(w, nh + 8)
	nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(nb)
	var tabs := [["shop", "SHOP"], ["team", "TEAM"], ["play", "PLAY"], ["club", "CLUB"], ["profile", "PROFILE"]]
	if incar:
		# the career mode has its own menus
		tabs = [["career", "HOME"], ["team", "SQUAD"], ["transfers", "TRANSFERS"], ["club", "CLUB"], ["office", "OFFICE"]]
	var tw := (w - 32.0 - 4 * 8.0) / 5.0
	for i in tabs.size():
		var on: bool = tabs[i][0] == tab
		var tb := _btn(tabs[i][1], "tab", tabs[i][0], "ghost", Vector2(16 + i * (tw + 8.0), h - nh - 2), Vector2(tw, nh - 6), 24 if tabs[i][0] in ["play", "career"] else 20)
		if on:
			# chalk white = where you are
			for st in ["normal", "hover", "focus", "pressed"]:
				tb.add_theme_stylebox_override(st, _box(Color(0.94, 0.95, 0.92), 14))
			for cc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				tb.add_theme_color_override(cc, Color(0.03, 0.08, 0.05))
		elif tabs[i][0] in ["play", "career"]:
			for cc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				tb.add_theme_color_override(cc, GREEN.lightened(0.25))
		menu.add_child(tb)
	var y0 := 78.0
	var ch := h - nh - 8.0 - y0 - 12.0
	var msg := str(c.get("msg", ""))
	match tab:
		"play":
			_play_tab(info, w, y0, ch, items, anim)
		"career":
			var lw := w * 0.58 - 48.0
			var bh := minf(84.0, ch * 0.24)
			var card := _panel(Vector2(32, y0), Vector2(lw, ch - bh - 10.0))
			items.append([card, Vector2(-60, 0), 0.0])
			var cy := card.size.y
			if bool(c.get("over", false)):
				var nt := _label(str(c.get("note", "SEASON OVER")), 24, GOLD)
				nt.autowrap_mode = TextServer.AUTOWRAP_WORD
				nt.position = Vector2(20, cy * 0.5 - 45)
				nt.size = Vector2(lw - 40, 90)
				nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				card.add_child(nt)
				if bool(c.get("sacked", false)):
					nt.text = "THE BOARD HAS SACKED YOU. THREE CLUBS WANT YOU AS THEIR MANAGER."
					nt.add_theme_color_override("font_color", Color(0.95, 0.4, 0.35))
				var ns := _btn("THE BOARD'S VERDICT", "c_review", null, "primary", Vector2(32, y0 + ch - bh), Vector2(lw, bh), 34)
				menu.add_child(ns)
				items.append([ns, Vector2(0, 60), 0.1])
			else:
				var cdue := bool(c.get("cup_due", false))
				var cpn: Dictionary = c.get("cup", {})
				var nx := _label(("THE CUP   ·   " + str(cpn.get("name", ""))) if cdue else ("NEXT LEAGUE MATCH   ·   " + ("HOME" if bool(c.get("home", true)) else "AWAY")), 17, GOLD, font2)
				nx.position = Vector2(0, 14)
				nx.size = Vector2(lw, 26)
				nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				card.add_child(nx)
				var kits := [c.get("kit", ["888888"]), cpn.get("opp_kit", ["888888"]) if cdue else c.get("opp_kit", ["888888"])]
				var nms := [str(c.get("name", "")), str(cpn.get("opp", "")) if cdue else str(c.get("opp", ""))]
				var rks := [int(c.get("rank", 1)), int(cpn.get("opp_rank", 1)) if cdue else int(c.get("opp_rank", 1))]
				var my := cy * 0.5 - 62.0 + 4.0
				for si in 2:
					var cx := lw * (0.25 if si == 0 else 0.75)
					var sh2 := Panel.new()
					sh2.add_theme_stylebox_override("panel", _box(Color(str(kits[si][0])), 10, Color(1, 1, 1, 0.55)))
					sh2.mouse_filter = Control.MOUSE_FILTER_IGNORE
					sh2.size = Vector2(60, 60)
					sh2.position = Vector2(cx - 30, my)
					card.add_child(sh2)
					var fs2 := 26
					while fs2 > 14 and font.get_string_size(nms[si], HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x > lw * 0.5 - 30.0:
						fs2 -= 2
					var nl2 := _label(nms[si], fs2, Color.WHITE)
					nl2.position = Vector2(cx - lw * 0.25, my + 68)
					nl2.size = Vector2(lw * 0.5, 34)
					nl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					card.add_child(nl2)
					var rl := _label((str(cpn.get("opp_lg", "")) if cdue and si == 1 and str(cpn.get("opp_lg", "")) != str(c.get("lgname", "")) else _ord(rks[si]) + " IN THE TABLE"), 14, Color(1, 1, 1, 0.7), font2)
					rl.position = Vector2(cx - lw * 0.25, my + 102)
					rl.size = Vector2(lw * 0.5, 24)
					rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					card.add_child(rl)
				var vv := _label("V", 32, GOLD)
				vv.position = Vector2(0, my + 12)
				vv.size = Vector2(lw, 40)
				vv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				card.add_child(vv)
				# the board's mood and the main goal, always in sight
				var bdi: Dictionary = c.get("board", {})
				var bc := int(bdi.get("conf", 50))
				var strip := Panel.new()
				strip.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.28), 10))
				strip.position = Vector2(14, cy - 44)
				strip.size = Vector2(lw - 28, 32)
				strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.add_child(strip)
				var sbar := ColorRect.new()
				sbar.color = _conf_col(bc)
				sbar.position = Vector2(10, 12)
				sbar.size = Vector2(maxf(60.0 * bc / 100.0, 2.0), 8)
				strip.add_child(sbar)
				var sbg := ColorRect.new()
				sbg.color = Color(1, 1, 1, 0.12)
				sbg.position = Vector2(10, 12)
				sbg.size = Vector2(60, 8)
				strip.add_child(sbg)
				sbg.move_to_front()
				sbar.move_to_front()
				var objs0: Array = bdi.get("obj", [])
				var stl := _label("BOARD: %s   ·   %s" % [str(bdi.get("mood", "")), str(objs0[0]["t"]) if not objs0.is_empty() else ""], 14, Color(1, 1, 1, 0.85), font2)
				stl.position = Vector2(80, 5)
				stl.size = Vector2(lw - 28 - 90, 22)
				stl.clip_text = true
				strip.add_child(stl)
				var pm := _btn(_co_play_text(info, "PLAY CUP MATCH" if cdue else "PLAY MATCH"), "c_play", null, "primary", Vector2(32, y0 + ch - bh), Vector2(lw, bh), 34)
				menu.add_child(pm)
				items.append([pm, Vector2(0, 60), 0.1])
				if anim:
					pm.ready.connect(func(): _pulse(pm))
				else:
					_pulse(pm)
			var rx := w * 0.58
			var rw := w - rx - 32.0
			var th := (ch - 30.0) / 4.0
			var cpi: Dictionary = c.get("cup", {})
			var cps := "You won it! A new cup starts next season" if bool(cpi.get("won", false)) else ("You are out. A new cup starts next season" if bool(cpi.get("out", false)) else ("%s against %s: next match!" % [str(cpi.get("name", "")).capitalize(), str(cpi.get("opp", ""))] if bool(c.get("cup_due", false)) else "%s against %s after round %d" % [str(cpi.get("name", "")).capitalize(), str(cpi.get("opp", "")), int(c.get("cup_after", 0))]))
			var t0 := _tile("THE CUP", cps, "cup", null, Vector2(rx, y0), Vector2(rw, th), GOLD, 22)
			var t1 := _tile("THE TABLE", "%s   ·   %s place" % [str(c.get("lgname", "")).capitalize(), _ord(int(c.get("rank", 1)))], "c_table", null, Vector2(rx, y0 + th + 10.0), Vector2(rw, th), Color.WHITE, 22)
			var t2 := _tile("THE SQUAD", "Look at the players and suggest changes", "tab", "team", Vector2(rx, y0 + 2 * (th + 10.0)), Vector2(rw, th), Color.WHITE, 22) if bool(info.get("assist", false)) else _tile("PLAY IT TOGETHER", ("Room %s: your friend joins with this code" % str(info.get("co_room", ""))) if str(info.get("co_room", "")) != "" else "Your friend joins your career on his phone", "friend", null, Vector2(rx, y0 + 2 * (th + 10.0)), Vector2(rw, th), Color.WHITE, 22)
			var bdt: Dictionary = c.get("board", {})
			var t3 := _tile("THE BOARD", "Confidence %d: %s. Your goals this season." % [int(bdt.get("conf", 50)), str(bdt.get("mood", "")).capitalize()], "c_board", null, Vector2(rx, y0 + 3 * (th + 10.0)), Vector2(rw, th), Color.WHITE, 22)
			menu.add_child(t0)
			items.append([t0, Vector2(80, 0), 0.0])
			for t in [t1, t2, t3]:
				menu.add_child(t)
			items.append([t1, Vector2(80, 0), 0.04])
			items.append([t2, Vector2(80, 0), 0.08])
			items.append([t3, Vector2(80, 0), 0.12])
		"transfers":
			var cw8 := (w - 64.0 - 20.0) / 3.0
			var mk8: Array = c.get("market", [])
			var t8 := [
				["TRANSFER LIST", "%d players for sale right now. New ones after every match." % mk8.size(), "c_market"],
				["OTHER CLUBS", "See any club's squad in England and Denmark, bid for their players and haggle.", "scout"],
				["SELL PLAYERS", "Open your squad, tap a bench player and sell him to a club that wants him.", "c_squad"],
			]
			for i in 3:
				var tl8 := _tile(t8[i][0], t8[i][1], t8[i][2], null, Vector2(32 + i * (cw8 + 10.0), y0), Vector2(cw8, ch * 0.62), Color.WHITE, 26)
				menu.add_child(tl8)
				items.append([tl8, Vector2(0, 50), 0.04 * i])
			var bp8 := _panel(Vector2(32, y0 + ch * 0.62 + 10.0), Vector2(w - 64.0, ch * 0.38 - 10.0))
			var bl8 := _label("TRANSFER BUDGET", 14, GOLD, font2)
			bl8.position = Vector2(18, 10)
			bp8.add_child(bl8)
			var bv8 := _label(_mp(int(c.get("coins", 0))), 40, Color.WHITE)
			bv8.position = Vector2(18, 30)
			bp8.add_child(bv8)
			if bool(c.get("eur", false)):
				# the wage budget next to it, and money moved between the two
				var wl8 := _label("WAGES A WEEK", 14, GOLD, font2)
				wl8.position = Vector2(300, 10)
				bp8.add_child(wl8)
				var wv8 := _label("%s  OF  %s" % [Career.wage_text(int(c.get("wages", 0))), Career.wage_text(int(c.get("wb", 0)))], 30, Color.WHITE)
				wv8.position = Vector2(300, 32)
				bp8.add_child(wv8)
				var wn8 := _label("Every new man and every new contract must fit in the wage budget.", 13, Color(1, 1, 1, 0.65), font2)
				wn8.position = Vector2(300, 74)
				bp8.add_child(wn8)
				var bx8 := w - 32.0 - 300.0
				var by8 := y0 + ch * 0.62 + 10.0
				var u8 := _btn("+ %s WAGES  (– %s)" % [Career.wage_text(Career.WB_STEP), _mp(Career.WB_STEP * Career.WB_RATE)], "c_wb", "up", "alt", Vector2(bx8, by8 + 12), Vector2(280, 44), 15)
				var d8 := _btn("– %s WAGES  (+ %s)" % [Career.wage_text(Career.WB_STEP), _mp(Career.WB_STEP * Career.WB_RATE)], "c_wb", "down", "ghost", Vector2(bx8, by8 + 62), Vector2(280, 44), 15)
				menu.add_child(u8)
				menu.add_child(d8)
				if str(c.get("msg", "")) != "":
					var ms8 := _label(str(c.get("msg", "")), 14, GOLD, font2)
					ms8.position = Vector2(300, 96)
					bp8.add_child(ms8)
			else:
				var bn8 := _label("The career has its own money: win matches, sell players and please the board to get more. It never mixes with your coins outside.", 15, Color(1, 1, 1, 0.7), font2)
				bn8.autowrap_mode = TextServer.AUTOWRAP_WORD
				bn8.position = Vector2(300, 22)
				bn8.size = Vector2(w - 64.0 - 330.0, 60)
				bp8.add_child(bn8)
		"office":
			var bdo: Dictionary = c.get("board", {})
			var cwo := (w - 64.0 - 2 * 10.0) / 3.0
			var tho := (ch - 10.0) * 0.5
			var cpo: Dictionary = c.get("cup", {})
			var to := [
				["THE BOARD", "Confidence %d: %s. Your goals this season." % [int(bdo.get("conf", 50)), str(bdo.get("mood", "")).capitalize()], "c_board", GOLD],
				["THE TABLE", "%s   ·   %s place" % [str(c.get("lgname", "")).capitalize(), _ord(int(c.get("rank", 1))).to_lower()], "c_table", Color.WHITE],
				["THE CUP", str(cpo.get("cname", "The cup")).capitalize(), "cup", Color.WHITE],
				["PLAY TOGETHER", "Your friend joins this career on his phone", "friend", Color(0.55, 0.8, 1.0)],
				["CAREER: " + ("FULL" if str(c.get("mode", "")) == "full" else "SIMPLE"), "Simple or full: can the board sack you?", "cmode", Color.WHITE],
				["NEW CAREER", "Start again with your club, a new club or another club", "c_new", Color(1, 1, 1, 0.8)],
			]
			for i in to.size():
				var tlo := _tile(to[i][0], to[i][1], to[i][2], null, Vector2(32 + (i % 3) * (cwo + 10.0), y0 + (i / 3) * (tho + 10.0)), Vector2(cwo, tho), to[i][3], 22)
				menu.add_child(tlo)
				items.append([tlo, Vector2(0, 40), 0.03 * i])
		"team":
			var lw2 := w * 0.5 - 40.0
			var sq: Array = c.get("squad", [])
			var xi: Array = c.get("xi", [])
			var bt := _tile("THE TEAM", ("%d training points to use.  " % int(c.get("tp", 0)) if int(c.get("tp", 0)) > 0 else "") + "Line-up, formation, training and selling.", "c_squad", null, Vector2(32, y0), Vector2(lw2, ch * 0.56), Color.WHITE, 34)
			menu.add_child(bt)
			items.append([bt, Vector2(-60, 0), 0.0])
			var hw2 := (lw2 - 10.0) * 0.5
			var p1 := _panel(Vector2(32, y0 + ch * 0.56 + 10.0), Vector2(hw2, ch * 0.44 - 10.0))
			var p2 := _panel(Vector2(32 + hw2 + 10.0, y0 + ch * 0.56 + 10.0), Vector2(hw2, ch * 0.44 - 10.0))
			p2.queue_free()
			var pln: Dictionary = c.get("plan", {})
			var unh := 0
			for sq0 in sq:
				if int((sq0 as Dictionary).get("mo", 65)) < 35:
					unh += 1
			var ot := _tile("TRAINING", "%s  ·  %s%s" % [Career.FOCI[str(pln.get("f", "balanced"))][0], Career.INTENS[int(pln.get("i", 1))][0], ("  ·  %d UNHAPPY" % unh) if unh > 0 else ""], "c_trainm", null, Vector2(32 + hw2 + 10.0, y0 + ch * 0.56 + 10.0), Vector2(hw2, ch * 0.44 - 10.0), Color.WHITE, 22) if bool(c.get("eur", false)) else _tile("NAME AND KIT", "Your club's name and colours", "own", null, Vector2(32 + hw2 + 10.0, y0 + ch * 0.56 + 10.0), Vector2(hw2, ch * 0.44 - 10.0), Color.WHITE, 22)
			menu.add_child(ot)
			var vals := [["TEAM RATING", str(int(c.get("str", 0)))]]
			var pp := [p1]
			for i in 1:
				var a := _label(vals[i][0], 14, GOLD, font2)
				a.position = Vector2(0, 12)
				a.size = Vector2(hw2, 22)
				a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				pp[i].add_child(a)
				var b2 := _label(vals[i][1], 44, Color.WHITE)
				b2.position = Vector2(0, (pp[i].size.y - 22.0) * 0.5 - 14.0)
				b2.size = Vector2(hw2, 56)
				b2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				pp[i].add_child(b2)
			var rx2 := w * 0.5 + 8.0
			var rw2 := w - rx2 - 32.0
			var lp := _panel(Vector2(rx2, y0), Vector2(rw2, ch))
			items.append([lp, Vector2(80, 0), 0.05])
			var lh := _label("YOUR BEST PLAYERS", 15, GOLD, font2)
			lh.position = Vector2(18, 12)
			lp.add_child(lh)
			var idx := []
			for i in sq.size():
				idx.append(i)
			idx.sort_custom(func(a3, b3): return int(sq[a3]["ovr"]) > int(sq[b3]["ovr"]))
			var rows := mini(idx.size(), int((ch - 48.0) / 38.0))
			var pc := {"GK": Color(1.0, 0.6, 0.1), "DF": Color(0.3, 0.6, 1.0), "MF": Color(0.3, 0.85, 0.45), "FW": Color(0.95, 0.3, 0.3)}
			for r in rows:
				var pl: Dictionary = sq[idx[r]]
				var yy := 42.0 + r * 38.0
				var st := ColorRect.new()
				st.color = pc.get(str(pl["pos"]), Color.WHITE)
				st.position = Vector2(18, yy + 4)
				st.size = Vector2(5, 26)
				lp.add_child(st)
				var n1 := _label("%s   %s" % [str(pl["pos"]), str(pl["n"])], 20, Color.WHITE)
				n1.position = Vector2(32, yy)
				lp.add_child(n1)
				if bool(c.get("eur", false)):
					var md := _label(Career.mood_name(int(pl.get("mo", 65))), 12, _mood_col(int(pl.get("mo", 65))), font2)
					md.position = Vector2(rw2 * 0.5, yy + 6)
					lp.add_child(md)
				var n2 := _label(("" if xi.has(idx[r]) else "BENCH    ") + str(int(pl["ovr"])), 20, Color.WHITE if xi.has(idx[r]) else Color(1, 1, 1, 0.6))
				n2.position = Vector2(rw2 - 198, yy)
				n2.size = Vector2(180, 30)
				n2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				lp.add_child(n2)
		"club":
			var fcs: Array = c.get("fac", [])
			var ft := ""
			for f in fcs:
				ft += ("" if ft == "" else "   ·   ") + "%s %d" % [str((f as Dictionary).get("n", "")).capitalize(), int((f as Dictionary).get("lv", 1))]
			var cw := (w - 64.0 - 20.0) / 3.0
			var defs := [
				["FACILITIES", "Stadium, training ground and youth academy. Build them with your %s." % _mw(), "c_club"],
				["TRANSFERS", "%d players for sale. New ones after every match." % (c.get("market", []) as Array).size(), "c_market"],
				["LEAGUE TABLE", "You are %s of %d in season %d." % [_ord(int(c.get("rank", 1))), int(c.get("n", 20)), int(c.get("season", 1))], "c_table"] if incar else ["NAME AND KIT", "Your club's name and colours.", "own"],
			]
			for i in 3:
				var t := _tile(defs[i][0], defs[i][1], defs[i][2], null, Vector2(32 + i * (cw + 10.0), y0), Vector2(cw, ch * 0.62), Color.WHITE, 28)
				menu.add_child(t)
				items.append([t, Vector2(0, 50), 0.04 * i])
			var ip := _panel(Vector2(32, y0 + ch * 0.62 + 10.0), Vector2(w - 64.0, ch * 0.38 - 10.0))
			var il := _label("YOUR CLUB NOW", 14, GOLD, font2)
			il.position = Vector2(18, 10)
			ip.add_child(il)
			var it := _label(ft if ft != "" else "Nothing built yet", 22, Color.WHITE)
			it.position = Vector2(18, 34)
			it.size = Vector2(w - 100.0, 30)
			ip.add_child(it)
			var i2 := _label("A bigger stadium brings %s at home matches. A better training ground makes players grow faster." % _mw(), 15, Color(1, 1, 1, 0.7), font2)
			i2.autowrap_mode = TextServer.AUTOWRAP_WORD
			i2.position = Vector2(18, 68)
			i2.size = Vector2(w - 100.0, 44)
			ip.add_child(i2)
		"shop":
			var packs: Array = info.get("packs", [])
			var cw2 := (w - 64.0 - 20.0) / 3.0
			var pcol := [Color(0.8, 0.52, 0.3), Color(0.82, 0.86, 0.9), GOLD]
			for i in packs.size():
				var pk: Dictionary = packs[i]
				var pn := _panel(Vector2(32 + i * (cw2 + 10.0), y0), Vector2(cw2, ch - 30.0), 0.9)
				items.append([pn, Vector2(0, 50), 0.05 * i])
				var top := ColorRect.new()
				top.color = pcol[i]
				top.position = Vector2(18, 16)
				top.size = Vector2(cw2 - 36.0, 6)
				pn.add_child(top)
				var pt := _label(str(pk["n"]), 30, pcol[i])
				pt.position = Vector2(0, 30)
				pt.size = Vector2(cw2, 40)
				pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				pn.add_child(pt)
				var pd := _label("One new player for your squad", 15, Color(1, 1, 1, 0.75), font2)
				pd.position = Vector2(0, 74)
				pd.size = Vector2(cw2, 22)
				pd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				pn.add_child(pd)
				var pr := _label("RATING  %d  TO  %d" % [int(pk["lo"]), int(pk["hi"])], 24, Color.WHITE)
				pr.position = Vector2(0, (ch - 30.0) * 0.5 - 12.0)
				pr.size = Vector2(cw2, 34)
				pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				pn.add_child(pr)
				var can: bool = int(c.get("coins", 0)) >= int(pk["cost"])
				var bb := _btn("OPEN   %d COINS" % int(pk["cost"]), "pack", i, "primary" if can else "off", Vector2(32 + i * (cw2 + 10.0) + 18.0, y0 + ch - 30.0 - 70.0), Vector2(cw2 - 36.0, 54), 22)
				menu.add_child(bb)
				items.append([bb, Vector2(0, 50), 0.05 * i])
			var sm := _label(msg if msg != "" else "You earn coins in ranked online, the cup and your career.", 15, GOLD if msg != "" else Color(1, 1, 1, 0.7), font2)
			sm.position = Vector2(0, y0 + ch - 22.0)
			sm.size = Vector2(w, 22)
			sm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			menu.add_child(sm)
		"profile":
			var ps: Dictionary = info.get("pstats", {})
			var lw3 := w * 0.5 - 40.0
			var sp := _panel(Vector2(32, y0), Vector2(lw3, ch))
			items.append([sp, Vector2(-60, 0), 0.0])
			var sh := _label("YOUR RECORD", 15, GOLD, font2)
			sh.position = Vector2(18, 12)
			sp.add_child(sh)
			var rws := [["MATCHES", int(ps.get("p", 0))], ["WON", int(ps.get("w", 0))], ["DRAWN", int(ps.get("d", 0))], ["LOST", int(ps.get("l", 0))], ["GOALS SCORED", int(ps.get("gf", 0))], ["GOALS AGAINST", int(ps.get("ga", 0))], ["LEAGUE TITLES", int(ps.get("titles", 0))]]
			var rh := minf(40.0, (ch - 50.0) / rws.size())
			for i in rws.size():
				var a2 := _label(rws[i][0], 18, Color(1, 1, 1, 0.8), font2)
				a2.position = Vector2(20, 44 + i * rh)
				sp.add_child(a2)
				var b3 := _label(str(rws[i][1]), 22, Color.WHITE)
				b3.position = Vector2(lw3 - 140, 42 + i * rh)
				b3.size = Vector2(120, 30)
				b3.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				sp.add_child(b3)
			var rx3 := w * 0.5 + 8.0
			var rw3 := w - rx3 - 32.0
			var bw := (rw3 - 10.0) * 0.5
			var sbh := minf(62.0, (ch - 40.0) / 5.0 - 8.0)
			var sl := _label("SETTINGS", 15, GOLD, font2)
			sl.position = Vector2(rx3 + 4, y0 + 2)
			menu.add_child(sl)
			var sets := [
				["SOUND: " + str(info.get("snd", "")), "snd_opt"], ["VOICE: " + ("ON" if bool(info.get("voice", true)) else "OFF"), "voice_opt"],
				["LEVEL: " + str(info.get("diff", "")), "diff"], ["MATCH: " + str(info.get("len", "")), "len"],
				["HOW TO PLAY", "how"], ["UPDATE THE GAME", "update"],
				["INSTALLED" if bool(info.get("inst", false)) else "INSTALL THE GAME", "install"],
			]
			for i in sets.size():
				var sb := _btn(sets[i][0], sets[i][1], null, "ghost" if sets[i][1] == "c_new" else "alt", Vector2(rx3 + (i % 2) * (bw + 10.0), y0 + 28.0 + (i / 2) * (sbh + 8.0)), Vector2(bw, sbh), 19)
				menu.add_child(sb)
				items.append([sb, Vector2(80, 0), 0.03 * i])
			var ver := _label("VERSION  " + str(info.get("version", "")), 14, Color(1, 1, 1, 0.6), font2)
			ver.position = Vector2(rx3 + 4, y0 + ch - 20.0)
			menu.add_child(ver)
	var ver2 := _label(str(info.get("version", "")), 12, Color(1, 1, 1, 0.55), font2)
	ver2.position = Vector2(w - 270, 45)
	ver2.size = Vector2(250, 16)
	ver2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu.add_child(ver2)

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
	var cl := _label("CONFIDENCE", 15, GOLD, font2)
	cl.position = Vector2(20, 14)
	p.add_child(cl)
	var big := _label(str(c), 64, _conf_col(c))
	big.position = Vector2(18, 30)
	p.add_child(big)
	var md := _label(str(bd.get("mood", "")), 24, _conf_col(c))
	md.position = Vector2(110, 52)
	p.add_child(md)
	var chg := int(bd.get("chg", 0))
	var cg := _label(("%s%d AFTER THE LAST MATCH" % ["+" if chg >= 0 else "", chg]) if chg != 0 else "NO CHANGE AFTER THE LAST MATCH", 13, Color(1, 1, 1, 0.6), font2)
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
		var st := _label("SACK", 11, Color(0.95, 0.4, 0.35), font2)
		st.position = Vector2(sx - 14, 136)
		p.add_child(st)
	var bl := ColorRect.new()
	bl.color = Color(1, 0.84, 0.25, 0.7)
	bl.position = Vector2(20.0 + bw * 0.8 - 1, 110)
	bl.size = Vector2(2, 26)
	p.add_child(bl)
	var bt := _label("BONUS", 11, GOLD, font2)
	bt.position = Vector2(20.0 + bw * 0.8 - 16, 136)
	p.add_child(bt)
	var exl := _label("THE BOARD EXPECTED YOU TO FINISH ABOUT %s THIS SEASON" % _ord(int(bd.get("ex", 4))), 13, Color(1, 1, 1, 0.6), font2)
	exl.autowrap_mode = TextServer.AUTOWRAP_WORD
	exl.position = Vector2(20, p.size.y - 104)
	exl.size = Vector2(pw - 40.0, 40)
	p.add_child(exl)
	var msg := _label(str(bd.get("msg", "")), 17, Color.WHITE)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.position = Vector2(20, 164)
	msg.size = Vector2(pw - 40.0, 80)
	p.add_child(msg)
	var bn := _label("At 80 or more the board adds 20%% to the %s you win in matches." % _mw() + ("  IT DOES NOW!" if bool(bd.get("bonus", false)) else ""), 14, GOLD if bool(bd.get("bonus", false)) else Color(1, 1, 1, 0.6), font2)
	bn.autowrap_mode = TextServer.AUTOWRAP_WORD
	bn.position = Vector2(20, p.size.y - 58)
	bn.size = Vector2(pw - 40.0, 44)
	p.add_child(bn)

# One goal from the board: what it is, where it stands now, and a coloured tag.
func _obj_row(p: Panel, tag: String, what: String, now: String, st: String, pw: float, ph: float) -> void:
	var tg := _label(tag, 13, GOLD, font2)
	tg.position = Vector2(20, 10)
	p.add_child(tg)
	var fs := 20
	while fs > 14 and font.get_string_size(what, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > pw - 220.0:
		fs -= 1
	var wl := _label(what, fs, Color.WHITE)
	wl.position = Vector2(20, 28)
	wl.size = Vector2(pw - 210.0, 30)
	wl.clip_text = true
	p.add_child(wl)
	var nl := _label(now, 15, Color(1, 1, 1, 0.7), font2)
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
	var ct := _label(str(names.get(st, st.to_upper())), 17, col)
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
		var s := _label(small, 18, Color(1, 1, 1, 0.75), font2)
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
			if _starts.get(e.index, e.position).y - e.position.y > 30.0:
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
