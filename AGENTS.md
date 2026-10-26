# Blade Concord — handoff Cursor PC

> Lis ce fichier en premier. Projet Roblox 1v1 sabre (Luau + Rojo). Langue user : **français**.

Repo : `KirarariK/Robiloxi` · branche **`main`** seulement (jamais de PR)  
Checkout PC : `C:\Users\devaa\Desktop\robiloxiiiii` · place : `BladeConcord.rbxlx`

---

## Qu’est-ce que c’est

**Blade Concord** : duel compétitif 1v1 au sabre d’énergie (branding original Dawn/Dusk — pas de noms Star Wars). Combat skill-based (parade, dash, Focus), formes gacha + Fair Kit Ranked, boutique cosmétiques, quêtes, factions.

GDD / TDD / roadmap (store Project, si monté) :
- GDD, roadmap, TDD, limitations, direction UI : voir aussi `docs/` du repo (`docs/concord-hall.md`, etc.) et le Context Project Cursor.

---

## Règles absolues

1. Push **direct `main`** — pas de Pull Requests.
2. **Pas de clips** vidéo / anim showcase sauf demande explicite.
3. Piste **animations procédurales abandonnée** — ne pas relancer Animation feel.
4. Spawn = **lobby d’abord**, jamais duel direct.
5. UI / map : **pas générique** ; côté écran pour Classe / Boutique / Reroll.
6. Kit combat jouable : **LMB** attaque · **RMB** parade · **Shift** dash · **Space air** double saut · **F** Force Push.
7. Après changement jouable : rebuild `BladeConcord.rbxlx` sur le Desktop.

---

## État actuel de la map (ArtPass 9)

| Élément | Détail |
|--------|--------|
| Lobby | Hall intérieur type croiseur (Metal/Neon), lighting **Future** |
| Baie | Grande baie **Glass** pour spectate visuel |
| Matchmaking | **Exactement 2 slots** devant la baie (`BC_DuelSlot` 1–2, ProximityPrompt + Touched) |
| Arènes | **8** grandes (4 gauche / 4 droite), tag `BC_MatchArena`, floors ~120² |
| UI lobby | Rails **Classe** / **Boutique** (gauche) · **Reroll** (droite) |
| VFX | `NeonFx.lua` + tags `BC_NeonStrip` |
| Bug Play | Fix sons ambiance IDs non-Audio (Output rouge) — Ambient* vides / skip preload |

**Polish restant** : densifier volumes (moins “strips dans le vide”), DoF faible/off, baie + arènes plus lisibles.

---

## Architecture code (Rojo)

```
src/
  ReplicatedStorage/BladeConcord/   Shared, Animation, Visual (NeonFx, Saber…)
  ServerScriptService/BladeConcord/
    Combat/     ArenaService, CombatService, HitService, …
    Lobby/      LobbyBuilder, LobbyConfig, LobbyLighting, LobbyProps, …
    Match/      MatchService, SlotMatchService, …
    Meta/       Form/Shop/Ranked/Quest…
    Data/       PlayerData, DataStoreSafe
  StarterPlayer/StarterPlayerScripts/BladeConcord/
    Combat/     InputCombat, CombatHud, …
    UI/         LobbyHud, MetaHud, Kit/*, Screens/*
    Audio/      SoundHooks
    FX/         LobbyNeon.client…
```

Contrats utiles :
- Slots : attribut `BC_DuelSlot`, tag `BC_DuelSlotPad`
- Arènes match : tag `BC_MatchArena`
- 2 joueurs même slot → `SlotMatchService` → arène libre ; solo Studio → bot ~2,5 s

---

## Comment lancer (PC)

```bat
cd C:\Users\devaa\Desktop\robiloxiiiii
git pull --rebase origin main
rojo build -o BladeConcord.rbxlx
```

Ouvrir `BladeConcord.rbxlx` dans Studio → Play.  
Rojo serve (souvent port **34872**) si sync live.

Smoke : `bash tools/smoke-check.sh` (si dispo).

---

## MCP Roblox Studio (actif sur le PC)

- Studio → Assistant → Manage MCP Servers → **Enable ON** · Quick connect **Cursor ON** · **1 client connecté**.
- `C:\Users\devaa\.cursor\mcp.json` :

