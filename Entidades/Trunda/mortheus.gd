# mortheus.gd  —  RAID 1 (Trunda), GATE 1: Mortheus, O Último
# ============================================================================
# Cavaleiro arcano de gelo e neve. Melee + mobilidade + rajadas, costurado por
# 3 mecânicas narrativas:
#   MEC 1 — SALVA-GUARDA: escudo de gelo + bonecos de neve HITKILL avançando
#           pela direita + counters periódicos do boss. Encha o stagger (imenso)
#           antes do timer; sucesso = 17s vulnerável com 2x dano. Falha = wipe.
#   TRANSIÇÃO — Shader de sombras nasce do centro e toma a tela; troca a música.
#   MEC 2 — CAVALEIRO DAS SOMBRAS: ele joga a espada no chão e VIRA a espada.
#           Slash arqueado, Lanças das Sombras das bordas e Desaparecimento com
#           janela de counter (errar = dano colossal tela inteira).
#   MEC 3 — EXPLOSÃO DAS SOMBRAS (logo após a espada): esfera no centro cresce
#           até o wipe; quebre sombras pelo chão pra acumular 10 stacks de
#           proteção. <10 stacks no fim = wipe; >=10 = sobrevive e termina.
#
# Tudo exportado pelo Inspetor pra balancear (dano, tempos, velocidade, etc.).
# ============================================================================
extends BossBase

# --- LIMIARES DE FASE (% do HP máx) ---
@export_group("Mortheus: Limiares (% HP)")
@export var th_salva_pct    : float = 0.70   ## dispara Mecânica 1 (Salva-Guarda)
@export var th_espada_pct   : float = 0.45   ## dispara Transição + Mecânica 2 (Espada)
@export var th_explosao_pct : float = 0.15   ## dispara Mecânica 3 (Explosão das Sombras)

@export_group("Mortheus: Ritmo")
@export var pause            : float = 1.1
@export var pause_aggressive : float = 0.8   ## pausa depois do vulnerable / depois da espada


# --- ATAQUE PADRÃO 1: Investida Espada ---
@export_group("Mortheus: Investida Espada")
@export var dash_damage        : float = 1_900.0
@export var dash_speed         : float = 540.0
@export var dash_telegraph     : float = 0.45  ## tempo piscando antes de dashar
@export var dash_recover       : float = 0.6


# --- ATAQUE PADRÃO 2: Lanças Arcanas (Wipe-grande counterable) ---
@export_group("Mortheus: Lanças Arcanas (raro)")
@export var lance_cooldown        : float = 18.0   ## cooldown alto entre usos
@export var lance_invoke_time     : float = 1.4    ## tempo de invocação
@export var lance_counter_window  : float = 0.55   ## janela de parry no ápice
@export var lance_damage          : float = 4_500.0
@export var lance_half_count      : int   = 3       ## quantas lanças cobrem a metade
@export var lance_recover         : float = 1.2


# --- ATAQUE PADRÃO 3: Rajadas Verticais ---
@export_group("Mortheus: Rajadas Verticais")
@export var beam_count       : int   = 4
@export var beam_damage      : float = 1_500.0
@export var beam_telegraph   : float = 0.55
@export var beam_active      : float = 0.22
@export var beam_gap         : float = 0.32   ## delay entre rajadas
@export var beam_width       : float = 28.0


