class_name Hud
extends CanvasLayer
## 遊戲畫面：左上愛心、右上分數與最高紀錄、左邊橘色專注力、右下 3D 雷達、蘋果方向箭頭、
## 上方暫停／音樂／示範按鈕、彈出文字、暫停選單與結算畫面。

signal menu_requested
signal retry_requested
signal tutorial_requested

var game: Game
var root: Control
var canvas: Control
var font: Font
var pause_btn: GazeButton
var music_btn: GazeButton
var ap_btn: GazeButton
var cam_btn: GazeButton
var rest_btn: GazeButton
var rest_left := 0.0
var _resting := false
var _fact_id := ""
var _fact_t := 0.0
var _fact_hold := 0.0
var panel: Control = null
var _pops: Array = []            # [{text, color, t}]
var _flash := 0.0
var _t := 0.0


func _ready() -> void:
	layer = 3
	font = load("res://assets/fonts/ui_font.tres")
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := App.safe_margins(get_viewport().get_visible_rect().size)
	root.offset_left = m.x
	root.offset_top = m.y
	root.offset_right = -m.z
	root.offset_bottom = -m.w
	add_child(root)
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_hud)
	root.add_child(canvas)
	pause_btn = GazeButton.new("暫停", Color(0.3, 0.35, 0.5))
	pause_btn.picked.connect(toggle_pause)
	root.add_child(pause_btn)
	music_btn = GazeButton.new("音樂", Color(0.35, 0.3, 0.55))
	music_btn.picked.connect(func(): Snd.next_track() if bool(App.settings.music_on) else null)
	root.add_child(music_btn)
	ap_btn = GazeButton.new("小柯示範", Color(0.2, 0.45, 0.4))
	ap_btn.picked.connect(func(): set_ap(not game.ap))
	root.add_child(ap_btn)
	cam_btn = GazeButton.new("鏡頭", Color(0.25, 0.4, 0.55))
	cam_btn.picked.connect(func(): game.next_cam())
	root.add_child(cam_btn)
	rest_btn = GazeButton.new("休息好了，繼續", Color(0.2, 0.5, 0.35))
	rest_btn.picked.connect(func(): game.skip_rest())
	rest_btn.visible = false
	root.add_child(rest_btn)
	App.pet_level_up.connect(func(_lv): popup("小蛇長大了！", Color(1, 0.9, 0.4)); Snd.say("level_up"))
	root.resized.connect(_layout)
	_layout()


func _vs() -> Vector2:
	return root.size if root.size.x > 10 else get_viewport().get_visible_rect().size


func _layout() -> void:
	var vs := _vs()
	pause_btn.size = Vector2(120, 58)
	music_btn.size = Vector2(120, 58)
	ap_btn.size = Vector2(150, 58)
	pause_btn.position = Vector2(vs.x * 0.5 - 60, 10)
	music_btn.position = Vector2(vs.x * 0.5 + 72, 10)
	ap_btn.position = Vector2(vs.x * 0.5 - 222, 10)
	cam_btn.size = Vector2(120, 58)
	cam_btn.position = Vector2(vs.x * 0.5 + 204, 10)
	rest_btn.size = Vector2(300, 76)
	rest_btn.position = Vector2(vs.x * 0.5 - 150, vs.y * 0.68)


func set_ap(on: bool) -> void:
	game.ap = on
	ap_btn.selected = on
	ap_btn.queue_redraw()
	Snd.say("ap_on" if on else "ap_off", true)


## 視線在按鈕上時不轉向（避免看暫停鍵時蛇亂轉）
func gaze_on_ui() -> bool:
	if panel != null:
		return true
	if _resting:
		return true
	for b in [pause_btn, music_btn, ap_btn, cam_btn]:
		if (b as GazeButton).get_global_rect().grow(6).has_point(Gaze.point):
			return true
	return false


func popup(text: String, col: Color) -> void:
	_pops.append({"text": text, "color": col, "t": 0.0})
	if _pops.size() > 4:
		_pops.pop_front()


