extends Node3D
# Test rig: one player in front of a close camera, saves a strip of frames of one animation.
const PlayerS = preload("res://player.gd")
var p
var kind := "run"
var out := ""
var every := 3
var n := 0
var shots := 0
var view := "side"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--anim="):
			kind = a.substr(7)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--every="):
			every = int(a.substr(8))
		elif a.begins_with("--view="):
			view = a.substr(7)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.6, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.6, 0.25)
	g.material_override = gm
	add_child(g)
	p = PlayerS.new()
	p.num = 9
	p.build(Color(0.86, 0.14, 0.14), Color(0.97, 0.97, 0.97), Color(0.86, 0.14, 0.14), Color(0.87, 0.67, 0.5), Color(0.1, 0.08, 0.06), Color(1.0, 0.45, 0.1))
	add_child(p)
	p.yaw = -PI * 0.5 # facing +X
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 30.0
	if view == "front":
		cam.position = Vector3(5.5, 1.5, 2.2)
	elif view == "back":
		cam.position = Vector3(-5.0, 2.2, 2.6)
	elif view == "gk":
		cam.position = Vector3(9.0, 1.3, 0.0)
		cam.fov = 34.0
	else:
		cam.position = Vector3(0.6, 1.4, 6.2)
	cam.look_at(Vector3(0, 1.05, 0))

func _process(_dt: float) -> void:
	var dt := 1.0 / 60.0
	n += 1
	var start := 24
	match kind:
		"run":
			p.vel = p.fwd() * 7.6
		"sprint":
			p.vel = p.fwd() * 8.6
			p.sprinting = true
		"jog":
			p.vel = p.fwd() * 3.5
		"idle":
			p.vel = Vector3.ZERO
		"kick":
			p.vel = p.fwd() * (5.0 if n < start + 6 else 2.0)
			if n == start:
				p.start_kick(0.3)
		"pass":
			p.vel = p.fwd() * 4.0
			if n == start:
				if p.has_method("start_pass"):
					p.start_pass()
				else:
					p.start_kick(0.3)
		"tackle":
			p.vel = p.fwd() * 7.0
			if n == start:
				p.start_tackle()
		"dive":
			p.vel = Vector3.ZERO
			if n == start:
				p.start_dive(1.0)
		"skill":
			p.vel = p.fwd() * 6.0
			if n == start:
				p.start_kick(0.5, 3)
		"header":
			p.vel = Vector3.ZERO
			if n == start:
				p.start_kick(0.7, 1)
		"throw":
			p.vel = Vector3.ZERO
			p.hold_up = n < start + 12
			if n == start + 12:
				p.start_kick(0.5, 2)
		"fall":
			p.vel = p.fwd() * (6.0 if n < start else maxf(3.0 - (n - start) * 0.3, 0.0))
			if n == start:
				p.start_fall(0.6)
		"foul":
			p.vel = p.fwd() * (6.0 if n < start else maxf(3.0 - (n - start) * 0.3, 0.0))
			if n == start:
				p.start_fall(1.2)
		"strafe":
			p.vel = Vector3(0, 0, 3.4)
		"backpedal":
			p.vel = -p.fwd() * 3.2
		"cele":
			p.mood = 1
			p.vel = p.fwd() * (6.0 if n < start + 14 else 0.5)
		"happy":
			p.mood = 2
			p.vel = Vector3.ZERO
		"sad":
			p.mood = 3
			p.vel = Vector3.ZERO
		"stop":
			p.vel = p.fwd() * (7.6 if n < start else maxf(7.6 - (n - start) * 0.5, 0.0))
	p.animate(dt)
	if n >= start and (n - start) % every == 0:
		get_viewport().get_texture().get_image().save_png("%s_%02d.png" % [out, shots])
		shots += 1
		if shots >= 8:
			get_tree().quit()
