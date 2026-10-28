## 三消棋盘的纯逻辑层：只有数据和算法，不依赖任何节点。
## 游戏场景（main.gd）和无界面测试（tests/board_test.gd）用的是同一份代码。
class_name Board
extends RefCounted

#region data
const EMPTY := -1             ## 空格（刚被消掉，还没补上）
const RAINBOW := 99           ## 同色炸弹没有颜色，用一个不会参与匹配的值表示
const NO_CELL := Vector2i(-1, -1)

enum Special { NONE, LINE_H, LINE_V, BOMB, COLOR }

var width := 8
var height := 8
var kinds := 6                ## 宝石颜色种类数
var specials_enabled := true
## 一维数组存二维棋盘：格子 (x, y) 的下标是 y * width + x
var cells := PackedInt32Array()     # 每格的颜色 0..kinds-1，EMPTY 或 RAINBOW
var special := PackedInt32Array()   # 每格的特殊类型 Special
var rng := RandomNumberGenerator.new()   # 自己的随机数发生器：种子相同，整局就完全相同


func _init(w := 8, h := 8, k := 6, seed_value := 1) -> void:
	width = w
	height = h
	kinds = k
	rng.seed = seed_value
	cells.resize(w * h)
	cells.fill(EMPTY)
	special.resize(w * h)
	special.fill(Special.NONE)
#endregion


#region coords
func idx(c: Vector2i) -> int:
	return c.y * width + c.x


func cell_of(i: int) -> Vector2i:
	return Vector2i(i % width, i / width)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func kind_at(c: Vector2i) -> int:
	return cells[idx(c)] if in_bounds(c) else EMPTY


func special_at(c: Vector2i) -> int:
	return special[idx(c)] if in_bounds(c) else Special.NONE


func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func swap(a: Vector2i, b: Vector2i) -> void:
	var ia := idx(a)
	var ib := idx(b)
	var k := cells[ia]
	cells[ia] = cells[ib]
	cells[ib] = k
	var s := special[ia]
	special[ia] = special[ib]
	special[ib] = s
#endregion


func _matchable(k: int) -> bool:
	return k >= 0 and k != RAINBOW


#region fill
## 生成一个开局就没有三连的棋盘。按从左到右、从上到下的顺序填：
## 填 (x, y) 时只有左边两格和上面两格已经确定，所以只要避开
## "左边两格同色"和"上面两格同色"的那个颜色，就不可能凑成三连。
## 每格最多排除 2 种颜色，kinds ≥ 3 时一定有得选。
func fill_without_matches() -> void:
	for attempt in 100:
		for y in height:
			for x in width:
				var banned: Array[int] = []
				if x >= 2 and cells[idx(Vector2i(x - 1, y))] == cells[idx(Vector2i(x - 2, y))]:
					banned.append(cells[idx(Vector2i(x - 1, y))])
				if y >= 2 and cells[idx(Vector2i(x, y - 1))] == cells[idx(Vector2i(x, y - 2))]:
					banned.append(cells[idx(Vector2i(x, y - 1))])
				var choices: Array[int] = []
				for k in kinds:
					if k not in banned:
						choices.append(k)
				cells[idx(Vector2i(x, y))] = choices[rng.randi_range(0, choices.size() - 1)]
				special[idx(Vector2i(x, y))] = Special.NONE
		# 没有三连还不够：开局至少要有一步能走，否则重新生成
		if not find_valid_moves().is_empty():
			return
#endregion


#region scan
## 扫描所有横向、纵向长度 ≥ 3 的同色连续段（run）。
## 每一行、每一列各走一遍，每个格子被看两次，复杂度 O(W·H)。
func find_runs() -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	for y in height:
		_scan_line(Vector2i(0, y), Vector2i.RIGHT, width, true, runs)
	for x in width:
		_scan_line(Vector2i(x, 0), Vector2i.DOWN, height, false, runs)
	return runs


