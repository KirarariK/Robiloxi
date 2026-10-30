# Missions pour Codex : vérification et fiabilisation du code Luau d'Ether Blades

Tu travailles dans ce dépôt (`C:\Users\devaa\Desktop\robiloxiiiii`). Le jeu est un projet Rojo :
- `src/shared` → `ReplicatedStorage.EtherBlades`
- `src/server` → `ServerScriptService.EtherBlades`
- `src/client` → `StarterPlayerScripts.EtherBlades`

Avant de commencer, lis `docs/CONTRACTS.md` et `README.md`.

L'autre agent (Claude, en cloud) ne peut exécuter **aucun** outil Luau. Ton rôle est donc tout ce qui demande des outils locaux. Fais les missions dans l'ordre.

## Règles
- Ne modifie que `src/`, `tests/`, `docs/CODEX_REPORT.md` et les fichiers de configuration d'outillage à la racine (`selene.toml`, `stylua.toml`, `.luaurc`, `rokit.toml`, `sourcemap.json`).
- Ne touche pas à `blender/`, `scripts/`, `exports/` ni aux fichiers `.rbxl`.
- Ne change **jamais** une API publique sans la documenter :
  - les contrats de `docs/CONTRACTS.md` ;
  - les noms de remotes dans `src/shared/NetDefs/*` ;
  - les noms des parts du Hub et des arènes.
- Garde `--!strict` partout et les commentaires en français. Aucun TODO.
- Fais un commit git local par mission, avec un message clair en français, sur `main`. **Ne pousse pas** (`git push` interdit) : Claude récupère tes commits depuis ce dossier.
- Si une mission est impossible, note-le dans `docs/CODEX_REPORT.md` avec la raison, puis passe à la suivante.

## Mission 1 : vérifier le typage strict (priorité absolue)
1. Installe l'outillage :
   - `rokit` (ou `aftman`), puis `rojo`, `luau-lsp`, `selene` et `stylua` ;
   - les définitions Roblox de `luau-lsp` (`globalTypes.d.luau`).
2. Génère `sourcemap.json` avec `rojo sourcemap default.project.json -o sourcemap.json`.
3. Lance `luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json --base-luaurc=.luaurc src` en mode strict.
4. Corrige **toutes** les erreurs de type, sans changer le comportement. Priorité aux erreurs qui plantent à l'exécution :
   - champ nil ;
   - mauvais argument ;
   - méthode inexistante, en particulier les API Roblox qui n'existent pas.
5. Relance jusqu'à 0 erreur. Note dans le rapport les avertissements restants, s'il y en a.

## Mission 2 : lint et format
1. Configure `selene.toml` en `std = "roblox"`.
2. Corrige les vrais problèmes signalés par selene : variable masquée, shadowing de `task`/`game`, code mort, comparaisons douteuses.
3. Lance `stylua src`. Indentation par tabulations, comme le code actuel.

## Mission 3 : tests de la logique pure
1. Installe `lune`.
2. Écris des tests dans `tests/`, exécutables avec `lune run tests/<fichier>`, pour les modules sans dépendance au moteur Roblox :
   - `src/shared/Config/FormData.lua` :
     - la somme des poids vaut 100 ;
     - `pick` respecte les bornes ;
     - 100 000 tirages donnent ±0,3 % des poids.
   - `src/shared/Config/RankData.lua` :
     - `delta` est symétrique ;
     - `tierFor` gère le seuil et le Top 50.
   - `src/shared/Combat/CombatMath.lua` : combos, timings, variantes directionnelles.
   - la garantie de relance dans `src/server/Services/RerollService.lua` : au plus 50 tirages sans Épique ou mieux. Extrais la fonction pure si besoin.
3. Si un module importe des services Roblox, isole la logique pure dans une fonction testable sans changer son API.

## Mission 4 : revue de bugs (lecture attentive)
Relis en priorité les fichiers suivants :
- `src/server/Combat/*`
- `src/server/Services/CombatService.lua`
- `src/server/Services/MatchService.lua`
- `src/server/Match/*`
- `src/server/Services/DataService.lua`

Cherche :
- les fuites (connexions jamais coupées entre les rounds) ;
- les courses (joueur qui part pendant `playIntro` / `playFinisher`, double `RoundEnded`) ;
- les yields dans des callbacks qui ne doivent pas en faire ;
- les remotes non validées ;
- l'Elo appliqué deux fois.

Corrige ce qui est sûr. Liste le reste dans le rapport, avec fichier:ligne.

## Rapport
Écris `docs/CODEX_REPORT.md`, court et en français :
- ce qui a été fait ;
- le nombre d'erreurs avant et après ;
- les bugs trouvés et corrigés ;
- ce qui reste ;
- les commandes pour relancer les vérifications.
