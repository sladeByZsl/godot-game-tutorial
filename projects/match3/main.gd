## 三消游戏的"导演"：接收输入，调用 Board（逻辑）算出结果，再指挥 Gem（表现）把结果演出来。
## 逻辑层一步就算完；表现层要花时间播动画。两者之间用 await 串起来。
extends Node2D

#region params
@export_group("棋盘")
@export_range(5, 10) var board_width := 8:
	set(v):
		board_width = v
		_request_rebuild()
@export_range(5, 10) var board_height := 8:
	set(v):
		board_height = v
		_request_rebuild()
@export_range(3, 7) var gem_kinds := 6:          ## 颜色越少，越容易凑成三连和连锁
	set(v):
		gem_kinds = v
		_request_rebuild()
@export var rng_seed := 1:                        ## 0 = 每局随机；其他值 = 每次开局完全一样
	set(v):
		rng_seed = v
		_request_rebuild()
@export var specials_enabled := true:
	set(v):
		specials_enabled = v
		if board:
			board.specials_enabled = v

@export_group("动画")
@export var swap_time := 0.18                     ## 交换动画时长（秒）
@export var clear_time := 0.24                    ## 消除动画时长
@export var fall_time := 0.11                     ## 下落 1 格的时长；落 n 格用 fall_time·√n
@export_enum("BOUNCE", "BACK", "QUAD", "LINEAR") var fall_ease := "BOUNCE"
@export var chain_delay := 0.06                   ## 连锁每一轮之间的停顿
@export var shake_strength := 6.0                 ## 连锁和特殊宝石触发时的震屏幅度（像素）

@export_group("操作")
@export var drag_threshold := 0.35                ## 拖动超过多少个格子宽才算一次滑动
@export var hint_delay := 5.0                     ## 多少秒不操作就提示一步
@export var auto_play := false

@export_group("关卡")
@export var move_limit := 20:
	set(v):
		move_limit = v
		_on_level_param_changed()
@export var target_score := 3000:
	set(v):
		target_score = v
		_on_level_param_changed()
@export var show_debug := false:
	set(v):
		show_debug = v
		if overlay:
			overlay.show_debug = v
#endregion

var board: Board
var score := 0
var moves_left := 0
var chain := 0
var max_chain := 0

var _gems: Array = []             # 和 board.cells 一一对应的 Gem 节点（空格是 null）
var _busy := false                # 动画进行中：锁住输入
var _rebuild_pending := false     # 动画进行中改了棋盘参数：等这一回合结束再重建
var _started := false
var _game_over := false
var _moves_used := 0
var _used_seed := 0
var _valid_count := 0
var _selected := Board.NO_CELL
var _drag_from := Board.NO_CELL
var _drag_start := Vector2.ZERO
var _hint: Array = []
var _idle := 0.0
var _shake := 0.0
var _board_origin := Vector2.ZERO
var _fx_rng := RandomNumberGenerator.new()   # 特效、提示、自动演示用；不碰 board.rng，保证棋盘可复现

@onready var view: BoardView = $BoardView
@onready var overlay: BoardOverlay = $BoardView/Overlay
@onready var fx: BoardFx = $BoardView/Fx
@onready var hud: Hud = $HUD


func _ready() -> void:
	Tuning.bind(self, "game", [
		"board_width", "board_height", "gem_kinds", "rng_seed", "specials_enabled",
		"swap_time", "clear_time", "fall_time", "fall_ease", "chain_delay", "shake_strength",
		"drag_threshold", "hint_delay", "auto_play", "move_limit", "target_score", "show_debug",
	])
	Tuning.action_triggered.connect(_on_action)
	hud.restart_pressed.connect(_request_rebuild.bind(true))
	get_viewport().size_changed.connect(_layout)
	overlay.view = view
	overlay.show_debug = show_debug
	_started = true
	_new_game()


func _on_action(action_name: String) -> void:
	match action_name:
		"restart":
			_request_rebuild(true)
		"shuffle":
			if not _busy and not _game_over:
				_busy = true
				await _shuffle_board("手动洗牌")
				_finish_turn()
		"hint":
			if not _busy:
				_show_hint()