func show_fact(id: String) -> void:
	_fact_id = id
	_fact_t = 0.0


func fact_showing() -> bool:
	return _fact_id != ""


func show_rest(on: bool) -> void:
	_resting = on
	rest_btn.visible = on


func flash() -> void:
	_flash = 0.6


## 教學聚光框用
func target_rect(name: String) -> Rect2:
	var vs := _vs()
	var o := root.position
	match name:
		"hearts": return Rect2(o + Vector2(12, 10), Vector2(200, 60))
		"score": return Rect2(o + Vector2(vs.x - 290, 8), Vector2(280, 84))
		"focus": return Rect2(o + Vector2(10, vs.y * 0.3 - 10), Vector2(64, vs.y * 0.42 + 50))
		"radar": return Rect2(o + Vector2(vs.x - 200, vs.y - 200), Vector2(190, 190))
		"pause": return pause_btn.get_global_rect()
		"cam": return cam_btn.get_global_rect()
		"ap": return ap_btn.get_global_rect()
		"apple":
			var a := game.nearest_apple()
			if not a.is_empty():
				var sp = game.screen_pos((a.node as Node3D).global_position)
				if sp != null:
					return Rect2(sp - Vector2(50, 50), Vector2(100, 100))
			return Rect2()
		"snake":
			var sp2 = game.screen_pos(game.snake.head_pos)
			if sp2 != null:
				return Rect2(sp2 - Vector2(110, 90), Vector2(220, 180))
	return Rect2()


func _process(dt: float) -> void:
	_t += dt
	_flash = maxf(0.0, _flash - dt)
	for p in _pops:
		p.t += dt
	_pops = _pops.filter(func(p): return p.t < 1.8)
	if _fact_id != "":
		_fact_t += dt
		if Snd.is_speaking():
			_fact_hold = 0.0
		else:
			_fact_hold += dt
		if (_fact_t > 4.0 and _fact_hold > 2.5) or _fact_t > 45.0:
			_fact_id = ""
	canvas.queue_redraw()


