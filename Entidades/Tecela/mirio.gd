# mirio.gd — RAID 4, GATE 2: Mirio, os Gêmeos Espelho
# ============================================================================
# Antessala dos clones da Nyx. Aqui só EXISTE O REAL (CharacterBody2D), mas
# ele cria UMA CÓPIA visual ao lado que ataca em sincronia. Só o real fere.
# O TELL pisca em quem é o real. 2 fases + portão (troca rápida + ataques).
# ============================================================================
extends BossBase

@export_group("Mirio")
@export var swap_time     : float = 1.6   ## tempo entre trocas (encolhe na fase 2)
@export var tell_time     : float = 0.6   ## tell pisca antes da troca
@export var slash_damage  : float = 1_700.0
@export var pause         : float = 1.0
@export var th_gate_pct   : float = 0.55

@export_group("Mirio: Skins (opcional)")
@export var skin_corte : PackedScene
@export var skin_clone : PackedScene

var _clone : Node2D = null


func fight() -> void:
	_set_body("Corpo", Color(0.55, 0.45, 0.9))
	_spawn_clone()
	var i := 0
	while _alive() and current_hp > max_hp * th_gate_pct:
		await _swap_pose(swap_time)
		match i % 2:
			0: await _atk_twin_slash()
			1: await _atk_twin_pillars()
		i += 1
		await _after_attack(pause)
	if _alive(): await _gate_swap()
	_phase_card("FASE 2 — Reflexo Frenético")
	i = 0
	while _alive():
		await _swap_pose(swap_time * 0.6)
		match i % 3:
			0: await _atk_twin_slash()
			1: await _atk_twin_pillars()
			2: await _atk_twin_fan()
		i += 1
		await _after_attack(pause * 0.8)
	_clear_clone()


func _spawn_clone() -> void:
	if _clone == null or not is_instance_valid(_clone):
		_clone = _make_cube(Vector2(arena_left + 80.0, arena_floor - 20.0),
			body_size, Color(0.55, 0.45, 0.9), skin_clone)


func _clear_clone() -> void:
	if is_instance_valid(_clone):
		_clone.queue_free()
	_clone = null


# Reposiciona o REAL e o CLONE, e pisca um TELL no real (revela quem é).
func _swap_pose(t: float) -> void:
	if not is_instance_valid(_clone): _spawn_clone()
	var lx := arena_left + 70.0
	var rx := arena_right - 70.0
	var real_left : bool = randf() > 0.5
	global_position = Vector2(lx if real_left else rx, arena_floor - 20.0)
	_clone.global_position = Vector2(rx if real_left else lx, arena_floor - 20.0)
	_set_color(Color(1.0, 0.9, 0.3))   # TELL: o REAL pisca amarelo
	await _sleep(tell_time)
	_restore_body_color()
	await _sleep(max(0.0, t - tell_time))


# Ambos cortam horizontal no mesmo Y; só o real causa dano (perigo no real).
func _atk_twin_slash() -> void:
	_play_anim("attack")
	var y := randf_range(arena_top + 30.0, arena_floor - 12.0)
	_spawn_hazard(Vector2(global_position.x, y), Vector2(140.0, 10.0),
		Color(0.7, 0.7, 1.0), slash_damage, 0.7, 0.25, 0.0, true, false, skin_corte)
	await _sleep(1.1)


# 3 colunas verticais a partir do real (force a leitura).
func _atk_twin_pillars() -> void:
	_play_anim("attack")
	for k in 3:
		var x := global_position.x + (float(k) - 1.0) * 60.0
		_spawn_hazard(Vector2(clampf(x, arena_left + 14.0, arena_right - 14.0),
			_arena_center().y), Vector2(20.0, arena_floor - arena_top),
			Color(0.7, 0.7, 1.0), slash_damage, 0.7, 0.3, 0.0, true, false, skin_corte)
	await _sleep(1.2)


func _atk_twin_fan() -> void:
	_play_anim("attack")
	for k in 5:
		var ang := -PI * 0.5 + deg_to_rad(30.0 * (float(k) - 2.0))
		_spawn_projectile(PROJECTILE.Mode.STRAIGHT, global_position,
			Vector2.RIGHT.rotated(ang), 300.0, slash_damage * 0.8, false,
			null, Vector2(14, 6), Color(0.85, 0.85, 1.0))
	await _sleep(0.6)


# Portão: trocas rapidíssimas + cortes; ache o real pelo tell e bata.
func _gate_swap() -> void:
	_gate_card("PORTÃO — Trocas Espelhadas: ache o real (dourado)!")
	var swap_cd : float = 0.0
	var slash_cd : float = 0.8
	var on_tick = func(dt: float) -> void:
		swap_cd -= dt
		slash_cd -= dt
		if swap_cd <= 0.0:
			swap_cd = 1.4
			# troca de lado e pisca o tell
			if is_instance_valid(_clone):
				var tmp := global_position
				global_position = _clone.global_position
				_clone.global_position = tmp
				_set_color(Color(1.0, 0.9, 0.3))
		if slash_cd <= 0.0:
			slash_cd = 1.3
			_restore_body_color()
			var y := randf_range(arena_top + 30.0, arena_floor - 12.0)
			_spawn_hazard(Vector2(global_position.x, y), Vector2(140.0, 10.0),
				Color(0.7, 0.7, 1.0), slash_damage * 0.75, 0.65, 0.25,
				0.0, true, false, skin_corte)
	var ok := await _stagger_gate(11.0, on_tick, false)
	if ok: _announce("Reflexo quebrado!", Color(0.5, 1.0, 0.8))
