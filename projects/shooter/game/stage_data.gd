## 一关 = 一串 WaveData。stage1.tres 就是这个类型的资源。
class_name StageData
extends Resource

@export var title := ""
@export var waves: Array[WaveData] = []
