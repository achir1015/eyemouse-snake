class_name Arena
extends Node3D
## 三個 3D 世界（彎曲的球形空間）：
##   quantum 量子領域：六重對稱萬花筒星雲、彩虹泡泡、雙螺旋光點、光環
##   space   星雲宇宙：藍紫星雲、明亮恆星、漂浮的月岩（障礙）、光環
##   garden  微觀花園：像蟻人一樣縮小到草叢裡（照片掃描的草、蒲公英、蕨類、苔石、露珠）
## 邊界是半徑 R 的球面（花園是半球＋地面）。

const INFO := {
	"quantum": {"name": "量子領域", "desc": "彩色對稱的萬花筒空間", "color": Color(0.6, 0.25, 0.7), "food": {"apple": 1.0}},
	"space": {"name": "太陽系", "desc": "八大行星、外星飛碟、宇宙知識", "color": Color(0.15, 0.3, 0.7), "food": {"apple": 1.0}, "facts": "space"},
	"blackhole": {"name": "黑洞", "desc": "吸積盤與重力透鏡、黑洞起源", "color": Color(0.45, 0.25, 0.1), "food": {"apple": 1.0}, "facts": "hole"},
	"garden": {"name": "微觀花園", "desc": "縮小到螞蟻大小的草叢", "color": Color(0.2, 0.5, 0.2), "food": {"apple": 0.6, "pest": 0.4}, "facts": "pest"},
	"dino": {"name": "恐龍時代", "desc": "巨大蕨類、蜥腳類恐龍、翼龍", "color": Color(0.5, 0.4, 0.15), "food": {"apple": 0.6, "pest": 0.4}, "facts": "dino"},
	"ocean": {"name": "海底", "desc": "海帶森林、魚群、發光細菌", "color": Color(0.1, 0.4, 0.55), "food": {"apple": 0.5, "bacteria": 0.5}, "facts": "germ"},
	"pond": {"name": "荷花池", "desc": "錦鯉、荷葉、蚊子幼蟲孑孓", "color": Color(0.55, 0.3, 0.45), "food": {"apple": 0.4, "pest": 0.6}, "facts": "pest"},
	"gutter": {"name": "水溝", "desc": "蟑螂、孑孓、細菌大掃除", "color": Color(0.35, 0.38, 0.3), "food": {"pest": 0.6, "bacteria": 0.4}, "facts": "pest"},
	"bacteria": {"name": "細菌世界", "desc": "顯微鏡下的細菌、病毒與預防", "color": Color(0.15, 0.45, 0.35), "food": {"bacteria": 1.0}, "facts": "germ"},
}
const ORDER := ["quantum", "space", "blackhole", "garden", "dino", "ocean", "pond", "gutter", "bacteria"]

var id := "quantum"
var R := 60.0
var floor_y := -INF                 # 花園的地面高度
var obstacles: Array = []           # [{c: Vector3, r: float, node: Node3D}]
var columns: Array = []             # 花園的草叢：直立圓柱 [{c: Vector3（地面）, r: float, h: float}]
var discs: Array = []               # 荷葉：水平圓盤 [{c: Vector3, r: float}]
var walls: Array = []               # 平面牆：[{n: Vector3（朝內）, d: float}]，要保持 n·p > d
var water_y := INF                  # 水面高度（荷花池：上面是空氣）
var underwater := false             # 整個世界都在水裡
var hazards: Array = []             # 會動的危險（飛碟）：[{node, r, base, rad, sp, ph}]
var spots: Array = []               # 看久了會講知識的地方：[{node, fact, r}]
var animals: Array = []             # 恐龍、翼龍等動畫：[{node, kind, ...}]
var _air_fog := {}
var _water_fog := {}
var rings: Array = []               # [{node: Node3D, r: float}]
var env: Environment
var cam_attr: CameraAttributesPractical
var boundary_mat: ShaderMaterial
var loop_name := "hum"
var _spin: Array = []               # [{node, axis, speed}]
var _drift: Array = []              # [{node, base, amp, ph}]
var _t := 0.0
var rng := RandomNumberGenerator.new()
var low := false


static func name_of(w: String) -> String:
	return str(INFO.get(w, {}).get("name", w))


