## 界面：金币数、失误次数、计时、提示气泡、通关面板。数字变化时用 Tween 弹一下。
class_name Hud
extends CanvasLayer

var _coin_total := 0

@onready var coin_icon: Control = %CoinIcon
@onready var coin_label: Label = %CoinLabel
@onready var death_label: Label = %DeathLabel
@onready var time_label: Label = %TimeLabel
@onready var toast_label: Label = %Toast
@onready var win_panel: PanelContainer = %WinPanel
@onready var win_label: Label = %WinStats
@onready var hint: Label = %Hint


func _ready() -> void:
	toast_label.modulate.a = 0.0
	win_panel.hide()
	var tw := create_tween()
	tw.tween_interval(7.0)
	tw.tween_property(hint, "modulate:a", 0.0, 1.0)


func setup(coin_total: int) -> void:
	_coin_total = coin_total
	set_coins(0)


func set_coins(n: int) -> void:
	coin_label.text = "%d / %d" % [n, _coin_total]
	if n > 0:
		pop(coin_icon)
		pop(coin_label, 1.3)


func set_deaths(n: int) -> void:
	death_label.text = "失误 %d" % n
	pop(death_label, 1.4)


func set_time(t: float) -> void:
	time_label.text = "%02d:%02d" % [int(t) / 60, int(t) % 60]


#region pop
## UI 弹跳：先瞬间放大，再用 ELASTIC 缓动弹回原大小。
## Control 默认绕左上角缩放，所以先把 pivot_offset 设到中心。
func pop(c: Control, amount := 1.6) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(amount, amount)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
#endregion


func toast(text: String) -> void:
	toast_label.text = text
	toast_label.pivot_offset = toast_label.size / 2.0
	var tw := create_tween()
	tw.tween_property(toast_label, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(toast_label, "scale", Vector2.ONE, 0.4).from(Vector2(0.4, 0.4)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.4)


func show_win(coins: int, deaths: int, t: float) -> void:
	win_label.text = "金币 %d / %d　　失误 %d　　用时 %02d:%02d\n4 秒后重新开始" % [coins, _coin_total, deaths, int(t) / 60, int(t) % 60]
	win_panel.show()
	win_panel.pivot_offset = win_panel.size / 2.0
	var tw := create_tween()
	tw.tween_property(win_panel, "scale", Vector2.ONE, 0.6).from(Vector2(0.2, 0.2)) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
