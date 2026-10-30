# Rapport Codex — Ether Blades

- **Mission 1 :** `sourcemap.json` générée et `.luaurc` réglé en strict. Analyse Luau impossible : `luau-lsp` et `globalTypes.d.luau` absents. Nombre d’erreurs avant/après : **inconnu** (analyse non exécutée).
- **Mission 2 :** `selene.toml` utilise `std = "roblox"` et `stylua.toml` conserve les tabulations. Lint et formatage non exécutés : Selene et StyLua absents.
- **Mission 3 :** logique pure de garantie extraite dans `RerollMath.lua`; tests ajoutés pour les poids, rangs, combats et 50 tirages. Tests non exécutés : Lune absent.
- **Mission 4 :** le serveur vérifie la proximité de l’autel pour chaque relance et refuse un impact si `HitValidation` échoue. Les connexions du fallback sont nettoyées au changement de round et à la fin du duel. Le garde-fou `Finished` et `LeaverHandled` évite une double application des résultats/Elo.
- **Corrigé ensuite par Claude :** `CombatBridge.lua` bascule désormais le match sur le repli si un appel à CombatService échoue (match « dégradé »), et `onRoundEnded` écoute aussi le repli. Constat initial : `CombatBridge.lua:36-40` journalise l’échec d’une méthode de `CombatService`, mais signale quand même l’appel comme traité. Si `startRound` échoue, le repli n’a pas de duel initialisé et le match peut attendre la fin du délai. Un basculement automatique n’est pas sûr sans gérer l’état partiellement initialisé.
- **Outils et commits :** `winget` ne démarre pas, les outils demandés sont absents et `.git` refuse la création de `.git/index.lock`. Les quatre commits locaux n’ont donc pas pu être créés. Aucun push effectué. Les éléments non suivis `EtherBlades.rbxl.lock` et `SyndicateBlackMarket/` étaient présents au départ ; `blender/eb_hub_kit.py` a été détecté ensuite. Tous ont été laissés intacts.

## Vérifications à relancer après installation des outils

```powershell
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json --base-luaurc=.luaurc src
selene src
stylua src
lune run tests/FormData.luau
lune run tests/RankData.luau
lune run tests/CombatMath.luau
lune run tests/RerollMath.luau
```
