## 游戏流程（自动加载，名字叫 Flow）：标题 → 游戏 → 暂停 → 结算，以及最高分存档。
## 自动加载的节点不会随场景切换被释放，所以"现在处于哪个状态""历史最高分"放在这里。
extends Node

signal state_changed(state: State)

enum State { TITLE, PLAYING, PAUSED, RESULT }

const TITLE_SCENE := "res://ui/title.tscn"
const GAME_SCENE := "res://game/game.tscn"
const SAVE_PATH := "user://shooter_save.cfg"
const MAX_SCORES := 5

var state := State.TITLE
var start_at_boss := false
var start_phase := 0          # 调试/截图用：Boss 从第几阶段开始
var autoplay := false         # 截图/演示用：飞船自动驾驶
var high_scores: Array[Dictionary] = []    # [{"score": int, "wave": int, "date": String}]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时也要能响应"继续"
	load_save()
	Tuning.action_triggered.connect(_on_action)
	# 开发用命令行参数（放在 -- 后面）：--autoplay 自动驾驶，--boss 直接打 Boss，--phase=2
	var args := OS.get_cmdline_user_args()
	autoplay = "--autoplay" in args
	for a in args:
		if a.begins_with("--phase="):
			start_phase = int(a.substr(8))
	if autoplay or "--boss" in args:
		start_game.call_deferred("--boss" in args)


#region change_scene
func start_game(at_boss := false) -> void:
	start_at_boss = at_boss
	get_tree().paused = false
	Audio.set_muffled(false)
	_set_state(State.PLAYING)
	# change_scene_to_file 会在本帧结束时释放旧场景、加载新场景，
	# 旧场景里的节点（包括它们的 Tuning 绑定、信号连接）都会跟着消失。
	get_tree().change_scene_to_file(GAME_SCENE)


func go_to_title() -> void:
	get_tree().paused = false
	Audio.set_muffled(false)
	_set_state(State.TITLE)
	get_tree().change_scene_to_file(TITLE_SCENE)
#endregion


#region pause
func set_paused(paused: bool) -> void:
	if state != State.PLAYING and state != State.PAUSED:
		return
	# get_tree().paused 会停掉所有 process_mode 为 INHERIT/PAUSABLE 的节点：
	# _process、_physics_process、物理、动画、计时器（create_timer 的 process_always=false 时）都停。
	# 暂停菜单把自己设成 WHEN_PAUSED，Flow 和 Audio 是 ALWAYS，所以它们还能动。
	get_tree().paused = paused
	Audio.set_muffled(paused)
	_set_state(State.PAUSED if paused else State.PLAYING)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(state == State.PLAYING)
		get_viewport().set_input_as_handled()
#endregion


## 一局结束：记录成绩，返回名次（0 起；没进榜返回 -1）。
func finish_game(score: int, wave: int) -> int:
	_set_state(State.RESULT)
	var entry := {"score": score, "wave": wave, "date": Time.get_date_string_from_system()}
	high_scores.append(entry)
	high_scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	var rank := high_scores.find(entry)
	high_scores.resize(mini(high_scores.size(), MAX_SCORES))
	save()
	return rank if rank < MAX_SCORES else -1


func best_score() -> int:
	return high_scores[0]["score"] if not high_scores.is_empty() else 0


#region save
## 存档用 ConfigFile（INI 格式的文本）。user:// 在桌面上是系统的应用数据目录，
## 在 Web 上是浏览器的 IndexedDB——刷新页面后还在，换浏览器或清除网站数据就没了。
func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "list", high_scores)
	cfg.set_value("audio", "music_volume", Audio.music_volume)
	cfg.set_value("audio", "sfx_volume", Audio.sfx_volume)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("存档失败：%s" % error_string(err))


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return      # 第一次运行，还没有存档
	high_scores.assign(cfg.get_value("scores", "list", []))
	Audio.music_volume = cfg.get_value("audio", "music_volume", Audio.music_volume)
	Audio.sfx_volume = cfg.get_value("audio", "sfx_volume", Audio.sfx_volume)
#endregion


func _set_state(s: State) -> void:
	state = s
	state_changed.emit(s)


func _on_action(action: String) -> void:
	match action:
		"restart":
			start_game(false)
		"boss":
			start_game(true)
		"pause":
			set_paused(state == State.PLAYING)
