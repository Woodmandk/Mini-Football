extends Node3D
# The stadium: sky, light, pitch with painted lines, goals with nets, stands, crowd, boards, floodlights.

const HL := 52.5
const HW := 34.0
const GOAL_HW := 3.66
const GOAL_H := 2.44

var crowd_mat: ShaderMaterial
var sun: DirectionalLight3D
var nets := {} # true = +x goal, false = -x goal -> Node3D
var net_t := {true: 9.0, false: 9.0}
var excite := 0.0
var excite_to := 0.0

const PITCH_SHADER := """
shader_type spatial;
render_mode specular_disabled;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ln(float d, float w, float aa) { return 1.0 - smoothstep(w - aa, w + aa, abs(d)); }
float box(vec2 p, vec2 c, vec2 h) {
	vec2 d = abs(p - c) - h;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}
void fragment() {
	vec2 p = wp.xz;
	vec2 q = abs(p);
	float aa = max(fwidth(p.x), fwidth(p.y)) * 0.9;
	float w = 0.075 + aa * 0.35;
	float m = 0.0;
	m = max(m, ln(box(p, vec2(0.0), vec2(52.5, 34.0)), w, aa));
	float inside = step(q.x, 52.5 + w) * step(q.y, 34.0 + w);
	m = max(m, ln(p.x, w, aa) * inside);
	m = max(m, ln(length(p) - 9.15, w, aa));
	m = max(m, 1.0 - smoothstep(0.2 - aa, 0.2 + aa, length(p)));
	m = max(m, ln(box(q, vec2(52.5 - 8.25, 0.0), vec2(8.25, 20.16)), w, aa));
	m = max(m, ln(box(q, vec2(52.5 - 2.75, 0.0), vec2(2.75, 9.16)), w, aa));
	vec2 spot = vec2(52.5 - 11.0, 0.0);
	m = max(m, 1.0 - smoothstep(0.2 - aa, 0.2 + aa, length(q - spot)));
	m = max(m, ln(length(q - spot) - 9.15, w, aa) * step(q.x, 52.5 - 16.5));
	m = max(m, ln(length(q - vec2(52.5, 34.0)) - 1.0, w, aa) * inside);
	float stripe = mod(floor((p.x + 52.5) / 5.833), 2.0);
	float stripe2 = mod(floor((p.y + 34.0) / 5.666), 2.0);
	vec3 g1 = vec3(0.105, 0.295, 0.095);
	vec3 g2 = vec3(0.15, 0.375, 0.125);
	vec3 grass = mix(g1, g2, stripe);
	grass *= 0.96 + 0.04 * stripe2;
	float n = hash(floor(p * 24.0)) * 0.6 + hash(floor(p * 7.0)) * 0.4;
	grass *= 0.95 + 0.10 * n;
	// big soft patches so the turf is not one flat colour, and worn grass in the goal mouths and centre spot
	float big = sin(p.x * 0.11 + 1.3) * sin(p.y * 0.14 + 0.4) * 0.5 + sin(p.x * 0.031 - p.y * 0.045) * 0.5;
	grass *= 1.0 + 0.045 * big;
	float wear = (1.0 - smoothstep(1.5, 7.0, length((q - vec2(52.5 - 3.0, 0.0)) * vec2(1.0, 0.55)))) * 0.5;
	wear = max(wear, (1.0 - smoothstep(0.5, 4.0, length(p))) * 0.25);
	wear *= 0.55 + 0.45 * hash(floor(p * 3.0));
	grass = mix(grass, vec3(0.27, 0.33, 0.13), wear * 0.55);
	if (inside < 0.5) {
		float edge = max(q.x - 52.5, q.y - 34.0);
		grass = mix(grass * 0.9, vec3(0.08, 0.2, 0.08), clamp(edge / 5.0, 0.0, 1.0));
	}
	ALBEDO = mix(grass, vec3(0.96), m * 0.92);
	ROUGHNESS = 1.0;
}
"""

