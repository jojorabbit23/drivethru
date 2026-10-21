# Tiny generated sounds, so states never rely on colour alone and the project
# needs no audio files: bell (patty ready), alarm (patty burnt), horn (car arrives), order chime,
# till (cash), sizzle (loop on a cooking grill), click (empty gun), thunk.
#   Sfx.play(node, "bell")            non-positional
#   Sfx.play_at(node, "horn", pos)    3D
extends RefCounted

const RATE := 22050
static var _cache := {}

static func stream(name: String) -> AudioStreamWAV:
	if name == "pistol":
		return preload("res://weapons/pistol/audio/shot.wav")
	if _cache.has(name):
		return _cache[name]
	var s := _make(name)
	_cache[name] = s
	return s

static func play(node: Node, name: String, volume_db := -6.0) -> void:
	if DisplayServer.get_name() == "headless" and name == "pistol": return
	if not node.is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream(name)
	p.volume_db = volume_db
	node.get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

static func play_at(node: Node, name: String, at: Vector3, volume_db := 0.0) -> void:
	if not node.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(name)
	p.volume_db = volume_db
	p.unit_size = 4.0
	node.get_tree().root.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()

static func _make(name: String) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	match name:
		"phone": # Original double ring, softened to sit above kitchen ambience.
			for i in int(RATE*1.4):
				var t: float=float(i)/RATE
				var on: float=1.0 if t<.45 or (t>.65 and t<1.1) else 0.0
				var envelope: float=minf(1.0,t*80.0)*(.65+.35*sin(TAU*22*t))
				samples.append(on*envelope*(sin(TAU*440*t)+.45*sin(TAU*480*t))*.35)
		"warning_tick", "storage_full":
			for i in int(RATE*0.18):
				var t: float=float(i)/RATE
				var hz: float=660.0 if name=="warning_tick" else (330.0 if t<0.09 else 220.0)
				samples.append(sin(TAU*hz*t)*exp(-t*24.0)*0.5)
		"bell":    # two bright partials, long ring
			for i in int(RATE * 0.9):
				var t := float(i) / RATE
				var env := exp(-t * 5.0)
				samples.append(env * (0.6 * sin(TAU * 1320.0 * t) + 0.3 * sin(TAU * 1980.0 * t) + 0.15 * sin(TAU * 2640.0 * t)))
		"horn":    # two honks
			for i in int(RATE * 0.55):
				var t := float(i) / RATE
				var on := 1.0 if (t < 0.18 or (t > 0.27 and t < 0.5)) else 0.0
				var w := signf(sin(TAU * 392.0 * t)) * 0.5 + signf(sin(TAU * 494.0 * t)) * 0.3
				samples.append(on * w * 0.5)
		"order":   # rising chime
			for i in int(RATE * 0.45):
				var t := float(i) / RATE
				var f := 880.0 if t < 0.15 else (1109.0 if t < 0.3 else 1319.0)
				samples.append(exp(-fmod(t, 0.15) * 12.0) * sin(TAU * f * t) * 0.6)
		"till":    # cha-ching
			for i in int(RATE * 0.5):
				var t := float(i) / RATE
				var hit := exp(-t * 30.0) * rng.randf_range(-1.0, 1.0) * 0.5
				var ring := exp(-maxf(t - 0.08, 0.0) * 6.0) * (sin(TAU * 2093.0 * t) + 0.6 * sin(TAU * 2637.0 * t)) * (0.0 if t < 0.08 else 0.4)
				samples.append(hit + ring)
		"sizzle":  # loopable hiss with crackles
			var last := 0.0
			for i in int(RATE * 1.0):
				var n := rng.randf_range(-1.0, 1.0)
				last = last * 0.55 + n * 0.45      # soften
				var crackle := (rng.randf_range(-1.0, 1.0) if rng.randf() < 0.004 else 0.0)
				samples.append((n - last) * 0.25 + crackle * 0.6)
		"alarm":   # burnt patty: two-tone beep-beep
			for i in int(RATE * 0.6):
				var t := float(i) / RATE
				var on := 1.0 if fmod(t, 0.3) < 0.18 else 0.0
				var f := 1568.0 if t < 0.3 else 1175.0
				samples.append(on * signf(sin(TAU * f * t)) * 0.35)
		"click":
			for i in int(RATE * 0.06):
				var t := float(i) / RATE
				samples.append(exp(-t * 120.0) * rng.randf_range(-1.0, 1.0) * 0.7)
		"thunk":   # deposit / pick up
			for i in int(RATE * 0.2):
				var t := float(i) / RATE
				samples.append(exp(-t * 25.0) * sin(TAU * (160.0 - t * 300.0) * t) * 0.8)
		_:
			samples.append(0.0)
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if name == "sizzle":
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = samples.size()
	return s
