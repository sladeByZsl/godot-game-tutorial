## 一句台词。在检查器里新建 DialogueLine 资源就能直接填。
#region line
class_name DialogueLine
extends Resource

@export var speaker := ""
@export_multiline var text := ""                 ## 可以写 {left} 这类占位符，见 Game.format_text()
@export var choices: PackedStringArray = []      ## 非空时，这句播完后让玩家选
@export var choice_flags: PackedStringArray = [] ## 选第 i 项时设置的全局标记（可以留空）
#endregion
