## 游戏中的 HUD。它在 CanvasLayer（第 1 层）上：不受 Camera2D 震动影响，也不吃 WorldEnvironment 的发光。
class_name Hud
extends CanvasLayer

@onready var score_label: Label = %Score
@onready var best_label: Label = %Best
@onready var lives_label: Label = %Lives
@onready var bombs_label: Label = %Bombs
@onready var power_bar: ProgressBar = %Power
@onready var shield_label: Label = %Shield
@onready var wave_label: Label = %Wave
@onready var wave_name: Label = %WaveName
@onready var pool_label: Label = %PoolMode
@onready var perf_label: Label = %Perf
@onready var boss_box: Control = %BossBox
@onready var boss_bar: ProgressBar = %BossBar
@onready var boss_phase_label: Label = %BossPhase
@onready var banner_box: Control = %BannerBox
@onready var banner_title: Label = %BannerTitle
@onready var banner_sub: Label = %BannerSub
@onready var flash_rect: ColorRect = %Flash

var _banner_tween: Tween


func _ready() -> void:
	boss_box.hide()
	banner_box.modulate.a = 0.0


func set_status(score: int, best: int, lives: int, bombs: int, power: int, shield: bool) -> void:
	score_label.text = "%08d" % score
	best_label.text = "%08d" % best
	lives_label.text = "♥".repeat(lives) if lives > 0 else "—"
	bombs_label.text = "★".repeat(bombs) if bombs > 0 else "—"
	power_bar.value = power
	shield_label.text = "有" if shield else "无"


func set_perf(pooled: bool, live: int, idle: int, per_sec: int, frame_ms: float, worst_ms: float) -> void:
	pool_label.text = "开" if pooled else "关"
	pool_label.modulate = Color(0.5, 1, 0.7) if pooled else Color(1, 0.5, 0.5)
	perf_label.text = "活动子弹  %d\n池中空闲  %d\n新建/秒  %d\n帧时间  %.1f ms\n最差帧  %.1f ms" % [
		live, idle, per_sec, frame_ms, worst_ms]


func banner(title: String, sub := "", color := Color(1, 1, 1)) -> void:
	banner_title.text = title
	banner_sub.text = sub
	banner_title.modulate = color
	if title.begins_with("第"):
		wave_label.text = title
		wave_name.text = sub
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner_box, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(1.4)
	_banner_tween.tween_property(banner_box, "modulate:a", 0.0, 0.5)


func warning() -> void:
	banner("WARNING", "强敌接近", Color(1.3, 0.4, 0.5))
	wave_label.text = "Boss"
	wave_name.text = "警告"


func show_boss(on: bool) -> void:
	boss_box.visible = on


func set_boss_hp(ratio: float) -> void:
	boss_bar.value = ratio * 100.0


func boss_phase(phase_name: String) -> void:
	boss_phase_label.text = phase_name
	wave_name.text = phase_name


func flash() -> void:
	flash_rect.color.a = 0.7
	create_tween().tween_property(flash_rect, "color:a", 0.0, 0.5)
