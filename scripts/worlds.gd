class_name Worlds
extends RefCounted
## 其他世界的建造：太陽系、黑洞、恐龍時代、海底、荷花池、水溝、細菌世界。
## 共用 Arena 的工具（_env、_sun、_model、_ring、_motes、random_point）。


# ---------------------------------------------------------------- 太陽系
static func solar(a: Arena) -> void:
	a.R = 70.0
	a.loop_name = "space"
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load("res://assets/planets/2k_stars_milky_way.jpg")
	pm.energy_multiplier = 0.6
	a._env(pm, 0.35)
	# 太陽在遠方，真的會發光；行星在邊界外圍繞（比例縮小，方便看清楚）
	var sun_dir := Vector3(-0.8, 0.15, -0.55).normalized()
	var sun := Props.planet("2k_sun", 60.0, true)
	sun.position = sun_dir * 620.0
	a.add_child(sun)
	a.spots.append({"node": sun, "fact": "f_sun", "r": 60.0})
	var glow := OmniLight3D.new()
	a._sun(-sun_dir, Color(1.0, 0.96, 0.88), 2.4)
	a.env.glow_intensity = 1.2
	var defs := [
		["2k_mercury", 6.0, 190.0, 2.2, "f_mercury"],
		["2k_venus_atmosphere", 11.0, 230.0, 1.4, "f_venus"],
		["earth", 22.0, 150.0, 0.55, "f_earth"],
		["2k_mars", 9.0, 170.0, 3.6, "f_mars"],
		["2k_jupiter", 48.0, 420.0, 4.4, "f_jupiter"],
		["saturn", 38.0, 380.0, 5.3, "f_saturn"],
		["2k_uranus", 20.0, 330.0, 0.15, "f_uranus"],
		["2k_neptune", 19.0, 360.0, 5.9, "f_neptune"],
	]
	for d in defs:
		var n: Node3D
		if d[0] == "earth":
			n = Props.earth(d[1])
		elif d[0] == "saturn":
			n = Props.saturn(d[1])
		else:
			n = Props.planet(d[0], d[1])
		var ang: float = d[3]
		n.position = Vector3(cos(ang) * d[2], sin(ang * 1.7) * d[2] * 0.22, sin(ang) * d[2])
		n.rotation.z = 0.4 if d[0] == "2k_uranus" else 0.2
		a.add_child(n)
		a.spots.append({"node": n, "fact": d[4], "r": d[1]})
		a._spin.append({"node": n, "axis": Vector3.UP, "speed": 0.03})
		a.animals.append({"node": n, "kind": "orbit", "rad": Vector2(n.position.x, n.position.z).length(), "ang": ang, "sp": 0.004 * 200.0 / float(d[2]), "y": n.position.y})
		if d[0] == "earth":
			var moon := Props.planet("2k_moon", 6.0)
			moon.position = Vector3(36, 6, 0)
			n.add_child(moon)
	# 月岩小行星帶（障礙）
	var rocks := ["res://assets/models/moon_rock1/moon_rock1.gltf", "res://assets/models/moon_rock3/moon_rock3.gltf", "res://assets/models/moon_rock5/moon_rock5.gltf"]
	for i in (5 if a.low else 9):
		var size := a.rng.randf_range(3.0, 8.0)
		var m := a._model(rocks[i % rocks.size()], size, false)
		if m == null:
			continue
		var p := a.random_point(size + 6.0)
		m.position = p
		m.rotation = Vector3(a.rng.randf() * TAU, a.rng.randf() * TAU, 0)
		a.obstacles.append({"c": p, "r": size * 0.42, "node": m})
		a._spin.append({"node": m, "axis": Vector3(a.rng.randf_range(-1, 1), 1, 0).normalized(), "speed": a.rng.randf_range(0.03, 0.15)})
	# 外星人飛碟（會巡邏，碰到會扣愛心）
	for i in 3:
		var u := Props.ufo()
		a.add_child(u)
		var base := a.random_point(20.0)
		a.hazards.append({"node": u, "r": 2.6, "base": base, "rad": a.rng.randf_range(8.0, 16.0), "sp": a.rng.randf_range(0.12, 0.22) * (1 if i % 2 == 0 else -1), "ph": a.rng.randf() * TAU})
	a._motes(300 if a.low else 800, Color(0.75, 0.85, 1.0, 0.6), 0.1, a.R)
	for i in 4:
		a._ring(a.random_point(12.0), 4.0, Color(0.3, 0.75, 1.0), Color(1.0, 0.85, 0.4))


