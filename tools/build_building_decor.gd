extends SceneTree
const C=preload("res://props/building_decor/palette.gd")
const Geometry=preload("res://tools/decor_mesh.gd")
const Decoration=preload("res://props/building_decor/decoration.gd")
const OUT="res://props/building_decor/generated/"
var scene: Node3D
var item: Node3D
var b: RefCounted
var catalogue: Dictionary={}
func _initialize() -> void:
 scene=Node3D.new();scene.set_script(preload("res://props/building_decor/building_decor.gd"));scene.name="BuildingDecorations"
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://art/building_decor/catalogue.json"))
 for row: Dictionary in rows:catalogue[row.id]=row
 build()
 var packed:=PackedScene.new();assert(packed.pack(scene)==OK);assert(ResourceSaver.save(packed,OUT+"building_decor.tscn")==OK)
 print("Saved decoration guide: ",scene.get_child_count()," / ",catalogue.size()," individually placeable objects")
 assert(scene.get_child_count()==catalogue.size())
 scene.free();quit()
func begin(id: String,at: Vector3,yaw: float=0.0,mode: String="static",existing: String="") -> void:
 item=Node3D.new();item.set_script(Decoration);item.name=id;item.position=at;item.rotation.y=deg_to_rad(yaw);item.mode=mode
 if mode=="knockable" or id=="BACK_crates":item.solid=false
 item.set_meta("guide",catalogue[id]);item.set_meta("guide_id",id)
 if existing!="":item.linked_path=NodePath(existing);item.set_meta("reuses_existing",true)
 b=Geometry.new()
func end() -> void:
 if not b.v.is_empty():
  var mi:=MeshInstance3D.new();mi.name="Mesh";mi.mesh=b.finish();mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;item.add_child(mi)
  if item.mode in ["breakable","cover","knockable"]:
   var bounds: AABB=mi.mesh.get_aabb();item.hit_size=bounds.size.max(Vector3(.06,.06,.06));item.hit_centre=bounds.get_center()
 own(item,item)
 var position: Vector3=item.position;var angle: Vector3=item.rotation
 item.position=Vector3.ZERO;item.rotation=Vector3.ZERO
 var packed:=PackedScene.new();assert(packed.pack(item)==OK);assert(ResourceSaver.save(packed,OUT+String(item.name)+".tscn")==OK)
 var path: String=OUT+String(item.name)+".tscn";item.free()
 var placed: Node3D=load(path).instantiate();placed.position=position;placed.rotation=angle;scene.add_child(placed);placed.owner=scene
func own(node: Node,root: Node) -> void:
 for child in node.get_children():child.owner=root;own(child,root)
func text(value: String,at: Vector3,width: float=.6,colour: Color=C.CREAM,name: String="Text") -> Label3D:
 var label:=Label3D.new();label.name=name;label.text=value;label.position=at;label.modulate=colour;label.font_size=18;label.outline_size=0;label.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 label.font=preload("res://fonts/pixel/pixel_font.tres")
 var longest: float=1
 for line: String in value.split("\n"):longest=maxf(longest,label.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size).x)
 label.pixel_size=minf(.008,width/longest);label.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 item.add_child(label);return label
func make_sign(value: String,width: float,height: float,colour: Color=C.CREAM,ink: Color=C.CHARCOAL,at: Vector3=Vector3.ZERO) -> void:
 b.box(at,Vector3(width,height,.025),colour)
 # Sparse edge chips keep wear local to each sign, leaving room tiles calm.
 for i in 9:
  var x: float=sin(i*12.3)*width*.46
  var y: float=(height*.46)*(1 if i%2==0 else -1)
  b.box(at+Vector3(x,y,.015),Vector3(.012+float(i%3)*.008,.012,.004),C.RUST)
 var writing:=text(value,at+Vector3(0,0,.018),width*.88,ink)
 writing.pixel_size=minf(writing.pixel_size,height*.75/(value.split("\n").size()*writing.font.get_height(writing.font_size)))
 # Chipped corners and two old screw heads are part of the same mesh.
 for side in [-1,1]:b.box(at+Vector3(side*(width*.5-.03),height*.5-.03,.018),Vector3(.025,.025,.008),C.STEEL)
