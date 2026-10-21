extends "res://game/station.gd"
const Items=preload("res://game/burger_items.gd")
const Recipes=preload("res://game/recipes.gd")
const Slot=preload("res://game/serving_tray_slot.gd")
signal changed
var items: Array[Dictionary]=[{}, {}, {}, {}]
var boxes: Array[Node3D]=[]
var timers: Array[Label3D]=[]
var icons: Array[Sprite3D]=[]
var lids: Array[MeshInstance3D]=[]
var badges: Array[Sprite3D]=[]
var _warning: float=20.0
var warning_count: int=0
func _ready() -> void:
	add_box(Vector3(0.94,0.025,0.56),Vector3.ZERO,P.CONCRETE_GREY)
	for x in [-0.47,0.47]:add_box(Vector3(0.025,0.06,0.58),Vector3(x,0.02,0),P.WET_CHARCOAL)
	for z in [-0.28,0.28]:add_box(Vector3(0.94,0.06,0.025),Vector3(0,0.02,z),P.WET_CHARCOAL)
	for i in 4:
		var slot: Node3D=Slot.new()
		slot.tray=self
		slot.index=i
		slot.name="BoxSlot%d" % (i+1)
		slot.position=Vector3(-0.22+(i%2)*0.44,0.025,-0.13+(i/2)*0.26)
		add_child(slot)
		var carton:=Node3D.new()
		slot.add_child(carton)
		var box: MeshInstance3D=add_box(Vector3(0.37,0.09,0.22),Vector3(0,0.045,0),P.BURNT_ORANGE,carton)
		box.material_override=load("res://materials/serve_carton.tres")
		lids.append(add_box(Vector3(0.38,0.015,0.23),Vector3(0,0.095,0),P.AMBER_GLOW,carton))
		boxes.append(carton)
		var icon: Sprite3D=Icons.sprite("burger_brown",0.004)
		icon.position=Vector3(0,0.16,0)
		carton.add_child(icon)
		icons.append(icon)
		var badge: Sprite3D=Icons.sprite("freshness_fresh",0.003)
		badge.position=Vector3(0.11,0.16,0)
		carton.add_child(badge)
		badges.append(badge)
		var label: Label3D=add_label("",slot.position+Vector3(0,0.25,0),P.WARM_CHALK,20)
		timers.append(label)
	_no_shadows(self)
	refresh()
func _no_shadows(node: Node) -> void:
	if node is MeshInstance3D:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():_no_shadows(child)
func _physics_process(delta: float) -> void:
	var occupied: Array=[]
	for item: Dictionary in items:
		if not item.is_empty():occupied.append(item)
	var e: Node=economy()
	if Items.tick(occupied,delta,e!=null and e.has_serving_heater,self):refresh()
	var has_cold: bool=false
	for item: Dictionary in occupied:has_cold=has_cold or Items.cold(item)
	_warning=_warning-delta if has_cold else 20.0
	if _warning<=0.0:
		_warning=20.0
		warning_count+=1
		Sfx.play(self,"warning_tick",-24.0)
func recipe_name(item: Dictionary) -> String:
	return Recipes.name_of(String(item.get("kind","brown")))
func deposit(player: Node,index: int=-1) -> bool:
	if player.held!="burger":return false
	if index<0:
		for i in 4:
			if items[i].is_empty():index=i;break
	if index<0 or index>=4 or not items[index].is_empty():
		Sfx.play(self,"storage_full",-15.0)
		return false
	items[index]=player.take_selected_burger()
	refresh()
	changed.emit()
	Sfx.play(self,"storage_full" if not items.any(func(b: Dictionary) -> bool:return b.is_empty()) else "thunk",-12)
	return true
func pick_up(player: Node,index: int) -> bool:
	if index<0 or index>=4 or items[index].is_empty() or not player.can_carry_burger():return false
	if not player.add_burger(items[index]):return false
	items[index]={}
	refresh()
	changed.emit()
	return true
func take_matching(order: String,allow_discount: bool=true) -> Dictionary:
	# No reservations: freshest matching item available at the time of purchase.
	var chosen: int=-1
	for i in 4:
		if items[i].is_empty() or Items.spoiled(items[i]) or items[i].get("kind","")!=order:continue
		if chosen<0 or Items.age(items[i])<Items.age(items[chosen]):chosen=i
	if chosen<0 and allow_discount:
		for i in 4:
			if items[i].is_empty() or not items[i].get("discount",false) or Items.spoiled(items[i]):continue
			if chosen<0 or Items.age(items[i])<Items.age(items[chosen]):chosen=i
	if chosen<0:return {}
	var item: Dictionary=items[chosen]
	items[chosen]={}
	refresh()
	changed.emit()
	return item
func refresh() -> void:
	for i in boxes.size():
		var item: Dictionary=items[i]
		boxes[i].visible=not item.is_empty()
		timers[i].visible=not item.is_empty()
		if item.is_empty():continue
		(lids[i].material_override as StandardMaterial3D).albedo_color=Recipes.colour(String(item.get("kind","brown")))
		badges[i].texture=Icons.texture(Items.icon(item))
		timers[i].text=Items.timer(item)+("  SALE" if item.get("discount",false) else "")
		timers[i].modulate=P.AMBER_GLOW if Items.cold(item) else P.WARM_CHALK
		icons[i].texture=Icons.texture("burger_"+String(item.get("kind","brown")))