func setup(world_id: String) -> void:
	id = world_id
	low = App.settings.quality == "low" or App.is_mobile() or OS.has_feature("web")
	rng.seed = 20261124
	match id:
		"space": Worlds.solar(self)
		"blackhole": Worlds.blackhole(self)
		"garden": _build_garden()
		"dino": Worlds.dino(self)
		"ocean": Worlds.ocean(self)
		"pond": Worlds.pond(self)
		"gutter": Worlds.gutter(self)
		"bacteria": Worlds.bacteria(self)
		_: _build_quantum()
	_build_boundary()


# ---------------------------------------------------------------- 共用
func _env(sky_mat: Material, energy := 1.0) -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	var we := WorldEnvironment.new()
	we.environment = env
	cam_attr = CameraAttributesPractical.new()
	we.camera_attributes = cam_attr
	add_child(we)


func _sun(dir: Vector3, col: Color, energy: float, shadows := true) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.shadow_enabled = shadows and not low
	l.directional_shadow_max_distance = 90.0
	add_child(l)
	l.look_at_from_position(Vector3.ZERO, dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD)
	return l


func _build_boundary() -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = R
	s.height = R * 2.0
	s.radial_segments = 96
	s.rings = 48
	m.mesh = s
	boundary_mat = ShaderMaterial.new()
	boundary_mat.shader = load("res://shaders/boundary.gdshader")
	var tint: Color = {"quantum": Color(0.9, 0.5, 1.0), "space": Color(0.35, 0.8, 1.0), "garden": Color(0.8, 1.0, 0.7)}.get(id, Color(0.5, 0.9, 1.0))
	boundary_mat.set_shader_parameter("tint", tint)
	boundary_mat.set_shader_parameter("base_alpha", 0.012 if id == "quantum" else (0.003 if id in ["space", "blackhole"] else 0.0))
	m.material_override = boundary_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


func _ring(at: Vector3, radius: float, a: Color, b: Color) -> void:
	var n := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = radius - 0.35
	t.outer_radius = radius + 0.35
	t.rings = 64
	t.ring_segments = 16
	n.mesh = t
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ring.gdshader")
	mat.set_shader_parameter("a", a)
	mat.set_shader_parameter("b", b)
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	n.position = at
	# 光環面向球心附近的隨機方向，方便穿越
	var nrm := (Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.6), rng.randf_range(-1, 1))).normalized()
	n.basis = Basis(_perp(nrm), nrm, nrm.cross(_perp(nrm))).orthonormalized()
	var l := OmniLight3D.new()
	l.light_color = a.lerp(b, 0.5)
	l.light_energy = 0.8
	l.omni_range = radius * 2.5
	n.add_child(l)
	rings.append({"node": n, "r": radius})
	_spin.append({"node": n, "axis": Vector3.UP, "speed": 0.0})


static func _perp(v: Vector3) -> Vector3:
	var p := v.cross(Vector3.UP)
	if p.length() < 0.1:
		p = v.cross(Vector3.RIGHT)
	return p.normalized()


## 光環換到新位置（被穿越後）
func move_ring(i: int) -> void:
	var n: Node3D = rings[i].node
	n.position = random_point(10.0)
	var nrm := (Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.6), rng.randf_range(-1, 1))).normalized()
	n.basis = Basis(_perp(nrm), nrm, nrm.cross(_perp(nrm))).orthonormalized()


func random_point(margin := 8.0) -> Vector3:
	for k in 80:
		var p := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * (R - margin)
		if p.length() > R - margin:
			continue
		if floor_y > -INF:
			p.y = absf(p.y) * 0.55 + floor_y + 2.5
			if p.length() > R - margin:
				continue
		if not inside_walls(p, margin * 0.5 + 1.0):
			continue
		if blocked(p, 1.5):
			continue
		return p
	return Vector3(0, (floor_y + 6.0) if floor_y > -INF else 0.0, 0)


func inside_walls(p: Vector3, pad: float) -> bool:
	for w in walls:
		if (w.n as Vector3).dot(p) < float(w.d) + pad:
			return false
	return true


func blocked(p: Vector3, pad: float) -> bool:
	for d in discs:
		if absf(p.y - d.c.y) < pad + 1.0 and Vector2(p.x - d.c.x, p.z - d.c.z).length() < float(d.r) + pad:
			return true
	for o in obstacles:
		if p.distance_to(o.c) < float(o.r) + pad:
			return true
	return _in_column(p, pad)