## 沿 step 方向走 length 格，用"段起点 + 段终点"两个下标找连续段。
func _scan_line(start: Vector2i, step: Vector2i, length: int, horizontal: bool, runs: Array[Dictionary]) -> void:
	var i := 0
	while i < length:
		var k := cells[idx(start + step * i)]
		var j := i + 1
		while j < length and cells[idx(start + step * j)] == k:
			j += 1
		# [i, j) 是一段同色，长度 j - i
		if j - i >= 3 and _matchable(k):
			var run: Array[Vector2i] = []
			for t in range(i, j):
				run.append(start + step * t)
			runs.append({"cells": run, "kind": k, "horizontal": horizontal})
		i = j    # 直接跳到下一段，不回头
#endregion


#region merge
## 把共享格子的连续段合并成一组：L 形、T 形、十字形都是"一横一竖"共用一个格子。
## 组里的格子用 Dictionary 当集合存（键是 Vector2i，值随便），同一个格子只会出现一次。
## 返回 Array[Dictionary]：{cells: {Vector2i: true}, kind, h, v, longest, corner}
func find_matches() -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for run in find_runs():
		var merged := {"cells": {}, "kind": run.kind, "h": 0, "v": 0, "longest": 0, "corner": NO_CELL}
		for g in groups.duplicate():
			if _shares_cell(g.cells, run.cells):
				_absorb(merged, g)
				groups.erase(g)
		for c: Vector2i in run.cells:
			if merged.cells.has(c):
				merged.corner = c      # 这个格子同时属于横段和竖段：L/T 的拐点
			merged.cells[c] = true
		merged.h += 1 if run.horizontal else 0
		merged.v += 0 if run.horizontal else 1
		merged.longest = maxi(merged.longest, run.cells.size())
		groups.append(merged)
	return groups


func _shares_cell(set_a: Dictionary, run_cells: Array[Vector2i]) -> bool:
	for c in run_cells:
		if set_a.has(c):
			return true
	return false


func _absorb(into: Dictionary, g: Dictionary) -> void:
	into.cells.merge(g.cells)
	into.h += g.h
	into.v += g.v
	into.longest = maxi(into.longest, g.longest)
	if g.corner != NO_CELL:
		into.corner = g.corner
#endregion


#region classify
## 根据组的形状决定生成哪种特殊宝石。优先级：5 连 > L/T > 4 连。
func classify(g: Dictionary) -> int:
	if g.longest >= 5:
		return Special.COLOR
	if g.h > 0 and g.v > 0:
		return Special.BOMB
	if g.longest == 4:
		return Special.LINE_H if g.h > 0 else Special.LINE_V
	return Special.NONE
#endregion


#region valid_swap
## 判断交换 a、b 之后能不能形成消除（不真的改棋盘：换过去、看一眼、换回来）。
func is_valid_swap(a: Vector2i, b: Vector2i) -> bool:
	if not (in_bounds(a) and in_bounds(b) and is_adjacent(a, b)):
		return false
	if kind_at(a) == RAINBOW or kind_at(b) == RAINBOW:
		return true                 # 同色炸弹和谁换都能炸
	if kind_at(a) == kind_at(b):
		return false
	swap(a, b)
	var ok := _match_through(a) or _match_through(b)
	swap(a, b)
	return ok


## 只看经过 c 的那一横一竖：往两边数同色，加上自己 ≥ 3 就是三连。
func _match_through(c: Vector2i) -> bool:
	var k := kind_at(c)
	if not _matchable(k):
		return false
	var h := 1 + _count(c, Vector2i.LEFT, k) + _count(c, Vector2i.RIGHT, k)
	var v := 1 + _count(c, Vector2i.UP, k) + _count(c, Vector2i.DOWN, k)
	return h >= 3 or v >= 3


func _count(c: Vector2i, dir: Vector2i, k: int) -> int:
	var n := 0
	var p := c + dir
	while kind_at(p) == k:
		n += 1
		p += dir
	return n
#endregion


#region moves
## 所有可行的交换。每个格子只试"右"和"下"两个方向，避免同一对算两次。
func find_valid_moves() -> Array[Array]:
	var moves: Array[Array] = []
	for y in height:
		for x in width:
			var a := Vector2i(x, y)
			for d in [Vector2i.RIGHT, Vector2i.DOWN]:
				if is_valid_swap(a, a + d):
					moves.append([a, a + d])
	return moves
#endregion


