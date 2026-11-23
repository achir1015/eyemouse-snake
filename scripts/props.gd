class_name Props
extends RefCounted
## 程序產生的寫實物件：行星、外星飛碟、海帶、魚群、錦鯉、荷葉荷花、細胞、可以吃的細菌與害蟲。

const PLANET_DIR := "res://assets/planets/"


static func _mat(col: Color, rough := 0.5, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m


static func _sphere(r: float, seg := 32) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(8, seg / 2)
	return s


static func _mi(mesh: Mesh, mat: Material, parent: Node3D = null, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	if parent:
		parent.add_child(m)
	return m


# ---------------------------------------------------------------- 太陽系
## 行星：真實貼圖（Solar System Scope CC BY 4.0）
static func planet(tex: String, r: float, emissive := false) -> Node3D:
	var n := Node3D.new()
	var m := StandardMaterial3D.new()
	var path := PLANET_DIR + tex + ".jpg"
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.roughness = 0.9
	if emissive:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = 3.0
	var mi := _mi(_sphere(r, 64), m, n)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Body"
	return n


static func earth(r: float) -> Node3D:
	var n := planet("2k_earth_daymap", r)
	var cm := StandardMaterial3D.new()
	cm.albedo_texture = load(PLANET_DIR + "2k_earth_clouds.jpg")
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cm.albedo_color = Color(1, 1, 1, 0.9)
	var clouds := _mi(_sphere(r * 1.015, 64), cm, n)
	clouds.name = "Clouds"
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 大氣層藍色光暈
	var am := ShaderMaterial.new()
	am.shader = load("res://shaders/atmosphere.gdshader")
	var atm := _mi(_sphere(r * 1.06, 48), am, n)
	atm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


static func saturn(r: float) -> Node3D:
	var n := planet("2k_saturn", r)
	var ring := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(r * 4.6, r * 4.6)
	ring.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/saturn_ring.gdshader")
	sm.set_shader_parameter("ring_tex", load(PLANET_DIR + "2k_saturn_ring_alpha.png"))
	sm.set_shader_parameter("inner", 1.24 / 2.3)
	ring.material_override = sm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	ring.rotation = Vector3(0.45, 0, 0.15)
	return n


## 外星飛碟：金屬碟身、玻璃座艙裡的外星人、底部旋轉的燈環
static func ufo() -> Node3D:
	var n := Node3D.new()
	var hull := _mat(Color(0.62, 0.64, 0.68), 0.25, 0.9)
	var disc := _mi(_sphere(2.4, 48), hull, n)
	disc.scale = Vector3(1, 0.26, 1)
	var rim := TorusMesh.new()
	rim.inner_radius = 2.15
	rim.outer_radius = 2.5
	var rim_m := _mat(Color(0.4, 0.42, 0.45), 0.3, 1.0)
	_mi(rim, rim_m, n)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.5, 0.9, 0.8, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	var dome := _mi(_sphere(1.05, 32), glass, n, Vector3(0, 0.45, 0))
	dome.scale = Vector3(1, 0.85, 1)
	# 外星人：灰綠色大頭、黑色大眼
	var skin := _mat(Color(0.45, 0.6, 0.45), 0.55)
	var head := _mi(_sphere(0.42, 24), skin, n, Vector3(0, 0.7, 0))
	head.scale = Vector3(1, 1.25, 1)
	_mi(_sphere(0.22, 16), skin, n, Vector3(0, 0.3, 0)).scale = Vector3(1, 1.2, 0.8)
	var eye := _mat(Color(0.02, 0.02, 0.03), 0.02)
	eye.metallic_specular = 1.0
	for s in [-1.0, 1.0]:
		var e := _mi(_sphere(0.13, 16), eye, head, Vector3(s * 0.17, 0.02, -0.33))
		e.scale = Vector3(1.0, 0.6, 0.5)
		e.rotation.z = s * 0.5
	# 底部燈環（綠光）
	var lights := Node3D.new()
	lights.name = "Lights"
	n.add_child(lights)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.4, 1.0, 0.6)
	for i in 10:
		var a := TAU * i / 10.0
		_mi(_sphere(0.13, 8), lm, lights, Vector3(cos(a) * 1.8, -0.4, sin(a) * 1.8))
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 1.0, 0.6)
	l.light_energy = 2.0
	l.omni_range = 10.0
	l.position = Vector3(0, -1.2, 0)
	n.add_child(l)
	return n


