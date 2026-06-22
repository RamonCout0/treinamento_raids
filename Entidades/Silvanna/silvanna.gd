# silvanna.gd  —  BOSS 1: Silvanna, a Maga de Prata
# ============================================================================
# IDENTIDADE: maratona multi-fase. Escada de fases por HP, com PORTÕES DE STAGGER
# nas transições (encha a barra a tempo ou é wipe) e um DPS check no final.
# Stressa: TODAS as ferramentas (resistência / aprender a dança).
#
# Versão enxuta e otimizada da luta original do AS-astral (toda a encanação
# agora vem de BossBase). Veja COMO_USAR.md p/ trocar placeholders e tunar.
# ============================================================================
extends BossBase

# --- LIMIARES DE FASE (% do HP máx — mude o max_hp e as fases se ajustam) ---
@export_group("Silvanna: Limiares (%)")
@export var th_trans1_pct   : float = 0.80
@export var th_trans2_pct   : float = 0.55
@export var th_vassoura_pct : float = 0.45
@export var th_espelhos_pct : float = 0.35
@export var th_final_pct    : float = 0.10

@export_group("Silvanna: Ritmo")
@export var pause_fase1 : float = 1.2
@export var pause_fase2 : float = 1.0
@export var pause_fase3 : float = 1.4

@export_group("Silvanna: Ataques")
@export var pendulo_speed  : float = 1.8
@export var pendulo_damage : float = 2_000.0
@export var pendulo_range  : float = 30.0
@export var laser_telegraph : float = 0.8
@export var laser_speed     : float = 170.0
@export var laser_damage    : float = 1_800.0
@export var corte_damage    : float = 2_400.0
@export var espadas_damage  : float = 2_600.0
@export var espadas_gaps    : int   = 2
@export var duelo_window    : float = 0.8
@export var duelo_damage    : float = 2_200.0

@export_group("Silvanna: Transições/Eventos")
@export var vortice_time : float = 22.0
@export var vortice_pull : float = 200.0
@export var trans2_time  : float = 18.0
@export var espelho_laser_interval : float = 1.1
@export var espelho_laser_damage   : float = 1_400.0
@export var vassoura_wind : float = 240.0
@export var vassoura_time : float = 6.0
@export var vassoura_counter_window : float = 1.8

@export_group("Silvanna: Fase Final")
@export var final_time      : float = 35.0
@export var final_dps_check : float = 12_000.0
@export var hipotermia_pct  : float = 0.02

# --- skins opcionais (placeholder = cubo) ---
@export_group("Silvanna: Skins (opcional)")
@export var skin_laser  : PackedScene
@export var skin_gelo   : PackedScene
@export var skin_corte  : PackedScene
@export var skin_espada : PackedScene
@export var skin_nucleo : PackedScene
@export var skin_faca   : PackedScene
@export var skin_dragao : PackedScene

var _did_vassoura := false
var _did_espelhos := false


func fight() -> void:
	await _phase_1()
	if not _alive(): return
	await _trans_1()
	if not _alive(): return
	await _phase_2()
	if not _alive(): return
	await _trans_2()
	if not _alive(): return
	await _phase_3()
	if not _alive(): return
	await _phase_final()


# ── FASE 1 — CHAPÉU ──────────────────────────────────────────────
func _phase_1() -> void:
	_phase_card("FASE 1 — O Prelúdio")
	_set_body("Forma_Chapeu", Color(0.6, 0.1, 0.1))
	var i := 0
	while _alive() and current_hp > max_hp * th_trans1_pct:
		match i % 3:
			0: await _atk_pendulo()
			1: await _atk_varredura()
			2: await _atk_gelo()
		i += 1
		await _after_attack(pause_fase1)


func _atk_pendulo() -> void:
	var from_left := randf() > 0.5
	var start := Vector2(arena_left + 16.0 if from_left else arena_right - 16.0, arena_top + 16.0)
	var end_x := _player_x()
	var peak := arena_floor - 6.0
	await _move_to(start, move_speed)
	if not _alive(): return
	_play_anim("attack")
	var t := 0.0
	var dmg_cd := 0.0
	var dt := get_physics_process_delta_time()
	while _alive() and t < 1.0:
		t += dt * pendulo_speed
		var tt := clampf(t, 0.0, 1.0)
		var x := lerpf(start.x, end_x, tt)
		var y := lerpf(start.y, peak, pow(sin(tt * PI), 0.6))
		global_position = Vector2(clampf(x, arena_left, arena_right), clampf(y, arena_top, arena_floor))
		dmg_cd -= dt
		if _player_alive() and global_position.distance_to(_player.global_position) < pendulo_range and dmg_cd <= 0.0 and not _player_invincible():
			_player.take_damage(pendulo_damage); dmg_cd = 0.3
		await get_tree().physics_frame
	_play_anim("idle")
	await _move_to(_idle_pos(), move_speed)


