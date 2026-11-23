extends Node
## 主程式：選單 → 遊戲。所有選單按鈕都能用眼睛停留選取。
## 主選單背後是一條小柯自動示範的 3D 蛇（量子領域）。

var ui: CanvasLayer
var screen: Control
var game: Game
var bg_game: Game
var font: Font
var status_label: Label
var tut: Control
var last_world := "quantum"


func _ready() -> void:
	font = load("res://assets/fonts/ui_font.tres")
	RenderingServer.set_default_clear_color(Color(0.02, 0.03, 0.08))
	last_world = str(App.settings.world)
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	get_viewport().size_changed.connect(func(): if screen and screen.has_meta("rebuild"): (screen.get_meta("rebuild") as Callable).call())
	if bool(App.settings.fullscreen):
		App.set_fullscreen(true)
	if App.test_mode:
		_run_test()
		return
	show_title()
	if not bool(App.settings.tutorial_done):
		await get_tree().create_timer(0.8).timeout
		_menu_tutorial()
	else:
		Snd.say("title_hello")
	Updater.checked.connect(_on_update_checked)
	Updater.check()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F11:
		App.set_fullscreen(not bool(App.settings.fullscreen))
		App.save()


# ---------------------------------------------------------------- 共用
func _clear(with_bg := true) -> Control:
	if screen:
		screen.queue_free()
	if tut:
		tut.queue_free()
		tut = null
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := App.safe_margins(get_viewport().get_visible_rect().size)
	screen.offset_left = m.x
	screen.offset_top = m.y
	screen.offset_right = -m.z
	screen.offset_bottom = -m.w
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(screen)
	if with_bg:
		_ensure_bg()
		var shade := ColorRect.new()
		shade.color = Color(0.01, 0.02, 0.06, 0.45)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.offset_left = -m.x
		shade.offset_top = -m.y
		shade.offset_right = m.z
		shade.offset_bottom = m.w
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(shade)
	return screen


## 主選單背景：3D 量子領域裡小柯自動示範的蛇
func _ensure_bg() -> void:
	if bg_game or game:
		return
	bg_game = Game.new()
	bg_game.quiet = true
	add_child(bg_game)
	bg_game.setup("quantum")


func _free_bg() -> void:
	if bg_game:
		bg_game.queue_free()
		bg_game = null


func _vs() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var m := App.safe_margins(vp)
	return vp - Vector2(m.x + m.z, m.y + m.w)


func _title(text: String, sub := "") -> void:
	var vs := _vs()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 8)
	l.position = Vector2(0, 18)
	l.size = Vector2(vs.x, 56)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(l)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.add_theme_font_size_override("font_size", 20)
		s.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
		s.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		s.add_theme_constant_override("outline_size", 6)
		s.position = Vector2(20, 74)
		s.size = Vector2(vs.x - 40, 30)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		screen.add_child(s)


func _btn(text: String, r: Rect2, col: Color, cb: Callable, sub := "", fs := 24) -> GazeButton:
	var b := GazeButton.make(screen, text, r, col, cb)
	b.sub = sub
	b.font_size = fs
	return b


func _grid(items: Array, top: float, cols: int, h: float, w_max := 300.0, gap := 14.0) -> Array:
	var vs := _vs()
	var w := minf(w_max, (vs.x - 60 - gap * (cols - 1)) / cols)
	var total_w := w * cols + gap * (cols - 1)
	var x0 := (vs.x - total_w) * 0.5
	var out := []
	for i in items.size():
		var it: Array = items[i]
		var r := Rect2(x0 + (i % cols) * (w + gap), top + (i / cols) * (h + gap), w, h)
		out.append(_btn(it[0], r, it[1], it[2], it[3] if it.size() > 3 else "", it[4] if it.size() > 4 else 24))
	return out


func _back(cb := Callable(self, "show_title")) -> void:
	_btn("◀ 返回", Rect2(16, 16, 150, 64), Color(0.35, 0.38, 0.45), cb)