# --- MEC 1: Salva-Guarda ---
# Duas barras: ESCUDO (refilla cada ciclo — você enche batendo) + PRINCIPAL
# (só progride no counter pós-quebra-de-escudo). Mortheus anda devagar com
# escudo empurrando o player; soldados ficam parados na direita (HITKILL).
@export_group("Mortheus: Salva-Guarda")
@export var salva_shield_max          : float = 2_500.0   ## tamanho do ESCUDO (refilla cada ciclo)
@export var salva_main_cycles_needed  : int   = 4          ## quantos counters bem-sucedidos pra vencer
@export var salva_time_limit          : float = 60.0       ## tempo máx até wipe (mech demora)
@export var salva_mortheus_start_x    : float = 60.0       ## boss começa na ESQUERDA
@export var salva_mortheus_walk_speed : float = 18.0       ## px/s (lento, empurrando)
@export var salva_push_distance       : float = 22.0       ## gap mínimo Mortheus⇄player (shove)
@export var salva_soldier_count       : int   = 3          ## soldados estacionários na direita
@export var salva_soldier_start_x     : float = 420.0      ## x do primeiro soldado
@export var salva_soldier_spacing     : float = 14.0       ## entre soldados
@export var salva_soldier_kill_dist   : float = 20.0       ## dist do soldado que mata
@export var salva_counter_telegraph   : float = 0.45
@export var salva_counter_window      : float = 0.6
@export var salva_counter_fail_push   : float = 90.0       ## empurrão grande no fail
@export var salva_vuln_time           : float = 17.0       ## boss imóvel 2x dano após vencer
@export var salva_vuln_dmg_mult       : float = 2.0


# --- TRANSIÇÃO (Shader Sombras) ---
@export_group("Mortheus: Transição (Sombras)")
@export var transicao_fill_time : float = 1.4   ## tempo pra preencher a tela
@export var transicao_hold_time : float = 0.7   ## segura preto
@export var transicao_reveal    : float = 1.0   ## fade out revelando


# --- MEC 2: Cavaleiro das Sombras (a Espada) ---
@export_group("Mortheus: Espada das Sombras")
@export var espada_slash_damage    : float = 2_000.0
@export var espada_slash_radius    : float = 70.0
@export var espada_slash_telegraph : float = 0.7
@export var espada_slash_active    : float = 0.3
@export var espada_lance_damage    : float = 1_400.0
@export var espada_lance_speed     : float = 240.0
@export var espada_lance_count     : int   = 4
@export var espada_lance_gap       : float = 0.3
@export var espada_disappear_telegraph : float = 1.3
@export var espada_disappear_window    : float = 0.6
@export var espada_disappear_damage    : float = 5_500.0   ## colossal tela inteira
@export var espada_pause           : float = 1.0


# --- MEC 3: Explosão das Sombras ---
@export_group("Mortheus: Explosão das Sombras")
@export var explosao_time          : float = 22.0   ## timer pra esfera explodir
@export var explosao_stacks_needed : int   = 10
@export var explosao_wipe_damage   : float = 1.0e9  ## ignora qualquer survivability
@export var explosao_shadow_spawn_interval : float = 0.85
@export var explosao_shadow_hp         : float = 200.0   ## ~1 facada do combo
@export var explosao_shadow_touch_damage : float = 600.0  ## se o player pisar
@export var explosao_sphere_growth_rate : float = 12.0    ## px/s no raio visual


# --- SKINS (opcional, placeholder = cubo) ---
@export_group("Mortheus: Skins (opcional)")
@export var skin_lanca   : PackedScene
@export var skin_rajada  : PackedScene
@export var skin_boneco  : PackedScene
@export var skin_espada  : PackedScene
@export var skin_sombra  : PackedScene
@export var skin_esfera  : PackedScene


# === ESTADO ============================================================
var _lance_cd     : float = 0.0
var _phase_sword  : bool  = false       # mecânica 2 ativa (visual de espada)


