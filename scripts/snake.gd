class_name Snake
extends Node3D
## 3D 蛇：頭在空間中自由轉向（偏航＋俯仰，翻滾會慢慢自動回正），身體沿著頭走過的軌跡。
## 身體是每格重建的圓管網格（平行移動座標系，不會扭曲），蛇皮 shader 做鱗片與對稱花紋。

const SPACING := 0.28          # 身體取樣間距（公尺）
const RADIAL := 14             # 圓管一圈的頂點數
const BODY_R := 0.5

var head_pos := Vector3.ZERO
var head_basis := Basis.IDENTITY   # -Z 前、+Y 上
var length := 7.0                  # 身體長度（公尺）
var trail := PackedVector3Array()  # 頭走過的點（新→舊），間距約 SPACING
var samples := PackedVector3Array()   # 身體取樣點（頭→尾）
var radii := PackedFloat32Array()
var hurt := 0.0
var glow := 0.0
var shimmer := 0.0

var body: MeshInstance3D
var mesh := ArrayMesh.new()
var skin: ShaderMaterial
var head_skin: ShaderMaterial
var head: Node3D
var tongue: Node3D
var _tongue_t := 0.0
var _jaw: Node3D
var _eat_t := 0.0


func _ready() -> void:
	skin = ShaderMaterial.new()
	skin.shader = load("res://shaders/snake_skin.gdshader")
	body = MeshInstance3D.new()
	body.mesh = mesh
	body.material_override = skin
	add_child(body)
	_build_head()


## 依「我的小蛇」等級換花紋顏色（背色、花紋色、腹色）
const SKINS := [
	[Color(0.05, 0.22, 0.09), Color(0.55, 0.45, 0.12), Color(0.72, 0.68, 0.48)],
	[Color(0.18, 0.14, 0.05), Color(0.85, 0.62, 0.12), Color(0.85, 0.78, 0.5)],
	[Color(0.03, 0.14, 0.3), Color(0.25, 0.65, 0.85), Color(0.75, 0.82, 0.85)],
	[Color(0.18, 0.05, 0.28), Color(0.5, 0.75, 0.95), Color(0.8, 0.72, 0.88)],
	[Color(0.35, 0.04, 0.03), Color(0.95, 0.55, 0.12), Color(0.9, 0.75, 0.55)],
	[Color(0.75, 0.75, 0.72), Color(0.55, 0.6, 0.65), Color(0.95, 0.95, 0.92)],
	[Color(0.03, 0.03, 0.04), Color(0.9, 0.72, 0.2), Color(0.3, 0.28, 0.25)],
	[Color(0.02, 0.25, 0.22), Color(0.9, 0.3, 0.55), Color(0.7, 0.9, 0.85)],
	[Color(0.03, 0.04, 0.15), Color(0.7, 0.8, 1.0), Color(0.35, 0.38, 0.55)],
	[Color(0.45, 0.3, 0.04), Color(1.0, 0.85, 0.3), Color(0.95, 0.88, 0.6)],
]


func apply_skin(level: int) -> void:
	var c: Array = SKINS[clampi(level, 0, SKINS.size() - 1)]
	for m in [skin, head_skin]:
		m.set_shader_parameter("col_back", c[0])
		m.set_shader_parameter("col_pat", c[1])
		m.set_shader_parameter("col_belly", c[2])


func fwd() -> Vector3:
	return -head_basis.z


func up() -> Vector3:
	return head_basis.y


func right() -> Vector3:
	return head_basis.x


func reset(p: Vector3, forward: Vector3, len := 7.0) -> void:
	head_pos = p
	var f := forward.normalized()
	head_basis = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.95 else Vector3.FORWARD)
	length = len
	trail.clear()
	# 一開始身體往後直直排好
	var n := int(length / SPACING) + 4
	for i in n:
		trail.append(p - f * SPACING * i)
	_resample()
	_rebuild()


## 轉向：steer.x 正＝右轉、steer.y 正＝往上；rate 為最大角速度（弧度／秒）
## 蛇頭永遠保持水平（不翻滾），俯仰限制在 ±80°，畫面不會轉暈。
func steer(dt: float, s: Vector2, rate: float) -> void:
	var f := fwd()
	if absf(s.x) > 0.0001:
		f = f.rotated(Vector3.UP, -s.x * rate * dt)
	if absf(s.y) > 0.0001:
		var r := f.cross(Vector3.UP).normalized()
		f = f.rotated(r, s.y * rate * dt)
	_set_fwd(f)


