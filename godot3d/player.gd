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
var ai_cool := 0.0
var hold_t := 0.0
var react_t := 0.0

# animation state
var phase := 0.0
var kick_t := -1.0
var tackle_t := -1.0
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
	# hips / shorts
	_part(body, _box(Vector3(0.40, 0.30, 0.25)), mat(shorts), Vector3(0, 0.93, 0))
	# torso
	torso = Node3D.new()
	torso.position = Vector3(0, 1.05, 0)
	body.add_child(torso)
	_part(torso, _capsule(0.215, 0.72), mat(shirt), Vector3(0, 0.33, 0), Vector3(1.0, 1.0, 0.68))
	# shirt number on the back
	if num > 0:
		var nl := Label3D.new()
		nl.text = str(num)
		nl.font = load("res://fonts/ChakraPetch-Bold.ttf")
		nl.font_size = 64
		nl.pixel_size = 0.0042
		nl.outline_size = 0
		nl.double_sided = false
		nl.modulate = Color(0.08, 0.08, 0.08) if shirt.get_luminance() > 0.6 else Color(1, 1, 1)
		nl.position = Vector3(0, 0.40, 0.152)
		nl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		torso.add_child(nl)
	# head
	head = Node3D.new()
	head.position = Vector3(0, 0.72, 0)
	torso.add_child(head)
	_part(head, _capsule(0.06, 0.16), mat(skin), Vector3(0, -0.02, 0))
	_part(head, _sphere(0.135), mat(skin), Vector3(0, 0.13, 0))
	_part(head, _sphere(0.142), mat(hair), Vector3(0, 0.165, 0.025), Vector3(1.0, 0.8, 1.0))
	# arms
	arm_l = Node3D.new()
	arm_l.position = Vector3(-0.27, 0.58, 0)
	torso.add_child(arm_l)
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.27, 0.58, 0)
	torso.add_child(arm_r)
	fore_l = Node3D.new()
	fore_r = Node3D.new()
	var k := 0
	for a in [arm_l, arm_r]:
		_part(a, _capsule(0.075, 0.36), mat(shirt), Vector3(0, -0.13, 0))
		var f: Node3D = fore_l if k == 0 else fore_r
		f.position = Vector3(0, -0.29, 0)
		a.add_child(f)
		_part(f, _capsule(0.055, 0.34), mat(skin), Vector3(0, -0.14, 0))
		k += 1
	# legs
	leg_l = Node3D.new()
	leg_l.position = Vector3(-0.115, 0.92, 0)
	body.add_child(leg_l)
	leg_r = Node3D.new()
	leg_r.position = Vector3(0.115, 0.92, 0)
	body.add_child(leg_r)
	shin_l = Node3D.new()
	shin_r = Node3D.new()
	k = 0
	for l in [leg_l, leg_r]:
		_part(l, _capsule(0.098, 0.26), mat(shorts), Vector3(0, -0.1, 0))
		_part(l, _capsule(0.088, 0.46), mat(skin), Vector3(0, -0.23, 0))
		var s: Node3D = shin_l if k == 0 else shin_r
		s.position = Vector3(0, -0.45, 0)
		l.add_child(s)
		_part(s, _capsule(0.076, 0.46), mat(socks), Vector3(0, -0.2, 0))
		_part(s, _box(Vector3(0.13, 0.1, 0.3)), mat(boots, 0.4), Vector3(0, -0.42, -0.06))
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

func fwd() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

