extends Node
# ============================================================================
# EventBus — barramento de sinais global (autoload).
# Player e Bosses emitem aqui; HUDs e Arenas escutam. Desacopla tudo.
# @warning_ignore evita o falso "unused" — os sinais SÃO usados em outros scripts.
# ============================================================================

# --- Jogador ---
@warning_ignore("unused_signal")
signal player_max_health_set(max_health)
@warning_ignore("unused_signal")
signal player_health_updated(current_health)
@warning_ignore("unused_signal")
signal player_counter_pressed()          ## emitido no instante do parry (tecla Z)
@warning_ignore("unused_signal")
signal player_parried()                  ## emitido quando um parry ANULA um dano
@warning_ignore("unused_signal")
signal player_died()
@warning_ignore("unused_signal")
signal player_hurt()                      ## tomou dano (pra SFX)

# --- Chefe ---
@warning_ignore("unused_signal")
signal boss_intro(boss_name: String)     ## nome do boss ao iniciar a luta
@warning_ignore("unused_signal")
signal boss_max_health_set(max_health, health_per_segment)
@warning_ignore("unused_signal")
signal boss_health_updated(current_health)
@warning_ignore("unused_signal")
signal boss_staggered()
@warning_ignore("unused_signal")
signal boss_stagger_updated(current_stagger: float, max_stagger: float)
@warning_ignore("unused_signal")
signal boss_banner(text: String)         ## texto de fase/evento ("FASE 2", etc.)
@warning_ignore("unused_signal")
signal boss_intro_cine(boss_name: String, epithet: String, color: Color)  ## cinemática inicial
@warning_ignore("unused_signal")
signal mechanic_announce(text: String, kind: String, color: Color)  ## kind: "phase" | "mech" | "gate" | "wipe"
@warning_ignore("unused_signal")
signal boss_died()
@warning_ignore("unused_signal")
signal boss_hit()                         ## levou dano (pra SFX)
