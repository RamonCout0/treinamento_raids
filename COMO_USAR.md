# 🗡️ RAIDO — Guia de uso (placeholders → sua arte)

Projeto focado em **mecânica de boss**. Tudo é **placeholder** (cubos coloridos +
shader de brilho) feito pra ser **trocado pela sua arte** sem mexer na lógica.

> Engine: **Godot 4.6**. Cena principal (`run/main_scene` em `project.godot`):
> `res://Lobby/lobby.tscn`.

---

## 1) Controles

| Tecla | Ação | Observação |
|---|---|---|
| ← → | Mover | |
| Espaço | Pular | na parede = wall-jump |
| **C** (segurar) | Agarrar/escalar parede | |
| **Shift** | Dash | **i-frames** (invencível) + cooldown |
| **X** | Atacar (combo de 3) | o 3º golpe dá mais stagger |
| **V** | **Heavy** carregado | **o que MAIS gera stagger** (abre janelas de DPS) |
| **Z** | **Parry / Counter** | anula 1 golpe e dispara o sinal de counter — coração de várias mecânicas |
| Esc | Voltar ao menu | |

O **parry** e o **heavy** são as ferramentas-chave: parry para defender/contra-atacar,
heavy para quebrar a postura (stagger) dos chefes.

---

## 2) Estrutura do projeto

```
Manager/EventBus.gd          # barramento de sinais (player <-> boss <-> HUD)
Player/player.gd|.tscn       # protagonista (Visual = ColorRect placeholder)
Entidades/Comum/
  boss_base.gd               # MOTOR de boss (herde isto)
  hazard.gd                  # perigo genérico (cubo -> skin)
  projectile.gd              # projétil genérico (reto/teleguiado/ricochete)
Entidades/<Boss>/<boss>.gd|.tscn   # os 5 chefes (só a coreografia)
Arenas/arena.gd              # monta cenário + tela de vitória/derrota
Arenas/arena_<boss>.tscn     # 1 arena por chefe
UI/menu / boss_hud / player_hud
Shaders_Efeitos/perigo.gdshader
```

**5 Raids × 3 gates** (Gate 1 → Gate 2 → BOSS), inspirado nas raids do Lost Ark.
A cena principal é o **LOBBY** (`Lobby/lobby.tscn`): andar até um portal e apertar
**C** entra na raid. Vencer um gate → carrega o próximo. Esc volta ao lobby ou
ao menu (modo treino).

**Raid 1 — Silvanna (mágica/gelo/lâminas)**
- Gate 1 · *Eira* — cristais em círculo + lanças + zona segura + portão nevasca
- Gate 2 · *Vex* — corte horizontal + lâminas ricocheteantes + corte em X + portão chuva
- BOSS · *Silvanna* — maratona multi-fase + portões + DPS check final

**Raid 2 — Kael (parry puro)**
- Gate 1 · *Renji* — aprende o parry (janela enorme, sem azul)
- Gate 2 · *Hana* — shurikens em padrões (cruz, leque, círculo) + portão de chuva
- BOSS · *Kael* — vermelho=parry / azul=dash; riposte; espada arremessada; corte em cruz

**Raid 3 — Gorm (pedra/posição/stagger)**
- Gate 1 · *Bruta* — estaca circular + onda + portão de ondas cruzadas
- Gate 2 · *Mygur* — rápido demais; investidas curtas + pulo de impacto + portão loop
- BOSS · *Gorm* — blindado; donut "fique perto", chuva de meteoros, tremor, portão rocha

**Raid 4 — Nyx (ilusão/leitura)**
- Gate 1 · *Lira* — telegrafa padrões (linhas, cruz, X, quadrantes)
- Gate 2 · *Mirio* — clone visual; tell pisca no REAL; portão de trocas
- BOSS · *Nyx* — clones (só o real fere), lado seguro esq/dir, lasers, portão ilusão

**Raid 5 — Vorth (capstone)**
- Gate 1 · *Asha* — trilha de fogo + bolas + mini-lava + portão jato giratório
- Gate 2 · *Karva* — voa; cuspe explosivo (círculo) + mergulho + chama em cruz
- BOSS · *Vorth* — capstone: terra → lava pulsante → wipe (parry) → DPS check