func fight() -> void:
	_set_body("Corpo", Color(0.65, 0.85, 1.0))

	# ── FASE 1: ataques normais até bater Salva-Guarda ─────────────
	_phase_card("FASE 1 — O Último Cavaleiro")
	await _phase_normal(th_salva_pct, pause)
	if not _alive(): return

	# ── MEC 1: Salva-Guarda (inclui a janela vulnerável de 17s se vencer) ──
	await _mech_salva_guarda()
	if not _alive() or not _player_alive(): return

	# ── Continua normal até a transição ────────────────────────────
	await _phase_normal(th_espada_pct, pause_aggressive)
	if not _alive(): return

	# ── TRANSIÇÃO: shader de sombras ───────────────────────────────
	await _transition_shadows()
	if not _alive(): return

	# ── MEC 2: Cavaleiro das Sombras ───────────────────────────────
	await _phase_sword_loop()
	if not _alive(): return

	# ── MEC 3: Explosão das Sombras ────────────────────────────────
	await _mech_explosao_sombras()
	if not _alive(): return

	# Garantia: encerra a luta.
	_die()


# ============================================================================
# FASE NORMAL — rota de ataques padrão até bater o threshold de HP.
# ============================================================================
func _phase_normal(threshold_pct: float, p: float) -> void:
	var i := 0
	while _alive() and current_hp > max_hp * threshold_pct:
		# Lanças Arcanas têm cooldown — se pronto, com alguma chance, usa.
		if _lance_cd <= 0.0 and randf() < 0.35:
			await _atk_lances_arcanas()
		else:
			match i % 2:
				0: await _atk_dash_sword()
				1: await _atk_rajadas_verticais()
		i += 1
		_lance_cd = max(0.0, _lance_cd - p - 0.5)
		await _after_attack(p)


# ============================================================================
# ATAQUE 1 — Investida Espada (dash em direção ao player).
# ============================================================================
func _atk_dash_sword() -> void:
	# Posiciona no mesmo Y do player, lado oposto.
	if not _player_alive(): return
	var py := clampf(_player.global_position.y, arena_top + 24.0, arena_floor - 24.0)
	var from_left := _player.global_position.x > _arena_center().x
	var start_x : float = arena_left + 30.0 if from_left else arena_right - 30.0
	await _move_to(Vector2(start_x, py), move_speed * 1.3)
	if not _alive(): return

	# Telegrafo
	_set_color(Color(0.6, 0.85, 1.0))
	await _sleep(dash_telegraph)
	if not _alive(): return
	_restore_body_color()
	_play_anim("dash")

	# Dash atravessando a arena
	var dir : float = 1.0 if from_left else -1.0
	var dt := get_physics_process_delta_time()
	var hit := false
	while _alive():
		global_position.x += dir * dash_speed * dt
		if not hit and _player_alive() \
				and absf(_player.global_position.x - global_position.x) < 28.0 \
				and absf(_player.global_position.y - global_position.y) < 30.0 \
				and not _player_invincible():
			_player.take_damage(dash_damage)
			hit = true
		if global_position.x <= arena_left + 18.0 or global_position.x >= arena_right - 18.0:
			break
		await get_tree().physics_frame
	await _sleep(dash_recover)


# ============================================================================
# ATAQUE 2 — Lanças Arcanas (counter-or-die, cooldown alto).
# ============================================================================
func _atk_lances_arcanas() -> void:
	_announce("LANÇAS ARCANAS — defenda (Z) ou perca a metade!", Color(0.7, 0.9, 1.0))
	_lance_cd = lance_cooldown
	await _move_to(_idle_pos(), move_speed)
	if not _alive(): return

	# Invocação (pisca + carrega)
	_set_color(Color(0.6, 0.9, 1.0))
	_play_anim("cast")
	await _sleep(lance_invoke_time * 0.6)
	if not _alive(): return

	# Janela de counter no "ápice"
	_set_color(Color(1.0, 1.0, 0.3))
	var ok := await _await_counter(lance_counter_window)
	_restore_body_color()
	if ok:
		_announce("Lanças dissipadas!", Color(0.5, 1.0, 0.8))
		_parry_feedback()
		add_stagger(max_stagger * 0.35, true)
		await _sleep(0.7)
		return

	# Falhou: dispara as lanças cobrindo METADE da arena (lado do player).
	var on_right : bool = _player_x() > _arena_center().x
	var half_left  : float = arena_left  if not on_right else _arena_center().x
	var half_right : float = _arena_center().x if not on_right else arena_right
	for k in lance_half_count:
		var step : float = (half_right - half_left) / float(lance_half_count + 1)
		var x : float = half_left + step * float(k + 1)
		_spawn_hazard(Vector2(x, _arena_center().y),
			Vector2(36.0, arena_floor - arena_top), Color(0.5, 0.85, 1.0),
			lance_damage, 0.35, 0.4, 0.0, true, false, skin_lanca)
	await _sleep(lance_recover)


