# colosso.gd  —  BOSS 3: Gorm, o Colosso de Pedra
# ============================================================================
# IDENTIDADE: POSICIONAMENTO + STAGGER, agora MULTI-FASE como a Silvanna.
# Blindado: leva pouco dano normal — construa STAGGER (Heavy/V) pra DERRUBÁ-LO.
#   FASE 1 (100–60%) : pisão (onda), pedras (rebatíveis), investida.
#   PORTÃO (60%)     : ROCHA GIGANTE — encha o stagger a tempo ou é esmagado (wipe).
#   FASE 2 (60–25%)  : tudo mais rápido + CHUVA DE ROCHAS do teto.
#   FASE 3 (25–0%)   : TREMOR (ondas pelo chão inteiro) + ritmo frenético.
# ============================================================================
extends BossBase

@export_group("Colosso")
@export var armor_mult     : float = 0.30
@export var slam_damage    : float = 2_600.0
@export var wave_damage    : float = 2_000.0
@export var boulder_damage : float = 1_800.0
@export var charge_damage  : float = 3_000.0
@export var charge_speed   : float = 520.0
@export var rock_damage    : float = 1_900.0
@export var pause          : float = 1.6

@export_group("Colosso: Fases (% HP)")
@export var th_gate_pct : float = 0.60
@export var th_p3_pct   : float = 0.25

@export_group("Colosso: Skins (opcional)")
@export var skin_impacto : PackedScene   ## pisão central
@export var skin_onda    : PackedScene   ## onda de choque / tremor
@export var skin_pedra   : PackedScene   ## pedras (projétil) e chuva de rochas
@export var skin_pista   : PackedScene   ## telegrafo da investida
@export var skin_rocha   : PackedScene   ## sombra da rocha gigante (portão)

var _phase := 1
var _gate_cd := 0.0


func take_damage(amount: float) -> void:
	var amt := amount
	if state == State.FIGHT:
		amt *= armor_mult
	super.take_damage(amt)


func fight() -> void:
	_set_body("Corpo", Color(0.45, 0.42, 0.38))

	_phase = 1
	_phase_card("FASE 1 — Despertar de Pedra")
	var i := 0
	while _alive() and current_hp > max_hp * th_gate_pct:
		await _rotate(i); i += 1
		await _after_attack(pause)

	if _alive():
		await _gate_rocha()

	_phase = 2
	_phase_card("FASE 2 — A Montanha Treme")
	i = 0
	while _alive() and current_hp > max_hp * th_p3_pct:
		if i % 4 == 3:
			await _atk_circles()
		else:
			await _rotate(i)
		i += 1
		await _after_attack(pause * 0.8)

	_phase = 3
	_phase_card("FASE 3 — Fúria do Colosso")
	i = 0
	while _alive():
		if i % 3 == 2:
			await _atk_tremor()
		else:
			await _rotate(i)
		i += 1
		await _after_attack(pause * 0.6)


func _rotate(i: int) -> void:
	match i % 4:
		0: await _atk_pisao()
		1: await _atk_pedras()
		2: await _atk_investida()
		3: await _atk_get_close()


# DONUT (à la Lost Ark "fique perto"): dano em TODA a arena, menos colado nele.
func _atk_get_close() -> void:
	_announce("FIQUE PERTO — dano fora do círculo verde!", Color(0.4, 1.0, 0.5))
	await _move_to(_idle_pos(), move_speed)
	if not _alive(): return
	_play_anim("slam")
	# zona segura = círculo ao redor do corpo; quem estiver longe leva o golpe.
	_spawn_safezone(global_position, 64.0, Color(0.3, 1.0, 0.4), slam_damage, 1.4, 0.5)
	await _sleep(2.1)


# Chuva de meteoros: círculos telegrafados caindo pela arena.
func _atk_circles() -> void:
	_announce("Chuva de Pedras!", Color(0.8, 0.6, 0.4))
	await _move_to(_idle_pos(), move_speed)
	_play_anim("throw")
	for k in 5:
		if not _alive(): return
		var px := randf_range(arena_left + 24.0, arena_right - 24.0)
		var py := randf_range(arena_top + 40.0, arena_floor - 16.0)
		_spawn_circle(Vector2(px, py), 30.0, Color(0.6, 0.45, 0.3), rock_damage, 0.7, 0.3, true, false, skin_pedra)
		await _sleep(0.28)
	await _sleep(0.5)


# ── Portão: rocha gigante (encha o stagger ou wipe) ──────────────
func _gate_rocha() -> void:
	_gate_card("PORTÃO — ROCHA GIGANTE: quebre a postura!")
	await _move_to(_idle_pos(), move_speed)
	# Sombra crescente da rocha no centro (telegrafo permanente).
	var shadow := _make_cube(Vector2(_arena_center().x, arena_floor - 10.0), Vector2(120, 18), Color(0.3, 0.2, 0.1, 0.5), skin_rocha)
	_gate_cd = 0.0
	var ok := await _stagger_gate(12.0, _on_gate_tick, true)
	if is_instance_valid(shadow): shadow.queue_free()
	if ok:
		_announce("Rocha estilhaçada!", Color(0.5, 1.0, 0.8))