Telegrafos: **retângulo/linha** (corte/laser), **círculo** (meteoro/AoE) e **círculo
verde = zona segura** (fique DENTRO). Tudo pisca no aviso e fica sólido no dano.

---

## 3) Trocar o visual do PLAYER

Abra `Player/player.tscn`. O corpo é o nó **`Visual`** (ColorRect placeholder).
Para usar arte: **troque `Visual` por um `AnimatedSprite2D`** (mantenha o nome `Visual`).
O código então **troca de animação sozinho por estado** (e espelha com `flip_h`).

Crie no `SpriteFrames` estas animações (só as que faltarem são ignoradas):

| Animação | Quando toca |
|---|---|
| `idle` | parado no chão |
| `walking` | andando |
| `jump` | subindo (no ar) |
| `fall` | caindo (no ar) |
| `dash` | durante o dash |
| `grab` | agarrado na parede |
| `attack1` / `attack2` / `attack3` | os 3 golpes do combo (X) |
| `heavy` | golpe pesado (V) |
| `parry` | parry/counter (Z) |
| `hurt` | ao tomar dano |

Prioridade (se vários estados juntos): hurt → dash → parry → ataque → grab → ar → andar → idle.
Enquanto for o ColorRect, ele só muda de cor (placeholder) — os dois funcionam.

---

## 4) Trocar o visual dos CHEFES (formas por fase)

Cada chefe é só um `CharacterBody2D` com o script. O corpo aparece como **cubo**.
Para usar sprite:
1. Abra a cena do chefe (ex.: `Entidades/Colosso/colosso.tscn`).
2. Clique direito no nó raiz → **Add Child Node → AnimatedSprite2D**.
3. **Renomeie o nó EXATAMENTE** com o nome da forma da tabela abaixo.
4. No `SpriteFrames` dele, crie as animações que o código toca (no mínimo `idle`).
5. **Não mexa em "Visible"** — o script mostra/esconde. Centralize a arte em (0,0).
6. O nó tem que ser **filho direto** da raiz do chefe.

| Chefe (cena) | Nome(s) do nó (exato) | Quando aparece | Animações que o código toca |
|---|---|---|---|
| **Silvanna** (`silvanna.tscn`) | `Forma_Chapeu` | Fase 1 + Transição 1 | `idle`, `attack`, `laser_warn`, `laser_fire`, `staggered` |
| | `Forma_Lamina` | Fase 2 | `idle`, `attack`, `staggered` |
| | `Forma_Bruxa` | Transição 2 + Fase 3 + Vassoura | `idle`, `staggered` |
| | `Forma_Final` | Fase Final | `idle`, `staggered` |
| **Kael** (`duelista.tscn`) | `Corpo` | a luta toda | `idle`, `attack`, `throw`, `staggered` |
| **Gorm** (`colosso.tscn`) | `Corpo` | a luta toda | `idle`, `slam`, `throw`, `charge`, `staggered` |
| **Nyx** (`tecela.tscn`) | `Corpo` | a luta toda | `idle`, `cast`, `staggered` |
| **Vorth** (`devorador.tscn`) | `Corpo_Terra` | Ato 1 (terrestre) | `idle`, `attack`, `staggered` |
| | `Corpo_Aereo` | Ato 2 (aéreo) | `idle`, `attack`, `swoop`, `staggered` |
| | `Corpo_Final` | Final | `idle`, `attack`, `staggered` |

Notas:
- Os nomes (nó e animação) são **exatos e sensíveis a maiúsculas**. Só `idle` é
  essencial; as outras são opcionais (se faltarem, são ignoradas).
- Com sprite, a **cor de fase** (cubo) deixa de valer — o sprite fica na cor real.
  Só os flashes momentâneos (dano = vermelho, parry = azul, atordoado = amarelo)
  ainda tingem por cima (via `modulate`), então faça a arte clara se quiser que
  esses flashes apareçam bem.
- Se a arte for maior/menor que o cubo, ajuste `body_size` no Inspetor — isso
  redimensiona o cubo **e a hurtbox** (a área onde o player te acerta).

---

## 5) Trocar o visual dos ATAQUES (hazards/projéteis)

Cada perigo/projétil desenha um cubo. Para trocar por arte, passe uma **cena
(PackedScene)** como `skin` — centralizada na origem (0,0).