func _label(text: String, r: Rect2, size := 20, col := Color(0.85, 0.92, 1.0), center := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.position = r.position
	l.size = r.size
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(l)
	return l


# ---------------------------------------------------------------- 標題
func show_title() -> void:
	_stop_game()
	_clear()
	screen.set_meta("rebuild", Callable(self, "show_title"))
	var vs := _vs()
	var icon := TextureRect.new()
	icon.texture = load("res://icon.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(vs.x * 0.5 - 300, 16)
	icon.size = Vector2(100, 100)
	screen.add_child(icon)
	var l := _label(App.APP_NAME, Rect2(vs.x * 0.5 - 186, 20, 560, 62), 50, Color.WHITE, false)
	l.add_theme_constant_override("outline_size", 10)
	_label("教・學・養・心安　用眼睛玩、邊玩邊學　v" + App.APP_VERSION, Rect2(vs.x * 0.5 - 184, 82, 600, 30), 19, Color(0.75, 0.9, 1), false)
	var lv := App.pet_level()
	var items := [
		["開始遊戲", Color(0.15, 0.55, 0.35), show_worlds, "九個世界，選一個出發", 30],
		["語音教學", Color(0.45, 0.3, 0.65), _menu_tutorial, "小柯一步一步教你"],
		["知識卡", Color(0.6, 0.45, 0.1), show_facts, "宇宙、黑洞、病菌、害蟲、恐龍"],
		["我的小蛇", Color(0.2, 0.5, 0.45), show_pet, "Lv.%d %s" % [lv + 1, App.PET_SKINS[lv]]],
		["眼控校正", Color(0.4, 0.3, 0.75), show_calib, "攝影機看眼睛，約 1 分鐘"],
		["設定", Color(0.3, 0.35, 0.45), show_settings, "模式、休息提醒、音量"],
		["最高紀錄", Color(0.45, 0.4, 0.2), show_scores, ""],
		["檢查更新", Color(0.25, 0.4, 0.5), show_update, ""],
		["關於", Color(0.3, 0.3, 0.38), show_about, ""],
		["離開", Color(0.55, 0.22, 0.22), _quit, ""],
	]
	if OS.has_feature("web"):
		items.pop_back()
	var btns := _grid(items, 136, 4, 92, 290, 12)
	for b in btns:
		b.set_meta("menu", b.text)
	status_label = _label("", Rect2(20, vs.y - 34, vs.x - 40, 26), 17, Color(0.75, 0.85, 0.95))
	status_label.text = Gaze.status_text() + "　｜　" + App.CREDIT
	if Updater.has_update:
		_btn("有新版 %s，按這裡更新" % Updater.latest, Rect2(vs.x - 380, vs.y - 100, 360, 56), Color(0.8, 0.45, 0.1), show_update)
	if EyeCam.enabled and bool(App.settings.webcam) and not EyeCam.calibrated:
		_btn("第一次使用：先做攝影機眼控校正", Rect2(20, vs.y - 100, 400, 56), Color(0.45, 0.3, 0.8), show_calib)
	var lab := status_label
	var upd := func(_t := ""):
		if is_instance_valid(lab):
			lab.text = Gaze.status_text() + "　｜　" + App.CREDIT
	EyeCam.status_changed.connect(upd)
	lab.tree_exiting.connect(func(): if EyeCam.status_changed.is_connected(upd): EyeCam.status_changed.disconnect(upd))


func _quit() -> void:
	App.save()
	Gaze.shutdown()
	EyeCam.stop()
	get_tree().quit()


func _menu_btn(name: String) -> Rect2:
	if screen == null:
		return Rect2()
	for c in screen.get_children():
		if c is GazeButton and c.text == name:
			return c.get_global_rect()
	return Rect2()


# ---------------------------------------------------------------- 選世界
func show_worlds() -> void:
	_clear()
	screen.set_meta("rebuild", Callable(self, "show_worlds"))
	_title("選擇世界", "看著世界就出發；下面可以調整模式、速度和瞄準輔助")
	_back()
	var items := []
	for id in Arena.ORDER:
		var info: Dictionary = Arena.INFO[id]
		var wid: String = id
		items.append([info.name, info.color, func(): start_game(wid), "%s　最高 %d" % [info.desc, App.best(id)], 28])
	var btns := _grid(items, 108, 3, 84, 380, 10)
	for b in btns:
		b.set_meta("menu", b.text)
		b.selected = Arena.INFO[last_world].name == b.text
	var s := App.settings
	var sp := ["慢速", "普通", "快速"]
	var row := [
		["模式：" + ("放鬆（不會失敗）" if s.mode == "relax" else "挑戰（三顆愛心）"), Color(0.25, 0.5, 0.6), func(): _setv("mode", "challenge" if s.mode == "relax" else "relax", show_worlds); Snd.say("mode_" + str(App.settings.mode), true), "放鬆模式最安心"],
		["速度：" + sp[int(s.speed)], Color(0.2, 0.45, 0.7), func(): _setv("speed", (int(s.speed) + 1) % 3, show_worlds), "按一下切換"],
		["瞄準輔助：" + ["關", "低", "高"][int(s.assist)], Color(0.2, 0.45, 0.7), func(): _setv("assist", (int(s.assist) + 1) % 3, show_worlds), "看著食物附近就幫你轉過去"],
		["專注加速：" + ("開" if s.focus_boost else "關"), Color(0.6, 0.4, 0.15), func(): _setv("focus_boost", not s.focus_boost, show_worlds), "視線穩定時游得更快"],
	]
	_grid(row, 108 + 3 * 94 + 14, 4, 76, 290, 10)


# ---------------------------------------------------------------- 知識卡（學）、我的小蛇（養）
func show_facts(cat := "space", sel := "") -> void:
	_clear()
	screen.set_meta("rebuild", Callable(self, "show_facts").bind(cat, sel))
	var seen: Array = App.progress.get("facts", [])
	_title("知識卡", "看著卡片，小柯就會念給你聽（已聽過 %d / %d）" % [seen.size(), Lines.FACTS.size()])
	_back()
	var vs := _vs()
	var cats := [["space", "宇宙"], ["hole", "黑洞"], ["germ", "病菌預防"], ["pest", "害蟲防範"], ["dino", "恐龍"]]
	var tabs := []
	for c in cats:
		var cid: String = c[0]
		tabs.append([c[1], Color(0.6, 0.45, 0.1) if cid == cat else Color(0.25, 0.3, 0.4), func(): show_facts(cid)])
	_grid(tabs, 100, 5, 58, 200, 10)
	var items := []
	for id in Lines.facts_of(cat):
		var f: Array = Lines.FACTS[id]
		var known := seen.has(id)
		var fid: String = id
		var col := Color(0.2, 0.42, 0.55) if known else Color(0.28, 0.33, 0.42)
		if fid == sel:
			col = Color(0.65, 0.48, 0.12)
		items.append([str(f[1]), col, func(): _read_fact(cat, fid), "✓ 已聽過" if known else "看著聽聽看", 22])
	var btns := _grid(items, 172, 4, 66, 290, 8)
	for b in btns:
		b.selected = false
	# 選到的知識：大字卡片
	if sel != "" and Lines.FACTS.has(sel):
		var f2: Array = Lines.FACTS[sel]
		var rows := ceili(items.size() / 4.0)
		var top := 172.0 + rows * 74.0 + 6.0
		var box := ColorRect.new()
		box.color = Color(0.03, 0.08, 0.16, 0.92)
		box.position = Vector2(40, top)
		box.size = Vector2(vs.x - 80, maxf(120.0, vs.y - top - 20))
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(box)
		_label("【%s】" % f2[1], Rect2(60, top + 10, vs.x - 120, 40), 30, Color(1.0, 0.85, 0.35), false)
		var t := _label(str(f2[2]), Rect2(60, top + 56, vs.x - 120, box.size.y - 66), 24, Color(0.95, 0.97, 1.0), false)
		t.vertical_alignment = VERTICAL_ALIGNMENT_TOP


func _read_fact(cat: String, id: String) -> void:
	var seen: Array = App.progress.get("facts", [])
	if not seen.has(id):
		seen.append(id)
		App.progress["facts"] = seen
		App.save()
	show_facts(cat, id)
	Snd.say(id, true)


func show_pet() -> void:
	_clear()
	_title("我的小蛇", "每吃一個食物，小蛇就長大一點；升級會換上新的花紋")
	_back()
	var vs := _vs()
	var lv := App.pet_level()
	var nxt := App.pet_next()
	_label("Lv.%d　%s" % [lv + 1, App.PET_SKINS[lv]], Rect2(0, 120, vs.x, 60), 44, Color(1.0, 0.85, 0.35))
	_label("累積吃了 %d 個食物%s" % [App.pet_total(), ("，再吃 %d 個升級" % (nxt - App.pet_total())) if nxt > 0 else "，已經是最高等級！"],
		Rect2(0, 186, vs.x, 36), 24)
	var items := []
	for i in App.PET_SKINS.size():
		items.append([App.PET_SKINS[i] if i <= lv else "Lv.%d 解鎖" % (i + 1), Color(0.2, 0.5, 0.45) if i <= lv else Color(0.25, 0.27, 0.3), func(): pass, "需要 %d 個" % App.PET_STEPS[i], 22])
	_grid(items, 250, 5, 76, 230, 10)
	_label("小蛇的長度、花紋會帶進每一個世界。累了就休息，小蛇會一直在這裡等你。", Rect2(40, vs.y - 80, vs.x - 80, 60), 20, Color(0.8, 0.9, 1.0))


func _setv(k: String, v, back := Callable()) -> void:
	App.settings[k] = v
	App.save()
	Snd.refresh_music_volume()
	if back.is_valid():
		back.call()
	else:
		show_settings()


# ---------------------------------------------------------------- 攝影機眼控校正
func show_calib() -> void:
	_stop_game()
	_free_bg()
	_clear(false)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(bg)
	if not EyeCam.enabled:
		_title("攝影機眼控校正", "這個版本不支援內建攝影機眼控（手機、平板請用觸控或系統的眼動追蹤）")
		_back()
		return
	if not bool(App.settings.webcam):
		App.settings.webcam = true
		App.save()
	var c := Calib.new()
	ui.add_child(c)
	c.finished.connect(_on_calib_done)


func _on_calib_done(ok: bool) -> void:
	show_title()
	if ok:
		Snd.say("calib_ready")


# ---------------------------------------------------------------- 設定
func show_settings() -> void:
	_clear()
	screen.set_meta("rebuild", Callable(self, "show_settings"))
	_title("設定")
	_back()
	var s := App.settings
	var items := [
		["操作：" + ("看哪裡就往哪裡" if s.control == "eye" else "只用鍵盤"), Color(0.2, 0.45, 0.7), func(): _setv("control", "keys" if s.control == "eye" else "eye"), "眼睛、滑鼠、手指都算「看」"],
		["速度：" + ["慢速", "普通", "快速"][int(s.speed)], Color(0.2, 0.45, 0.7), func(): _setv("speed", (int(s.speed) + 1) % 3), ""],
		["轉彎靈敏度 %.1f" % float(s.turn), Color(0.2, 0.45, 0.7), func(): _setv("turn", 0.6 if float(s.turn) >= 1.4 else float(s.turn) + 0.2), "轉太快就調小"],
		["瞄準輔助：" + ["關", "低", "高"][int(s.assist)], Color(0.2, 0.45, 0.7), func(): _setv("assist", (int(s.assist) + 1) % 3), "小柯幫忙對準蘋果"],
		["專注加速：" + ("開" if s.focus_boost else "關"), Color(0.6, 0.4, 0.15), func(): _setv("focus_boost", not s.focus_boost), "視線穩定時游得更快"],
		["模式：" + ("放鬆" if s.mode == "relax" else "挑戰"), Color(0.25, 0.5, 0.6), func(): _setv("mode", "challenge" if s.mode == "relax" else "relax"), "放鬆＝不會失敗、不扣愛心"],
		["休息提醒：" + ("每 %d 分鐘" % int(s.rest_min) if int(s.rest_min) > 0 else "關"), Color(0.25, 0.5, 0.6), func(): _setv("rest_min", [10, 15, 20, 30, 0][([10, 15, 20, 30, 0].find(int(s.rest_min)) + 1) % 5]), "護眼：閉眼深呼吸 20 秒"],
		["鏡頭：" + Game.CAM_NAMES[int(s.cam)], Color(0.25, 0.4, 0.55), func(): _setv("cam", (int(s.cam) + 1) % Game.CAM_NAMES.size()), "遊戲中按 C 或「鏡頭」鍵"],
		["撞邊界扣愛心：" + ("開" if s.wall_hurt else "關"), Color(0.6, 0.4, 0.15), func(): _setv("wall_hurt", not s.wall_hurt), "挑戰模式才有作用"],
		["看不到眼睛就暫停：" + ("開" if s.auto_pause else "關"), Color(0.4, 0.3, 0.75), func(): _setv("auto_pause", not s.auto_pause), "眨眼不算，閉眼約 2 秒"],
		["停留時間 %.1f 秒" % float(s.dwell), Color(0.3, 0.4, 0.5), func(): _setv("dwell", 0.5 if float(s.dwell) >= 1.6 else float(s.dwell) + 0.2), "看著按鈕多久算選取"],
		["音量 %d%%" % int(float(s.volume) * 100), Color(0.3, 0.4, 0.5), func(): _setv("volume", 0.2 if float(s.volume) >= 1.0 else float(s.volume) + 0.2), ""],
		["音樂音量 %d%%" % int(float(s.music_volume) * 100), Color(0.3, 0.4, 0.5), func(): _setv("music_volume", 0.0 if float(s.music_volume) >= 0.9 else float(s.music_volume) + 0.15), ""],
		["背景音樂：" + ("開" if s.music_on else "關"), Color(0.35, 0.3, 0.55), func(): _setv("music_on", not s.music_on), "%d 首原創配樂" % Snd.tracks.size()],
		["小柯語音：" + ("開" if s.voice_on else "關"), Color(0.35, 0.3, 0.55), func(): _setv("voice_on", not s.voice_on), "台灣華語提示"],
		["視線圈：" + ("顯示" if s.look_ring else "隱藏"), Color(0.35, 0.3, 0.55), func(): _setv("look_ring", not s.look_ring), "畫出你看的位置"],
		["畫質：" + ("高" if s.quality == "high" else "省電"), Color(0.3, 0.4, 0.5), func(): _setv("quality", "low" if s.quality == "high" else "high"), "電腦較慢請選省電"],
		["全螢幕：" + ("開" if s.fullscreen else "關"), Color(0.3, 0.4, 0.5), func(): App.set_fullscreen(not s.fullscreen); App.save(); show_settings(), "F11 也可以切換"],
		["自動開眼動鼠：" + ("開" if s.auto_eyemouse else "關"), Color(0.3, 0.4, 0.5), func(): _setv("auto_eyemouse", not s.auto_eyemouse), "有 Tobii 眼動儀才需要"],
	]
	if EyeCam.enabled:
		items.push_front(["重新校正攝影機眼控", Color(0.4, 0.3, 0.75), show_calib, "換座位、燈光變了就重做"])
		items.push_front(["換攝影機（第 %d 台）" % (EyeCam.camera_index + 1), Color(0.4, 0.3, 0.75), func(): EyeCam.set_camera((EyeCam.camera_index + 1) % 3); show_settings(), "筆電內建＋外接攝影機"])
		items.push_front(["攝影機眼控：" + ("開" if s.webcam else "關"), Color(0.4, 0.3, 0.75), func(): EyeCam.set_enabled(not s.webcam); show_settings(), "不用買眼動儀，用網路攝影機看眼睛"])
	_grid(items, 92, 4, 60, 300, 7)
	var vs := _vs()
	_label(Gaze.status_text(), Rect2(20, vs.y - 38, vs.x - 40, 26), 18)


# ---------------------------------------------------------------- 最高紀錄、更新、關於
func show_scores() -> void:
	_clear()
	_title("最高紀錄")
	_back()
	var vs := _vs()
	var y := 110.0
	for id in Arena.ORDER:
		var p: Dictionary = App.progress.get(id, {})
		_label("%s　　最高 %d 分　　最多吃 %d 個　　玩了 %d 次" % [Arena.name_of(id), int(p.get("best", 0)), int(p.get("apples", 0)), int(p.get("plays", 0))],
			Rect2(40, y, vs.x - 80, 40), 24)
		y += 52


func show_update() -> void:
	_clear()
	_title("檢查更新", "目前版本 " + App.APP_VERSION + "（" + Updater.platform_name() + "）")
	_back()
	var vs := _vs()
	var l := _label("正在檢查…", Rect2(40, 150, vs.x - 80, 160), 24)
	var on_checked := func(has: bool, latest: String, notes: String):
		if not is_instance_valid(l):
			return
		if has:
			l.text = "有新版 %s！\n%s" % [latest, notes]
			_btn("立即更新", Rect2(vs.x * 0.5 - 160, 340, 320, 90), Color(0.8, 0.45, 0.1), func(): l.text = "準備更新…"; Updater.apply_update(), "", 30)
		else:
			l.text = "已經是最新版 %s 了。" % App.APP_VERSION
	Updater.checked.connect(on_checked, CONNECT_ONE_SHOT)
	Updater.failed.connect(func(m): if is_instance_valid(l): l.text = m, CONNECT_ONE_SHOT)
	Updater.progress.connect(func(r, t): if is_instance_valid(l): l.text = "%s（%d%%）" % [t, int(r * 100)])
	Updater.check()


func _on_update_checked(has: bool, _latest: String, _notes: String) -> void:
	if has and screen and screen.has_meta("rebuild") and (screen.get_meta("rebuild") as Callable).get_method() == "show_title":
		show_title()
		Snd.say("update_available")


func show_about() -> void:
	_clear()
	_title("關於", App.APP_NAME + "　v" + App.APP_VERSION)
	_back()
	var vs := _vs()
	var l := _label("\n".join([
		"給喜歡遊戲、也給手不方便的朋友：只要看著想去的地方，蛇就會在立體空間裡游過去。眼動儀、網路攝影機、滑鼠、手指都可以玩。",
		"玩法參考 NeuroSnake（Tobii 眼動＋腦波控制的 3D 貪吃蛇）的概念，以 Godot 全新實作：吃蘋果變長、咬到尾巴少一顆愛心、藍金寶石方塊恢復愛心、專注力讓蛇變快。",
		"為漸凍人與行動不便的朋友設計：教（小柯語音教學）、學（宇宙、黑洞、病菌、害蟲、恐龍知識卡）、養（護眼休息提醒、會長大的小蛇）、心安（放鬆模式不會失敗、呼吸引導）。",
		"九個世界：量子領域、太陽系、黑洞、微觀花園、恐龍時代、海底、荷花池、水溝、細菌世界。模型與材質來自 Poly Haven（CC0）；行星與銀河貼圖來自 Solar System Scope（CC BY 4.0）。",
		"攝影機眼控：MediaPipe 臉部特徵＋虹膜 → 每人校正 → One Euro 濾波，影像只在本機處理，不會上傳。",
		"配樂與音效皆為原創合成；語音為台灣華語。字型：Noto Sans TC（SIL OFL）。",
		"眼動：" + Gaze.status_text(),
		"",
		App.CREDIT,
	]), Rect2(60, 110, vs.x - 120, vs.y - 140), 20, Color(0.9, 0.95, 1.0), false)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP


# ---------------------------------------------------------------- 遊戲
func start_game(w: String, tutorial := false) -> void:
	last_world = w
	App.settings.world = w
	App.save()
	_clear(false)
	screen.visible = false
	_stop_game()
	_free_bg()
	game = Game.new()
	add_child(game)
	game.setup(w)
	game.hud.menu_requested.connect(func(): show_title(); Snd.say("title_back"))
	game.hud.retry_requested.connect(func(): start_game(w))
	game.hud.tutorial_requested.connect(func(): _game_tutorial())
	if not tutorial:
		Snd.say("start_" + w)
	else:
		await get_tree().create_timer(0.6).timeout
		_game_tutorial()


func _stop_game() -> void:
	if game:
		game.quit_game()
		game.queue_free()
		game = null
	Snd.stop_music()
	Snd.stop_loops()


# ---------------------------------------------------------------- 語音教學
func _menu_tutorial() -> void:
	show_title()
	tut = load("res://scripts/tutorial.gd").new()
	ui.add_child(tut)
	tut.done.connect(func():
		App.settings.tutorial_done = true
		App.save()
		tut = null)
	tut.start([
		{"id": "tut_m1"},
		{"id": "tut_m2", "target": func(): return _menu_btn("開始遊戲")},
		{"id": "tut_m3", "target": func(): return _menu_btn("開始遊戲")},
		{"id": "tut_m4", "target": func(): return _menu_btn("眼控校正")},
		{"id": "tut_m5", "target": func(): return _menu_btn("知識卡")},
		{"id": "tut_m6", "target": func(): return _menu_btn("語音教學")},
		{"id": "tut_m7", "action": func(): _start_tutorial_game()},
	])


func _start_tutorial_game() -> void:
	await get_tree().create_timer(3.5).timeout
	if tut:
		tut.queue_free()
		tut = null
	start_game("quantum", true)


func _game_tutorial() -> void:
	if game == null:
		return
	var g := game
	var t: Control = load("res://scripts/tutorial.gd").new()
	g.hud.root.add_child(t)
	t.shots = true
	var r := func(n: String) -> Rect2: return g.hud.target_rect(n)
	var apple_pt := func() -> Vector2:
		var a := g.nearest_apple()
		if not a.is_empty():
			var sp = g.screen_pos((a.node as Node3D).global_position)
			if sp != null:
				return sp
		return _vs() * Vector2(0.5, 0.47)
	t.start([
		{"id": "tut_g1", "target": r.bind("snake"), "action": func(): g.paused = false},
		{"id": "tut_g2", "gaze": func(): return _vs() * Vector2(0.5 + 0.3 * sin(Time.get_ticks_msec() / 900.0), 0.47 + 0.2 * cos(Time.get_ticks_msec() / 1300.0))},
		{"id": "tut_g3", "target": r.bind("apple"), "gaze": apple_pt},
		{"id": "tut_g4", "target": r.bind("hearts"), "gaze": apple_pt},
		{"id": "tut_g5", "gaze": apple_pt, "action": func(): if g.gem == null: g._spawn_gem()},
		{"id": "tut_g6", "target": r.bind("focus"), "gaze": apple_pt},
		{"id": "tut_g7", "target": r.bind("radar"), "gaze": apple_pt},
		{"id": "tut_g8", "target": r.bind("score"), "gaze": apple_pt},
		{"id": "tut_g9", "gaze": apple_pt},
		{"id": "tut_g10", "target": r.bind("cam")},
		{"id": "tut_g11"},
	])
	if App.args.has("quit-after-tutorial"):
		t.done.connect(func(): get_tree().quit())


# ---------------------------------------------------------------- 測試
func _run_test() -> void:
	var scr := App.arg("screen", "selftest")
	await get_tree().process_frame
	if App.args.has("auto-update"):
		show_update()
		var r: Array = await Updater.checked
		print("UPDATE current=%s latest=%s has=%s" % [Updater.current_version(), r[1], r[0]])
		if r[0]:
			Updater.progress.connect(func(x, t): print("UPDATE ", t))
			Updater.failed.connect(func(m): print("UPDATE FAIL ", m); get_tree().quit(1))
			Updater.apply_update()
		return
	match scr:
		"title": show_title()
		"worlds": show_worlds()
		"settings": show_settings()
		"about": show_about()
		"scores": show_scores()
		"facts": show_facts(App.arg("cat", "germ"), App.arg("sel", ""))
		"pet": show_pet()
		"calib": show_calib()
		"tutorial":
			start_game(App.arg("world", "quantum"), true)
		"game":
			start_game(App.arg("world", "quantum"))
			await get_tree().process_frame
			if App.args.has("ap"):
				game.ap = true
			if App.args.has("cam"):
				game.cam_mode = int(App.arg("cam"))
			if App.args.has("secs"):
				var secs := float(App.arg("secs"))
				var t0 := Time.get_ticks_msec()
				var last := 0.0
				var frames := 0
				while (Time.get_ticks_msec() - t0) / 1000.0 < secs and not game.done:
					await get_tree().process_frame
					frames += 1
					var el := (Time.get_ticks_msec() - t0) / 1000.0
					if el - last > 10.0:
						last = el
						print("T=%d pos=%s r=%.1f score=%d apples=%d lives=%d len=%.1f focus=%.2f fps=%d" % [int(el), game.snake.head_pos.round(), game.snake.head_pos.length(),
							game.score, game.eaten, game.lives, game.snake.length, game.focus, Engine.get_frames_per_second()])
				print("GAME_RESULT score=%d apples=%d lives=%d bites=%d rings=%d len=%.1f done=%s avg_fps=%.0f" % [game.score, game.eaten, game.lives, game.bites,
					game.rings_passed, game.snake.length, game.done, frames / maxf(0.1, (Time.get_ticks_msec() - t0) / 1000.0)])
		"selftest":
			await _selftest()
			return
	if App.args.has("shot"):
		var wait := float(App.arg("wait", "1.5"))
		await get_tree().create_timer(wait).timeout
		get_viewport().get_texture().get_image().save_png(App.arg("shot"))
		print("SHOT ", App.arg("shot"))
		get_tree().quit()
	elif scr == "game" and App.args.has("secs"):
		get_tree().quit()


func _selftest() -> void:
	var out := []
	var ok_all := true
	var check := func(name: String, ok: bool, detail := "") -> void:
		out.append("%s %s %s" % ["OK " if ok else "FAIL", name, detail])
	for id in Arena.ORDER:
		var a := Arena.new()
		add_child(a)
		a.setup(id)
		check.call("世界 " + Arena.name_of(id), a.R > 10.0 and a.rings.size() > 0, "R=%.0f 障礙 %d 光環 %d 危險 %d 知識點 %d" % [a.R, a.obstacles.size(), a.rings.size(), a.hazards.size(), a.spots.size()])
		a.queue_free()
	check.call("蘋果模型", ResourceLoader.exists("res://assets/models/apple/apple.gltf"))
	check.call("背景音樂", Snd.tracks.size() >= 6, "%d 首" % Snd.tracks.size())
	var missing := 0
	for id in Lines.all():
		if not ResourceLoader.exists("res://assets/voice/%s.ogg" % id):
			missing += 1
	check.call("小柯語音", missing == 0, "%d 句，缺 %d" % [Lines.all().size(), missing])
	for line in out:
		if line.begins_with("FAIL"):
			ok_all = false
		print(line)
	print("SELFTEST ", "PASS" if ok_all else "FAIL")
	if App.args.has("out"):
		var f := FileAccess.open(App.arg("out"), FileAccess.WRITE)
		f.store_string("\n".join(out) + "\nSELFTEST " + ("PASS" if ok_all else "FAIL") + "\n")
	get_tree().quit()
