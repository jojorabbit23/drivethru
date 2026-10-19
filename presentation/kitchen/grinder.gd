# Cosmetic prop API: play_deposit(count). Inventory remains owned by game/.
extends Node3D
signal visual_finished
const P=preload("res://core/palette.gd")
const Sounds=preload("res://presentation/audio_library.gd")
var elapsed: float=2.0
var busy: bool=false
var handle: Node3D
var pellets: Array[MeshInstance3D]=[]
var input_caps: Array[MeshInstance3D]=[]
var motor: AudioStreamPlayer3D
var material_cache: Dictionary={}
func material(key: String) -> Material:
 if material_cache.has(key):return material_cache[key]
 var mat: Material=load("res://materials/"+key+".tres")
 material_cache[key]=mat
 return mat
func box(at: Vector3,size: Vector3,key: String,parent: Node3D=self) -> MeshInstance3D:
 var mesh:=BoxMesh.new()
 mesh.size=size
 return piece(mesh,at,key,parent)
func cylinder(at: Vector3,radius: float,height: float,key: String,parent: Node3D=self) -> MeshInstance3D:
 var mesh:=CylinderMesh.new()
 mesh.top_radius=radius
 mesh.bottom_radius=radius
 mesh.height=height
 mesh.radial_segments=10
 return piece(mesh,at,key,parent)
func piece(mesh: Mesh,at: Vector3,key: String,parent: Node3D) -> MeshInstance3D:
 var node:=MeshInstance3D.new()
 node.mesh=mesh
 node.material_override=material(key)
 parent.add_child(node)
 node.position=at
 return node
func _ready() -> void:
 add_to_group("mushroom_grinder")
 box(Vector3(0,0.018,0),Vector3(0.25,0.035,0.25),"kit_teal")
 box(Vector3(0,0.10,0),Vector3(0.09,0.17,0.11),"steel")
 var body: MeshInstance3D=cylinder(Vector3(0,0.23,0),0.075,0.26,"steel")
 body.rotation.z=-PI/2
 var spout: MeshInstance3D=cylinder(Vector3(0.17,0.22,0),0.047,0.12,"steel")
 spout.rotation.z=-PI/2
 var rim: MeshInstance3D=cylinder(Vector3(0.235,0.22,0),0.054,0.022,"metal")
 rim.rotation.z=-PI/2
 for i in 7:
  var angle: float=TAU*float(i)/7
  var hole: MeshInstance3D=cylinder(Vector3(0.249,0.22+sin(angle)*0.032,cos(angle)*0.032),0.007,0.002,"ink")
  hole.rotation.z=-PI/2
 cylinder(Vector3(-0.035,0.31,0),0.037,0.13,"steel")
 # Open hopper with four sloping sides and a dark throat.
 box(Vector3(-0.035,0.365,0),Vector3(0.09,0.009,0.09),"metal")
 for side in [-1.0,1.0]:
  var wall: MeshInstance3D=box(Vector3(-0.035+side*0.075,0.405,0),Vector3(0.012,0.10,0.20),"steel")
  wall.rotation.z=-side*0.45
  wall=box(Vector3(-0.035,0.405,side*0.075),Vector3(0.20,0.10,0.012),"steel")
  wall.rotation.x=side*0.45
 handle=Node3D.new()
 add_child(handle)
 handle.position=Vector3(-0.145,0.23,0)
 var axle: MeshInstance3D=cylinder(Vector3.ZERO,0.018,0.055,"metal",handle)
 axle.rotation.z=PI/2
 box(Vector3(-0.02,-0.07,0),Vector3(0.025,0.14,0.024),"steel",handle)
 var grip: MeshInstance3D=cylinder(Vector3(-0.05,-0.14,0),0.024,0.09,"paint_orange",handle)
 grip.rotation.z=PI/2
 # Receiving tray directly below the spout, with raised metal edges.
 box(Vector3(0.28,0.015,0),Vector3(0.24,0.025,0.21),"steel")
 for z in [-0.10,0.10]:box(Vector3(0.28,0.04,z),Vector3(0.25,0.055,0.012),"steel")
 for x in [0.16,0.40]:box(Vector3(x,0.04,0),Vector3(0.012,0.055,0.20),"steel")
 for i in 18:
  var pellet: MeshInstance3D=cylinder(Vector3.ZERO,0.011,0.028,"kit_stalk")
  pellet.hide()
  pellets.append(pellet)
 for i in 3:
  var cap: MeshInstance3D=cylinder(Vector3.ZERO,0.027,0.025,"kit_cap")
  cap.hide()
  input_caps.append(cap)
 motor=AudioStreamPlayer3D.new()
 motor.bus="Effects"
 motor.unit_size=2.0
 motor.max_distance=10.0
 motor.volume_db=-12.0
 add_child(motor)
 set_process(false)
func play_deposit(count: int=1) -> bool:
 # Reject overlapping/empty requests. Never changes stock or queues inventory work.
 if count<=0 or busy:return false
 elapsed=0.0
 busy=true
 set_process(true)
 if DisplayServer.get_name()!="headless":
  motor.stream=Sounds.sound("grinder")
  motor.play()
 advance(0.0)
 return true
func _process(delta: float) -> void:advance(delta)
func advance(delta: float) -> void:
 if not busy:return
 elapsed+=delta
 var ramp: float=smoothstep(0.0,0.18,elapsed)*(1.0-smoothstep(1.5,1.9,elapsed))
 handle.rotation.x+=delta*20.0*ramp
 for i in input_caps.size():
  var t: float=elapsed-float(i)*0.13
  input_caps[i].visible=t>=0.0 and t<0.5
  input_caps[i].position=Vector3(-0.035+sin(float(i))*0.025,0.50-maxf(0.0,t)*0.30,cos(float(i))*0.02)
 for i in pellets.size():
  var t: float=elapsed-0.4-float(i)*0.055
  pellets[i].visible=t>=0.0
  if t>=0.0:
   var fall: float=minf(t,0.36)
   pellets[i].position=Vector3(0.25+fall*0.20, maxf(0.045,0.22-1.4*fall*fall),sin(float(i)*2.4)*0.055)
   pellets[i].rotation=Vector3(float(i)*0.7,0,t*3.0 if t<0.36 else 1.0)
 if elapsed>=1.95:
  busy=false
  for cap in input_caps:cap.hide()
  set_process(false)
  visual_finished.emit()
