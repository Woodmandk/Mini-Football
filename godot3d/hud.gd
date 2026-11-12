extends Control
# Everything drawn on top of the 3D view: touch controls, score bug, banners, minimap and all menus.

var stick := Vector2.ZERO
var shoot_down := false
var pass_down := false
var sprint_down := false
var ev := [] # queued events: "shoot_down", "shoot_up", "pass_down", "pass_up", "cam", "pause", "tap"
var charge := 0.0
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
	c1.color = Color(0.86, 0.16, 0.16)
	c1.position = Vector2(10, 10)
	c1.size = Vector2(6, 24)
	bug.add_child(c1)
	var c2 := ColorRect.new()
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

func set_score(a: int, b: int) -> void:
	score_lbl.text = "BIS  %d - %d  SHA" % [a, b]

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
			if anim:
				play.ready.connect(func(): _pulse(play))
			else:
				_pulse(play)
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
				var rx := w - col_w - 40.0
				var md := _btn("SAME TEAM" if str(info.get("mode", "")) == "coop" else "AGAINST EACH OTHER", "mode", null, "alt", Vector2(rx, 92), Vector2(col_w, 62), 24)
				menu.add_child(md)
				items.append([md, Vector2(80, 0), 0.05])
				var mh := _label("You two against the computer" if str(info.get("mode", "")) == "coop" else "You (red) against your friend (blue)", 16, Color(1, 1, 1, 0.75), font2)
				mh.position = Vector2(rx + 4, 158)
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
					txt = "Waiting for the host to start.   Mode: " + ("SAME TEAM" if str(info.get("mode", "")) == "coop" else "AGAINST EACH OTHER (you are blue)")
				var s3 := _label(txt, 20, Color(1, 1, 1, 0.8), font2)
				s3.position = Vector2(0, h * 0.5 + 10)
				s3.size = Vector2(w, 30)
				s3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				menu.add_child(s3)
		"pause":
			var pw := 340.0
			var panel := Panel.new()
			panel.add_theme_stylebox_override("panel", _box(Color(DARK.r, DARK.g, DARK.b, 0.94), 20, Color(1, 1, 1, 0.16)))
			panel.position = Vector2((w - pw) * 0.5, h * 0.5 - 130)
			panel.size = Vector2(pw, 260)
			menu.add_child(panel)
			var pt := _label("PAUSED" if not bool(info.get("online", false)) else "MENU", 34, Color.WHITE)
			pt.position = Vector2(0, 16)
			pt.size = Vector2(pw, 44)
			pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			panel.add_child(pt)
			panel.add_child(_btn("RESUME", "resume", null, "primary", Vector2(30, 76), Vector2(pw - 60, 72), 30))
			panel.add_child(_btn("LEAVE MATCH", "menu", null, "alt", Vector2(30, 164), Vector2(pw - 60, 60), 22))
			items.append([panel, Vector2(0, 60), 0.0])
		"full":
			var ft := _label("FULL TIME", 30, GOLD)
			ft.position = Vector2(0, h * 0.5 - 150)
			ft.size = Vector2(w, 40)
			ft.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			menu.add_child(ft)
			var sc := _label(str(info.get("score", "")), 120, Color.WHITE)
			sc.add_theme_constant_override("outline_size", 16)
			sc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
			sc.position = Vector2(0, h * 0.5 - 122)
			sc.size = Vector2(w, 130)
			sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sc.pivot_offset = Vector2(w * 0.5, 65)
			menu.add_child(sc)
			var tn := _label("RED BISON", 22, Color(1.0, 0.55, 0.5), font2)
			tn.position = Vector2(0, h * 0.5 - 76)
			tn.size = Vector2(w * 0.5 - 190, 30)
			tn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			menu.add_child(tn)
			var tn2 := _label("HARBOUR SHARKS", 22, Color(0.55, 0.75, 1.0), font2)
			tn2.position = Vector2(w * 0.5 + 190, h * 0.5 - 76)
			menu.add_child(tn2)
			var rs := _label(str(info.get("result", "")), 40, GREEN.lightened(0.35) if str(info.get("result", "")).begins_with("YOU WIN") else Color.WHITE)
			rs.position = Vector2(0, h * 0.5 + 14)
			rs.size = Vector2(w, 50)
			rs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			menu.add_child(rs)
			if anim:
				sc.scale = Vector2(2.6, 2.6)
				sc.modulate.a = 0.0
				var tw := sc.create_tween()
				tw.set_parallel(true)
				tw.tween_property(sc, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(sc, "modulate:a", 1.0, 0.2)
			items.append([rs, Vector2(0, 40), 0.35])
			var by2 := h - 96.0
			if str(info.get("role", "")) == "guest":
				var wt := _label("Waiting for the host...", 20, Color(1, 1, 1, 0.8), font2)
				wt.position = Vector2(w * 0.5 - 330, by2 + 22)
				menu.add_child(wt)
				var mb := _btn("MAIN MENU", "menu", null, "alt", Vector2(w * 0.5 + 20, by2), Vector2(300, 70), 24)
				menu.add_child(mb)
				items.append([mb, Vector2(0, 60), 0.5])
			else:
				var ag := _btn("PLAY AGAIN", "again", null, "primary", Vector2(w * 0.5 - 320, by2), Vector2(300, 70), 30)
				var mb2 := _btn("MAIN MENU", "menu", null, "alt", Vector2(w * 0.5 + 20, by2), Vector2(300, 70), 24)
				menu.add_child(ag)
				menu.add_child(mb2)
				items.append([ag, Vector2(0, 60), 0.5])
				items.append([mb2, Vector2(0, 60), 0.58])
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
	bug.visible = in_match and not replay_on
	queue_redraw()

func _draw() -> void:
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
	# camera + pause buttons
	var r := _cam_rect()
	draw_style_box(_box(Color(DARK.r, DARK.g, DARK.b, 0.7), 10), r)
	_text("CAM: " + cam_name, r.position + Vector2(r.size.x * 0.5, 27), 16, Color(1, 1, 1, 0.9))
	var pr := _pause_rect()
	draw_style_box(_box(Color(DARK.r, DARK.g, DARK.b, 0.7), 10), pr)
	draw_rect(Rect2(pr.position + Vector2(14, 11), Vector2(5, 18)), Color(1, 1, 1, 0.9))
	draw_rect(Rect2(pr.position + Vector2(25, 11), Vector2(5, 18)), Color(1, 1, 1, 0.9))
	_minimap()
	if not show_controls:
		return
	var b := _btn_pos()
	_button(b["shoot"][0], b["shoot"][1], lab_a, shoot_down, Color(0.25, 0.85, 0.4))
	_button(b["pass"][0], b["pass"][1], lab_b, pass_down, Color(0.95, 0.95, 0.95))
	_button(b["sprint"][0], b["sprint"][1], "SPRINT", sprint_down, GOLD)
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
			draw_circle(q, 2.6, Color(0.95, 0.25, 0.25) if p.z < 0.5 else Color(0.35, 0.6, 1.0))
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