# ---------------------------------------------------------------- 黑洞
static func blackhole(a: Arena) -> void:
	a.R = 65.0
	a.loop_name = "space"
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky_blackhole.gdshader")
	sm.set_shader_parameter("stars", load("res://assets/planets/2k_stars_milky_way.jpg"))
	a._env(sm, 0.5)
	a.env.glow_intensity = 1.3
	a.env.glow_hdr_threshold = 1.2
	a._sun(Vector3(0.0, -0.1, 1.0), Color(1.0, 0.75, 0.5), 1.6)   # 吸積盤的光從黑洞方向照過來
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.4, 0.5, 0.8)
	fill.light_energy = 0.25
	a.add_child(fill)
	# 被拉長的碎石（義大利麵化）：沿著朝黑洞的方向拉長
	var rocks := ["res://assets/models/moon_rock3/moon_rock3.gltf", "res://assets/models/moon_rock5/moon_rock5.gltf"]
	for i in (6 if a.low else 11):
		var size := a.rng.randf_range(2.5, 7.0)
		var m := a._model(rocks[i % 2], size, false)
		if m == null:
			continue
		var p := a.random_point(size + 6.0)
		m.position = p
		m.scale = Vector3(1, 1, 1.0 + a.rng.randf() * 1.6)
		m.look_at_from_position(p, p + Vector3(0, 0.08, -1), Vector3.UP)
		a.obstacles.append({"c": p, "r": size * 0.42, "node": m})
	# 一個空間站方向標示：看著黑洞就會講知識
	var marker := Node3D.new()
	marker.position = Vector3(0.0, 0.08, -1.0).normalized() * 600.0
	a.add_child(marker)
	a.spots.append({"node": marker, "fact": "f_hole_lens", "r": 120.0})
	a._motes(300 if a.low else 900, Color(1.0, 0.8, 0.6, 0.55), 0.12, a.R)
	for i in 4:
		a._ring(a.random_point(12.0), 4.0, Color(1.0, 0.55, 0.2), Color(1.0, 0.9, 0.6))


# ---------------------------------------------------------------- 恐龍時代
static func dino(a: Arena) -> void:
	a.R = 60.0
	a.floor_y = 0.0
	a.loop_name = "garden"
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load("res://assets/sky/meadow.hdr")
	a._env(pm, 0.8)
	a.env.fog_enabled = true
	a.env.fog_light_color = Color(0.75, 0.62, 0.45)
	a.env.fog_density = 0.0035
	a.env.fog_aerial_perspective = 0.6
	a.env.fog_sky_affect = 0.35
	a._sun(Vector3(-0.3, -0.55, -0.6), Color(1.0, 0.85, 0.65), 2.0)
	_ground(a, "mud", R2(a) * 12.0, 0.05)
	# 巨大蕨類與蘇鐵（使用掃描的蕨類模型放大）
	for i in (8 if a.low else 16):
		var h := a.rng.randf_range(14.0, 26.0)
		var m := a._model("res://assets/models/fern/fern.gltf", h, true)
		if m == null:
			break
		var ang := a.rng.randf() * TAU
		var d := a.rng.randf_range(a.R * 0.45, a.R - 4.0)
		m.position = Vector3(cos(ang) * d, 0, sin(ang) * d)
		m.rotation.y = a.rng.randf() * TAU
		Arena._no_shadow(m)
		a.columns.append({"c": m.position, "r": h * 0.2, "h": h * 0.8})
	for i in 4:
		var size := a.rng.randf_range(7.0, 12.0)
		var r := a._model("res://assets/models/rocks/rocks.gltf", size, false)
		if r == null:
			break
		var ang2 := TAU * i / 4.0 + 0.4
		var p := Vector3(cos(ang2) * 26.0, 0, sin(ang2) * 26.0)
		r.position = p
		a.obstacles.append({"c": p + Vector3(0, size * 0.15, 0), "r": size * 0.45, "node": r})
	# 遠方的火山（會冒發光熔岩）
	var cone := CylinderMesh.new()
	cone.top_radius = 18.0
	cone.bottom_radius = 120.0
	cone.height = 110.0
	cone.radial_segments = 48
	var vm := ShaderMaterial.new()
	vm.shader = load("res://shaders/lava.gdshader")
	vm.set_shader_parameter("h", 110.0)
	vm.set_shader_parameter("rock", load("res://assets/tex/mud_diff.jpg"))
	var vol := Props._mi(cone, vm, a, Vector3(-260, 40, -330))
	vol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lava := OmniLight3D.new()
	lava.light_color = Color(1.0, 0.4, 0.1)
	lava.light_energy = 8.0
	lava.omni_range = 160.0
	lava.position = Vector3(-260, 100, -330)
	a.add_child(lava)
	# 蜥腳類恐龍在邊界外慢慢走過；翼龍在天上盤旋
	for i in 3:
		var sz := a.rng.randf_range(0.9, 1.3)
		var dn := sauropod(sz)
		a.add_child(dn)
		var rad := a.R + 45.0 + i * 25.0
		var ang3 := a.rng.randf() * TAU
		a.animals.append({"node": dn, "kind": "walk", "rad": rad, "ang": ang3, "sp": 0.012 * (1 if i % 2 == 0 else -1), "y": 0.0, "t": a.rng.randf() * 10.0})
		a.spots.append({"node": dn, "fact": "f_dino_sauropod", "r": 20.0})
	for i in 3:
		var pt := pterosaur()
		a.add_child(pt)
		a.animals.append({"node": pt, "kind": "fly", "rad": a.rng.randf_range(30.0, 50.0), "ang": a.rng.randf() * TAU, "sp": a.rng.randf_range(0.12, 0.2), "y": a.rng.randf_range(38.0, 52.0), "t": 0.0})
		a.spots.append({"node": pt, "fact": "f_dino_ptero", "r": 6.0})
	a._motes(200, Color(1.0, 0.9, 0.7, 0.4), 0.1, a.R)
	for i in 3:
		a._ring(a.random_point(12.0), 4.0, Color(0.9, 0.7, 0.3), Color(0.5, 1.0, 0.4))