# ---------------------------------------------------------------- 畫面
func _heart(c: Vector2, s: float, fill: bool, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var t := TAU * i / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(c + Vector2(x, y) * s / 17.0)
	if fill:
		canvas.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	canvas.draw_polyline(pts, col.lightened(0.3), 3.0, true)


func _draw_hud() -> void:
	if game == null or game.snake == null:
		return
	var vs := _vs()
	var f := font
	# 受傷閃紅
	if _flash > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 0, 0, _flash * 0.35))
	# 愛心（放鬆模式不會扣，顯示「放鬆模式」）
	if game.relax:
		_heart(Vector2(44, 40), 24.0 * (1.0 + 0.05 * sin(_t * 2.0)), true, Color(0.55, 0.8, 1.0))
		canvas.draw_string_outline(font, Vector2(78, 52), "放鬆模式", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color(0, 0, 0, 0.8))
		canvas.draw_string(font, Vector2(78, 52), "放鬆模式", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.7, 0.9, 1.0))
	for i in (0 if game.relax else Game.LIVES_MAX):
		var full := i < game.lives
		var beat := 1.0 + (0.08 * sin(_t * 8.0) if full and game.lives == 1 else 0.0)
		_heart(Vector2(44 + i * 62, 40), 24.0 * beat, full, Color(1.0, 0.32, 0.45) if full else Color(0.55, 0.45, 0.5, 0.6))
	# 分數
	var sc := "分數 %d" % game.score
	_text_r(sc, Vector2(vs.x - 20, 46), 34, Color(1.0, 0.82, 0.3))
	_text_r("最高 %d　蘋果 %d　長度 %.0f 公尺" % [maxi(App.best(game.world_id), game.score), game.eaten, game.snake.length], Vector2(vs.x - 20, 80), 18, Color(0.85, 0.92, 1.0))
	# 專注力（左邊直條）
	var bx := 26.0
	var by := vs.y * 0.3
	var bh := vs.y * 0.42
	canvas.draw_rect(Rect2(bx, by, 22, bh), Color(0.9, 0.9, 0.95, 0.25))
	var fh := bh * game.focus
	canvas.draw_rect(Rect2(bx, by + bh - fh, 22, fh), Color(1.0, 0.6, 0.12).lerp(Color(1, 0.9, 0.3), game.focus))
	canvas.draw_rect(Rect2(bx, by, 22, bh), Color(1, 1, 1, 0.6), false, 2.0)
	_text_c("專注", Vector2(bx + 11, by + bh + 30), 18, Color(1.0, 0.7, 0.25))
	# 雷達：中心＝正前方，外圈＝正後方
	var rc := Vector2(vs.x - 105, vs.y - 105)
	var rr := 85.0
	canvas.draw_circle(rc, rr, Color(0.02, 0.06, 0.12, 0.6))
	canvas.draw_arc(rc, rr, 0, TAU, 48, Color(0.5, 0.85, 1.0, 0.8), 2.0, true)
	canvas.draw_arc(rc, rr * 0.5, 0, TAU, 32, Color(0.5, 0.85, 1.0, 0.35), 1.5, true)
	canvas.draw_line(rc - Vector2(rr, 0), rc + Vector2(rr, 0), Color(0.5, 0.85, 1.0, 0.2))
	canvas.draw_line(rc - Vector2(0, rr), rc + Vector2(0, rr), Color(0.5, 0.85, 1.0, 0.2))
	var sn := game.snake
	var near := game.nearest_apple()
	var kc := {"apple": Color(1.0, 0.25, 0.25), "bacteria": Color(0.3, 1.0, 0.6), "pest": Color(1.0, 0.65, 0.15)}
	for a in game.apples:
		var p := _radar(rc, rr, (a.node as Node3D).position)
		var c: Color = kc.get(str(a.get("kind", "apple")), Color.RED)
		canvas.draw_circle(p, 6.5 if a == near else 4.5, c if a == near else Color(c.r, c.g, c.b, 0.7))
	for h in game.arena.hazards:
		var hp := _radar(rc, rr, (h.node as Node3D).global_position)
		canvas.draw_arc(hp, 6, 0, TAU, 12, Color(0.8, 0.4, 1.0), 2.5)
	if game.gem:
		var gp := _radar(rc, rr, game.gem.position)
		canvas.draw_rect(Rect2(gp - Vector2(6, 6), Vector2(12, 12)), Color(0.3, 0.6, 1.0))
		canvas.draw_rect(Rect2(gp - Vector2(6, 6), Vector2(12, 12)), Color(1, 0.8, 0.3), false, 2.0)
	# 邊界距離：雷達外圈變紅
	var edge := clampf((sn.head_pos.length() - (game.arena.R - 12.0)) / 12.0, 0.0, 1.0)
	if edge > 0.0:
		canvas.draw_arc(rc, rr + 4, 0, TAU, 48, Color(1, 0.35, 0.3, edge), 4.0, true)
	_text_c("雷達", rc + Vector2(0, rr + 2), 15, Color(0.7, 0.9, 1.0))
	# 最近蘋果的方向箭頭（不在畫面上時）
	if not near.is_empty():
		var ap: Vector3 = (near.node as Node3D).global_position
		var sp = game.screen_pos(ap)
		var on_screen: bool = sp != null and Rect2(Vector2(40, 40), vs - Vector2(80, 80)).has_point(sp)
		if not on_screen:
			var d := (ap - sn.head_pos).normalized()
			var dir2 := Vector2(d.dot(sn.right()), -d.dot(sn.up()))
			if dir2.length() < 0.05:
				dir2 = Vector2(0, 1)
			dir2 = dir2.normalized()
			var c := vs * 0.5
			var ext := vs * 0.5 - Vector2(70, 70)
			var tt := minf(ext.x / maxf(absf(dir2.x), 0.001), ext.y / maxf(absf(dir2.y), 0.001))
			var tip := c + dir2 * tt
			var n := Vector2(-dir2.y, dir2.x)
			var pulse := 1.0 + 0.15 * sin(_t * 6.0)
			canvas.draw_colored_polygon(PackedVector2Array([tip + dir2 * 26 * pulse, tip + n * 16 * pulse, tip - n * 16 * pulse]), Color(1.0, 0.3, 0.25, 0.9))
			canvas.draw_circle(tip - dir2 * 14, 9, Color(1.0, 0.3, 0.25, 0.9))
	# 視線圈
	if bool(App.settings.look_ring) and Gaze.valid and panel == null:
		var col := Color(0.75, 0.45, 1.0, 0.85)
		canvas.draw_arc(Gaze.point - root.position, 26, 0, TAU, 32, col, 3.0, true)
		canvas.draw_circle(Gaze.point - root.position, 4, col)
	# 直走區提示（畫面中心的小十字）
	var cc := Vector2(vs.x * 0.5, vs.y * 0.47)
	canvas.draw_arc(cc, minf(vs.x, vs.y) * 0.05, 0, TAU, 32, Color(1, 1, 1, 0.18), 1.5, true)
	# 彈出文字
	for i in _pops.size():
		var p: Dictionary = _pops[i]
		var a := clampf(1.8 - float(p.t), 0.0, 1.0)
		var y := vs.y * 0.3 - float(p.t) * 40.0 - i * 44
		_text_c(p.text, Vector2(vs.x * 0.5, y), 34, Color(p.color.r, p.color.g, p.color.b, a))
	if game.calm > 0.0:
		_text_c("深呼吸⋯放輕鬆⋯", Vector2(vs.x * 0.5, vs.y * 0.62), 30, Color(0.6, 0.8, 1.0, minf(1.0, game.calm)))
	if _fact_id != "" and Lines.FACTS.has(_fact_id):
		var fc: Array = Lines.FACTS[_fact_id]
		var cat: String = {"space": "宇宙知識", "hole": "黑洞知識", "germ": "病菌與預防", "pest": "害蟲與防範", "dino": "恐龍知識"}.get(fc[0], "小知識")
		var w := minf(820.0, vs.x - 260)
		var box := Rect2(vs.x * 0.5 - w * 0.5, 84, w, 150)
		var a := clampf(_fact_t * 3.0, 0.0, 1.0)
		canvas.draw_rect(box, Color(0.03, 0.08, 0.16, 0.86 * a))
		canvas.draw_rect(box, Color(1.0, 0.82, 0.3, 0.9 * a), false, 3.0)
		canvas.draw_string(font, box.position + Vector2(18, 36), "【%s】%s" % [cat, fc[1]], HORIZONTAL_ALIGNMENT_LEFT, w - 36, 26, Color(1.0, 0.85, 0.35, a))
		canvas.draw_multiline_string(font, box.position + Vector2(18, 70), str(fc[2]), HORIZONTAL_ALIGNMENT_LEFT, w - 36, 19, 4, Color(0.92, 0.96, 1.0, a))
	if _resting:
		canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.05, 0.1, 0.8))
		var br := 0.5 + 0.5 * sin(_t * TAU / 8.0)   # 8 秒一次呼吸
		canvas.draw_circle(vs * Vector2(0.5, 0.42), 60.0 + 70.0 * br, Color(0.4, 0.7, 1.0, 0.25))
		canvas.draw_arc(vs * Vector2(0.5, 0.42), 60.0 + 70.0 * br, 0, TAU, 64, Color(0.6, 0.85, 1.0, 0.8), 3.0, true)
		_text_c("吸氣⋯" if cos(_t * TAU / 8.0) < 0.0 else "吐氣⋯", vs * Vector2(0.5, 0.42) + Vector2(0, 12), 34, Color.WHITE)
		_text_c("讓眼睛休息一下　輕輕閉上眼睛　%d 秒" % ceili(rest_left), Vector2(vs.x * 0.5, vs.y * 0.17), 30, Color(0.85, 0.93, 1.0))
		_text_c("（看遠方的東西、眨眨眼，也是很好的休息）", Vector2(vs.x * 0.5, vs.y * 0.17 + 40), 20, Color(0.7, 0.8, 0.9))
	if game.auto_paused:
		canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.45))
		_text_c("看不到眼睛，暫停中", Vector2(vs.x * 0.5, vs.y * 0.45), 40, Color.WHITE)
		_text_c("眼睛回到畫面就會繼續", Vector2(vs.x * 0.5, vs.y * 0.45 + 50), 24, Color(0.8, 0.9, 1))
	if game.ap:
		_text_c("小柯示範中（再按一次「小柯示範」換你玩）", Vector2(vs.x * 0.5, vs.y - 24), 20, Color(0.6, 1.0, 0.9))