# ============================================================================
# ATAQUE 3 — Rajadas Verticais (4 colunas top-down).
# ============================================================================
func _atk_rajadas_verticais() -> void:
	await _move_to(_idle_pos(), move_speed)
	if not _alive(): return
	_play_anim("cast")
	var step : float = (arena_right - arena_left - 60.0) / float(beam_count - 1)
	# Aleatoriza um pouco a ordem pra não ser sempre da esquerda pra direita.
	var order : Array = range(beam_count)
	order.shuffle()
	for k in order:
		var x : float = arena_left + 30.0 + step * float(k)
		_spawn_hazard(Vector2(x, _arena_center().y),
			Vector2(beam_width, arena_floor - arena_top),
			Color(0.55, 0.8, 1.0), beam_damage, beam_telegraph, beam_active,
			0.0, true, false, skin_rajada)
		await _sleep(beam_gap)
	await _sleep(beam_telegraph + 0.2)


# ============================================================================
# MEC 1 — SALVA-GUARDA
# DUAS barras: ESCUDO (refilla cada ciclo, enche batendo) + PRINCIPAL (counters
# bem-sucedidos avançam). Mortheus anda devagar empurrando o player; soldados
# ficam PARADOS na direita (HITKILL no toque). Sequência por ciclo:
#   1. Bate no Mortheus pra encher o ESCUDO
#   2. Escudo cheio → Mortheus dispara counter-attack
#   3. Counter Z na hora certa → +1 progresso no PRINCIPAL, escudo zera, volta a empurrar
#   4. Errar counter → empurrão grande do player pra perto dos soldados
# Vence quando PRINCIPAL chega em `salva_main_cycles_needed`. Tempo expira = wipe.
# ============================================================================
func _mech_salva_guarda() -> void:
	_gate_card("SALVA-GUARDA — Quebre o Escudo, vença o Principal!")
	# Boss vai pra ESQUERDA pra começar a empurrar pra direita
	await _move_to(Vector2(salva_mortheus_start_x, arena_floor - 20.0), move_speed * 1.6)
	if not _alive(): return
	_set_body("Corpo", Color(0.5, 0.8, 1.0))

	# Configura a HUD: barra de stagger vira o ESCUDO (refilla cada ciclo)
	var orig_max := max_stagger
	max_stagger = salva_shield_max
	EventBus.boss_stagger_updated.emit(0.0, max_stagger)
	is_immune = true                    # HP protegido durante toda a mech
	_set_stagger_mech_mode(true)        # ataques entram com mult de mecânica
	_stagger_cd_t = 0.0                 # zera anti-spam (mech ignora ele)
	_reset_stagger()

	# Spawna soldados ESTACIONÁRIOS à direita
	var soldiers : Array = []
	for k in salva_soldier_count:
		var sx : float = salva_soldier_start_x + float(k) * salva_soldier_spacing
		soldiers.append(_spawn_soldier(sx))

	var main_progress := 0
	_banner("PRINCIPAL: %d / %d" % [main_progress, salva_main_cycles_needed])
	var dt := get_physics_process_delta_time()
	var t := 0.0
	var won := false
	var advancing := true
	var boss_half : float = body_size.x * 0.5
	var player_half : float = 12.0   # estimativa do corpo do player

	while _alive() and _player_alive() and t < salva_time_limit and not won:
		t += dt
		# AVANÇA (anda devagar pra direita)
		if advancing:
			var bp : Vector2 = global_position
			bp.x += salva_mortheus_walk_speed * dt
			global_position = bp
			# Empurra o player se Mortheus encostou
			var min_x : float = global_position.x + boss_half + player_half + salva_push_distance
			if _player.global_position.x < min_x:
				var pp : Vector2 = _player.global_position
				pp.x = min_x
				_player.global_position = pp
		# HITKILL: player tocou em qualquer soldado
		for s in soldiers:
			if not is_instance_valid(s) or not _player_alive() or _player_invincible():
				continue
			if abs(s.global_position.x - _player.global_position.x) < salva_soldier_kill_dist \
					and abs(s.global_position.y - _player.global_position.y) < 32.0:
				_player.take_damage(WIPE_DAMAGE)
				break
		# ESCUDO QUEBROU → trigger counter-attack
		if advancing and stagger >= max_stagger:
			advancing = false
			var counter_ok : bool = await _run_salva_counter_attack()
			if counter_ok:
				main_progress += 1
				_banner("PRINCIPAL: %d / %d" % [main_progress, salva_main_cycles_needed])
				if main_progress >= salva_main_cycles_needed:
					won = true
			# Reseta escudo e volta a empurrar
			_reset_stagger()
			advancing = true
		await get_tree().physics_frame

	# Cleanup
	for s in soldiers:
		if is_instance_valid(s):
			s.queue_free()
	max_stagger = orig_max
	EventBus.boss_stagger_updated.emit(0.0, max_stagger)
	_set_stagger_mech_mode(false)
	is_immune = false
	_restore_body_color()

	if won:
		_announce("PRINCIPAL QUEBRADO — janela de 2x dano!", Color(1.0, 0.9, 0.3))
		await _salva_vulnerable_window()
	elif _alive() and _player_alive():
		_announce("Tempo esgotado.", Color(1.0, 0.3, 0.3))
		_wipe()


