class_name Game
extends Node3D
## 一局遊戲：世界、蛇、追蹤鏡頭、蘋果、寶石方塊、光環、規則。
## 操作：看著畫面的哪裡，蛇就往那裡轉（眼動儀／攝影機眼控／滑鼠／手指）；鍵盤方向鍵或 WASD 也可以。

signal finished(result: Dictionary)

const APPLES := 7
const SPEEDS := [5.0, 7.0, 9.5]
const EAT_DIST := 1.5
const LIVES_MAX := 3

var world_id := "quantum"
var arena: Arena
var snake: Snake
var cam: Camera3D
var hud: Hud
var apples: Array = []          # [{node: Node3D, pos: Vector3, ph: float}]
var gem: Node3D = null
var gem_life := 0.0
var gem_timer := 25.0
var lives := LIVES_MAX
var score := 0
var eaten := 0
var combo := 0
var combo_t := 0.0
var focus := 0.0                # 專注力 0..1
var speed := 7.0
var steer := Vector2.ZERO
var invuln := 0.0
var done := false
var paused := false
var auto_paused := false
var ap := false                 # 小柯示範（自動找蘋果）
var calm := 0.0                 # 吃到寶石後的「深呼吸」慢動作秒數
var elapsed := 0.0
var rings_passed := 0
var bites := 0
var _cam_pos := Vector3.ZERO
var _cam_up := Vector3.UP
var _gaze_prev := Vector2.ZERO
var _gaze_still := 0.0
var _touch_pt = null
var _apple_scene: PackedScene
var _wall_say := 0.0
var _focus_said := false
var _lost_t := 0.0
var _ring_side: Array = []
var _rng := RandomNumberGenerator.new()
var quiet := false              # 主選單背景示範：沒有聲音、沒有 HUD
var relax := true               # 放鬆模式：不會失敗、不扣愛心（心安）
var cam_mode := 0               # 鏡頭：0 追蹤 1 蛇眼 2 側面 3 高空俯瞰 4 環繞
const CAM_NAMES := ["追蹤鏡頭", "蛇眼視角", "側面鏡頭", "高空俯瞰", "環繞鏡頭"]
var food_eaten := {"apple": 0, "bacteria": 0, "pest": 0}
var fact_t := 0.0               # 距離上一張知識卡的秒數
var _spot_t := {}               # 看著行星／恐龍多久了
var _spot_done := {}
var _fact_queue: Array = []
var play_since_rest := 0.0
var resting := 0.0              # 休息倒數秒數（養：護眼休息）
var _hz_warn := 0.0
var _orbit := 0.0
var _gaze_dir := Vector3.ZERO   # 非追蹤鏡頭：視線指到的 3D 方向


func setup(w: String) -> void:
	world_id = w
	_rng.randomize()
	arena = Arena.new()
	add_child(arena)
	arena.setup(w)
	arena.rng.randomize()   # 場景固定，蘋果與出發點每局隨機
	snake = Snake.new()
	add_child(snake)
	# 每局隨機出發位置：在球內隨機一點，朝著大致往中心（稍微偏一點）的方向
	var start := arena.random_point(arena.R * 0.35)
	if arena.floor_y > -INF:
		start.y = clampf(start.y, arena.floor_y + 5.0, arena.floor_y + 14.0)
	var to_c := Vector3(0, start.y, 0) - start if arena.floor_y > -INF else -start
	if to_c.length() < 1.0:
		to_c = Vector3(0, 0, -1)
	var dir0 := (to_c.normalized() + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))).normalized()
	# 太陽系一開始面向地球、黑洞世界面向黑洞：第一眼就看到主角
	if not arena.spots.is_empty() and arena.id in ["space", "blackhole"]:
		var main_spot: Node3D = arena.spots[3 if arena.id == "space" and arena.spots.size() > 3 else 0].node
		var to_spot := main_spot.global_position - start
		dir0 = Vector3(to_spot.x, clampf(to_spot.y, -0.3 * to_spot.length(), 0.3 * to_spot.length()), to_spot.z).normalized()
	snake.reset(start, dir0, 7.0 + minf(6.0, App.pet_level() * 0.5))
	snake.apply_skin(App.pet_level())
	relax = str(App.settings.mode) == "relax"
	cam_mode = clampi(int(App.settings.cam), 0, CAM_NAMES.size() - 1)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.1
	cam.far = 2400.0
	add_child(cam)
	cam.current = true
	_cam_pos = start - dir0 * 7.5 + Vector3(0, 2.6, 0)
	cam.global_position = _cam_pos
	cam.look_at(start + dir0 * 6.0, Vector3.UP)
	speed = SPEEDS[clampi(int(App.settings.speed), 0, 2)]
	_apply_quality()
	if ResourceLoader.exists("res://assets/models/apple/apple.gltf"):
		_apple_scene = load("res://assets/models/apple/apple.gltf")
	for i in APPLES:
		_spawn_apple()
	for r in arena.rings:
		_ring_side.append(0.0)
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	if quiet:
		hud.visible = false
		ap = true
		return
	Snd.set_loop(arena.loop_name, 0.35)
	_sfx("start")
	if bool(App.settings.music_on):
		Snd.play_track(int(App.settings.music_track))


