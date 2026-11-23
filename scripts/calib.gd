class_name Calib
extends Control
## 攝影機眼控校正（每位使用者一次；換座位或燈光要重做）。
## 步驟：準備（看預覽、距離）→ 正前方 → 眼睛看點（頭不動，13 點）→ 轉頭看點（5 點，讓校正學會頭部轉動）
## → 嶺迴歸擬合 → 評估 5 點（顯示平均誤差）。

signal finished(ok: bool)

const MARGIN := 0.08
var stage := "setup"
var samples: Array = []          # [[feat, Vector2]]
var targets: Array = []
var ti := 0
var t := 0.0
var dot := Vector2(-100, -100)
var dot_from := Vector2.ZERO
var collecting := false
var cur: Array = []              # 這一點收集的樣本
var head_samples := {}           # 名稱 -> [yaw, pitch] 陣列
var center_hp: Array = []
var eval_err: Array = []
var eval_pts: Array = []
var model := {}
var head := {}
var msg := ""
var sub := ""
var preview_tex: ImageTexture
var _auto_t := 0.0
var _btns: Array = []
var font: Font
var _fake := false
var _fake_noise := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = load("res://assets/fonts/ui_font.tres")
	_fake = App.args.has("fake-eyecam")
	EyeCam.sample.connect(_on_sample)
	EyeCam.preview.connect(_on_preview)
	EyeCam.set_preview(true)
	if not EyeCam.linked and EyeCam.status in ["off", "error"] and not _fake:
		EyeCam.start()
	_setup_stage()


func _exit_tree() -> void:
	EyeCam.set_preview(false)


func _vs() -> Vector2:
	return get_viewport().get_visible_rect().size


func _clear_btns() -> void:
	for b in _btns:
		if is_instance_valid(b):
			b.queue_free()
	_btns.clear()


func _btn(text: String, r: Rect2, col: Color, cb: Callable, sub_t := "") -> void:
	var b := GazeButton.make(self, text, r, col, cb)
	b.sub = sub_t
	b.font_size = 24
	_btns.append(b)


func _setup_stage() -> void:
	stage = "setup"
	_clear_btns()
	var vs := _vs()
	msg = "攝影機眼控校正"
	sub = "坐正、臉在預覽畫面中間，距離螢幕約 50～70 公分。正面光線最好，背後不要有強光。"
	_btn("開始校正", Rect2(vs.x * 0.5 - 330, vs.y - 120, 300, 84), Color(0.15, 0.55, 0.35), _start, "看著正前方 3 秒也會自動開始")
	_btn("換攝影機", Rect2(vs.x * 0.5 + 30, vs.y - 120, 220, 84), Color(0.3, 0.4, 0.55), _next_cam)
	_btn("◀ 返回", Rect2(16, 16, 150, 64), Color(0.35, 0.38, 0.45), func(): _finish(false))
	_auto_t = 0.0
	Snd.say("calib_intro", true)


func _next_cam() -> void:
	EyeCam.set_camera((EyeCam.camera_index + 1) % 3)


func _start() -> void:
	_clear_btns()
	_btns.append(null)
	samples.clear()
	head_samples.clear()
	center_hp.clear()
	stage = "center"
	msg = "請看著中間的點"
	sub = "頭和眼睛都朝向正前方"
	dot = _vs() * 0.5
	dot_from = dot
	t = 0.0
	cur.clear()
	_btn("取消", Rect2(16, 16, 130, 56), Color(0.45, 0.3, 0.3), _setup_stage)
	Snd.say("calib_center", true)


func _grid_targets() -> Array:
	var out := []
	var xs := [MARGIN, 0.5, 1.0 - MARGIN]
	var ys := [MARGIN, 0.5, 1.0 - MARGIN]
	for j in 3:
		for i in 3:
			out.append(Vector2(xs[i if j % 2 == 0 else 2 - i], ys[j]))
	# 角落各再加一次（角落最難，UnitEye 也會重複掃角落）＋四個中間點
	out.append_array([Vector2(0.3, 0.3), Vector2(0.7, 0.3), Vector2(0.7, 0.7), Vector2(0.3, 0.7)])
	out.append_array([Vector2(MARGIN, MARGIN), Vector2(1.0 - MARGIN, 1.0 - MARGIN), Vector2(1.0 - MARGIN, MARGIN), Vector2(MARGIN, 1.0 - MARGIN)])
	# 再加 6 個隨機位置（每次不同），讓校正涵蓋整個畫面，不只集中在中間與格點
	out.append_array(_random_points(6))
	# 順序打亂：點會在畫面各處隨機跳動
	out.shuffle()
	return out