# Sub-rotina do counter-attack disparado quando o escudo quebra. Retorna true
# se o player acertou o Z na janela (+1 progresso no PRINCIPAL).
func _run_salva_counter_attack() -> bool:
	_announce("ESCUDO QUEBRADO — defenda (Z)!", Color(1.0, 0.9, 0.3))
	_set_color(Color(1.0, 0.5, 0.5))
	await _sleep(salva_counter_telegraph)
	if not _alive() or not _player_alive():
		_restore_body_color()
		return false
	_set_color(Color(1.0, 1.0, 0.3))
	var ok : bool = await _await_counter(salva_counter_window)
	_restore_body_color()
	if ok:
		_parry_feedback()
		return true
	# Falhou: empurra o player MUITO pra direita (perto dos soldados)
	if _player_alive():
		var pp : Vector2 = _player.global_position
		pp.x = clampf(pp.x + salva_counter_fail_push, arena_left + 8.0, arena_right - 8.0)
		_player.global_position = pp
	return false


# Soldado estacionário à direita (HITKILL no toque; checagem no main loop).
func _spawn_soldier(x: float) -> Node2D:
	var root := Node2D.new()
	if skin_boneco:
		root.add_child(skin_boneco.instantiate())
	else:
		var v := ColorRect.new()
		v.size = Vector2(20, 36)
		v.position = -Vector2(10, 18)
		v.color = Color(0.95, 0.95, 1.0)
		root.add_child(v)
		# Lança apontando pra Mortheus (esquerda)
		var spike := ColorRect.new()
		spike.size = Vector2(28, 3)
		spike.position = Vector2(-32, -4)
		spike.color = Color(0.7, 0.85, 1.0)
		root.add_child(spike)
	get_parent().add_child(root)
	root.global_position = Vector2(x, arena_floor - 22.0)
	return root