static func R2(a: Arena) -> float:
	return a.R


## 地面（照片材質）
static func _ground(a: Arena, tex: String, size: float, uv := 0.08, caustic := 0.0) -> MeshInstance3D:
	var g := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(a.R * 12.0, a.R * 12.0)
	g.mesh = pl
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/caustic_floor.gdshader")
	sm.set_shader_parameter("albedo_tex", load("res://assets/tex/%s_diff.jpg" % tex))
	sm.set_shader_parameter("normal_tex", load("res://assets/tex/%s_nor.jpg" % tex))
	sm.set_shader_parameter("uv_scale", uv)
	sm.set_shader_parameter("caustic", caustic)
	g.material_override = sm
	g.position.y = a.floor_y
	a.add_child(g)
	return g


static func sauropod(s: float) -> Node3D:
	var n := Node3D.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/dino_skin.gdshader")
	var body := Props._mi(Props._sphere(1.0, 32), sm, n, Vector3(0, 15, 0) * s)
	body.scale = Vector3(5.5, 5.0, 10.0) * s
	# 脖子與頭（一串球沿曲線往上）
	for i in 14:
		var t := float(i) / 13.0
		var p := Vector3(0, 17.0 + t * 15.0 - t * t * 3.0, -8.0 - t * 14.0) * s
		var r := lerpf(3.2, 1.0, t) * s
		Props._mi(Props._sphere(r, 16), sm, n, p)
	var head := Props._mi(Props._sphere(1.4 * s, 16), sm, n, Vector3(0, 29.5, -23.5) * s)
	head.scale = Vector3(1.0, 0.8, 1.6)
	head.name = "Head"
	# 尾巴
	for i in 16:
		var t := float(i) / 15.0
		var p := Vector3(sin(t * 2.0) * 1.5, 15.0 - t * 9.0 + t * t * 4.0, 9.0 + t * 22.0) * s
		Props._mi(Props._sphere(lerpf(3.4, 0.4, t) * s, 12), sm, n, p)
	# 四條腿（會擺動）
	var leg := CylinderMesh.new()
	leg.top_radius = 1.9 * s
	leg.bottom_radius = 1.6 * s
	leg.height = 13.0 * s
	for k in 4:
		var hip := Node3D.new()
		hip.position = Vector3((-3.2 if k % 2 == 0 else 3.2), 13.0, (-5.0 if k < 2 else 5.5)) * s
		hip.name = "Leg%d" % k
		n.add_child(hip)
		Props._mi(leg, sm, hip, Vector3(0, -6.5 * s, 0))
	return n