func face(dir: Vector3, rate: float, dt: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var want := atan2(-dir.x, -dir.z)
	yaw = lerp_angle(yaw, want, clampf(rate * dt, 0.0, 1.0))

func start_kick() -> void:
	kick_t = 0.0
	kick_n += 1

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

func animate(dt: float) -> void:
	rotation.y = yaw
	var sp := Vector2(vel.x, vel.z).length()
	phase += dt * (2.5 + sp * 1.5)
	var amp := clampf(sp / 7.0, 0.0, 1.15)
	var s := sin(phase)
	var c := cos(phase)
	var lx_l := s * 0.95 * amp
	var lx_r := -s * 0.95 * amp
	# the knee folds while the leg swings forward
	var kn_l := -(0.25 + 1.25 * maxf(c, 0.0)) * amp
	var kn_r := -(0.25 + 1.25 * maxf(-c, 0.0)) * amp
	var ax_l := -s * 0.9 * amp
	var ax_r := s * 0.9 * amp
	var el_l := 0.15 + 1.2 * amp
	var el_r := 0.15 + 1.2 * amp
	var az_l := -0.10
	var az_r := 0.10
	var lean := -0.2 * amp
	var roll := 0.0
	var by := absf(c) * 0.07 * amp
	var head_x := 0.0
	if amp < 0.1:
		by = sin(phase * 0.5) * 0.008
	if kick_t >= 0.0:
		kick_t += dt
		var t := kick_t / 0.38
		if t < 0.35:
			lx_r = lerpf(lx_r, -0.9, t / 0.35)
			kn_r = -1.3
		else:
			lx_r = lerpf(-0.9, 1.3, clampf((t - 0.35) / 0.3, 0.0, 1.0))
			kn_r = -0.1
		lx_l = -0.15
		kn_l = -0.25
		az_l = -0.9
		az_r = 0.5
		ax_l = 0.4
		el_l = 0.3
		el_r = 0.3
		lean = 0.12
		if t >= 1.0:
			kick_t = -1.0
	if tackle_t >= 0.0:
		tackle_t += dt
		var t2 := clampf(tackle_t / 0.15, 0.0, 1.0)
		lean = lerpf(lean, 1.15, t2)
		by = lerpf(by, -0.55, t2)
		lx_r = 1.5
		lx_l = 0.9
		kn_r = 0.0
		kn_l = -0.9
		az_l = -1.0
		az_r = 1.0
		el_l = 0.2
		el_r = 0.2
		if tackle_t > 0.55:
			tackle_t = -1.0
	if dive_t >= 0.0:
		dive_t += dt
		var t3 := clampf(dive_t / 0.22, 0.0, 1.0)
		roll = -dive_side * 1.35 * t3
		by = 0.25 * sin(clampf(dive_t / 0.6, 0.0, 1.0) * PI) - 0.25 * t3
		az_l = -2.7
		az_r = 2.7
		el_l = 0.0
		el_r = 0.0
		lx_l = 0.2
		lx_r = -0.2
		kn_l = -0.3
		kn_r = -0.6
		if dive_t > 0.95:
			dive_t = -1.0
	if mood != 0:
		mood_t += dt
	if mood == 1: # scorer: arms wide while running, then a knee slide
		az_l = -2.3 + sin(mood_t * 9.0) * 0.12
		az_r = 2.3 - sin(mood_t * 9.0) * 0.12
		ax_l = 0.0
		ax_r = 0.0
		el_l = 0.1
		el_r = 0.1
		lean = 0.1
		if sp < 2.5 and mood_t > 1.2:
			by = -0.44
			lx_l = 0.15
			lx_r = 0.15
			kn_l = -1.7
			kn_r = -1.7
			lean = 0.3
			head_x = -0.3
	elif mood == 2: # happy: jumping with fists up
		if sp < 1.0:
			var j := absf(sin(mood_t * 5.5 + idx))
			by = j * 0.38
			az_l = -2.8
			az_r = 2.8
			el_l = 0.2
			el_r = 0.2
			kn_l = -0.5 * (1.0 - j)
			kn_r = -0.5 * (1.0 - j)
	elif mood == 3: # sad: hands on head
		if sp < 1.5:
			az_l = -2.2
			az_r = 2.2
			ax_l = 0.0
			ax_r = 0.0
			el_l = 2.0
			el_r = 2.0
			head_x = 0.4
			lean = -0.08
	var k := clampf(dt * 18.0, 0.0, 1.0)
	leg_l.rotation.x = lerpf(leg_l.rotation.x, lx_l, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, lx_r, k)
	shin_l.rotation.x = lerpf(shin_l.rotation.x, kn_l, k)
	shin_r.rotation.x = lerpf(shin_r.rotation.x, kn_r, k)
	arm_l.rotation.x = lerpf(arm_l.rotation.x, ax_l, k)
	arm_r.rotation.x = lerpf(arm_r.rotation.x, ax_r, k)
	arm_l.rotation.z = lerpf(arm_l.rotation.z, az_l, k)
	arm_r.rotation.z = lerpf(arm_r.rotation.z, az_r, k)
	fore_l.rotation.x = lerpf(fore_l.rotation.x, el_l, k)
	fore_r.rotation.x = lerpf(fore_r.rotation.x, el_r, k)
	body.rotation.x = lerpf(body.rotation.x, lean, k)
	body.rotation.z = lerpf(body.rotation.z, roll, k)
	body.position.y = lerpf(body.position.y, by, k)
	head.rotation.x = lerpf(head.rotation.x, head_x, k)
