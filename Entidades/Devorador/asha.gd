# asha.gd — RAID 5, GATE 1: Asha, a Salamandra
# ============================================================================
# Prelúdio ao Vorth. Asha tem TRILHA DE FOGO no chão por onde anda (dano por
# tick), dispara BOLAS DE FOGO (rebatíveis no parry) e MINI-LAVA (precursor da
# pulsante). 2 fases + portão (jato de fogo girando — fique fora da linha).
# ============================================================================
extends BossBase

@export_group("Asha")
@export var trail_tick_damage : float = 600.0
@export var fireball_damage   : float = 1_400.0
@export var minilava_damage   : float = 1_800.0
@export var pause             : float = 1.1
@export var th_gate_pct       : float = 0.55

@export_group("Asha: Tempos e velocidade")
@export var fireball_speed : float = 240.0
@export var homing_speed   : float = 150.0
@export var jet_speed      : float = 220.0
@export var trail_active   : float = 3.0
@export var lava_telegraph : float = 0.7
@export var lava_active    : float = 2.5
@export var lava_duration  : float = 3.3
@export var gate_time      : float = 10.0

@export_group("Asha: Skins (opcional)")
@export var skin_trilha : PackedScene
@export var skin_bola   : PackedScene
@export var skin_lava   : PackedScene


func fight() -> void:
	_set_body("Corpo", Color(1.0, 0.55, 0.2))
	# começa cuspindo trilha enquanto se reposiciona
	var i := 0
	while _alive() and current_hp > max_hp * th_gate_pct:
		match i % 3:
			0: await _atk_fireballs()
			1: await _atk_trail()
			2: await _atk_mini_lava()
		i += 1
		await _after_attack(pause)
	if _alive(): await _gate_jet()
	_phase_card("FASE 2 — Salamandra Inflamada")
	i = 0
	while _alive():
		match i % 4:
			0: await _atk_fireballs()
			1: await _atk_trail()
			2: await _atk_mini_lava()
			3: await _atk_homing_fireballs()
		i += 1
		await _after_attack(pause * 0.85)


func _atk_fireballs() -> void:
	_play_anim("attack")
	for k in 3:
		if not _player_alive(): break
		var dir := (_player.global_position - global_position).normalized()
		_spawn_projectile(PROJECTILE.Mode.STRAIGHT, global_position, dir, fireball_speed,
			fireball_damage, true, skin_bola, Vector2(18, 18), Color(1.0, 0.5, 0.1))
		await _sleep(0.4)
	await _sleep(0.4)


func _atk_homing_fireballs() -> void:
	_play_anim("attack")
	for k in 2:
		_spawn_projectile(PROJECTILE.Mode.HOMING, global_position, Vector2.UP, homing_speed,
			fireball_damage, true, skin_bola, Vector2(20, 20), Color(1.0, 0.4, 0.2))
		await _sleep(0.45)
	await _sleep(0.6)


# Anda pela arena deixando uma trilha de fogo no chão (3 segmentos longos).
func _atk_trail() -> void:
	_play_anim("attack")
	var start_left : bool = randf() > 0.5
	var step := (arena_right - arena_left) / 4.0
	for k in 3:
		var cx : float = (arena_left + step) + step * float(k) if start_left \
			else (arena_right - step) - step * float(k)
		await _move_to(Vector2(cx, arena_floor - 22.0), move_speed * 1.2)
		_spawn_hazard(Vector2(cx, arena_floor - 8.0), Vector2(step + 6.0, 14.0),
			Color(1.0, 0.45, 0.05), trail_tick_damage, 0.3, trail_active, 0.5,
			true, false, skin_trilha)


# Mini-lava: faixa CENTRAL alta por 2.5s (suba nas plataformas — Vorth-light).
func _atk_mini_lava() -> void:
	_announce("LAVA SUBINDO — suba nas plataformas!", Color(1.0, 0.45, 0.1))
	await _move_to(Vector2(_arena_center().x, arena_top + 30.0), move_speed)
	_spawn_hazard(Vector2(_arena_center().x, arena_floor - 6.0),
		Vector2(arena_right - arena_left, 26.0), Color(1.0, 0.35, 0.05),
		minilava_damage, lava_telegraph, lava_active, 0.5, true, false, skin_lava)
	await _sleep(lava_duration)


# Portão: jato de fogo girando da Asha — fique fora da linha, encha o stagger.
func _gate_jet() -> void:
	_gate_card("PORTÃO — Jato Giratório: fique fora da linha!")
	await _move_to(_arena_center(), move_speed)
	var ang_cd : float = 0.0
	var angle := 0.0
	var on_tick = func(dt: float) -> void:
		angle += dt * 1.2   # rad/s
		ang_cd -= dt
		if ang_cd <= 0.0:
			ang_cd = 0.5
			# 2 projéteis na direção atual, opostos
			for s in [1.0, -1.0]:
				_spawn_projectile(PROJECTILE.Mode.STRAIGHT, _arena_center(),
					Vector2.RIGHT.rotated(angle + (PI if s < 0.0 else 0.0)), jet_speed,
					fireball_damage * 0.7, false, skin_bola, Vector2(16, 16),
					Color(1.0, 0.5, 0.1))
	var ok := await _stagger_gate(gate_time, on_tick, false)
	if ok: _announce("Jato apagado!", Color(0.5, 1.0, 0.8))