func _atk_varredura() -> void:
	var from_left := randf() > 0.5
	var x : float = (arena_left + 16.0) if from_left else (arena_right - 16.0)
	# coluna vertical que avisa e depois varre horizontalmente
	var beam := _make_cube(Vector2(x, _arena_center().y), Vector2(6.0, arena_floor - arena_top), Color(1.0, 0.1, 0.05, 0.35))
	_play_anim("laser_warn")
	await _sleep(laser_telegraph)
	if not _alive(): beam.queue_free(); return
	_play_anim("laser_fire")
	var dir : float = signf(_player_x() - x)
	if dir == 0.0: dir = 1.0
	var dt := get_physics_process_delta_time()
	while _alive():
		x += dir * laser_speed * dt
		beam.global_position.x = x
		if _player_alive() and absf(_player.global_position.x - x) < 10.0 and not _player_invincible():
			_player.take_damage(laser_damage)
		if x <= arena_left + 8.0 or x >= arena_right - 8.0:
			break
		await get_tree().physics_frame
	beam.queue_free()


func _atk_gelo() -> void:
	await _move_to(_idle_pos(), move_speed)
	for n in 3:
		var px := randf_range(arena_left + 30.0, arena_right - 30.0)
		_spawn_hazard(Vector2(px, arena_floor - 6.0), Vector2(56.0, 12.0),
			Color(0.4, 0.8, 1.0), 0.0, 0.5, 6.0, 0.0, true, false, skin_gelo)
		await _sleep(0.25)


# ── TRANSIÇÃO 1 — VÓRTICE (portão de stagger) ────────────────────
func _trans_1() -> void:
	_gate_card("TRANSIÇÃO — O Vórtice: quebre a postura ou wipe!")
	_set_body("Forma_Chapeu", Color(0.5, 0.1, 0.7))
	is_immune = true
	await _move_to(Vector2(_arena_center().x, arena_floor - 20.0), move_speed)
	_reset_stagger()
	var core := _spawn_hazard(global_position, Vector2(34.0, 34.0), Color(0.6, 0.0, 0.8),
		0.0, 0.3, vortice_time + 5.0, 0.0, false, true, skin_nucleo)
	var dt := get_physics_process_delta_time()
	var t := 0.0
	var ok := false
	while _alive() and t < vortice_time:
		t += dt
		if _player_alive():
			_player.global_position.x = move_toward(_player.global_position.x, _arena_center().x, vortice_pull * dt)
		if stagger >= max_stagger:
			ok = true; break
		await get_tree().physics_frame
	if is_instance_valid(core): core.queue_free()
	if not ok and _alive(): _wipe()
	_reset_stagger()
	is_immune = false


# ── FASE 2 — LÂMINA ──────────────────────────────────────────────
func _phase_2() -> void:
	_phase_card("FASE 2 — A Lâmina Sombria")
	_set_body("Forma_Lamina", Color(0.2, 0.3, 0.9))
	var i := 0
	while _alive() and current_hp > max_hp * th_trans2_pct:
		match i % 3:
			0: await _atk_corte()
			1: await _atk_duelo()
			2: await _atk_espadas()
		i += 1
		await _after_attack(pause_fase2)


func _atk_corte() -> void:
	await _move_to(Vector2(arena_left + 12.0, arena_floor - 30.0), move_speed * 1.25)
	_play_anim("attack")
	var low := randf() > 0.5
	var y : float = (arena_floor - 12.0) if low else (arena_floor - 60.0)
	_spawn_hazard(Vector2(_arena_center().x, y), Vector2(arena_right - arena_left, 10.0),
		Color(1.0, 0.0, 0.0), corte_damage, 0.8, 0.2, 0.0, true, false, skin_corte)
	await _sleep(1.2)


func _atk_duelo() -> void:
	var real_left := randf() > 0.5
	var lx := arena_left + 34.0
	var rx := arena_right - 34.0
	var real_x : float = lx if real_left else rx
	var cl := _make_cube(Vector2(lx, arena_floor - 20.0), Vector2(30, 40), Color(0.1, 0.3, 1.0) if real_left else Color(0.3, 0.3, 0.3))
	var cr := _make_cube(Vector2(rx, arena_floor - 20.0), Vector2(30, 40), Color(0.1, 0.3, 1.0) if not real_left else Color(0.3, 0.3, 0.3))
	var valid := func() -> bool:
		return _player_alive() and absf(_player.global_position.x - real_x) < 140.0
	var ok := await _await_counter(duelo_window, valid)
	if ok:
		_parry_feedback(); add_stagger(max_stagger * 0.4)
	elif _alive() and _player_alive():
		_player.take_damage(duelo_damage)
	cl.queue_free(); cr.queue_free()


