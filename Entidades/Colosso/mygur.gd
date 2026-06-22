# mygur.gd — RAID 3, GATE 2: Mygur, o Trog Gigante
# ============================================================================
# Antípoda do Colosso: GIGANTE mas RÁPIDO. Investidas curtas seguidas e PULOS
# que caem em círculo de impacto. SEM armadura — fere normal. 2 fases + portão
# (investidas em loop, pequena janela pra atacar entre elas).
# ============================================================================
extends BossBase

@export_group("Mygur")
@export var charge_damage : float = 2_200.0
@export var charge_speed  : float = 460.0
@export var jump_damage   : float = 2_400.0
@export var jump_radius   : float = 40.0
@export var pause         : float = 0.9
@export var th_gate_pct   : float = 0.50

@export_group("Mygur: Skins (opcional)")
@export var skin_impacto : PackedScene
@export var skin_pista   : PackedScene


func fight() -> void:
	_set_body("Corpo", Color(0.55, 0.6, 0.35))
	var i := 0
	while _alive() and current_hp > max_hp * th_gate_pct:
		match i % 2:
			0: await _atk_short_charge()
			1: await _atk_jump_slam()
		i += 1
		await _after_attack(pause)
	if _alive(): await _gate_loop()
	_phase_card("FASE 2 — Furor do Trog")
	i = 0
	while _alive():
		match i % 3:
			0: await _atk_short_charge()
			1: await _atk_jump_slam()
			2: await _atk_double_charge()
		i += 1
		await _after_attack(pause * 0.85)


# Investida curta: pista telegrafada metade da arena, ele corre.
func _atk_short_charge() -> void:
	var from_left := _player_x() > _arena_center().x
	var start_x : float = arena_left + 24.0 if from_left else arena_right - 24.0
	var end_x : float = arena_right - 24.0 if from_left else arena_left + 24.0
	var y := arena_floor - 22.0
	await _move_to(Vector2(start_x, y), move_speed * 1.3)
	if not _alive(): return
	var lane := _make_cube(Vector2((start_x + end_x) * 0.5, y),
		Vector2(absf(end_x - start_x), 36.0), Color(1.0, 0.6, 0.2, 0.28), skin_pista)
	await _sleep(0.55)
	lane.queue_free()
	_play_anim("charge")
	var dir : float = signf(end_x - start_x)
	var dt := get_physics_process_delta_time()
	var hit := false
	while _alive() and ((dir > 0 and global_position.x < end_x) or (dir < 0 and global_position.x > end_x)):
		global_position.x += dir * charge_speed * dt
		if not hit and _player_alive() and absf(_player.global_position.x - global_position.x) < 28.0 \
				and absf(_player.global_position.y - y) < 30.0 and not _player.get("is_dashing"):
			_player.take_damage(charge_damage); hit = true
		await get_tree().physics_frame


# Pulo: telegrafa círculo no chão, cai dando dano em quem está dentro.
func _atk_jump_slam() -> void:
	_play_anim("slam")
	var px : float = _player.global_position.x if _player_alive() else _arena_center().x
	_spawn_circle(Vector2(px, arena_floor - 12.0), jump_radius, Color(0.7, 0.8, 0.4),
		jump_damage, 0.8, 0.3, true, false, skin_impacto)
	await _sleep(1.1)


func _atk_double_charge() -> void:
	await _atk_short_charge()
	await _sleep(0.3)
	await _atk_short_charge()


# Portão: investidas em loop curtas — encha o stagger enquanto desvia.
func _gate_loop() -> void:
	_gate_card("PORTÃO — Loop de Investida!")
	is_immune = true
	var dt := get_physics_process_delta_time()
	var t := 0.0
	var gate_time := 11.0
	while _alive() and t < gate_time:
		t += dt
		if t + 1.0 < gate_time:
			# investida sem await — corre paralelo
			_charge_pass()
			await _sleep(1.6)
		else:
			await get_tree().physics_frame
		if stagger >= max_stagger:
			break
	is_immune = false
	_reset_stagger()


func _charge_pass() -> void:
	var from_left : bool = randf() > 0.5
	var start_x : float = arena_left + 24.0 if from_left else arena_right - 24.0
	var end_x   : float = arena_right - 24.0 if from_left else arena_left + 24.0
	var y := arena_floor - 22.0
	global_position = Vector2(start_x, y)
	var dir : float = signf(end_x - start_x)
	var dt := get_physics_process_delta_time()
	var t := 0.0
	while _alive() and t < 1.3:
		t += dt
		global_position.x += dir * charge_speed * 0.9 * dt
		if _player_alive() and absf(_player.global_position.x - global_position.x) < 26.0 \
				and absf(_player.global_position.y - y) < 30.0 and not _player.get("is_dashing"):
			_player.take_damage(charge_damage * 0.7)
		await get_tree().physics_frame
