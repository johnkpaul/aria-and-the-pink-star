extends Node

## Autoload: generates all sound effects and background music procedurally
## as AudioStreamWAV PCM buffers (no imported audio files), and exposes
## play_sfx()/play_bgm()/unlock_audio() for the rest of the game.

const SAMPLE_RATE := 22050

var _sfx_streams: Dictionary = {}
var _bgm_stream: AudioStreamWAV
var _bgm_player: AudioStreamPlayer
var _unlocked := false
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_PLAYER_POOL_SIZE := 6


func _ready() -> void:
	_build_all_sfx()
	_build_bgm()

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "BGM"
	_bgm_player.stream = _bgm_stream
	add_child(_bgm_player)

	for i in range(SFX_PLAYER_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)


func unlock_audio() -> void:
	if _unlocked:
		return
	_unlocked = true
	if AudioServer.has_method("set_bus_mute"):
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	# Nudge the browser audio context awake with a near-silent blip.
	play_sfx("unlock")
	play_bgm()


func play_sfx(sfx_name: String) -> void:
	if not _sfx_streams.has(sfx_name):
		return
	var player := _get_free_sfx_player()
	player.stream = _sfx_streams[sfx_name]
	player.play()


func play_bgm() -> void:
	if _bgm_player and not _bgm_player.playing:
		_bgm_player.play()


func stop_bgm() -> void:
	if _bgm_player:
		_bgm_player.stop()


func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	return _sfx_players[0]


# ---------------------------------------------------------------------------
# SFX construction
# ---------------------------------------------------------------------------

func _build_all_sfx() -> void:
	_sfx_streams["reveal"] = _make_reveal_sfx()
	_sfx_streams["reveal_empty"] = _make_reveal_empty_sfx()
	_sfx_streams["dissolve"] = _make_dissolve_sfx()
	_sfx_streams["key"] = _make_key_sfx()
	_sfx_streams["pulled"] = _make_pulled_sfx()
	_sfx_streams["stuck"] = _make_stuck_sfx()
	_sfx_streams["bump"] = _make_bump_sfx()
	_sfx_streams["ui_tap"] = _make_ui_tap_sfx()
	_sfx_streams["unlock"] = _make_silent_sfx()


func _make_silent_sfx() -> AudioStreamWAV:
	var frames := int(SAMPLE_RATE * 0.02)
	var data := PackedByteArray()
	data.resize(frames * 2)
	return _wrap_pcm(data)


## Sparkling rising arpeggio - "a light just found something".
func _make_reveal_sfx() -> AudioStreamWAV:
	var notes := [880.0, 1108.73, 1318.51]
	var note_dur := 0.06
	var frames_per_note := int(SAMPLE_RATE * note_dur)
	var total_frames := frames_per_note * notes.size()
	var data := PackedByteArray()
	data.resize(total_frames * 2)
	for n in range(notes.size()):
		var freq: float = notes[n]
		for i in range(frames_per_note):
			var t := float(i) / frames_per_note
			var env: float = sin(t * PI)
			var sample := sin(TAU * freq * (float(i) / SAMPLE_RATE)) * env
			_write_sample(data, n * frames_per_note + i, sample * 0.7)
	return _wrap_pcm(data)


## A single soft, neutral blip - "the light searched, nothing here" -
## deliberately calmer than the reveal chime (no rising pitch, no
## multi-note pattern) so a tap that finds nothing still feels like it did
## something, without reading as a wrong-answer buzz.
func _make_reveal_empty_sfx() -> AudioStreamWAV:
	var duration := 0.12
	var frames := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var freq := 520.0
	for i in range(frames):
		var t := float(i) / frames
		var env: float = sin(t * PI) * (1.0 - t * 0.3)
		var sample := sin(TAU * freq * (float(i) / SAMPLE_RATE)) * env
		_write_sample(data, i, sample * 0.45)
	return _wrap_pcm(data)


## A soft descending "melt" - filtered noise fading with a falling pitch
## whistle layered on top.
func _make_dissolve_sfx() -> AudioStreamWAV:
	var duration := 0.3
	var frames := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var prev := 0.0
	var phase := 0.0
	for i in range(frames):
		var t := float(i) / frames
		var raw := rng.randf_range(-1.0, 1.0)
		prev = prev * 0.7 + raw * 0.3
		var freq: float = lerp(900.0, 300.0, t)
		phase += freq / SAMPLE_RATE
		var whistle := sin(phase * TAU)
		var env: float = 1.0 - t
		_write_sample(data, i, (prev * 0.5 + whistle * 0.5) * env * 0.8)
	return _wrap_pcm(data)


## C6-E6-G6 ascending beeps - bright, celebratory, distinct from the
## reveal chime.
func _make_key_sfx() -> AudioStreamWAV:
	var notes := [1046.5, 1318.51, 1567.98]
	var note_dur := 0.09
	var frames_per_note := int(SAMPLE_RATE * note_dur)
	var total_frames := frames_per_note * notes.size()
	var data := PackedByteArray()
	data.resize(total_frames * 2)
	for n in range(notes.size()):
		var freq: float = notes[n]
		for i in range(frames_per_note):
			var t := float(i) / frames_per_note
			var env: float = sin(t * PI)
			var sample := sin(TAU * freq * (float(i) / SAMPLE_RATE)) * env
			_write_sample(data, n * frames_per_note + i, sample)
	return _wrap_pcm(data)


## Descending "whoosh" with a wobble - a gentle pull-back, not a harsh
## failure buzz.
func _make_pulled_sfx() -> AudioStreamWAV:
	var duration := 0.45
	var frames := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for i in range(frames):
		var t := float(i) / frames
		var wobble: float = sin(t * PI * 8.0) * 30.0
		var freq: float = lerp(600.0, 140.0, t) + wobble
		phase += freq / SAMPLE_RATE
		var env: float = 1.0 - t
		var sample := sin(phase * TAU) * env
		_write_sample(data, i, sample * 0.85)
	return _wrap_pcm(data)