## 內顯（例如 Intel Iris）也要順：3D 以較低解析度算，再用 FSR 放大銳化
func _apply_quality() -> void:
	var vp := get_viewport()
	if OS.has_feature("web") or App.is_mobile() or RenderingServer.get_current_rendering_method() == "gl_compatibility":
		vp.scaling_3d_scale = 0.8 if App.settings.quality == "high" else 0.6
		return
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = 0.77 if App.settings.quality == "high" else 0.59
	vp.fsr_sharpness = 0.3


func _say(id: String, interrupt := false) -> void:
	if not quiet:
		Snd.say(id, interrupt)


func _sfx(n: String, v := 1.0) -> void:
	if not quiet:
		Snd.play(n, v)


func quit_game() -> void:
	Snd.stop_loops()


# ---------------------------------------------------------------- 蘋果、寶石
func _make_apple() -> Node3D:
	var holder := Node3D.new()
	if _apple_scene:
		var n: Node3D = _apple_scene.instantiate()
		var bb := Arena._aabb(n)
		var s := 1.7 / maxf(0.001, maxf(bb.size.x, maxf(bb.size.y, bb.size.z)))
		n.scale = Vector3.ONE * s
		n.position = -bb.get_center() * s
		holder.add_child(n)
	else:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.8
		sm.height = 1.5
		m.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.05, 0.08)
		mat.roughness = 0.25
		m.material_override = mat
		holder.add_child(m)
	if not arena.id in ["garden", "dino", "pond"]:
		# 太空裡沒有陽光照到的地方也看得到蘋果
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.9, 0.85)
		l.light_energy = 0.9
		l.omni_range = 3.2
		l.position = Vector3(0.6, 1.2, 0.8)
		holder.add_child(l)
	return holder


func _pick_kind() -> String:
	var w: Dictionary = Arena.INFO.get(arena.id, {}).get("food", {"apple": 1.0})
	var tot := 0.0
	for k in w:
		tot += float(w[k])
	var r := _rng.randf() * tot
	for k in w:
		r -= float(w[k])
		if r <= 0.0:
			return k
	return "apple"


func _in_water(p: Vector3) -> bool:
	return arena.underwater or (arena.water_y < INF and p.y < arena.water_y)


func _spawn_apple() -> void:
	var kind := _pick_kind()
	var p := Vector3.ZERO
	for k in 40:
		p = arena.random_point(6.0)
		if p.distance_to(snake.head_pos) > 9.0 and not _near_body(p, 2.0):
			break
	var n: Node3D
	match kind:
		"bacteria": n = Props.bacteria(_rng)
		"pest":
			n = Props.pest(_in_water(p))
			if not _in_water(p):
				_add_wings(n)
		_: n = _make_apple()
	add_child(n)
	n.position = p
	apples.append({"node": n, "pos": p, "ph": _rng.randf() * TAU, "kind": kind,
		"vel": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-1, 1)).normalized()})


## 會飛的害蟲：半透明翅膀（拍動）
func _add_wings(n: Node3D) -> void:
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.8, 0.85, 0.8, 0.35)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	wm.roughness = 0.1
	for s in [-1.0, 1.0]:
		var piv := Node3D.new()
		piv.name = "W%d" % (0 if s < 0 else 1)
		piv.position = Vector3(s * 0.2, 0.35, -0.4)
		n.add_child(piv)
		var q := QuadMesh.new()
		q.size = Vector2(1.2, 0.5)
		var w := MeshInstance3D.new()
		w.mesh = q
		w.material_override = wm
		w.position = Vector3(s * 0.6, 0, 0.3)
		w.rotation.x = -PI * 0.5
		piv.add_child(w)


func _near_body(p: Vector3, d: float) -> bool:
	for s in snake.samples:
		if s.distance_to(p) < d:
			return true
	return false


func _spawn_gem() -> void:
	gem = Node3D.new()
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(1.3, 1.3, 1.3)
	m.mesh = b
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/gem.gdshader")
	m.material_override = mat
	gem.add_child(m)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 0.65, 1.0)
	l.light_energy = 2.5
	l.omni_range = 9.0
	gem.add_child(l)
	add_child(gem)
	var p := Vector3.ZERO
	for k in 30:
		p = arena.random_point(8.0)
		if p.distance_to(snake.head_pos) > 14.0:
			break
	gem.position = p
	gem_life = 22.0
	_sfx("chime")
	_say("gem_appear")


