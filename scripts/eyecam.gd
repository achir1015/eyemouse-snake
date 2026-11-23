extends Node
## 內建網路攝影機眼動追蹤（電腦版）：自動啟動 EyeCam 小程式（127.0.0.1:47971），讀取臉部特徵，
## 用每位使用者的校正（嶺迴歸）換算成畫面視線點，再經 One Euro 濾波；眨眼時維持上一個點。
## 另外提供「頭部轉向」（相對於校正時的正前方），讓鏡頭可以像 Beam 一樣頭眼合併控制。
## 遊戲關閉時會送 quit 並結束小程式；小程式也會偵測遊戲 PID 消失而自動結束。

signal status_changed(text: String)
signal preview(img: Image)
signal sample(feat: PackedFloat32Array)

const PORT := 47971
const CALIB_FILE := "user://calib_webcam.json"

var enabled := false             # 這個平台可以用內建攝影機追蹤
var linked := false
var status := "off"              # off / starting / ok / nocam / noface / error
var face := false
var fps := 0.0
var dist_cm := 0.0
var blink := false
var head_yaw := 0.0              # 度（相對正前方，正＝往左轉頭）
var head_pitch := 0.0            # 度（正＝抬頭）
var feat := PackedFloat32Array() # 最新原始特徵
var calibrated := false
var calib := {}                  # {mean, std, wx, wy, yaw0, pitch0, yaw_sign, pitch_sign, rmse, vs:[w,h]}
var point := Vector2(-1000, -1000)   # 濾波後視線點（遊戲畫面座標）
var raw_point := Vector2(-1000, -1000)
var valid := false
var camera_index := 0
var cameras: Array = []

var _pid := -1
var _tcp: StreamPeerTCP
var _buf := PackedByteArray()
var _retry := 0.0
var _connecting := 0.0
var _last_data := -10.0
var _blink_since := -1.0
var _fx: OneEuro
var _fy: OneEuro
var _want_preview := false
var _started_at := 0.0
var _restarts := 0
var web := false                 # 線上版：瀏覽器內 MediaPipe（web/eyecam_web.js），經 JavaScriptBridge 讀資料
var _web_loaded := false


class OneEuro:
	var min_cutoff := 1.0
	var beta := 0.007
	var d_cutoff := 1.0
	var _x := 0.0
	var _dx := 0.0
	var _started := false

	func _init(mc := 1.0, b := 0.007) -> void:
		min_cutoff = mc
		beta = b

	func _alpha(cutoff: float, dt: float) -> float:
		var tau := 1.0 / (TAU * cutoff)
		return 1.0 / (1.0 + tau / maxf(dt, 1e-4))

	func filt(x: float, dt: float) -> float:
		if not _started:
			_started = true
			_x = x
			return x
		var dx := (x - _x) / maxf(dt, 1e-4)
		_dx = lerpf(_dx, dx, _alpha(d_cutoff, dt))
		var cutoff := min_cutoff + beta * absf(_dx)
		_x = lerpf(_x, x, _alpha(cutoff, dt))
		return _x

	func reset() -> void:
		_started = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	web = OS.has_feature("web")
	enabled = not App.is_mobile()
	_fx = OneEuro.new(0.6, 0.004)
	_fy = OneEuro.new(0.6, 0.004)
	camera_index = int(App.settings.get("camera", 0))
	_load_calib()
	if App.test_mode and not App.args.has("eyecam"):
		return
	if enabled and bool(App.settings.get("webcam", true)):
		# 線上版：已經校正過才自動開相機（第一次要到「眼控校正」才會詢問相機權限）
		if not web or calibrated:
			start()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		stop()


