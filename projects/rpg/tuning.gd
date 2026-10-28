## 教程网页 <-> 游戏 的参数桥（自动加载单例，名字叫 Tuning）。
##
## - 网页上拖动滑块时，用 postMessage 把新值发进游戏；游戏脚本调用
##   Tuning.bind(self, "player", ["speed", "gravity"]) 后，对应属性会被自动改掉。
## - 游戏可以用 Tuning.stat("score", 10) 把实时数据报给网页显示。
## - 在编辑器里运行时，只会应用 params.json 里写了 "value" 的参数
##   （从网页"下载当前参数的工程"时会写进去），其余保持脚本里的 @export 默认值。
extends Node

signal changed(key: String, value: Variant)
signal action_triggered(action_name: String)
signal touch_look(relative: Vector2)      ## 网页触屏"转视角"区域的滑动量（像素），FPS 用
signal touch_mode_changed(on: bool)

## 网页上显示了触屏虚拟按键时为 true（手机上玩）。需要鼠标锁定之类的游戏据此换一套做法。
var touch_mode := false

const PARAMS_PATH := "res://params.json"

var defs: Dictionary = {}    # 参数名 -> 定义（来自 params.json）
var values: Dictionary = {}  # 参数名 -> 被覆盖后的值

var _bindings: Array = []    # 每项: [WeakRef, 参数名, 属性名]
var _stats: Dictionary = {}
var _stats_dirty := false
var _stats_timer := 0.0
var _js_callback: JavaScriptObject  # 必须保存引用，否则回调会被回收
var _shot_path := ""
var _shot_frame := 120


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_defs()
	_parse_cmdline()
	if OS.has_feature("web"):
		_setup_web()


## 把参数 "prefix.属性名" 绑定到 obj 的同名属性上。
#region bind
func bind(obj: Object, prefix: String, props: Array) -> void:
	for prop: String in props:
		var key := "%s.%s" % [prefix, prop]
		_bindings.append([weakref(obj), key, prop])
		if values.has(key):
			obj.set(prop, values[key])
		elif OS.is_debug_build() and defs.has(key) and defs[key].has("default"):
			var expected: Variant = _coerce(defs[key], defs[key]["default"])
			if str(expected) != str(obj.get(prop)):
				push_warning("Tuning: %s 在 params.json 的 default=%s，但脚本里是 %s" % [key, expected, obj.get(prop)])
#endregion


func get_value(key: String, fallback: Variant = null) -> Variant:
	if values.has(key):
		return values[key]
	if defs.has(key) and defs[key].has("default"):
		return _coerce(defs[key], defs[key]["default"])
	return fallback


func set_value(key: String, value: Variant) -> void:
	if defs.has(key):
		value = _coerce(defs[key], value)
	values[key] = value
	var alive: Array = []
	for b: Array in _bindings:
		var obj: Object = b[0].get_ref()
		if obj == null:
			continue
		alive.append(b)
		if b[1] == key:
			obj.set(b[2], value)
	_bindings = alive
	changed.emit(key, value)


## 把一条实时数据报告给网页（网页上的"实时数据"面板会显示）。
func stat(stat_name: String, value: Variant) -> void:
	if _stats.get(stat_name) != value:
		_stats[stat_name] = value
		_stats_dirty = true


func _process(delta: float) -> void:
	if _stats_dirty and OS.has_feature("web"):
		_stats_timer -= delta
		if _stats_timer <= 0.0:
			_stats_timer = 0.12
			_stats_dirty = false
			_post({"type": "stats", "stats": _stats})
	if _shot_path != "" and Engine.get_process_frames() >= _shot_frame:
		var path := _shot_path
		_shot_path = ""
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)
		print("Tuning: 截图已保存 ", path)
		get_tree().quit()


#region 内部实现
func _load_defs() -> void:
	if not FileAccess.file_exists(PARAMS_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PARAMS_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Tuning: params.json 格式不对")
		return
	for group: Dictionary in data.get("groups", []):
		for p: Dictionary in group.get("params", []):
			defs[p["key"]] = p
			if p.has("value"):
				values[p["key"]] = _coerce(p, p["value"])


func _coerce(def: Dictionary, v: Variant) -> Variant:
	match def.get("type", "float"):
		"int":
			return int(v)
		"bool":
			return bool(v)
		"color":
			return Color.html(str(v))
		"string", "enum":
			return str(v)
		_:
			return float(v)


## 开发用命令行参数（放在 -- 后面）：
##   --set=player.speed=300   覆盖参数
##   --shot=out.png --frame=90  第 90 帧截图后退出
func _parse_cmdline() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--set="):
			var kv := arg.substr(6).split("=", true, 1)
			if kv.size() == 2:
				var raw: Variant = JSON.parse_string(kv[1])
				set_value(kv[0], kv[1] if raw == null else raw)
		elif arg.begins_with("--shot="):
			_shot_path = arg.substr(7)
		elif arg.begins_with("--frame="):
			_shot_frame = int(arg.substr(8))


#endregion


#region web_setup
func _setup_web() -> void:
	var window := JavaScriptBridge.get_interface("window")
	_js_callback = JavaScriptBridge.create_callback(_on_js_message)
	window.addEventListener("message", _js_callback)
	_post({"type": "ready"})
#endregion


#region web_message
func _on_js_message(args: Array) -> void:
	var raw: Variant = args[0].data
	if typeof(raw) != TYPE_STRING:
		return
	var msg: Variant = JSON.parse_string(raw)
	if typeof(msg) != TYPE_DICTIONARY or msg.get("ns") != "godot-tut":
		return
	match msg.get("type"):
		"set":
			set_value(msg["key"], msg["value"])
		"action":
			action_triggered.emit(msg["name"])
		"hello":
			_post({"type": "ready"})
		"input":   # 虚拟按键 / 摇杆：当成真实的输入动作注入，游戏代码不用区分来源
			_set_touch_mode(true)
			var action_name: String = msg["action"]
			if InputMap.has_action(action_name):
				var ev := InputEventAction.new()
				ev.action = action_name
				ev.strength = clampf(float(msg.get("strength", 1.0)), 0.0, 1.0)
				ev.pressed = ev.strength > 0.0
				Input.parse_input_event(ev)
		"look":
			_set_touch_mode(true)
			touch_look.emit(Vector2(float(msg["dx"]), float(msg["dy"])))
		"touch":
			_set_touch_mode(bool(msg["on"]))


func _set_touch_mode(on: bool) -> void:
	if touch_mode != on:
		touch_mode = on
		touch_mode_changed.emit(on)
#endregion


#region web_post
func _post(msg: Dictionary) -> void:
	msg["ns"] = "godot-tut"
	var js_str := JSON.stringify(JSON.stringify(msg))
	JavaScriptBridge.eval("window.parent.postMessage(%s, '*')" % js_str)
#endregion
