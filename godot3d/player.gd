extends Node3D
# One footballer: a low-poly figure built from simple shapes, animated in code.

var team := 0
var idx := 0
var role := "MF" # GK, DF, MF, FW
var home := Vector2.ZERO # formation spot: x 0..1 own goal -> opponent goal, y -1..1 across
var vel := Vector3.ZERO
var yaw := 0.0
var top_speed := 7.4
var sprinting := false
var stun := 0.0
var recv := false
var press_t := 0.0
var step_t := 0.0
var wait_t := 0.0
var jock := false
var ball_side := 0.0
var think_t := 0.0
var think_at := Vector3.ZERO
var touch_ph := 0.0
var acc_k := 1.0
var turn_k := 1.0
var carry_k := 0.92
var phy := 60.0
var ai_cool := 0.0
var hold_t := 0.0
var react_t := 0.0

# animation state
var phase := 0.0
var kick_t := -1.0
var kick_pw := 0.7
var kick_kind := 0
var head_t := -1.0
var throw_t := -1.0
var skill_t := -1.0
var hold_up := false
var fall_t := -1.0
var fall_dur := 0.6
var fall_n := 0
var windup := 0.0
var _yaw_prev := 0.0
var _turn := 0.0
var _idle_t := 0.0
var tackle_t := -1.0
var feet := false # keeper only: he has the ball at his feet (back pass), not in his hands
var slide_live := false
var dive_t := -1.0
var dive_side := 0.0
var mood := 0 # 0 normal, 1 scorer, 2 happy, 3 sad
var mood_t := 0.0
var off := false
var yellow := 0
var offside := false
var commit_t := -1.0
var kick_n := 0
var tackle_n := 0
var dive_n := 0
var pname := ""
var pac := 70
var sho := 65
var pas := 65
var dfn := 60
var ovr := 70
var star := false
var fit := 1.0 # match fitness: drains as he runs, slows him when low
var base_top := 7.0
var num_label: Label3D = null
var sq := -1
var num := 0
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var marker: MeshInstance3D
var blob: MeshInstance3D
var ring_mat: StandardMaterial3D

var body: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var ring: MeshInstance3D

static var _mats := {}

static func mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var k := c.to_html() + str(rough)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[k] = m
	return _mats[k]

func _part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi

static var _meshes := {}
static func _capsule(r: float, h: float) -> CapsuleMesh:
	var k := "c%s_%s" % [r, h]
	if not _meshes.has(k):
		var c := CapsuleMesh.new()
		c.radius = r
		c.height = h
		c.radial_segments = 10
		c.rings = 3
		_meshes[k] = c
	return _meshes[k]
static func _sphere(r: float) -> SphereMesh:
	var k := "s%s" % r
	if not _meshes.has(k):
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = 12
		s.rings = 6
		_meshes[k] = s
	return _meshes[k]
static func _cyl(rt: float, rb: float, h: float) -> CylinderMesh:
	var k := "y%s_%s_%s" % [rt, rb, h]
	if not _meshes.has(k):
		var c := CylinderMesh.new()
		c.top_radius = rt
		c.bottom_radius = rb
		c.height = h
		c.radial_segments = 10
		c.rings = 1
		_meshes[k] = c
	return _meshes[k]
static func _box(v: Vector3) -> BoxMesh:
	var k := "b%s" % v
	if not _meshes.has(k):
		var b := BoxMesh.new()
		b.size = v
		_meshes[k] = b
	return _meshes[k]