static func pterosaur() -> Node3D:
	var n := Node3D.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/dino_skin.gdshader")
	sm.set_shader_parameter("back", Color(0.35, 0.25, 0.2))
	var body := Props._mi(Props._sphere(0.6, 16), sm, n)
	body.scale = Vector3(0.8, 0.7, 2.4)
	var head := Props._mi(Props._sphere(0.35, 12), sm, n, Vector3(0, 0.3, -1.6))
	head.scale = Vector3(0.6, 0.7, 2.6)
	var crest := Props._mi(Props._sphere(0.3, 8), sm, n, Vector3(0, 0.6, -1.0))
	crest.scale = Vector3(0.2, 0.6, 1.8)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.45, 0.33, 0.25)
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	wm.roughness = 0.8
	wm.backlight_enabled = true
	wm.backlight = Color(0.5, 0.25, 0.1)
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "Wing" if s < 0 else "Wing2"
		n.add_child(pivot)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pts := [Vector3(0, 0, -0.6), Vector3(s * 4.5, 0.2, -0.2), Vector3(0, 0, 1.0), Vector3(s * 4.5, 0.2, -0.2), Vector3(s * 2.0, 0, 0.9), Vector3(0, 0, 1.0)]
		for p in pts:
			st.add_vertex(p)
		st.generate_normals()
		Props._mi(st.commit(), wm, pivot)
	n.scale = Vector3.ONE * 1.6
	return n


# ---------------------------------------------------------------- 海底
static func _water_env(a: Arena, top: Color, deep: Color, dens: float) -> void:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky_water.gdshader")
	sm.set_shader_parameter("top", top)
	sm.set_shader_parameter("deep", deep)
	a._env(sm, 1.0)
	a.env.fog_enabled = true
	a.env.fog_light_color = deep.lerp(top, 0.45)
	a.env.fog_density = dens
	a.env.fog_sky_affect = 0.0


static func ocean(a: Arena) -> void:
	a.R = 60.0
	a.floor_y = 0.0
	a.underwater = true
	a.loop_name = "hum"
	_water_env(a, Color(0.3, 0.65, 0.75), Color(0.01, 0.1, 0.16), 0.022)
	a._sun(Vector3(0.15, -1.0, 0.2), Color(0.75, 0.95, 1.0), 1.6)
	_ground(a, "sand", a.R * 12.0, 0.06, 1.0)
	var surf := Props.water_surface(a.R * 6.0, a.R * 0.82)
	a.add_child(surf)
	# 海帶森林
	for i in (25 if a.low else 55):
		var h := a.rng.randf_range(14.0, 40.0)
		var k := Props.kelp(h, a.rng, Color(0.28, 0.36, 0.1).lerp(Color(0.4, 0.3, 0.1), a.rng.randf()))
		var ang := a.rng.randf() * TAU
		var d := lerpf(a.R * 0.35, a.R - 3.0, sqrt(a.rng.randf()))
		k.position = Vector3(cos(ang) * d, 0, sin(ang) * d)
		a.add_child(k)
	# 礁石與貝殼
	for i in 5:
		var size := a.rng.randf_range(8.0, 14.0)
		var m := a._model("res://assets/models/sea_rock/sea_rock.gltf", size, false)
		if m == null:
			break
		var ang2 := TAU * i / 5.0 + 0.3
		var p := Vector3(cos(ang2) * a.rng.randf_range(18.0, 40.0), 0, sin(ang2) * a.rng.randf_range(18.0, 40.0))
		m.position = p
		m.rotation.y = a.rng.randf() * TAU
		a.obstacles.append({"c": p + Vector3(0, size * 0.1, 0), "r": size * 0.45, "node": m})
	for i in 4:
		var m := a._model("res://assets/models/shell/shell.gltf", 4.0, false)
		if m == null:
			break
		m.position = Vector3(a.rng.randf_range(-30, 30), 1.0, a.rng.randf_range(-30, 30))
		m.rotation = Vector3(0.3, a.rng.randf() * TAU, 0)
	# 魚群
	for i in 4:
		var school := Props.fish_school(28 if a.low else 45, a.rng)
		a.add_child(school)
		a.animals.append({"node": school, "kind": "school", "rad": a.rng.randf_range(18.0, 38.0), "ang": a.rng.randf() * TAU, "sp": a.rng.randf_range(0.08, 0.16) * (1 if i % 2 == 0 else -1), "y": a.rng.randf_range(10.0, 35.0), "t": 0.0})
	_light_shafts(a, a.R * 0.82, Color(0.6, 0.9, 1.0))
	a._motes(500 if a.low else 1200, Color(0.8, 0.95, 1.0, 0.35), 0.08, a.R)   # 海雪（懸浮顆粒）
	for i in 3:
		a._ring(a.random_point(12.0), 4.0, Color(0.3, 0.9, 1.0), Color(0.9, 1.0, 0.8))


