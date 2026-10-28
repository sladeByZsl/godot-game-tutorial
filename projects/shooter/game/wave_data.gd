## 一波敌人的描述。它是 Resource，可以存成 .tres，在检查器里直接编辑——
## 关卡设计改的是数据，不用碰代码。
class_name WaveData
extends Resource

enum Kind { DRONE, SHOOTER, TURRET }
enum Fire { NONE, AIMED, FAN, RING, SPIRAL }

#region fields
@export var label := ""                       ## 显示在屏幕上的名字
@export var kind := Kind.DRONE                ## 敌人类型（决定外形、血量基数）
@export var path_name: StringName = &"SwoopLeft"   ## 沿哪条 Path2D 飞
@export var mirror := false                   ## 同时在左右镜像的路径上各出一队
@export var count := 6                        ## 一队几架
@export var gap := 1.0                        ## 同队相邻两架的出发间隔（乘以全局"生成间隔"）
@export var speed_scale := 1.0                ## 相对全局"敌人速度"的倍数
@export var hp := 3                           ## 血量（还会乘以全局"血量倍数"）
@export var fire := Fire.NONE                 ## 射击方式
@export var fire_interval := 1.5              ## 射击间隔（秒）
@export_range(-1.0, 1.0) var hold_at := -1.0  ## 走到路径的这个比例时停下来（-1 表示不停）
@export var hold_time := 0.0                  ## 停多久
@export var wait_after := 3.0                 ## 这一波最后一架出发后，再等几秒开始下一波
@export_range(0.0, 1.0) var drop_chance := 0.12   ## 击落后掉道具的概率
#endregion