#region rebuild
## 改了棋盘大小、颜色数、种子：要整个重建。动画播到一半时不能直接删宝石节点
## （正在 await 的协程醒来后会去操作已经释放的节点），所以先记下来，等回合结束再做。
func _request_rebuild(_force := false) -> void:
	if not _started:
		return
	if _busy:
		_rebuild_pending = true
	else:
		_new_game()
#endregion


func _new_game() -> void:
	_rebuild_pending = false
	_set_hint([])
	_used_seed = rng_seed if rng_seed > 0 else randi_range(1, 99999)
	_fx_rng.seed = _used_seed
	board = Board.new(board_width, board_height, gem_kinds, _used_seed)
	board.specials_enabled = specials_enabled
	board.fill_without_matches()
	overlay.board = board
	score = 0
	chain = 0
	max_chain = 0
	_moves_used = 0
	moves_left = move_limit
	_game_over = false
	_selected = Board.NO_CELL
	overlay.selected = _selected
	hud.hide_result()
	for g in view.gem_layer.get_children():
		g.queue_free()
	_gems.clear()
	_gems.resize(board.cells.size())
	_layout()
	for i in _gems.size():
		_make_gem(board.cell_of(i))
	hud.set_info("种子 %d · %d×%d · %d 种宝石\n点一颗再点相邻的一颗，或直接拖动" % [_used_seed, board.width, board.height, board.kinds])
	_refresh_hud()
	_busy = true
	await _animate_intro()
	_finish_turn()


func _make_gem(c: Vector2i) -> Gem:
	var g := Gem.new()
	g.setup(board.kind_at(c), board.special_at(c), view.cell_size * 0.42)
	g.position = view.cell_to_pixel(c)
	view.gem_layer.add_child(g)
	_gems[board.idx(c)] = g
	return g


func _layout() -> void:
	if board == null:
		return
	var vp := get_viewport_rect().size
	var margin := 28.0
	var portrait := vp.x < vp.y * 1.1
	var panel_rect: Rect2
	var area: Rect2
	if portrait:
		panel_rect = Rect2(margin, margin, vp.x - margin * 2.0, 0)
		area = Rect2(margin, margin + 300.0, vp.x - margin * 2.0, vp.y - margin * 2.0 - 300.0)
	else:
		var pw := 230.0
		panel_rect = Rect2(vp.x - pw - margin, margin, pw, 0)
		area = Rect2(margin + 10.0, margin, vp.x - pw - margin * 3.0 - 10.0, vp.y - margin * 2.0)
	var cs := floorf(minf(area.size.x / board.width, area.size.y / board.height))
	cs = minf(cs, 84.0)
	var size_px := Vector2(board.width, board.height) * cs
	_board_origin = (area.position + (area.size - size_px) * 0.5).round()
	view.position = _board_origin
	view.configure(board.width, board.height, cs)
	hud.layout(panel_rect, Rect2(_board_origin, size_px))
	for i in _gems.size():
		var g: Gem = _gems[i]
		if g:
			g.radius = cs * 0.42
			g.queue_redraw()
			if not _busy:
				g.position = view.cell_to_pixel(board.cell_of(i))


func _process(delta: float) -> void:
	# 震屏：每帧给棋盘一个随机偏移，幅度线性衰减到 0
	_shake = move_toward(_shake, 0.0, delta * (shake_strength * 3.0 + 4.0))
	view.position = _board_origin + Vector2(_fx_rng.randf_range(-1, 1), _fx_rng.randf_range(-1, 1)) * _shake
	if _busy:
		return
	_idle += delta
	if _game_over:
		if auto_play and _idle > 2.5:
			_request_rebuild()
		return
	if _hint.is_empty() and _idle > hint_delay:
		_show_hint()
	if auto_play and _idle > 0.5:
		var moves := board.find_valid_moves()
		if not moves.is_empty():
			var m: Array = moves[_fx_rng.randi_range(0, moves.size() - 1)]
			_play_turn(m[0], m[1])