## 水中的光柱（上方灑下來）
static func _light_shafts(a: Arena, top_y: float, col: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(col.r, col.g, col.b, 0.05)
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.0
	cyl.bottom_radius = 5.0
	cyl.height = top_y
	cyl.cap_top = false
	cyl.cap_bottom = false
	for i in 10:
		var s := Props._mi(cyl, mat, a, Vector3(a.rng.randf_range(-35, 35), top_y * 0.5, a.rng.randf_range(-35, 35)))
		s.rotation = Vector3(0.18, 0, 0.12)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------- 荷花池
static func pond(a: Arena) -> void:
	a.R = 55.0
	a.floor_y = 0.0
	a.water_y = 26.0
	a.loop_name = "garden"
	var pmat := PanoramaSkyMaterial.new()
	pmat.panorama = load("res://assets/sky/garden.hdr")
	a._env(pmat, 0.9)
	a.env.fog_enabled = true
	a._air_fog = {"col": Color(0.7, 0.78, 0.7), "dens": 0.003, "sky": 0.0}
	a._water_fog = {"col": Color(0.16, 0.24, 0.12), "dens": 0.035, "sky": 1.0}
	a._sun(Vector3(-0.3, -0.85, -0.3), Color(1.0, 0.95, 0.85), 2.0)
	_ground(a, "mud", a.R * 12.0, 0.07, 0.6)
	a.add_child(Props.water_surface(a.R * 6.0, a.water_y, true))
	# 荷葉、荷花、荷梗
	for i in (14 if a.low else 26):
		var r := a.rng.randf_range(6.0, 11.0)
		var ang := a.rng.randf() * TAU
		var d := a.rng.randf_range(6.0, a.R - 8.0)
		var leaf := Props.lotus_leaf(r, a.water_y + 0.3, a.rng)
		leaf.position = Vector3(cos(ang) * d, a.water_y + a.rng.randf_range(0.1, 3.0), sin(ang) * d)
		leaf.rotation.y = a.rng.randf() * TAU
		a.add_child(leaf)
		a.columns.append({"c": Vector3(leaf.position.x, 0, leaf.position.z), "r": 0.8, "h": a.water_y})
		a.discs.append({"c": leaf.position, "r": r})
	for i in 7:
		var r2 := a.rng.randf_range(3.0, 4.5)
		var ang2 := a.rng.randf() * TAU
		var d2 := a.rng.randf_range(8.0, a.R - 10.0)
		var fl := Props.lotus_flower(r2, a.water_y + 6.0)
		fl.position = Vector3(cos(ang2) * d2, a.water_y + 6.0, sin(ang2) * d2)
		a.add_child(fl)
	# 水草、石頭、錦鯉
	for i in (14 if a.low else 28):
		var k := Props.kelp(a.rng.randf_range(6.0, 18.0), a.rng, Color(0.25, 0.35, 0.1))
		var ang3 := a.rng.randf() * TAU
		var d3 := a.rng.randf_range(10.0, a.R - 3.0)
		k.position = Vector3(cos(ang3) * d3, 0, sin(ang3) * d3)
		a.add_child(k)
	for i in 4:
		var size := a.rng.randf_range(6.0, 10.0)
		var m := a._model("res://assets/models/pond_rock/pond_rock.gltf", size, false)
		if m == null:
			break
		var p := Vector3(a.rng.randf_range(-35, 35), 0, a.rng.randf_range(-35, 35))
		m.position = p
		a.obstacles.append({"c": p + Vector3(0, size * 0.1, 0), "r": size * 0.45, "node": m})
	for i in 2:
		var koi := Props.fish_school(5, a.rng, true)
		a.add_child(koi)
		a.animals.append({"node": koi, "kind": "school", "rad": a.rng.randf_range(15.0, 30.0), "ang": a.rng.randf() * TAU, "sp": 0.08 * (1 if i == 0 else -1), "y": a.rng.randf_range(8.0, 18.0), "t": 0.0})
	_light_shafts(a, a.water_y, Color(0.8, 0.9, 0.6))
	a._motes(300 if a.low else 700, Color(0.85, 0.9, 0.7, 0.3), 0.08, a.R)
	for i in 3:
		a._ring(a.random_point(12.0), 4.0, Color(1.0, 0.6, 0.75), Color(0.6, 1.0, 0.5))


# ---------------------------------------------------------------- 水溝
static func gutter(a: Arena) -> void:
	a.R = 55.0
	a.floor_y = 0.0
	a.water_y = 9.0
	a.loop_name = "wind"
	var pmat := PanoramaSkyMaterial.new()
	pmat.panorama = load("res://assets/sky/garden.hdr")
	a._env(pmat, 0.55)
	a.env.fog_enabled = true
	a._air_fog = {"col": Color(0.45, 0.47, 0.42), "dens": 0.008, "sky": 0.0}
	a._water_fog = {"col": Color(0.18, 0.2, 0.12), "dens": 0.05, "sky": 1.0}
	a._sun(Vector3(0.2, -0.9, 0.35), Color(1.0, 0.95, 0.85), 1.6)
	var half := 15.0
	a.walls.append({"n": Vector3(1, 0, 0), "d": -half})
	a.walls.append({"n": Vector3(-1, 0, 0), "d": -half})
	a.walls.append({"n": Vector3(0, -1, 0), "d": -30.0})   # 上方的水溝蓋
	_ground(a, "pebbles", a.R * 12.0, 0.1, 0.25)
	# 兩側水泥牆
	var cm := StandardMaterial3D.new()
	cm.albedo_texture = load("res://assets/tex/concrete_diff.jpg")
	cm.normal_enabled = true
	cm.normal_texture = load("res://assets/tex/concrete_nor.jpg")
	cm.roughness_texture = load("res://assets/tex/concrete_rough.jpg")
	cm.uv1_triplanar = true
	cm.uv1_scale = Vector3(0.05, 0.05, 0.05)
	for s in [-1.0, 1.0]:
		var bx := BoxMesh.new()
		bx.size = Vector3(4, 40, a.R * 2.4)
		Props._mi(bx, cm, a, Vector3(s * (half + 2.0), 20, 0))
	# 水溝蓋（格柵，光從縫隙灑下）
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.22, 0.2, 0.18)
	gm.metallic = 0.8
	gm.roughness = 0.6
	for i in 40:
		var bar := BoxMesh.new()
		bar.size = Vector3(half * 2.0 + 4, 1.2, 1.4)
		Props._mi(bar, gm, a, Vector3(0, 31, -a.R * 1.2 + i * a.R * 2.4 / 40.0))
	a.add_child(Props.water_surface(a.R * 4.0, a.water_y, true))
	# 生鏽的罐頭、石頭（放大成巨大障礙）
	for i in 3:
		var size := a.rng.randf_range(9.0, 13.0)
		var m := a._model("res://assets/models/can/can.gltf", size, false)
		if m == null:
			break
		var p := Vector3(a.rng.randf_range(-6, 6), size * 0.3, -30.0 + i * 28.0)
		m.position = p
		m.rotation = Vector3(PI * 0.5, a.rng.randf() * TAU, 0)
		a.obstacles.append({"c": p, "r": size * 0.42, "node": m})
	for i in 8:
		var k := Props.kelp(a.rng.randf_range(5.0, 12.0), a.rng, Color(0.3, 0.35, 0.15))
		k.position = Vector3(a.rng.randf_range(-half + 1, half - 1), 0, a.rng.randf_range(-45, 45))
		a.add_child(k)
	_light_shafts(a, 30.0, Color(1.0, 0.95, 0.8))
	a._motes(300, Color(0.9, 0.9, 0.8, 0.3), 0.08, a.R)
	for i in 3:
		a._ring(a.random_point(12.0), 3.5, Color(0.9, 0.8, 0.4), Color(0.5, 0.9, 1.0))


