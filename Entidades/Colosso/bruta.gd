# bruta.gd — RAID 3, GATE 1: Bruta, a Sentinela
# ============================================================================
# Versão menor do Colosso. Tem armadura mas leve (você fere com facadas
# normais). Estaca de pedra (telegrafa círculo) + onda horizontal de uma
# direção. 2 fases + portão (2 ondas simultâneas).
# ============================================================================
extends BossBase

@export_group("Bruta")
@export var armor_mult     : float = 0.55   ## menos blindada que o Gorm (0.30)
@export var stake_damage   : float = 1_800.0
@export var wave_damage    : float = 1_600.0
@export var pause          : float = 1.3
@export var th_gate_pct    : float = 0.55

@export_group("Bruta: Skins (opcional)")
@export var skin_estaca : PackedScene
@export var skin_onda   : PackedScene


func take_damage(amount: float) -> void:
	var amt := amount
	if state == State.FIGHT:
		amt *= armor_mult
	super.take_damage(amt)


func fight() -> void:
	_set_body("Corpo", Color(0.6, 0.55, 0.45))
	var i := 0
	while _alive() and current_hp > max_hp * th_gate_pct:
		match i % 2:
			0: await _atk_stake()
			1: await _atk_wave()
		i += 1
		await _after_attack(pause)
	if _alive(): await _gate_double_wave()
	_phase_card("FASE 2 — Sentinela Furiosa")
	i = 0
	while _alive():
		match i % 3:
			0: await _atk_stake()
			1: await _atk_wave()
			2: await _atk_stake_twin()
		i += 1
		await _after_attack(pause * 0.85)


# Estaca de pedra (círculo telegrafado na posição do player).
func _atk_stake() -> void:
	_play_anim("slam")
	var px : float = _player.global_position.x if _player_alive() else _arena_center().x
	_spawn_circle(Vector2(px, arena_floor - 12.0), 30.0, Color(0.7, 0.55, 0.4),
		stake_damage, 0.7, 0.3, true, false, skin_estaca)
	await _sleep(1.1)


# Onda horizontal de uma direção (ripple, telegrafo crescente).
func _atk_wave() -> void:
	_play_anim("slam")
	var from_left := _player_x() > _arena_center().x
	var dir : float = -1.0 if not from_left else 1.0
	var start_x : float = arena_left + 30.0 if from_left else arena_right - 30.0
	var step := 50.0
	var n : int = int((arena_right - arena_left) / step)
	for k in n:
		var x : float = start_x + dir * step * float(k)
		_spawn_hazard(Vector2(x, arena_floor - 10.0), Vector2(38.0, 16.0),
			Color(0.85, 0.6, 0.25), wave_damage, 0.4 + 0.07 * k, 0.22, 0.0, true, false, skin_onda)
	await _sleep(0.4 + 0.07 * n + 0.4)


# Duas estacas seguidas (uma na sua posição, outra próxima — força movimento).
func _atk_stake_twin() -> void:
	await _atk_stake()
	await _atk_stake()


# Portão: duas ondas SIMULTÂNEAS de direções opostas, encontre a brecha (jump/dash).
func _gate_double_wave() -> void:
	_gate_card("PORTÃO — Ondas Cruzadas: quebre a postura!")
	var cd := 0.0
	var on_tick = func(dt: float) -> void:
		cd -= dt
		if cd <= 0.0:
			cd = 2.6
			var step := 50.0
			var n : int = int((arena_right - arena_left) / step)
			for k in n:
				_spawn_hazard(Vector2(arena_left + 30.0 + step * k, arena_floor - 10.0),
					Vector2(38.0, 16.0), Color(0.85, 0.6, 0.25),
					wave_damage * 0.7, 0.5 + 0.06 * k, 0.22, 0.0, true, false, skin_onda)
				_spawn_hazard(Vector2(arena_right - 30.0 - step * k, arena_floor - 10.0),
					Vector2(38.0, 16.0), Color(0.85, 0.6, 0.25),
					wave_damage * 0.7, 0.5 + 0.06 * k, 0.22, 0.0, true, false, skin_onda)
	var ok := await _stagger_gate(10.0, on_tick, false)
	if ok: _announce("Ondas quebradas!", Color(0.5, 1.0, 0.8))