# ---------------------------------------------------------------- 水中
static func kelp(h: float, rng: RandomNumberGenerator, col := Color(0.25, 0.42, 0.12)) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 16
	var w := rng.randf_range(0.6, 1.3)
	var twist := rng.randf_range(-2.0, 2.0)
	for i in seg:
		var t0 := float(i) / seg
		var t1 := float(i + 1) / seg
		var pts := []
		for t in [t0, t1]:
			var a: float = t * twist
			var ww: float = w * (0.4 + sin(t * PI) * 0.8)
			var c := Vector3(sin(t * 5.0) * 0.4, t * h, cos(t * 4.0) * 0.4)
			var dir := Vector3(cos(a), 0, sin(a))
			pts.append([c - dir * ww, c + dir * ww, t])
		var quad := [pts[0][0], pts[0][1], pts[1][1], pts[1][0]]
		var uv := [Vector2(0, t0), Vector2(1, t0), Vector2(1, t1), Vector2(0, t1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[k])
			st.add_vertex(quad[k])
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/kelp.gdshader")
	sm.set_shader_parameter("col", col)
	sm.set_shader_parameter("height", h)
	sm.set_shader_parameter("phase", rng.randf() * TAU)
	m.material_override = sm
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## 魚群（MultiMesh，一群一起游；身體擺尾在 shader 裡）
static func fish_school(count: int, rng: RandomNumberGenerator, koi := false) -> MultiMeshInstance3D:
	var mesh := _fish_mesh()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/fish.gdshader")
	sm.set_shader_parameter("koi", 1.0 if koi else 0.0)
	mesh.surface_set_material(0, sm)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var p := Vector3(rng.randf_range(-6, 6), rng.randf_range(-2.5, 2.5), rng.randf_range(-6, 6))
		var s := rng.randf_range(0.7, 1.3) * (3.0 if koi else 1.0)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), p))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), 0, 0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _fish_mesh() -> ArrayMesh:
	# 紡錘形身體（-Z 朝前）＋尾鰭＋背鰭
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 10
	var rad := 8
	var L := 1.0
	var prof := func(t: float) -> float: return 0.18 * sin(clampf(t, 0, 1) * PI) * (1.0 - 0.35 * t)
	for i in rings:
		var t0 := float(i) / rings
		var t1 := float(i + 1) / rings
		for k in rad:
			var a0 := TAU * k / rad
			var a1 := TAU * (k + 1) / rad
			var v := func(t: float, a: float) -> Vector3:
				var r: float = prof.call(t)
				return Vector3(cos(a) * r * 0.7, sin(a) * r, -L * 0.5 + t * L)
			var q := [v.call(t0, a0), v.call(t0, a1), v.call(t1, a1), v.call(t1, a0)]
			var uv := [Vector2(t0, float(k) / rad), Vector2(t0, float(k + 1) / rad), Vector2(t1, float(k + 1) / rad), Vector2(t1, float(k) / rad)]
			for j in [0, 2, 1, 0, 3, 2]:
				st.set_uv(uv[j])
				st.add_vertex(q[j])
	# 尾鰭
	var tail := [Vector3(0, 0, L * 0.45), Vector3(0, 0.22, L * 0.72), Vector3(0, -0.22, L * 0.72)]
	for j in [0, 1, 2, 0, 2, 1]:
		st.set_uv(Vector2(1.0, 0.5))
		st.add_vertex(tail[j])
	# 背鰭
	var dorsal := [Vector3(0, 0.15, -0.1), Vector3(0, 0.3, 0.1), Vector3(0, 0.13, 0.22)]
	for j in [0, 1, 2, 0, 2, 1]:
		st.set_uv(Vector2(0.5, 0.25))
		st.add_vertex(dorsal[j])
	st.generate_normals()
	return st.commit()


