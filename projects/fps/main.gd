## 游戏流程：开始 / 暂停（鼠标锁定）、刷怪、击杀统计、玩家死亡后重生、网页按钮。
## 本节点 process_mode = ALWAYS（暂停时也要检查鼠标状态），玩法相关的子节点设为 PAUSABLE。
extends Node3D

var kills := 0
var _running := false
var _had_capture := false
var _dev_mode := false
var _flash_frame := -1

@onready var level: NavigationRegion3D = $Level
@onready var player: Player = $Player
@onready var spawner: Node3D = $Enemies
@onready var debug_draw: DebugDraw = $DebugDraw
@onready var hud: Control = $UI/HUD
@onready var overlay: Control = $UI/Overlay
@onready var weapons: WeaponManager = $Player/Head/Camera3D/Weapons


func _ready() -> void:
	level.baked.connect(_on_level_baked)
	player.died.connect(_on_player_died)
	spawner.enemy_killed.connect(func() -> void:
		kills += 1
		hud.set_kills(kills))
	hud.setup(player, weapons)
	hud.set_kills(0)
	overlay.clicked.connect(_on_overlay_clicked)
	Tuning.touch_mode_changed.connect(_on_touch_mode)
	Tuning.action_triggered.connect(_on_action)
	# 开发截图（--shot=...）时直接开始，不弹提示层
	if Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--shot=")):
		_set_running(true)
		_dev_args()
	elif Tuning.touch_mode:
		_set_running(true)                              # 手机上重新开始：直接进入游戏
	else:
		_set_running(false)
		overlay.show_start()


func _on_level_baked() -> void:
	debug_draw.show_navigation_mesh(level.navigation_mesh)
	spawner.start()


#region capture
## Web 上的鼠标锁定（Pointer Lock）有两条规则：
##   1. 必须在用户点击 / 按键的处理过程中请求，否则浏览器直接拒绝；
##   2. 用户按 Esc 时浏览器自己解除锁定，游戏往往收不到这个 Esc。
## 所以：点击提示层时请求锁定；之后每帧检查锁定状态，"锁过又丢了"就暂停。
## 手机上没有鼠标锁定：网页一打开触屏按键，游戏就直接开始，视角改由右半屏滑动控制。
func _on_touch_mode(on: bool) -> void:
	if on and not _running:
		_set_running(true)


func _on_overlay_clicked() -> void:
	capture_mouse()
	_set_running(true)


## 请求锁定鼠标。Web 版的输入事件是在浏览器的点击回调里同步处理的，所以这里仍算"用户手势"。
## Godot 自带的实现在锁定失败时（比如窗口没有焦点）会留下一条未捕获的 Promise 错误，
## 所以 Web 上自己调用 requestPointerLock() 并把失败吞掉；锁定成功后 Input.mouse_mode 会读到 CAPTURED。
func capture_mouse() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""(function () {
			var c = document.getElementById('canvas');
			var p = c && c.requestPointerLock ? c.requestPointerLock() : null;
			if (p && p.catch) p.catch(function () {});
		})()""")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if Tuning.touch_mode:
		hud.set_hint("")                                 # 手机上用虚拟按键，不需要锁定鼠标
	elif captured:
		_had_capture = true
		hud.set_hint("")
	elif _running and _had_capture:
		_had_capture = false
		_set_running(false)
		overlay.show_paused()
	elif _running and not _dev_mode:
		# 锁定没成功（比如无头浏览器、或者刚按过 Esc 浏览器还在冷却）：游戏照常运行，提示再点一次
		hud.set_hint("鼠标未锁定：点一下画面即可用鼠标转视角")
	if Engine.get_process_frames() == _flash_frame:
		weapons.models[weapons.current].flash()
	Tuning.stat("FPS", Engine.get_frames_per_second())
	Tuning.stat("敌人", spawner.alive().size())
	Tuning.stat("击杀", kills)
	# 渲染统计：每帧的绘制调用次数和三角形数，是判断 Web 版性能的两个主要指标
	Tuning.stat("绘制调用", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	Tuning.stat("三角形", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE      # 桌面版：Esc 释放鼠标（下一帧会进入暂停）
	elif _running and event is InputEventMouseButton and event.pressed and not Tuning.touch_mode \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		capture_mouse()                                  # 运行中但没锁定：这次点击用来重新锁定，不开火
		weapons.block_trigger()


func _set_running(on: bool) -> void:
	_running = on
	get_tree().paused = not on
	overlay.visible = not on
	if on:
		weapons.block_trigger()
#endregion


func _on_player_died() -> void:
	hud.show_message("你被击倒了", 2.5)
	await get_tree().create_timer(2.5, false).timeout
	player.respawn()


func _on_action(action: String) -> void:
	match action:
		"restart":
			get_tree().paused = false
			get_tree().reload_current_scene()
		"spawn_enemy":
			spawner.spawn_one(true)


## 开发截图用的命令行参数（放在 -- 后面，配合 --shot 使用）：
##   --view=x,y,z,偏航,俯仰   把玩家放到指定位置和朝向
##   --enemy=x,z             在指定位置放一个敌人（可以写多个）
##   --flash=帧号            在这一帧显示枪口火光
func _dev_args() -> void:
	_dev_mode = true
	var enemies: Array[Vector3] = []
	for arg in OS.get_cmdline_user_args():
		var v := arg.get_slice("=", 1).split_floats(",")
		if arg.begins_with("--view="):
			player.global_position = Vector3(v[0], v[1], v[2])
			player.rotation.y = deg_to_rad(v[3])
			player.head.rotation.x = deg_to_rad(v[4])
		elif arg.begins_with("--enemy="):
			enemies.append(Vector3(v[0], 0.0, v[1]))
		elif arg.begins_with("--flash="):
			_flash_frame = int(v[0])
	if enemies.is_empty():
		return
	await level.baked
	while not spawner.is_started():
		await get_tree().physics_frame
	for p in enemies:
		var e: Enemy = spawner.spawn_one()
		e.global_position = p
