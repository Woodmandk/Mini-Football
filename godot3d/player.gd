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
var kick_n := 0
var tackle_n := 0
var dive_n := 0
var pname := ""
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
	for a in [arm_l, arm_r]:
		_part(a, _capsule(0.075, 0.34), mat(shirt), Vector3(0, -0.12, 0))
		_part(a, _capsule(0.055, 0.40), mat(skin), Vector3(0, -0.40, 0))
	# legs
	leg_l = Node3D.new()
	leg_l.position = Vector3(-0.115, 0.92, 0)
	body.add_child(leg_l)
	leg_r = Node3D.new()
	leg_r.position = Vector3(0.115, 0.92, 0)
	body.add_child(leg_r)
	for l in [leg_l, leg_r]:
		_part(l, _capsule(0.092, 0.50), mat(skin), Vector3(0, -0.24, 0))
		_part(l, _capsule(0.078, 0.48), mat(socks), Vector3(0, -0.62, 0))
		_part(l, _box(Vector3(0.13, 0.10, 0.30)), mat(boots, 0.4), Vector3(0, -0.87, -0.06))
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

func set_ring(on: bool, col: Color, arrow: bool) -> void:
	ring.visible = on
	marker.visible = on and arrow
	if on:
		ring_mat.albedo_color = col

func animate(dt: float) -> void:
	rotation.y = yaw
	var sp := Vector2(vel.x, vel.z).length()
	phase += dt * (3.0 + sp * 1.55)
	var amp := clampf(sp / 7.0, 0.0, 1.15)
	var s := sin(phase)
	var lx_l := s * 0.85 * amp
	var lx_r := -s * 0.85 * amp
	var ax_l := -s * 0.75 * amp
	var ax_r := s * 0.75 * amp
	var az_l := -0.10
	var az_r := 0.10
	var lean := -0.16 * amp
	var roll := 0.0
	var by := absf(cos(phase)) * 0.07 * amp
	var bz := 0.0
	var head_x := 0.0
	if amp < 0.1:
		by = sin(phase * 0.5) * 0.008
	if kick_t >= 0.0:
		kick_t += dt
		var t := kick_t / 0.38
		if t < 0.35:
			lx_r = lerpf(lx_r, -1.0, t / 0.35)
		else:
			lx_r = lerpf(-1.0, 1.35, clampf((t - 0.35) / 0.3, 0.0, 1.0))
		lx_l = -0.15
		az_l = -0.9
		az_r = 0.5
		ax_l = 0.4
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
		az_l = -1.0
		az_r = 1.0
		if tackle_t > 0.55:
			tackle_t = -1.0
	if dive_t >= 0.0:
		dive_t += dt
		var t3 := clampf(dive_t / 0.22, 0.0, 1.0)
		roll = -dive_side * 1.35 * t3
		by = 0.25 * sin(clampf(dive_t / 0.6, 0.0, 1.0) * PI) - 0.25 * t3
		az_l = -2.7
		az_r = 2.7
		lx_l = 0.2
		lx_r = -0.2
		if dive_t > 0.95:
			dive_t = -1.0
	if mood != 0:
		mood_t += dt
	if mood == 1: # scorer: arms wide, running then knee slide
		az_l = -2.4 + sin(mood_t * 9.0) * 0.15
		az_r = 2.4 - sin(mood_t * 9.0) * 0.15
		ax_l = 0.0
		ax_r = 0.0
		lean = 0.12
		if sp < 2.5 and mood_t > 1.2:
			by = -0.42
			lx_l = -1.5
			lx_r = -1.5
			lean = 0.35
	elif mood == 2: # happy: jumping with fists up
		var j := absf(sin(mood_t * 5.5 + idx))
		if sp < 1.0:
			by = j * 0.38
			az_l = -2.8
			az_r = 2.8
	elif mood == 3: # sad: hands on head
		if sp < 1.5:
			az_l = -2.5
			az_r = 2.5
			ax_l = 0.0
			ax_r = 0.0
			head_x = 0.45
			lean = -0.1
	var k := clampf(dt * 18.0, 0.0, 1.0)
	leg_l.rotation.x = lerpf(leg_l.rotation.x, lx_l, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, lx_r, k)
	arm_l.rotation.x = lerpf(arm_l.rotation.x, ax_l, k)
	arm_r.rotation.x = lerpf(arm_r.rotation.x, ax_r, k)
	arm_l.rotation.z = lerpf(arm_l.rotation.z, az_l, k)
	arm_r.rotation.z = lerpf(arm_r.rotation.z, az_r, k)
	body.rotation.x = lerpf(body.rotation.x, lean, k)
	body.rotation.z = lerpf(body.rotation.z, roll, k)
	body.position.y = lerpf(body.position.y, by, k)
	body.position.z = bz
	head.rotation.x = lerpf(head.rotation.x, head_x, k)
