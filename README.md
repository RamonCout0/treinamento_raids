# 🗡️ Raido

Treino de **raids** em Godot 4.6 (GDScript): **5 chefes × 3 gates** (Gate 1 → Gate 2
→ BOSS), inspirado nas raids do Lost Ark. O foco é a **mecânica de boss** — todo o
visual é placeholder (cubos coloridos + shader de brilho), pensado pra ser trocado
pela sua arte sem mexer na lógica.

O motor de boss (`BossBase`) cuida de vida, stagger, atordoamento, formas, hurtbox,
camadas de colisão e morte. Cada chefe herda dele e escreve **só a coreografia** em
`fight()`.

## Como rodar

1. Instale o **Godot 4.6** (build padrão, GDScript — não precisa do .NET).
2. Abra a engine, **Import** e selecione o `project.godot` na raiz deste repositório.
3. Rode com **F5**. A cena principal é o **lobby** (`res://Lobby/lobby.tscn`):
   ande até um portal e aperte **C** pra entrar na raid.

Para um *smoke test* sem abrir a interface (usado também na CI):

```bash
godot --headless --path . --import
```

## Controles

| Tecla | Ação |
|---|---|
| ← → | Mover |
| Espaço | Pular (na parede = wall-jump) |
| **C** (segurar) | Agarrar/escalar parede · entrar no portal (lobby) |
| **Shift** | Dash (i-frames + cooldown) |
| **X** | Atacar (combo de 3; o 3º dá mais stagger) |
| **V** | Heavy carregado (o que mais gera stagger) |
| **Z** | Parry / Counter (anula 1 golpe, dispara o sinal de counter) |
| Esc | Voltar ao lobby/menu |

Parry e heavy são as ferramentas-chave: parry para defender/contra-atacar, heavy
para quebrar a postura (stagger) e abrir janelas de DPS.

## Estrutura

```
project.godot                # main_scene = res://Lobby/lobby.tscn
Lobby/lobby.gd|.tscn         # hub com os portais das raids
Manager/                     # autoloads: EventBus, AudioManager, RaidManager, GameFeel
Player/player.gd|.tscn       # protagonista (Visual = ColorRect placeholder)
Entidades/Comum/
  boss_base.gd               # MOTOR de boss (herde isto)
  hazard.gd                  # perigo genérico (telegrafo → ativo)
  projectile.gd              # projétil (reto/teleguiado/ricochete)
Entidades/<Raid>/<boss>.gd   # os chefes (só a coreografia em fight())
Arenas/                      # cenário + tela de vitória/derrota; 1 arena por chefe
UI/                          # menu, HUDs, números de dano
Shaders_Efeitos/             # shader de brilho dos perigos
```

## Documentação

Veja **[COMO_USAR.md](COMO_USAR.md)** para o guia completo: trocar placeholders pela
sua arte (player, chefes, ataques), áudio, resolução dos sprites, ajuste de
dificuldade (multiplicadores globais de ritmo e os campos "Tempos e velocidade" por
chefe) e como adicionar um novo chefe.

## Licença

[MIT](LICENSE) © 2026 Ramon Couto.