#region input
## 用 _unhandled_input 而不是 _input：HUD 上的按钮先处理点击，没被界面吃掉的才轮到棋盘。
## 触屏在 Web 和手机上默认会被模拟成鼠标事件（emulate_mouse_from_touch），所以只处理鼠标即可。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local := view.make_input_local(event) as InputEventMouseButton   # 换算到棋盘坐标
		if event.pressed:
			_on_press(view.pixel_to_cell(local.position), local.position)
		else:
			_drag_from = Board.NO_CELL
	elif event is InputEventMouseMotion and _drag_from != Board.NO_CELL:
		var local := view.make_input_local(event) as InputEventMouseMotion
		_on_drag(local.position)


func _on_press(cell: Vector2i, pos: Vector2) -> void:
	if _busy or _game_over or not board.in_bounds(cell):
		_selected = Board.NO_CELL
		overlay.selected = _selected
		return
	_idle = 0.0
	if _selected != Board.NO_CELL and board.is_adjacent(_selected, cell):
		var from := _selected      # 第二次点击：和已选中的相邻格交换
		_selected = Board.NO_CELL
		overlay.selected = _selected
		_play_turn(from, cell)
		return
	_selected = cell               # 第一次点击：选中，同时准备拖动
	overlay.selected = cell
	_drag_from = cell
	_drag_start = pos


