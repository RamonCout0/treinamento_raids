# lira.gd — RAID 4, GATE 1: Lira, a Vidente
# ============================================================================
# Prelúdio à Nyx. Lira PREVÊ seus padrões: telegrafa formas geométricas
# (linhas, X, cruz) e dispara. Mas ela é REAL (sem clones — só padrões).
# 2 fases + portão "padrão rotativo" (encha o stagger lendo a rotação).
# ============================================================================
extends BossBase

@export_group("Lira")
@export var pattern_damage : float = 1_600.0
@export var pause          : float = 1.0
@export var th_gate_pct    : float = 0.55

@export_group("Lira: Tempos e velocidade")
@export var x_speed         : float = 280.0
@export var line_telegraph  : float = 0.8
@export var line_late       : float = 1.1
@export var cross_telegraph : float = 0.9
@export var line_active     : float = 0.3
@export var gate_time       : float = 10.0

@export_group("Lira: Skins (opcional)")
@export var skin_padrao : PackedScene


func fight() -> void:
	_set_body("Corpo", Color(0.7, 0.5, 1.0))
	var i := 0
	while _alive() and current_hp > max_hp * th_gate_pct:
		match i % 3:
			0: await _pattern_horizontal()
			1: await _pattern_cross()
			2: await _pattern_x()
		i += 1
		await _after_attack(pause)
	if _alive(): await _gate_rotating()
	_phase_card("FASE 2 — Visões Cruzadas")
	i = 0
	while _alive():
		match i % 4:
			0: await _pattern_horizontal()
			1: await _pattern_cross()
			2: await _pattern_x()
			3: await _pattern_quadrants()
		i += 1
		await _after_attack(pause * 0.85)


func _pattern_horizontal() -> void:
	_play_anim("cast")
	# 2 linhas horizontais, uma alta uma baixa
	var w := arena_right - arena_left
	_spawn_hazard(Vector2(_arena_center().x, arena_top + 60.0), Vector2(w, 10.0),
		Color(0.8, 0.4, 1.0), pattern_damage, line_telegraph, line_active, 0.0, true, false, skin_padrao)
	_spawn_hazard(Vector2(_arena_center().x, arena_floor - 30.0), Vector2(w, 10.0),
		Color(0.8, 0.4, 1.0), pattern_damage, line_late, line_active, 0.0, true, false, skin_padrao)
	await _sleep(1.7)


func _pattern_cross() -> void:
	_play_anim("cast")
	var c := _arena_center()
	_spawn_hazard(c, Vector2(arena_right - arena_left, 10.0), Color(0.8, 0.4, 1.0),
		pattern_damage, cross_telegraph, line_active, 0.0, true, false, skin_padrao)
	_spawn_hazard(c, Vector2(10.0, arena_floor - arena_top), Color(0.8, 0.4, 1.0),
		pattern_damage, cross_telegraph, line_active, 0.0, true, false, skin_padrao)
	await _sleep(1.4)


# X = 2 retângulos rotacionados — placeholder: 2 linhas diagonais simuladas
# por colunas cortadas. Pra simplicidade, fan de 4 projéteis nas diagonais.
func _pattern_x() -> void:
	_play_anim("cast")
	var c := _arena_center()
	for ang in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		_spawn_projectile(PROJECTILE.Mode.STRAIGHT, c, Vector2.RIGHT.rotated(ang),
			x_speed, pattern_damage, false, skin_padrao, Vector2(14, 8), Color(0.8, 0.4, 1.0))
	await _sleep(0.7)


# 4 círculos nos quadrantes (canto NE, NO, SE, SO).
func _pattern_quadrants() -> void:
	_play_anim("cast")
	var qx := [arena_left + 90.0, arena_right - 90.0, arena_left + 90.0, arena_right - 90.0]
	var qy := [arena_top + 60.0, arena_top + 60.0, arena_floor - 60.0, arena_floor - 60.0]
	for k in 4:
		_spawn_circle(Vector2(qx[k], qy[k]), 36.0, Color(0.8, 0.4, 1.0),
			pattern_damage, line_telegraph, line_active)
	await _sleep(1.4)


# Portão: padrão rotativo (linhas rotacionando lentamente — encha o stagger).
func _gate_rotating() -> void:
	_gate_card("PORTÃO — Visão Rotativa!")
	var cd := 0.0
	var on_tick = func(dt: float) -> void:
		cd -= dt
		if cd <= 0.0:
			cd = 1.4
			var y := randf_range(arena_top + 40.0, arena_floor - 20.0)
			_spawn_hazard(Vector2(_arena_center().x, y), Vector2(arena_right - arena_left, 10.0),
				Color(0.8, 0.4, 1.0), pattern_damage * 0.7, 0.7, 0.3, 0.0, true, false, skin_padrao)
	var ok := await _stagger_gate(gate_time, on_tick, false)
	if ok: _announce("Visão desfeita!", Color(0.5, 1.0, 0.8))