**TODOS os chefes** expõem campos de skin no Inspetor (grupo "Skins (opcional)").
Arraste sua `.tscn` no campo do ataque correspondente:
- **Silvanna:** `Skin Laser`, `Skin Gelo`, `Skin Corte`, `Skin Espada`, `Skin Nucleo`, `Skin Faca`, `Skin Dragao`
- **Kael (Duelista):** `Skin Espada Arremesso`, `Skin Corte`
- **Gorm (Colosso):** `Skin Impacto`, `Skin Onda`, `Skin Pedra`, `Skin Pista`, `Skin Rocha`
- **Nyx (Tecelã):** `Skin Clone`, `Skin Wisp`, `Skin Laser`, `Skin Corte`
- **Vorth (Devorador):** `Skin Corte`, `Skin Alma`, `Skin Garra`, `Skin Lava`, `Skin Mergulho`

> A skin é **só visual**: hitbox, tamanho, dano e tempo continuam vindo da config.

---

## 5.1) Áudio (música + SFX)

Tudo passa pelo autoload **`AudioManager`**. Abra `Manager/AudioManager.tscn` e
arraste seus arquivos (`.ogg`/`.wav`/`.mp3`) nos campos. Vazio = silêncio.

- **Música do menu:** campo `Menu Music` no `AudioManager`.
- **Música de cada luta:** campo `Arena Music` na cena de cada `Arenas/arena_*.tscn`.
- **SFX automáticos** (campos no `AudioManager`): `Sfx Hit` (acertou o boss),
  `Sfx Parry`, `Sfx Stagger` (quebrou a postura), `Sfx Boss Death`,
  `Sfx Player Hurt`, `Sfx Player Death`.
- **Volumes:** `Music Volume Db`, `Sfx Volume Db`.
- Pra música em **loop**: selecione o arquivo → aba **Import** → marque **Loop** → Reimport.
- Trocar faixa por fase (opcional): no script do boss chame
  `AudioManager.play_music(minha_stream)`.

## 5.2) Resolução / tamanho dos sprites (base)

O jogo roda em **480×270** lógico (a janela faz upscale ×2.4). Estilo **pixel art**:
nos sprites, deixe **Filter = Nearest** (na importação) pra não borrar.
Desenhe **centralizado na origem (0,0)**; **projéteis apontando para a DIREITA (→)**.

Os tamanhos abaixo são o "alvo" (a hitbox usa esse tamanho). Pode dar uma folga
de moldura ao redor — o que importa é o corpo preencher mais ou menos isso.

| Elemento | Tamanho base (px) |
|---|---|
| **Player** | corpo ~16×32 (moldura sugerida 32×48) |
| Boss Silvanna | 44×44 |
| Boss Kael (Duelista) | 36×48 |
| Boss Gorm (Colosso) | 64×84 |
| Boss Nyx (Tecelã) | 34×44 |
| Boss Vorth (Devorador) | 48×52 |
| Faca / garra (projétil) | ~12×4 a 14×6 |
| Wisp / alma / pedra | 16×16 a 28×28 |
| Mão de dragão | 28×20 |
| Linha de corte / laser | largura da arena × ~8–10 |
| Coluna (espadas/varredura/mergulho) | ~24–40 × altura da arena (~236) |
| Gelo (poça) | 56×12 |
| Onda/pisão (Colosso) | 34–60 × 16 |

> O tamanho do **corpo do boss** vem de `body_size` no Inspetor — mude lá pra casar
> com sua arte (isso reajusta o cubo **e** a hurtbox). O tamanho dos **ataques** vem
> da config de cada um; a `skin` só substitui o visual.

---

## 6) Ajustar dificuldade (tudo no Inspetor)

Selecione o chefe na arena e edite os grupos exportados:
- **Vida e Stagger:** `max_hp`, `hp_per_bar` (tamanho de cada barra),
  `max_stagger`, `stagger_decay`, `stagger_stun_time`, `stagger_stun_dmg_mult`.
- **Arena:** `arena_left/right/top/floor`, `hover_height`, `move_speed`
  (combine os limites com os de `Arenas/arena.gd` se mudar o tamanho).
- Cada chefe tem seu grupo próprio (telegrafo, janelas de parry, dano, intervalos…).

### Ritmo Global (multiplicadores) — todos os chefes