# Janela vulnerável pós Salva-Guarda: boss imóvel + 2x dano por `salva_vuln_time`.
func _salva_vulnerable_window() -> void:
	_announce("DERRUBADO — janela de dano (2x) por %ds!" % int(salva_vuln_time), Color(1.0, 0.9, 0.3))
	_set_color(Color(1.0, 1.0, 0.3))
	var orig_mult := stagger_stun_dmg_mult
	stagger_stun_dmg_mult = salva_vuln_dmg_mult
	state = State.STAGGERED   # reaproveita o estado (já multiplica dano)
	EventBus.boss_staggered.emit()
	var dt := get_physics_process_delta_time()
	var t := 0.0
	while _alive() and t < salva_vuln_time:
		t += dt
		await get_tree().physics_frame
	if state == State.STAGGERED:
		state = State.FIGHT
	stagger_stun_dmg_mult = orig_mult
	_stagger_cd_t = 0.0   # NÃO entra no anti-spam, a janela já foi a "punição"
	_restore_body_color()
	_play_anim("idle")


# ============================================================================
# TRANSIÇÃO — shader de sombras cresce do centro e toma a tela.
# ============================================================================
func _transition_shadows() -> void:
	_phase_card("AS SOMBRAS VÊM…", Color(0.6, 0.3, 1.0))
	# Boss para no centro
	await _move_to(_idle_pos(), move_speed)
	is_immune = true

	# Camada full-screen com ColorRect crescendo do centro.
	var layer := CanvasLayer.new()
	layer.layer = 6
	var dark := ColorRect.new()
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0.05, 0.0, 0.10, 0.0)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dark)
	get_parent().add_child(layer)

	# Sobe o alpha (efeito "sombra preenchendo")
	var dt := get_physics_process_delta_time()
	var t := 0.0
	while _alive() and t < transicao_fill_time:
		t += dt
		dark.color.a = clampf(t / transicao_fill_time, 0.0, 1.0)
		await get_tree().physics_frame
	dark.color.a = 1.0
	await _sleep(transicao_hold_time)

	# Troca de cenário "visual": muda o tint do corpo do boss enquanto está preto.
	_set_body("Corpo", Color(0.35, 0.25, 0.55))
	_phase_sword = true

	# Reveal
	t = 0.0
	while _alive() and t < transicao_reveal:
		t += dt
		dark.color.a = clampf(1.0 - (t / transicao_reveal), 0.0, 1.0)
		await get_tree().physics_frame
	if is_instance_valid(layer): layer.queue_free()

	is_immune = false


# ============================================================================
# MEC 2 — Cavaleiro das Sombras (a Espada)
# ============================================================================
func _phase_sword_loop() -> void:
	_phase_card("ESPADA DAS SOMBRAS — derrube a lâmina")
	_set_color(Color(0.55, 0.4, 0.85))
	var i := 0
	while _alive() and current_hp > max_hp * th_explosao_pct:
		match i % 3:
			0: await _atk_sword_slash()
			1: await _atk_sword_shadow_lances()
			2: await _atk_sword_disappear()
		i += 1
		await _after_attack(espada_pause)


# Slash arqueado grande (círculo de dano ao redor do boss).
func _atk_sword_slash() -> void:
	await _move_to(_idle_pos(), move_speed)
	if not _alive(): return
	_play_anim("attack")
	_spawn_circle(global_position, espada_slash_radius, Color(0.6, 0.3, 1.0),
		espada_slash_damage, espada_slash_telegraph, espada_slash_active,
		true, false, skin_espada)
	await _sleep(espada_slash_telegraph + espada_slash_active + 0.4)


