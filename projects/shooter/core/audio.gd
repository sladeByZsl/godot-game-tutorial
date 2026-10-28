## 音频管理（自动加载，名字叫 Audio）。
## - 每种音效一个 AudioStreamPlayer，用 max_polyphony 控制同时最多响几个
## - 爆炸用一小组 AudioStreamPlayer2D，按位置左右声像
## - 音量走总线：Music / SFX 两条总线都送到 Master
## - Web 上要等玩家第一次按键/点击之后才开始放音乐
extends Node

const SFX := {
	"shoot": preload("res://audio/shoot.wav"),
	"enemy_shot": preload("res://audio/enemy_shot.wav"),
	"explosion": preload("res://audio/explosion.wav"),
	"big_explosion": preload("res://audio/big_explosion.wav"),
	"pickup": preload("res://audio/pickup.wav"),
	"hurt": preload("res://audio/hurt.wav"),
	"ui_move": preload("res://audio/ui_move.wav"),
	"ui_ok": preload("res://audio/ui_ok.wav"),
}
const BGM := preload("res://audio/bgm.ogg")
const POSITIONAL_VOICES := 8
const MUFFLED_GAIN := 0.45

#region params
@export_range(0.0, 1.0) var music_volume := 0.6:
	set(v):
		music_volume = v
		_apply_bus_volume(&"Music", v * (MUFFLED_GAIN if _muffled else 1.0))
@export_range(0.0, 1.0) var sfx_volume := 0.8:
	set(v):
		sfx_volume = v
		_apply_bus_volume(&"SFX", v)
@export_range(0.0, 0.5) var random_pitch := 0.08     ## 每次播放随机改变音高的幅度（±比例）
@export_range(1, 32) var max_polyphony := 6:          ## 同一个音效最多同时响几个
	set(v):
		max_polyphony = v
		for p: AudioStreamPlayer in _players.values():
			p.max_polyphony = v
#endregion

var _players: Dictionary[String, AudioStreamPlayer] = {}
var _voices_2d: Array[AudioStreamPlayer2D] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _unlocked := not OS.has_feature("web")    # 桌面版不需要等
var _want_music := false
var _muffled := false
var plays_this_second := 0                   # 统计用：每秒请求播放了多少次
var _plays_counter := 0
var _count_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS    # 暂停菜单里也要能响
	#region players
	for sfx_name: String in SFX:
		var p := AudioStreamPlayer.new()
		p.stream = SFX[sfx_name]
		p.bus = &"SFX"
		p.max_polyphony = max_polyphony
		add_child(p)
		_players[sfx_name] = p
	for i in POSITIONAL_VOICES:
		var p2 := AudioStreamPlayer2D.new()
		p2.bus = &"SFX"
		p2.max_distance = 1400.0
		add_child(p2)
		_voices_2d.append(p2)
	_music = AudioStreamPlayer.new()
	_music.stream = BGM
	_music.bus = &"Music"
	add_child(_music)
	#endregion
	music_volume = music_volume       # 触发 setter，把初始音量写进总线
	sfx_volume = sfx_volume
	Tuning.bind(self, "audio", ["music_volume", "sfx_volume", "random_pitch", "max_polyphony"])


#region play
## 播放一个非定位音效（射击、拾取、UI）。
func play(sfx_name: String, volume_db := 0.0) -> void:
	var p: AudioStreamPlayer = _players.get(sfx_name)
	if p == null:
		return
	_plays_counter += 1
	p.volume_db = volume_db
	# 随机音高：同一个声音连发几十次也不会像"机关枪录音"。
	# 注意 pitch_scale 是整个节点的属性，会影响它正在响的其他声部；短音效听不出来。
	p.pitch_scale = 1.0 + randf_range(-random_pitch, random_pitch)
	p.play()     # max_polyphony > 1 时，play() 会新开一个声部；满了就掐掉最老的


## 在某个位置播放（爆炸）。AudioStreamPlayer2D 会根据它和摄像机的相对位置算左右声像和衰减。
func play_at(sfx_name: String, global_pos: Vector2, volume_db := 0.0) -> void:
	_plays_counter += 1
	var p := _voices_2d[_next_voice]
	_next_voice = (_next_voice + 1) % _voices_2d.size()   # 轮流使用，最老的被复用
	p.stream = SFX[sfx_name]
	p.global_position = global_pos
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-random_pitch, random_pitch)
	p.play()
#endregion


#region unlock
## 浏览器的自动播放策略：用户和页面交互之前，声音不允许播放。
## Godot 收到第一次输入时会恢复 AudioContext；这里也等到那一刻再开始放音乐，
## 这样玩家不会错过开头，也不会在后台"无声地"播完前奏。
func play_music() -> void:
	_want_music = true
	if _unlocked and not _music.playing:
		_music.play()


func _input(event: InputEvent) -> void:
	if _unlocked:
		return
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
			or event is InputEventScreenTouch) and event.is_pressed():
		_unlocked = true
		if _want_music:
			_music.play()
#endregion


#region muffle
## 暂停时把音乐"闷"住：打开 Music 总线上的低通滤波器，并压低音量。
## 低通是总线效果器，Web 默认的 Sample 播放模式不支持效果器，所以再叠一个降音量，两边都能听出变化。
func set_muffled(on: bool) -> void:
	_muffled = on
	var bus := AudioServer.get_bus_index(&"Music")
	var lowpass := AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	lowpass.cutoff_hz = 900.0 if on else 20000.0
	music_volume = music_volume      # 重新走一遍 setter，按 _muffled 算音量
#endregion


func _apply_bus_volume(bus_name: StringName, linear: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(linear, 0.0001)))   # 0~1 的线性值换成分贝
	AudioServer.set_bus_mute(bus, linear <= 0.001)


func _process(delta: float) -> void:
	_count_timer += delta
	if _count_timer >= 1.0:
		_count_timer = 0.0
		plays_this_second = _plays_counter
		_plays_counter = 0


func _exit_tree() -> void:
	# 退出时先停掉所有声音，否则正在播放的流还被音频服务器引用着，退出时会报"资源仍在使用"
	for p in get_children():
		p.stop()
		p.stream = null