Todo chefe herda da `BossBase` o grupo **"Ritmo Global (multiplicadores)"**: quatro
multiplicadores que escalam o "feel" da luta inteira sem mexer ataque por ataque.
O default de todos é **1.0** (não muda nada). Diminua para deixar mais lento/fácil,
aumente para acelerar/endurecer:
- `telegraph_mult` — escala o tempo de **aviso** (telegrafo) de TODO perigo/círculo/
  zona segura. >1.0 = mais tempo pra reagir; <1.0 = avisos mais curtos (mais difícil).
- `active_mult` — escala o tempo em que o perigo fica **dando dano** (janela ativa).
- `projectile_speed_mult` — escala a **velocidade de todos os projéteis** do chefe.
- `recovery_mult` — escala as **pausas entre ataques** (o `_after_attack`). >1.0 dá
  mais respiro entre golpes.

### Tempos e velocidade — por chefe (gates)

Os 6 chefes de gate (Eira, Vex, Hana, Bruta, Lira, Asha) têm um grupo
**"Tempos e velocidade"** (ou "Velocidade dos shurikens", na Hana) que expõe os
tempos/velocidades antes fixos no código. Os defaults reproduzem o comportamento
atual — mude só se quiser rebalancear aquele ataque específico:
- **Eira:** `lance_speed` (lanças), `crystal_telegraph`/`crystal_active` (cristais),
  `safe_telegraph`/`safe_active`/`safe_duration` (zona segura central), `gate_time`.
- **Vex:** `blade_speed` (lâminas), `slash_telegraph`/`slash_active` (corte),
  `cross_telegraph`/`cross_active` (corte em X), `rain_telegraph`/`rain_active`
  (chuva), `gate_time`.
- **Hana:** `cross_speed`, `fan_speed`, `circle_speed`, `homing_speed`, `rain_speed`
  (velocidade dos shurikens em cada padrão), `gate_time`.
- **Bruta:** `stake_telegraph`/`stake_active` (estaca), `wave_telegraph`/`wave_step`/
  `wave_active` (onda — `wave_step` é o atraso somado por segmento), `gate_time`.
- **Lira:** `x_speed` (padrão X), `line_telegraph`/`line_late`/`cross_telegraph`/
  `line_active` (tempos das linhas/cruz/quadrantes), `gate_time`.
- **Asha:** `fireball_speed`, `homing_speed`, `jet_speed` (velocidades de fogo),
  `trail_active` (duração da trilha), `lava_telegraph`/`lava_active`/`lava_duration`
  (mini-lava), `gate_time`.

Dano/stagger do player ficam em `Player/player.gd` (`COMBO_DMG`, `COMBO_STAGGER`,
`HEAVY_DMG`, `HEAVY_STAGGER`, `PARRY_WINDOW`).

---

## 7) Como o dano funciona (resumo)

- O golpe do player acerta a **Hurtbox** do chefe (criada automática) e chama
  `take_damage()` (tira HP) **e** `add_stagger()` (enche a barra amarela).
- Encheu o stagger → **atordoado**: toca `staggered`, fica amarelo e leva
  **dano dobrado** (`stagger_stun_dmg_mult`) — sua janela de DPS.
- **Parry (Z):** anula o golpe; em mecânicas de duelo/ilusão/wipe ele é obrigatório.
- **Transições/portões:** o stagger vira um **portão** (encha a tempo, senão é wipe).
- Todo perigo **pisca (telegrafo)** antes de virar **sólido (dano)**. **Dash atravessa.**

---

## 8) Adicionar um 6º chefe (padrão)

1. Crie `Entidades/NovoBoss/novoboss.gd`:
   ```gdscript
   extends BossBase
   func fight() -> void:
       _banner("MINHA LUTA")
       _set_body("", Color(0.5, 0.5, 0.5))
       while _alive():
           # use os helpers: _move_to, _spawn_hazard, _spawn_projectile,
           # _await_counter, add_stagger, _after_attack(pausa)...
           await _after_attack(1.2)
   ```
2. Crie `novoboss.tscn` (um `CharacterBody2D` + o script + tuning).
3. Duplique uma `Arenas/arena_*.tscn`, troque o chefe e o `arena_tint`.
4. Adicione a entrada em `UI/menu.gd` (`BOSSES`).

O motor (`BossBase`) cuida de vida, stagger, atordoamento, formas, hurtbox,
camadas de colisão e morte. Você escreve **só a dança**.