func fungal(at: Vector3,size: float=1.0) -> void:
 b.cylinder(at+Vector3(0,.08*size,0),.035*size,.16*size,C.CREAM)
 b.cylinder(at+Vector3(0,.16*size,0),.14*size,.075*size,C.OLIVE,.02*size)
 b.box(at+Vector3(.06*size,.2*size,0),Vector3(.045,.02,.045)*size,C.EMBER)
func cracks() -> void:
 var mesh:=Geometry.new()
 mesh.beam(Vector3(-.20,-.18,.025),Vector3(.08,.12,.025),.012,C.CREAM)
 mesh.beam(Vector3(.08,.12,.025),Vector3(.22,.06,.025),.009,C.CREAM)
 var root:=MeshInstance3D.new();root.name="Cracks";root.mesh=mesh.finish();root.visible=false;root.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;item.add_child(root)
func glow(name: String,at: Vector3,size: Vector3,colour: Color) -> void:
 var mi:=MeshInstance3D.new();mi.name=name;var mesh:=BoxMesh.new();mesh.size=size;mi.mesh=mesh;mi.position=at
 var mat:=StandardMaterial3D.new();mat.albedo_color=colour;mat.emission_enabled=true;mat.emission=colour;mat.emission_energy_multiplier=.35;mi.material_override=mat;mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;item.add_child(mi)
func car(minivan: bool) -> void:
 var colour: Color=C.LIGHT_TEAL if minivan else C.RUST
 b.box(Vector3(0,.62,0),Vector3(1.8,.65,3.9),colour)
 b.box(Vector3(0,1.28,.35),Vector3(1.6,.68,2.4 if minivan else 1.45),C.MIDNIGHT)
 b.box(Vector3(0,1.65,.35),Vector3(1.75,.13,2.5 if minivan else 1.5),colour)
 for x in [-.92,.92]:
  for z in [-1.25,1.25]:
   b.box(Vector3(x,.3,z),Vector3(.23,.48 if x<0 and z<0 else .65,.65),C.CHARCOAL)
   b.box(Vector3(x*1.01,.3,z),Vector3(.24,.24,.25),C.STEEL)
 for x in [-.62,.62]:b.box(Vector3(x,.73,-2),Vector3(.3,.16,.04),C.CREAM)
 b.box(Vector3(0,.48,-2),Vector3(1.85,.16,.12),C.STEEL)
 if minivan:
  b.box(Vector3(.95,1.12,.8),Vector3(.08,.95,1.25),C.TEAL,Vector3(0,.65,0))
  b.box(Vector3(.96,.85,-.3),Vector3(.1,.1,.5),C.RUST)