#region clear
## 执行一轮消除。groups 来自 find_matches()；prefer 是玩家刚交换的两个格子，
## 新的特殊宝石优先生成在那里；extra 是额外要清掉的格子（同色炸弹交换时用）。
## 返回 {cleared: [{cell, kind, special}], spawned: [{cell, kind, special}], triggered: [{cell, special}]}
func clear_matches(groups: Array[Dictionary], prefer: Array[Vector2i] = [], extra: Array[Vector2i] = []) -> Dictionary:
	var to_clear := {}       # 集合：要清掉的格子
	var protect := {}        # 这一轮新生成特殊宝石的格子，不清
	var spawned: Array[Dictionary] = []
	for g in groups:
		to_clear.merge(g.cells)
		var sp := classify(g) if specials_enabled else Special.NONE
		if sp != Special.NONE:
			var at := _spawn_cell(g, prefer)
			if at != NO_CELL and not protect.has(at):
				protect[at] = true
				spawned.append({"cell": at, "kind": RAINBOW if sp == Special.COLOR else g.kind, "special": sp})
	for c in extra:
		to_clear[c] = true
	for c in protect:
		to_clear.erase(c)

	# 链式触发：被清掉的格子里有特殊宝石，就把它的作用范围也加进来，
	# 新加进来的格子里如果又有特殊宝石，会在队列后面继续触发（广度优先）。
	var queue: Array = to_clear.keys()
	var triggered: Array[Dictionary] = []
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var sp := special_at(c)
		if sp == Special.NONE:
			continue
		triggered.append({"cell": c, "special": sp})
		for t in effect_area(c, sp):
			if not to_clear.has(t) and not protect.has(t):
				to_clear[t] = true
				queue.append(t)

	var cleared: Array[Dictionary] = []
	for c: Vector2i in to_clear:
		cleared.append({"cell": c, "kind": kind_at(c), "special": special_at(c)})
		cells[idx(c)] = EMPTY
		special[idx(c)] = Special.NONE
	for s in spawned:
		cells[idx(s.cell)] = s.kind
		special[idx(s.cell)] = s.special
	return {"cleared": cleared, "spawned": spawned, "triggered": triggered}
#endregion


#region effect
## 特殊宝石生成在哪：玩家刚动过的格子 > L/T 的拐点 > 段的中间。已有特殊宝石的格子不用。
func _spawn_cell(g: Dictionary, prefer: Array[Vector2i]) -> Vector2i:
	var keys: Array = g.cells.keys()
	var candidates: Array = []
	candidates.append_array(prefer)
	candidates.append(g.corner)
	candidates.append(keys[keys.size() / 2])
	candidates.append_array(keys)
	for c in candidates:
		if g.cells.has(c) and special_at(c) == Special.NONE:
			return c
	return NO_CELL