func build(shirt: Color, shorts: Color, socks: Color, skin: Color, hair: Color, boots: Color) -> void:
	body = Node3D.new()
	add_child(body)
	var NS := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var trim := shorts if shorts.to_html() != shirt.to_html() else socks
	var skin_m := mat(skin, 0.62)
	# hips / shorts
	_part(body, _cyl(0.178, 0.212, 0.26), mat(shorts), Vector3(0, 0.95, 0), Vector3(1.0, 1.0, 0.64))
	# torso: narrow waist, wide chest, real shoulders
	torso = Node3D.new()
	torso.position = Vector3(0, 1.05, 0)
	body.add_child(torso)
	_part(torso, _cyl(0.215, 0.165, 0.54), mat(shirt), Vector3(0, 0.29, 0), Vector3(1.0, 1.0, 0.62))
	_part(torso, _capsule(0.098, 0.56), mat(shirt), Vector3(0, 0.535, 0), Vector3(1.0, 1.0, 1.2)).rotation.z = PI * 0.5
	_part(torso, _cyl(0.07, 0.085, 0.04), mat(trim), Vector3(0, 0.645, 0)).cast_shadow = NS
	# shirt number on the back
	if num > 0:
		var nl := Label3D.new()
		nl.text = str(num)
		nl.font = load("res://fonts/ChakraPetch-Bold.ttf")
		nl.font_size = 64
		nl.pixel_size = 0.0036
		nl.outline_size = 0
		nl.double_sided = false
		nl.modulate = Color(0.08, 0.08, 0.08) if shirt.get_luminance() > 0.6 else Color(1, 1, 1)
		nl.position = Vector3(0, 0.36, 0.134)
		nl.cast_shadow = NS
		torso.add_child(nl)
		num_label = nl
	# head: smaller, longer than wide, with a jaw
	head = Node3D.new()
	head.position = Vector3(0, 0.72, 0)
	torso.add_child(head)
	_part(head, _cyl(0.05, 0.058, 0.14), skin_m, Vector3(0, -0.035, 0.005))
	_part(head, _sphere(0.112), skin_m, Vector3(0, 0.125, 0), Vector3(0.86, 1.08, 0.98))
	_part(head, _sphere(0.09), skin_m, Vector3(0, 0.075, -0.012), Vector3(0.86, 0.95, 0.96))
	# hair: a few styles so the players do not all look the same
	var hs := (num * 7 + idx * 3) % 6
	var hm := mat(hair, 0.95)
	if hs == 0:
		_part(head, _sphere(0.114), hm, Vector3(0, 0.162, 0.024), Vector3(0.87, 1.0, 0.99)) # shaved
	elif hs == 1:
		_part(head, _sphere(0.118), hm, Vector3(0, 0.177, 0.032), Vector3(0.9, 0.95, 1.0))
		_part(head, _sphere(0.07), hm, Vector3(0, 0.257, -0.026), Vector3(1.2, 0.55, 1.1)) # swept up at the front
	elif hs == 2:
		_part(head, _sphere(0.138), hm, Vector3(0, 0.197, 0.034), Vector3(0.95, 0.9, 1.0)) # curls
	elif hs == 3:
		_part(head, _sphere(0.118), hm, Vector3(0, 0.177, 0.032), Vector3(0.9, 0.95, 1.0))
		_part(head, _sphere(0.048), hm, Vector3(0, 0.247, 0.114)) # bun
	elif hs == 4:
		_part(head, _sphere(0.12), hm, Vector3(0, 0.162, 0.044), Vector3(0.92, 1.05, 1.02)) # longer at the back
	else:
		_part(head, _sphere(0.118), hm, Vector3(0, 0.177, 0.032), Vector3(0.9, 0.95, 1.0))
	# face: small eyes under a brow, nose, ears
	var dark := mat(Color(0.1, 0.07, 0.06))
	_part(head, _sphere(0.009), dark, Vector3(-0.036, 0.128, -0.1), Vector3(1.3, 0.8, 0.5)).cast_shadow = NS
	_part(head, _sphere(0.009), dark, Vector3(0.036, 0.128, -0.1), Vector3(1.3, 0.8, 0.5)).cast_shadow = NS
	_part(head, _sphere(0.016), mat(skin.darkened(0.04), 0.62), Vector3(0, 0.098, -0.108), Vector3(0.8, 1.5, 1.0)).cast_shadow = NS
	_part(head, _sphere(0.022), mat(skin.darkened(0.05), 0.62), Vector3(-0.094, 0.115, 0.005), Vector3(0.5, 1.2, 0.9)).cast_shadow = NS
	_part(head, _sphere(0.022), mat(skin.darkened(0.05), 0.62), Vector3(0.094, 0.115, 0.005), Vector3(0.5, 1.2, 0.9)).cast_shadow = NS
	# arms: short sleeve, upper arm, tapered forearm, hand
	arm_l = Node3D.new()
	arm_l.position = Vector3(-0.262, 0.55, 0)
	torso.add_child(arm_l)
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.262, 0.55, 0)
	torso.add_child(arm_r)
	fore_l = Node3D.new()
	fore_r = Node3D.new()
	var k := 0
	for a in [arm_l, arm_r]:
		_part(a, _cyl(0.076, 0.08, 0.17), mat(shirt), Vector3(0, -0.07, 0))
		_part(a, _cyl(0.081, 0.081, 0.025), mat(trim), Vector3(0, -0.16, 0)).cast_shadow = NS
		_part(a, _cyl(0.062, 0.05, 0.3), skin_m, Vector3(0, -0.15, 0))
		var f: Node3D = fore_l if k == 0 else fore_r
		f.position = Vector3(0, -0.29, 0)
		a.add_child(f)
		_part(f, _sphere(0.051), skin_m, Vector3.ZERO).cast_shadow = NS
		_part(f, _cyl(0.05, 0.037, 0.28), skin_m, Vector3(0, -0.14, 0))
		_part(f, _sphere(0.045), skin_m, Vector3(0, -0.315, 0), Vector3(0.6, 1.25, 0.95))
		k += 1
	# legs: strong thigh, knee, calf muscle, slim ankle, boot
	leg_l = Node3D.new()
	leg_l.position = Vector3(-0.1, 0.92, 0)
	body.add_child(leg_l)
	leg_r = Node3D.new()
	leg_r.position = Vector3(0.1, 0.92, 0)
	body.add_child(leg_r)
	shin_l = Node3D.new()
	shin_r = Node3D.new()
	k = 0
	for l in [leg_l, leg_r]:
		_part(l, _cyl(0.106, 0.12, 0.25), mat(shorts), Vector3(0, -0.095, 0))
		_part(l, _cyl(0.1, 0.068, 0.45), skin_m, Vector3(0, -0.225, 0))
		var s: Node3D = shin_l if k == 0 else shin_r
		s.position = Vector3(0, -0.45, 0)
		l.add_child(s)
		_part(s, _sphere(0.068), skin_m, Vector3.ZERO)
		_part(s, _cyl(0.064, 0.077, 0.16), mat(socks), Vector3(0, -0.1, 0.008))
		_part(s, _cyl(0.077, 0.047, 0.26), mat(socks), Vector3(0, -0.31, 0.004))
		_part(s, _cyl(0.068, 0.068, 0.03), mat(trim), Vector3(0, -0.035, 0)).cast_shadow = NS
		_part(s, _capsule(0.05, 0.27), mat(boots, 0.4), Vector3(0, -0.428, -0.07), Vector3(1.0, 1.0, 0.72)).rotation.x = PI * 0.5
		k += 1
	# ring under the player you control
	ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.62
	t.outer_radius = 0.80
	t.rings = 24
	t.ring_segments = 4
	ring.mesh = t
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.92, 0.25)
	ring.material_override = ring_mat
	ring.scale = Vector3(1, 0.08, 1)
	ring.position = Vector3(0, 0.04, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visible = false
	add_child(ring)
	# soft round shadow, used when real shadows are switched off on weak phones
	blob = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.42
	bm.bottom_radius = 0.42
	bm.height = 0.01
	bm.radial_segments = 12
	blob.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(0, 0, 0, 0.32)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob.material_override = bmat
	blob.position = Vector3(0, 0.02, 0)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.visible = false
	add_child(blob)
	marker = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.17
	cone.bottom_radius = 0.0
	cone.height = 0.3
	cone.radial_segments = 4
	marker.mesh = cone
	marker.material_override = ring_mat
	marker.position = Vector3(0, 2.2, 0)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.visible = false
	add_child(marker)
	scale = Vector3.ONE * 1.22

func hands() -> bool:
	return role == "GK" and not feet

func fwd() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

func face(dir: Vector3, rate: float, dt: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var want := atan2(-dir.x, -dir.z)
	yaw = lerp_angle(yaw, want, clampf(rate * dt, 0.0, 1.0))

func start_kick(pw := 0.7, kind := 0) -> void:
	kick_pw = pw
	kick_n += 1
	if kind == 1:
		head_t = 0.0
	elif kind == 2:
		throw_t = 0.0
	elif kind == 3:
		skill_t = 0.0
	else:
		kick_t = 0.0
	kick_kind = kind

func start_fall(dur := 0.6) -> void:
	fall_t = 0.0
	fall_dur = dur
	fall_n += 1

func start_tackle() -> void:
	tackle_t = 0.0
	tackle_n += 1

func start_dive(sd: float) -> void:
	dive_t = 0.0
	dive_side = sd
	dive_n += 1

func set_hint(col: Color) -> void:
	# small arrow over the team mate a pass would go to
	marker.visible = true
	ring_mat.albedo_color = col

func set_ring(on: bool, col: Color, arrow: bool) -> void:
	ring.visible = on
	marker.visible = on and arrow
	if on:
		ring_mat.albedo_color = col

# ---------------------------------------------------------------- animation
# Angles: leg/arm x > 0 swings forward, knee < 0 folds, body lean < 0 leans forward.

const G_T := [0.0, 0.12, 0.30, 0.45, 0.62, 0.80, 1.0]
const RUN_HIP := [0.50, 0.10, -0.60, -0.50, 0.30, 1.05, 0.50]
const RUN_KNEE := [-0.20, -0.42, -0.25, -1.50, -2.00, -1.20, -0.20]
const JOG_HIP := [0.36, 0.05, -0.40, -0.30, 0.20, 0.62, 0.36]
const JOG_KNEE := [-0.15, -0.32, -0.15, -0.90, -1.25, -0.70, -0.15]

static func _cyc(v: Array, ph: float) -> float:
	ph = fposmod(ph, 1.0)
	for i in G_T.size() - 1:
		if ph <= G_T[i + 1]:
			var u: float = (ph - G_T[i]) / (G_T[i + 1] - G_T[i])
			u = u * u * (3.0 - 2.0 * u)
			return lerpf(v[i], v[i + 1], u)
	return v[0]

static func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func animate(dt: float) -> void:
	rotation.y = yaw
	var sp := Vector2(vel.x, vel.z).length()
	phase += dt * (2.5 + sp * 1.5)
	_idle_t += dt
	# how hard the player is turning, for leaning into the turn
	if dt > 0.0:
		var dy := wrapf(yaw - _yaw_prev, -PI, PI)
		_turn = lerpf(_turn, clampf(dy / dt, -6.0, 6.0), clampf(dt * 8.0, 0.0, 1.0))
	_yaw_prev = yaw
	var a := _ease(sp / 2.2) # 0 standing .. 1 moving
	var w := clampf((sp - 3.0) / 4.3, 0.0, 1.0) # 0 jog .. 1 full run
	if sprinting:
		w = minf(w + 0.15, 1.15)
	var ph := phase / TAU
	# moving sideways or backwards while facing something else (keepers, defenders)
	var fl := 1.0
	var sd := 0.0
	if sp > 0.5:
		fl = (vel.x * -sin(yaw) + vel.z * -cos(yaw)) / sp
		sd = (vel.x * cos(yaw) + vel.z * -sin(yaw)) / sp
	# legs
	var hip_r := lerpf(_cyc(JOG_HIP, ph), _cyc(RUN_HIP, ph), w) * a
	var knee_r := lerpf(_cyc(JOG_KNEE, ph), _cyc(RUN_KNEE, ph), w) * a
	var hip_l := lerpf(_cyc(JOG_HIP, ph + 0.5), _cyc(RUN_HIP, ph + 0.5), w) * a
	var knee_l := lerpf(_cyc(JOG_KNEE, ph + 0.5), _cyc(RUN_KNEE, ph + 0.5), w) * a
	hip_r *= fl
	hip_l *= fl
	var side_sw := cos(TAU * (ph - 0.85)) * sd * 0.30 * a
	var spread_l := -0.02 - side_sw
	var spread_r := 0.02 + side_sw
	if absf(sd) > 0.3:
		knee_r = lerpf(knee_r, -0.45 - 0.3 * maxf(cos(TAU * ph), 0.0), absf(sd))
		knee_l = lerpf(knee_l, -0.45 - 0.3 * maxf(-cos(TAU * ph), 0.0), absf(sd))
	# arms swing against the legs, elbows bent
	var sw := cos(TAU * (ph - 0.85))
	var arm_a := lerpf(0.45, 1.0, w) * a * absf(fl)
	var sh_r := -sw * arm_a
	var sh_l := sw * arm_a
	var ab_l := -0.12 - 0.45 * absf(sd) * a
	var ab_r := 0.12 + 0.45 * absf(sd) * a
	var el_r := (1.35 + 0.35 * -sw) * a
	var el_l := (1.35 + 0.35 * sw) * a
	# body
	var lean := -(0.07 + 0.16 * w) * a * fl
	var roll := clampf(_turn * sp * 0.012, -0.32, 0.32)
	var turn := 0.0
	var by := (-cos(2.0 * TAU * (ph - 0.12)) * 0.5 + 0.5) * (0.035 + 0.045 * w) * a
	var bz := 0.0
	var bx := 0.0
	var tw := -sw * (0.10 + 0.14 * w) * a
	var bend := 0.0
	var head_x := 0.0
	var head_y := 0.0
	var k := clampf(dt * 16.0, 0.0, 1.0)
	# standing: loose, feet apart, breathing
	var idle := 1.0 - a
	if idle > 0.0:
		var breathe := sin(_idle_t * 1.7 + idx)
		var ready := 1.0 if role == "GK" else 0.35
		spread_l -= 0.085 * idle * (1.0 + ready * 0.8)
		spread_r += 0.085 * idle * (1.0 + ready * 0.8)
		hip_l += (0.10 + 0.22 * ready) * idle
		hip_r += (0.10 + 0.22 * ready) * idle
		knee_l -= (0.20 + 0.45 * ready) * idle
		knee_r -= (0.20 + 0.45 * ready) * idle
		lean -= (0.04 + 0.16 * ready) * idle
		by -= (0.015 + 0.06 * ready - breathe * 0.006) * idle
		ab_l -= (0.10 + 0.45 * ready) * idle
		ab_r += (0.10 + 0.45 * ready) * idle
		el_l += (0.30 + 0.5 * ready + breathe * 0.03) * idle
		el_r += (0.30 + 0.5 * ready + breathe * 0.03) * idle
		sh_l += 0.10 * ready * idle
		sh_r += 0.10 * ready * idle
		bend -= breathe * 0.012 * idle
		head_y += sin(_idle_t * 0.45 + idx * 1.7) * 0.22 * idle
		roll += sin(_idle_t * 0.6 + idx) * 0.015 * idle
	# drawing the leg back while a shot is charged
	if windup > 0.0 and kick_t < 0.0:
		var c := _ease(windup * 1.6) * 0.85
		hip_r = lerpf(hip_r, -0.75, c)
		knee_r = lerpf(knee_r, -1.35, c)
		ab_l = lerpf(ab_l, -1.0, c)
		sh_l = lerpf(sh_l, 0.5, c)
		sh_r = lerpf(sh_r, -0.6, c)
		tw = lerpf(tw, 0.3, c)
		lean = lerpf(lean, 0.06, c)
	# kick: starts at contact (the ball leaves at once), then the follow-through
	if kick_t >= 0.0:
		kick_t += dt
		var dur := 0.34 + 0.2 * kick_pw
		var t := kick_t / dur
		var hit := _ease(t / 0.2) # leg whips through
		var back := _ease((t - 0.5) / 0.5) # and comes back down
		var top := 0.6 + 1.0 * kick_pw + sin(clampf((t - 0.2) / 0.5, 0.0, 1.0) * PI) * 0.22
		var kk := (1.0 - back)
		hip_r = lerpf(hip_r, lerpf(0.25, top, hit), kk)
		knee_r = lerpf(knee_r, lerpf(-0.55, -0.05, hit), kk)
		hip_l = lerpf(hip_l, -0.12 - 0.2 * hit * kick_pw, kk)
		knee_l = lerpf(knee_l, -0.22, kk)
		if kick_pw < 0.45:
			# side-foot pass: the foot opens out
			spread_r = lerpf(spread_r, 0.22, kk)
			turn = lerpf(0.0, -0.25, kk)
		else:
			# a proper strike: hips open on the way in and whip through the ball
			turn = lerpf(0.32, -0.38, hit) * kk * kick_pw
			roll += lerpf(0.0, 0.14, hit) * kk * kick_pw
			knee_l = lerpf(knee_l, -0.42, kk)
		ab_l = lerpf(ab_l, -1.15 - 0.3 * kick_pw, kk)
		sh_l = lerpf(sh_l, 0.7, kk)
		sh_r = lerpf(sh_r, -0.9 * kick_pw - 0.2, kk)
		el_l = lerpf(el_l, 0.35, kk)
		el_r = lerpf(el_r, 0.5, kk)
		tw = lerpf(tw, lerpf(0.25, -0.45, hit) * (0.5 + kick_pw), kk)
		lean = lerpf(lean, lerpf(0.10, -0.12, hit) * (0.6 + kick_pw), kk)
		by += sin(clampf(t / 0.7, 0.0, 1.0) * PI) * 0.10 * kick_pw * kk
		k = clampf(dt * (42.0 if t < 0.25 else 16.0), 0.0, 1.0)
		if t >= 1.0:
			kick_t = -1.0
	# skill move: a full spin over the ball
	var spin_y := 0.0
	if skill_t >= 0.0:
		skill_t += dt
		var su := skill_t / 0.5
		spin_y = TAU * _ease(su)
		ab_l = -0.9
		ab_r = 0.9
		el_l = 0.5
		el_r = 0.5
		sh_l *= 0.3
		sh_r *= 0.3
		lean = -0.12
		by -= 0.06 * sin(clampf(su, 0.0, 1.0) * PI)
		tw = 0.0
		if su >= 1.0:
			skill_t = -1.0
	# throw-in: ball held over the head, then both arms whip forward
	if hold_up or throw_t >= 0.0:
		var th := 0.0
		if throw_t >= 0.0:
			throw_t += dt
			th = _ease(throw_t / 0.16)
			if throw_t > 0.5:
				throw_t = -1.0
		sh_l = lerpf(3.35, 1.9, th)
		sh_r = lerpf(3.35, 1.9, th)
		ab_l = -0.10
		ab_r = 0.10
		el_l = lerpf(0.75, 0.1, th)
		el_r = lerpf(0.75, 0.1, th)
		lean = lerpf(0.22, -0.28, th)
		bend = lerpf(0.12, -0.2, th)
		tw = 0.0
		hip_l = -0.25
		hip_r = 0.25
		knee_l = -0.15
		knee_r = -0.25
		k = clampf(dt * 26.0, 0.0, 1.0)
	# header: jump, arch back, snap the head through the ball
	if head_t >= 0.0:
		head_t += dt
		var u := head_t / 0.55
		var air := sin(clampf(u, 0.0, 1.0) * PI)
		var snap := _ease((u - 0.25) / 0.2)
		by = 0.42 * air
		lean = lerpf(0.25, -0.2, snap)
		bend = lerpf(0.18, -0.35, snap)
		head_x = lerpf(-0.35, 0.45, snap)
		ab_l = -0.9
		ab_r = 0.9
		sh_l = lerpf(-0.5, 0.3, snap)
		sh_r = lerpf(-0.5, 0.3, snap)
		el_l = 0.7
		el_r = 0.7
		hip_l = 0.15 * air
		hip_r = -0.1 * air
		knee_l = -0.9 * air
		knee_r = -0.5 * air
		tw = 0.0
		k = clampf(dt * 26.0, 0.0, 1.0)
		if u >= 1.0:
			head_t = -1.0
	# slide tackle: down on one hip, leading leg stretched along the grass
	if tackle_t >= 0.0:
		tackle_t += dt
		var down := _ease(tackle_t / 0.12)
		var up := _ease((tackle_t - 0.40) / 0.15)
		var s := down * (1.0 - up)
		lean = lerpf(lean, 1.0, s)
		by = lerpf(by, -0.36, s)
		bz = lerpf(0.0, -0.55, s)
		roll = lerpf(roll, 0.28, s)
		hip_r = lerpf(hip_r, 0.62, s)
		knee_r = lerpf(knee_r, -0.03, s)
		hip_l = lerpf(hip_l, 0.35, s)
		knee_l = lerpf(knee_l, -1.75, s)
		spread_l = lerpf(spread_l, -0.3, s)
		sh_l = lerpf(sh_l, -0.9, s)
		ab_l = lerpf(ab_l, -0.5, s)
		el_l = lerpf(el_l, 0.2, s)
		sh_r = lerpf(sh_r, 1.1, s)
		ab_r = lerpf(ab_r, 0.7, s)
		el_r = lerpf(el_r, 0.6, s)
		bend = lerpf(bend, -0.45, s)
		head_x = lerpf(head_x, -0.3, s)
		tw = lerpf(tw, 0.0, s)
		k = clampf(dt * 26.0, 0.0, 1.0)
		if tackle_t > 0.55:
			tackle_t = -1.0
	# keeper dive: push off, fly flat with both hands to the ball, land, get up
	if dive_t >= 0.0:
		dive_t += dt
		var go := _ease(dive_t / 0.2)
		var up2 := _ease((dive_t - 0.72) / 0.23)
		var s2 := go * (1.0 - up2)
		var fly := sin(clampf(dive_t / 0.5, 0.0, 1.0) * PI)
		roll = lerpf(roll, -dive_side * 1.42, s2)
		by = lerpf(by, 0.20 + fly * 0.30, s2)
		lean = lerpf(lean, 0.0, s2)
		bend = lerpf(bend, 0.0, s2)
		sh_l = lerpf(sh_l, 2.95, s2)
		sh_r = lerpf(sh_r, 2.95, s2)
		ab_l = lerpf(ab_l, -0.12 + dive_side * 0.25, s2)
		ab_r = lerpf(ab_r, 0.12 + dive_side * 0.25, s2)
		el_l = lerpf(el_l, 0.1, s2)
		el_r = lerpf(el_r, 0.1, s2)
		# the lower leg trails straight, the upper one bends
		var lo_hip := 0.05
		var hi_hip := 0.55
		hip_l = lerpf(hip_l, hi_hip if dive_side > 0.0 else lo_hip, s2)
		hip_r = lerpf(hip_r, lo_hip if dive_side > 0.0 else hi_hip, s2)
		knee_l = lerpf(knee_l, -0.95 if dive_side > 0.0 else -0.15, s2)
		knee_r = lerpf(knee_r, -0.15 if dive_side > 0.0 else -0.95, s2)
		head_y = 0.0
		tw = 0.0
		k = clampf(dt * 24.0, 0.0, 1.0)
		if dive_t > 0.95:
			dive_t = -1.0
	# knocked over: down on hands and knees (short) or flat on the grass (long), then up again
	if fall_t >= 0.0:
		fall_t += dt
		var dn := _ease(fall_t / 0.18)
		var up3 := _ease((fall_t - (fall_dur - 0.22)) / 0.22)
		var s3 := dn * (1.0 - up3)
		var flat := 1.0 if fall_dur > 0.9 else 0.0
		lean = lerpf(lean, lerpf(-0.10, -1.50, flat), s3)
		bend = lerpf(bend, lerpf(-1.15, 0.0, flat), s3)
		by = lerpf(by, lerpf(-0.46, 0.16, flat), s3)
		bz = lerpf(0.0, lerpf(-0.25, 0.0, flat), s3)
		hip_l = lerpf(hip_l, lerpf(0.10, 0.05, flat), s3)
		hip_r = lerpf(hip_r, lerpf(0.35, 0.25, flat), s3)
		knee_l = lerpf(knee_l, lerpf(-1.50, -0.1, flat), s3)
		knee_r = lerpf(knee_r, lerpf(-1.75, -0.7, flat), s3)
		sh_l = lerpf(sh_l, lerpf(1.25, 2.6, flat), s3)
		sh_r = lerpf(sh_r, lerpf(1.25, 1.2, flat), s3)
		el_l = lerpf(el_l, 0.15, s3)
		el_r = lerpf(el_r, lerpf(0.15, 1.4, flat), s3)
		ab_l = lerpf(ab_l, -0.25, s3)
		ab_r = lerpf(ab_r, 0.25, s3)
		roll = lerpf(roll, 0.25 * flat, s3)
		head_x = lerpf(head_x, lerpf(-0.5, -0.2, flat), s3)
		tw = lerpf(tw, 0.0, s3)
		k = clampf(dt * 22.0, 0.0, 1.0)
		if fall_t > fall_dur:
			fall_t = -1.0
	if mood != 0:
		mood_t += dt
	if mood == 1: # scorer: arms wide while running, then a knee slide
		ab_l = -2.3 + sin(mood_t * 9.0) * 0.12
		ab_r = 2.3 - sin(mood_t * 9.0) * 0.12
		sh_l = 0.0
		sh_r = 0.0
		el_l = 0.1
		el_r = 0.1
		lean = 0.1 * a
		tw *= 0.4
		head_x = -0.2
		if sp < 2.5 and mood_t > 1.2:
			by = -0.44
			hip_l = 0.15
			hip_r = 0.15
			knee_l = -1.7
			knee_r = -1.7
			spread_l = -0.18
			spread_r = 0.18
			lean = 0.3
			head_x = -0.35
			ab_l = -2.6
			ab_r = 2.6
	elif mood == 2: # happy: jumping with fists up
		if sp < 1.0:
			var j := absf(sin(mood_t * 5.5 + idx))
			by = j * 0.38
			ab_l = -2.8
			ab_r = 2.8
			sh_l = 0.0
			sh_r = 0.0
			el_l = 0.3 + 0.5 * (1.0 - j)
			el_r = 0.3 + 0.5 * (1.0 - j)
			knee_l = -0.7 * (1.0 - j)
			knee_r = -0.7 * (1.0 - j)
			hip_l = 0.35 * (1.0 - j)
			hip_r = 0.35 * (1.0 - j)
			lean = 0.0
	elif mood == 3: # sad: hands on head, looking down
		if sp < 1.5:
			ab_l = -2.2
			ab_r = 2.2
			sh_l = 0.0
			sh_r = 0.0
			el_l = 2.0
			el_r = 2.0
			head_x = 0.45
			head_y = 0.0
			lean = -0.1
			bend = 0.12
	leg_l.rotation.x = lerpf(leg_l.rotation.x, hip_l, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, hip_r, k)
	leg_l.rotation.z = lerpf(leg_l.rotation.z, spread_l, k)
	leg_r.rotation.z = lerpf(leg_r.rotation.z, spread_r, k)
	shin_l.rotation.x = lerpf(shin_l.rotation.x, knee_l, k)
	shin_r.rotation.x = lerpf(shin_r.rotation.x, knee_r, k)
	arm_l.rotation.x = lerpf(arm_l.rotation.x, sh_l, k)
	arm_r.rotation.x = lerpf(arm_r.rotation.x, sh_r, k)
	arm_l.rotation.z = lerpf(arm_l.rotation.z, ab_l, k)
	arm_r.rotation.z = lerpf(arm_r.rotation.z, ab_r, k)
	fore_l.rotation.x = lerpf(fore_l.rotation.x, el_l, k)
	fore_r.rotation.x = lerpf(fore_r.rotation.x, el_r, k)
	body.rotation.x = lerpf(body.rotation.x, lean, k)
	body.rotation.z = lerpf(body.rotation.z, roll, k)
	body.rotation.y = spin_y if skill_t >= 0.0 else lerpf(wrapf(body.rotation.y, -PI, PI), turn, k)
	body.position.y = lerpf(body.position.y, by, k)
	body.position.z = lerpf(body.position.z, bz, k)
	torso.rotation.y = lerpf(torso.rotation.y, tw, k)
	torso.rotation.x = lerpf(torso.rotation.x, bend, k)
	head.rotation.x = lerpf(head.rotation.x, head_x, k)
	head.rotation.y = lerpf(head.rotation.y, head_y, k)

func set_num(n: int) -> void:
	num = n
	if num_label != null:
		num_label.text = str(n)
