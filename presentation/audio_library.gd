# Cached, band-limited presentation sounds. Separate from the cooking SFX library.
extends RefCounted
const RATE: int=22050
static var cache: Dictionary={}
static func sound(name: String, variant: int=0) -> AudioStreamWAV:
 var key: String=name+str(variant%4)
 if cache.has(key):return cache[key]
 var rng:=RandomNumberGenerator.new()
 rng.seed=hash(key)
 var seconds: float=0.18
 if name in ["fridge","air"]:seconds=4.0
 elif name in ["groan","chitter"]:seconds=0.65
 elif name=="death":seconds=0.42
 elif name=="land":seconds=0.25
 elif name=="select":seconds=0.055
 elif name=="confirm":seconds=0.13
 var count: int=int(seconds*RATE)
 var samples:=PackedFloat32Array()
 samples.resize(count)
 var low: float=0.0
 var phase: float=0.0
 var pitch: float=1.0+float(variant%4-1)*0.035
 for i in count:
  var t: float=float(i)/RATE
  var noise: float=rng.randf_range(-1.0,1.0)
  low=lerpf(low,noise,0.12)
  var value: float=0.0
  match name:
   "tile","grit","rubber","land":
    var decay: float=24.0 if name!="land" else 17.0
    var body: float=sin(TAU*(83.0*pitch*t-32.0*t*t))*exp(-t*decay)*0.30
    var contact: float=(noise-low)*exp(-t*80.0)*0.10
    var scuff: float=low*exp(-t*22.0)*0.22
    if name=="grit":scuff*=2.0
    if name=="rubber":contact*=0.2
    value=body+contact+scuff
   "cloth","hurt":
    value=low*exp(-t*20.0)*0.55+sin(TAU*68.0*t)*exp(-t*32.0)*0.12
   "wood":
    value=(sin(TAU*143.0*t)+0.3*sin(TAU*337.0*t))*exp(-t*35.0)*0.24+noise*exp(-t*100.0)*0.08
   "groan","chitter","death":
    var hz: float=72.0 if name=="groan" else (165.0 if name=="chitter" else 55.0)
    phase+=TAU*hz*pitch*(1.0-0.25*t)* (1.0+0.04*sin(t*TAU*9.0))/RATE
    var voice: float=sin(phase)+0.28*sin(phase*2.0)+0.12*sin(phase*3.0)
    var env: float=sin(PI*clampf(t/seconds,0.0,1.0))
    if name=="chitter":env*=0.4+0.6*pow(sin(t*TAU*6.0),2.0)
    value=(voice*0.13+low*0.35)*env
   "fridge":
    value=(sin(TAU*50.0*t)*0.025+sin(TAU*100.0*t)*0.009+sin(TAU*150.0*t)*0.004)*(0.92+0.08*cos(TAU*t/4.0))
   "air":
    value=low*0.025
   "select":
    value=sin(TAU*640.0*t)*exp(-t*90.0)*0.12
   "confirm":
    value=(sin(TAU*640.0*t)+sin(TAU*960.0*t)*0.35)*exp(-t*30.0)*0.13
  # Suppress sample-edge clicks in one-shots.
  if name not in ["fridge","air"]:value*=minf(1.0,t/0.003)*minf(1.0,(seconds-t)/0.008)
  samples[i]=clampf(value,-0.8,0.8)
 if name in ["fridge","air"]:
  # Blend the loop seam without fading the whole loop in/out.
  var seam: int=256
  for i in seam:
   var u: float=float(i)/float(seam)
   samples[count-seam+i]=lerpf(samples[count-seam+i],samples[i],u)
 var bytes:=PackedByteArray()
 bytes.resize(count*2)
 for i in count:bytes.encode_s16(i*2,int(samples[i]*32767.0))
 var stream:=AudioStreamWAV.new()
 stream.format=AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate=RATE
 stream.data=bytes
 if name in ["fridge","air"]:
  stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
  stream.loop_end=count
 cache[key]=stream
 return stream
static func ui(parent: Node, name: String) -> void:
 if DisplayServer.get_name()=="headless" or not parent.is_inside_tree():return
 var player:=AudioStreamPlayer.new()
 player.bus="UI"
 player.stream=sound(name)
 player.volume_db=-9.0
 parent.add_child(player)
 player.finished.connect(player.queue_free)
 player.play()