# ---------------------------------------------------------------- 小程式啟動／結束
func helper_cmd() -> Array:
	## 回傳 [執行檔, 參數前綴]；找不到就空陣列
	var base := OS.get_executable_path().get_base_dir()
	var cands := []
	if OS.get_name() == "Windows":
		cands = [base.path_join("eyecam/EyeCam.exe")]
	elif OS.get_name() == "macOS":
		cands = [base.path_join("../Resources/eyecam/EyeCam"), base.path_join("eyecam/EyeCam")]
	for c in cands:
		if FileAccess.file_exists(c):
			return [c, []]
	# 開發中：直接用 Python 跑原始碼
	var src := ProjectSettings.globalize_path("res://eyecam/eyecam.py")
	if FileAccess.file_exists(src):
		var dist := ProjectSettings.globalize_path("res://").path_join("../build/eyecam/EyeCam/EyeCam.exe").simplify_path()
		if FileAccess.file_exists(dist):
			return [dist, []]
		return ["python" if OS.get_name() == "Windows" else "python3", [src]]
	return []


func start() -> void:
	if not enabled:
		return
	_started_at = Time.get_ticks_msec() / 1000.0
	_set_status("starting")
	if web:
		_web_start()
		return
	# 先試著連線（可能已經在跑）；連不上才啟動
	_try_connect()
	await get_tree().create_timer(0.4).timeout
	if linked:
		return
	var hc := helper_cmd()
	if hc.is_empty():
		_set_status("error")
		return
	var args: Array = hc[1].duplicate()
	args.append_array(["--port", str(PORT), "--parent", str(OS.get_process_id()), "--camera", str(camera_index)])
	_pid = OS.create_process(hc[0], args, false)
	if _pid <= 0:
		_set_status("error")


func stop() -> void:
	if web:
		if _web_loaded:
			JavaScriptBridge.eval("window.__ec && window.__ec.stop()", true)
		linked = false
		_set_status("off")
		return
	_send({"cmd": "quit"})
	if _tcp:
		_tcp.poll()
		_tcp.disconnect_from_host()
	_tcp = null
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	linked = false
	_set_status("off")


func set_enabled(on: bool) -> void:
	App.settings.webcam = on
	App.save()
	if on:
		start()
	else:
		stop()


func set_camera(i: int) -> void:
	camera_index = i
	App.settings.camera = i
	App.save()
	_send({"cmd": "camera", "index": i})


func ask_cameras() -> void:
	_send({"cmd": "cameras"})


func set_preview(on: bool) -> void:
	_want_preview = on
	if web and _web_loaded:
		JavaScriptBridge.eval("window.__ec.previewOn = %s" % ("true" if on else "false"), true)
	_send({"cmd": "preview", "on": on})


func _set_status(s: String) -> void:
	if s == status:
		return
	status = s
	status_changed.emit(status_text())


func status_text() -> String:
	match status:
		"off": return "攝影機眼控：關閉"
		"starting": return "攝影機眼控：啟動中…"
		"nocam": return "攝影機眼控：打不開攝影機（請在瀏覽器網址列允許使用相機）" if web else "攝影機眼控：找不到攝影機（請確認沒有其他程式在使用）"
		"error": return "攝影機眼控：無法載入臉部追蹤（請確認網路連線）" if web else "攝影機眼控：無法啟動追蹤程式"
		"noface": return "攝影機眼控：看不到臉，請正對攝影機"
	if not calibrated:
		return "攝影機眼控：已啟動，請先做校正（%d fps）" % int(fps)
	return "攝影機眼控：追蹤中（%d fps，距離約 %d 公分）" % [int(fps), int(dist_cm)]


# ---------------------------------------------------------------- 連線
func _try_connect() -> void:
	_tcp = StreamPeerTCP.new()
	_tcp.set_no_delay(true)
	_tcp.connect_to_host("127.0.0.1", PORT)
	_connecting = 0.0


func _send(obj: Dictionary) -> void:
	if _tcp and _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_tcp.put_data((JSON.stringify(obj) + "\n").to_utf8_buffer())


