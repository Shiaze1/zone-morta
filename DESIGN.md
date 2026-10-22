# Extração & Sobrevivência — Design (v0.1)

Nome provisório: **"Zona Morta"**. Tema assumido: pós-apocalíptico realista
(cidade abandonada). Modo assumido: **PvPvE** (outros jogadores são a maior ameaça,
o ambiente é a segunda).

## Loop principal

```
LOBBY (stash, loja, loadout)
   │  escolhe o que levar (até 10 de espaço)
   ▼
RAID (mapa compartilhado, entra quando quiser)
   │  saqueia caixas  ─ sobrevive a fome/sede/inimigos ─ mata/evita jogadores
   ├─► chega numa EXTRAÇÃO e segura 8s  → tudo da mochila vai pro stash
   └─► morre / tempo acaba / sai do jogo → perde TUDO que levou e achou
                                            (vira um "corpo" saqueável no mapa)
   ▼
LOBBY: vende itens, monta loadout melhor, entra de novo
```

O risco é o coração do jogo: quanto mais você leva e quanto mais tempo fica,
mais pode ganhar e mais pode perder.

## Regras do MVP (o que o código base já faz)

| Sistema | Regra |
|---|---|
| Stash | Persistente (DataStore), capacidade 200 de espaço, com dinheiro e estatísticas |
| Loadout | Até 10 de espaço do stash; sai do stash ao entrar na raid |
| Mochila da raid | 20 de espaço; cada item tem um `size` |
| Raid | 15 min por jogador; entrada a qualquer momento (drop-in) |
| Extração | Ficar 8s dentro de uma zona; algumas zonas só abrem depois de X s |
| Morte | Perde a mochila inteira; deixa um corpo saqueável por 5 min |
| Sair no meio da raid | Conta como morte (anti combat-log) |
| Fome / Sede | Caem com o tempo; em 0 causam dano. Comida, água e remédios restauram |
| Loot | Caixas "comum" e "militar" com tabelas de peso; reaparecem 5 min depois |
| Economia | Vender itens no lobby dá dinheiro (`value` do item) |

## Arquitetura

Projeto **Rojo** (Luau), servidor autoritativo: o cliente só pede ações
(entrar na raid, usar item, vender) e o servidor valida tudo.

```
src/shared   → ReplicatedStorage.Shared   (Config, Items, Remotes)
src/server   → ServerScriptService.Server (serviços)
src/client   → StarterPlayerScripts.Client (HUD)
```

Serviços do servidor (carregados em ordem por `init.server.luau`):

- **SyncService**: junta o estado de cada jogador e envia um snapshot ao cliente.
- **DataService**: DataStore com retry, session lock, autosave e BindToClose.
- **InventoryService**: mochila da raid.
- **SurvivalService**: fome, sede, uso de itens.
- **MatchService**: lobby ↔ raid, loadout, morte, timer, venda.
- **LootService**: caixas de loot e corpos de jogadores.
- **ExtractionService**: zonas de extração e progresso.
- **MapBootstrap**: se não existir `Workspace.Map`, gera um mapa de teste.

## Próximos passos sugeridos

1. Armas (raycast validado no servidor) e PvP de verdade.
2. Inimigos IA (zumbis ou saqueadores) com loot próprio.
3. Mapa real feito no Studio (a estrutura de pastas já está pronta).
4. Loja/comerciantes e missões.
5. Raids em servidores separados (TeleportService + reserved servers).
6. Trocar o DataService pelo ProfileStore quando o jogo crescer.
