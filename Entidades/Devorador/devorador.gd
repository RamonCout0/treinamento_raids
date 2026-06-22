# devorador.gd  —  BOSS 5: Vorth, o Devorador (FINAL)
# ============================================================================
# IDENTIDADE: CAPSTONE — usa TODAS as ferramentas. Três atos por HP:
#   1) TERRESTRE  — cortes, almas teleguiadas (parry dissipa) e leques de garra.
#   2) AÉREO      — o chão vira LAVA: suba/segure nas PAREDES (grab/wall-climb).
#                   Ele mergulha (swoop); acerte-o quando ele desce.
#   3) WIPE       — um ataque que MATA. A ÚNICA forma de sobreviver é o PARRY.
#   FINAL         — DPS check: ele DEVORA sua vida por segundo; mate a tempo.
#
# Stressa: mobilidade (wall-climb/dash), parry (wipe + almas) e DPS sob pressão.
# ============================================================================
extends BossBase

@export_group("Devorador: Limiares (HP)")
@export var th_air   : float = 20_000.0
@export var th_wipe  : float =  8_000.0
@export var final_dps_check : float = 10_000.0

@export_group("Devorador: Terrestre")
@export var cut_damage  : float = 2_200.0
@export var soul_damage : float = 1_400.0
@export var claw_damage : float = 1_600.0
@export var pause_ground : float = 1.3

@export_group("Devorador: Aéreo (lava pulsante)")
@export var lava_tick_damage  : float = 700.0   ## dano/tick da lava no chão
@export var lava_up_time      : float = 4.0     ## tempo COM lava (fique nas plataformas)
@export var safe_window       : float = 4.0     ## tempo SEM lava (desça e ataque)
@export var fireball_interval : float = 0.85    ## frequência das bolas de fogo
@export var fireball_radius   : float = 26.0
@export var fireball_damage   : float = 1_800.0
@export var ground_attack_dmg : float = 2_000.0 ## corte na janela de DPS

@export_group("Devorador: Skins (opcional)")
@export var skin_corte    : PackedScene   ## corte horizontal
@export var skin_alma     : PackedScene   ## alma teleguiada
@export var skin_garra    : PackedScene   ## leque de garras
@export var skin_lava     : PackedScene   ## faixa de lava (ato aéreo)
@export var skin_mergulho : PackedScene   ## coluna de aviso do mergulho

@export_group("Devorador: Wipe / Final")
@export var wipe_telegraph : float = 1.4
@export var wipe_window    : float = 0.6
@export var final_time     : float = 35.0
@export var devour_pct     : float = 0.03   ## % da vida máx. do player drenada/seg


func fight() -> void:
	await _phase_ground()
	if not _alive(): return
	await _phase_air()
	if not _alive(): return
	await _attack_wipe()
	if not _alive(): return
	await _phase_final()


# ── ATO 1 — TERRESTRE ────────────────────────────────────────────
func _phase_ground() -> void:
	_phase_card("ATO 1 — O Devorador Desperta")
	_set_body("Corpo_Terra", Color(0.35, 0.1, 0.15))
	var i := 0
	while _alive() and current_hp > th_air:
		match i % 5:
			0: await _atk_cut()
			1: await _atk_souls()
			2: await _atk_claw_fan()
			3: await _atk_meteors()
			4: await _atk_safezone()
		i += 1
		await _after_attack(pause_ground)


# Meteoros: vários círculos telegrafados caindo (desvie andando/dash).
func _atk_meteors() -> void:
	_announce("Chuva de Meteoros — fique fora dos círculos!", Color(1.0, 0.5, 0.1))
	_play_anim("attack")
	for k in 4:
		if not _alive(): return
		var px := randf_range(arena_left + 30.0, arena_right - 30.0)
		_spawn_circle(Vector2(px, arena_floor - 12.0), 28.0, Color(1.0, 0.5, 0.1),
			cut_damage * 0.7, 0.7, 0.3)
		await _sleep(0.3)
	await _sleep(0.6)


