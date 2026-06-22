# karva.gd — RAID 5, GATE 2: Karva, o Wyrm das Cinzas
# ============================================================================
# Prelúdio ao swoop/wipe do Vorth. Karva VOA no alto e:
#   • CUSPE EXPLOSIVO: projétil que cria um círculo de fogo onde cai.
#   • MERGULHO: telegrafa coluna, desce e sobe (igual swoop do Vorth).
#   • CHAMA EM CRUZ: 4 linhas saindo do centro (rotação).
# 2 fases + portão (chuva de cuspes — encha o stagger nas brechas).
# ============================================================================
extends BossBase

@export_group("Karva")
@export var spit_radius   : float = 32.0
@export var spit_damage   : float = 1_600.0
@export var dive_damage   : float = 2_400.0
@export var dive_speed    : float = 580.0
@export var pause         : float = 1.0
@export var th_gate_pct   : float = 0.55

@export_group("Karva: Skins (opcional)")
@export var skin_cuspe    : PackedScene
@export var skin_explosao : PackedScene
@export var skin_mergulho : PackedScene


func fight() -> void:
	_set_body("Corpo", Color(0.85, 0.3, 0.15))
	is_immune = false
	# Voa no alto sempre
	await _move_to(Vector2(_arena_center().x, arena_top + 30.0), move_speed)
	var i := 0
	while _alive() and current_hp > max_hp * th_gate_pct:
		match i % 3:
			0: await _atk_spit()
			1: await _atk_dive()
			2: await _atk_cross_flame()
		i += 1
		await _after_attack(pause)
	if _alive(): await _gate_spit_rain()
	_phase_card("FASE 2 — Fúria do Wyrm")
	i = 0
	while _alive():
		match i % 4:
			0: await _atk_spit()
			1: await _atk_dive()
			2: await _atk_cross_flame()
			3: await _atk_triple_spit()
		i += 1
		await _after_attack(pause * 0.8)


# Cuspe: projétil que vira CÍRCULO de fogo onde cai (perto do player).
func _atk_spit() -> void:
	_play_anim("attack")
	if not _player_alive(): return
	var target := _player.global_position
	# projétil rápido pra criar suspense
	_spawn_projectile(PROJECTILE.Mode.STRAIGHT, global_position,
		(target - global_position).normalized(), 320.0, spit_damage * 0.5,
		true, skin_cuspe, Vector2(14, 14), Color(1.0, 0.45, 0.1))
	# o telegrafo do círculo já avisa antes da explosão
	_spawn_circle(target, spit_radius, Color(1.0, 0.4, 0.1),
		spit_damage, 0.8, 0.3, true, false, skin_explosao)
	await _sleep(1.2)


func _atk_triple_spit() -> void:
	for k in 3:
		if not _player_alive(): break
		var target := _player.global_position + Vector2(randf_range(-40.0, 40.0), 0.0)
		_spawn_circle(target, spit_radius, Color(1.0, 0.4, 0.1),
			spit_damage * 0.8, 0.7, 0.3, true, false, skin_explosao)
		await _sleep(0.3)
	await _sleep(0.5)


# Mergulho (precursor do swoop do Vorth): vai pra cima do player, desce e sobe.
func _atk_dive() -> void:
	await _move_to(Vector2(_player_x(), arena_top + 24.0), move_speed * 1.4)
	if not _alive(): return
	var warn := _make_cube(Vector2(global_position.x, _arena_center().y),
		Vector2(36.0, arena_floor - arena_top), Color(1.0, 0.5, 0.1, 0.22), skin_mergulho)
	await _sleep(0.6)
	warn.queue_free()
	_play_anim("swoop")
	var dt := get_physics_process_delta_time()
	var hit := false
	while _alive() and global_position.y < arena_floor - 24.0:
		global_position.y += dive_speed * dt
		if not hit and _player_alive() \
				and global_position.distance_to(_player.global_position) < 24.0 \
				and not _player.get("is_dashing"):
			_player.take_damage(dive_damage); hit = true
		await get_tree().physics_frame
	await _sleep(0.4)   # janela de DPS no chão
	while _alive() and global_position.y > arena_top + 30.0:
		global_position.y -= dive_speed * 0.7 * dt
		await get_tree().physics_frame


# 4 linhas saindo do centro em cruz/X (alterna).
func _atk_cross_flame() -> void:
	_play_anim("attack")
	var c := _arena_center()
	var diag : bool = randf() > 0.5
	var angs := [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75] if diag else [0.0, PI * 0.5, PI, PI * 1.5]
	for a in angs:
		_spawn_projectile(PROJECTILE.Mode.STRAIGHT, c, Vector2.RIGHT.rotated(a),
			260.0, spit_damage, false, skin_cuspe, Vector2(14, 6), Color(1.0, 0.5, 0.2))
	await _sleep(0.7)


# Portão: chuva de cuspes — encha o stagger nas brechas.
func _gate_spit_rain() -> void:
	_gate_card("PORTÃO — Chuva de Cinzas: encontre as brechas!")
	var cd : float = 0.0
	var on_tick = func(dt: float) -> void:
		cd -= dt
		if cd <= 0.0:
			cd = 0.55
			var px := randf_range(arena_left + 30.0, arena_right - 30.0)
			var py := randf_range(arena_top + 60.0, arena_floor - 24.0)
			_spawn_circle(Vector2(px, py), 26.0, Color(1.0, 0.4, 0.1),
				spit_damage * 0.7, 0.6, 0.25, true, false, skin_explosao)
	var ok := await _stagger_gate(11.0, on_tick, false)
	if ok: _announce("Cinzas dispersas!", Color(0.5, 1.0, 0.8))