func _in_column(p: Vector3, pad: float) -> bool:
	for c in columns:
		if p.y < float(c.h) + pad and Vector2(p.x - c.c.x, p.z - c.c.z).length() < float(c.r) + pad:
			return true
	return false


## 載入 Poly Haven 模型並等比縮放到指定高度（或最大邊長）
func _model(path: String, size: float, by_height := true) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var n: Node3D = (load(path) as PackedScene).instantiate()
	var bb := _aabb(n)
	var s := size / maxf(0.001, bb.size.y if by_height else maxf(bb.size.x, maxf(bb.size.y, bb.size.z)))
	var holder := Node3D.new()
	holder.add_child(n)
	n.scale = Vector3.ONE * s
	n.position = -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z) * s if by_height else -bb.get_center() * s
	add_child(holder)
	return holder


static func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)


static func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[n, Transform3D.IDENTITY]]
	while stack.size() > 0:
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		var xf: Transform3D = it[1]
		if node is Node3D and node != n:
			xf = xf * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var a: AABB = xf * (node as MeshInstance3D).mesh.get_aabb()
			out = a if first else out.merge(a)
			first = false
		for c in node.get_children():
			stack.append([c, xf])
	return out


func _motes(count: int, col: Color, size: float, radius: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = col
	mat.albedo_texture = _dot_tex()
	# 太靠近鏡頭的顆粒淡出，不會變成一大片灰影
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 1.0
	mat.distance_fade_max_distance = 4.0
	q.material = mat
	mm.mesh = q
	mm.instance_count = count
	for i in count:
		var p := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * pow(rng.randf(), 0.4) * radius
		if floor_y > -INF:
			p.y = absf(p.y) + floor_y + 0.5
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.4, 1.4)), p))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


static var _dot: Texture2D
static func _dot_tex() -> Texture2D:
	if _dot:
		return _dot
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_dot = ImageTexture.create_from_image(img)
	return _dot


