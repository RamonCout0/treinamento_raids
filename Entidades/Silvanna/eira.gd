# eira.gd — RAID 1, GATE 1: Eira, a Acólita do Gelo
# ============================================================================
# Prelúdio ao tema gélido da Silvanna. Mecânicas: CRISTAIS caem em CÍRCULOS
# telegrafados, lanças de gelo retas, e uma "abraçar o centro" (zona segura).
# 2 fases curtas + portão de stagger.
# ============================================================================
extends BossBase

@export_group("Eira")
@export var crystal_damage : float = 1_400.0
@export var lance_damage   : float = 1_500.0
@export var pause          : float = 1.1
@export var th_gate_pct : float = 0.55

@export_group("Eira: Skins (opcional)")
@export var skin_cristal : PackedScene
@export var skin_lanca   : PackedScene


func fight() -> void:
	_set_body("Corpo", Color(0.5, 0.85, 1.0))
	# FASE 1
	var i := 0
	while _alive() and current_hp > max_hp * th_gate_pct:
		match i % 3:
			0: await _atk_crystals(3)
			1: await _atk_lances()
			2: await _atk_safe_center()
		i += 1
		await _after_attack(pause)
	# PORTÃO
	if _alive(): await _gate_blizzard()
	# FASE 2
	_phase_card("FASE 2 — Tempestade de Cristal")
	i = 0
	while _alive():
		match i % 3:
			0: await _atk_crystals(5)
			1: await _atk_lances()
			2: await _atk_safe_center()
		i += 1
		await _after_attack(pause * 0.8)


func _atk_crystals(n: int) -> void:
	_play_anim("cast")
	for k in n:
		if not _alive(): return
		var px := randf_range(arena_left + 24.0, arena_right - 24.0)
		var py := randf_range(arena_top + 40.0, arena_floor - 16.0)
		_spawn_circle(Vector2(px, py), 24.0, Color(0.6, 0.9, 1.0),
			crystal_damage, 0.7, 0.3, true, false, skin_cristal)
		await _sleep(0.28)
	await _sleep(0.5)


func _atk_lances() -> void:
	_play_anim("cast")
	for k in 3:
		if not _player_alive(): break
		var dir := (_player.global_position - global_position).normalized()
		_spawn_projectile(PROJECTILE.Mode.STRAIGHT, global_position, dir, 280.0,
			lance_damage, false, skin_lanca, Vector2(18, 5), Color(0.55, 0.85, 1.0))
		await _sleep(0.35)
	await _sleep(0.5)


func _atk_safe_center() -> void:
	_announce("Fique no círculo verde!", Color(0.4, 1.0, 0.5))
	_play_anim("cast")
	_spawn_safezone(_arena_center(), 48.0, Color(0.3, 1.0, 0.4),
		crystal_damage * 1.2, 1.3, 0.5)
	await _sleep(2.0)


# Portão: nevasca curta, encha o stagger ou pequeno dano contínuo
func _gate_blizzard() -> void:
	_gate_card("PORTÃO — Nevasca: quebre a postura!")
	var crystal_cd : float = 0.0
	var on_tick = func(dt: float) -> void:
		crystal_cd -= dt
		if crystal_cd <= 0.0:
			crystal_cd = 0.45
			var px := randf_range(arena_left + 24.0, arena_right - 24.0)
			_spawn_circle(Vector2(px, arena_floor - 16.0), 20.0,
				Color(0.55, 0.85, 1.0), crystal_damage * 0.6, 0.4, 0.25)
	var ok := await _stagger_gate(10.0, on_tick, false)
	if ok: _announce("Nevasca dissipada!", Color(0.5, 1.0, 0.8))
