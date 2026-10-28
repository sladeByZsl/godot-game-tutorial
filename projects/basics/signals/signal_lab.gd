## 信号实验室的根节点（父节点）。
## 原则："向下调用、向上发信号"——父节点可以直接调用子节点的方法；
## 子节点不认识父节点和兄弟节点，只发信号；由父节点负责把信号连到该去的地方。
extends Node2D

const CARD := Rect2(390, 82, 180, 46)

@export var damage := 20            ## 点一次"攻击"扣多少血
@export var heal_amount := 15
@export var auto_demo := false      ## 自动随机触发事件
@export var one_shot_badge := true: ## "首次开箱"成就用一次性连接
	set(value):
		one_shot_badge = value
		if is_node_ready():
			_connect_first_chest()

var _auto_timer := 0.0

@onready var hurt_button: Button = $HurtButton
@onready var heal_button: Button = $HealButton
@onready var player: Slime = $Player
@onready var health_bar: HealthBar = $HealthBar
@onready var chest: Chest = $Chest
@onready var score_board: ScoreBoard = $ScoreBoard
@onready var achievements: Achievements = $Achievements
@onready var viz: SignalViz = $SignalViz


#region wiring
func _ready() -> void:
	viz.watch([self, hurt_button, heal_button, player, health_bar, chest, score_board, achievements, Events])
	# 由父节点把子节点的信号连起来：按钮 → 自己，史莱姆 → 血条，宝箱 → 计分板
	hurt_button.pressed.connect(_on_hurt_pressed)
	heal_button.pressed.connect(_on_heal_pressed)
	player.health_changed.connect(health_bar.update_bar)
	player.died.connect(_on_player_died)
	chest.opened.connect(score_board.add_gold)
	_connect_first_chest()
#endregion
	viz.add_call_link(self, player, "take_damage() / heal()")
	viz.add_call_link(score_board, Events, "Events.gold_changed.emit()")
	Pal.style_button(hurt_button, Pal.RED)
	Pal.style_button(heal_button, Pal.GREEN)
	Tuning.bind(self, "lab", ["damage", "heal_amount", "auto_demo", "one_shot_badge"])
	Tuning.bind(player, "player", ["max_health"])
	Tuning.bind(chest, "chest", ["gold", "cooldown"])
	Tuning.bind(viz, "viz", ["pulse_speed", "show_wires", "show_labels"])


#region one_shot
func _connect_first_chest() -> void:
	var callable := achievements.on_first_chest
	if chest.opened.is_connected(callable):
		chest.opened.disconnect(callable)
	if achievements.unlocked[0] and one_shot_badge:
		return   # 已经解锁过了，一次性连接不再需要
	var flags := CONNECT_ONE_SHOT if one_shot_badge else 0
	chest.opened.connect(callable, flags)   # ONE_SHOT：第一次触发后自动断开
#endregion


#region call_down
func _on_hurt_pressed() -> void:
	SignalViz.report(self, player, "take_damage(%d)" % damage)   # 只为了在画面上画出这次调用
	player.take_damage(damage)        # 父节点直接调用子节点的方法：向下调用


func _on_heal_pressed() -> void:
	SignalViz.report(self, player, "heal(%d)" % heal_amount)
	player.heal(heal_amount)


func _on_player_died() -> void:
	hurt_button.disabled = true
	heal_button.disabled = true
	await get_tree().create_timer(1.6).timeout   # 等 1.6 秒再复活，期间游戏照常运行
	SignalViz.report(self, player, "revive()")
	player.revive()
	hurt_button.disabled = false
	heal_button.disabled = false
#endregion


func viz_rect() -> Rect2:
	return Rect2(to_global(CARD.position), CARD.size)


func _process(delta: float) -> void:
	Tuning.stat("血量", player.health)
	Tuning.stat("金币", score_board.gold)
	if not auto_demo:
		return
	_auto_timer -= delta
	if _auto_timer <= 0.0:
		_auto_timer = 2.4 / viz.pulse_speed
		match randi() % 3:
			0:
				if not hurt_button.disabled:
					hurt_button.pressed.emit()   # 也可以用代码手动发出内置信号
			1:
				if not heal_button.disabled:
					heal_button.pressed.emit()
			2:
				chest.open()