## 拖动：位移超过阈值后，按 |dx| 和 |dy| 谁大决定方向，只取上下左右四个方向之一。
func _on_drag(pos: Vector2) -> void:
	var d := pos - _drag_start
	if d.length() < view.cell_size * drag_threshold:
		return
	var dir := Vector2i(signi(roundi(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, signi(roundi(d.y)))
	var from := _drag_from
	_drag_from = Board.NO_CELL
	if board.in_bounds(from + dir) and not _busy:
		_selected = Board.NO_CELL
		overlay.selected = _selected
		_play_turn(from, from + dir)
#endregion


#region turn
## 一回合：交换 →（检测 → 消除 → 下落补充）循环 → 死局检查。
## 每个 await 都会把这个函数挂起，等动画播完再往下走。挂起期间 _busy 为 true，输入一律忽略。
func _play_turn(a: Vector2i, b: Vector2i) -> void:
	_busy = true
	_set_hint([])
	var bomb_swap := board.kind_at(a) == Board.RAINBOW or board.kind_at(b) == Board.RAINBOW
	board.swap(a, b)
	await _animate_swap(a, b)
	if not bomb_swap and board.find_matches().is_empty():
		board.swap(a, b)                    # 没有形成消除：逻辑上换回去
		await _animate_swap(a, b)           # 画面上也换回去
		_finish_turn()
		return
	_moves_used += 1
	moves_left -= 1
	var extra: Array[Vector2i] = []
	if bomb_swap:
		extra = board.activate_color_bomb(a, b)
		fx.ring(view.cell_to_pixel(b if board.kind_at(b) == Board.RAINBOW else a), view.cell_size * 4.0, Color.WHITE)
	var prefer: Array[Vector2i] = [b, a]    # 新的特殊宝石优先出现在玩家拖过去的位置
	chain = 0
	while not _rebuild_pending:
		var groups := board.find_matches()
		if groups.is_empty() and extra.is_empty():
			break
		chain += 1
		var res := board.clear_matches(groups, prefer, extra)
		extra = []
		prefer = []
		_add_score(res, groups)
		await _animate_clear(res)
		if _rebuild_pending:
			break
		var moves := board.collapse()
		var spawns := board.refill()
		await _animate_fall(moves, spawns)
		if chain_delay > 0.0:
			await get_tree().create_timer(chain_delay).timeout
	if not _rebuild_pending and board.find_valid_moves().is_empty():
		await _shuffle_board("没有可走的步了，自动洗牌")
	_finish_turn()


func _finish_turn() -> void:
	_busy = false
	_idle = 0.0
	if _rebuild_pending:
		_new_game()
		return
	_valid_count = board.find_valid_moves().size()
	_refresh_hud()
	if moves_left <= 0 and not _game_over:
		_game_over = true
		hud.show_result(score, target_score)
#endregion


#region swap_anim
## 交换动画：一个 Tween 同时移动两颗宝石（set_parallel），await finished 等它播完。
func _animate_swap(a: Vector2i, b: Vector2i) -> void:
	var ga: Gem = _gems[board.idx(a)]
	var gb: Gem = _gems[board.idx(b)]
	_gems[board.idx(a)] = gb               # 表现层的数组也跟着换，保持和 board 一一对应
	_gems[board.idx(b)] = ga
	ga.z_index = 1                         # 被拖动的那颗画在上面
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(ga, "position", view.cell_to_pixel(b), swap_time)
	tw.tween_property(gb, "position", view.cell_to_pixel(a), swap_time)
	await tw.finished
	ga.z_index = 0
#endregion


#region clear_anim
## 消除动画：所有要消的宝石放进同一个并行 Tween。每颗先放大再缩小淡出，
## 第二段用 set_delay 推迟开始，这样一个 Tween 里就能表达"先后"。
func _animate_clear(res: Dictionary) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_interval(clear_time)          # 保证 Tween 里至少有一步（空 Tween 会报错）
	var dying: Array[Gem] = []
	for e: Dictionary in res.cleared:
		var i := board.idx(e.cell)
		var g: Gem = _gems[i]
		_gems[i] = null
		if g == null:
			continue
		dying.append(g)
		fx.burst(g.position, Gem.color_of(e.kind), view.cell_size)
		tw.tween_property(g, "scale", Vector2(1.25, 1.25), clear_time * 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_property(g, "scale", Vector2.ZERO, clear_time * 0.65).set_delay(clear_time * 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(g, "modulate:a", 0.0, clear_time * 0.65).set_delay(clear_time * 0.35)
	for t: Dictionary in res.triggered:
		_special_fx(t.cell, t.special)
	for s: Dictionary in res.spawned:       # 新生成的特殊宝石：原地变身 + 弹一下
		var g: Gem = _gems[board.idx(s.cell)]
		g.set_special(s.kind, s.special)
		g.scale = Vector2(1.6, 1.6)
		tw.tween_property(g, "scale", Vector2.ONE, clear_time * 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	for g in dying:
		g.queue_free()
#endregion


func _special_fx(c: Vector2i, sp: int) -> void:
	var cs := view.cell_size
	var p := view.cell_to_pixel(c)
	var col := Gem.color_of(board.kind_at(c))
	match sp:
		Board.Special.LINE_H:
			fx.beam(Vector2(0, p.y), Vector2(board.width * cs, p.y), col, cs * 0.5)
		Board.Special.LINE_V:
			fx.beam(Vector2(p.x, 0), Vector2(p.x, board.height * cs), col, cs * 0.5)
		Board.Special.BOMB:
			fx.ring(p, cs * 1.8, col)
		Board.Special.COLOR:
			fx.ring(p, cs * 4.0, Color.WHITE)
	_shake = maxf(_shake, shake_strength)


#region fall_anim
## 下落动画：已有宝石往下掉，新宝石从棋盘上方 drop 格处掉进来，全部并行。
## 落 n 格用时 fall_time·√n：自由落体 h = ½gt²，t 和 √h 成正比，远的掉得久一点但不会久太多。
func _animate_fall(moves: Array[Dictionary], spawns: Array[Dictionary]) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_interval(0.01)
	for m in moves:
		var g: Gem = _gems[board.idx(m.from)]
		_gems[board.idx(m.from)] = null
		_gems[board.idx(m.to)] = g
		_fall(tw, g, m.to, m.to.y - m.from.y)
	for s in spawns:
		var g := _make_gem(s.cell)
		g.position = view.cell_to_pixel(s.cell - Vector2i(0, s.drop))
		_fall(tw, g, s.cell, s.drop)
	await tw.finished


func _fall(tw: Tween, g: Gem, to: Vector2i, cells: int) -> PropertyTweener:
	var t := fall_time * sqrt(float(cells))
	var pt := tw.tween_property(g, "position", view.cell_to_pixel(to), t)
	match fall_ease:
		"BOUNCE":
			pt.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"BACK":
			pt.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"QUAD":
			pt.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_:
			pt.set_trans(Tween.TRANS_LINEAR)
	return pt
#endregion


func _animate_intro() -> void:
	var tw := create_tween().set_parallel(true)
	for i in _gems.size():
		var g: Gem = _gems[i]
		var c := board.cell_of(i)
		g.position = view.cell_to_pixel(c - Vector2i(0, board.height))
		_fall(tw, g, c, board.height).set_delay((board.height - 1 - c.y) * 0.02 + c.x * 0.008)
	await tw.finished


#region score
## 计分：每颗 10 分；一组超过 3 颗，每多一颗 +20；每触发一个特殊宝石 +30。
## 整轮得分再乘以连锁数：第 1 轮 ×1，第 2 轮 ×2……连锁越深越值钱。
func _add_score(res: Dictionary, groups: Array[Dictionary]) -> void:
	var base: int = res.cleared.size() * 10 + res.triggered.size() * 30
	for g in groups:
		base += maxi(0, g.cells.size() - 3) * 20
	var gained := base * chain
	score += gained
	max_chain = maxi(max_chain, chain)
	var center := Vector2.ZERO
	for e: Dictionary in res.cleared:
		center += view.cell_to_pixel(e.cell)
	center /= maxf(1.0, res.cleared.size())
	var col := Color("#fff2a8") if chain < 2 else Color("#ff9ad5")
	fx.float_text(center, "+%d" % gained, col, int(view.cell_size * (0.42 + 0.06 * mini(chain, 5))))
	if chain >= 2:
		hud.show_chain(chain)
		_shake = maxf(_shake, shake_strength * (0.5 + 0.25 * mini(chain, 4)))
	_refresh_hud()
#endregion


#region deadlock
## 死局：没有任何一步能形成消除。逻辑层负责洗出一个"无三连、有步可走"的排列，
## 表现层按排列 perm 把每颗宝石飞到新位置。
func _shuffle_board(msg: String) -> void:
	_set_hint([])
	hud.toast(msg)
	var old := _gems.duplicate()
	var perm := board.shuffle()
	var tw := create_tween().set_parallel(true)
	tw.tween_interval(0.01)
	if perm.is_empty():                    # 洗不出来，逻辑层重新生成了：宝石全部重建
		for g in old:
			if g:
				g.queue_free()
		for i in _gems.size():
			_make_gem(board.cell_of(i)).scale = Vector2.ZERO
			tw.tween_property(_gems[i], "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		for i in perm.size():
			_gems[i] = old[perm[i]]
			tw.tween_property(_gems[i], "position", view.cell_to_pixel(board.cell_of(i)), 0.45) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT).set_delay(_fx_rng.randf() * 0.12)
	await tw.finished
#endregion


#region hint
## 提示一步：从所有可行步里随机挑一个（用特效专用的随机数，不影响棋盘的随机序列）。
func _show_hint() -> void:
	var moves := board.find_valid_moves()
	if not moves.is_empty():
		_set_hint(moves[_fx_rng.randi_range(0, moves.size() - 1)])
#endregion


func _set_hint(h: Array) -> void:
	for c: Vector2i in _hint:
		var g: Gem = _gems[board.idx(c)] if board else null
		if g:
			g.set_hint(false)
	_hint = h
	for c: Vector2i in _hint:
		var g: Gem = _gems[board.idx(c)]
		if g:
			g.set_hint(true)
	overlay.hint = h


func _on_level_param_changed() -> void:
	if not _started:
		return
	moves_left = maxi(move_limit - _moves_used, 0)
	_refresh_hud()
	if _busy:
		return
	if moves_left == 0:
		_game_over = true
		hud.show_result(score, target_score)     # 已经结算过也重新显示：目标分数变了，星级要重新算
	elif _game_over:
		_game_over = false
		hud.hide_result()


func _refresh_hud() -> void:
	hud.set_values(score, target_score, moves_left)
	Tuning.stat("分数", score)
	Tuning.stat("剩余步数", moves_left)
	Tuning.stat("本回合连锁", chain)
	Tuning.stat("最大连锁", max_chain)
	Tuning.stat("可行步数", _valid_count)
	Tuning.stat("种子", _used_seed)