func _process(delta: float) -> void:
	if web:
		_web_poll()
		return
	if not _tcp:
		return
	_tcp.poll()
	var st := _tcp.get_status()
	if st == StreamPeerTCP.STATUS_CONNECTING:
		_connecting += delta
		if _connecting > 1.0:
			_tcp.disconnect_from_host()
			st = StreamPeerTCP.STATUS_ERROR
	if st == StreamPeerTCP.STATUS_CONNECTED:
		if not linked:
			linked = true
			if _want_preview:
				_send({"cmd": "preview", "on": true})
		var n := _tcp.get_available_bytes()
		if n > 0:
			var r := _tcp.get_data(n)
			if r[0] == OK:
				_buf.append_array(r[1])
				_parse()
	else:
		if linked:
			linked = false
			face = false
		_retry += delta
		if _retry > 1.0:
			_retry = 0.0
			# 小程式意外結束：自動重新啟動（最多 3 次）
			if _pid > 0 and not OS.is_process_running(_pid) and _restarts < 3:
				_restarts += 1
				_pid = -1
				start()
				return
			# 小程式啟動要幾秒（載入模型）；超過 40 秒都連不上就算失敗
			if Time.get_ticks_msec() / 1000.0 - _started_at > 40.0 and _pid > 0 and not OS.is_process_running(_pid):
				_set_status("error")
				_tcp = null
				return
			_try_connect()
	var now := Time.get_ticks_msec() / 1000.0
	valid = linked and calibrated and face and now - _last_data < 0.4


func _parse() -> void:
	while true:
		var i := _buf.find(10)
		if i < 0:
			break
		var line := _buf.slice(0, i).get_string_from_utf8()
		_buf = _buf.slice(i + 1)
		var m = JSON.parse_string(line)
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var ev := str(m.get("ev", ""))
		if ev == "status":
			_set_status(str(m.status))
		elif ev == "preview":
			var img := Image.new()
			if img.load_jpg_from_buffer(Marshalls.base64_to_raw(str(m.jpg))) == OK:
				preview.emit(img)
		elif ev == "cameras":
			cameras = m.list
		elif ev == "":
			_on_data(m)


func _on_data(m: Dictionary) -> void:
	fps = float(m.get("fps", 0))
	var was := face
	face = int(m.get("face", 0)) == 1
	if not face:
		if status in ["ok", "noface"]:
			_set_status("noface")
		return
	if status in ["noface", "starting", "ok"]:
		if status != "ok" or was != face:
			status = "ok"
			status_changed.emit(status_text())
	var now := Time.get_ticks_msec() / 1000.0
	var dt := clampf(now - _last_data, 0.01, 0.2)
	_last_data = now
	dist_cm = float(m.get("dist", 0))
	feat = features(m)
	sample.emit(feat)
	# 眨眼：兩眼 eyeBlink 都高 → 維持上一點（最多 0.5 秒）
	var bs: Array = m.get("bs", [])
	blink = bs.size() >= 10 and float(bs[8]) > 0.55 and float(bs[9]) > 0.55
	var hp: Array = m.hp
	if calibrated:
		head_yaw = (float(hp[0]) - float(calib.yaw0)) * float(calib.yaw_sign)
		head_pitch = (float(hp[1]) - float(calib.pitch0)) * float(calib.pitch_sign)
		if blink:
			if _blink_since < 0:
				_blink_since = now
			if now - _blink_since < 0.5:
				return
		else:
			_blink_since = -1.0
		var p := predict(feat)
		raw_point = p
		var vs := get_viewport().get_visible_rect().size
		var cal_vs: Array = calib.get("vs", [vs.x, vs.y])
		p = p * Vector2(vs.x / float(cal_vs[0]), vs.y / float(cal_vs[1]))
		point = Vector2(_fx.filt(p.x, dt), _fy.filt(p.y, dt))
		point = point.clamp(Vector2(-40, -40), vs + Vector2(40, 40))