func nearest_apple() -> Dictionary:
	var best := {}
	var bd := INF
	for a in apples:
		var d: float = snake.head_pos.distance_to(a.pos)
		if d < bd:
			bd = d
			best = a
	return best


# ---------------------------------------------------------------- 輸入
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		_touch_pt = e.position if e.pressed else null
	elif e is InputEventScreenDrag:
		_touch_pt = e.position
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_ESCAPE, KEY_P, KEY_SPACE:
				hud.toggle_pause()
			KEY_F:
				App.set_fullscreen(not bool(App.settings.fullscreen))
				App.save()
			KEY_C, KEY_V:
				next_cam()


## 視線點 → 轉向量（以畫面中心為準，中間有一小塊「直走區」）
func _gaze_steer(pt: Vector2) -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	var c := Vector2(vs.x * 0.5, vs.y * 0.47)
	var off := (pt - c) / (minf(vs.x, vs.y) * 0.5)
	var dead := 0.1
	var out := Vector2.ZERO
	for k in 2:
		var a := absf(off[k])
		var v := pow(clampf((a - dead) / (0.8 - dead), 0.0, 1.0), 1.15)
		out[k] = signf(off[k]) * v
	out.y = -out.y
	return out


## 追蹤／蛇眼鏡頭：看畫面哪一邊就往哪一邊轉。
## 側面、俯瞰、環繞鏡頭：看著 3D 空間裡的哪個位置，蛇就游向那裡。
func _steer_from_point(pt: Vector2) -> Vector2:
	if cam_mode <= 1:
		_gaze_dir = Vector3.ZERO
		return _gaze_steer(pt)
	var o := cam.project_ray_origin(pt)
	var dir := cam.project_ray_normal(pt)
	var plane_n := -cam.global_basis.z
	var denom := dir.dot(plane_n)
	if absf(denom) < 1e-4:
		return Vector2.ZERO
	var t := (snake.head_pos - o).dot(plane_n) / denom
	var target := o + dir * t
	var d := target - snake.head_pos
	if d.length() < 1.5:
		_gaze_dir = Vector3.ZERO
		return Vector2.ZERO
	d = d.normalized()
	_gaze_dir = d
	var v := Vector2(d.dot(snake.right()), d.dot(snake.up()))
	if d.dot(snake.fwd()) < 0.0:
		v = v.normalized() if v.length() > 0.01 else Vector2(1, 0)
	return (v * 2.0).limit_length(1.0)


func next_cam() -> void:
	cam_mode = (cam_mode + 1) % CAM_NAMES.size()
	App.settings.cam = cam_mode
	App.save()
	hud.popup(CAM_NAMES[cam_mode], Color(0.7, 0.9, 1.0))
	_say("cam_%d" % cam_mode, true)


func _read_input(dt: float) -> Vector2:
	var s := Vector2.ZERO
	var kx := Input.get_axis("ui_left", "ui_right")
	var ky := Input.get_axis("ui_down", "ui_up")
	if Input.is_key_pressed(KEY_A): kx -= 1.0
	if Input.is_key_pressed(KEY_D): kx += 1.0
	if Input.is_key_pressed(KEY_W): ky += 1.0
	if Input.is_key_pressed(KEY_S): ky -= 1.0
	var keys := Vector2(clampf(kx, -1, 1), clampf(ky, -1, 1))
	if keys != Vector2.ZERO:
		_gaze_still = 0.0
		return keys
	if ap:
		return _autopilot()
	if _touch_pt != null:
		return _steer_from_point(_touch_pt)
	if App.settings.control == "keys" and Gaze.bot_point == null:
		return Vector2.ZERO
	if Gaze.valid and not hud.gaze_on_ui():
		s = _steer_from_point(Gaze.point)
		# 專注力：視線穩穩的（移動很少）
		var mv := Gaze.point.distance_to(_gaze_prev) / maxf(dt, 0.001)
		_gaze_prev = Gaze.point
		var vs := get_viewport().get_visible_rect().size
		if mv < vs.y * 0.6:
			_gaze_still += dt
		else:
			_gaze_still = 0.0
		s = _assist(s)
	return s


