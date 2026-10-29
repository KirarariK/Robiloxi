# Ether Blades — contrats entre équipes (à lire avant de coder)

Jeu Roblox de duels 1v1 aux lames d'énergie. **Univers 100 % original** : aucun terme Star Wars
(pas de Jedi, Sith, Padawan, Darth, sabre laser, Force, Kyber, Shii-Cho… Juyo, Darksaber, Mustafar, Ahsoka, Kylo).
UI et commentaires **en français**. Lexique officiel : `README.md`.

## Règles communes
- Luau `--!strict` en tête de chaque fichier, types explicites, aucune variable globale, pas de `_G`.
- **Aucun TODO, aucun placeholder, aucun code incomplet.**
- Connexions / instances temporaires nettoyées avec `ReplicatedStorage.EtherBlades.Util.Maid` (entre rounds, à la mort, au départ d'un joueur).
- Le serveur fait autorité : il recalcule dégâts, posture, endurance, Elo, relances, équipements. Le client ne fait qu'envoyer des intentions.
- Toute remote client → serveur passe par `ServerScriptService.EtherBlades.Services.Guard` (`Guard.func` / `Guard.event` : débit + types + pcall).
- Pas d'assets à uploader : **animations procédurales** (Motor6D.Transform pilotés par code), sons intégrés `rbxasset://sounds/...`
  (ex. `swordslash.wav`, `swordlunge.wav`, `unsheath.wav`, `electronicpingshort.wav`, `button.wav`, `hit.wav`, `metal.ogg`).
  Les textures de particules intégrées : `rbxasset://textures/particles/sparkles_main.dds`, `fire_main.dds`, `smoke_main.dds`.
- Ne modifie **que les fichiers que ton équipe possède** (tableau plus bas). Si tu as besoin d'un changement ailleurs, écris-le dans ton rapport final.
- Ne fais **pas** de commit git. L'orchestrateur intègre, déploie et teste.

## Arborescence (Rojo)
| Dépôt | Studio |
|---|---|
| `src/shared` | `ReplicatedStorage.EtherBlades` |
| `src/server` | `ServerScriptService.EtherBlades` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.EtherBlades` |
`*.server.lua` = Script, `*.client.lua` = LocalScript, `*.lua` = ModuleScript, dossier = Folder.

Assets 3D (créés par l'équipe Modélisation, hors Rojo) :
- `ReplicatedStorage.EtherBladesAssets.Hilts` : Models `Hilt_Single`, `Hilt_Staff` (la double lame = deux `Hilt_Single`).
  Chaque poignée : `PrimaryPart` = `Grip` (pièce saisie, axe +Y = direction de la lame), une Attachment `BladeStart` (+ `BladeStart2` pour le Bâton-Lame, orientée vers -Y) à l'émetteur.
- `ServerStorage.EtherBladesAssets.Arenas.<ArenaId>` (Id = `ArenaData`) : Model contenant des Parts invisibles et non collidables
  `SpawnA`, `SpawnB` (face à face, LookVector vers l'adversaire), `IntroCam` (CFrame caméra de l'intro), `Center`, et `KillY` (Part dont le Y = altitude de chute mortelle pour lave / vide).
- `Workspace.Hub` : lobby. Parts d'ancrage (invisibles sauf mention) : `HubSpawn` (SpawnLocation), `Pod_Ranked`, `Pod_Casual`, `Pod_Challenge`
  (pods de file, avec ProximityPrompt créé par l'équipe UI), `RerollShrine`, `SaberBench`, `Leaderboard_Elo`, `Leaderboard_Wins`, `Leaderboard_Streak`
  (panneaux : la face avant `Front` porte la SurfaceGui), `Dummy_1`, `Dummy_2`, `Dummy_3` (emplacements des mannequins), `MeditationSpot_1..4`.

## Démarrage automatique
- Serveur : chaque ModuleScript de `Services` est requis ; `init()` puis `start()` sont appelés dans l'ordre de `Priority` (défaut 100, DataService = 0).
- Client : idem pour `Controllers` (dans `StarterPlayerScripts.EtherBlades`).
- Remotes : chaque équipe déclare les siennes dans **son** fichier `src/shared/NetDefs/<Domaine>.lua`
  (`return { ClientEvents = {...}, ServerEvents = {...}, Functions = {...} }`). Accès : `Net.event(name)`, `Net.func(name)`.

## API existantes (socle)
- `DataService.get(player): Profile?` · `DataService.update(player, fn(profile))` (pousse `ProfileUpdated`) · `DataService.ProfileLoaded` (player, profile).
- `Types.Profile` : Elo, PeakElo, Wins, Losses, WinStreak, BestStreak, RankedPlayed, Rerolls, Crystals, EquippedForm, OwnedForms,
  FormMastery, EquippedWeapon, EquippedColor, OwnedColors, EquippedTitle, OwnedTitles, EquippedEmotes, LeavePenaltyUntil.
- Config : `FormData` (7 Voies, `pick(roll)`), `WeaponData`, `SaberColors` (`glowAt(def, t)`), `RankData` (`delta`, `tierFor`, `Formats`),
  `ArenaData`, `TitleData`, `EmoteData`, `Rarity`.
- Client : `ClientState.getProfile()`, `ClientState.ProfileChanged`.

## Contrat Combat (équipe Combat) → utilisé par Match / UI
Serveur, `ServerScriptService.EtherBlades.Services.CombatService` :
```
CombatService.beginDuel(matchId: string, a: Player, b: Player, arena: Model) -> ()   -- équipe les lames, place sur SpawnA/SpawnB, gel
CombatService.playIntro(matchId: string) -> ()          -- cinématique 3-4 s chez les deux clients ; rend la main à la fin (yield)
CombatService.startRound(matchId: string) -> ()         -- reset posture/endurance/PV, replace aux spawns, dégel
CombatService.playFinisher(matchId: string, winner: Player, loser: Player) -> ()   -- exécution 2-3 s (yield)
CombatService.endDuel(matchId: string) -> ()            -- retire l'état de duel, nettoie tout (Maid)
CombatService.RoundEnded : RBXScriptSignal  -- (matchId: string, winner: Player, loser: Player)
```
Le combat est aussi actif dans le Hub contre les mannequins (pas de PvP dans le Hub).
Attributs répliqués posés sur le **Character** (lus par l'UI) : `Posture`, `MaxPosture`, `Stamina`, `MaxStamina`, `HealthPct` (0-1),
`CombatState` (texte : Idle, Attacking, Blocking, Parrying, Dodging, Stunned, GuardBroken, Dead), `InDuel` (bool).

Client, `StarterPlayerScripts.EtherBlades.Combat.ProceduralAnimator` :
```
ProceduralAnimator.play(character: Model, clipId: string, opts: { Looped: boolean?, Speed: number? }?) -> (() -> ())  -- renvoie stop()
```
Clips d'emote obligatoires : `Emote_<Id>` pour chaque `EmoteData.List`.
Client, `StarterPlayerScripts.EtherBlades.Combat.SaberVisual` :
```
SaberVisual.build(weapon: WeaponType, colorId: string) -> Model     -- poignée(s) + lame(s) allumées (aperçu atelier / UI)
```

## Contrat Sécurité (équipe Architecture & Réseau) → utilisé par Combat
`ServerScriptService.EtherBlades.Services.HitValidation` :
```
HitValidation.canHit(attacker: Player, targetRoot: BasePart, reach: number, arcDeg: number, clientTime: number?) -> boolean
-- portée + angle mesurés sur l'historique des positions serveur (compensation de latence bornée à 250 ms)
HitValidation.recordNpc(model: Model) -> ()  -- suivre aussi un mannequin
```
`AntiExploit` : contrôles de vitesse / téléportation / vol, journalisation, sanctions progressives (remise en place, puis kick).
Les déplacements légitimes du jeu (esquive, poussée, téléport vers l'arène) passent par
`AntiExploit.allowMovement(player, seconds)` pour ne pas être sanctionnés.

## Contrat Match / Progression (équipe UI & Progression)
Possède : relances, équipement, file d'attente, déroulé des matchs (BO3 / BO5, Elo, abandon = défaite + pénalité),
classements (OrderedDataStore, rafraîchis toutes les 60 s), titres (BillboardGui), emotes (roue radiale), toute l'UI (HUD inclus).

## Propriété des fichiers
| Équipe | Fichiers |
|---|---|
| Orchestrateur | `Net.lua`, `Types.lua`, `Config/*`, `Util/*`, `NetDefs/Core.lua`, `Main.*`, `ClientState.lua`, `DataService`, `Guard`, `RateLimiter`, `docs/`, `scripts/` |
| Architecture & Réseau | `Services/HitValidation.lua`, `Services/AntiExploit.lua`, `NetDefs/Security.lua`, `src/server/Security/*` |
| Modélisation (Blender) | `blender/*` (scripts), FBX dans `exports/` sur le PC, assets Studio listés plus haut. **Seule équipe autorisée à utiliser Studio / Blender / l'écran.** |
| Combat | `src/shared/Combat/*`, `NetDefs/Combat.lua`, `Services/CombatService.lua`, `src/server/Combat/*`, `src/client/Combat/*`, `Controllers/CombatController.lua` |
| UI & Progression | `NetDefs/Progression.lua`, `NetDefs/Match.lua`, `Services/{Reroll,Equip,Matchmaking,Match,Leaderboard,Title,Emote}Service.lua`, `src/server/Match/*`, `src/client/UI/*`, `Controllers/{Hud,Menu,Emote,Title,Hub}Controller.lua` |