# ---------------------------------------------------------------- 特徵與校正
## 原始資料 → 特徵向量（虹膜位置、eyeLook 係數、頭部姿勢、鼻尖，再加二次項讓角落不會被壓縮）
static func features(m: Dictionary) -> PackedFloat32Array:
	var ir: Array = m.ir
	var bs: Array = m.bs
	var hp: Array = m.hp
	var nose: Array = m.nose
	# 影像左眼 h 以外角→內角（影像向右）為正；影像右眼相反 → 合成「往影像右邊」
	var ix := (float(ir[0]) - float(ir[2])) * 0.5
	var iv := (float(ir[1]) + float(ir[3])) * 0.5
	# eyeLook：受試者左眼 Out＋右眼 In ＝看受試者的左邊
	var bx := (float(bs[0]) + float(bs[5]) - float(bs[1]) - float(bs[4])) * 0.5
	var by := (float(bs[2]) + float(bs[6]) - float(bs[3]) - float(bs[7])) * 0.5
	var yaw := float(hp[0]) / 30.0
	var pitch := float(hp[1]) / 30.0
	var roll := float(hp[2]) / 30.0
	var nx := float(nose[0])
	var ny := float(nose[1])
	return PackedFloat32Array([ix, iv, bx, by, yaw, pitch, roll, nx, ny,
		ix * ix, iv * iv, ix * iv, bx * bx, by * by, bx * by, yaw * yaw, pitch * pitch, ix * yaw, iv * pitch])


func predict(f: PackedFloat32Array) -> Vector2:
	if not calibrated:
		return Vector2(-1000, -1000)
	var mean: Array = calib.mean
	var sd: Array = calib.std
	var wx: Array = calib.wx
	var wy: Array = calib.wy
	var x := float(wx[0])
	var y := float(wy[0])
	for k in f.size():
		var z := (f[k] - float(mean[k])) / float(sd[k])
		x += z * float(wx[k + 1])
		y += z * float(wy[k + 1])
	return Vector2(x, y)


## 嶺迴歸：samples = [[feat, target(Vector2)]]；以保留樣本挑選正則化強度，回傳 {model, rmse}
static func fit(samples: Array, vs: Vector2) -> Dictionary:
	var n := samples.size()
	if n < 20:
		return {}
	var d: int = (samples[0][0] as PackedFloat32Array).size()
	var mean := []
	var sd := []
	for k in d:
		var s := 0.0
		for smp in samples:
			s += smp[0][k]
		mean.append(s / n)
	for k in d:
		var s := 0.0
		for smp in samples:
			s += pow(smp[0][k] - mean[k], 2)
		sd.append(maxf(sqrt(s / n), 1e-5))
	var Z := []
	for smp in samples:
		var row := [1.0]
		for k in d:
			row.append((smp[0][k] - mean[k]) / sd[k])
		Z.append(row)
	var best_l := 1.0
	var best_e := INF
	for lam in [0.01, 0.1, 1.0, 3.0, 10.0, 30.0]:
		var tr := []
		var te := []
		for i in n:
			(te if i % 5 == 2 else tr).append(i)
		var w := _ridge(Z, samples, tr, lam)
		var e := _rmse(Z, samples, te, w[0], w[1])
		if e < best_e:
			best_e = e
			best_l = lam
	var all := range(n)
	var w2 := _ridge(Z, samples, all, best_l)
	return {"mean": mean, "std": sd, "wx": w2[0], "wy": w2[1], "rmse": best_e, "lambda": best_l, "vs": [vs.x, vs.y]}


static func _ridge(Z: Array, samples: Array, idx: Array, lam: float) -> Array:
	var p: int = Z[0].size()
	var A := []
	for i in p:
		var r := []
		r.resize(p)
		r.fill(0.0)
		A.append(r)
	var bx := []
	bx.resize(p)
	bx.fill(0.0)
	var by := bx.duplicate()
	for i in idx:
		var z: Array = Z[i]
		var t: Vector2 = samples[i][1]
		for a in p:
			var za: float = z[a]
			bx[a] += za * t.x
			by[a] += za * t.y
			for b in range(a, p):
				A[a][b] += za * z[b]
	for a in p:
		for b in range(a):
			A[a][b] = A[b][a]
		if a > 0:
			A[a][a] += lam * idx.size() * 0.01
	return [_solve(A, bx), _solve(A, by)]


