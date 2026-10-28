# Hall du Concord — lobby intérieur + 8 arènes

**ArtPass 13** (`BC_Layout = CruiserHall`) · Origin monde `(0, 0, 700)` · aucun nom Star Wars (branding Concord).
Tout est **procédural** (`Lobby/*` + `ArenaService`) : rien à poser à la main pour jouer.
Sol commun lobby + arènes : dessus à **Y = 1.1**.

## 1. Dimensions exactes (repère local, spawn au sud, −Z = vers la baie)

| Élément | Dimensions (studs) | Matériau | Notes |
|---|---|---|---|
| Allée centrale | 40 × 140 (z +50 → −90), hauteur 32 | sol **Granite** (24,26,34) refl. 0.14 | murs Metal (24,28,38) refl. 0.18 |
| Tapis | 14 × 0.3 × 136 | **DiamondPlate** | décor, sans collision |
| Colonnes | 3 × 32 × 3, tous les 20, x = ±17 (12 au total) | Metal sombre refl. 0.25 | anneaux Neon à y 8 et 24 |
| Néons muraux | 0.4 × 0.6 × 134, y 4 et 28 | **Neon** Focus (gauche) / Dawn (droite) | tag `BC_NeonStrip` |
| Plafond | épaisseur 2, y = 33.1 | Metal sombre | rail Neon central 3 de large |
| Galerie d'observation | 150 × 40 (z −90 → −130), hauteur 32 | sol **Marble** (30,34,48) refl. 0.22 | passage de 40 vers l'allée |
| **Baie vitrée** | 150 × 26, z = −130 | **Glass** transp. 0.82, refl. 0.12 | 5 vitres de 30 + 6 meneaux Metal 1.6, linteau 6, seuil DiamondPlate |
| Pads (2 slots) | 12 × 0.4 × 12 à **(−14, −116)** et **(+14, −116)** | **Neon** Focus / Dawn | 8 studs devant la vitre |
| Spawn | `(0, 3, 30)` face −Z · tag `BC_LobbySpawn` | | 3 spawns de réserve |

