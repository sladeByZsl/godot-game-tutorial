## 事件总线（自动加载，名字叫 Events）。
## 只声明信号，不写逻辑。任何节点都可以 Events.xxx.emit()，任何节点都可以 Events.xxx.connect()，
## 发送方和接收方互相不需要知道对方在场景树的哪里。
extends Node

#region bus
signal gold_changed(total: int)
signal achievement_unlocked(title: String)
#endregion