## 高斯消去法（部分選主元）
static func _solve(A0: Array, b0: Array) -> Array:
	var n := b0.size()
	var A := []
	for r in A0:
		A.append((r as Array).duplicate())
	var b := b0.duplicate()
	for c in n:
		var piv := c
		for r in range(c + 1, n):
			if absf(A[r][c]) > absf(A[piv][c]):
				piv = r
		if piv != c:
			var t = A[c]
			A[c] = A[piv]
			A[piv] = t
			var tb = b[c]
			b[c] = b[piv]
			b[piv] = tb
		var dv: float = A[c][c]
		if absf(dv) < 1e-12:
			dv = 1e-12
		for r in range(c + 1, n):
			var f: float = A[r][c] / dv
			if f == 0.0:
				continue
			for k in range(c, n):
				A[r][k] -= f * A[c][k]
			b[r] -= f * b[c]
	var x := []
	x.resize(n)
	x.fill(0.0)
	for r in range(n - 1, -1, -1):
		var s: float = b[r]
		for k in range(r + 1, n):
			s -= A[r][k] * x[k]
		x[r] = s / (A[r][r] if absf(A[r][r]) > 1e-12 else 1e-12)
	return x


static func _rmse(Z: Array, samples: Array, idx: Array, wx: Array, wy: Array) -> float:
	var s := 0.0
	for i in idx:
		var z: Array = Z[i]
		var px := 0.0
		var py := 0.0
		for a in z.size():
			px += z[a] * wx[a]
			py += z[a] * wy[a]
		s += (Vector2(px, py) - (samples[i][1] as Vector2)).length_squared()
	return sqrt(s / maxf(1.0, idx.size()))


func apply_calib(model: Dictionary, head: Dictionary) -> void:
	calib = model.duplicate(true)
	calib.merge(head, true)
	calibrated = true
	_fx.reset()
	_fy.reset()
	if not App.test_mode:
		var f := FileAccess.open(CALIB_FILE, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(calib))


func clear_calib() -> void:
	calibrated = false
	calib = {}
	if FileAccess.file_exists(CALIB_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CALIB_FILE))


func _load_calib() -> void:
	var f := FileAccess.open(CALIB_FILE, FileAccess.READ)
	if not f:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) == TYPE_DICTIONARY and d.has("wx") and (d.wx as Array).size() == 20:
		calib = d
		calibrated = true


# ---------------------------------------------------------------- 線上版（瀏覽器）
func _web_start() -> void:
	if not _web_loaded:
		var f := FileAccess.open("res://web/eyecam_web.js", FileAccess.READ)
		if f == null:
			_set_status("error")
			return
		JavaScriptBridge.eval(f.get_as_text(), true)
		_web_loaded = true
	JavaScriptBridge.eval("window.__ec.previewOn = %s; window.__ec.start()" % ("true" if _want_preview else "false"), true)


func _web_poll() -> void:
	if not _web_loaded:
		return
	var st := str(JavaScriptBridge.eval("window.__ec.status", true))
	linked = st == "ok"
	if st in ["starting", "nocam", "error"] and st != status:
		_set_status(st)
	elif st == "off" and status != "off":
		_set_status("off")
	var line := str(JavaScriptBridge.eval("window.__ec.pop()", true))
	if line != "" and line != "<null>":
		var m = JSON.parse_string(line)
		if typeof(m) == TYPE_DICTIONARY:
			_on_data(m)
	if _want_preview:
		var b64 := str(JavaScriptBridge.eval("window.__ec.popPreview()", true))
		if b64 != "" and b64 != "<null>":
			var img := Image.new()
			if img.load_jpg_from_buffer(Marshalls.base64_to_raw(b64)) == OK:
				preview.emit(img)
	var now := Time.get_ticks_msec() / 1000.0
	valid = linked and calibrated and face and now - _last_data < 0.4