## 分散的隨機點：畫面切成 3×2 區，每區隨機一點，避免擠在一起
func _random_points(n: int) -> Array:
	var cells := []
	for j in 2:
		for i in 3:
			cells.append(Rect2(MARGIN + i * (1.0 - 2 * MARGIN) / 3.0, MARGIN + j * (1.0 - 2 * MARGIN) / 2.0, (1.0 - 2 * MARGIN) / 3.0, (1.0 - 2 * MARGIN) / 2.0))
	cells.shuffle()
	var out := []
	for k in n:
		var c: Rect2 = cells[k % cells.size()]
		out.append(Vector2(randf_range(c.position.x, c.end.x), randf_range(c.position.y, c.end.y)))
	return out


func _begin_eyes() -> void:
	stage = "eyes"
	targets = _grid_targets()
	ti = 0
	t = 0.0
	msg = "頭不要動，用眼睛追著點看"
	sub = "點縮小時保持看著它的中心"
	dot_from = dot
	Snd.say("calib_eyes", true)


func _begin_head() -> void:
	stage = "head"
	targets = [{"p": Vector2(0.5, 0.5), "n": "c"}, {"p": Vector2(MARGIN, 0.5), "n": "l"}, {"p": Vector2(1.0 - MARGIN, 0.5), "n": "r"},
		{"p": Vector2(0.5, MARGIN), "n": "u"}, {"p": Vector2(0.5, 1.0 - MARGIN), "n": "d"}, {"p": Vector2(0.5, 0.5), "n": "c"}]
	ti = 0
	t = 0.0
	msg = "這次請「轉頭」看著點"
	sub = "慢慢把頭轉過去看著點"
	dot_from = dot
	Snd.say("calib_head", true)


func _begin_eval() -> void:
	var vs := _vs()
	model = EyeCam.fit(samples, vs)
	if model.is_empty():
		msg = "收集到的資料太少"
		sub = "請確認攝影機看得到臉，再試一次"
		_setup_stage()
		return
	var yl := _mean(head_samples.get("l", []), 0)
	var yr := _mean(head_samples.get("r", []), 0)
	var pu := _mean(head_samples.get("u", []), 1)
	var pd := _mean(head_samples.get("d", []), 1)
	var y0 := _mean(center_hp, 0)
	var p0 := _mean(center_hp, 1)
	head = {"yaw0": y0, "pitch0": p0, "yaw_sign": 1.0 if yl >= yr else -1.0, "pitch_sign": 1.0 if pu >= pd else -1.0,
		"yaw_range": maxf(5.0, absf(yl - yr) * 0.5), "pitch_range": maxf(4.0, absf(pu - pd) * 0.5)}
	EyeCam.apply_calib(model, head)
	stage = "eval"
	targets = _random_points(5)   # 評估點也隨機，檢查的是整個畫面而不是固定位置
	ti = 0
	t = 0.0
	eval_err.clear()
	eval_pts.clear()
	msg = "最後檢查準確度：眼睛看著點"
	sub = "綠色小點是電腦算出來你在看的位置"
	dot_from = dot
	Snd.say("calib_eval", true)


func _mean(arr: Array, k: int) -> float:
	if arr.is_empty():
		return 0.0
	var s := 0.0
	for a in arr:
		s += float(a[k])
	return s / arr.size()


func _show_result() -> void:
	stage = "result"
	_clear_btns()
	var vs := _vs()
	var e := 0.0
	for v in eval_err:
		e += v * v
	e = sqrt(e / maxf(1, eval_err.size()))
	var pct := e / vs.length() * 100.0
	var grade := "優良" if pct < 6.0 else ("可以使用" if pct < 11.0 else "不太準")
	msg = "校正完成：%s" % grade
	sub = "平均誤差約 %d 像素（畫面對角線的 %.1f%%）。遊戲時看著想去的地方，蛇就會游過去。" % [int(e), pct]
	if not _fake:
		Snd.say("calib_good" if pct < 11.0 else "calib_bad", true)
	_btn("完成", Rect2(vs.x * 0.5 - 330, vs.y - 120, 300, 84), Color(0.15, 0.55, 0.35), func(): _finish(true))
	_btn("重新校正", Rect2(vs.x * 0.5 + 30, vs.y - 120, 260, 84), Color(0.6, 0.4, 0.15), _setup_stage)
	if App.test_mode:
		print("CALIB_RESULT rmse_px=%d pct=%.2f samples=%d yaw_sign=%d pitch_sign=%d lambda=%s" % [int(e), pct, samples.size(), int(head.yaw_sign), int(head.pitch_sign), str(model.get("lambda"))])
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png("user://calib_result.png")
		get_tree().quit()