func _atk_espadas() -> void:
	await _move_to(_arena_center() + Vector2(0, -50), move_speed)
	var step := 38.0
	var n := int((arena_right - arena_left) / step)
	var gaps := {}
	var safety := 0
	while gaps.size() < mini(espadas_gaps, n) and safety < 50:
		gaps[randi() % n] = true; safety += 1
	for c in n:
		if gaps.has(c): continue
		var cx := arena_left + step * 0.5 + c * step
		_spawn_hazard(Vector2(cx, _arena_center().y), Vector2(24.0, arena_floor - arena_top),
			Color(0.8, 0.1, 0.1), espadas_damage, 1.0, 0.5, 0.0, true, false, skin_espada)
	await _sleep(1.8)


# ── TRANSIÇÃO 2 — LASERS DE ESPELHO (portão de stagger) ──────────
func _trans_2() -> void:
	_gate_card("TRANSIÇÃO — A Fúria da Bruxa: quebre a postura!")
	_set_body("Forma_Bruxa", Color(0.0, 0.5, 0.6))
	is_immune = true
	await _move_to(_idle_pos(), move_speed)
	_reset_stagger()
	var dt := get_physics_process_delta_time()
	var t := 0.0
	var cd := 0.0
	var ok := false
	while _alive() and t < trans2_time:
		t += dt; cd -= dt
		if cd <= 0.0:
			cd = espelho_laser_interval
			var h := randf_range(arena_top + 30.0, arena_floor - 10.0)
			_spawn_hazard(Vector2(_arena_center().x, h), Vector2(arena_right - arena_left, 8.0),
				Color(1.0, 0.2, 0.2), espelho_laser_damage, 0.8, 0.5)
		if stagger >= max_stagger:
			ok = true; break
		await get_tree().physics_frame
	if not ok and _alive(): _wipe()
	_reset_stagger()
	is_immune = false


# ── FASE 3 — TEMPESTADE ──────────────────────────────────────────
func _phase_3() -> void:
	_phase_card("FASE 3 — A Tempestade Prateada")
	_set_body("Forma_Bruxa", Color(0.85, 0.85, 0.95))
	var i := 0
	while _alive() and current_hp > max_hp * th_final_pct:
		if not _did_vassoura and current_hp <= max_hp * th_vassoura_pct:
			_did_vassoura = true; await _event_vassoura(); continue
		if not _did_espelhos and current_hp <= max_hp * th_espelhos_pct:
			_did_espelhos = true; await _event_espelhos(); continue
		match i % 3:
			0: await _atk_facas()
			1: await _atk_dragao()
			2: await _atk_gelo_meteoros()
		i += 1
		await _after_attack(pause_fase3)


# Meteoros de gelo: círculos telegrafados caindo (variedade na fase 3).
func _atk_gelo_meteoros() -> void:
	_announce("Estilhaços de Gelo!", Color(0.5, 0.85, 1.0))
	for k in 4:
		if not _alive(): return
		var px := randf_range(arena_left + 30.0, arena_right - 30.0)
		var py := randf_range(arena_top + 40.0, arena_floor - 16.0)
		_spawn_circle(Vector2(px, py), 26.0, Color(0.5, 0.85, 1.0), corte_damage * 0.6, 0.7, 0.3, true, false, skin_gelo)
		await _sleep(0.3)
	await _sleep(0.5)


func _atk_facas() -> void:
	var base := (_player.global_position - global_position).angle() if _player_alive() else 0.0
	for k in 5:
		var frac := (float(k) / 4.0) - 0.5
		var ang := base + deg_to_rad(80.0 * frac)
		_spawn_projectile(PROJECTILE.Mode.BOUNCE, global_position, Vector2.RIGHT.rotated(ang),
			380.0, 800.0, false, skin_faca, Vector2(12, 4), Color(0.9, 0.9, 0.6))
	await _sleep(0.4)


func _atk_dragao() -> void:
	for h in 2:
		_spawn_projectile(PROJECTILE.Mode.HOMING,
			Vector2(randf_range(arena_left + 30.0, arena_right - 30.0), arena_floor - 14.0),
			Vector2.UP, 180.0, 1500.0, true, skin_dragao, Vector2(28, 20), Color(1.0, 0.4, 0.0, 0.9))
		await _sleep(0.5)
	await _sleep(2.0)


