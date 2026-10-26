# Concord Hall — lobby serveur

Hall procédural ~360×360 studs (`LobbyArtPass = 6`), origin monde `(0, 0, 700)` pour ne pas chevaucher les arènes de match.

## Modules

| Module | Rôle |
|--------|------|
| `Lobby/LobbyConfig.lua` | Layout, palette, budgets, tags |
| `Lobby/LobbyUtil.lua` | Parts / lights / emitters + compteurs |
| `Lobby/LobbyLighting.lua` | Atmosphere, Sky, Bloom, CC, SunRays, DoF |
| `Lobby/LobbyProps.lua` | Colonnes, arches, braseros, cristaux, piédestaux |
| `Lobby/LobbyBuilder.lua` | Assemble zones + pads + anims + leaderboards |

`ArenaService.ensureLobby()` délègue à `LobbyBuilder`. `MatchService` bind les pads → `enqueue`.

## Zones (coordonnées locales plaza)

| Zone | Centre (X, Z) |
|------|----------------|
| Plaza / spawn | (0, 0) |
| Pad Amical | (−26, −96) cyan |
| Pad Classé | (+26, −96) or |
| Galerie | (0, −140) |
| Dioramas | Obsidian (−105,−215) · Sanctum (0,−235) · Mirage (+105,−215) |
| Classement ELO / Faction | (−64,−64) / (+64,−64) |
| Aube / Crépuscule | (−135,−10) / (+135,−10) |
| Formes / Forge | (−95,+80) / (+95,+80) |
| Quêtes / Entraînement | (0,+105) / (0,+170) |

Pads monde (studs) ≈ Amical `(−26, ~2, 604)` · Classé `(26, ~2, 604)`.

## Attributs / tags client

- `ConcordLobby` : `ArtPass`, `DisplayName`, `BC_LobbyOrigin`, `OffsetZ`
- Pads : `BC_QueueMode` = `Casual` \| `Ranked`, tag `BC_QueuePad`, ProximityPrompt + Touched
- Zones : `BC_ZoneId`, tag `BC_LobbyZone`
- Panneaux : `BC_OpenPanel` = `Forms` \| `Forge` \| `Quests` (UI client)
- Leaderboards : `BC_LeaderboardKind` = `Elo` \| `FactionTop` \| `Faction`
- Joueur : `BC_MMR`, `BC_Faction`, `BC_WarScore` (rafraîchis 60 s pour SurfaceGui)
- Lighting : `BC_LightingMode` = `ConcordHall`
- MatchState `arenaId = "ConcordLobby"` → `SoundHooks.AmbientLobby`

## Budgets

≤ 6000 parts · ≤ 20 PointLights · ≤ 30 ParticleEmitters · ≤ 6 SurfaceGui. Log au build : `[BladeConcord] ConcordHall budget …`.