## A short, soft "boing" - getting caught in the goo, playful not scary.
func _make_stuck_sfx() -> AudioStreamWAV:
	var duration := 0.18
	var frames := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for i in range(frames):
		var t := float(i) / frames
		var wobble: float = sin(t * PI * 5.0) * 60.0
		var freq: float = lerp(220.0, 340.0, t) + wobble
		phase += freq / SAMPLE_RATE
		var env: float = sin(t * PI)
		var sample := sin(phase * TAU) * env
		_write_sample(data, i, sample * 0.8)
	return _wrap_pcm(data)


## A soft low thud - bumping an asteroid, quieter than a real impact.
func _make_bump_sfx() -> AudioStreamWAV:
	var duration := 0.1
	var frames := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var freq := 180.0
	for i in range(frames):
		var t := float(i) / frames
		var phase := fmod(i * freq / SAMPLE_RATE, 1.0)
		var sample: float = 1.0 if phase < 0.5 else -1.0
		var env: float = 1.0 - t
		_write_sample(data, i, sample * env * 0.6)
	return _wrap_pcm(data)


## A quick, light tick - generic menu-button feedback (title screen, tutorial
## NEXT, level-intro START, in-level MENU). Deliberately plainer than the
## gameplay action sounds (reveal/dissolve/key/etc.) so menus feel responsive
## without competing with those more distinctive cues.
func _make_ui_tap_sfx() -> AudioStreamWAV:
	var duration := 0.05
	var frames := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var freq := 900.0
	for i in range(frames):
		var t := float(i) / frames
		var env: float = 1.0 - t
		var sample := sin(TAU * freq * (float(i) / SAMPLE_RATE)) * env
		_write_sample(data, i, sample * 0.4)
	return _wrap_pcm(data)


# ---------------------------------------------------------------------------
# BGM construction
# ---------------------------------------------------------------------------

func _build_bgm() -> void:
	# 16-second loop, 110 BPM, soft square melody + triangle bass over an
	# A minor pentatonic scale for a slightly more "magical/starlit" feel
	# than a bright major key.
	const BPM := 110.0
	const BEAT_SEC := 60.0 / BPM
	const STEP_SEC := BEAT_SEC / 2.0
	const TOTAL_SEC := 16.0
	var total_frames := int(SAMPLE_RATE * TOTAL_SEC)

	var pentatonic := [220.00, 261.63, 293.66, 329.63, 392.00]  # A C D E G
	var melody_pattern := [0, -1, 2, -1, 4, 3, -1, 2, 0, -1, 3, 4, -1, 2, 1, -1]
	var bass_pattern := [0, -1, -1, -1, 3, -1, -1, -1]

	var data := PackedByteArray()
	data.resize(total_frames * 2)

	var steps_total := int(TOTAL_SEC / STEP_SEC)
	var mel_phase := 0.0
	var bass_phase := 0.0

	for step in range(steps_total):
		var start_frame := int(step * STEP_SEC * SAMPLE_RATE)
		var end_frame := int((step + 1) * STEP_SEC * SAMPLE_RATE)
		end_frame = mini(end_frame, total_frames)

		var mel_idx: int = melody_pattern[step % melody_pattern.size()]
		var bass_idx: int = bass_pattern[(step / 2) % bass_pattern.size()]

		var mel_freq := 0.0
		if mel_idx >= 0:
			mel_freq = pentatonic[mel_idx] * 2.0
		var bass_freq := 0.0
		if bass_idx >= 0:
			bass_freq = pentatonic[bass_idx] * 0.5

		var step_frames := end_frame - start_frame
		for i in range(step_frames):
			var frame_idx := start_frame + i
			if frame_idx >= total_frames:
				break
			var local_t := float(i) / step_frames
			var env: float = 1.0
			if local_t > 0.7:
				env = 1.0 - (local_t - 0.7) / 0.3

			var sample := 0.0
			if mel_freq > 0.0:
				mel_phase += mel_freq / SAMPLE_RATE
				var sq: float = 1.0 if fmod(mel_phase, 1.0) < 0.5 else -1.0
				sample += sq * 0.16 * env
			if bass_freq > 0.0:
				bass_phase += bass_freq / SAMPLE_RATE
				var tri_phase := fmod(bass_phase, 1.0)
				var tri: float = 4.0 * abs(tri_phase - 0.5) - 1.0
				sample += tri * 0.2

			var existing := _read_sample(data, frame_idx)
			_write_sample(data, frame_idx, clampf(existing + sample, -1.0, 1.0))

	_bgm_stream = _wrap_pcm(data)
	_bgm_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_bgm_stream.loop_begin = 0
	_bgm_stream.loop_end = total_frames


# ---------------------------------------------------------------------------
# PCM helpers
# ---------------------------------------------------------------------------

func _write_sample(data: PackedByteArray, frame_index: int, value: float) -> void:
	var clamped: float = clampf(value, -1.0, 1.0)
	var s16 := int(clamped * 32767.0)
	var byte_idx := frame_index * 2
	data[byte_idx] = s16 & 0xFF
	data[byte_idx + 1] = (s16 >> 8) & 0xFF


func _read_sample(data: PackedByteArray, frame_index: int) -> float:
	var byte_idx := frame_index * 2
	var lo: int = data[byte_idx]
	var hi: int = data[byte_idx + 1]
	var s16 := lo | (hi << 8)
	if s16 >= 32768:
		s16 -= 65536
	return s16 / 32767.0


func _wrap_pcm(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
