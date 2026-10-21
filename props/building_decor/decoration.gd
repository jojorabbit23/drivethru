extends "res://game/station.gd"
@export var mode: String="static"
@export var hit_size:=Vector3.ZERO
@export var hit_centre:=Vector3.ZERO
@export var solid: bool=true
@export var max_health: float=50.0
@export var linked_path: NodePath
var health: float=50.0
var broken: bool=false
var knocked: bool=false
var rings: int=0
var wear: float=0.0
func _ready() -> void:
 health=max_health
 if mode in ["breakable","knockable","cover"] and hit_size.length()>0:
  var body: CollisionObject3D=StaticBody3D.new() if solid else Area3D.new();body.name="DamageProxy";body.set_script(preload("res://props/building_decor/damage_proxy.gd"));body.collision_layer=1;body.collision_mask=0
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=hit_size;shape.shape=box;shape.position=hit_centre;body.add_child(shape);add_child(body)
  add_to_group("building_destructibles")
 if mode in ["bell","door","ticket","weapons","knockable"]:
  add_zone(hit_size if hit_size.length()>0 else Vector3(.35,.35,.35),hit_centre)
func linked() -> Node:
 var main: Node=get_tree().get_first_node_in_group("decorated_game")
 return main.get_node_or_null(linked_path) if main and not linked_path.is_empty() else null
func prompt(player: Node) -> String:
 if broken:return ""
 match mode:
  "bell":return "E  ring service bell"
  "door":
   var target:=linked()
   return target.prompt(player) if target and target.has_method("prompt") else "CLOSED"
  "ticket":return "E  read order ticket"
  "weapons":return "E  weapon shelf"
  "knockable":return "E  knock over" if not knocked else ""
 return ""
func interact(player: Node) -> void:
 if broken or player.is_dead():return
 match mode:
  "bell":rings+=1;Sfx.play_at(self,"bell",global_position,-1.0)
  "door":
   var target:=linked()
   if target and target.has_method("interact"):
    target.interact(player)
    if target.get("unlocked")==true:
     for child in get_children():
      if child is GeometryInstance3D:child.hide()
     get_node("Zone").collision_layer=0
  "ticket":
   var target:=linked()
   var car: Node=target.current_car() if target else null
   var text: String=preload("res://game/recipes.gd").ticket_text(car.order,car.quantity-car.received) if car else "NO ORDERS"
   player.open_menu(self,[{"label":text,"enabled":true,"icon":"burger","action":func()->void:pass}])
  "weapons":
   var rows: Array=[]
   for i in player.weapons.size():
    var weapon: Node=player.weapons[i]
    var title: String=String(weapon.get("display_name")) if weapon.get("display_name")!=null else ("KNIFE" if i==1 else "DAGGER")
    if weapon.get_meta("purchased",true):rows.append({"label":title,"enabled":true,"icon":"ammo","action":player.switch_weapon.bind(i)})
   player.open_menu(self,rows)
  "knockable":knock()
func take_prop_damage(amount: float) -> void:
 if amount<=0 or broken:return
 if mode=="knockable":knock();return
 if not mode in ["breakable","cover"]:return
 health-=amount
 if health<=0:shatter()
func knock() -> void:
 if knocked or broken:return
 knocked=true
 var proxy:=get_node_or_null("DamageProxy") as CollisionObject3D
 if proxy:proxy.collision_layer=0
 var tw:=create_tween();tw.tween_property(self,"rotation:z",rotation.z+1.25,.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
 Sfx.play_at(self,"thunk",global_position,-10)
func shatter() -> void:
 if broken:return
 broken=true
 var proxy:=get_node_or_null("DamageProxy") as CollisionObject3D
 if proxy:proxy.collision_layer=0
 for child in get_children():
  if child is GeometryInstance3D:child.hide()
 var zone:=get_node_or_null("Zone") as CollisionObject3D
 if zone:zone.collision_layer=0
 if DisplayServer.get_name()!="headless" and get_tree().get_nodes_in_group("decor_scraps").size()<6:
  var scraps:=Node3D.new();get_parent().add_child(scraps);scraps.add_to_group("decor_scraps");scraps.global_position=global_position
  var mesh:=BoxMesh.new();mesh.size=Vector3(.4,.045,.09)
  var mat:=StandardMaterial3D.new();mat.albedo_color=preload("res://props/building_decor/palette.gd").RUST;mesh.material=mat
  for i in 6:
   var plank:=MeshInstance3D.new();plank.mesh=mesh;plank.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;scraps.add_child(plank)
   var tw:=plank.create_tween();tw.tween_property(plank,"position",Vector3(sin(i*2.3)*.6,-global_position.y+.05,cos(i*2.3)*.6),.4)
   tw.parallel().tween_property(plank,"rotation",Vector3(i*.4,i*1.2,.2),.4)
  get_tree().create_timer(7).timeout.connect(scraps.queue_free)
 Sfx.play_at(self,"thunk",global_position,-6)
func apply_wear(amount: float) -> void:
 wear=clampf(amount,0,1)
 var cracks:=get_node_or_null("Cracks") as Node3D
 if cracks:cracks.visible=wear>.15
 var paper:=get_node_or_null("Paper") as MeshInstance3D
 if paper and paper.material_override is ShaderMaterial:paper.material_override.set_shader_parameter("wear",wear)
 if name=="EXT_tape_hazard":
  var mesh:=get_node_or_null("Mesh") as Node3D
  if mesh:mesh.scale.x=maxf(.2,1.0-wear*.8)