const NET_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec2 cells = vec2(30.0, 10.0);
void fragment() {
	vec2 g = abs(fract(UV * cells) - 0.5);
	float l = smoothstep(0.38, 0.46, max(g.x, g.y));
	ALBEDO = vec3(1.0);
	ALPHA = l * 0.75 + 0.04;
}
"""

const CROWD_SHADER := """
shader_type spatial;
render_mode specular_disabled;
uniform float excite = 0.0;
varying vec3 col;
varying float ly;
varying float pid;
void vertex() {
	float id = float(INSTANCE_ID);
	ly = VERTEX.y;
	pid = id;
	float ph = fract(id * 0.6180339) * 6.2831;
	float sp = 2.0 + fract(id * 0.371) * 2.0;
	float calm = sin(TIME * sp * 0.6 + ph) * 0.03;
	float wild = abs(sin(TIME * (5.0 + fract(id * 0.77) * 3.0) + ph)) * 0.5;
	VERTEX.y += mix(calm, wild, excite) * step(0.0, VERTEX.y + 0.2) ;
	VERTEX.y *= 1.0 + excite * 0.12 * step(0.0, VERTEX.y);
	col = COLOR.rgb;
}
void fragment() {
	// each fan is a shirt with a head and hair on top, so the stands read as people and not as blocks
	vec3 skin = mix(vec3(0.93, 0.74, 0.58), vec3(0.45, 0.29, 0.2), step(0.72, fract(pid * 0.4142)));
	vec3 hair = mix(vec3(0.12, 0.09, 0.07), vec3(0.62, 0.45, 0.22), step(0.8, fract(pid * 0.2718)));
	vec3 c = col;
	c = mix(c, skin, step(0.15, ly));
	c = mix(c, hair, step(0.33, ly));
	c = mix(c, col * 0.55, 1.0 - step(-0.3, ly));
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""

func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _box(size: Vector3, pos: Vector3, m: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func build() -> void:
	_env()
	_pitch()
	_goal(true)
	_goal(false)
	_stands()
	_boards()
	_flags()
	_floodlights()

func _env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.16, 0.36, 0.72)
	sm.sky_horizon_color = Color(0.62, 0.78, 0.93)
	sm.ground_bottom_color = Color(0.1, 0.16, 0.12)
	sm.ground_horizon_color = Color(0.62, 0.78, 0.93)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.8, 0.95)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 1.4
	we.environment = e
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.shadow_bias = 0.06
	sun.shadow_opacity = 0.62
	add_child(sun)

func _pitch() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(190, 150)
	mi.mesh = pm
	var sh := Shader.new()
	sh.code = PITCH_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _goal(right: bool) -> void:
	var s := 1.0 if right else -1.0
	var g := Node3D.new()
	g.position = Vector3(s * HL, 0, 0)
	add_child(g)
	var white := _mat(Color(0.97, 0.97, 0.97), 0.4)
	var post := CylinderMesh.new()
	post.top_radius = 0.07
	post.bottom_radius = 0.07
	post.height = GOAL_H
	post.radial_segments = 8
	for z in [-GOAL_HW, GOAL_HW]:
		var mi := MeshInstance3D.new()
		mi.mesh = post
		mi.material_override = white
		mi.position = Vector3(0, GOAL_H * 0.5, z)
		g.add_child(mi)
	var bar := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.07
	bm.bottom_radius = 0.07
	bm.height = GOAL_HW * 2.0 + 0.14
	bm.radial_segments = 8
	bar.mesh = bm
	bar.material_override = white
	bar.rotation_degrees = Vector3(90, 0, 0)
	bar.position = Vector3(0, GOAL_H, 0)
	g.add_child(bar)
	# net: back, top and two sides
	var net := Node3D.new()
	g.add_child(net)
	nets[right] = net
	var depth := 2.0
	var sh := Shader.new()
	sh.code = NET_SHADER
	var defs := [
		[Vector2(GOAL_HW * 2.0, GOAL_H), Vector3(s * depth, GOAL_H * 0.5, 0), Vector3(0, 90, 0), Vector2(30, 10)],
		[Vector2(depth, GOAL_HW * 2.0), Vector3(s * depth * 0.5, GOAL_H, 0), Vector3(90, 0, 0), Vector2(8, 30)],
		[Vector2(depth, GOAL_H), Vector3(s * depth * 0.5, GOAL_H * 0.5, -GOAL_HW), Vector3(0, 0, 0), Vector2(8, 10)],
		[Vector2(depth, GOAL_H), Vector3(s * depth * 0.5, GOAL_H * 0.5, GOAL_HW), Vector3(0, 0, 0), Vector2(8, 10)],
	]
	for d in defs:
		var q := QuadMesh.new()
		q.size = d[0]
		var mi2 := MeshInstance3D.new()
		mi2.mesh = q
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("cells", d[3])
		mi2.material_override = m
		mi2.position = d[1]
		mi2.rotation_degrees = d[2]
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		net.add_child(mi2)