func _event_vassoura() -> void:
	_announce("Vassoura Empurradora — vá para a direita e parry (Z)!", Color(0.85, 0.85, 1.0))
	await _move_to(Vector2(arena_right - 20.0, arena_floor - 20.0), move_speed)
	var spikes := _spawn_hazard(Vector2(arena_left + 8.0, _arena_center().y),
		Vector2(16.0, arena_floor - arena_top), Color(0.7, 0.7, 0.7), 0.0, 0.3, vassoura_time + 3.0, 0.0, false, true)
	var dt := get_physics_process_delta_time()
	var t := 0.0
	while _alive() and t < vassoura_time:
		t += dt
		if _player_alive():
			_player.global_position.x += vassoura_wind * dt
		await get_tree().physics_frame
	_set_color(Color(1.0, 1.0, 0.4))
	var valid := func() -> bool:
		return _player_alive() and _player.global_position.x > _arena_center().x
	var ok := await _await_counter(vassoura_counter_window, valid)
	if ok:
		_parry_feedback(); _stun_pending = true
	elif _alive() and _player_alive():
		_player.take_damage(3000.0)
	if is_instance_valid(spikes): spikes.queue_free()
	_set_body("Forma_Bruxa", Color(0.85, 0.85, 0.95))
	await _check_stun()


func _event_espelhos() -> void:
	_announce("Espelhos Gêmeos — fique no lado oposto ao ícone!", Color(0.85, 0.85, 1.0))
	await _move_to(_arena_center(), move_speed)
	var icon_red := randf() > 0.5
	var lc := _make_cube(Vector2(arena_left + 34.0, arena_floor - 20.0), Vector2(30, 40), Color(0.9, 0.1, 0.1))
	var rc := _make_cube(Vector2(arena_right - 34.0, arena_floor - 20.0), Vector2(30, 40), Color(0.85, 0.85, 0.9))
	var icon := _make_cube(global_position + Vector2(0, -30), Vector2(14, 14), Color(0.9, 0.1, 0.1) if icon_red else Color(0.85, 0.85, 0.9))
	var valid_x : float = (arena_right - 34.0) if icon_red else (arena_left + 34.0)
	var valid := func() -> bool:
		return _player_alive() and absf(_player.global_position.x - valid_x) < 140.0
	var ok := await _await_counter(5.0, valid)
	if ok: _parry_feedback()
	elif _alive() and _player_alive(): _player.take_damage(2000.0)
	lc.queue_free(); rc.queue_free(); icon.queue_free()


# ── FASE FINAL — ZERO ABSOLUTO (DPS check) ───────────────────────
func _phase_final() -> void:
	_phase_card("FASE FINAL — O Zero Absoluto: DPS check!", Color(0.7, 0.95, 1.0))
	_set_body("Forma_Final", Color(0.7, 0.95, 1.0))
	await _move_to(_idle_pos(), move_speed)
	var fog := _spawn_fog()
	current_hp = final_dps_check
	EventBus.boss_health_updated.emit(current_hp)
	var dt := get_physics_process_delta_time()
	var t := 0.0
	var hypo_cd := 0.0
	var knife_cd := 0.0
	var cut_cd := 0.0
	var ok := false
	while _alive() and t < final_time:
		t += dt
		hypo_cd -= dt
		if hypo_cd <= 0.0 and _player_alive():
			hypo_cd = 1.0
			_player.take_damage(_player.get("max_health") * hipotermia_pct)
		knife_cd -= dt
		if knife_cd <= 0.0:
			knife_cd = 1.3; _atk_facas()
		cut_cd -= dt
		if cut_cd <= 0.0:
			cut_cd = 1.8
			var y := randf_range(arena_top + 30.0, arena_floor - 12.0)
			_spawn_hazard(Vector2(_arena_center().x, y), Vector2(arena_right - arena_left, 10.0),
				Color(1, 0, 0), corte_damage, 0.7, 0.2, 0.0, true, false, skin_corte)
		if current_hp <= 0.0:
			ok = true; break
		await get_tree().physics_frame
	if is_instance_valid(fog): fog.queue_free()
	if ok: _die()
	elif _alive(): _wipe()


# Nevasca placeholder (tela cheia). Troque por sua arte/shader depois.
func _spawn_fog() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 1
	var fog := ColorRect.new()
	fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog.color = Color(0.85, 0.92, 1.0, 0.18)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fog)
	get_parent().add_child(layer)
	return layer