## 小柯瞄準輔助：視線大致對著蘋果時，幫忙把蛇頭修正過去
func _assist(s: Vector2) -> Vector2:
	var lvl := int(App.settings.assist)
	if lvl <= 0 or apples.is_empty():
		return s
	var best := Vector2.ZERO
	var best_dot := cos(deg_to_rad(28.0 if lvl == 1 else 40.0))
	var found := false
	for a in apples:
		var d: Vector3 = (a.pos - snake.head_pos)
		if d.length() > 30.0:
			continue
		var dn := d.normalized()
		var dd := dn.dot(snake.fwd())
		if dd > best_dot:
			best_dot = dd
			best = Vector2(dn.dot(snake.right()), dn.dot(snake.up()))
			found = true
	if not found:
		return s
	var k := 0.35 if lvl == 1 else 0.6
	var aim := (best * 2.5).limit_length(1.0)
	return s.lerp(aim, k * (1.0 - clampf(s.length(), 0.0, 1.0) * 0.5))


## 小柯示範：自動轉向最近的蘋果，避開邊界與自己的身體
func _autopilot() -> Vector2:
	var tgt: Vector3
	if gem and gem_life > 0 and lives < LIVES_MAX:
		tgt = gem.position
	else:
		var a := nearest_apple()
		if a.is_empty():
			return Vector2.ZERO
		tgt = a.pos
	var d := (tgt - snake.head_pos).normalized()
	var v := Vector2(d.dot(snake.right()), d.dot(snake.up()))
	if d.dot(snake.fwd()) < 0.0:
		v = v.normalized() if v.length() > 0.01 else Vector2(1, 0)
	var out := (v * 2.2).limit_length(1.0)
	# 前方有身體就往旁邊閃
	var ahead := snake.head_pos + snake.fwd() * 3.0
	for i in range(12, snake.samples.size()):
		if snake.samples[i].distance_to(ahead) < 1.6:
			var away := (ahead - snake.samples[i]).normalized()
			out += Vector2(away.dot(snake.right()), away.dot(snake.up())) * 1.5
			break
	return out.limit_length(1.0)


# ---------------------------------------------------------------- 每格
func _process(dt: float) -> void:
	if done:
		_update_camera(dt)
		return
	_check_gaze_lost(dt)
	if resting > 0.0:
		_update_rest(dt)
		_update_camera(dt * 0.3)
		return
	if paused or auto_paused:
		_update_camera(0.0)
		return
	elapsed += dt
	play_since_rest += dt
	if not quiet and not App.demo and int(App.settings.rest_min) > 0 and play_since_rest > float(App.settings.rest_min) * 60.0:
		_start_rest()
	var sdt := dt * (0.35 if calm > 0.0 else 1.0)
	calm = maxf(0.0, calm - dt)
	steer = _read_input(dt)
	var rate := 1.75 * float(App.settings.turn)
	snake.steer(sdt, steer, rate)
	_avoid_edges(sdt)
	# 專注力
	if bool(App.settings.focus_boost):
		var steady := (_gaze_still > 0.6 or steer.length() < 0.3) and steer.length() < 0.6
		focus = clampf(focus + (dt * 0.12 if steady else -dt * 0.35), 0.0, 1.0)
		if focus >= 0.99 and not _focus_said:
			_focus_said = true
			_say("focus_full")
		elif focus < 0.5:
			_focus_said = false
	else:
		focus = 0.0
	var v := speed * (0.9 + 0.45 * focus)
	snake.move(sdt, v)
	snake.shimmer = focus
	invuln = maxf(0.0, invuln - dt)
	combo_t = maxf(0.0, combo_t - dt)
	if combo_t <= 0.0:
		combo = 0
	_eat_apples()
	_update_gem(dt)
	_check_rings()
	_check_self()
	arena.tick(dt, snake.head_pos, cam.global_position)
	_check_hazards(dt)
	_update_facts(dt)
	_move_food(sdt)
	_update_camera(dt)
	_wall_say = maxf(0.0, _wall_say - dt)


