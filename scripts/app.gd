extends Node
## 全域：版本、設定、最高分、測試參數。

const APP_VERSION := "1.0.0"
const APP_NAME := "眼動鼠貪吃蛇"
const SHORT_NAME := "眼動貪吃蛇"
const CREDIT := "系統開發：吳玉柱 先生 與 Claude AI Opus 5.5"

const DEFAULTS := {
	"volume": 0.8,
	"music_volume": 0.4,
	"voice_on": true,           # 小柯語音（提示、加油）
	"music_on": true,
	"music_track": 0,
	"control": "eye",           # eye 看哪裡蛇就往哪裡（滑鼠、眼動儀、攝影機）、keys 鍵盤方向鍵
	"dwell": 0.8,               # 選單停留秒數
	"auto_eyemouse": false,     # 有 Tobii 才需要；預設用內建攝影機眼控
	"webcam": true,             # 內建網路攝影機眼控（EyeCam）
	"camera": 0,
	"look_ring": true,          # 顯示視線圈
	"tutorial_done": false,
	"world": "quantum",         # quantum 量子領域、space 星雲宇宙、garden 微觀花園
	"speed": 1,                 # 0 慢速、1 普通、2 快速
	"assist": 1,                # 小柯瞄準輔助 0 關、1 低、2 高
	"focus_boost": true,        # 專注加速：視線穩定時蛇會變快
	"wall_hurt": false,         # 撞到邊界扣生命（預設只會轉彎）
	"auto_pause": true,         # 看不到眼睛時自動暫停
	"turn": 1.0,                # 轉彎靈敏度
	"mode": "relax",            # relax 放鬆模式（不會失敗，心安）、challenge 挑戰模式（三顆愛心）
	"rest_min": 15,             # 每玩幾分鐘提醒眼睛休息（0＝不提醒）
	"cam": 0,                   # 鏡頭視角
	"fullscreen": false,
	"quality": "high",          # high / low
}

var settings := DEFAULTS.duplicate(true)
var progress := {}              # world -> {"best": 分數, "apples": 最多蘋果, "plays": 次數}
var test_mode := false
var args := {}                  # --key=value 測試參數
var demo := false               # 教學／自動示範中


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	test_mode = args.has("test")
	_load()
	if test_mode:
		settings = DEFAULTS.duplicate(true)
		settings.tutorial_done = true
		settings.auto_eyemouse = false
		if args.has("keys"):
			settings.control = "keys"
	if OS.has_feature("web") or is_mobile():
		settings.auto_eyemouse = false
	if is_mobile():
		settings.quality = "low"
		settings.control = "eye"   # 手機沒有鍵盤：手指按住想去的方向
		var df := FileAccess.open("user://diag.txt", FileAccess.WRITE)   # 手機除錯用：系統名稱與標籤
		if df:
			df.store_string("%s mobile=%s ios=%s control=%s safe=%s win=%s" % [OS.get_name(), OS.has_feature("mobile"), OS.has_feature("ios"),
				settings.control, DisplayServer.get_display_safe_area(), DisplayServer.window_get_size()])


## 手機／平板（Godot 4.7 的 iOS 不一定有 "mobile" 標籤，所以也看系統名稱）
static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("ios") or OS.has_feature("android") or OS.get_name() in ["iOS", "Android"]


## 手機瀏海／圓角的安全邊界（視窗座標，左上右下）；電腦與網頁都是 0
func safe_margins(vp: Vector2) -> Vector4:
	if not is_mobile():
		return Vector4.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if win.x < 10 or safe.size.x < 10:
		return Vector4.ZERO
	var k := vp / win
	return Vector4(safe.position.x * k.x, safe.position.y * k.y, (win.x - safe.end.x) * k.x, (win.y - safe.end.y) * k.y)


func arg(key: String, def := "") -> String:
	return str(args.get(key, def))


func _load() -> void:
	var f := FileAccess.open("user://settings.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			for k in d:
				if settings.has(k):
					settings[k] = d[k]
	f = FileAccess.open("user://progress.json", FileAccess.READ)
	if f:
		var p = JSON.parse_string(f.get_as_text())
		if typeof(p) == TYPE_DICTIONARY:
			progress = p


func save() -> void:
	if test_mode:
		return
	var f := FileAccess.open("user://settings.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "\t"))
	f = FileAccess.open("user://progress.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(progress, "\t"))


func record(world: String, score: int, apples: int) -> bool:
	var old: Dictionary = progress.get(world, {"best": 0, "apples": 0, "plays": 0})
	var is_best := score > int(old.best)
	progress[world] = {"best": maxi(int(old.best), score), "apples": maxi(int(old.apples), apples), "plays": int(old.get("plays", 0)) + 1}
	save()
	return is_best


## 我的小蛇（養）：累積吃的東西越多，等級越高，蛇會長大、換上新花紋
const PET_STEPS := [0, 10, 30, 60, 100, 160, 240, 350, 500, 700]
const PET_SKINS := ["翠綠青蛇", "金紋錦蛇", "海藍水蛇", "紫晶彩虹蛇", "赤焰紅蛇", "雪白玉蛇", "黑曜金環蛇", "琉璃寶石蛇", "星空銀河蛇", "黃金神龍蛇"]


func pet_total() -> int:
	return int(progress.get("pet", 0))


func pet_level() -> int:
	var t := pet_total()
	var lv := 0
	for i in PET_STEPS.size():
		if t >= PET_STEPS[i]:
			lv = i
	return lv


func pet_next() -> int:
	var lv := pet_level()
	return PET_STEPS[lv + 1] if lv + 1 < PET_STEPS.size() else -1


signal pet_level_up(level: int)


func feed_pet(n: int) -> void:
	if test_mode or demo:
		return
	var before := pet_level()
	progress["pet"] = pet_total() + n
	if pet_level() > before:
		pet_level_up.emit(pet_level())
	save()


func best(world: String) -> int:
	return int(progress.get(world, {}).get("best", 0))


func set_fullscreen(on: bool) -> void:
	settings.fullscreen = on
	if OS.has_feature("web") or is_mobile():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_MAXIMIZED)
