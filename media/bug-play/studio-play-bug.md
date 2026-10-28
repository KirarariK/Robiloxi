# Studio Play bug — diagnostic + fix

**HEAD avant fix :** `38486b6`  
**Fix pushé :** `73cd6a8` — `fix(audio): clear non-Audio ambient IDs that spam Play Output`  
**Place :** `C:\Users\devaa\Desktop\robiloxiiiii\BladeConcord.rbxlx`

## Symptôme user

« Quand je lance ça bug » → Output Studio rouge dès Play solo.

## Output exact (avant)

Extrait log Studio `*Studio*last.log` / `FLog::CreatorError` à chaque Play :

```
Error: Failed to load sound rbxassetid://9116395309: Asset type does not match requested type
Error: Failed to load sound rbxassetid://9114221571: Asset type does not match requested type
Error: Failed to load sound rbxassetid://9114221256: Asset type does not match requested type
Error: Failed to load sound rbxassetid://9113839759: Asset type does not match requested type
```

Aussi en Warning preload :

```
Warning: ContentId: rbxassetid://9114221256 failed due to: Asset type does not match requested type
```

(répété pour les 4 IDs)

## Cause

`SoundHooks.AssetIds.Ambient*` + `LobbyConfig.AmbientSoundIds` pointaient vers des **rbxassetid qui ne sont pas de type Audio**.  
`ContentProvider:PreloadAsync` + `Sound:Play` → spam rouge Output au lancement (lobby / ambient).

Bootstrap serveur/client OK malgré ça :

- `[BladeConcord] SlotMatchService: slots 1-2`
- `[BladeConcord] CombatBootstrap server ready`
- `[BladeConcord] Client ready`

Note historique (autre session) : `CombatHud:715 attempt to index nil with 'Transparency'` — non reproduit sur Play actuel ; garde `UIStroke` déjà nil-safe L587–590.

## Fix

1. `SoundHooks.lua` — `AmbientObsidian/Sanctum/Eclipse/Mirage/Lobby = ""` ; ne PreloadAsync que si `SoundId ~= ""`.
2. `LobbyConfig.lua` — `AmbientSoundIds` Hall/Forge/Fountain = `""`.

## Après (re-Play)

Log post-fix : **aucune** ligne `Failed to load sound` / `Asset type does not match`.  
Présent :

```
[BladeConcord] SlotMatchService: slots 1-2 → pool 8 arènes
[BladeConcord] CombatBootstrap server ready — combat + match + Focus + arènes
[BladeConcord] Client ready - salon · 32 anim sets · Jouer · M méta · F8 debug
```

## Screenshots

- Avant : `media/bug-play/01-play.png` (store + Desktop)
- Après : `media/bug-play/02-after-fix.png` (store + Desktop)

Store : `...\bc-01a17797-...\files\media\bug-play\`  
Desktop : `C:\Users\devaa\Desktop\robiloxiiiii\media\bug-play\`
