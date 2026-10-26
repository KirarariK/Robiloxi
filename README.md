# Blade Concord

Duel **1v1** au **sabre d’énergie** sur Roblox — skill-based (stamina, parade parfaite), Focus utilitaire, formes, ranked fair-kit, boutique cosmétiques.

**Lexique live** : Sabre / Focus / Ordre de l’Aube / Voie du Crépuscule / Astra·Duelant·Aegis·Zephyr — **aucun** terme Star Wars en UI.

Design (Agent Store) : `docs/gdd-duel-sabre.md`, `roadmap-mvp.md`, `tdd-combat-mvp.md`.

---

## Ouvrir dans Studio (Rojo)

```bash
rojo serve default.project.json
```

Studio → New Baseplate → plugin **Rojo** → **Connect** → Play Solo ou Local Server + 2 Players.

DataStores : **mock automatique en Studio** (`DataStoreSafe`) ; en production Roblox DataStore API (retries + session lock soft).

---

## Contrôles

### PC

| Input | Action |
|-------|--------|
| LMB | Attaque légère (maintenir ≈ lourde) |
| RMB | Parade hold (pendant startup légère = **feinte**) |
| Q / E ou double-tap A / D | Esquive (i-frames 160 ms) |
| Shift + direction | Dash combat (pas d’i-frames) |
| F | **Poussée Focus** (knockback, 0 dmg, CD 14 s) |
| G | **Dash Focus** (12 studs + i-frames 100 ms, CD 11 s) |
| M | Panneau méta (shop / gacha / quêtes / queue) |

### Mobile

Boutons ContextActionService : **Attaque**, **Parade**, **Esquive**, **Dash**, **Poussée**, **Dash Focus** (hold Attaque = lourde).

---

## Systèmes livrés

### Combat (P0 + P1)

- Attaques légère / lourde (frame data serveur)
- Parade hold + perfect ±90 ms, chip, guard break, riposte-lock + buff légère +30 %
- Stamina 100, regen 18/s après 0,35 s, exhaustion &lt; 15
- Hitboxes capsule lame, autorité serveur, clash (stamina −8, micro-KB, VFX stub)
- Esquive i-frames, dash combat, feinte
- Caméra lock soft adversaire
- HUD HP / stamina / flash Perfect·Clash·Riposte

### Match + Focus + arènes (P2)

- Lobby auto → countdown → duel **BO3 (FT2)** → rematch
- Score UI + rotation d’arènes
- **Poussée Focus** / **Dash Focus** (CDs, stamina, anti-parade push, anti-stack esquive)
- Arènes GDD :
  - **Obsidian Pit** — lave bordure (8 DPS soft)
  - **Sanctum des Deux Astres** — vents latéraux
  - **Trône d’Éclipse** — pression anti-camp estrade
  - **Quai Mirage** — panneaux temporaires (cycle collide)

### Méta (P3)

- **Formes gacha** Commun→Légendaire, pity 40/90, fragments sur doublons
- **Ranked fair-kit** : passifs capped Rare ; Épique/Légendaire = cosmetics/mastery en Ranked (`Fair Kit · STATS: RARE CAP`)
- **Économie** : Crédits d’Arène (victoires/quêtes) + Éclats Focus (stub grant) + Fragments
- **Boutique** : couleurs lame, manches, auras, skins, emotes, finishers (0 stats)
- **MMR/ELO** Bronze→Grandmaster, modes Casual vs Ranked
- **Rétention** : quêtes journalières, factions Aube vs Crépuscule (War Score), event week-end double crédits (stub calendrier)
- **DataStores** : `BladeConcord_Player_v1` + mock Studio

---

## Structure

```
src/
  ReplicatedStorage/BladeConcord/
    Shared/     CombatConfig, CombatTypes, Remotes, FormConfig, EconomyConfig, RankedConfig, QuestConfig
    Remotes/    créés au runtime (Combat + Meta)
  ServerScriptService/BladeConcord/
    Combat/     services combat + ArenaService + Dodge/Dash/Focus
    Match/      MatchService BO3
    Data/       DataStoreSafe, PlayerDataService
    Meta/       FormService, ShopService, RankedService, QuestService, MetaBootstrap
  StarterPlayer/.../BladeConcord/
    Combat/     Input, Predict, Hud, Bootstrap
    Camera/     SoftLockCamera
    UI/         MetaHud
  Workspace/Arenas/          mapping Rojo (build runtime)
  ServerStorage/BladeConcord stubs assets TODO
```

---

## Panneau Méta (touche M)

1. Queue Casual ou Ranked  
2. Banner formes (pull ×1 soft / ×10 premium / ticket free hebdo)  
3. Équiper forme owned  
4. Boutique cosmétiques + stub +100 Éclats  
5. Claim quêtes  
6. Choisir faction (une fois)

---

## Notes assets

Meshes sabre, animations swing/dodge, finishers, emotes : **stubs** (Parts Neon, Trails, StringValue TODO sous `ServerStorage/BladeConcord`). La **logique** est complète sans ces assets.