func _set_fwd(f: Vector3) -> void:
	f = f.normalized()
	var max_y := sin(deg_to_rad(80.0))
	if absf(f.y) > max_y:
		var h := Vector3(f.x, 0, f.z)
		if h.length() < 0.01:
			h = Vector3(-head_basis.z.x, 0, -head_basis.z.z)
			if h.length() < 0.01:
				h = Vector3.FORWARD
		h = h.normalized() * cos(asin(max_y))
		f = Vector3(h.x, signf(f.y) * max_y, h.z).normalized()
	head_basis = Basis.looking_at(f, Vector3.UP)


## 直接把前進方向往某個方向偏（邊界、障礙閃避用）
func turn_toward(dir: Vector3, amount: float) -> void:
	var f := fwd()
	var d := dir.normalized()
	var axis := f.cross(d)
	if axis.length() < 1e-4:
		axis = Vector3.UP
	var ang := minf(f.angle_to(d), amount)
	_set_fwd(f.rotated(axis.normalized(), ang))


func move(dt: float, speed: float) -> void:
	head_pos += fwd() * speed * dt
	if trail.is_empty() or head_pos.distance_to(trail[0]) >= SPACING:
		# 依間距補點（速度快時一格可能走超過一個間距）
		var last := trail[0] if not trail.is_empty() else head_pos
		var d := head_pos.distance_to(last)
		var steps := int(d / SPACING)
		for k in range(1, steps + 1):
			trail.insert(0, last.lerp(head_pos, float(k) * SPACING / d))
	var keep := int(length / SPACING) + 6
	if trail.size() > keep:
		trail.resize(keep)
	_resample()


func _resample() -> void:
	samples.clear()
	radii.clear()
	samples.append(head_pos)
	var n := int(length / SPACING)
	for i in range(0, mini(n, trail.size())):
		samples.append(trail[i])
	var m := samples.size()
	for i in m:
		var u := float(i) / maxf(1.0, m - 1)
		# 頸部稍細、身體最粗、尾巴漸細
		var r := BODY_R * (0.82 + 0.18 * smoothstep(0.0, 0.08, u)) * (1.0 - 0.85 * pow(smoothstep(0.45, 1.0, u), 1.3))
		radii.append(maxf(r, 0.05))


func grow(meters: float) -> void:
	length += meters


## 從第 i 個取樣點切斷（咬到自己）
func cut_at(i: int) -> void:
	length = maxf(4.0, i * SPACING)
	var keep := int(length / SPACING) + 6
	if trail.size() > keep:
		trail.resize(keep)
	_resample()


func _process(dt: float) -> void:
	hurt = maxf(0.0, hurt - dt * 1.5)
	glow = maxf(0.0, glow - dt * 0.8)
	skin.set_shader_parameter("hurt", hurt)
	skin.set_shader_parameter("glow", glow)
	skin.set_shader_parameter("shimmer", shimmer)
	head_skin.set_shader_parameter("hurt", hurt)
	head_skin.set_shader_parameter("glow", glow)
	_rebuild()
	head.global_transform = Transform3D(head_basis, head_pos)
	# 吐信：每 1.6 秒伸出縮回
	_tongue_t += dt
	var ph := fmod(_tongue_t, 1.6)
	var ext := 0.0
	if ph < 0.35:
		ext = sin(ph / 0.35 * PI)
	tongue.scale = Vector3(1, 1, maxf(0.01, ext))
	tongue.visible = ext > 0.02
	tongue.rotation.x = sin(_tongue_t * 30.0) * 0.12 * ext
	_eat_t = maxf(0.0, _eat_t - dt)
	_jaw.rotation.x = sin(clampf(_eat_t / 0.35, 0, 1) * PI) * 0.45


func chomp() -> void:
	_eat_t = 0.35


