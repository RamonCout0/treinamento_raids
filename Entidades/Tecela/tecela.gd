# tecela.gd  —  BOSS 4: Nyx, a Tecelã de Ilusões
# ============================================================================
# IDENTIDADE: LEITURA / ILUSÃO, agora MULTI-FASE como a Silvanna.
# Só o REAL tem Hurtbox (bater nos clones não faz nada). O "tell" (pisca) revela.
#   FASE 1 (100–66%) : embaralha + wisps teleguiados (rebatíveis no Parry).
#   PORTÃO (66%)     : ILUSÃO TOTAL — ache o real pelos tells e bata pra encher
#                      o stagger a tempo (senão wipe), enquanto cortes ilusórios caem.
#   FASE 2 (66–33%)  : mais clones, troca rápida + LASERS DE ESPELHO.
#   FASE 3 (33–0%)   : clones demais, tells curtíssimos, ritmo frenético.
# ============================================================================
extends BossBase

@export_group("Tecelã")
@export var decoys_base  : int   = 2
@export var hidden_time  : float = 1.4
@export var tell_time    : float = 0.7
@export var weave_cycles : int   = 3
@export var wisp_damage  : float = 1_200.0
@export var laser_damage : float = 1_500.0
@export var cut_damage   : float = 1_600.0
@export var pause        : float = 1.0

@export_group("Tecelã: Fases (% HP)")
@export var th_gate_pct : float = 0.66
@export var th_p3_pct   : float = 0.33

@export_group("Tecelã: Skins (opcional)")
@export var skin_clone : PackedScene   ## clones/decoys (de preferência igual ao corpo)
@export var skin_wisp  : PackedScene   ## wisp teleguiado
@export var skin_laser : PackedScene   ## laser de espelho
@export var skin_corte : PackedScene   ## corte ilusório (portão)

var _decoys : Array = []
var _phase := 1
# estado do portão
var _tell_showing := false
var _gate_tell_cd := 0.0
var _gate_cut_cd  := 0.0


func fight() -> void:
	_set_body("Corpo", Color(0.5, 0.2, 0.7))
	is_immune = false

	_phase = 1
	_phase_card("FASE 1 — O Véu: bata no real (dourado)!")
	while _alive() and current_hp > max_hp * th_gate_pct:
		await _weave()
		if not _alive(): break
		await _atk_wisps()
		await _after_attack(pause)
	_clear_decoys()

	if _alive():
		await _gate_ilusao()

	_phase = 2
	_phase_card("FASE 2 — Espelhos Infinitos")
	var i := 0
	while _alive() and current_hp > max_hp * th_p3_pct:
		await _weave()
		if not _alive(): break
		match i % 3:
			0: await _atk_wisps()
			1: await _atk_mirror_lasers()
			2: await _atk_sides()
		i += 1
		await _after_attack(pause * 0.8)
	_clear_decoys()

	_phase = 3
	_phase_card("FASE 3 — Colapso de Ilusões")
	i = 0
	while _alive():
		await _weave()
		if not _alive(): break
		if i % 2 == 0:
			await _atk_sides()
		else:
			await _atk_wisps()
		i += 1
		await _after_attack(pause * 0.6)
	_clear_decoys()


# LADO SEGURO (à la Lost Ark): um lado da arena vira perigo. Fique no outro!
func _atk_sides() -> void:
	var danger_left := randf() > 0.5
	_announce("LADO SEGURO — vá para a " + ("DIREITA!" if danger_left else "ESQUERDA!"), Color(1.0, 0.5, 1.0))
	_play_anim("cast")
	var mid := _arena_center().x
	var half_w := (arena_right - arena_left) * 0.5
	var cx : float = arena_left + half_w * 0.5 if danger_left else arena_right - half_w * 0.5
	_spawn_hazard(Vector2(cx, _arena_center().y), Vector2(half_w, arena_floor - arena_top),
		Color(0.85, 0.2, 0.9), laser_damage, 1.1, 0.6, 0.0, true, false, skin_laser)
	await _sleep(1.9)


