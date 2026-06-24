# duelista.gd  —  BOSS 2: Kael, o Espadachim Espelho
# ============================================================================
# IDENTIDADE: DUELO DE PARRY (mesmo espírito, agora MULTI-FASE como a Silvanna).
# Ele é IMUNE — só fere quem DEFENDE (Parry/Z) os golpes:
#   • Parry certo  -> enche stagger + abre RIPOSTE (ele fica vulnerável).
#   • Encheu o stagger -> DERRUBADO (dano 2x).
# Estrutura:
#   FASE 1 (100–66%) : golpes simples/duplos + fintas.
#   PORTÃO (66%)     : FLURRY — rajada de golpes; defenda pra encher o stagger.
#   FASE 2 (66–33%)  : combos triplos + ESPADA ARREMESSADA (rebata no parry).
#   FASE 3 (33–0%)   : tudo mais rápido, fintas duplas, mais arremessos.
# ============================================================================
extends BossBase

@export_group("Duelo")
@export var telegraph     : float = 0.5
@export var parry_window  : float = 0.42
@export var strike_damage : float = 1_400.0
@export var parry_stagger  : float = 1_400.0
@export var throw_damage   : float = 1_600.0
@export var gap   : float = 0.28
@export var pause : float = 1.0
@export var feint_chance : float = 0.25
@export var unblock_chance: float = 0.30   ## chance de golpe AZUL (esquive) nas fases 2+

@export_group("Duelo: Fases (% HP)")
@export var th_gate_pct : float = 0.66
@export var th_p3_pct   : float = 0.33

@export_group("Duelo: Skins (opcional)")
@export var skin_espada_arremesso : PackedScene
@export var skin_corte : PackedScene   ## corte em cruz (fase 3)

var _phase := 1


func fight() -> void:
	_set_body("Corpo", Color(0.55, 0.55, 0.7))
	is_immune = true

	# FASE 1
	_phase = 1
	_phase_card("FASE 1 — A Saudação")
	while _alive() and current_hp > max_hp * th_gate_pct:
		await _round()

	# PORTÃO: flurry de parry
	if _alive():
		await _gate_flurry()

	# FASE 2
	_phase = 2
	_set_color(Color(0.6, 0.5, 0.8)); _restore_body_color()
	_phase_card("FASE 2 — O Espelho Rachado: cuidado com o azul (dash)!")
	while _alive() and current_hp > max_hp * th_p3_pct:
		await _round()

	# FASE 3
	_phase = 3
	_phase_card("FASE 3 — Fúria do Duelista")
	while _alive():
		await _round()


# Uma rodada: às vezes arremessa, às vezes parte pro combo de parry.
func _round() -> void:
	if _phase >= 2 and randf() < 0.35:
		await _thrown_sword()
		await _after_attack(pause * 0.6)
		return

	# Fase 3: às vezes abre com um corte em cruz (esquivável).
	if _phase >= 3 and randf() < 0.3:
		await _atk_cross()
		await _after_attack(pause * 0.6)
		return

	await _move_to(_approach_pos(), move_speed)
	if not _alive(): return
	var n := _combo_len()
	var parried := 0
	for s in n:
		if not _alive(): return
		# Golpe AZUL = inesquivável por parry: tem que DASH. (fases 2+)
		if _phase >= 2 and randf() < unblock_chance:
			await _unblockable_strike()
			await _sleep(gap)
			continue
		if randf() < _feint_chance():
			await _feint()
			continue
		if await _strike():
			parried += 1
			if stagger >= max_stagger:
				await _topple(); break
		await _sleep(gap)
	if parried > 0 and _alive() and state == State.FIGHT:
		await _riposte(parried)
	await _after_attack(pause)


# Golpe AZUL (inesquivável): parry NÃO funciona — tem que DASH (i-frame).
func _unblockable_strike() -> void:
	_set_color(Color(0.3, 0.6, 1.0))   # azul = esquive
	await _sleep(_scaled(telegraph))
	if not _alive(): return
	_set_color(Color(0.6, 0.85, 1.0))
	_play_anim("attack")
	var dt := get_physics_process_delta_time()
	var t := 0.0
	var safe := false
	while _alive() and t < 0.2:
		if _player_invincible():
			safe = true; break
		t += dt
		await get_tree().physics_frame
	if not safe and _player_alive():
		_player.take_damage(strike_damage * 1.3)
	_restore_body_color()