# ---------------------------------------------------------------- 量子領域
func _build_quantum() -> void:
	R = 60.0
	loop_name = "hum"
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky_quantum.gdshader")
	_env(sm, 1.4)
	env.fog_enabled = not low
	env.fog_light_color = Color(0.35, 0.15, 0.45)
	env.fog_density = 0.004
	# 左右對稱的兩盞色光（洋紅 ↔ 青藍）＋上方金光
	for side in [-1.0, 1.0]:
		var l := OmniLight3D.new()
		l.light_color = Color(0.95, 0.3, 0.75) if side < 0 else Color(0.25, 0.8, 1.0)
		l.light_energy = 3.0
		l.omni_range = 90.0
		l.position = Vector3(side * 32.0, 8.0, 0)
		add_child(l)
	_sun(Vector3(0.2, -1, -0.3), Color(1.0, 0.88, 0.7), 0.6, false)
	# 中央雙螺旋光點（上下、左右對稱）
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sp := SphereMesh.new()
	sp.radius = 0.32
	sp.height = 0.64
	sp.radial_segments = 10
	sp.rings = 6
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp.material = mat
	mm.mesh = sp
	var n := 220
	mm.instance_count = n * 2
	for i in n:
		var t := float(i) / n
		var y := lerpf(-R * 0.75, R * 0.75, t)
		var a := t * TAU * 4.0
		for s in 2:
			var ang := a + PI * s
			var p := Vector3(cos(ang) * 5.0, y, sin(ang) * 5.0)
			mm.set_instance_transform(i * 2 + s, Transform3D(Basis(), p))
			mm.set_instance_color(i * 2 + s, Color(0.95, 0.35, 0.8) if s == 0 else Color(0.3, 0.85, 1.0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	add_child(mi)
	_spin.append({"node": mi, "axis": Vector3.UP, "speed": 0.08})
	# 彩虹泡泡（可以穿過）
	var bmat := ShaderMaterial.new()
	bmat.shader = load("res://shaders/bubble.gdshader")
	for i in (10 if low else 22):
		var b := MeshInstance3D.new()
		var bs := SphereMesh.new()
		var r := rng.randf_range(1.5, 5.5)
		bs.radius = r
		bs.height = r * 2.0
		b.mesh = bs
		b.material_override = bmat
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.position = random_point(10.0)
		add_child(b)
		_drift.append({"node": b, "base": b.position, "amp": rng.randf_range(0.5, 2.0), "ph": rng.randf() * TAU})
	_motes(300 if low else 900, Color(1.0, 0.85, 0.95, 0.8), 0.18, R)
	for i in 6:
		var even := i % 2 == 0
		_ring(random_point(12.0), 3.6, Color(0.95, 0.35, 0.85) if even else Color(0.3, 0.9, 1.0), Color(1.0, 0.8, 0.3))


# ---------------------------------------------------------------- 星雲宇宙
func _build_space() -> void:
	R = 70.0
	loop_name = "space"
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky_nebula.gdshader")
	var star := Vector3(0.0, 0.25, -1.0)
	sm.set_shader_parameter("star_dir", star)
	_env(sm, 0.7)
	_sun(-star, Color(0.8, 0.9, 1.0), 2.2)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.5, 0.35, 0.8)
	fill.light_energy = 0.35
	add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, star, Vector3.UP)
	var rocks := ["res://assets/models/moon_rock1/moon_rock1.gltf", "res://assets/models/moon_rock3/moon_rock3.gltf", "res://assets/models/moon_rock5/moon_rock5.gltf"]
	for i in (8 if low else 14):
		var size := rng.randf_range(3.5, 10.0)
		var m := _model(rocks[i % rocks.size()], size, false)
		if m == null:
			continue
		var p := random_point(size + 6.0)
		m.position = p
		m.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		obstacles.append({"c": p, "r": size * 0.42, "node": m})
		_spin.append({"node": m, "axis": Vector3(rng.randf_range(-1, 1), 1, rng.randf_range(-1, 1)).normalized(), "speed": rng.randf_range(0.03, 0.15)})
	_motes(400 if low else 1200, Color(0.75, 0.85, 1.0, 0.7), 0.12, R)
	for i in 4:
		_ring(random_point(12.0), 4.0, Color(0.3, 0.75, 1.0), Color(1.0, 0.85, 0.4))


