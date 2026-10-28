## 结算界面：显示本局成绩和排行榜。
class_name ResultScreen
extends CanvasLayer

@onready var panel: Control = %Panel
@onready var title_label: Label = %Title
@onready var record_label: Label = %NewRecord
@onready var score_label: Label = %ScoreValue
@onready var kills_label: Label = %KillsValue
@onready var time_label: Label = %TimeValue
@onready var best_label: Label = %BestValue
@onready var board: VBoxContainer = %Board
@onready var retry_button: Button = %Retry


func _ready() -> void:
	hide()
	retry_button.pressed.connect(func() -> void: Flow.start_game(false))
	%ToTitle.pressed.connect(Flow.go_to_title)
	UiSounds.attach(self)


func open(cleared: bool, score: int, kills: int, seconds: float, rank: int) -> void:
	title_label.text = "任务完成" if cleared else "任务失败"
	title_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.7) if cleared else Color(1.0, 0.4, 0.55))
	record_label.visible = rank == 0
	score_label.text = str(score)
	kills_label.text = str(kills)
	time_label.text = "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
	best_label.text = str(Flow.best_score())
	for c in board.get_children():
		c.queue_free()
	for i in Flow.high_scores.size():
		var e: Dictionary = Flow.high_scores[i]
		var row := Label.new()
		row.theme_type_variation = &"HudSmall"
		row.text = "%d.  %8d   第 %d 波   %s" % [i + 1, e["score"], e["wave"], e["date"]]
		if i == rank:
			row.add_theme_color_override("font_color", Color(1, 0.6, 0.9))
		board.add_child(row)
	show()
	# 弹出动画：从 90% 缩放、透明，补间到正常
	panel.pivot_offset = panel.size / 2
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	retry_button.grab_focus()
