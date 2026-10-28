## 生成 game/stage1.tres（第一关的波次数据）。也可以直接在编辑器里打开 stage1.tres 修改。
## 用法：Godot --headless --path projects/shooter -s res://gen/make_stage.gd
extends SceneTree


func _initialize() -> void:
	var s := StageData.new()
	s.title = "第一关 · 霓虹航道"
	var K := WaveData.Kind
	var F := WaveData.Fire
	s.waves = [
		_w("侦察机编队", K.DRONE, &"SwoopLeft", false, 6, 1.0, 1.0, 2, F.NONE, 0, -1, 0, 2.0),
		_w("侦察机编队", K.DRONE, &"SwoopLeft", true, 6, 1.0, 1.0, 2, F.NONE, 0, -1, 0, 3.0),
		_w("狙击小队", K.SHOOTER, &"ZigZag", false, 4, 2.2, 0.8, 5, F.AIMED, 1.4, -1, 0, 3.0),
		_w("回旋编队", K.DRONE, &"Loop", true, 8, 0.8, 1.2, 2, F.NONE, 0, -1, 0, 2.5),
		_w("炮台", K.TURRET, &"DropIn", true, 1, 1.0, 1.0, 26, F.RING, 1.1, 0.35, 5.0, 3.0),
		_w("扇形射手", K.SHOOTER, &"SwoopLeft", true, 4, 1.6, 0.9, 5, F.FAN, 1.6, -1, 0, 3.0),
		_w("螺旋炮台", K.TURRET, &"DropCenter", false, 1, 1.0, 1.0, 40, F.SPIRAL, 0.08, 0.3, 6.0, 2.5),
		_w("最后的冲锋", K.DRONE, &"Loop", true, 10, 0.6, 1.4, 2, F.AIMED, 2.5, -1, 0, 4.0),
	]
	var err := ResourceSaver.save(s, "res://game/stage1.tres")
	print("stage1.tres 保存结果：", error_string(err))
	quit()


func _w(label: String, kind: int, path: StringName, mirror: bool, count: int, gap: float,
		speed: float, hp: int, fire: int, fire_interval: float, hold_at: float,
		hold_time: float, wait_after: float) -> WaveData:
	var w := WaveData.new()
	w.label = label
	w.kind = kind as WaveData.Kind
	w.path_name = path
	w.mirror = mirror
	w.count = count
	w.gap = gap
	w.speed_scale = speed
	w.hp = hp
	w.fire = fire as WaveData.Fire
	w.fire_interval = fire_interval
	w.hold_at = hold_at
	w.hold_time = hold_time
	w.wait_after = wait_after
	w.drop_chance = 0.5 if w.kind == WaveData.Kind.TURRET else 0.12
	return w