func kick_net(right: bool) -> void:
	if net_t[right] > 0.6:
		net_t[right] = 0.0

func set_excite(v: float) -> void:
	excite_to = v

func _process(dt: float) -> void:
	excite = lerpf(excite, excite_to, clampf(dt * 3.0, 0.0, 1.0))
	if crowd_mat:
		crowd_mat.set_shader_parameter("excite", excite)
	for k in nets:
		net_t[k] += dt
		var t: float = net_t[k]
		var bulge := exp(-t * 3.5) * sin(t * 16.0) * 0.28 + exp(-t * 5.0) * 0.3
		nets[k].scale = Vector3(1.0 + bulge, 1.0, 1.0 + bulge * 0.15) if t < 3.0 else Vector3.ONE

func _stands() -> void:
	var concrete := _mat(Color(0.42, 0.45, 0.5))
	var dark := _mat(Color(0.2, 0.22, 0.27))
	var roof := _mat(Color(0.13, 0.15, 0.2), 0.6)
	var rows := 12
	var step_d := 1.25
	var step_h := 0.72
	var xf := []
	# [centre, along-axis is x?, length, outward dir]
	var sides := [
		[Vector3(0, 0, -(HW + 7.0)), true, 122.0, Vector3(0, 0, -1)],
		[Vector3(0, 0, HW + 7.0), true, 122.0, Vector3(0, 0, 1)],
		[Vector3(-(HL + 8.0), 0, 0), false, 78.0, Vector3(-1, 0, 0)],
		[Vector3(HL + 8.0, 0, 0), false, 78.0, Vector3(1, 0, 0)],
	]
	var cols := [Color(0.86, 0.16, 0.16), Color(0.86, 0.16, 0.16), Color(0.95, 0.95, 0.95), Color(0.2, 0.42, 0.95), Color(0.2, 0.42, 0.95),
		Color(0.95, 0.85, 0.3), Color(0.15, 0.15, 0.2), Color(0.9, 0.55, 0.2), Color(0.5, 0.75, 0.9), Color(0.75, 0.75, 0.78)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var colors := []
	for sd in sides:
		var c: Vector3 = sd[0]
		var along_x: bool = sd[1]
		var length: float = sd[2]
		var out: Vector3 = sd[3]
		var near_cam := out.z > 0.5
		var n_rows := 7 if near_cam else rows
		for r in n_rows:
			var pos := c + out * (r * step_d) + Vector3(0, (r + 1) * step_h * 0.5, 0)
			var size := Vector3(length, (r + 1) * step_h, step_d) if along_x else Vector3(step_d, (r + 1) * step_h, length)
			_box(size, pos, concrete if r % 2 == 0 else dark, false)
			var seat_y := (r + 1) * step_h
			var n := int(length / 0.62)
			for i in n:
				if rng.randf() < 0.1:
					continue
				var a := -length * 0.5 + (i + 0.5) * 0.62 + rng.randf_range(-0.08, 0.08)
				var p := c + out * (r * step_d + rng.randf_range(-0.15, 0.15)) + Vector3(0, seat_y + 0.42, 0)
				if along_x:
					p.x += a
				else:
					p.z += a
				var b := Basis().scaled(Vector3(1, rng.randf_range(0.85, 1.15), 1))
				xf.append(Transform3D(b, p))
				var col: Color = cols[rng.randi() % cols.size()]
				# home fans (red) behind one goal, away fans (blue) behind the other
				if not along_x:
					if rng.randf() < 0.7:
						col = Color(0.86, 0.16, 0.16) if out.x < 0.0 else Color(0.2, 0.42, 0.95)
				colors.append(col.darkened(rng.randf() * 0.25))
		if not near_cam:
			# back wall and roof
			var top := n_rows * step_h
			var back := c + out * (n_rows * step_d + 0.3)
			var wsize := Vector3(length, top + 5.0, 0.6) if along_x else Vector3(0.6, top + 5.0, length)
			_box(wsize, back + Vector3(0, (top + 5.0) * 0.5, 0), dark, false)
			var rsize := Vector3(length, 0.4, n_rows * step_d * 0.8) if along_x else Vector3(n_rows * step_d * 0.8, 0.4, length)
			_box(rsize, back - out * (n_rows * step_d * 0.4) + Vector3(0, top + 5.0, 0), roof, false)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var person := BoxMesh.new()
	person.size = Vector3(0.44, 0.84, 0.3)
	mm.mesh = person
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var sh := Shader.new()
	sh.code = CROWD_SHADER
	crowd_mat = ShaderMaterial.new()
	crowd_mat.shader = sh
	mmi.material_override = crowd_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _boards() -> void:
	var texts := ["BANEBOLD", "RED BISON", "HARBOUR SHARKS", "BANEBOLD 3D", "PLAY THE MATCH"]
	var bg := [Color(0.05, 0.08, 0.07), Color(0.75, 0.1, 0.1), Color(0.1, 0.25, 0.7), Color(0.95, 0.8, 0.15), Color(0.05, 0.08, 0.07)]
	var fg := [Color(0.3, 0.95, 0.5), Color(1, 1, 1), Color(1, 1, 1), Color(0.05, 0.08, 0.07), Color(1, 1, 1)]
	var n := 10
	var w := (HL * 2.0 + 6.0) / n
	for i in n:
		var x := -HL - 3.0 + (i + 0.5) * w
		var k := i % texts.size()
		var m := StandardMaterial3D.new()
		m.albedo_color = bg[k]
		m.emission_enabled = true
		m.emission = bg[k]
		m.emission_energy_multiplier = 0.35
		_box(Vector3(w - 0.15, 1.0, 0.25), Vector3(x, 0.5, -(HW + 3.6)), m)
		var l := Label3D.new()
		l.text = texts[k]
		l.font_size = 96
		l.pixel_size = 0.0075
		l.modulate = fg[k]
		l.outline_size = 0
		l.position = Vector3(x, 0.5, -(HW + 3.6) + 0.14)
		add_child(l)
	# short boards behind the goals
	for sx in [-1.0, 1.0]:
		for j in 2:
			var z := (-1.0 if j == 0 else 1.0) * 14.0
			var m2 := StandardMaterial3D.new()
			m2.albedo_color = bg[0]
			_box(Vector3(0.25, 1.0, 18.0), Vector3(sx * (HL + 4.2), 0.5, z), m2)
			var l2 := Label3D.new()
			l2.text = "BANEBOLD"
			l2.font_size = 96
			l2.pixel_size = 0.0075
			l2.modulate = fg[0]
			l2.outline_size = 0
			l2.position = Vector3(sx * (HL + 4.2) - sx * 0.14, 0.5, z)
			l2.rotation_degrees = Vector3(0, -90.0 * sx, 0)
			add_child(l2)

func _flags() -> void:
	var pole := _mat(Color(0.95, 0.95, 0.95), 0.5)
	var cloth := _mat(Color(1.0, 0.85, 0.15), 0.8)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.05, 1.6, 0.05), Vector3(sx * HL, 0.8, sz * HW), pole)
			_box(Vector3(0.42, 0.28, 0.02), Vector3(sx * (HL - 0.22), 1.44, sz * HW), cloth)

func _floodlights() -> void:
	var steel := _mat(Color(0.3, 0.32, 0.36), 0.5)
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1, 1, 0.92)
	lamp.emission_enabled = true
	lamp.emission = Color(1, 1, 0.9)
	lamp.emission_energy_multiplier = 2.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0]:
			var base := Vector3(sx * (HL + 12.0), 0, sz * (HW + 24.0))
			_box(Vector3(0.9, 34.0, 0.9), base + Vector3(0, 17.0, 0), steel, false)
			var head := _box(Vector3(7.0, 4.0, 0.6), base + Vector3(0, 35.0, 0), lamp, false)
			head.look_at_from_position(base + Vector3(0, 35.0, 0), Vector3(0, 0, 0), Vector3.UP)
