# renji.gd — RAID 2, GATE 1: Renji, o Discípulo
# ============================================================================
# Versão MAIS PERDOADORA do Kael, pra aprender o parry. Janela enorme, sem
# golpe azul (inesquivável), sem fintas. 2 fases curtas, 1 portão de rajada.
# ============================================================================
extends BossBase

@export_group("Renji")
@export var telegraph     : float = 0.7
@export var parry_window  : float = 0.55
@export var strike_damage : float = 1_000.0
@export var parry_stagger : float = 2_000.0
@export var gap   : float = 0.35
@export var pause : float = 1.2
@export var th_gate_pct : float = 0.55


func fight() -> void:
	_set_body("Corpo", Color(0.7, 0.8, 1.0))
	is_immune = true
	# FASE 1
	while _alive() and current_hp > max_hp * th_gate_pct:
		await _round(1)
	# PORTÃO
	if _alive(): await _gate_flurry()
	# FASE 2
	_phase_card("FASE 2 — Sem dó")
	while _alive():
		await _round(2)


func _round(phase: int) -> void:
	await _move_to(_approach_pos(), move_speed)
	if not _alive(): return
	var n : int = 1 if phase == 1 else 2
	var parried := 0
	for s in n:
		if not _alive(): return
		if await _strike():
			parried += 1
			if stagger >= max_stagger:
				await _topple()
				return
		await _sleep(gap)
	if parried > 0 and _alive() and state == State.FIGHT:
		await _riposte(parried)
	await _after_attack(pause)


func _strike() -> bool:
	_set_color(Color(1.0, 0.3, 0.3))
	await _sleep(telegraph)
	if not _alive(): return false
	_play_anim("attack")
	_set_color(Color(1, 1, 1))
	var ok := await _await_counter(parry_window)
	if ok:
		_parry_feedback()
		add_stagger(parry_stagger, true)   # parry-counter = mecânica (ignora nerf neutro)
		return true
	if _player_alive(): _player.take_damage(strike_damage)
	_restore_body_color()
	return false


func _riposte(count: int) -> void:
	_announce("RIPOSTE — ataque agora!", Color(0.4, 0.8, 1.0))
	is_immune = false
	_set_color(Color(0.4, 0.7, 1.0))
	await _sleep(0.6 + 0.4 * count)
	is_immune = true
	_stun_pending = false
	_restore_body_color()


func _topple() -> void:
	_announce("DERRUBADO — janela de dano!", Color(1.0, 0.9, 0.3))
	is_immune = false
	_stun_pending = true
	await _do_stun()
	is_immune = true


func _gate_flurry() -> void:
	_gate_card("PORTÃO — Cinco Golpes: defenda (Z)!")
	is_immune = true
	var parried := 0
	for s in 5:
		if not _alive(): break
		_set_color(Color(1.0, 0.3, 0.3))
		await _sleep(telegraph * 0.85)
		if not _alive(): break
		_set_color(Color(1, 1, 1))
		if await _await_counter(parry_window):
			parried += 1; _parry_feedback()
		elif _player_alive():
			_player.take_damage(strike_damage)
		await _sleep(0.2)
	is_immune = false
	_restore_body_color()
	if parried >= 3 and _alive():
		_announce("Cinco quebrados — DERRUBADO!", Color(1.0, 0.9, 0.3))
		await _topple()


func _approach_pos() -> Vector2:
	var x := _player_x()
	var side := -50.0 if x > _arena_center().x else 50.0
	return Vector2(clampf(x + side, arena_left + 30.0, arena_right - 30.0), arena_floor - 20.0)