# Zona segura: fique DENTRO do círculo verde ou toma o golpe.
func _atk_safezone() -> void:
	_announce("Fique no círculo verde!", Color(0.4, 1.0, 0.5))
	var c := Vector2(randf_range(arena_left + 70.0, arena_right - 70.0), arena_floor - 20.0)
	_spawn_safezone(c, 46.0, Color(0.3, 1.0, 0.4), cut_damage, 1.3, 0.5)
	await _sleep(2.0)


func _atk_cut() -> void:
	await _move_to(_idle_pos(), move_speed)
	_play_anim("attack")
	var y := randf_range(arena_top + 30.0, arena_floor - 12.0)
	_spawn_hazard(Vector2(_arena_center().x, y), Vector2(arena_right - arena_left, 10.0),
		Color(1.0, 0.1, 0.1), cut_damage, 0.7, 0.25, 0.0, true, false, skin_corte)
	await _sleep(1.1)


func _atk_souls() -> void:
	_play_anim("attack")
	for k in 3:
		if not _alive(): return
		_spawn_projectile(PROJECTILE.Mode.HOMING, global_position, Vector2.DOWN, 165.0,
			soul_damage, true, skin_alma, Vector2(18, 18), Color(0.8, 0.2, 0.5, 0.9))
		await _sleep(0.45)
	await _sleep(0.8)


func _atk_claw_fan() -> void:
	_play_anim("attack")
	var base := (_player.global_position - global_position).angle() if _player_alive() else PI * 0.5
	for k in 5:
		var frac := (float(k) / 4.0) - 0.5
		var ang := base + deg_to_rad(70.0 * frac)
		_spawn_projectile(PROJECTILE.Mode.STRAIGHT, global_position, Vector2.RIGHT.rotated(ang),
			320.0, claw_damage, false, skin_garra, Vector2(14, 6), Color(1.0, 0.5, 0.2))
	await _sleep(0.6)


# ── ATO 2 — AÉREO (lava PULSANTE; suba nas plataformas) ─────────
# Ritmo de raid: LAVA SOBE (sobreviva nas plataformas dodgeando bolas de fogo)
# -> LAVA BAIXA (ele desce e fica vulnerável; DESÇA e ataque) -> repete.
func _phase_air() -> void:
	_phase_card("ATO 2 — Mar de Lava: use as plataformas!", Color(1.0, 0.5, 0.2))
	_set_body("Corpo_Aereo", Color(0.9, 0.4, 0.1))
	is_immune = true
	await _move_to(Vector2(_arena_center().x, arena_top + 26.0), move_speed)
	while _alive() and current_hp > th_wipe:
		await _lava_wave()
		if not _alive(): break
		await _ground_window()
	is_immune = false
	await _move_to(_idle_pos(), move_speed)


# Lava sobe: chão vira dano por lava_up_time; bolas de fogo caem na sua posição.
func _lava_wave() -> void:
	_announce("LAVA SUBINDO — suba já!", Color(1.0, 0.45, 0.1))
	is_immune = true
	await _move_to(Vector2(_arena_center().x, arena_top + 26.0), move_speed * 1.5)
	var lava := _spawn_hazard(Vector2(_arena_center().x, arena_floor - 4.0),
		Vector2(arena_right - arena_left, 34.0), Color(1.0, 0.35, 0.05),
		lava_tick_damage, 0.7, lava_up_time, 0.6, true, false, skin_lava)
	var dt := get_physics_process_delta_time()
	var t := 0.0
	var fb := 0.6
	while _alive() and t < lava_up_time:
		t += dt
		fb -= dt
		if fb <= 0.0:
			fb = fireball_interval
			var px : float = _player.global_position.x if _player_alive() else _arena_center().x
			var py : float = _player.global_position.y if _player_alive() else (arena_floor - 60.0)
			_spawn_circle(Vector2(clampf(px, arena_left + 12.0, arena_right - 12.0),
				clampf(py, arena_top + 20.0, arena_floor - 20.0)),
				fireball_radius, Color(1.0, 0.5, 0.1), fireball_damage, 0.6, 0.3)
		await get_tree().physics_frame
	if is_instance_valid(lava): lava.queue_free()