## 蘋果上下浮動；細菌慢慢漂；害蟲會亂飛，蛇靠近時會逃
func _move_food(dt: float) -> void:
	for a in apples:
		var n: Node3D = a.node
		match str(a.get("kind", "apple")):
			"apple":
				n.rotate_y(dt * 0.6)
				n.position = a.pos + Vector3(0, sin(elapsed * 1.6 + a.ph) * 0.25, 0)
			"bacteria":
				a.pos += (a.vel as Vector3) * dt * 0.4
				n.rotate(Vector3(0.2, 1, 0.1).normalized(), dt * 0.8)
				n.position = a.pos + Vector3(sin(elapsed * 2.0 + a.ph), cos(elapsed * 1.7 + a.ph), 0) * 0.15
			"pest":
				var to_head: Vector3 = snake.head_pos - (a.pos as Vector3)
				var v: Vector3 = a.vel
				if to_head.length() < 9.0:
					v = v.lerp(-to_head.normalized(), dt * 2.0).normalized()   # 逃跑（但比蛇慢）
				else:
					v = v.rotated(Vector3.UP, sin(elapsed * 0.7 + a.ph) * dt).normalized()
				a.vel = v
				var spd := 2.2 if to_head.length() < 9.0 else 1.0
				a.pos += v * dt * spd * (0.55 if relax else 0.7)
				if not n.position.is_equal_approx(a.pos):
					n.look_at_from_position(a.pos, a.pos + v, Vector3.UP if absf(v.y) < 0.95 else Vector3.FORWARD)
				for k in 2:
					var w := n.get_node_or_null("W%d" % k) as Node3D
					if w:
						w.rotation.z = sin(elapsed * 40.0) * 0.6 * (1 if k == 0 else -1)
				n.rotation.z += sin(elapsed * 6.0 + a.ph) * 0.02
		# 不要跑出邊界、牆、水面
		var p: Vector3 = a.pos
		if p.length() > arena.R - 5.0 or not arena.inside_walls(p, 2.0) or (arena.floor_y > -INF and p.y < arena.floor_y + 2.0):
			a.vel = (Vector3(0, arena.floor_y + 10.0 if arena.floor_y > -INF else 0.0, 0) - p).normalized()
			a.pos = p + (a.vel as Vector3) * 0.2
		if str(a.get("kind", "")) == "pest" and arena.water_y < INF and arena.id == "pond":
			a.pos.y = minf(a.pos.y, arena.water_y - 1.0)


func _check_gaze_lost(dt: float) -> void:
	# 只有用眼睛玩時才自動暫停（滑鼠、鍵盤、示範都不會）
	var eye := Gaze.source in ["eyemouse", "webcam"] and Gaze.bot_point == null and not ap and not quiet
	if not eye or not bool(App.settings.auto_pause) or paused:
		_lost_t = 0.0
		if auto_paused and not eye:
			auto_paused = false
		return
	if Gaze.real_valid:
		if auto_paused:
			_lost_t += dt
			if _lost_t > 1.0:
				auto_paused = false
				_lost_t = 0.0
				_say("eye_back")
		else:
			_lost_t = 0.0
	else:
		if not auto_paused:
			_lost_t += dt
			if _lost_t > 1.8:
				auto_paused = true
				_lost_t = 0.0
				_say("lost_eye", true)
		else:
			_lost_t = 0.0


func _avoid_edges(dt: float) -> void:
	var p := snake.head_pos
	var d := p.length()
	var soft := arena.R - 9.0
	if d > soft:
		var k := clampf((d - soft) / 9.0, 0.0, 1.0)
		# 往中心轉，越靠近邊界轉得越用力
		var inward := -p.normalized()
		if snake.fwd().dot(inward) < 0.3:
			snake.turn_toward(inward, k * k * 2.6 * dt)
		if d > arena.R - 1.0:
			snake.head_pos = p.normalized() * (arena.R - 1.0)
			snake.turn_toward(inward, 1.2)
			_hit_wall()
	if arena.floor_y > -INF:
		var h := p.y - arena.floor_y
		if h < 4.0 and snake.fwd().y < 0.35:
			snake.turn_toward(Vector3(snake.fwd().x, 0.6, snake.fwd().z), (1.0 - h / 4.0) * 2.4 * dt)
		if h < 1.0:
			snake.head_pos.y = arena.floor_y + 1.0
			snake.turn_toward(Vector3(snake.fwd().x, 0.8, snake.fwd().z), 0.8)
			_hit_wall()
	for o in arena.obstacles:
		var c: Vector3 = o.c
		var r: float = o.r
		var dd := snake.head_pos.distance_to(c)
		if dd < r + 3.5:
			var away := (snake.head_pos - c).normalized()
			if snake.fwd().dot(-away) > -0.2:
				var k2 := clampf(1.0 - (dd - r) / 3.5, 0.0, 1.0)
				var side := (snake.fwd() - away * snake.fwd().dot(away)).normalized()
				snake.turn_toward(side + away * 0.5, k2 * 2.4 * dt)
		if dd < r + 0.7:
			snake.head_pos = c + (snake.head_pos - c).normalized() * (r + 0.7)
			_hit_wall()
	# 荷葉：水平圓盤，從上面或下面繞過
	for dsc in arena.discs:
		var dc: Vector3 = dsc.c
		var hp2 := snake.head_pos
		var hd := Vector2(hp2.x - dc.x, hp2.z - dc.z).length()
		var dy := hp2.y - dc.y
		if hd < float(dsc.r) + 1.5 and absf(dy) < 3.0:
			var vdir := 1.0 if dy >= 0.0 else -1.0
			snake.turn_toward(Vector3(snake.fwd().x, 0.8 * vdir, snake.fwd().z), (1.0 - absf(dy) / 3.0) * 2.5 * dt)
			if absf(dy) < 1.0:
				snake.head_pos.y = dc.y + vdir * 1.0
	# 花園草叢：直立圓柱，從旁邊繞過或從上面越過
	for col in arena.columns:
		var h: float = col.h
		var hp := snake.head_pos
		if hp.y > h + 2.0:
			continue
		var c2 := Vector2(hp.x - col.c.x, hp.z - col.c.z)
		var dd2 := c2.length()
		var rr: float = col.r
		if dd2 < rr + 4.0:
			var away := Vector3(c2.x, 0, c2.y).normalized()
			if snake.fwd().dot(-away) > -0.2:
				var k3 := clampf(1.0 - (dd2 - rr) / 4.0, 0.0, 1.0)
				var side2 := (snake.fwd() - away * snake.fwd().dot(away)).normalized()
				snake.turn_toward(side2 + away * 0.6, k3 * 2.6 * dt)
		if dd2 < rr + 0.6:
			var pushed := Vector2(col.c.x, col.c.z) + c2.normalized() * (rr + 0.6)
			snake.head_pos = Vector3(pushed.x, hp.y, pushed.y)


