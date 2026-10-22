# Zona Morta (nome provisório)

Jogo de extração e sobrevivência multiplayer para Roblox. Veja o design em [DESIGN.md](DESIGN.md).

## Como rodar

1. Instale o [Rojo](https://rojo.space) (por exemplo com `rokit add rojo-rbx/rojo`) e o plugin do Rojo no Studio.
2. Clone o repositório e, dentro da pasta, rode `rojo serve`:
   ```
   git clone https://github.com/Shiaze1/zone-morta
   cd zone-morta
   rojo serve
   ```
3. No Studio, abra um place (pode ser o Baseplate), clique em **Connect** no plugin do Rojo.
4. Em **Game Settings > Security**, ative **Enable Studio Access to API Services** (para o DataStore funcionar).
5. Dê **Play**. Se o place não tiver `Workspace.Map`, um mapa de teste é gerado automaticamente.

Sem Rojo: crie no Studio a mesma estrutura do `default.project.json` e cole cada arquivo
como Script / LocalScript / ModuleScript (`init.server.luau` = Script, `init.client.luau` = LocalScript,
o resto = ModuleScript filho).

## Como jogar (teste)

- No lobby, o painel à direita mostra seu stash. **Levar** coloca no loadout, **Vender** vende 1 unidade.
- **ENTRAR NA RAID** te leva para o mapa. Segure **E** nas caixas para saquear.
- Ache uma zona verde de **EXTRAÇÃO** e fique 8s dentro. O Heliponto só abre depois de 5 min.
- Morreu ou acabou o tempo: perde tudo, e seu corpo fica no mapa para outros saquearem.
- Tecla **B** mostra/esconde o painel.

## Estrutura

```
src/shared/   Config, Items, Remotes           → ReplicatedStorage.Shared
src/server/   init.server, MapBootstrap,
              LootTables, Services/*           → ServerScriptService.Server
src/client/   init.client (HUD), UI            → StarterPlayerScripts.Client
```

Para montar um mapa real, crie no Studio `Workspace.Map` com as pastas
`RaidSpawns`, `LootSpawns` (atributo `LootTable`) e `ExtractZones`
(atributos `DisplayName` e `OpensAfter`).