## 水面（從水下看：會波動、反光）
static func water_surface(size: float, y: float, murky := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	pm.subdivide_width = 48
	pm.subdivide_depth = 48
	m.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water_surface.gdshader")
	sm.set_shader_parameter("murky", 1.0 if murky else 0.0)
	m.material_override = sm
	m.position.y = y
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## 荷葉（圓形、中間凹、有缺口）＋荷梗
static func lotus_leaf(r: float, stem_h: float, rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 40
	var notch := rng.randf() * TAU
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		if absf(angle_difference(a0, notch)) < 0.18:
			continue
		var p0 := Vector3(cos(a0) * r, 0.12 * r * (1.0 + 0.1 * sin(a0 * 7.0)), sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0.12 * r * (1.0 + 0.1 * sin(a1 * 7.0)), sin(a1) * r)
		var c := Vector3(0, -0.04 * r, 0)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(c)
		st.set_uv(Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5))
		st.add_vertex(p1)
		st.set_uv(Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5))
		st.add_vertex(p0)
	st.generate_normals()
	var leaf := MeshInstance3D.new()
	leaf.mesh = st.commit()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/lotus_leaf.gdshader")
	leaf.material_override = sm
	n.add_child(leaf)
	var cyl := CylinderMesh.new()
	cyl.top_radius = r * 0.04
	cyl.bottom_radius = r * 0.05
	cyl.height = stem_h
	var stem := _mi(cyl, _mat(Color(0.3, 0.45, 0.18), 0.6), n, Vector3(0, -stem_h * 0.5, 0))
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## 荷花：粉紅色花瓣一層層展開，中間黃色蓮蓬
static func lotus_flower(r: float, stem_h: float) -> Node3D:
	var n := Node3D.new()
	var pet := StandardMaterial3D.new()
	pet.albedo_color = Color(0.98, 0.72, 0.8)
	pet.roughness = 0.6
	pet.subsurf_scatter_enabled = true
	pet.subsurf_scatter_strength = 0.5
	pet.rim_enabled = true
	pet.rim = 0.3
	var tip := ShaderMaterial.new()
	tip.shader = load("res://shaders/petal.gdshader")
	for layer in 3:
		var cnt := 6 + layer * 2
		for i in cnt:
			var a := TAU * (i + layer * 0.5) / cnt
			var p := _mi(_sphere(r * (0.42 - layer * 0.06), 16), tip, n)
			p.scale = Vector3(0.45, 0.12, 1.0)
			var open := 0.9 - layer * 0.3
			p.basis = Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, -open)
			p.position = Vector3(sin(a), 0, cos(a)) * r * (0.32 - layer * 0.07) + Vector3(0, r * (0.2 + layer * 0.08), 0)
	var pod := CylinderMesh.new()
	pod.top_radius = r * 0.17
	pod.bottom_radius = r * 0.12
	pod.height = r * 0.12
	_mi(pod, _mat(Color(0.95, 0.78, 0.2), 0.7), n, Vector3(0, r * 0.3, 0))
	var cyl := CylinderMesh.new()
	cyl.top_radius = r * 0.05
	cyl.bottom_radius = r * 0.06
	cyl.height = stem_h
	_mi(cyl, _mat(Color(0.3, 0.45, 0.18), 0.6), n, Vector3(0, -stem_h * 0.5, 0))
	return n


# ---------------------------------------------------------------- 細菌世界
## 顯微鏡下的大細胞（半透明細胞膜＋細胞核）
static func cell(r: float, col: Color) -> Node3D:
	var n := Node3D.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/cell.gdshader")
	sm.set_shader_parameter("tint", col)
	var body := _mi(_sphere(r, 40), sm, n)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var nuc := StandardMaterial3D.new()
	nuc.albedo_color = col.darkened(0.3)
	nuc.emission_enabled = true
	nuc.emission = col * 0.6
	nuc.roughness = 0.4
	var nu := _mi(_sphere(r * 0.32, 24), nuc, n, Vector3(r * 0.2, r * 0.1, -r * 0.15))
	nu.scale = Vector3(1.1, 0.9, 1.0)
	return n


## 病毒（有刺突的球）
static func virus(r: float, col: Color) -> Node3D:
	var n := Node3D.new()
	var m := _mat(col, 0.5)
	m.emission_enabled = true
	m.emission = col * 0.5
	_mi(_sphere(r, 24), m, n)
	var cyl := CylinderMesh.new()
	cyl.top_radius = r * 0.06
	cyl.bottom_radius = r * 0.05
	cyl.height = r * 0.5
	var knob := _sphere(r * 0.1, 8)
	for i in 30:
		# 費氏球面分布，對稱又均勻
		var y := 1.0 - 2.0 * (i + 0.5) / 30.0
		var rr := sqrt(1.0 - y * y)
		var a := i * 2.39996
		var d := Vector3(cos(a) * rr, y, sin(a) * rr)
		var s := _mi(cyl, m, n, d * r * 1.2)
		s.basis = Basis(_perp(d), d, _perp(d).cross(d)).orthonormalized()
		_mi(knob, m, n, d * r * 1.48)
	return n


static func _perp(v: Vector3) -> Vector3:
	var p := v.cross(Vector3.UP)
	if p.length() < 0.1:
		p = v.cross(Vector3.RIGHT)
	return p.normalized()