func _hit_wall() -> void:
	if _wall_say > 0.0:
		return
	_wall_say = 3.0
	_sfx("wall", 0.7)
	if bool(App.settings.wall_hurt) and invuln <= 0.0:
		_lose_life("wall_hurt")
	else:
		_say("wall")
		hud.popup("邊界，轉回來囉", Color(0.6, 0.9, 1.0))


# ---------------------------------------------------------------- 飛碟（太陽系）
func _check_hazards(dt: float) -> void:
	_hz_warn = maxf(0.0, _hz_warn - dt)
	for h in arena.hazards:
		var n: Node3D = h.node
		var d := snake.head_pos.distance_to(n.global_position)
		if d < 14.0 and _hz_warn <= 0.0:
			_hz_warn = 12.0
			_say("ufo_warn")
		if d < float(h.r) + 0.8 and invuln <= 0.0:
			snake.head_pos = n.global_position + (snake.head_pos - n.global_position).normalized() * (float(h.r) + 1.0)
			snake.turn_toward(snake.head_pos - n.global_position, 1.2)
			_lose_life("ufo_hit")


# ---------------------------------------------------------------- 科普知識卡（學）
func _queue_fact(cat: String) -> void:
	if quiet:
		return
	var ids := Lines.facts_of(cat)
	if ids.is_empty():
		return
	# 優先講還沒聽過的
	var seen: Array = App.progress.get("facts", [])
	var fresh := ids.filter(func(i): return not seen.has(i))
	var pool := fresh if not fresh.is_empty() else ids
	var id: String = pool[_rng.randi() % pool.size()]
	if not _fact_queue.has(id):
		_fact_queue.append(id)


func _update_facts(dt: float) -> void:
	if quiet:
		return
	fact_t += dt
	# 看著行星、黑洞、恐龍一段時間就講它的知識
	var fwd := -cam.global_basis.z
	for sp in arena.spots:
		var n: Node3D = sp.node
		if not is_instance_valid(n) or _spot_done.has(sp.fact):
			continue
		var to := n.global_position - cam.global_position
		var ang := fwd.angle_to(to)
		var lim := atan2(float(sp.r) * 1.3, to.length()) + deg_to_rad(10.0)
		var key: String = sp.fact
		if ang < lim:
			_spot_t[key] = float(_spot_t.get(key, 0.0)) + dt
			if float(_spot_t[key]) > 1.2:
				_spot_done[key] = true
				_fact_queue.push_front(key)
		else:
			_spot_t[key] = 0.0
	# 有知識分類的世界：沒事時也會定期講一則
	var cat := str(Arena.INFO.get(arena.id, {}).get("facts", ""))
	if cat in ["space", "hole", "dino"] and fact_t > 35.0 and _fact_queue.is_empty():
		_queue_fact(cat)
	if not _fact_queue.is_empty() and fact_t > 12.0 and not Snd.is_speaking() and not hud.fact_showing():
		var id: String = _fact_queue.pop_front()
		fact_t = 0.0
		hud.show_fact(id)
		Snd.say(id)
		var seen: Array = App.progress.get("facts", [])
		if not seen.has(id):
			seen.append(id)
			App.progress["facts"] = seen
			App.save()