func _weave() -> void:
	var slots := _slots()
	for c in weave_cycles:
		if not _alive(): break
		slots.shuffle()
		var k := _decoy_count()
		var picks := slots.slice(0, k + 1)
		global_position = Vector2(picks[0], arena_floor - 20.0)
		_clear_decoys()
		for j in range(1, picks.size()):
			_decoys.append(_make_cube(Vector2(picks[j], arena_floor - 20.0), body_size, Color(0.5, 0.2, 0.7), skin_clone))
		_restore_body_color()
		await _sleep(_scaled(hidden_time))
		if not _alive(): break
		_set_color(Color(1.0, 0.9, 0.3))   # TELL
		await _sleep(_scaled(tell_time))
		_restore_body_color()
	_clear_decoys()


func _atk_wisps() -> void:
	_play_anim("cast")
	for k in 3:
		if not _alive(): return
		_spawn_projectile(PROJECTILE.Mode.HOMING, global_position, Vector2.UP, 160.0,
			wisp_damage, true, skin_wisp, Vector2(16, 16), Color(0.7, 0.4, 1.0, 0.9))
		await _sleep(0.45)
	await _sleep(0.8)


# Lasers de espelho: linhas horizontais que avisam e dão dano (pule/agache/dash).
func _atk_mirror_lasers() -> void:
	_announce("Lasers de Espelho — pule/agache!", Color(1.0, 0.3, 0.9))
	_play_anim("cast")
	for k in 3:
		if not _alive(): return
		var y := randf_range(arena_top + 30.0, arena_floor - 12.0)
		_spawn_hazard(Vector2(_arena_center().x, y), Vector2(arena_right - arena_left, 8.0),
			Color(1.0, 0.3, 0.9), laser_damage, 0.8, 0.4, 0.0, true, false, skin_laser)
		await _sleep(0.7)
	await _sleep(0.5)


# ── Portão: ilusão total (ache o real e bata; cortes ilusórios caem) ──
func _gate_ilusao() -> void:
	_gate_card("PORTÃO — ILUSÃO TOTAL: ache o real (dourado)!")
	_clear_decoys()
	var slots := _slots()
	slots.shuffle()
	global_position = Vector2(slots[0], arena_floor - 20.0)
	for j in range(1, 4):
		_decoys.append(_make_cube(Vector2(slots[j], arena_floor - 20.0), body_size, Color(0.5, 0.2, 0.7), skin_clone))
	_tell_showing = false
	_gate_tell_cd = 0.0
	_gate_cut_cd = 1.0
	var ok := await _stagger_gate(13.0, _on_gate_tick, true)
	_clear_decoys()
	_restore_body_color()
	if ok:
		_announce("Ilusão dissipada!", Color(0.5, 1.0, 0.8))


func _on_gate_tick(dt: float) -> void:
	# pisca o tell (revela o real) em ciclos
	_gate_tell_cd -= dt
	if _gate_tell_cd <= 0.0:
		if _tell_showing:
			_restore_body_color()
			_tell_showing = false
			_gate_tell_cd = _scaled(hidden_time)
		else:
			_set_color(Color(1.0, 0.9, 0.3))
			_tell_showing = true
			_gate_tell_cd = _scaled(tell_time)
	# cortes ilusórios horizontais
	_gate_cut_cd -= dt
	if _gate_cut_cd <= 0.0:
		_gate_cut_cd = 1.5
		var y := randf_range(arena_top + 30.0, arena_floor - 12.0)
		_spawn_hazard(Vector2(_arena_center().x, y), Vector2(arena_right - arena_left, 8.0),
			Color(0.9, 0.3, 0.9), cut_damage, 0.6, 0.3, 0.0, true, false, skin_corte)


func _clear_decoys() -> void:
	for d in _decoys:
		if is_instance_valid(d):
			d.queue_free()
	_decoys.clear()


func _decoy_count() -> int:
	return decoys_base + (_phase - 1)   # 2 -> 4 conforme as fases


func _slots() -> Array:
	var xs : Array = []
	var n := 5
	var span := (arena_right - arena_left) - 100.0
	for k in n:
		xs.append(arena_left + 50.0 + span * (float(k) / float(n - 1)))
	return xs


func _scaled(v: float) -> float:
	var frac : float = clampf(current_hp / max_hp, 0.0, 1.0)
	return v * lerpf(0.55, 1.0, frac)
