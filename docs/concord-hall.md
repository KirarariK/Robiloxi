# Concord Hall — croiseur + baie + 8 arènes

**ArtPass 9** (`BC_Layout = CruiserBay`). Origin monde `(0, 0, 700)`. Esthétique Dawn/Dusk sombre — pas de noms Star Wars.

## Lobby (intérieur croiseur)

| Élément | Local (studs) |
|---------|----------------|
| Spawn | `(0, 4, 40)` face −Z (baie) · tag `BC_LobbySpawn` |
| Hall | largeur 56 · longueur 140 · hauteur 28 · plafond + parois Metal + strips Neon |
| Baie Glass | Z = **−85**, 72×22, spectate arènes |
| Slot 1 | ring (−16, −58) pad Focus · `BC_DuelSlot=1` |
| Slot 2 | ring (+16, −58) pad Dawn · `BC_DuelSlot=2` |
| Legacy Amical/Classé | (±20, +55) `BC_QueuePad` |

Monde slots ≈ `(±16, ~1, 642)` · baie ≈ `(0, 12, 615)`.

## Lighting

- `Technology=Future` (pcall) + `LightingStyle=Realistic`
- Atmosphere sombre · Bloom néons · ColorCorrection froid · **DoF off**
- Attr : `BC_LightingMode=ConcordCruiser`, `BC_DoF=false`

## 8 arènes (ArenaService ArtPass 6)

Floors **120²**, spawns ±32. Offsets monde :

| # | Id | Côté | OffsetX | OffsetZ |
|---|-----|------|---------|---------|
| 1 | ObsidianPit | Left | −380 | 450 |
| 2 | SanctumAstres | Left | −380 | 280 |
| 3 | TroneEclipse | Left | −380 | 110 |
| 4 | QuaiMirage | Left | −380 | −60 |
| 5 | ForgeAube | Right | +380 | 450 |
| 6 | SpireCrepuscule | Right | +380 | 280 |
| 7 | RecifNeant | Right | +380 | 110 |
| 8 | CourCristal | Right | +380 | −60 |

Source : `LobbyConfig.ArenaLayout`. `getSpawnCFrames` lit `OffsetX`+`OffsetZ`.

## Contrats Match

- `bindDuelSlots` → `SlotMatchService` (slots **1–2** seulement)
- `ArenaService.list()` = 8 ids · rotation match inchangée

## Modules

`Lobby/{Config,Util,Lighting,Props,Builder}` · `ArenaService` · docs store `archi-croiseur-lobby.md`