## 特殊宝石被消除时影响的格子。
func effect_area(c: Vector2i, sp: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	match sp:
		Special.LINE_H:
			for x in width:
				out.append(Vector2i(x, c.y))
		Special.LINE_V:
			for y in height:
				out.append(Vector2i(c.x, y))
		Special.BOMB:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if in_bounds(c + Vector2i(dx, dy)):
						out.append(c + Vector2i(dx, dy))
		Special.COLOR:
			var k := most_common_kind()
			for i in cells.size():
				if cells[i] == k:
					out.append(cell_of(i))
	return out


func most_common_kind() -> int:
	var counts := {}
	for k in cells:
		if _matchable(k):
			counts[k] = counts.get(k, 0) + 1
	var best := 0
	for k in counts:
		if counts[k] > counts.get(best, 0):
			best = k
	return best


## 玩家把同色炸弹和别的宝石交换：返回要清掉的格子（炸弹本身 + 所有和对方同色的宝石）。
## 两个同色炸弹互换：清空整个棋盘。调用前 a、b 已经交换过。
func activate_color_bomb(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var ka := kind_at(a)
	var kb := kind_at(b)
	special[idx(a)] = Special.NONE if ka == RAINBOW else special[idx(a)]   # 引信用掉了，别在链式触发里再炸一次
	special[idx(b)] = Special.NONE if kb == RAINBOW else special[idx(b)]
	if ka == RAINBOW and kb == RAINBOW:
		for i in cells.size():
			out.append(cell_of(i))
		return out
	var target := kb if ka == RAINBOW else ka
	out.append(a if ka == RAINBOW else b)
	for i in cells.size():
		if cells[i] == target:
			out.append(cell_of(i))
	return out
#endregion


#region gravity
## 重力压缩：每一列用两个指针从下往上走。
## read 找宝石，write 指向"下一个应该放宝石的位置"。遇到宝石就搬到 write，write 上移一格。
## 每列只走一遍，O(H)；整个棋盘 O(W·H)。返回移动列表 [{from, to}]，给动画用。
func collapse() -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for x in width:
		var write := height - 1
		for read in range(height - 1, -1, -1):
			var from := Vector2i(x, read)
			if cells[idx(from)] == EMPTY:
				continue
			if read != write:
				var to := Vector2i(x, write)
				cells[idx(to)] = cells[idx(from)]
				special[idx(to)] = special[idx(from)]
				cells[idx(from)] = EMPTY
				special[idx(from)] = Special.NONE
				moves.append({"from": from, "to": to})
			write -= 1
	return moves
#endregion


#region refill
## 压缩之后，空位只会出现在每列顶部。把它们补满新宝石。
## 补充时不避开三连：新掉下来的宝石凑成三连，就是"天降连锁"。
## 返回 [{cell, kind, drop}]，drop = 这一列补了几个，动画里新宝石从棋盘上方 drop 格处落下。
func refill() -> Array[Dictionary]:
	var spawns: Array[Dictionary] = []
	for x in width:
		var empty_count := 0
		while empty_count < height and cells[idx(Vector2i(x, empty_count))] == EMPTY:
			empty_count += 1
		for y in empty_count:
			var c := Vector2i(x, y)
			cells[idx(c)] = rng.randi_range(0, kinds - 1)
			special[idx(c)] = Special.NONE
			spawns.append({"cell": c, "kind": cells[idx(c)], "drop": empty_count})
	return spawns
#endregion


#region shuffle
## 死局洗牌：把所有宝石打乱（Fisher–Yates），直到"没有三连并且至少有一步可走"。
## 返回排列 perm：新下标 i 上的宝石来自旧下标 perm[i]（动画用它把宝石飞到新位置）。
## 洗 200 次都不行（颜色太少、棋盘太小）就重新生成，返回空数组。
func shuffle() -> PackedInt32Array:
	var old_cells := cells.duplicate()
	var old_special := special.duplicate()
	var perm := PackedInt32Array()
	perm.resize(cells.size())
	for attempt in 200:
		for i in perm.size():
			perm[i] = i
		for i in range(perm.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := perm[i]
			perm[i] = perm[j]
			perm[j] = t
		for i in perm.size():
			cells[i] = old_cells[perm[i]]
			special[i] = old_special[perm[i]]
		if find_matches().is_empty() and not find_valid_moves().is_empty():
			return perm
	fill_without_matches()
	return PackedInt32Array()
#endregion


#region settle
## 不带动画的完整一回合：交换 → 循环（检测 → 消除 → 压缩 → 补充）直到没有消除 → 死局洗牌。
## main.gd 用 await 做的是同一件事，只是每一步之间插入了动画。测试脚本直接调用这个函数。
func play_move(a: Vector2i, b: Vector2i) -> Dictionary:
	if not is_valid_swap(a, b):
		return {"ok": false}
	var bomb_swap := kind_at(a) == RAINBOW or kind_at(b) == RAINBOW
	swap(a, b)
	var extra: Array[Vector2i] = []
	if bomb_swap:
		extra = activate_color_bomb(a, b)
	var prefer: Array[Vector2i] = [b, a]
	var chain := 0
	var cleared := 0
	var spawned := 0
	while true:
		var groups := find_matches()
		if groups.is_empty() and extra.is_empty():
			break
		chain += 1
		var res := clear_matches(groups, prefer, extra)
		extra = []
		prefer = []
		cleared += res.cleared.size()
		spawned += res.spawned.size()
		collapse()
		refill()
	var shuffled := find_valid_moves().is_empty()
	if shuffled:
		shuffle()
	return {"ok": true, "chain": chain, "cleared": cleared, "spawned": spawned, "shuffled": shuffled}
#endregion
