## 演示用：一份"敌人模板"资源。注意 hp 这种会变的数值不该放在这里（见 duplicate_trap.gd）。
class_name EnemyData
extends Resource

@export var display_name := "史莱姆"
@export var max_hp := 3
@export var hp := 3          # ← 反例：每只敌人各自的状态被放进了共享资源