# ---------------------------------------------------------------- 護眼休息（養）
func _start_rest() -> void:
	play_since_rest = 0.0
	resting = 24.0
	hud.show_rest(true)
	Snd.say("rest_1", true)


func _update_rest(dt: float) -> void:
	resting -= dt
	hud.rest_left = resting
	if resting <= 0.0:
		resting = 0.0
		hud.show_rest(false)
		Snd.say("rest_done", true)


func skip_rest() -> void:
	resting = 0.01


func _eat_apples() -> void:
	var mouth := snake.head_pos + snake.fwd() * 0.6
	for i in range(apples.size() - 1, -1, -1):
		var a: Dictionary = apples[i]
		if mouth.distance_to((a.node as Node3D).position) < EAT_DIST:
			(a.node as Node3D).queue_free()
			apples.remove_at(i)
			eaten += 1
			combo = combo + 1 if combo_t > 0.0 else 1
			combo_t = 6.0
			var kind := str(a.get("kind", "apple"))
			food_eaten[kind] = int(food_eaten.get(kind, 0)) + 1
			var base_pts: int = {"apple": 100, "bacteria": 60, "pest": 150}.get(kind, 100)
			var pts := base_pts + (combo - 1) * 50 + int(focus * 50)
			score += pts
			snake.grow(1.6)
			snake.chomp()
			snake.glow = 0.6
			_sfx("eat")
			var label: String = {"apple": "", "bacteria": "細菌 ", "pest": "害蟲 "}.get(kind, "")
			hud.popup("%s+%d%s" % [label, pts, ("　連擊 ×%d" % combo) if combo > 1 else ""], Color(1.0, 0.85, 0.3))
			App.feed_pet(1)
			if kind == "bacteria":
				_say("eat_bacteria")
				_queue_fact("germ")
			elif kind == "pest":
				_say("eat_pest")
				_queue_fact("pest")
			elif combo == 3:
				_say("eat_3")
			elif combo > 3:
				_say("combo")
			elif eaten <= 2 or _rng.randf() < 0.2:
				_say("eat_1" if eaten % 2 == 1 else "eat_2")
			_spawn_apple()


func _update_gem(dt: float) -> void:
	if gem == null:
		gem_timer -= dt
		if gem_timer <= 0.0:
			gem_timer = 40.0 if lives >= LIVES_MAX else 22.0
			_spawn_gem()
		return
	gem_life -= dt
	gem.rotate(Vector3(0.3, 1, 0.2).normalized(), dt * 1.4)
	var mat: ShaderMaterial = (gem.get_child(0) as MeshInstance3D).material_override
	mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(elapsed * 6.0))
	if gem_life < 4.0:
		gem.visible = fmod(gem_life, 0.4) > 0.15
	if (snake.head_pos + snake.fwd() * 0.6).distance_to(gem.position) < EAT_DIST + 0.2:
		gem.queue_free()
		gem = null
		_sfx("gem")
		calm = 3.0
		snake.glow = 1.0
		_say("gem_eat", true)
		if lives < LIVES_MAX:
			lives += 1
			_sfx("heal")
			hud.popup("恢復一顆愛心 ♥", Color(0.5, 0.8, 1.0))
			_say("gem_heal")
		else:
			score += 300
			hud.popup("+300", Color(0.5, 0.8, 1.0))
			_say("gem_score")
	elif gem_life <= 0.0:
		gem.queue_free()
		gem = null


func _check_rings() -> void:
	for i in arena.rings.size():
		var rg: Dictionary = arena.rings[i]
		var n: Node3D = rg.node
		var nrm := n.global_basis.y.normalized()
		var rel := snake.head_pos - n.global_position
		var side := rel.dot(nrm)
		var prev: float = _ring_side[i]
		_ring_side[i] = side
		if prev != 0.0 and signf(prev) != signf(side) and (rel - nrm * side).length() < float(rg.r):
			rings_passed += 1
			score += 50
			_sfx("ring")
			hud.popup("穿過光環 +50", Color(0.5, 1.0, 0.9))
			if rings_passed <= 2:
				_say("ring")
			arena.move_ring(i)
			_ring_side[i] = 0.0


func _check_self() -> void:
	if invuln > 0.0:
		return
	var tip := snake.head_pos + snake.fwd() * 0.45
	var s := snake.samples
	var start := int(3.2 / Snake.SPACING)
	for i in range(start, s.size()):
		if tip.distance_to(s[i]) < 0.35 + snake.radii[i] * 0.85:
			bites += 1
			snake.cut_at(i)
			_lose_life("bite")
			return