func _radar(rc: Vector2, rr: float, world: Vector3) -> Vector2:
	var sn := game.snake
	var d := (world - sn.head_pos)
	if d.length() < 0.01:
		return rc
	d = d.normalized()
	var x := d.dot(sn.right())
	var y := d.dot(sn.up())
	var z := d.dot(sn.fwd())
	var ang := acos(clampf(z, -1.0, 1.0)) / PI      # 0 前方 → 1 後方
	var v := Vector2(x, -y)
	if v.length() < 0.001:
		v = Vector2(0, 1)
	return rc + v.normalized() * ang * rr


func _text_c(s: String, center_base: Vector2, size: int, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string_outline(font, center_base - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, col.a * 0.8))
	canvas.draw_string(font, center_base - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _text_r(s: String, right_base: Vector2, size: int, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string_outline(font, right_base - Vector2(w, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, 0.8))
	canvas.draw_string(font, right_base - Vector2(w, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


# ---------------------------------------------------------------- 暫停、結算
func toggle_pause() -> void:
	if game.done:
		return
	if panel:
		_close_panel()
		game.paused = false
		return
	game.paused = true
	Snd.say("paused")
	_open_panel("暫停", "休息一下，準備好再繼續", [
		["繼續", Color(0.15, 0.55, 0.35), func(): toggle_pause()],
		["重新開始", Color(0.2, 0.45, 0.7), func(): retry_requested.emit()],
		["再聽一次教學", Color(0.45, 0.3, 0.65), func(): _close_panel(); game.paused = false; tutorial_requested.emit()],
		["回主選單", Color(0.55, 0.25, 0.25), func(): menu_requested.emit()],
	])


func show_result(r: Dictionary) -> void:
	var lines := "分數 %d　｜　蘋果 %d 顆　｜　長度 %.0f 公尺　｜　光環 %d 個\n%s最高紀錄 %d" % [r.score, r.apples, r.length, r.rings,
		"新紀錄！　" if r.is_best else "", r.best]
	_open_panel("遊戲結束" if not r.is_best else "新紀錄！", lines, [
		["再玩一次", Color(0.15, 0.55, 0.35), func(): retry_requested.emit()],
		["回主選單", Color(0.3, 0.35, 0.5), func(): menu_requested.emit()],
	])


func _open_panel(title: String, sub: String, items: Array) -> void:
	_close_panel()
	var vs := _vs()
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.1, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 52)
	t.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	t.add_theme_color_override("font_outline_color", Color.BLACK)
	t.add_theme_constant_override("outline_size", 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(0, vs.y * 0.16)
	t.size = Vector2(vs.x, 70)
	panel.add_child(t)
	var s := Label.new()
	s.text = sub
	s.add_theme_font_size_override("font_size", 24)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.position = Vector2(20, vs.y * 0.16 + 80)
	s.size = Vector2(vs.x - 40, 80)
	s.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel.add_child(s)
	var w := 280.0
	var h := 84.0
	var cols := 2 if items.size() > 2 else items.size()
	var x0 := (vs.x - (w * cols + 16 * (cols - 1))) * 0.5
	for i in items.size():
		var it: Array = items[i]
		var r := Rect2(x0 + (i % cols) * (w + 16), vs.y * 0.45 + (i / cols) * (h + 16), w, h)
		var b := GazeButton.make(panel, it[0], r, it[1], it[2])
		b.font_size = 28
		b.set_meta("menu", it[0])


func _close_panel() -> void:
	if panel:
		panel.queue_free()
		panel = null