# ---------------------------------------------------------------- 細菌世界
static func bacteria(a: Arena) -> void:
	a.R = 58.0
	a.loop_name = "hum"
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky_micro.gdshader")
	a._env(sm, 0.6)
	a.env.glow_intensity = 1.2
	a._sun(Vector3(0.3, -1, -0.2), Color(0.8, 1.0, 0.9), 0.6, false)
	for side in [-1.0, 1.0]:
		var l := OmniLight3D.new()
		l.light_color = Color(0.3, 1.0, 0.6) if side < 0 else Color(1.0, 0.4, 0.85)
		l.light_energy = 2.5
		l.omni_range = 90.0
		l.position = Vector3(side * 30.0, 0, 0)
		a.add_child(l)
	# 大細胞（障礙）：左右對稱擺放，綠／洋紅螢光
	for i in (5 if a.low else 8):
		var r := a.rng.randf_range(4.0, 8.0)
		var p := a.random_point(r + 8.0)
		var c := Props.cell(r, Color(0.3, 1.0, 0.55) if i % 2 == 0 else Color(1.0, 0.4, 0.85))
		c.position = p
		a.add_child(c)
		a.obstacles.append({"c": p, "r": r, "node": c})
		var mirror := Props.cell(r, Color(1.0, 0.4, 0.85) if i % 2 == 0 else Color(0.3, 1.0, 0.55))
		var mp := Vector3(-p.x, p.y, p.z)
		if not a.blocked(mp, r + 1.0):
			mirror.position = mp
			a.add_child(mirror)
			a.obstacles.append({"c": mp, "r": r, "node": mirror})
		else:
			mirror.free()
	# 病毒（可以穿過，只是裝飾）
	for i in 6:
		var v := Props.virus(a.rng.randf_range(1.2, 2.2), Color(0.9, 0.5, 0.2))
		v.position = a.random_point(6.0)
		a.add_child(v)
		a._spin.append({"node": v, "axis": Vector3(a.rng.randf(), 1, a.rng.randf()).normalized(), "speed": 0.3})
		a._drift.append({"node": v, "base": v.position, "amp": 1.5, "ph": a.rng.randf() * TAU})
	a._motes(400 if a.low else 1000, Color(0.6, 1.0, 0.8, 0.45), 0.1, a.R)
	for i in 4:
		a._ring(a.random_point(12.0), 3.6, Color(0.3, 1.0, 0.55), Color(1.0, 0.4, 0.85))


