extends Control
# Everything drawn on top of the 3D view: touch controls, score bug, banners, minimap and all menus.

var stick := Vector2.ZERO
var shoot_down := false
var pass_down := false
var sprint_down := false
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
const GREEN := Color(0.2, 0.78, 0.38)
const GOLD := Color(1.0, 0.84, 0.25)
const DARK := Color(0.04, 0.08, 0.06)

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
		if on_action.is_valid():
			on_action.call(act, arg))
	return b

func _ord(n: int) -> String:
	return str(n) + (["TH", "ST", "ND", "RD"][n] if n < 4 else "TH")

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
	var chosen: bool = big and ci == int(info.get("club", -1))
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
	banner.scale = Vector2(3.2, 3.2)
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
	shade.color = Color(0.0, 0.03, 0.02, 0.45 if n in ["main", "full"] else 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(shade)
	var items := [] # [control, slide-from, delay]
	match n:
		"main":
			var t1 := _label("BANEBOLD", 92, Color.WHITE)
			t1.add_theme_constant_override("outline_size", 14)
			t1.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
			t1.position = Vector2(48, h * 0.5 - 118)
			menu.add_child(t1)
			items.append([t1, Vector2(-80, 0), 0.0])
			var t2 := _label("3D  PROTOTYPE", 30, GOLD)
			t2.add_theme_constant_override("outline_size", 8)
			t2.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
			t2.position = Vector2(54, h * 0.5 - 8)
			menu.add_child(t2)
			items.append([t2, Vector2(-80, 0), 0.08])
			var t3 := _label("Play the match yourself", 20, Color(1, 1, 1, 0.8), font2)
			t3.position = Vector2(54, h * 0.5 + 34)
			menu.add_child(t3)
			items.append([t3, Vector2(-80, 0), 0.14])
			var ver := _label(str(info.get("version", "")), 14, Color(1, 1, 1, 0.6), font2)
			ver.position = Vector2(16, h - 28)
			menu.add_child(ver)
			var bx := w - 372.0
			var by := h * 0.5 - 132.0
			var play := _btn("PLAY", "play", null, "primary", Vector2(bx, by), Vector2(324, 92), 44)
			menu.add_child(play)
			items.append([play, Vector2(120, 0), 0.1])
			var fr := _btn("PLAY WITH A FRIEND", "friend", null, "alt", Vector2(bx, by + 106), Vector2(324, 66), 24)
			menu.add_child(fr)
			items.append([fr, Vector2(120, 0), 0.18])
			var d := _btn("LEVEL: " + str(info.get("diff", "")), "diff", null, "ghost", Vector2(bx, by + 186), Vector2(156, 52), 17)
			menu.add_child(d)
			items.append([d, Vector2(120, 0), 0.26])
			var l := _btn("MATCH: " + str(info.get("len", "")), "len", null, "ghost", Vector2(bx + 168, by + 186), Vector2(156, 52), 17)
			menu.add_child(l)
			items.append([l, Vector2(120, 0), 0.3])
			by -= 46.0
			play.position.y = by
			play.size.y = 80
			play.pivot_offset = play.size * 0.5
			var cr := _btn("CAREER", "career", null, "alt", Vector2(bx, by + 92), Vector2(324, 70), 30)
			cr.add_theme_color_override("font_color", GOLD)
			menu.add_child(cr)
			items.append([cr, Vector2(120, 0), 0.14])
			fr.position.y = by + 174
			fr.size.y = 60
			d.position.y = by + 246
			l.position.y = by + 246
			var tb := _club_btn(info, int(info.get("club", 0)), "teams", null, Vector2(bx, by + 310), Vector2(324, 52), "TEAM:  ")
			menu.add_child(tb)
			items.append([tb, Vector2(120, 0), 0.34])
			if anim:
				play.ready.connect(func(): _pulse(play))
			else:
				_pulse(play)
		"career":
			var c: Dictionary = info.get("car", {})
			var t0 := _label(str(c.get("name", "")), 40, Color.WHITE)
			t0.position = Vector2(160, 10)
			menu.add_child(t0)
			var sub0 := _label("SEASON %d   ·   ROUND %d OF %d   ·   %s PLACE   ·   TEAM RATING %d" % [int(c.get("season", 1)), mini(int(c.get("round", 0)) + 1, int(c.get("rounds", 14))), int(c.get("rounds", 14)), _ord(int(c.get("rank", 1))), int(c.get("str", 0))], 16, Color(1, 1, 1, 0.8), font2)
			sub0.position = Vector2(162, 58)
			menu.add_child(sub0)
			var co := _label("COINS  %d" % int(c.get("coins", 0)), 24, GOLD)
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
			var sq := _btn("SQUAD", "c_squad", null, "alt", Vector2(rx2, 100), Vector2(rw / 3.0 - 6, 78), 21)
			var mkb := _btn("TRANSFERS", "c_market", null, "alt", Vector2(rx2 + rw / 3.0 + 3, 100), Vector2(rw / 3.0 - 6, 78), 21)
			var tbn := _btn("TABLE", "c_table", null, "alt", Vector2(rx2 + rw * 2.0 / 3.0 + 6, 100), Vector2(rw / 3.0 - 6, 78), 21)
			menu.add_child(sq)
			menu.add_child(mkb)
			items.append([mkb, Vector2(80, 0), 0.08])
			menu.add_child(tbn)
			items.append([sq, Vector2(80, 0), 0.05])
			items.append([tbn, Vector2(80, 0), 0.1])
			var lp := Panel.new()
			lp.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.8), 14))
			lp.position = Vector2(rx2, 192)
			lp.size = Vector2(rw, 190)
			lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu.add_child(lp)
			var lh := _label("LAST ROUND", 16, GOLD, font2)
			lh.position = Vector2(16, 10)
			lp.add_child(lh)
			var lst: Array = c.get("last", [])
			if lst.is_empty():
				var le := _label("The season starts now. Win matches to earn coins, and your players grow as they play.", 16, Color(1, 1, 1, 0.8), font2)
				le.autowrap_mode = TextServer.AUTOWRAP_WORD
				le.position = Vector2(16, 42)
				le.size = Vector2(rw - 32, 120)
				lp.add_child(le)
			for li in lst.size():
				var ll := _label(str(lst[li]), 19, Color.WHITE)
				ll.position = Vector2(16, 40 + li * 34)
				ll.size = Vector2(rw - 32, 30)
				ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lp.add_child(ll)
			var nw2 := _btn("SURE? TAP AGAIN" if bool(c.get("sure", false)) else "START OVER", "c_new", null, "ghost", Vector2(rx2 + rw - 190, 396), Vector2(190, 42), 15)
			menu.add_child(nw2)
			var bk0 := _btn("<  BACK", "back", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18)
			menu.add_child(bk0)
		"table":
			_title("LEAGUE TABLE", "")
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
		"squad":
			_title("SQUAD", "Tap two players to swap them")
			var c3: Dictionary = info.get("car", {})
			var sqd: Array = c3.get("squad", [])
			var xi: Array = c3.get("xi", [])
			var sel: int = int(c3.get("sel", -1))
			var form: Array = c3.get("form", [])
			var pw := w * 0.58 - 50.0
			var ph := h - 116.0
			var pp := Panel.new()
			pp.add_theme_stylebox_override("panel", _box(Color(0.10, 0.36, 0.17, 0.92), 16, Color(1, 1, 1, 0.35)))
			pp.position = Vector2(30, 100)
			pp.size = Vector2(pw, ph)
			pp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu.add_child(pp)
			var mid := ColorRect.new()
			mid.color = Color(1, 1, 1, 0.25)
			mid.position = Vector2(pw - 3, 0)
			mid.size = Vector2(2, ph)
			pp.add_child(mid)
			var pcol := {"GK": Color(0.95, 0.6, 0.1), "DF": Color(0.3, 0.6, 1.0), "MF": Color(0.3, 0.85, 0.45), "FW": Color(0.95, 0.3, 0.3)}
			var bw := minf(114.0, pw / 4.4)
			for si2 in xi.size():
				var pl: Dictionary = sqd[int(xi[si2])]
				var fx2: float = 0.0 if si2 == 0 else clampf(0.24 + (float(form[si2][1]) - 0.15) / 0.59 * 0.76, 0.0, 1.0)
				var fy: float = 0.5 + float(form[si2][2]) * 0.44
				var pb := _player_btn(pl, int(xi[si2]), Vector2(30 + fx2 * (pw - bw - 12) + 6, 100 + fy * (ph - 56) + 4), Vector2(bw, 48), pcol, int(xi[si2]) == sel, str(form[si2][0]) != str(pl["pos"]))
				menu.add_child(pb)
			var bx3 := 30 + pw + 16.0
			var bw3 := w - bx3 - 30.0
			var bl := _label("BENCH", 15, Color(1, 1, 1, 0.7), font2)
			bl.position = Vector2(bx3, 96)
			menu.add_child(bl)
			var bn := 0
			var bcols := 3 if sqd.size() - 11 <= 6 else 4
			for qi in sqd.size():
				if xi.has(qi) or xi.has(float(qi)):
					continue
				var bb := _player_btn(sqd[qi], qi, Vector2(bx3 + (bn % bcols) * (bw3 / bcols), 118 + (bn / bcols) * 54), Vector2(bw3 / bcols - 6, 48), pcol, qi == sel, false)
				menu.add_child(bb)
				bn += 1
			var dp := Panel.new()
			dp.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.9), 14, Color(1, 1, 1, 0.14)))
			dp.position = Vector2(bx3, 232)
			dp.size = Vector2(bw3, h - 232 - 16)
			dp.mouse_filter = Control.MOUSE_FILTER_PASS
			menu.add_child(dp)
			if sel >= 0 and sel < sqd.size():
				var sp2: Dictionary = sqd[sel]
				var dn := _label("%d  %s" % [int(sp2["num"]), str(sp2["n"])], 26, Color.WHITE)
				dn.position = Vector2(16, 8)
				dp.add_child(dn)
				var dd := _label("%s   ·   AGE %d   ·   RATING %d  (CAN REACH %d)   ·   %d GOALS" % [str(sp2["pos"]), int(sp2["age"]), int(sp2["ovr"]), int(sp2["pot"]), int(sp2["g"])], 13, Color(1, 1, 1, 0.75), font2)
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
				var xl := _label("GROWS BY PLAYING MATCHES" if int(sp2["ovr"]) < int(sp2["pot"]) else "AT HIS BEST", 11, Color(1, 1, 1, 0.6), font2)
				xl.position = Vector2(16, 162)
				dp.add_child(xl)
				var can: bool = int(c3.get("coins", 0)) >= int(sp2["cost"]) and int(sp2["ovr"]) < int(sp2["pot"])
				var on_bench: bool = not (xi.has(sel) or xi.has(float(sel)))
				var tw3 := (bw3 - 32) * (0.6 if on_bench else 1.0)
				var trb := _btn("TRAIN  +1   (%d COINS)" % int(sp2["cost"]), "c_train", null, "primary" if can else "off", Vector2(bx3 + 16, 232 + dp.size.y - 62), Vector2(tw3, 48), 17)
				menu.add_child(trb)
				if on_bench:
					var sure2: bool = int(c3.get("sell_sure", -1)) == sel
					var slb := _btn("SURE? TAP AGAIN" if sure2 else "SELL  (%d)" % int(sp2["sell"]), "c_sell", null, "ghost", Vector2(bx3 + 16 + tw3 + 8, 232 + dp.size.y - 62), Vector2(bw3 - 32 - tw3 - 8, 48), 14)
					menu.add_child(slb)
			else:
				var hint2 := _label("Tap a player to see him.
Tap another to swap the two.
A yellow mark means he is playing out of position.", 15, Color(1, 1, 1, 0.75), font2)
				hint2.position = Vector2(16, 14)
				hint2.size = Vector2(bw3 - 32, 120)
				hint2.autowrap_mode = TextServer.AUTOWRAP_WORD
				dp.add_child(hint2)
			if str(c3.get("msg", "")) != "":
				var ms := _label(str(c3.get("msg", "")), 15, GOLD, font2)
				ms.position = Vector2(bx3 + 16, 232 + dp.size.y - 90)
				menu.add_child(ms)
			var co3 := _label("COINS  %d" % int(c3.get("coins", 0)), 22, GOLD)
			co3.position = Vector2(w - 260, 20)
			co3.size = Vector2(230, 34)
			co3.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(co3)
			var bk3 := _btn("<  BACK", "career", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18)
			var fb := _btn("FORMATION:  " + str(c3.get("fname", "4-3-3")), "c_form", null, "alt", Vector2(158, 14), Vector2(230, 48), 17)
			menu.add_child(fb)
			menu.add_child(bk3)
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
		"market":
			_title("TRANSFERS", "New players are offered after every match")
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
				var p5 := _label({"GK": "GOALKEEPER", "DF": "DEFENDER", "MF": "MIDFIELDER", "FW": "FORWARD"}[str(mp["pos"])], 12, pcol5.get(str(mp["pos"]), Color.WHITE), font2)
				p5.position = Vector2(0.04 * tw5, cy5 + 2)
				rp5.add_child(p5)
				var vals5 := [[str(mp["age"]), 0.27, 18, Color(1, 1, 1, 0.85)], [str(mp["ovr"]), 0.35, 26, GOLD], [str(mp["pot"]), 0.44, 20, GREEN.lightened(0.3)],
					[str(mp["st"][0]), 0.56, 17, Color.WHITE], [str(mp["st"][1]), 0.62, 17, Color.WHITE], [str(mp["st"][2]), 0.68, 17, Color.WHITE], [str(mp["st"][3]), 0.74, 17, Color.WHITE]]
				for v5 in vals5:
					var vl5 := _label(str(v5[0]), int(v5[2]), v5[3])
					vl5.position = Vector2(float(v5[1]) * tw5, cy5 - int(v5[2]) * 0.72)
					rp5.add_child(vl5)
				var can5: bool = int(c5.get("coins", 0)) >= int(mp["price"])
				var bb5 := _btn("BUY   %d" % int(mp["price"]), "c_buy", mi, "primary" if can5 else "alt", Vector2(tx5 + tw5 * 0.81, 114 + mi * rh5 + 6), Vector2(tw5 * 0.19 - 8, rh5 - 18), 18)
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
			var co5 := _label("COINS  %d" % int(c5.get("coins", 0)), 22, GOLD)
			co5.position = Vector2(w - 260, 20)
			co5.size = Vector2(230, 34)
			co5.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(co5)
			var bk5 := _btn("<  BACK", "career", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18)
			menu.add_child(bk5)
		"teams":
			_title("PICK YOUR TEAM", "")
			var cl: Array = info.get("clubs", [])
			var gw := minf(250.0, (w - 100.0) / 4.0 - 12.0)
			var gx := (w - (gw + 12.0) * 4.0 + 12.0) * 0.5
			for ci in cl.size():
				var cb := _club_btn(info, ci, "club", ci, Vector2(gx + (ci % 4) * (gw + 12.0), 96 + (ci / 4) * 172.0), Vector2(gw, 156), "")
				menu.add_child(cb)
				items.append([cb, Vector2(0, 50), 0.03 * ci])
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
				var tb2 := _club_btn(info, int(info.get("club", 0)), "teams", null, Vector2(48, 318), Vector2(260, 50), "TEAM:  ")
				menu.add_child(tb2)
				var rx := w - col_w - 40.0
				var cot := str(info.get("co_text", ""))
				var md := _btn(("CAREER TOGETHER" if cot != "" else "SAME TEAM") if str(info.get("mode", "")) == "coop" else "AGAINST EACH OTHER", "mode", null, "alt", Vector2(rx, 92), Vector2(col_w, 62), 24)
				menu.add_child(md)
				items.append([md, Vector2(80, 0), 0.05])
				var mh := _label((cot if cot != "" else "You two against the computer") if str(info.get("mode", "")) == "coop" else "Your team against your friend's: " + str(info["clubs"][int(info.get("gclub", 1))]["n"]), 16, Color(1, 1, 1, 0.75), font2)
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
						txt = "CAREER TOGETHER:   " + str(info.get("co_text", ""))
				var s3 := _label(txt, 20, Color(1, 1, 1, 0.8), font2)
				s3.position = Vector2(0, h * 0.5 + 10)
				s3.size = Vector2(w, 30)
				s3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				menu.add_child(s3)
				if conn:
					var tb3 := _club_btn(info, int(info.get("club", 0)), "teams", null, Vector2(w * 0.5 - 170, h * 0.5 + 60), Vector2(340, 56), "YOUR TEAM:  ")
					menu.add_child(tb3)
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
				["PASS", "Tap for a pass along the ground. Hold for a high ball."],
				["TACKLE", "Without the ball: win it back. Never from behind, that is a foul."],
				["SWITCH", "Without the ball: change to the player nearest the ball."],
				["SPRINT", "Hold to run faster. Tap twice with the ball to spin past a defender."],
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
			var ph0 := 332.0 if can_sub else 260.0
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
			panel.add_child(_btn("LEAVE MATCH", "menu", null, "alt" if not can_sub else "ghost", Vector2(30, 236 if can_sub else 164), Vector2(pw - 60, 60), 22))
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
			if str(info.get("role", "")) == "guest":
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
				var ag := _btn("NEXT MATCH" if co_car else "PLAY AGAIN", "again", null, "primary", Vector2(w * 0.5 - 320, by2), Vector2(300, 70), 30)
				var mb2 := _btn("MAIN MENU", "menu", null, "alt", Vector2(w * 0.5 + 20, by2), Vector2(300, 70), 24)
				menu.add_child(ag)
				menu.add_child(mb2)
				items.append([ag, Vector2(0, 60), 0.5])
				items.append([mb2, Vector2(0, 60), 0.58])
			if not cls.is_empty():
				var shown := []
				for ci4 in mini(cls.size(), 4):
					shown.append(str(cls[ci4]))
				if cls.size() > 4:
					shown.append("+%d MORE" % (cls.size() - 4))
				var cll := _label("     ·     ".join(PackedStringArray(shown)), 19, GOLD)
				cll.position = Vector2(0, h * 0.5 + 30)
				cll.size = Vector2(w, 24)
				cll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				menu.add_child(cll)
	if n in ["friend", "join", "lobby"]:
		var back := _btn("<  BACK", "back", null, "ghost", Vector2(16, 14), Vector2(130, 48), 18)
		menu.add_child(back)
	if anim:
		for it in items:
			_slide_in(it[0], it[1], it[2])

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
		"sprint": [Vector2(s.x - 74, s.y - 218), 38.0],
	}

