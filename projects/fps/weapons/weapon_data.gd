## 一把武器的全部数值。做成 Resource，存成 .tres 文件，在检查器里就能调，
## 也方便多个场景共用同一份数据（步枪和霰弹枪只是两份不同的 WeaponData）。
class_name WeaponData
extends Resource

#region data
@export var display_name := "步枪"
@export var damage := 22.0              ## 每发（每颗弹丸）伤害
@export var fire_rate := 10.0           ## 射速（发/秒）
@export var automatic := true           ## 按住连发；false 时每次点击只打一发
@export var mag_size := 30              ## 弹匣容量
@export var reload_time := 1.5          ## 换弹时间（秒）
@export var pellets := 1                ## 每发弹丸数（霰弹枪 > 1）
@export var max_range := 120.0          ## 射线长度（米）

@export_group("散布与后坐力")
@export var spread := 0.6               ## 基础散布：静止站立时弹道偏离准星的最大角度（半角，度）
@export var spread_per_shot := 0.45     ## 每开一枪，散布增加多少度
@export var max_spread := 5.0           ## 连射散布的上限
@export var spread_recover := 10.0      ## 停火后散布每秒恢复多少度
@export var move_spread := 1.5          ## 以行走速度移动时额外增加的散布
@export var recoil := 1.2               ## 每发让视角上跳多少度
#endregion