# ---------------------------------------------------------------- 可以吃的東西
## 細菌（桿菌）：半透明螢光膠囊＋鞭毛
static func bacteria(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var cols := [Color(0.3, 1.0, 0.5), Color(1.0, 0.45, 0.85), Color(0.4, 0.8, 1.0)]
	var col: Color = cols[rng.randi() % cols.size()]
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/cell.gdshader")
	sm.set_shader_parameter("tint", col)
	sm.set_shader_parameter("glow", 1.6)
	var cap := CapsuleMesh.new()
	cap.radius = 0.38
	cap.height = 1.7
	var b := _mi(cap, sm, n)
	b.rotation.x = PI * 0.5
	var core := _mat(col.darkened(0.2), 0.4)
	core.emission_enabled = true
	core.emission = col
	core.emission_energy_multiplier = 1.2
	var c2 := CapsuleMesh.new()
	c2.radius = 0.16
	c2.height = 0.9
	_mi(c2, core, n).rotation.x = PI * 0.5
	# 鞭毛：彎曲的細線
	var fm := _mat(col.lightened(0.3), 0.6)
	fm.emission_enabled = true
	fm.emission = col * 0.6
	for k in 3:
		var prev := Vector3(0, 0, 0.85)
		for j in 8:
			var t := float(j + 1) / 8.0
			var p := Vector3(sin(t * 6.0 + k * 2.0) * 0.18 + (k - 1) * 0.12, cos(t * 6.0 + k) * 0.18, 0.85 + t * 1.1)
			var seg := CylinderMesh.new()
			seg.top_radius = 0.025
			seg.bottom_radius = 0.025
			seg.height = prev.distance_to(p)
			seg.radial_segments = 4
			var s := _mi(seg, fm, n, (prev + p) * 0.5)
			var d := (p - prev).normalized()
			s.basis = Basis(_perp(d), d, _perp(d).cross(d)).orthonormalized()
			prev = p
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 0.8
	l.omni_range = 3.0
	n.add_child(l)
	return n


## 害蟲：water=true 是孑孓（蚊子幼蟲），否則是蟑螂般的甲蟲（6 隻腳、觸角）
static func pest(water: bool) -> Node3D:
	var n := Node3D.new()
	if water:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.35, 0.3, 0.22, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.35
		m.rim_enabled = true
		m.rim = 0.6
		var head := _mi(_sphere(0.32, 16), _mat(Color(0.18, 0.15, 0.1), 0.4), n, Vector3(0, 0, -0.95))
		head.scale = Vector3(1, 0.8, 0.9)
		var thorax := _mi(_sphere(0.42, 16), m, n, Vector3(0, 0, -0.5))
		thorax.scale = Vector3(1.1, 0.9, 1)
		for i in 8:
			var r := 0.24 - i * 0.017
			_mi(_sphere(r, 12), m, n, Vector3(0, 0, -0.05 + i * 0.3)).scale = Vector3(1, 1, 1.5)
		# 呼吸管與毛
		var tube := CylinderMesh.new()
		tube.top_radius = 0.04
		tube.bottom_radius = 0.06
		tube.height = 0.6
		var t := _mi(tube, _mat(Color(0.2, 0.17, 0.12)), n, Vector3(0, 0.22, 2.25))
		t.rotation.x = -0.6
		var hair := CylinderMesh.new()
		hair.top_radius = 0.008
		hair.bottom_radius = 0.012
		hair.height = 0.45
		hair.radial_segments = 4
		for s in [-1.0, 1.0]:
			for i in 4:
				var h := _mi(hair, _mat(Color(0.25, 0.2, 0.15)), n, Vector3(s * 0.3, 0, -0.5 + i * 0.5))
				h.rotation.z = s * 1.2
		return n
	var shell := _mat(Color(0.32, 0.17, 0.07), 0.2)
	shell.clearcoat_enabled = true
	shell.clearcoat = 0.8
	var dark := _mat(Color(0.12, 0.07, 0.04), 0.35)
	var body := _mi(_sphere(0.55, 24), shell, n, Vector3(0, 0.1, 0.15))
	body.scale = Vector3(1.0, 0.42, 1.7)
	var pron := _mi(_sphere(0.42, 20), shell, n, Vector3(0, 0.12, -0.75))
	pron.scale = Vector3(1.1, 0.4, 0.8)
	_mi(_sphere(0.22, 16), dark, n, Vector3(0, 0.05, -1.08))
	var leg := CylinderMesh.new()
	leg.top_radius = 0.035
	leg.bottom_radius = 0.02
	leg.height = 0.9
	leg.radial_segments = 6
	for s in [-1.0, 1.0]:
		for i in 3:
			var l := _mi(leg, dark, n, Vector3(s * 0.62, -0.12, -0.55 + i * 0.5))
			l.rotation = Vector3(0, 0, s * 1.0)
			l.rotation.y = (i - 1) * 0.5 * s
			l.name = "Leg"
	var ant := CylinderMesh.new()
	ant.top_radius = 0.01
	ant.bottom_radius = 0.02
	ant.height = 1.6
	ant.radial_segments = 4
	for s in [-1.0, 1.0]:
		var a := _mi(ant, dark, n, Vector3(s * 0.35, 0.2, -1.75))
		a.rotation = Vector3(-1.2, s * 0.4, 0)
	return n