func _finish(ok: bool) -> void:
	finished.emit(ok)
	queue_free()


func _on_preview(img: Image) -> void:
	if preview_tex == null or preview_tex.get_size() != Vector2(img.get_size()):
		preview_tex = ImageTexture.create_from_image(img)
	else:
		preview_tex.update(img)


func _on_sample(f: PackedFloat32Array) -> void:
	if not collecting or EyeCam.blink:
		return
	cur.append(f)


## 測試用假攝影機：特徵＝目標位置的非線性函數＋雜訊
func _fake_feed() -> void:
	var vs := _vs()
	var n := dot / vs - Vector2(0.5, 0.5)
	var head_turn := Vector2.ZERO
	if stage == "head":
		head_turn = n * Vector2(-50, -30)
	var ix := n.x * 0.35 + randf_range(-0.01, 0.01)
	var iv := n.y * 0.12 + randf_range(-0.006, 0.006)
	var m := {"ir": [0.5 + ix, iv, 0.5 - ix, iv], "bs": [maxf(0, n.x), maxf(0, -n.x), maxf(0, -n.y), maxf(0, n.y), maxf(0, -n.x), maxf(0, n.x), maxf(0, -n.y), maxf(0, n.y), 0, 0],
		"hp": [head_turn.x + randf_range(-0.5, 0.5), head_turn.y + randf_range(-0.5, 0.5), 0.0], "nose": [0.5 - head_turn.x * 0.004, 0.5], "dist": 55}
	var f := EyeCam.features(m)
	if collecting:
		cur.append(f)


func _process(dt: float) -> void:
	queue_redraw()
	var vs := _vs()
	if _fake and stage != "setup":
		_fake_feed()
	match stage:
		"setup":
			if EyeCam.face or _fake:
				_auto_t += dt
				if _auto_t > (0.2 if _fake else 3.0):
					_start()
			else:
				_auto_t = 0.0
			sub = "坐正、臉在預覽畫面中間，距離螢幕約 50～70 公分。正面光線最好，背後不要有強光。"
			if EyeCam.face and (EyeCam.dist_cm > 85 or (EyeCam.dist_cm > 0 and EyeCam.dist_cm < 35)):
				sub = "距離約 %d 公分：%s" % [int(EyeCam.dist_cm), "太遠了，請靠近一點" if EyeCam.dist_cm > 85 else "太近了，請往後坐一點"]
		"center":
			t += dt
			collecting = t > 0.6
			if collecting:
				pass
			if t > 2.2:
				collecting = false
				for f in cur:
					center_hp.append([f[4] * 30.0, f[5] * 30.0])
					samples.append([f, dot])
				cur.clear()
				_begin_eyes()
		"eyes", "head", "eval":
			var tgt_n: Vector2 = targets[ti] if not (targets[ti] is Dictionary) else targets[ti].p
			var tgt := tgt_n * vs
			var move_t := 0.55
			var settle := 0.45 if stage == "eyes" else (0.9 if stage == "head" else 0.5)
			var hold := 1.0 if stage == "eyes" else (1.3 if stage == "head" else 1.0)
			t += dt
			var k := clampf(t / move_t, 0, 1)
			dot = dot_from.lerp(tgt, k * k * (3 - 2 * k))
			collecting = t > move_t + settle and t < move_t + settle + hold
			if stage == "eval" and collecting and EyeCam.calibrated and not cur.is_empty():
				var p := EyeCam.predict(cur[cur.size() - 1])
				eval_pts.append(p)
			if t >= move_t + settle + hold:
				collecting = false
				_end_point(tgt)
				ti += 1
				t = 0.0
				dot_from = dot
				if ti >= targets.size():
					if stage == "eyes":
						_begin_head()
					elif stage == "head":
						_begin_eval()
					else:
						_show_result()