# Corte em CRUZ: duas linhas (horizontal + vertical) telegrafadas. Esquive.
func _atk_cross() -> void:
	_announce("Corte em Cruz — fique nos quadrantes!", Color(0.7, 0.85, 1.0))
	await _move_to(_arena_center(), move_speed)
	_play_anim("attack")
	var cx := _arena_center().x
	var cy := _arena_center().y
	_spawn_hazard(Vector2(cx, cy), Vector2(arena_right - arena_left, 12.0),
		Color(0.7, 0.8, 1.0), strike_damage, 0.8, 0.3, 0.0, true, false, skin_corte)
	_spawn_hazard(Vector2(cx, cy), Vector2(12.0, arena_floor - arena_top),
		Color(0.7, 0.8, 1.0), strike_damage, 0.8, 0.3, 0.0, true, false, skin_corte)
	await _sleep(1.3)


func _strike() -> bool:
	_set_color(Color(1.0, 0.3, 0.3))
	await _sleep(_scaled(telegraph))
	if not _alive(): return false
	_set_color(Color(1, 1, 1))
	_play_anim("attack")
	var ok := await _await_counter(_scaled(parry_window))
	if ok:
		_parry_feedback()
		add_stagger(parry_stagger, true)   # parry-counter = mecânica (ignora nerf neutro)
		EventBus.boss_stagger_updated.emit(stagger, max_stagger)
		return true
	if _player_alive():
		_player.take_damage(strike_damage)
	_restore_body_color()
	return false


func _feint() -> void:
	_set_color(Color(1.0, 0.5, 0.2))
	await _sleep(_scaled(telegraph) * 0.6)
	_restore_body_color()
	await _sleep(0.35)


# Espada arremessada: projétil reto, REBATÍVEL no Parry (dissipa perto).
func _thrown_sword() -> void:
	_announce("Lâmina Arremessada — rebata no parry!", Color(0.85, 0.85, 1.0))
	await _move_to(_idle_pos(), move_speed)
	if not _player_alive(): return
	_play_anim("throw")
	var dir := (_player.global_position - global_position).normalized()
	_spawn_projectile(PROJECTILE.Mode.STRAIGHT, global_position, dir, 360.0,
		throw_damage, true, skin_espada_arremesso, Vector2(20, 6), Color(0.8, 0.85, 1.0))


# PORTÃO: rajada de golpes rápidos. Defenda o bastante pra DERRUBÁ-LO.
func _gate_flurry() -> void:
	_gate_card("PORTÃO — A Rajada: DEFENDA tudo (Z)!")
	await _move_to(_approach_pos(), move_speed)
	is_immune = true
	var total := 6
	var need := 4
	var parried := 0
	for s in total:
		if not _alive(): break
		_set_color(Color(1.0, 0.3, 0.3))
		await _sleep(_scaled(telegraph) * 0.7)
		if not _alive(): break
		_set_color(Color(1, 1, 1))
		if await _await_counter(_scaled(parry_window)):
			parried += 1
			_parry_feedback()
		elif _player_alive():
			_player.take_damage(strike_damage)
		await _sleep(0.18)
	is_immune = false
	_restore_body_color()
	if parried >= need and _alive():
		_announce("Rajada quebrada — DERRUBADO!", Color(1.0, 0.9, 0.3))
		await _topple()


func _riposte(count: int) -> void:
	_announce("RIPOSTE — ataque agora!", Color(0.4, 0.8, 1.0))
	is_immune = false
	_set_color(Color(0.4, 0.7, 1.0))
	await _sleep(0.45 + 0.45 * count)
	is_immune = true
	_stun_pending = false
	_restore_body_color()


func _topple() -> void:
	_announce("DERRUBADO — janela de dano!", Color(1.0, 0.9, 0.3))
	is_immune = false
	_stun_pending = true
	await _do_stun()
	is_immune = true


func _combo_len() -> int:
	match _phase:
		1: return [1, 1, 2][randi() % 3]
		2: return [2, 2, 3][randi() % 3]
		_: return [2, 3, 3][randi() % 3]


func _feint_chance() -> float:
	return feint_chance + (0.0 if _phase == 1 else 0.15)


func _scaled(v: float) -> float:
	var frac : float = clampf(current_hp / max_hp, 0.0, 1.0)
	return v * lerpf(0.55, 1.0, frac)


func _approach_pos() -> Vector2:
	var x := _player_x()
	var side := -50.0 if x > _arena_center().x else 50.0
	return Vector2(clampf(x + side, arena_left + 30.0, arena_right - 30.0), arena_floor - 20.0)