# ---------------------------------------------------------------- 動畫
static func animate(a: Arena, dt: float, t: float) -> void:
	for an in a.animals:
		var n: Node3D = an.node
		match str(an.kind):
			"orbit":
				an.ang = float(an.ang) + float(an.sp) * dt
				n.position = Vector3(cos(an.ang) * an.rad, an.y, sin(an.ang) * an.rad)
			"walk":
				an.ang = float(an.ang) + float(an.sp) * dt
				an.t = float(an.t) + dt
				var p := Vector3(cos(an.ang) * an.rad, 0, sin(an.ang) * an.rad)
				var tangent := Vector3(-sin(an.ang), 0, cos(an.ang)) * signf(an.sp)
				n.look_at_from_position(p, p + tangent, Vector3.UP)
				for k in 4:
					var leg := n.get_node_or_null("Leg%d" % k) as Node3D
					if leg:
						leg.rotation.x = sin(float(an.t) * 1.2 + (PI if k == 1 or k == 2 else 0.0)) * 0.35
				var head := n.get_node_or_null("Head") as Node3D
				if head:
					head.rotation.x = sin(float(an.t) * 0.4) * 0.15
			"fly", "school":
				an.ang = float(an.ang) + float(an.sp) * dt
				an.t = float(an.t) + dt
				var p2 := Vector3(cos(an.ang) * an.rad, float(an.y) + sin(float(an.ang) * 2.0) * 3.0, sin(an.ang) * an.rad)
				var tg := Vector3(-sin(an.ang), 0, cos(an.ang)) * signf(an.sp)
				n.look_at_from_position(p2, p2 + tg, Vector3.UP)
				if str(an.kind) == "fly":
					var w1 := n.get_node_or_null("Wing") as Node3D
					var w2 := n.get_node_or_null("Wing2") as Node3D
					var flap := sin(float(an.t) * 3.0) * 0.5
					if w1: w1.rotation.z = flap
					if w2: w2.rotation.z = -flap