func _end_point(tgt: Vector2) -> void:
	# 去掉離群值：只留最中間 80%（以特徵前兩項的距離中位數判斷）
	var good := cur
	if cur.size() >= 6:
		var mx := 0.0
		var my := 0.0
		for f in cur:
			mx += f[0]
			my += f[1]
		mx /= cur.size()
		my /= cur.size()
		var scored := []
		for f in cur:
			scored.append([absf(f[0] - mx) + absf(f[1] - my), f])
		scored.sort_custom(func(a, b): return a[0] < b[0])
		good = []
		for i in int(scored.size() * 0.8):
			good.append(scored[i][1])
	if stage == "eval":
		var errs := []
		for f in good:
			errs.append(EyeCam.predict(f).distance_to(tgt))
		if not errs.is_empty():
			errs.sort()
			eval_err.append(errs[errs.size() / 2])
	else:
		for f in good:
			samples.append([f, tgt])
		if stage == "head":
			var nm: String = targets[ti].n
			if not head_samples.has(nm):
				head_samples[nm] = []
			for f in good:
				head_samples[nm].append([f[4] * 30.0, f[5] * 30.0])
	cur.clear()


func _draw() -> void:
	var vs := _vs()
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.04, 0.06, 0.12))
	draw_string(font, Vector2(0, 70), msg, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 38, Color(1, 1, 1))
	draw_string(font, Vector2(40, 112), sub, HORIZONTAL_ALIGNMENT_CENTER, vs.x - 80, 21, Color(0.75, 0.88, 1))
	if stage == "setup" or stage == "result":
		var pr := Rect2(vs.x * 0.5 - 240, 150, 480, 360)
		draw_rect(pr, Color(0.1, 0.12, 0.18))
		if preview_tex:
			draw_texture_rect(preview_tex, pr, false)
		else:
			draw_string(font, pr.position + Vector2(0, pr.size.y * 0.5), "攝影機畫面載入中…", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 24, Color(0.7, 0.75, 0.8))
		draw_rect(pr, Color(0.5, 0.6, 0.9), false, 3)
		var st := EyeCam.status_text()
		draw_string(font, Vector2(pr.position.x, pr.end.y + 34), st, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 19,
			Color(0.6, 1, 0.7) if EyeCam.face else Color(1, 0.8, 0.5))
		if stage == "setup" and _auto_t > 0.0:
			draw_arc(pr.get_center(), 60, -PI * 0.5, -PI * 0.5 + TAU * minf(1, _auto_t / 3.0), 48, Color(0.4, 1, 0.6), 8)
		if stage == "result":
			for p in eval_pts:
				draw_circle(p, 3, Color(0.3, 1, 0.4, 0.4))
		return
	# 校正點：外圈縮小（收集中）、中心小點
	var r := 34.0
	if collecting:
		r = 12.0 + 22.0 * (1.0 - fmod(t, 1.0))
	var c := Color(1.0, 0.75, 0.2) if stage != "head" else Color(0.5, 0.75, 1.0)
	draw_circle(dot, r, Color(c, 0.35))
	draw_arc(dot, r, 0, TAU, 40, c, 3)
	draw_circle(dot, 6, Color(1, 1, 1))
	draw_circle(dot, 2.5, Color(0.9, 0.1, 0.1))
	if stage == "head":
		var arrow := (dot - vs * 0.5)
		if arrow.length() > 40:
			draw_string(font, dot + Vector2(-80, 64), "轉頭看這裡", HORIZONTAL_ALIGNMENT_CENTER, 160, 22, Color(0.7, 0.85, 1))
	if stage == "eval":
		for p in eval_pts.slice(maxi(0, eval_pts.size() - 20)):
			draw_circle(p, 5, Color(0.3, 1, 0.4, 0.6))
	# 進度
	var total := 1 + _grid_targets().size() + 6 + 5
	var done := 0
	match stage:
		"eyes": done = 1 + ti
		"head": done = 1 + _grid_targets().size() + ti
		"eval": done = 1 + _grid_targets().size() + 6 + ti
	draw_rect(Rect2(vs.x * 0.2, vs.y - 26, vs.x * 0.6, 8), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(vs.x * 0.2, vs.y - 26, vs.x * 0.6 * done / total, 8), Color(0.4, 0.9, 0.6))
