extends Node
## AudioManager (autoload "Audio"): efectos CC0 (Kenney) + motor y sirena
## generados proceduralmente (sin assets externos). Mantiene musica/jingles.

var _ui: AudioStreamPlayer
var _foot: AudioStreamPlayer
var _engine_3d: AudioStreamPlayer3D
var _engine_stream: AudioStreamWAV
var _siren_stream: AudioStreamWAV
var _music: AudioStreamPlayer

var _foot_t: float = 0.0
var _music_on: bool = false


func _ready() -> void:
	_ui = _mk_player(-6.0)
	_foot = _mk_player(-8.0)
	_music = _mk_player(-14.0)
	_engine_stream = _make_engine_loop()
	_engine_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_siren_stream = _make_siren_loop()
	_siren_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD


## Stream de sirena (para AudioStreamPlayer3D en cada coche de policia).
func siren_stream() -> AudioStream:
	return _siren_stream


func _mk_player(vol_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = vol_db
	p.bus = "Master"
	add_child(p)
	return p


func _ensure_stream(player: AudioStreamPlayer, key: String) -> bool:
	var s := Assets.random_stream(key)
	if s == null:
		return false
	player.stream = s
	return true


# --------------------------------------------------------------------------
# Efectos
# --------------------------------------------------------------------------

func play_click() -> void:
	if _ensure_stream(_ui, "click"):
		_ui.play()


func play_confirm() -> void:
	var s := Assets.random_stream("confirm")
	if s != null:
		_ui.stream = s
		_ui.play()


func play_error() -> void:
	var s := Assets.random_stream("error")
	if s != null:
		_ui.stream = s
		_ui.play()


func play_impact() -> void:
	if _ensure_stream(_ui, "impact"):
		_ui.play()


func play_footstep(delta: float) -> void:
	_foot_t -= delta
	if _foot_t > 0.0:
		return
	_foot_t = 0.42
	if _ensure_stream(_foot, "footsteps"):
		_foot.pitch_scale = randf_range(0.92, 1.08)
		_foot.play()


func play_jingle() -> void:
	var s := Assets.random_stream("jingles")
	if s != null:
		_ui.stream = s
		_ui.play()


# --------------------------------------------------------------------------
# Motor y sirena (procedurales, en loop)
# --------------------------------------------------------------------------

func engine_start(node: Node3D) -> void:
	engine_stop()
	if node == null:
		return
	_engine_3d = AudioStreamPlayer3D.new()
	_engine_3d.stream = _engine_stream
	_engine_3d.volume_db = -4.0
	_engine_3d.unit_size = 12.0
	_engine_3d.max_distance = 60.0
	node.add_child(_engine_3d)
	_engine_3d.play()


func engine_stop() -> void:
	if _engine_3d != null and is_instance_valid(_engine_3d):
		_engine_3d.queue_free()
	_engine_3d = null


func engine_update(speed: float) -> void:
	if _engine_3d != null and is_instance_valid(_engine_3d):
		_engine_3d.pitch_scale = clampf(0.7 + absf(speed) * 0.05, 0.6, 2.2)


# --------------------------------------------------------------------------
# Sintesis de loops (16-bit PCM)
# --------------------------------------------------------------------------

func _make_engine_loop() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.5
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(rate)
		var v := sin(TAU * 58.0 * t) * 0.5 + sin(TAU * 116.0 * t) * 0.25
		v += (randf() * 2.0 - 1.0) * 0.08
		var s := int(clampf(v, -1.0, 1.0) * 16000.0)
		data.encode_s16(i * 2, s)
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.stereo = false
	st.data = data
	return st


func _make_siren_loop() -> AudioStreamWAV:
	var rate := 22050
	var dur := 1.0
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(rate)
		var f := 700.0 if t < 0.5 else 950.0
		var v := sin(TAU * f * t) * 0.5
		var s := int(clampf(v, -1.0, 1.0) * 15000.0)
		data.encode_s16(i * 2, s)
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.stereo = false
	st.data = data
	return st
