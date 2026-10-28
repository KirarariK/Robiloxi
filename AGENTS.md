# Steal A Snake — handoff PC

> Lis ce fichier en premier. Projet Roblox tycoon/steal (Luau + Rojo). Langue user : **français**.

Repo : `KirarariK/Robiloxi` · branche **`main`** seulement (jamais de PR)  
Checkout PC : `C:\Users\devaa\Desktop\robiloxiiiii` · place : `StealASnake.rbxlx`

---

## Qu’est-ce que c’est

**Steal A Snake** : clone des mécaniques *Steal An Egg* (serpents).
Plots / 20 vivariums / treadmill / vol + poids / gardiens / mutations / fusion / rebirth / portes biomes.

Assets Blender FBX : `tools/steal-a-snake/exports/` (23 fichiers). En jeu : proxies Parts (`ModelFactory`) + VFX templates.

---

## Boucle

LMB N/A — **ProximityPrompt Voler** · **G** lâcher · DropZone · CollectPad · Treadmill · Fusion (slots 1+2+3) · Rebirth

Formules : `NormalSpeed = 16 + Speed^0.65` · `CarrySpeed = clamp(Normal - Weight*0.35, 5, Normal)`

---

## Lancer

```bat
cd C:\Users\devaa\Desktop\robiloxiiiii
rojo build -o StealASnake.rbxlx
```

MCP (Claude) : Roblox Studio + Blender.
