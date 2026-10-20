extends "res://enemies/shambler/shambler.gd"
const Rally=preload("res://enemies/hollowhead/horde_rally.gd")
const Spores=preload("res://enemies/hollowhead/spore_burst.gd")
const CLICK_STREAM=preload("res://enemies/hollowhead/audio/click.wav")
const ATTACKS: Array[String]=["swing","swing_left","slam"]
var attack_index: int=0
var attack_clip: String="swing"
var agitated: float=0
var frenzy: bool=false
var charge_time: float=0
var charge_windup: float=0
var charge_cooldown: float=0
var charge_direction:=Vector3.ZERO
var charge_landed: bool=false
var click_cooldown: float=0
var sense_timer: float=0
var stumble_timer: float=8.0
var life_time: float=0
var click: AudioStreamPlayer3D
func _init() -> void:
	max_health=80
	lane_speed=1.05
	hunt_speed=1.25
	turn_rate=3.0
	attack_range=1.35
	attack_damage=8
	head_multiplier=3.5
	stagger_threshold=15
func _ready() -> void:
	super._ready()
	sense_timer=randf()*.25
	stumble_timer=randf_range(7,11)
	if DisplayServer.get_name()!="headless":
		click=AudioStreamPlayer3D.new()
		click.stream=CLICK_STREAM
		click.bus="Effects"
		click.volume_db=-9
		click.unit_size=5
		click.max_distance=24
		click.position.y=1.55
		add_child(click)
func hear_hollowhead(duration: float) -> void:
	agitated=maxf(agitated,duration)
func rally_nearby() -> void:
	for enemy: Node3D in get_tree().get_nodes_in_group("zombies"):
		if enemy!=self and global_position.distance_to(enemy.global_position)<8:Rally.apply(enemy)
	hear_hollowhead(5)
	if click:click.play()
	click_cooldown=8.0
func _physics_process(delta: float) -> void:
	life_time+=delta
	agitated=maxf(0,agitated-delta)
	click_cooldown=maxf(0,click_cooldown-delta)
	charge_cooldown=maxf(0,charge_cooldown-delta)
	sense_timer-=delta
	if state!=State.DEAD and sense_timer<=0:
		sense_timer=.25
		if target and is_instance_valid(target) and not target.is_dead() and global_position.distance_to(target.global_position)<8 and _can_see(target):
			if click_cooldown<=0:rally_nearby()
	if state==State.HUNT and charge_time<=0 and charge_windup<=0:
		stumble_timer-=delta
		if stumble_timer<=0:
			stumble_timer=randf_range(7,11)
			_resume_state=State.HUNT
			state=State.STAGGER
			_play("flinch",.1)
	super._physics_process(delta)
func take_damage(amount: float,headshot:=false,hit: Dictionary={}) -> void:
	super.take_damage(amount,headshot,hit)
	if state==State.DEAD:return
	if health/max_health<.30:
		frenzy=true
		if click:click.pitch_scale=1.45;click.play()
	if state==State.STAGGER:
		charge_time=0
		charge_windup=0
		charge_cooldown=1.0
func _hunt(delta: float) -> void:
	if not is_instance_valid(target) or target.is_dead():
		charge_time=0
		charge_windup=0
		super._hunt(delta)
		return
	if charge_windup>0:
		charge_windup-=delta
		velocity.x=0
		velocity.z=0
		_play("idle",.1)
		if charge_windup<=0:
			charge_time=1.0
			charge_landed=false
		return
	if charge_time>0:
		charge_time-=delta
		velocity.x=charge_direction.x*3.2
		velocity.z=charge_direction.z*3.2
		_face(charge_direction,delta)
		_play("shamble")
		anim.speed_scale=2.6
		var to_player: Vector3=target.global_position-global_position
		to_player.y=0
		if not charge_landed and to_player.length()<1.1 and charge_direction.dot(to_player.normalized())>.2 and _can_see(target):
			charge_landed=true
			target.take_damage(16,self)
		if charge_time<=0:charge_cooldown=2.5
		return
	var distance: float=global_position.distance_to(target.global_position)
	if frenzy and charge_cooldown<=0 and distance>1.8 and distance<6 and _can_see(target):
		charge_direction=target.global_position-global_position
		charge_direction.y=0
		charge_direction=charge_direction.normalized()
		charge_windup=.45
		if click:click.pitch_scale=1.45;click.play()
		return
	var base_speed: float=hunt_speed
	if agitated>0 and fposmod(life_time,3.5)<.8:hunt_speed*=1.5
	agent.max_speed=hunt_speed
	super._hunt(delta)
	hunt_speed=base_speed
func _on_safe_velocity(value: Vector3) -> void:
	if charge_time>0 or charge_windup>0:return
	super._on_safe_velocity(value)
func _play(name: String,blend: float=-1.0) -> void:
	if name=="swing":
		attack_clip=ATTACKS[attack_index%3]
		attack_index+=1
		super._play(attack_clip,blend)
	else:super._play(name,blend)
func _attack(delta: float) -> void:
	velocity.x=0
	velocity.z=0
	agent.velocity=Vector3.ZERO
	if is_instance_valid(target) and not target.is_dead():
		var direction: Vector3=target.global_position-global_position
		direction.y=0
		if anim.current_animation_position<SWING_HIT:_face(direction.normalized(),delta)
		if not _swing_landed and anim.current_animation_position>=SWING_HIT:
			_swing_landed=true
			if direction.length()<attack_range+.3 and (-global_basis.z).dot(direction.normalized())>.1 and _can_see(target):
				target.take_damage(12 if attack_clip=="slam" else attack_damage,self)
	if not anim.is_playing() or anim.current_animation!=attack_clip:state=State.HUNT
func _die() -> void:
	if state==State.DEAD:return
	var origin: Vector3=global_position+Vector3(0,1.55,0)
	super._die()
	var burst: Node3D=Spores.new()
	burst.position=get_parent().to_local(origin)
	get_parent().add_child(burst)