# ---------------------------------------------------------------- 網格
func _rebuild() -> void:
	var m := samples.size()
	if m < 2:
		return
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(m * (RADIAL + 1) + 1)
	norms.resize(verts.size())
	uvs.resize(verts.size())
	# 平行移動座標系：從頭的「上」開始
	var t0 := (samples[0] - samples[1]).normalized()
	var nrm := head_basis.y
	nrm = (nrm - t0 * nrm.dot(t0)).normalized()
	var prev_t := t0
	var vi := 0
	for i in m:
		var t: Vector3
		if i == 0:
			t = t0
		elif i == m - 1:
			t = (samples[i - 1] - samples[i]).normalized()
		else:
			t = (samples[i - 1] - samples[i + 1]).normalized()
		if t.length() < 0.5:
			t = prev_t
		# 把上一個法線轉到新的切線
		var ax := prev_t.cross(t)
		if ax.length() > 1e-5:
			nrm = nrm.rotated(ax.normalized(), prev_t.angle_to(t))
		nrm = (nrm - t * nrm.dot(t)).normalized()
		var bin := t.cross(nrm)
		prev_t = t
		var c := samples[i]
		var r := radii[i]
		# 頭的地方往前縮進頭部裡面
		if i == 0:
			c -= t * 0.25
		var v := i * SPACING
		for k in RADIAL + 1:
			var a := TAU * k / RADIAL
			var dir := nrm * cos(a) + bin * sin(a)
			verts[vi] = c + dir * r
			norms[vi] = dir
			uvs[vi] = Vector2(float(k) / RADIAL, v)
			vi += 1
	# 尾端封口
	var tail_i := vi
	verts[tail_i] = samples[m - 1] - prev_t * 0.1
	norms[tail_i] = -prev_t
	uvs[tail_i] = Vector2(0.5, (m - 1) * SPACING)
	for i in m - 1:
		var a0 := i * (RADIAL + 1)
		var b0 := (i + 1) * (RADIAL + 1)
		for k in RADIAL:
			idx.append(a0 + k)
			idx.append(a0 + k + 1)
			idx.append(b0 + k)
			idx.append(a0 + k + 1)
			idx.append(b0 + k + 1)
			idx.append(b0 + k)
	var last := (m - 1) * (RADIAL + 1)
	for k in RADIAL:
		idx.append(last + k)
		idx.append(last + k + 1)
		idx.append(tail_i)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	body.custom_aabb = AABB(head_pos - Vector3.ONE * (length + 2), Vector3.ONE * (length + 2) * 2.0)


# ---------------------------------------------------------------- 頭
func _build_head() -> void:
	head = Node3D.new()
	add_child(head)
	var skull := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 28
	s.rings = 16
	skull.mesh = s
	head_skin = skin.duplicate()
	head_skin.set_shader_parameter("scale_u", 30.0)
	head_skin.set_shader_parameter("scale_v", 14.0)
	head_skin.set_shader_parameter("head", 1.0)
	skull.material_override = head_skin
	skull.scale = Vector3(1.25, 0.82, 1.55)
	skull.position = Vector3(0, 0.05, -0.25)
	skull.rotation.x = -PI * 0.5   # 球的極點朝前：鱗片一圈一圈往後排
	head.add_child(skull)
	# 下顎（吃東西時張開）
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.12, 0.25)
	head.add_child(_jaw)
	var jaw := MeshInstance3D.new()
	var js := SphereMesh.new()
	js.radius = 0.5
	js.height = 1.0
	jaw.mesh = js
	jaw.material_override = head_skin
	jaw.scale = Vector3(1.05, 0.45, 1.35)
	jaw.position = Vector3(0, -0.02, -0.5)
	_jaw.add_child(jaw)
	# 眼睛：金色虹膜＋垂直瞳孔＋高光（左右對稱）
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.95, 0.72, 0.12)
	eye_mat.roughness = 0.05
	eye_mat.metallic_specular = 1.0
	eye_mat.clearcoat_enabled = true
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.5, 0.35, 0.05)
	var pupil_mat := StandardMaterial3D.new()
	pupil_mat.albedo_color = Color(0.01, 0.01, 0.01)
	pupil_mat.roughness = 0.0
	for side in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.13
		es.height = 0.26
		e.mesh = es
		e.material_override = eye_mat
		e.position = Vector3(side * 0.42, 0.22, -0.48)
		head.add_child(e)
		var p := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 0.06
		ps.height = 0.12
		p.mesh = ps
		p.material_override = pupil_mat
		p.scale = Vector3(0.45, 1.5, 0.6)
		p.position = Vector3(side * 0.08, 0.0, -0.08)
		e.add_child(p)
		# 鼻孔
		var nn := MeshInstance3D.new()
		var ns := SphereMesh.new()
		ns.radius = 0.035
		ns.height = 0.07
		nn.mesh = ns
		nn.material_override = pupil_mat
		nn.position = Vector3(side * 0.13, 0.18, -1.0)
		head.add_child(nn)
	# 舌頭（分叉）
	tongue = Node3D.new()
	tongue.position = Vector3(0, -0.02, -0.95)
	head.add_child(tongue)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.75, 0.05, 0.12)
	tm.roughness = 0.3
	var stem := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.05, 0.025, 0.45)
	stem.mesh = bx
	stem.material_override = tm
	stem.position = Vector3(0, 0, -0.22)
	tongue.add_child(stem)
	for side in [-1.0, 1.0]:
		var fk := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.035, 0.02, 0.18)
		fk.mesh = fb
		fk.material_override = tm
		fk.position = Vector3(side * 0.04, 0, -0.5)
		fk.rotation.y = side * 0.4
		tongue.add_child(fk)
