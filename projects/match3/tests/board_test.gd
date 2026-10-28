## Board 逻辑层的无界面测试：不需要场景、不需要窗口，直接 new 一个 Board 来跑。
## 运行：Godot --headless --path projects/match3 -s res://tests/board_test.gd
extends SceneTree

var _fails := 0


func _initialize() -> void:
	_test_scan_and_merge()
	_test_collapse()
	_test_initial_boards()
	_test_random_play(1000)
	_test_determinism()
	print("BOARD TEST %s（失败 %d 项）" % ["通过" if _fails == 0 else "失败", _fails])
	quit(1 if _fails else 0)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", msg)


## 从字符串摆一个棋盘，"." 表示空格，数字是颜色。
func _board_from(rows: Array[String], kinds := 6) -> Board:
	var b := Board.new(rows[0].length(), rows.size(), kinds, 1)
	for y in rows.size():
		for x in rows[y].length():
			var ch := rows[y][x]
			b.cells[b.idx(Vector2i(x, y))] = Board.EMPTY if ch == "." else int(ch)
	return b


#region test_scan
func _test_scan_and_merge() -> void:
	var b := _board_from([
		"11123",
		"45163",
		"23145",
		"54321",
	])
	var groups := b.find_matches()
	_check(groups.size() == 1, "L 形应合并成 1 组，实际 %d 组" % groups.size())
	if groups.size() == 1:
		var g: Dictionary = groups[0]
		_check(g.cells.size() == 5, "L 形 5 格（拐点只算一次），实际 %d" % g.cells.size())
		_check(g.corner == Vector2i(2, 0), "拐点应是 (2,0)，实际 %s" % g.corner)
		_check(b.classify(g) == Board.Special.BOMB, "L 形应生成范围炸弹")
	var line5 := _board_from(["22222", "13131", "31313"])
	_check(b.classify(line5.find_matches()[0]) == Board.Special.COLOR, "5 连应生成同色炸弹")
	var line4 := _board_from(["1", "1", "1", "1", "2"])
	_check(line4.classify(line4.find_matches()[0]) == Board.Special.LINE_V, "竖 4 连应生成竖向直线炸弹")
#endregion


func _test_collapse() -> void:
	var b := _board_from(["1.", ".2", "3.", "..", "4."])
	var moves := b.collapse()
	_check(b.cells == _board_from(["..", "..", "1.", "3.", "42"]).cells, "压缩结果不对：%s" % b.cells)
	_check(moves.size() == 3, "应移动 3 颗（1、3、2），实际 %d" % moves.size())


func _test_initial_boards() -> void:
	for s in range(1, 201):
		var b := Board.new(5 + s % 6, 5 + (s / 6) % 6, 3 + s % 5, s)
		b.fill_without_matches()
		_check(b.find_matches().is_empty(), "种子 %d：开局有三连" % s)
		_check(not b.find_valid_moves().is_empty(), "种子 %d：开局无步可走" % s)


#region test_random
## 1000 次随机交换（一半随便挑相邻两格，一半从可行步里挑），每回合结束后检查不变量。
func _test_random_play(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var b: Board
	var stats := {"ok": 0, "rejected": 0, "chain": 0, "spawned": 0, "shuffled": 0}
	for i in n:
		if i % 100 == 0:   # 每 100 步换一种棋盘配置
			b = Board.new(rng.randi_range(5, 10), rng.randi_range(5, 10), rng.randi_range(3, 7), rng.randi())
			b.fill_without_matches()
		var a := Vector2i(rng.randi_range(0, b.width - 1), rng.randi_range(0, b.height - 1))
		var c: Vector2i = a + [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][rng.randi_range(0, 3)]
		if i % 2 == 0:
			var moves := b.find_valid_moves()
			var m: Array = moves[rng.randi_range(0, moves.size() - 1)]
			a = m[0]
			c = m[1]
		var before := b.cells.duplicate()
		var expect_ok := b.is_valid_swap(a, c)
		var res := b.play_move(a, c)
		_check(res.ok == expect_ok, "第 %d 步：play_move 和 is_valid_swap 不一致" % i)
		if not res.ok:
			stats.rejected += 1
			_check(b.cells == before, "第 %d 步：无效交换改动了棋盘" % i)
			continue
		stats.ok += 1
		stats.chain = maxi(stats.chain, res.chain)
		stats.spawned += res.spawned
		stats.shuffled += 1 if res.shuffled else 0
		_check_invariants(b, "第 %d 步" % i)
	print("随机交换 %d 次：有效 %d，被拒 %d，最长连锁 %d，生成特殊宝石 %d，死局洗牌 %d" % [
		n, stats.ok, stats.rejected, stats.chain, stats.spawned, stats.shuffled])
	_check(stats.ok > n / 3 and stats.rejected > 0, "有效/被拒的次数不合理")


func _check_invariants(b: Board, where: String) -> void:
	_check(b.cells.size() == b.width * b.height, where + "：格子数变了")
	for i in b.cells.size():
		var k := b.cells[i]
		var sp := b.special[i]
		_check(k != Board.EMPTY, where + "：回合结束后还有空格")
		_check((k >= 0 and k < b.kinds) or k == Board.RAINBOW, where + "：非法颜色 %d" % k)
		_check((k == Board.RAINBOW) == (sp == Board.Special.COLOR), where + "：同色炸弹和颜色不一致")
	_check(b.find_matches().is_empty(), where + "：回合结束后棋盘上还有三连")
	var moves := b.find_valid_moves()
	_check(not moves.is_empty(), where + "：回合结束后无步可走（应该已经洗牌）")
	# 可行步检测和"真的交换再扫描"结果一致
	for m in moves:
		b.swap(m[0], m[1])
		var real := not b.find_matches().is_empty() or b.kind_at(m[0]) == Board.RAINBOW or b.kind_at(m[1]) == Board.RAINBOW
		b.swap(m[0], m[1])
		_check(real, where + "：%s↔%s 被报告为可行步，但交换后没有三连" % [m[0], m[1]])
#endregion


## 同一个种子 + 同样的操作序列 → 完全相同的棋盘。
func _test_determinism() -> void:
	var boards: Array[Board] = []
	for t in 2:
		var b := Board.new(8, 8, 6, 77)
		b.fill_without_matches()
		for i in 50:
			var m: Array = b.find_valid_moves()[0]
			b.play_move(m[0], m[1])
		boards.append(b)
	_check(boards[0].cells == boards[1].cells and boards[0].special == boards[1].special, "同种子同操作，结果却不同")
