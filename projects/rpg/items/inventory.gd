## 背包：固定 8 格，每格是一个 Slot（引用共享的 ItemData + 自己的数量）。
class_name Inventory
extends RefCounted

signal changed

const SIZE := 8

#region slot
class Slot:
	var item: ItemData   # 共享、只读
	var count := 0       # 每格自己的状态

	func _init(i: ItemData, n: int) -> void:
		item = i
		count = n
#endregion

var slots: Array[Slot] = []


func _init() -> void:
	slots.resize(SIZE)


func clear() -> void:
	slots.fill(null)
	changed.emit()


#region add
## 放入物品，先叠加到同类格子，再放进空格。返回放不下的数量。
func add(item: ItemData, amount := 1) -> int:
	for s in slots:
		if amount > 0 and s != null and s.item.id == item.id and s.count < item.max_stack:
			var n := mini(amount, item.max_stack - s.count)
			s.count += n
			amount -= n
	for i in SIZE:
		if amount > 0 and slots[i] == null:
			var n := mini(amount, item.max_stack)
			slots[i] = Slot.new(item, n)
			amount -= n
	changed.emit()
	return amount
#endregion


func remove_at(index: int, amount := 1) -> void:
	var s := slots[index]
	if s == null:
		return
	s.count -= amount
	if s.count <= 0:
		slots[index] = null
	changed.emit()


func count_of(id: StringName) -> int:
	var n := 0
	for s in slots:
		if s != null and s.item.id == id:
			n += s.count
	return n


#region serialize
func to_save() -> Array:
	var out := []
	for s in slots:
		out.append(null if s == null else {"id": String(s.item.id), "count": s.count})
	return out


func from_save(data: Array, db: Dictionary) -> void:
	slots.fill(null)
	for i in mini(data.size(), SIZE):
		var d: Variant = data[i]
		if d is Dictionary and db.has(StringName(d["id"])):
			slots[i] = Slot.new(db[StringName(d["id"])], int(d["count"]))
	changed.emit()
#endregion
