## 全局状态（自动加载单例，名字叫 Game）。
## 血量、金币、背包、任务标记都放在这里：切换场景、重新加载场景时它们不会丢，
## 任何脚本都能直接写 Game.hp、Game.add_coins(5)。
extends Node

#region signals
signal hp_changed(hp: int, max_hp: int)
signal coins_changed(coins: int)
signal flags_changed
signal toast(text: String)                     ## HUD 底部弹出一行提示
signal dialogue_requested(dialogue: Dialogue)  ## NPC 请求播放对话，由对话框接收
signal loaded                                  ## 读档完成，场景里的宝箱等据此刷新
#endregion

const SAVE_PATH := "user://save.json"
const QUEST_TARGET := 3
## 物品数据库：存档里只记 id，读档时用 id 找回共享的 ItemData
const ITEMS := {
	&"potion": preload("res://items/potion.tres"),
	&"apple": preload("res://items/apple.tres"),
	&"gel": preload("res://items/gel.tres"),
	&"key": preload("res://items/key.tres"),
}

#region state
var max_hp := 6          ## 半颗心为 1，6 = 三颗心
var hp := 6
var coins := 0
var inventory := Inventory.new()
var flags: Dictionary = {}           ## 任务标记，如 {"quest_active": true}
var slimes_killed := 0
var opened_chests: Array[String] = []
#endregion

#region debug_flags
@export var show_ranges := false     ## 显示敌人的感知 / 丢失半径
@export var show_states := false     ## 显示状态机当前状态
@export var show_boxes := false      ## 显示碰撞形状、Hitbox、Hurtbox
#endregion


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Tuning.bind(self, "debug", ["show_ranges", "show_states", "show_boxes"])


## 重新开始：autoload 不会随 reload_current_scene() 重置，要手动清。
func reset() -> void:
	max_hp = 6
	hp = max_hp
	coins = 0
	inventory.clear()
	flags.clear()
	slimes_killed = 0
	opened_chests.clear()
	_emit_all()


func change_hp(delta: int) -> void:
	hp = clampi(hp + delta, 0, max_hp)
	hp_changed.emit(hp, max_hp)


func add_coins(n: int) -> void:
	coins += n
	coins_changed.emit(coins)


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func set_flag(flag: String) -> void:
	if flag != "":
		flags[flag] = true
		flags_changed.emit()


#region quest
func on_enemy_killed(kind: StringName) -> void:
	if kind != &"slime" or not has_flag("quest_active") or has_flag("slimes_cleared"):
		return
	slimes_killed += 1
	if slimes_killed >= QUEST_TARGET:
		set_flag("slimes_cleared")
		toast.emit("史莱姆清理完毕，回去找村长吧")
	else:
		toast.emit("史莱姆 %d / %d" % [slimes_killed, QUEST_TARGET])
	flags_changed.emit()


## 对话文本里的 {left} {coins} 等占位符
func format_text(text: String) -> String:
	return text.format({"left": maxi(0, QUEST_TARGET - slimes_killed), "coins": coins, "target": QUEST_TARGET})
#endregion


#region save
## enemies 是场上每只敌人的 {"kind", "x", "y", "hp"}，由主场景收集后传进来。
func save_game(player_pos: Vector2, enemies: Array = []) -> bool:
	var data := {
		"version": 1,
		"player": {"x": player_pos.x, "y": player_pos.y, "hp": hp, "max_hp": max_hp},  # Vector2 不能直接进 JSON
		"enemies": enemies,
		"coins": coins,
		"inventory": inventory.to_save(),
		"flags": flags,
		"slimes_killed": slimes_killed,
		"opened_chests": opened_chests,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("存档失败：%s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if OS.has_feature("web"):
		JavaScriptBridge.force_fs_sync()   # Web 上 user:// 在 IndexedDB 里，立刻同步一次
	return true
#endregion


#region load
## 读档成功返回 {"x":..,"y":..} 形式的玩家数据，另外 "enemies" 里是存档时场上的敌人；
## 没有存档或格式不对返回空字典。
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != 1:
		push_warning("存档格式不对，忽略")
		return {}
	var p: Dictionary = data["player"]
	max_hp = int(p["max_hp"])          # JSON 里的数字读回来都是 float，要转回 int
	hp = int(p["hp"])
	coins = int(data["coins"])
	inventory.from_save(data["inventory"], ITEMS)
	flags = data["flags"]
	slimes_killed = int(data["slimes_killed"])
	opened_chests.assign(data["opened_chests"])
	_emit_all()
	loaded.emit()
	p["enemies"] = data.get("enemies", [])   # 老存档没有这一项
	return p
#endregion


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _emit_all() -> void:
	hp_changed.emit(hp, max_hp)
	coins_changed.emit(coins)
	inventory.changed.emit()
	flags_changed.emit()
