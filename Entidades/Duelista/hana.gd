# hana.gd — RAID 2, GATE 2: Hana, a Mestra dos Arremessos
# ============================================================================
# Antessala da espada arremessada do Kael. Hana joga SHURIKENS em padrões
# geométricos (cruz, X, fan). Parry perto destrói os shurikens (rebatíveis).
# 2 fases + 1 portão (chuva de shurikens — esquive nas brechas).
# ============================================================================
extends BossBase

@export_group("Hana")
@export var shuriken_damage : float = 1_300.0
@export var th_gate_pct : float = 0.55
@export var pause : float = 1.0

@export_group("Hana: Velocidade dos shurikens")
@export var cross_speed  : float = 280.0
@export var fan_speed    : float = 300.0
@export var circle_speed : float = 250.0
@export var homing_speed : float = 200.0
@export var rain_speed   : float = 240.0
@export var gate_time    : float = 10.0

@export_group("Hana: Skins (opcional)")
@export var skin_shuriken : PackedScene


func fight() -> void:
	_set_body("Corpo", Color(0.95, 0.7, 0.5))
	var i := 0
	while _alive() and current_hp > max_hp * th_gate_pct:
		match i % 3:
			0: await _pattern_cross()
			1: await _pattern_fan()
			2: await _pattern_circle()
		i += 1
		await _after_attack(pause)
	if _alive(): await _gate_rain()
	_phase_card("FASE 2 — Dança das Lâminas")
	i = 0
	while _alive():
		match i % 4:
			0: await _pattern_cross()
			1: await _pattern_fan()
			2: await _pattern_circle()
			3: await _pattern_homing()
		i += 1
		await _after_attack(pause * 0.8)


# 4 shurikens em cruz (cima/baixo/esq/dir).
func _pattern_cross() -> void:
	_play_anim("throw")
	for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
		_spawn_projectile(PROJECTILE.Mode.STRAIGHT, global_position,
			Vector2.RIGHT.rotated(ang), cross_speed, shuriken_damage, true,
			skin_shuriken, Vector2(12, 12), Color(0.95, 0.8, 0.4))
	await _sleep(0.6)


# Leque de 5 na direção do player.
func _pattern_fan() -> void:
	_play_anim("throw")
	var base := (_player.global_position - global_position).angle() if _player_alive() else 0.0
	for k in 5:
		var ang := base + deg_to_rad(20.0 * (float(k) - 2.0))
		_spawn_projectile(PROJECTILE.Mode.STRAIGHT, global_position,
			Vector2.RIGHT.rotated(ang), fan_speed, shuriken_damage, true,
			skin_shuriken, Vector2(12, 12), Color(0.95, 0.8, 0.4))
	await _sleep(0.55)


# 8 shurikens em círculo (todas as direções).
func _pattern_circle() -> void:
	_play_anim("throw")
	for k in 8:
		var ang := TAU * (float(k) / 8.0)
		_spawn_projectile(PROJECTILE.Mode.STRAIGHT, global_position,
			Vector2.RIGHT.rotated(ang), circle_speed, shuriken_damage, true,
			skin_shuriken, Vector2(12, 12), Color(0.95, 0.8, 0.4))
	await _sleep(0.7)


# Shuriken teleguiado: parry dissipa.
func _pattern_homing() -> void:
	_play_anim("throw")
	for k in 2:
		_spawn_projectile(PROJECTILE.Mode.HOMING, global_position, Vector2.UP, homing_speed,
			shuriken_damage, true, skin_shuriken, Vector2(14, 14), Color(1.0, 0.5, 0.3))
		await _sleep(0.4)
	await _sleep(0.8)


# Portão: chuva de shurikens caindo, encontre as brechas (encha o stagger).
func _gate_rain() -> void:
	_gate_card("PORTÃO — Chuva de Shurikens!")
	var cd := 0.0
	var on_tick = func(dt: float) -> void:
		cd -= dt
		if cd <= 0.0:
			cd = 0.55
			# 4 shurikens caindo em x aleatórios
			for k in 4:
				var px := randf_range(arena_left + 20.0, arena_right - 20.0)
				_spawn_projectile(PROJECTILE.Mode.STRAIGHT,
					Vector2(px, arena_top + 10.0), Vector2.DOWN, rain_speed,
					shuriken_damage * 0.7, true, skin_shuriken,
					Vector2(12, 12), Color(0.95, 0.8, 0.4))
	var ok := await _stagger_gate(gate_time, on_tick, false)
	if ok: _announce("Chuva quebrada!", Color(0.5, 1.0, 0.8))