func build() -> void:
 begin("EXT_roof_sign",Vector3(-3,3.15,-4.85),180)
 b.box(Vector3(0,.65,0),Vector3(.16,1.3,.16),C.CHARCOAL);b.cylinder(Vector3(0,1.55,0),1.2,.28,C.ORANGE,.25)
 make_sign("DRIVE THR",2.0,.45,C.CHARCOAL,C.CREAM,Vector3(0,1.13,.62));item.get_node("Text").name="Letters"
 b.box(Vector3(-.85,1.12,.66),Vector3(.1,.1,.04),C.STEEL);b.box(Vector3(.85,1.12,.66),Vector3(.1,.1,.04),C.AMBER);glow("FlickeringBulb",Vector3(.85,1.12,.69),Vector3(.08,.08,.025),C.AMBER);end()
 begin("EXT_barricade_table",Vector3(12.7,0,.2),0,"breakable")
 for i in 5:b.box(Vector3((i-2)*.15,.65,0),Vector3(.13,1.3,.10),C.RUST)
 for x in [-.32,.32]:b.beam(Vector3(x,.1,0),Vector3(x,.5,.8),.1,C.DEEP_TEAL)
 end()
 begin("EXT_barricade_menu",Vector3(3,1.2,11.66),0,"breakable");make_sign("CLOSED\nTRY THE WINDOW",1.15,1.5,C.CHARCOAL,C.CREAM);end()
 begin("EXT_barricade_cones",Vector3(8.5,0,1.1),0,"knockable")
 b.box(Vector3(0,.035,0),Vector3(.48,.07,.48),C.CHARCOAL);b.cylinder(Vector3(0,.32,0),.20,.55,C.ORANGE,.025);b.cylinder(Vector3(0,.38,0),.12,.12,C.CREAM,.085);end()
 begin("EXT_barricade_pallets",Vector3(-10,0,4.5),15,"breakable")
 for layer in 3:
  for i in 5:b.box(Vector3((i-2)*.2,.12+layer*.2,0),Vector3(.17,.06,.95),C.RUST)
  for x in [-.4,.4]:b.box(Vector3(x,.05+layer*.2,0),Vector3(.1,.1,.9),C.SLATE)
 end()
 begin("EXT_tape_hazard",Vector3(12.7,.85,.29))
 for i in 12:b.box(Vector3((i-6)*.075,0,0),Vector3(.075,.065,.012),C.TEAL if i%2==0 else C.CHARCOAL)
 end()
 for entry: Array in [["EXT_decal_nowserving","NOW\nSERVING",Vector3(-3.7,1.65,-5.17)],["EXT_decal_combo","ASK ABOUT\nOUR COMBO",Vector3(-2.25,1.65,-5.17)]]:
  begin(entry[0],entry[2],180);make_sign(entry[1],.4,.3,C.DEEP_TEAL,C.CREAM);cracks();end()
 begin("EXT_plywood",Vector3(-2.15,1.75,-5.17),0,"breakable")
 for i in 3:b.box(Vector3(0,(i-1)*.15,0),Vector3(.42,.12,.055),C.RUST,Vector3(0,0,.08*(i-1)))
 end()
 for entry: Array in [["EXT_sign_norefunds","NO REFUNDS\nAFTER THE\nAPOCALYPSE",Vector3(-.85,1.8,-5.2),C.ORANGE],["EXT_sign_limbs","MANAGEMENT NOT\nRESPONSIBLE FOR\nLOST LIMBS",Vector3(4.4,1.9,11.74),C.DEEP_TEAL]]:
  begin(entry[0],entry[2],180 if entry[0]=="EXT_sign_norefunds" else 0);make_sign(entry[1],1.1,.6,entry[3]);end()
 begin("EXT_fungus_shelf",Vector3(5.95,2.8,-2.4),90)
 for i in 9:fungal(Vector3((i-4)*.18,0,.06),.7+float(i%3)*.2)
 end()
 begin("EXT_fungus_moss",Vector3(6.22,.35,4.3),90)
 for i in 7:b.box(Vector3((i%3)*.13,(i/3)*.1,0),Vector3(.18,.14,.035),C.OLIVE if i%2==0 else C.SPORE)
 glow("Bioluminescence",Vector3(.12,.12,.025),Vector3(.22,.12,.01),C.SPORE)
 end()
 begin("EXT_vehicle_pickup",Vector3(-14,0,10),-25,"cover");car(false);item.max_health=250;end()
 begin("EXT_vehicle_minivan",Vector3(-13,0,-15),15,"cover");car(true);item.max_health=250;end()
 begin("EXT_decal_kidseatfree",Vector3(-12.49,1.2,-13.1),15);make_sign("KIDS EAT FREE",.8,.18,C.ORANGE);end()
 begin("LANE_menu_board",Vector3(-14,0,-11.3),180,"breakable")
 b.box(Vector3(0,.7,0),Vector3(.12,1.4,.12),C.STEEL);make_sign("TODAY'S M NU\nREGULAR   $30\nBLUE      $30\nYELLOW    $30\nDOUBLE    $50\nSPECIAL   $60",1.35,1.5,C.CHARCOAL,C.CREAM,Vector3(0,1.9,0));end()
 begin("LANE_speaker_post",Vector3(-11.5,0,-11.15),180)
 b.box(Vector3(0,.7,0),Vector3(.18,1.4,.18),C.STEEL);b.box(Vector3(0,1.4,0),Vector3(.4,.55,.24),C.CHARCOAL)
 for i in 6:b.box(Vector3(0,1.27+i*.04,.13),Vector3(.30,.012,.01),C.STEEL)
 make_sign("WELCOME",.38,.10,C.CREAM,C.CHARCOAL,Vector3(0,1.73,.13))
 for i in 4:b.beam(Vector3((i-2)*.06,1.3,.15),Vector3((i-2)*.07,1.05,.15),.014,C.OLIVE)
 end()
 begin("LANE_clearance_bar",Vector3(-18,0,-8),-90)
 b.beam(Vector3(-2.7,0,0),Vector3(-2.7,3.4,0),.14,C.STEEL);b.beam(Vector3(-2.7,3.4,0),Vector3(2,3.4,0),.14,C.STEEL);b.beam(Vector3(2,3.4,0),Vector3(2.2,2.8,0),.14,C.STEEL)
 make_sign("MAX HEIGHT 2.1M",2,.28,C.ORANGE,C.CREAM,Vector3(0,3.4,.1));b.box(Vector3(2.1,2.53,0),Vector3(.18,.4,.12),C.EMBER);end()
 begin("LANE_arrows",Vector3(-11,.012,-8))
 b.box(Vector3(0,0,0),Vector3(1,.003,.1),C.CREAM)
 b.beam(Vector3(.5,0,0),Vector3(.15,0,.35),.07,C.CREAM);b.beam(Vector3(.5,0,0),Vector3(.15,0,-.35),.07,C.CREAM);end()
 begin("LANE_oil_stains",Vector3(-22,.012,-8));b.cylinder(Vector3.ZERO,.6,.003,C.CHARCOAL);b.cylinder(Vector3(.3,.003,0),.3,.003,C.MIDNIGHT);end()
 begin("LANE_claw_gouges",Vector3(9,.015,-10.4))
 for i in 3:b.beam(Vector3(i*.08,0,0),Vector3(i*.08+.4,0,.45),.025,C.SLATE)
 end()
 begin("WIN_sliding_window",Vector3(-3,1.5,-4.99))
 for x in [-.85,.85]:b.box(Vector3(x,0,0),Vector3(.025,1,.025),C.STEEL)
 for y in [-.49,.49]:b.box(Vector3(0,y,0),Vector3(1.7,.025,.025),C.STEEL)
 b.box(Vector3(.66,0,0),Vector3(.02,1,.03),C.STEEL)
 var glass:=MeshInstance3D.new();glass.name="Glass";var pane:=QuadMesh.new();pane.size=Vector2(.18,.94);glass.mesh=pane;glass.position=Vector3(.75,0,0)
 var glass_mat:=StandardMaterial3D.new();glass_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass_mat.albedo_color=Color(.38,.71,.69,.14);glass_mat.cull_mode=BaseMaterial3D.CULL_DISABLED;glass.material_override=glass_mat;glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;item.add_child(glass)
 for i in 3:b.beam(Vector3(.69,-.3+i*.2,.005),Vector3(.79,-.23+i*.2,.005),.003,C.STEEL)
 cracks();end()
 begin("WIN_sign_knock",Vector3(-3.65,1.76,-4.91));make_sign("PLEASE\nKNOCK",.25,.22);end()
 begin("WIN_bell",Vector3(-4.52,1.02,-4.31),0,"bell")
 b.cylinder(Vector3(0,.025,0),.085,.05,C.RUST);b.cylinder(Vector3(0,.075,0),.07,.07,C.AMBER,.035);b.cylinder(Vector3(0,.13,0),.018,.025,C.STEEL);item.hit_size=Vector3(.25,.25,.25);end()
 begin("WIN_tray_shelf",Vector3(-3,1.02,-4.4),0,"static","ServingTray")
 b.box(Vector3(0,-.015,.21),Vector3(1.45,.018,.025),C.STEEL)
 for i in 3:b.cylinder(Vector3(-.45+i*.4,-.003,.16),.035,.002,C.CHARCOAL)
 end()
 begin("WIN_napkins",Vector3(-4.14,1.02,-4.5))
 b.box(Vector3(0,.12,0),Vector3(.22,.24,.17),C.STEEL);b.box(Vector3(0,.16,.09),Vector3(.16,.08,.012),C.CREAM);end()
 begin("WIN_special_card",Vector3(-.95,1.17,-4.15));make_sign("TODAY'S SPECIAL\nASK WHAT'S IN IT",.42,.25,C.CREAM,C.ORANGE);end()
 begin("WIN_ticket_rail",Vector3(1.4,2.15,-4.72),0,"ticket","OrderRail");b.box(Vector3(0,.09,.01),Vector3(.5,.025,.06),C.AMBER);item.hit_size=Vector3(.6,.35,.25);end()
 begin("WIN_feedback_box",Vector3(-.16,1.8,-3.5),-90)
 b.box(Vector3.ZERO,Vector3(.35,.4,.18),C.TEAL);b.box(Vector3(0,.11,.10),Vector3(.22,.025,.01),C.CHARCOAL)
 for x in [-.1,0,.1]:b.box(Vector3(x,-.1,.12),Vector3(.055,.07,.025),C.STEEL)
 text("FEEDBACK",Vector3(0,.02,.105),.3,C.CREAM);end()
 begin("KIT_grill",Vector3(2.1,.92,-4.425),0,"static","Grill");b.box(Vector3(0,-.06,.31),Vector3(1,.025,.025),C.STEEL);end()
 begin("KIT_fryer",Vector3(3.12,.95,-4.4))
 for x in [-.2,.2]:
  for z in [-.15,.15]:b.box(Vector3(x,0,z),Vector3(.02,.12,.32) if absf(x)>.1 else Vector3(.38,.12,.02),C.STEEL)
 for i in 7:b.box(Vector3(-.18+i*.06,.015,0),Vector3(.012,.1,.3),C.STEEL)
 b.beam(Vector3(0,.05,.14),Vector3(0,.16,.4),.025,C.CHARCOAL);end()
 begin("KIT_hood_vent",Vector3(2.1,2.45,-4.55),0,"static","ShopGreybox")
 for i in 6:b.box(Vector3(-.55+i*.22,-.18,.32),Vector3(.1,.13,.018),C.RUST)
 end()
 begin("KIT_sign_cleangrill",Vector3(2.6,1.9,-4.68));make_sign("CLEAN GRILL\n= HAPPY GRILL",.65,.34,C.ORANGE);end()
 begin("KIT_hooks_wall",Vector3(.16,1.7,-3.5),90)
 b.box(Vector3(0,0,0),Vector3(.8,.06,.05),C.STEEL)
 b.box(Vector3(-.25,-.24,.03),Vector3(.24,.42,.035),C.ORANGE);b.beam(Vector3(-.3,-.1,.03),Vector3(-.3,.09,.03),.03,C.ORANGE)
 b.box(Vector3(.04,-.15,.04),Vector3(.14,.2,.07),C.CHARCOAL);b.box(Vector3(.13,-.08,.04),Vector3(.08,.05,.07),C.CHARCOAL)
 b.box(Vector3(.30,-.22,.04),Vector3(.13,.18,.025),C.STEEL);b.box(Vector3(.30,-.08,.04),Vector3(.035,.12,.04),C.RUST)
 for i in 4:b.beam(Vector3(-.05+i*.035,.03,.04),Vector3(.1,.14,.04),.008,C.CREAM)
 end()
 begin("KIT_prep_board",Vector3(.95,.96,-4.22),0,"static","PrepBench")
 b.box(Vector3.ZERO,Vector3(.3,.025,.22),C.CREAM);b.box(Vector3(.12,.035,0),Vector3(.06,.01,.09),C.STEEL);b.box(Vector3(.12,.035,.12),Vector3(.02,.025,.17),C.CHARCOAL);end()
 begin("KIT_ticket_spike",Vector3(.25,.97,-4.3))
 for i in 4:b.box(Vector3(0,.003*i,0),Vector3(.14,.003,.1),C.CREAM,Vector3(0,.2*i,0))
 b.cylinder(Vector3(0,.075,0),.009,.15,C.STEEL,0);end()
 for row: Array in [["KIT_health_cert","HEALTH CERTIFICATE\nSCORE: [SMUDGED]\nEXPIRED 1998",Vector3(.18,2.3,-3.55),90,.65,.42,C.CREAM],["KIT_rota","SHIFT ROTA\nCLEATIMUS: ALL SHIFTS\nDAVE: ------------",Vector3(.18,2.1,-1.1),90,.58,.4,C.CREAM],["KIT_notice_washhands","WASH HANDS\nBOTH, IF AVAILABLE",Vector3(4.65,2.45,-.17),180,.5,.4,C.LIGHT_TEAL],["KIT_notice_infection","IN CASE OF INFECTION\nFEEL ODD? > CLOCK OUT\nNO PULSE? > TELL DAVE",Vector3(.18,2.3,-.5),90,.65,.45,C.CREAM]]:
  begin(row[0],row[2],row[3]);make_sign(row[1],row[4],row[5],row[6],C.CHARCOAL);end()
 begin("KIT_floor_tiles",Vector3(2.4,.017,-3.5),0,"static","ShopGreybox")
 for i in 3:b.cylinder(Vector3((i-1)*.2,0,.1*(i%2)),.06,.002,C.CHARCOAL)
 end()
 begin("KIT_mop_bucket",Vector3(5.35,0,-.55),0,"knockable")
 b.box(Vector3(0,.15,0),Vector3(.34,.28,.28),C.SLATE);b.box(Vector3(.1,.33,0),Vector3(.14,.12,.3),C.STEEL);b.beam(Vector3(0,.1,0),Vector3(.15,1.15,0),.025,C.RUST);end()
 begin("KIT_sign_wetfloor",Vector3(4.9,0,-.7),0,"knockable")
 b.box(Vector3(0,.25,0),Vector3(.3,.5,.04),C.AMBER,Vector3(.18,0,0));b.box(Vector3(0,.25,-.18),Vector3(.3,.5,.04),C.AMBER,Vector3(-.18,0,0));text("WET\nFLOOR",Vector3(0,.28,.06),.25,C.CHARCOAL);end()
 begin("DIN_booth",Vector3(-1.35,0,-.27),180,"cover")
 b.box(Vector3(0,.2,0),Vector3(1.15,.4,.6),C.CHARCOAL);b.box(Vector3(0,.46,0),Vector3(1.2,.13,.65),C.ORANGE);b.box(Vector3(0,.8,-.25),Vector3(1.2,.65,.13),C.ORANGE)
 b.box(Vector3(-.26,.83,-.17),Vector3(.14,.35,.015),C.STEEL);b.box(Vector3(.3,.54,.1),Vector3(.12,.012,.1),C.EMBER);fungal(Vector3(.44,.05,-.2),.45);end()
 begin("DIN_poster_pinup",Vector3(-5.68,1.8,-1.4),90)
 var paper:=MeshInstance3D.new();paper.name="Paper";var quad:=QuadMesh.new();quad.size=Vector2(.48,.65);paper.mesh=quad
 var mat:=ShaderMaterial.new();mat.shader=preload("res://props/building_decor/worn_paper.gdshader");mat.set_shader_parameter("paper",load("res://art/posters/service_yeasty_pinup.png"));paper.material_override=mat;paper.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;item.add_child(paper);end()
 begin("DIN_calendar",Vector3(-.16,1.9,-1.0),-90);make_sign("SPORE OF THE MONTH\nMARCH\n[STILL MARCH]",.5,.6);fungal(Vector3(0,-.1,.03),.5);end()
 begin("DIN_standee_cleatimus",Vector3(-4.45,0,-2.0),60,"knockable")
 b.box(Vector3(-.045,.9,0),Vector3(.39,1.05,.025),C.ORANGE)
 b.box(Vector3(.195,.75,0),Vector3(.09,.75,.025),C.ORANGE)
 b.box(Vector3(.195,1.38,0),Vector3(.09,.09,.025),C.ORANGE);b.cylinder(Vector3(0,1.58,0),.18,.25,C.CREAM);b.box(Vector3(0,.13,0),Vector3(.44,.26,.025),C.CHARCOAL)
 b.box(Vector3(-.30,1.07,0),Vector3(.14,.46,.025),C.ORANGE,Vector3(0,0,-.2))
 b.box(Vector3(.30,.94,0),Vector3(.14,.22,.025),C.ORANGE,Vector3(0,0,.4))
 b.box(Vector3(0,1.74,0),Vector3(.46,.07,.035),C.TEAL)
 for x in [-.065,.065]:b.box(Vector3(x,1.62,-.18),Vector3(.065,.045,.018),C.CHARCOAL)
 # Missing cardboard chunks at the right shoulder form bite marks in silhouette.
 b.box(Vector3(.22,1.3,0),Vector3(.045,.06,.026),C.CREAM)
 make_sign("CLEATIMUS SAYS\nTRY THE DOUBLE!",.54,.28,C.CREAM,C.CHARCOAL,Vector3(0,.8,.03));end()
 begin("DIN_figurine_display",Vector3(-5,1.02,-4.2))
 b.box(Vector3(0,.1,0),Vector3(.6,.2,.25),C.LIGHT_TEAL)
 for i in 6:b.box(Vector3(-.25+i*.1,.21,0),Vector3(.07,.02,.12),C.CHARCOAL)
 fungal(Vector3(-.25,.23,0),.3);text("COLLECT ALL 6 FUNGI FIGURINES",Vector3(0,.12,.14),.52,C.CREAM);end()
 begin("DIN_jukebox",Vector3(-.53,0,-1.35),0,"weapons")
 b.box(Vector3(0,.55,0),Vector3(.65,1.1,.44),C.TEAL);b.box(Vector3(0,.75,.24),Vector3(.54,.4,.025),C.CHARCOAL)
 for i in 5:b.box(Vector3(0,.15+i*.065,.24),Vector3(.48,.02,.025),C.STEEL)
 make_sign("OUT OF ORDER\nLIKE EVERYTHING",.5,.18,C.CREAM,C.CHARCOAL,Vector3(0,.8,.26));b.box(Vector3(0,1.13,0),Vector3(.75,.06,.5),C.CHARCOAL)
 # An inert display pistol marks the owned-weapon shelf without granting a weapon.
 b.box(Vector3(0,1.24,0),Vector3(.43,.09,.075),C.CHARCOAL)
 b.box(Vector3(.12,1.18,0),Vector3(.09,.16,.075),C.TEAL,Vector3(0,0,.25))
 b.box(Vector3(-.14,1.295,0),Vector3(.025,.02,.03),C.AMBER);end()
 begin("DIN_clock",Vector3(-3.9,2.4,-.16),180)
 b.cylinder(Vector3.ZERO,.25,.035,C.STEEL,-1,Vector3(PI*.5,0,0));b.cylinder(Vector3(0,0,.025),.22,.015,C.CREAM,-1,Vector3(PI*.5,0,0));b.box(Vector3(0,.07,.04),Vector3(.015,.15,.01),C.CHARCOAL);text("12",Vector3(0,.15,.05),.11,C.CHARCOAL);end()
 begin("BACK_crates",Vector3(4.7,0,3.6),0,"cover")
 for at: Vector3 in [Vector3.ZERO,Vector3(.6,0,0),Vector3(.3,.45,0)]:
  b.box(at+Vector3(0,.22,0),Vector3(.55,.44,.5),C.RUST)
  for x in [-.22,.22]:b.box(at+Vector3(x,.22,.26),Vector3(.035,.4,.018),C.SLATE)
 text("PREMIUM CAPS\nDO NOT EAT RAW",Vector3(.3,.67,.27),.48,C.CREAM);end()
 begin("BACK_freezer_door",Vector3(3,1.2,4.74),180,"door","ShopGreybox/Garage")
 for x in [-.55,.55]:b.box(Vector3(x,0,0),Vector3(.05,2.2,.025),C.LIGHT_TEAL)
 make_sign("DON'T.",.36,.2,C.CREAM,C.CHARCOAL,Vector3(.12,-.24,.03));item.hit_size=Vector3(1.1,2.1,.12);end()
 begin("BACK_desk",Vector3(-2.8,.775,4.35),0,"static","ShopGreybox")
 b.box(Vector3(0,0,0),Vector3(1.55,.012,.57),C.SLATE);end()
 begin("BACK_plant_dead",Vector3(-2.18,.79,4.4))
 b.cylinder(Vector3(0,.065,0),.07,.13,C.RUST,.09)
 for i in 5:b.beam(Vector3(0,.12,0),Vector3(sin(i*2)*.12,.18+(i%2)*.08,cos(i*2)*.12),.012,C.OLIVE)
 end()
 begin("BACK_phone_rotary",Vector3(-3.43,.79,4.2),180)
 b.box(Vector3(0,.055,0),Vector3(.24,.11,.19),C.CHARCOAL);b.cylinder(Vector3(0,.12,0),.065,.012,C.CREAM);b.box(Vector3(.1,.1,.15),Vector3(.25,.045,.05),C.CHARCOAL)
 for i in 6:b.box(Vector3(.08+sin(i)*.03,.03,.15+i*.025),Vector3(.015,.015,.04),C.CHARCOAL)
 end()
 begin("BACK_invoices",Vector3(-2.38,.79,4.1))
 for i in 7:b.box(Vector3(0,i*.003,0),Vector3(.2,.003,.24),C.CREAM,Vector3(0,i*.07,0))
 text("UNPAID",Vector3(0,.025,.03),.16,C.EMBER);item.get_node("Text").rotation.x=-PI*.5;end()
 begin("BACK_photo_eotm",Vector3(-2.0,2.3,4.70),180)
 make_sign("EMPLOYEE OF\nTHE MONTH\nDAVE",.52,.55,C.CREAM,C.CHARCOAL);item.get_node("Text").name="EmployeeName"
 item.get_node("EmployeeName").position.y=.13
 for x in [-.26,.26]:b.box(Vector3(x,0,.018),Vector3(.025,.57,.025),C.RUST)
 for y in [-.275,.275]:b.box(Vector3(0,y,.018),Vector3(.52,.025,.025),C.RUST)
 b.box(Vector3(0,-.15,.023),Vector3(.25,.19,.008),C.SLATE)
 b.cylinder(Vector3(0,-.11,.031),.047,.012,C.CHARCOAL,-1,Vector3(PI*.5,0,0))
 b.box(Vector3(0,-.20,.035),Vector3(.12,.08,.008),C.CHARCOAL);end()
 begin("FX_light_fluoro",Vector3.ZERO,0,"static","ShopGreybox/Lights")
 for at: Vector3 in [Vector3(-3,2.9,-2.4),Vector3(3,2.9,-2.4),Vector3(-3,2.9,2.4),Vector3(3,2.9,2.4)]:b.box(at,Vector3(.8,.025,.07),C.AMBER)
 end()
 begin("FX_light_fluoro_dead",Vector3.ZERO)
 for at: Vector3 in [Vector3(-3,2.9,-1.2),Vector3(3,2.9,-1.2),Vector3(-3,2.9,3.5),Vector3(3,2.9,3.5)]:b.box(at,Vector3(.8,.025,.07),C.STEEL)
 end()
 begin("FX_light_window_glow",Vector3(-3,2.08,-5.2),180, "static","ShopGreybox/Lights")
 b.box(Vector3.ZERO,Vector3(1.8,.04,.04),C.AMBER);end()
 for row: Array in [["FX_audio_ice_machine",Vector3(5.4,1,-4.4)],["FX_audio_fridge_hum",Vector3(3,1,2)],["FX_audio_hold_music",Vector3(-11.5,1.4,-11.15)]]:
  begin(row[0],row[1]);item.set_meta("audio_emitter",true);end()