func _cam_rect() -> Rect2:
	return Rect2(size.x - 128, 14, 110, 40)

func _pause_rect() -> Rect2:
	return Rect2(size.x - 182, 14, 44, 40)

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
			if _cam_rect().grow(6).has_point(p):
				ev.append("cam")
				return
			if _pause_rect().grow(6).has_point(p):
				ev.append("pause")
				return
			ev.append("tap")
			if not show_controls:
				return
			var b := _btn_pos()
			for k in b:
				if p.distance_to(b[k][0]) < b[k][1] + 14.0:
					_ids[e.index] = k
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
			elif _ids.has(e.index):
				_set_btn(_ids[e.index], false)
				_ids.erase(e.index)
	elif e is InputEventScreenDrag:
		if e.index == _stick_id:
			_stick_pos = e.position
			var d := _stick_pos - _stick_base
			if d.length() > STICK_R:
				# the base follows the thumb so the stick never gets stuck at the edge
				_stick_base = _stick_pos - d.normalized() * STICK_R
				d = _stick_pos - _stick_base
			stick = d / STICK_R
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
	elif k == "sprint":
		sprint_down = down

# ---------------------------------------------------------------- drawing

func _process(dt: float) -> void:
	_t += dt / maxf(Engine.time_scale, 0.05)
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
	var r := _cam_rect()
	draw_style_box(_box(Color(DARK.r, DARK.g, DARK.b, 0.7), 10), r)
	_text("CAM: " + cam_name, r.position + Vector2(r.size.x * 0.5, 27), 16, Color(1, 1, 1, 0.9))
	var pr := _pause_rect()
	draw_style_box(_box(Color(DARK.r, DARK.g, DARK.b, 0.7), 10), pr)
	draw_rect(Rect2(pr.position + Vector2(14, 11), Vector2(5, 18)), Color(1, 1, 1, 0.9))
	draw_rect(Rect2(pr.position + Vector2(25, 11), Vector2(5, 18)), Color(1, 1, 1, 0.9))
	if not show_controls:
		return
	_minimap()
	var b := _btn_pos()
	_button(b["shoot"][0], b["shoot"][1], lab_a, shoot_down, Color(0.25, 0.85, 0.4))
	_button(b["pass"][0], b["pass"][1], lab_b, pass_down, Color(0.95, 0.95, 0.95))
	_button(b["sprint"][0], b["sprint"][1], "SPRINT", sprint_down, GOLD if stam > 0.3 else Color(0.9, 0.35, 0.25))
	draw_arc(b["sprint"][0], b["sprint"][1] + 7.0, -PI * 0.5, -PI * 0.5 + TAU * stam, 40, Color(1.0, 0.84, 0.25, 0.85) if stam > 0.3 else Color(0.95, 0.3, 0.2, 0.9), 4.0, true)
	if ctrl_name != "":
		_text(ctrl_name, Vector2(size.x * 0.5, size.y - 138.0 * 68.0 / 105.0 - 20.0), 16, Color(1, 1, 1, 0.9))
	if charge > 0.0:
		var c: Vector2 = b["shoot"][0]
		var col := Color(1.0, 0.9, 0.2).lerp(Color(1.0, 0.25, 0.15), clampf((charge - 0.6) / 0.4, 0.0, 1.0))
		draw_arc(c, b["shoot"][1] + 9.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, col, 7.0, true)
	if _stick_id != -1:
		draw_circle(_stick_base, STICK_R + 8.0, Color(1, 1, 1, 0.10))
		draw_arc(_stick_base, STICK_R + 8.0, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
		draw_circle(_stick_base + stick * STICK_R, 30.0, Color(1, 1, 1, 0.55))
	else:
		var hint := Vector2(120, size.y - 110)
		draw_arc(hint, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.16), 2.0, true)
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