# Sombras nas bordas atiram lanças em direção ao player.
func _atk_sword_shadow_lances() -> void:
	_announce("Lanças das Sombras!", Color(0.7, 0.3, 1.0))
	_play_anim("cast")
	# 4 "sombras" alternando bordas (esq/dir)
	for k in espada_lance_count:
		if not _alive(): return
		var from_left : bool = k % 2 == 0
		var origin := Vector2(arena_left + 8.0 if from_left else arena_right - 8.0,
			randf_range(arena_top + 30.0, arena_floor - 30.0))
		var dir : Vector2 = (_player.global_position - origin).normalized() if _player_alive() \
			else (Vector2.RIGHT if from_left else Vector2.LEFT)
		_spawn_projectile(PROJECTILE.Mode.STRAIGHT, origin, dir, espada_lance_speed,
			espada_lance_damage, true, skin_lanca, Vector2(20, 6),
			Color(0.6, 0.3, 1.0))
		await _sleep(espada_lance_gap)
	await _sleep(0.5)


# Desaparece, vai pra extremidade, janela de counter. Errar = dano colossal.
func _atk_sword_disappear() -> void:
	_announce("DESAPARECIMENTO — defenda (Z) ou tela inteira!", Color(1.0, 0.4, 0.4))
	is_immune = true
	# "Some" indo pra borda
	var to_left : bool = _player_x() > _arena_center().x
	var dest := Vector2(arena_left + 18.0 if to_left else arena_right - 18.0, arena_floor - 30.0)
	await _move_to(dest, move_speed * 2.2)
	if not _alive(): return

	# Tela pulsa avisando
	var layer := CanvasLayer.new()
	layer.layer = 5
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.5, 0.2, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	get_parent().add_child(layer)

	var dt := get_physics_process_delta_time()
	var t := 0.0
	while _alive() and t < espada_disappear_telegraph:
		t += dt
		flash.color.a = 0.30 * (sin(t * 11.0) * 0.5 + 0.5)
		await get_tree().physics_frame
	flash.color.a = 0.55

	var ok : bool = await _await_counter(espada_disappear_window)
	if is_instance_valid(layer): layer.queue_free()
	if ok:
		_announce("Cancelado!", Color(0.5, 1.0, 0.8))
		_parry_feedback()
		add_stagger(max_stagger * 0.4, true)
	elif _alive() and _player_alive():
		_player.take_damage(espada_disappear_damage)
	is_immune = false
	await _move_to(_idle_pos(), move_speed)


# ============================================================================
# MEC 3 — Explosão das Sombras (DPS de cobertura: junte 10 stacks ou morra)
# ============================================================================
func _mech_explosao_sombras() -> void:
	_wipe_card("EXPLOSÃO DAS SOMBRAS — quebre as sombras (10 stacks)!")
	is_immune = true
	await _move_to(_arena_center(), move_speed)
	_set_color(Color(0.4, 0.2, 0.7))

	# Estado compartilhado: stacks contados quando uma sombra morre.
	var counter := {"stacks": 0}

	# Esfera no centro, crescendo (visual + emite o "estouro" no fim).
	var sphere : Node2D = _spawn_explosao_sphere()
	var shadows : Array = []
	var dt := get_physics_process_delta_time()
	var t := 0.0
	var spawn_cd : float = 0.0

	# Atualiza o banner de stacks pela barra de boss banner (texto).
	var last_stacks := -1

	while _alive() and t < explosao_time:
		t += dt
		# Atualiza visual da esfera (cresce)
		if is_instance_valid(sphere):
			var s : float = 1.0 + (t / explosao_time) * (explosao_sphere_growth_rate * 0.5)
			sphere.scale = Vector2(s, s)
		# Spawna sombras destrutíveis pelo chão
		spawn_cd -= dt
		if spawn_cd <= 0.0:
			spawn_cd = explosao_shadow_spawn_interval
			var sh := _spawn_destructible_shadow(counter)
			if sh:
				shadows.append(sh)
		# Atualiza banner se mudou
		if counter["stacks"] != last_stacks:
			last_stacks = counter["stacks"]
			_banner("Stacks: %d / %d" % [last_stacks, explosao_stacks_needed])
		await get_tree().physics_frame

	# Cleanup sombras restantes
	for sh in shadows:
		if is_instance_valid(sh):
			sh.queue_free()
	if is_instance_valid(sphere):
		sphere.queue_free()

	if counter["stacks"] >= explosao_stacks_needed:
		_announce("Proteção total — você sobreviveu!", Color(0.5, 1.0, 0.8))
		await _sleep(1.0)
	elif _alive() and _player_alive():
		_wipe()
	is_immune = false
	_restore_body_color()