func _on_gate_tick(dt: float) -> void:
	_gate_cd -= dt
	if _gate_cd <= 0.0:
		_gate_cd = 0.9
		var px := randf_range(arena_left + 20.0, arena_right - 20.0)
		_spawn_hazard(Vector2(px, arena_top + 20.0), Vector2(26, 26), Color(0.5, 0.4, 0.3),
			rock_damage, 0.5, 0.3, 0.0, true, false, skin_pedra)


# ── Ataques ──────────────────────────────────────────────────────
func _atk_pisao() -> void:
	await _move_to(Vector2(_player_x(), arena_floor - hover_height), move_speed)
	if not _alive(): return
	_play_anim("slam")
	var cx := global_position.x
	_spawn_hazard(Vector2(cx, arena_floor - 8.0), Vector2(60.0, 16.0),
		Color(0.8, 0.5, 0.2), slam_damage, 0.7, 0.3, 0.0, true, false, skin_impacto)
	await _sleep(0.7)
	var step := 46.0
	var n := int((arena_right - arena_left) / step)
	for k in range(1, n):
		var delay := 0.07 * k
		var rx := cx + step * k
		var lx := cx - step * k
		if rx < arena_right - 6.0:
			_spawn_hazard(Vector2(rx, arena_floor - 8.0), Vector2(34.0, 16.0),
				Color(0.85, 0.6, 0.25), wave_damage, delay, 0.22, 0.0, true, false, skin_onda)
		if lx > arena_left + 6.0:
			_spawn_hazard(Vector2(lx, arena_floor - 8.0), Vector2(34.0, 16.0),
				Color(0.85, 0.6, 0.25), wave_damage, delay, 0.22, 0.0, true, false, skin_onda)
	await _sleep(0.07 * n + 0.4)


func _atk_pedras() -> void:
	await _move_to(_idle_pos(), move_speed)
	_play_anim("throw")
	var count := 3 if _phase == 1 else 4
	for k in count:
		if not _player_alive(): break
		var dir := (_player.global_position - global_position).normalized()
		_spawn_projectile(PROJECTILE.Mode.STRAIGHT, global_position, dir, 300.0,
			boulder_damage, true, skin_pedra, Vector2(22, 22), Color(0.6, 0.55, 0.5))
		await _sleep(0.45)
	await _sleep(0.4)


func _atk_investida() -> void:
	var from_left := _player_x() > _arena_center().x
	var start_x : float = (arena_left + 20.0) if from_left else (arena_right - 20.0)
	var y := arena_floor - 22.0
	await _move_to(Vector2(start_x, y), move_speed)
	if not _alive(): return
	var lane := _make_cube(Vector2(_arena_center().x, y), Vector2(arena_right - arena_left, 40.0), Color(1.0, 0.4, 0.1, 0.25), skin_pista)
	await _sleep(0.8)
	lane.queue_free()
	_play_anim("charge")
	var dir : float = 1.0 if from_left else -1.0
	var spd : float = charge_speed * (1.0 if _phase < 3 else 1.25)
	var dt := get_physics_process_delta_time()
	var hit := false
	while _alive():
		global_position.x += dir * spd * dt
		if not hit and _player_alive() and absf(_player.global_position.x - global_position.x) < 28.0 \
				and absf(_player.global_position.y - y) < 30.0 and not _player.get("is_dashing"):
			_player.take_damage(charge_damage); hit = true
		if global_position.x <= arena_left + 16.0 or global_position.x >= arena_right - 16.0:
			break
		await get_tree().physics_frame
	await _move_to(_idle_pos(), move_speed)


# Chuva de rochas do teto (várias colunas com brechas).
func _atk_chuva_rochas() -> void:
	_announce("Chuva de Rochas!", Color(0.8, 0.6, 0.4))
	await _move_to(_idle_pos(), move_speed)
	for w in 6:
		var px := randf_range(arena_left + 16.0, arena_right - 16.0)
		_spawn_hazard(Vector2(px, arena_top + 20.0), Vector2(28, 28), Color(0.5, 0.4, 0.3),
			rock_damage, 0.5, 0.3, 0.0, true, false, skin_pedra)
		await _sleep(0.22)
	await _sleep(0.6)


# Tremor: ondas saindo do centro pelo chão inteiro (pule/dash).
func _atk_tremor() -> void:
	_announce("TREMOR — pule ou dash por cima das ondas!", Color(0.9, 0.55, 0.2))
	await _move_to(_idle_pos(), move_speed)
	var cx := _arena_center().x
	var step := 40.0
	var n := int((arena_right - arena_left) / step)
	for k in range(1, n):
		var delay := 0.06 * k
		_spawn_hazard(Vector2(cx + step * k, arena_floor - 8.0), Vector2(30, 18), Color(0.9, 0.55, 0.2),
			wave_damage, delay, 0.2, 0.0, true, false, skin_onda)
		_spawn_hazard(Vector2(cx - step * k, arena_floor - 8.0), Vector2(30, 18), Color(0.9, 0.55, 0.2),
			wave_damage, delay, 0.2, 0.0, true, false, skin_onda)
	await _sleep(0.06 * n + 0.5)