### PBR (optionnel, dans Studio)
Les matériaux ci-dessus sont des matériaux Roblox natifs (reflets via `Reflectance` + Lighting Future).
Pour un PBR custom : `MaterialService` → `MaterialVariant` (BaseMaterial = Granite / Marble / Metal / DiamondPlate),
renseigner tes ColorMap / NormalMap / MetalnessMap / RoughnessMap, nom du variant identique au matériau de base
(`MaterialVariant.Name = "Granite"` s'applique à toutes les parts Granite). Pas d'ID d'asset dans le code.

## 2. Lighting (`Lobby/LobbyLighting.lua`)

| Propriété | Valeur |
|---|---|
| **Technology** | **Future** — à régler **une fois dans Studio** (propriété non scriptable en jeu) |
| ClockTime / Brightness | 0 / 1.1 |
| Ambient / OutdoorAmbient | (12,14,22) / (22,26,42) |
| EnvironmentSpecularScale / DiffuseScale | 1 / 1 (reflets métalliques max) |
| ExposureCompensation | 0.25 |
| Atmosphere | Density 0.3 · Offset 0 · Color (26,34,58) · Decay (8,10,22) · Glare 0 · Haze 1.4 |
| Bloom | Intensity 0.55 · Size 30 · Threshold 0.95 |
| ColorCorrection | Brightness −0.02 · Contrast 0.2 · Saturation 0.12 · Tint (224,234,255) |
| Sky | 3000 étoiles · DoF off · SunRays off |

Les arènes gardent leur propre ambiance pendant le duel (`applyArenaLighting`) ; le lighting du hall revient au retour salon.

## 3. Les 8 arènes (`LobbyConfig.ArenaLayout`)

Floors **160 × 160** (rim 166, murets 4), spawns à **±40** de l'axe → ≥ 40 studs de chaque mur :
dash (12), Dash Focus (12), double saut et Poussée Focus n'atteignent jamais un muret.
Voie centrale de **100** entre les deux colonnes ; 1ʳᵉ rangée à 30 studs derrière la baie ; pas de 200.

| # | Id | Côté | X | Z monde |
|---|---|---|---|---|
| 1 | ObsidianPit | Gauche | −130 | 460 |
| 2 | SanctumAstres | Gauche | −130 | 260 |
| 3 | TroneEclipse | Gauche | −130 | 60 |
| 4 | QuaiMirage | Gauche | −130 | −140 |
| 5 | ForgeAube | Droite | +130 | 460 |
| 6 | SpireCrepuscule | Droite | +130 | 260 |
| 7 | RecifNeant | Droite | +130 | 60 |
| 8 | CourCristal | Droite | +130 | −140 |

Pour changer la taille : `ArenaFloorSize`, `ArenaSpawnSep`, `ArenaColumnX`, `ArenaRowStep` dans `LobbyConfig.lua`.

## 4. Scripts (modulaires)

| Module | Rôle |
|---|---|
| `Lobby/LobbyConfig` | toutes les dimensions, couleurs, tags, layout des arènes |
| `Lobby/LobbyLighting` | Future, Atmosphere, Bloom, ColorCorrection |
| `Lobby/LobbyProps` | colonnes, bandes Neon, **pad de file** (ProximityPrompt + hitbox) |
| `Lobby/LobbyBuilder` | construit le hall + `bindDuelSlots` |
| `Match/SlotMatchService` | file 1v1 : 2 pads, libération si le joueur s'éloigne (> 16 studs) |
| `Combat/ArenaService` | `pickMatchArena` (arène **libre**), `resetArena`, `releasePoolOccupation` |
| `Match/MatchService` | téléporte, puis **réinitialise l'arène** au retour salon / revanche |

Flux : joueur sur un pad (E ou hitbox) → `SlotMatchService.claimByIndex` → 2 joueurs → `MatchService.tryStartPair`
→ `ArenaService.pickMatchArena()` (1ʳᵉ arène libre, rotation) → téléportation → combat BO3 →
`returnToLobby` : joueurs au spawn, arène libérée **puis reconstruite** (`resetArena`).

## 5. Organiser le Workspace (étape par étape)

**Cas par défaut : rien à faire.** `rojo serve` / Play → le serveur crée `Workspace.Arenas.ConcordLobby` et les 8 dossiers d'arènes.

**Si tu construis/remplaces des morceaux à la main dans Studio**, respecte ce contrat (noms, tags, attributs) :

1. `Workspace/Arenas/` (Folder) contient `ConcordLobby` (Model) et les 8 dossiers d'arènes.
2. **Lobby** : Model `ConcordLobby` avec l'attribut `ArtPass = 13` (sinon il est détruit et reconstruit au démarrage).
3. **Spawn** : une `SpawnLocation` taguée `BC_LobbySpawn`, orientée −Z.
4. **Pads** : 2 Parts nommées **`ClaimPad`**, tag **`BC_DuelSlotPad`**, attributs `BC_DuelSlot = 1` et `BC_DuelSeat = 1|2`,
   chacune avec un `ProximityPrompt` enfant. Une Part volume (CanCollide off, transparente) taguée de même ajoute la hitbox spatiale.
5. **Arène** (un Folder/Model par arène) : tag **`BC_MatchArena`**, attribut `BC_ArenaIndex` = 1..8, attributs `OffsetX` / `OffsetZ`,
   deux Parts taguées `ArenaSpawnA` / `ArenaSpawnB` (positions des combattants). Zones mortelles : tag `KillPlane`, dangers : tag `Hazard`.
6. **Néons** : Parts Neon taguées `BC_NeonStrip` pour les effets de dérive (budget émetteurs partagé).
7. Lighting : régler **Technology = Future** à la main, le reste est posé par le script.

Attention : `resetArena` reconstruit une arène depuis `ArenaService` (pas depuis ta version manuelle) ; pour garder une arène
dessinée à la main, retire-la du pool (pas de tag `BC_MatchArena`) ou adapte `resetArena`.

## 6. Limites connues

- **Un seul match à la fois par serveur** : `MatchService` / `CombatService` gardent une phase globale
  (`MatchService.getPhase()`). Le pool gère déjà l'occupation par arène (`occupied`), mais faire tourner 2+ duels
  simultanés demande de passer `MatchService`/`CombatService` en sessions par match. Chantier à part.
- Les décors thématiques des arènes datent d'une échelle 120 : le contenu reste centré, le surplus de sol est dégagé.
- Aucun test dans Studio n'a été fait depuis cet environnement (syntaxe Luau vérifiée uniquement).
