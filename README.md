# Blade Concord

Duel 1v1 au **sabre d’énergie** sur Roblox — skill-based, stamina, parade parfaite.

**Scope P0 (ce repo)** : proto combat Studio — attaques légère/lourde, parade, stamina, hitboxes serveur, arène **Obsidian Pit**, HUD HP/stamina.

**Hors MVP** : gacha, ranked, shop, Focus powers (Push / Dash Focus), esquive/dash/feinte.

Design & TDD (Agent Store) :

- `/cursor/stores/self/docs/gdd-duel-sabre.md`
- `/cursor/stores/self/docs/roadmap-mvp.md`
- `/cursor/stores/self/docs/tdd-combat-mvp.md`
- `/cursor/stores/self/docs/skills-install-notes.md`

---

## Structure

```
src/
  ReplicatedStorage/BladeConcord/
    Shared/          CombatConfig, CombatTypes, Remotes
    Remotes/Combat/  RemoteEvents (créés aussi au runtime)
  ServerScriptService/BladeConcord/Combat/
    CombatBootstrap.server.lua
    CombatService, StaminaService, AttackService,
    GuardService, HitService, ArenaService, FighterState
  StarterPlayer/.../BladeConcord/Combat/
    CombatBootstrap.client.lua
    InputCombat, CombatPredict, CombatHud
  Workspace/Arenas/  mapping Rojo (Pit buildée par ArenaService)
```

---

## Ouvrir dans Roblox Studio (Rojo)

1. Installer [Rojo](https://rojo.space/docs/installation/) (CLI + plugin Studio).
2. Dans ce repo :

```bash
rojo serve default.project.json
```

3. Dans Studio : New Baseplate → plugin **Rojo** → **Connect** (port 34872 par défaut).
4. Play Solo ou Local Server + 2 Players.

**Contrôles PC** : LMB = légère (maintenir ≈ lourde) · RMB = parade hold.

### MCP Studio (optionnel, agents)

Assistant → Manage MCP Servers → Enable Studio as MCP server — voir `/cursor/stores/self/docs/skills-install-notes.md`.

### Skills Cursor

Pack `TabooHarmony/roblox-brain` installé sous `.agents/skills/` (29 skills).

---

## Lexique live

Sabre / Focus / Ordre de l’Aube / Voie du Crépuscule — **aucun** terme Star Wars en UI.
