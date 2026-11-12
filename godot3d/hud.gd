extends Control
# Touch controls (floating joystick + buttons), score bug and big banners.

var stick := Vector2.ZERO
var shoot_down := false
var pass_down := false
var sprint_down := false
var ev := [] # queued events: "shoot_down", "shoot_up", "pass_down", "pass_up", "cam", "tap"
var charge := 0.0
var lab_a := "SHOOT"
var lab_b := "PASS"
var show_controls := true
var cam_name := "TV"

var _stick_id := -1
var _stick_base := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _ids := {} # touch index -> button name
var _font: Font

var score_lbl: Label
var clock_lbl: Label
var banner: Label
var sub: Label
var flash: ColorRect
var bug: Panel
var title: Control
var _banner_tw: Tween

const STICK_R := 62.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	# score bug
	bug = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.06, 0.82)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(1, 1, 1, 0.14)
	sb.set_border_width_all(1)
	bug.add_theme_stylebox_override("panel", sb)
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
	score_lbl = _label(22, Color.WHITE)
	score_lbl.position = Vector2(22, 6)
	score_lbl.size = Vector2(184, 32)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.text = "BIS  0 - 0  SHA"
	bug.add_child(score_lbl)
	clock_lbl = _label(20, Color(1.0, 0.86, 0.3))
	clock_lbl.position = Vector2(220, 7)
	clock_lbl.size = Vector2(64, 32)
	clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_lbl.text = "0'"
	bug.add_child(clock_lbl)
	# banners
	banner = _label(96, Color.WHITE)
	banner.add_theme_constant_override("outline_size", 18)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0
	add_child(banner)
	sub = _label(26, Color.WHITE)
	sub.add_theme_constant_override("outline_size", 8)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.modulate.a = 0.0
	add_child(sub)

func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func set_score(a: int, b: int) -> void:
	score_lbl.text = "BIS  %d - %d  SHA" % [a, b]

func set_clock(minute: int) -> void:
	clock_lbl.text = "%d'" % minute

func pop_score() -> void:
	bug.pivot_offset = bug.size * 0.5
	var tw := create_tween()
	tw.tween_property(bug, "scale", Vector2(1.35, 1.35), 0.12)
	tw.tween_property(bug, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func show_banner(text: String, col: Color, hold := 1.6, small := "") -> void:
	if _banner_tw:
		_banner_tw.kill()
	banner.text = text
	banner.add_theme_color_override("font_color", col)
	banner.pivot_offset = size * 0.5
	banner.scale = Vector2(3.2, 3.2)
	banner.modulate.a = 0.0
	banner.rotation = -0.08
	sub.text = small
	sub.position.y = 84
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

func _btn_pos() -> Dictionary:
	var s := size
	return {
		"shoot": [Vector2(s.x - 92, s.y - 92), 56.0],
		"pass": [Vector2(s.x - 218, s.y - 66), 46.0],
		"sprint": [Vector2(s.x - 74, s.y - 218), 38.0],
	}

func _cam_rect() -> Rect2:
	return Rect2(size.x - 128, 14, 110, 40)

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var p: Vector2 = e.position
		if e.pressed:
			ev.append("tap")
			if _cam_rect().grow(8).has_point(p):
				ev.append("cam")
				return
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
		queue_redraw()
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
			queue_redraw()

func _set_btn(k: String, down: bool) -> void:
	if k == "shoot":
		shoot_down = down
		ev.append("shoot_down" if down else "shoot_up")
	elif k == "pass":
		pass_down = down
		ev.append("pass_down" if down else "pass_up")
	elif k == "sprint":
		sprint_down = down

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	# camera button
	var r := _cam_rect()
	draw_style_box(_pill(Color(0.04, 0.07, 0.06, 0.7)), r)
	_text("CAM: " + cam_name, r.position + Vector2(r.size.x * 0.5, 27), 16, Color(1, 1, 1, 0.9))
	if not show_controls:
		return
	var b := _btn_pos()
	_button(b["shoot"][0], b["shoot"][1], lab_a, shoot_down, Color(0.25, 0.85, 0.4))
	_button(b["pass"][0], b["pass"][1], lab_b, pass_down, Color(0.95, 0.95, 0.95))
	_button(b["sprint"][0], b["sprint"][1], "SPRINT", sprint_down, Color(1.0, 0.82, 0.25))
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

func _pill(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(10)
	return s

func _button(c: Vector2, rad: float, text: String, down: bool, col: Color) -> void:
	var k := 0.92 if down else 1.0
	draw_circle(c, rad * k, Color(col.r, col.g, col.b, 0.5 if down else 0.2))
	draw_arc(c, rad * k, 0, TAU, 48, Color(col.r, col.g, col.b, 0.9), 3.0, true)
	_text(text, c + Vector2(0, 6), 17 if rad > 50.0 else 14, Color(1, 1, 1, 0.95))

func _text(t: String, at: Vector2, fs: int, col: Color) -> void:
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(_font, at - Vector2(w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
	draw_string(_font, at - Vector2(w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