# Esfera visual crescendo no centro.
func _spawn_explosao_sphere() -> Node2D:
	var root := Node2D.new()
	if skin_esfera:
		root.add_child(skin_esfera.instantiate())
	else:
		var r := ColorRect.new()
		r.size = Vector2(28, 28)
		r.position = -Vector2(14, 14)
		r.color = Color(0.45, 0.1, 0.7, 0.7)
		root.add_child(r)
	get_parent().add_child(root)
	root.global_position = _arena_center()
	return root


# Sombra destrutível: player bate (combo/heavy) pra quebrar e ganhar 1 stack.
# Em "boss" group pro AttackHitbox do player registrar. Tocá-la causa dano leve.
func _spawn_destructible_shadow(counter: Dictionary) -> Node2D:
	var pos := Vector2(randf_range(arena_left + 30.0, arena_right - 30.0),
		randf_range(arena_floor - 60.0, arena_floor - 20.0))
	var sh := DestructibleShadow.new()
	sh.setup(explosao_shadow_hp, explosao_shadow_touch_damage, counter, skin_sombra)
	get_parent().add_child(sh)
	sh.global_position = pos
	return sh


# Sub-classe interna: sombra com hurtbox que o player pode quebrar.
class DestructibleShadow extends Node2D:
	var hp : float = 200.0
	var touch_dmg : float = 600.0
	var _counter : Dictionary = {}
	var _hurt   : Area2D = null
	var _player : Node2D = null
	var _hit_cd : float = 0.0

	func setup(p_hp: float, p_touch_dmg: float, p_counter: Dictionary, skin: PackedScene = null) -> void:
		hp = p_hp
		touch_dmg = p_touch_dmg
		_counter = p_counter
		if skin:
			add_child(skin.instantiate())
		else:
			var r := ColorRect.new()
			r.size = Vector2(20, 20)
			r.position = -Vector2(10, 10)
			r.color = Color(0.25, 0.05, 0.4, 0.92)
			add_child(r)

	func _ready() -> void:
		add_to_group("boss")   # player.gd hit-test usa esse grupo
		_player = get_tree().get_first_node_in_group("player") as Node2D
		_hurt = Area2D.new()
		_hurt.name = "Hurtbox"
		_hurt.collision_layer = 8     # camada que o AttackHitbox do player escuta
		_hurt.collision_mask  = 0
		var hs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(22, 22)
		hs.shape = rect
		_hurt.add_child(hs)
		add_child(_hurt)

	func _physics_process(delta: float) -> void:
		_hit_cd -= delta
		# Dano de toque (player encostou e não tá invencível)
		if _player and is_instance_valid(_player) and _hit_cd <= 0.0:
			if global_position.distance_to(_player.global_position) < 16.0 \
					and not (_player.has_method("is_invincible") and _player.is_invincible()):
				_player.take_damage(touch_dmg)
				_hit_cd = 0.5

	func take_damage(amount: float) -> void:
		hp -= amount
		modulate = Color(1.3, 1.3, 1.6)
		if hp <= 0.0:
			_counter["stacks"] = int(_counter.get("stacks", 0)) + 1
			queue_free()

	# Player chama add_stagger via has_method — não queremos contribuir pra
	# barra do boss principal, então NÃO definimos esse método aqui (player
	# checa has_method e pula). Mantido como nota explícita.