# Lava baixa: ele desce ao alcance do melee e fica VULNERÁVEL; cortes telegrafados.
func _ground_window() -> void:
	_announce("ABERTURA — desça e ataque!", Color(1.0, 0.9, 0.3))
	await _move_to(Vector2(_player_x(), arena_floor - 24.0), move_speed * 1.6)
	if not _alive(): return
	is_immune = false
	var dt := get_physics_process_delta_time()
	var t := 0.0
	var atk := 0.9
	while _alive() and t < safe_window:
		t += dt
		atk -= dt
		if atk <= 0.0:
			atk = 1.4
			_play_anim("attack")
			var y := arena_floor - randf_range(10.0, 44.0)
			_spawn_hazard(Vector2(_arena_center().x, y), Vector2(arena_right - arena_left, 10.0),
				Color(1.0, 0.3, 0.1), ground_attack_dmg, 0.6, 0.25, 0.0, true, false, skin_corte)
		await get_tree().physics_frame
	is_immune = true


# ── ATO 3 — WIPE (só o Parry salva) ─────────────────────────────
func _attack_wipe() -> void:
	_wipe_card("ATAQUE FINAL — DEFENDA (Z) OU MORRA!")
	is_immune = true
	await _move_to(_idle_pos(), move_speed)
	# telegrafo grande (tela pulsa vermelho)
	var flash := _spawn_screen_flash(Color(1.0, 0.0, 0.0, 0.0))
	var dt := get_physics_process_delta_time()
	var t := 0.0
	while _alive() and t < wipe_telegraph:
		t += dt
		if is_instance_valid(flash):
			flash.color.a = 0.35 * (sin(t * 12.0) * 0.5 + 0.5)
		await get_tree().physics_frame
	if not _alive():
		if is_instance_valid(flash): flash.get_parent().queue_free()
		return
	# o instante: parry agora
	if is_instance_valid(flash): flash.color.a = 0.6
	_set_color(Color(1, 1, 1))
	var ok := await _await_counter(wipe_window)
	if is_instance_valid(flash): flash.get_parent().queue_free()
	if ok:
		_announce("DEFENDIDO — ele cambaleia!", Color(0.5, 1.0, 0.8))
		_parry_feedback()
		is_immune = false
		_stun_pending = true
		await _do_stun()
	elif _alive():
		_wipe()
	is_immune = false


# ── FINAL — DPS check com devorar ───────────────────────────────
func _phase_final() -> void:
	_phase_card("FINAL — Acabe com ele antes que te devore!", Color(0.6, 0.0, 0.1))
	_set_body("Corpo_Final", Color(0.6, 0.0, 0.1))
	current_hp = final_dps_check
	EventBus.boss_health_updated.emit(current_hp)
	var dt := get_physics_process_delta_time()
	var t := 0.0
	var devour_cd := 0.0
	var soul_cd := 0.0
	var meteor_cd := 1.2
	var ok := false
	while _alive() and t < final_time:
		t += dt
		devour_cd -= dt
		if devour_cd <= 0.0 and _player_alive():
			devour_cd = 1.0
			_player.take_damage(_player.get("max_health") * devour_pct)
		soul_cd -= dt
		if soul_cd <= 0.0:
			soul_cd = 1.6
			_spawn_projectile(PROJECTILE.Mode.HOMING, global_position, Vector2.DOWN, 175.0,
				soul_damage, true, skin_alma, Vector2(18, 18), Color(0.8, 0.2, 0.5, 0.9))
		meteor_cd -= dt
		if meteor_cd <= 0.0:
			meteor_cd = 1.5
			var px := randf_range(arena_left + 30.0, arena_right - 30.0)
			_spawn_circle(Vector2(px, arena_floor - 12.0), 26.0, Color(1.0, 0.45, 0.1),
				cut_damage * 0.6, 0.6, 0.3)
		if current_hp <= 0.0:
			ok = true; break
		await get_tree().physics_frame
	if ok: _die()
	elif _alive(): _wipe()


func _spawn_screen_flash(c: Color) -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 2
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	get_parent().add_child(layer)
	return r