# ---------------------------------------------------------------- 微觀花園
func _build_garden() -> void:
	R = 55.0
	floor_y = 0.0
	loop_name = "garden"
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load("res://assets/sky/garden.hdr")
	pm.energy_multiplier = 1.0
	_env(pm, 0.8)
	env.fog_enabled = not low
	env.fog_light_color = Color(0.62, 0.72, 0.55)
	env.fog_density = 0.006
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.0
	# 微距鏡頭感：遠處景深模糊
	if not low:
		cam_attr.dof_blur_far_enabled = true
		cam_attr.dof_blur_far_distance = 38.0
		cam_attr.dof_blur_far_transition = 25.0
		cam_attr.dof_blur_amount = 0.06
	_sun(Vector3(-0.45, -0.8, -0.35), Color(1.0, 0.95, 0.85), 2.0)
	# 地面：腐葉土（照片材質），放大到螞蟻尺度
	var g := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(R * 4.0, R * 4.0)
	pl.subdivide_width = 1
	pl.subdivide_depth = 1
	g.mesh = pl
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/tex/leaves_diff.jpg")
	gm.normal_enabled = true
	gm.normal_texture = load("res://assets/tex/leaves_nor.jpg")
	gm.roughness_texture = load("res://assets/tex/leaves_rough.jpg")
	gm.uv1_scale = Vector3(14, 14, 1)
	g.material_override = gm
	add_child(g)
	# 苔石（障礙）
	var rock_paths := ["res://assets/models/rocks/rocks.gltf"]
	for i in (4 if low else 7):
		var size := rng.randf_range(8.0, 16.0)
		var m := _model(rock_paths[0], size, false)
		if m == null:
			break
		var a := TAU * i / 7.0 + rng.randf_range(-0.3, 0.3)
		var d := rng.randf_range(16.0, R - 10.0)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		m.position = p
		m.rotation.y = rng.randf() * TAU
		obstacles.append({"c": p + Vector3(0, size * 0.15, 0), "r": size * 0.45, "node": m})
	# 草叢、蕨類、蒲公英、花（照片掃描模型，放大成巨大的森林）
	var plants := [
		["res://assets/models/grass/grass.gltf", 22.0, 30.0, 14 if low else 24],
		["res://assets/models/grass2/grass2.gltf", 18.0, 28.0, 6 if low else 12],
		["res://assets/models/fern/fern.gltf", 16.0, 24.0, 4 if low else 8],
		["res://assets/models/dandelion/dandelion.gltf", 34.0, 46.0, 3],
		["res://assets/models/flower/flower.gltf", 16.0, 24.0, 4 if low else 7],
		["res://assets/models/moss/moss.gltf", 2.0, 4.0, 6 if low else 12],
	]
	var cache := {}
	for pl_def in plants:
		var path: String = pl_def[0]
		if not ResourceLoader.exists(path):
			continue
		for k in int(pl_def[3]):
			var h := rng.randf_range(pl_def[1], pl_def[2])
			var m := _model(path, h, true)
			if m == null:
				break
			var p := Vector3.ZERO
			for tries in 20:
				var a := rng.randf() * TAU
				# 大部分長在外圍，中間留出空地
				var d := sqrt(rng.randf()) * (R - 3.0)
				if path.contains("moss"):
					d = rng.randf_range(4.0, R - 6.0)
				if not path.contains("moss"):
					d = lerpf(R * 0.5, R - 4.0, sqrt(rng.randf()))
				p = Vector3(cos(a) * d, 0, sin(a) * d)
				if not blocked(p, 3.0) and not _in_column(p, 3.0):
					break
			m.position = p
			m.rotation.y = rng.randf() * TAU
			m.rotation.x = rng.randf_range(-0.08, 0.08)
			if not path.contains("dandelion"):
				_no_shadow(m)
			if not path.contains("moss"):
				columns.append({"c": p, "r": h * (0.08 if path.contains("dandelion") else 0.22), "h": h * 0.85})
	# 露珠（水珠會折射背景；碰到會彈開）
	if not low:
		var dmat := ShaderMaterial.new()
		dmat.shader = load("res://shaders/dewdrop.gdshader")
		for i in 9:
			var r := rng.randf_range(1.2, 2.6)
			var b := MeshInstance3D.new()
			var bs := SphereMesh.new()
			bs.radius = r
			bs.height = r * 1.7
			b.mesh = bs
			b.material_override = dmat
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var p := random_point(6.0)
			p.y = r * 0.8
			b.position = p
			add_child(b)
			obstacles.append({"c": p, "r": r, "node": b})
	_motes(200 if low else 500, Color(1.0, 0.95, 0.7, 0.45), 0.1, R)   # 陽光下的花粉
	for i in 3:
		_ring(random_point(12.0), 4.0, Color(0.6, 1.0, 0.5), Color(1.0, 0.85, 0.35))


# ---------------------------------------------------------------- 每格
func tick(dt: float, head: Vector3, cam_pos := Vector3.ZERO) -> void:
	_t += dt
	for h in hazards:
		var n: Node3D = h.node
		var a: float = _t * float(h.sp) + float(h.ph)
		n.position = (h.base as Vector3) + Vector3(cos(a) * float(h.rad), sin(a * 0.7) * float(h.rad) * 0.3, sin(a) * float(h.rad))
		n.rotate_y(dt * 2.0)
	Worlds.animate(self, dt, _t)
	if water_y < INF and not _water_fog.is_empty():
		var under := cam_pos.y < water_y
		var f: Dictionary = _water_fog if under else _air_fog
		env.fog_light_color = f.col
		env.fog_density = f.dens
		env.fog_sky_affect = f.sky
	if boundary_mat:
		boundary_mat.set_shader_parameter("head", head)
	for s in _spin:
		if float(s.speed) != 0.0:
			(s.node as Node3D).rotate(s.axis, float(s.speed) * dt)
	for d in _drift:
		(d.node as Node3D).position = d.base + Vector3(sin(_t * 0.3 + d.ph), sin(_t * 0.23 + d.ph * 1.3), cos(_t * 0.27 + d.ph)) * float(d.amp)
	if env and env.sky and id == "quantum":
		env.sky_rotation = Vector3(0, _t * 0.01, 0)