func _lose_life(say_id: String) -> void:
	if relax:
		# 放鬆模式：不扣愛心、不會結束，只溫柔提醒
		invuln = 2.0
		snake.hurt = 0.6
		combo = 0
		_sfx("wall", 0.6)
		hud.popup("沒關係，慢慢來", Color(0.7, 0.9, 1.0))
		_say(say_id + "_relax", true)
		return
	lives -= 1
	invuln = 2.0
	snake.hurt = 1.0
	combo = 0
	focus *= 0.5
	_sfx("hurt")
	hud.popup("少一顆愛心", Color(1.0, 0.4, 0.35))
	hud.flash()
	if lives <= 0:
		_game_over()
		return
	_say(say_id, true)
	if lives == 1:
		_say("last_life")


func _game_over() -> void:
	if quiet:
		lives = LIVES_MAX
		return
	done = true
	_sfx("over")
	var is_best := false
	if not App.demo and not ap:
		is_best = App.record(world_id, score, eaten)
	_say("best" if is_best else "over", true)
	var res := {"score": score, "apples": eaten, "length": snake.length, "best": App.best(world_id), "is_best": is_best,
		"time": elapsed, "rings": rings_passed, "world": world_id}
	hud.show_result(res)
	finished.emit(res)


# ---------------------------------------------------------------- 鏡頭
func _update_camera(dt: float) -> void:
	var f := snake.fwd()
	var u := snake.up()
	var flat := Vector3(f.x, 0, f.z).normalized() if Vector2(f.x, f.z).length() > 0.05 else Vector3.FORWARD
	var side := flat.cross(Vector3.UP).normalized()
	var want := snake.head_pos - f * 7.5 + u * 2.6
	var look := snake.head_pos + f * 6.0
	match cam_mode:
		1:   # 蛇眼：在頭上方一點、往前看
			want = snake.head_pos + u * 0.75 + f * 0.2
			look = snake.head_pos + f * 10.0 + u * 0.4
		2:   # 側面
			want = snake.head_pos + side * 13.0 + Vector3.UP * 3.0 - flat * 2.0
			look = snake.head_pos + flat * 3.0
		3:   # 高空俯瞰
			want = snake.head_pos + Vector3.UP * 22.0 - flat * 6.0
			look = snake.head_pos + flat * 2.0
		4:   # 環繞
			_orbit += dt * 0.25
			want = snake.head_pos + Vector3(cos(_orbit), 0.35, sin(_orbit)) * 15.0
			look = snake.head_pos
	var k := (1.0 - exp(-dt * (12.0 if cam_mode == 1 else 4.0))) if dt > 0.0 else 0.0
	_cam_pos = _cam_pos.lerp(want, k)
	_cam_up = Vector3.UP   # 畫面永遠保持水平
	# 鏡頭不要穿出邊界或地面
	if _cam_pos.length() > arena.R - 0.5:
		_cam_pos = _cam_pos.normalized() * (arena.R - 0.5)
	if arena.floor_y > -INF and _cam_pos.y < arena.floor_y + 0.6:
		_cam_pos.y = arena.floor_y + 0.6
	for dsc in arena.discs:
		var dc2: Vector3 = dsc.c
		if Vector2(_cam_pos.x - dc2.x, _cam_pos.z - dc2.z).length() < float(dsc.r) + 0.5 and absf(_cam_pos.y - dc2.y) < 1.2:
			_cam_pos.y = dc2.y + (1.3 if snake.head_pos.y >= dc2.y else -1.3)
	for col in arena.columns:
		# 旁觀鏡頭（側面、俯瞰、環繞）在草叢、蕨類裡時，往上抬到植物上方
		if cam_mode >= 2 and _cam_pos.y < float(col.h) + 2.0 and Vector2(_cam_pos.x - col.c.x, _cam_pos.z - col.c.z).length() < float(col.r) * 2.5 + 1.0:
			_cam_pos.y = lerpf(_cam_pos.y, float(col.h) + 2.0, 0.2)
			continue
		if _cam_pos.y < float(col.h) and Vector2(_cam_pos.x - col.c.x, _cam_pos.z - col.c.z).length() < float(col.r) + 0.5:
			_cam_pos = _cam_pos.lerp(snake.head_pos - f * 3.0 + Vector3.UP * 1.5, 0.5)
			break
	cam.global_position = _cam_pos
	snake.head.visible = cam_mode != 1
	cam.fov = 80.0 if cam_mode == 1 else 72.0
	if look.distance_to(_cam_pos) > 0.1 and absf((look - _cam_pos).normalized().dot(Vector3.UP)) < 0.995:
		cam.look_at(look, _cam_up)


## 把世界座標轉成畫面座標（HUD 用）；在鏡頭後面時回傳 null
func screen_pos(p: Vector3):
	if cam.is_position_behind(p):
		return null
	return cam.unproject_position(p)
