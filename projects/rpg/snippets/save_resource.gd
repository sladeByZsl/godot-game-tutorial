## 另一种存档写法：ResourceSaver + 自定义 Resource。对照 autoload/game.gd 里的 JSON 写法。
extends Node

const PATH := "user://save.tres"


#region resource_save
func save_with_resource(pos: Vector2) -> void:
	var data := SaveData.new()
	data.player_position = pos
	data.hp = Game.hp
	data.coins = Game.coins
	data.flags = Game.flags.duplicate()
	var err := ResourceSaver.save(data, PATH)
	if err != OK:
		push_error("存档失败：%s" % error_string(err))


func load_with_resource() -> SaveData:
	if not ResourceLoader.exists(PATH):
		return null
	# CACHE_MODE_IGNORE：不要拿缓存里的旧对象，每次都从文件重新读
	return ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
#endregion


#region user_dir
func where_is_user_dir() -> void:
	# Windows: %APPDATA%\Godot\app_userdata\<项目名>
	# macOS:   ~/Library/Application Support/Godot/app_userdata/<项目名>
	# Linux:   ~/.local/share/godot/app_userdata/<项目名>
	# Web:     浏览器 IndexedDB 里的 /userfs（清除网站数据就没了）
	print(OS.get_user_data_dir())
	print(ProjectSettings.globalize_path("user://save.json"))
#endregion
