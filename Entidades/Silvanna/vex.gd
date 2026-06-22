# vex.gd — RAID 1, GATE 2: Vex, a Acólita das Lâminas
# ============================================================================
# Prelúdio ao Armateus-Lâmina da Silvanna: cortes horizontais, espadas que
# ricocheteiam (rebatíveis), e CHUVA de espadas com brechas. Portão = chuva
# longa que precisa de stagger pra parar.
# ============================================================================
extends BossBase

@export_group("Vex")
@export var slash_damage : float = 1_800.0
@export var blade_damage : float = 1_400.0
@export var rain_damage  : float = 2_000.0
@export var rain_gaps    : int   = 2
@export var pause        : float = 1.0
@export var th_gate_pct : float = 0.50

@export_group("Vex: Tempos e velocidade")
@export var blade_speed      : float = 360.0
@export var slash_telegraph  : float = 0.75
@export var slash_active     : float = 0.25
@export var cross_telegraph  : float = 0.8
@export var cross_active     : float = 0.3
@export var rain_telegraph   : float = 0.9
@export var rain_active      : float = 0.4
@export var gate_time        : float = 11.0

@export_group("Vex: Skins (opcional)")
@export var skin_corte : PackedScene
@export var skin_lamina : PackedScene


func fight() -> void:
	_set_body("Corpo", Color(0.6, 0.7, 0.95))
	var i := 0
	while _alive() and current_hp > max_hp * th_gate_pct:
		match i % 3:
			0: await _atk_slash()
			1: await _atk_bounce_blades()
			2: await _atk_cross()
		i += 1
		await _after_attack(pause)
	if _alive(): await _gate_rain()
	_phase_card("FASE 2 — Fúria das Lâminas")
	i = 0
	while _alive():
		match i % 4:
			0: await _atk_slash()
			1: await _atk_bounce_blades()
			2: await _atk_cross()
			3: await _atk_rain()
		i += 1
		await _after_attack(pause * 0.8)


func _atk_slash() -> void:
	await _move_to(_idle_pos(), move_speed)
	_play_anim("attack")
	var y := randf_range(arena_top + 30.0, arena_floor - 12.0)
	_spawn_hazard(Vector2(_arena_center().x, y), Vector2(arena_right - arena_left, 10.0),
		Color(0.9, 0.9, 1.0), slash_damage, slash_telegraph, slash_active, 0.0, true, false, skin_corte)
	await _sleep(1.2)


func _atk_bounce_blades() -> void:
	_play_anim("attack")
	var base := (_player.global_position - global_position).angle() if _player_alive() else 0.0
	for k in 3:
		var ang := base + deg_to_rad(40.0 * (float(k) - 1.0))
		_spawn_projectile(PROJECTILE.Mode.BOUNCE, global_position, Vector2.RIGHT.rotated(ang),
			blade_speed, blade_damage, true, skin_lamina, Vector2(14, 4), Color(0.85, 0.9, 1.0))
	await _sleep(0.6)


func _atk_cross() -> void:
	_announce("Corte em X — esquive pelos quadrantes!", Color(0.85, 0.9, 1.0))
	await _move_to(_arena_center(), move_speed)
	_play_anim("attack")
	var c := _arena_center()
	# linha horizontal + vertical
	_spawn_hazard(c, Vector2(arena_right - arena_left, 12.0), Color(0.9, 0.95, 1.0),
		slash_damage, cross_telegraph, cross_active, 0.0, true, false, skin_corte)
	_spawn_hazard(c, Vector2(12.0, arena_floor - arena_top), Color(0.9, 0.95, 1.0),
		slash_damage, cross_telegraph, cross_active, 0.0, true, false, skin_corte)
	await _sleep(1.3)


func _atk_rain() -> void:
	_announce("Chuva de Espadas — corra para as brechas!", Color(0.85, 0.9, 1.0))
	await _move_to(_arena_center() + Vector2(0, -50), move_speed)
	_play_anim("attack")
	var step := 38.0
	var n : int = int((arena_right - arena_left) / step)
	var gaps : Dictionary = {}
	var safety := 0
	while gaps.size() < mini(rain_gaps, n) and safety < 50:
		gaps[randi() % n] = true; safety += 1
	for c in n:
		if gaps.has(c): continue
		var cx : float = arena_left + step * 0.5 + c * step
		_spawn_hazard(Vector2(cx, _arena_center().y), Vector2(24.0, arena_floor - arena_top),
			Color(0.85, 0.9, 1.0), rain_damage, rain_telegraph, rain_active, 0.0, true, false, skin_lamina)
	await _sleep(1.5)


func _gate_rain() -> void:
	_gate_card("PORTÃO — Chuva Sem Fim: quebre a postura!")
	var rain_cd := 0.0
	var on_tick = func(dt: float) -> void:
		rain_cd -= dt
		if rain_cd <= 0.0:
			rain_cd = 1.4
			var step := 60.0
			var n : int = int((arena_right - arena_left) / step)
			var gap := randi() % n
			for c in n:
				if c == gap: continue
				var cx : float = arena_left + step * 0.5 + c * step
				_spawn_hazard(Vector2(cx, _arena_center().y), Vector2(28.0, arena_floor - arena_top),
					Color(0.85, 0.9, 1.0), rain_damage * 0.7, 0.8, 0.35, 0.0, true, false, skin_lamina)
	var ok := await _stagger_gate(gate_time, on_tick, false)
	if ok: _announce("Chuva quebrada!", Color(0.5, 1.0, 0.8))