```json
{
  "mcpServers": {
    "Roblox_Studio": {
      "command": "cmd.exe",
      "args": ["/c", "cd /d %LOCALAPPDATA%\\Roblox && .\\mcp.bat"]
    }
  }
}
```

En chat Cursor **local** tu peux : `list_roblox_studios`, tree, `execute_luau`, play, `screen_capture`, `generate_mesh` / procedural…  
Skill : `.agents/skills/roblox-studio-mcp/SKILL.md`

---

## Skills installés (`.agents/skills/` — ~89)

### Roblox (TabooHarmony/roblox-brain)
`roblox-luau-core`, `roblox-luau-types`, `roblox-luau-patterns`, `roblox-architecture`, `roblox-networking`, `roblox-security`, `roblox-performance`, `roblox-data`, `roblox-server-data`, `roblox-building`, `roblox-lighting`, `roblox-animation-vfx`, `roblox-gui`, `roblox-input`, `roblox-camera`, `roblox-physics`, `roblox-npc-ai`, `roblox-audio`, `roblox-studio-mcp`, `roblox-tooling`, `roblox-cloud`, `roblox-publish-checklist`, design/growth/monetization/analytics/psychology/localization/collaboration…

**Prioritaires map/lobby :** `roblox-building`, `roblox-lighting`, `roblox-performance`, `roblox-animation-vfx`, `roblox-studio-mcp`.

### Ponytail
`ponytail`, `ponytail-review`, `ponytail-audit`, `ponytail-debt`, `ponytail-gain`, `ponytail-help`  
Hooks : `.cursor/hooks.json` · clone local : `%USERPROFILE%\tools\ponytail`

### OmniRoute
`omni-auth`, `omni-models`, `omni-providers`, `omni-mcp`, `omni-combos-routing`, … + `cli-*`

### vercel-labs/agent-skills
`vercel-react-best-practices`, `vercel-optimize`, `web-design-guidelines`, `writing-guidelines`, …

### Graphify
Rule always-on : `.cursor/rules/graphify.mdc` · CLI : `graphify` · build : `/graphify .` → `graphify-out/`

### CLI
`skills` + `ags` (`@agentskill.sh/cli`) — réinstall : voir `docs` / preferences tooling.

---

## Équipe agents Project (cloud) — ne pas recréer

| Rôle | Focus |
|------|--------|
| Combat systems | Hitboxes, SlotMatch, double saut, Force |
| World lobby | Géométrie lobby / arènes / lighting |
| Premium UI | Rails + écrans méta |
| VFX polish | NeonFx, trails, particles |
| Meta economy | Gacha, shop, ranked, data |
| Studio build | Pull + rojo + place sur **ce PC** |
| Animation feel | **PARKED** |

---

## Fait (résumé chronologique)

1. Scaffold Rojo + GDD combat / meta / ranked  
2. Combat P1 + BO3 + Focus + arènes  
3. Formes gacha Fair Kit + économie + quêtes/factions  
4. ≥20 sets anim (piste ensuite **abandonnée**)  
5. Lobby spawn + UI premium + maquettes  
6. Allée slots → puis **croiseur** 2 slots + 8 arènes  
7. Rails Classe / Boutique / Reroll  
8. Tools permanents Ponytail / Graphify / OmniRoute / agent-skills  
9. MCP Studio connecté Cursor PC  
10. Fix bug Play (sounds Ambient)

---

## Prochaines priorités suggérées

1. Densifier lobby croiseur (volumes Metal, baie lisible, DoF off) via World lobby + MCP `generate_procedural_model` si utile  
2. Vérifier Play + claim 2 slots → arène  
3. Sons Ambient valides (vrais asset Audio)  
4. Polish arènes / Fair Kit / mobile

---

## Liens utiles dans le repo

- `default.project.json` — Rojo  
- `docs/concord-hall.md` — layout lobby  
- `tools/smoke-check.sh`  
- `.cursor/rules/graphify.mdc`  
- `.agents/skills/**/SKILL.md`

Fin du handoff — mets à jour ce fichier quand l’état map/MCP/skills change.
