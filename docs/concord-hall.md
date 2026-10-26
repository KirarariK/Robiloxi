# Concord Hall — lobby allée + slots 1v1

Layout **ArtPass 8** (`BC_Layout = AlleySlots`) : grande allée centrale + rings 1v1 côte à côte (réf `ref-lobby.png`). Origin monde `(0, 0, 700)`.

## Modules

| Module | Rôle |
|--------|------|
| `Lobby/LobbyConfig.lua` | Allée, slots, palette, budgets, tags |
| `Lobby/LobbyUtil.lua` | Parts / lights / emitters + compteurs |
| `Lobby/LobbyLighting.lua` | Ciel clair, Bloom/CC légers, **DoF off** |
| `Lobby/LobbyProps.lua` | `duelSlot` (ring + pad + SurfaceGui) |
| `Lobby/LobbyBuilder.lua` | Assemble allée + slots + hooks |

`ArenaService.ensureLobby()` → `LobbyBuilder.ensure`.  
`MatchService` actuel : `bindQueuePads` (pads Amical/Classé fin d’allée).  
**À brancher (Combat)** : `LobbyBuilder.bindDuelSlots(claimFn)`.

## Spawn

Local `(0, 4, 8)` face **nord (−Z)** — début d’allée. Monde ≈ `(0, 4, 708)`.

## Slots 1v1 (locaux X,Z → monde Z+700)

| Slot | Côté | Centre ring (X,Z) | Pad couleur |
|------|------|-------------------|-------------|
| 1 | Left | (−52, −36) | cyan Focus |
| 2 | Right | (+52, −36) | vert Success |
| 3 | Left | (−52, −88) | violet Arcane |
| 4 | Right | (+52, −88) | orange Dawn |
| 5 | Left | (−52, −140) | or Gold |
| 6 | Right | (+52, −140) | teal Mirage |
| 7 | Left | (−52, −192) | cyan Focus |
| 8 | Right | (+52, −192) | violet Arcane |

Pad claim ≈ vers l’allée (X ±28). Monde ring ≈ `(X, ~1, Z+700)`.

## Attributs / tags

| Élément | Attribut / tag |
|---------|----------------|
| Root | `ArtPass=8`, `BC_Layout=AlleySlots`, `BC_DuelSlotCount=8`, `BC_LobbyOrigin` |
| Claim pad / touch | `BC_DuelSlot` (number), tag **`BC_DuelSlotPad`**, ProximityPrompt « Rejoindre Slot N » |
| Slot model | `BC_DuelSlot`, `BC_DuelSlotSide`, `BC_ZoneId=DuelSlot` |
| SurfaceGui panneau | titre `SLOT N`, status « 1v1 — libre » |
| Legacy queue | `BC_QueueMode` Casual\|Ranked, tag `BC_QueuePad` — coords (−18/−240) (+18/−240) |
| Lighting | `BC_LightingMode=ConcordAlley`, `BC_DoF=false` |

## Contrat MatchService / Combat (hooks Lobby)

```luau
-- Après ArenaService.ensureLobby() :
LobbyBuilder.bindDuelSlots(function(player: Player, slotIndex: number)
  -- File par slotIndex (max 2). 2 joueurs → téléport arène BO3.
  -- Solo Studio : bot optionnel après délai.
end)

LobbyBuilder.getDuelSlotInfos()  -- layout
LobbyBuilder.getDuelSlotPad(n)   -- BasePart ClaimPad
LobbyBuilder.getSpawnCFrame()    -- retour lobby
```

World lobby **ne code pas** la file ni le téléport match.

## Budgets

≤ 6000 parts · ≤ 20 lights · ≤ 30 emitters · ≤ 12 SurfaceGui. Log : `[BladeConcord] ConcordHall budget …`.
