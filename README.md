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
- Hitboxes capsule lame, autorité serveur, clash (stamina −8, micro-KB, VFX)
- Esquive i-frames, dash combat, feinte
- Caméra lock soft + shake léger
- HUD soigné HP / stamina / flash Perfect·Clash·Riposte
- Sabre Constructible (hilt + Beam/Neon/Trail/Light) + poses Motor6D

### Match + Focus + arènes (P2)

- Lobby auto → countdown → duel **BO3 (FT2)** → rematch
- Score UI + rotation d’arènes
- **Poussée Focus** / **Dash Focus** (CDs, stamina, anti-parade push, anti-stack esquive)
- Arènes GDD (art pass matériaux / lighting / props) :
  - **Obsidian Pit** — lave glow + cendres (8 DPS soft)
  - **Sanctum des Deux Astres** — vents + astres lumineux
  - **Trône d’Éclipse** — trône Constructible + pression estrade
  - **Quai Mirage** — quai / eau / panneaux mirage

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
    Shared/     CombatConfig, Theme, Remotes, Form/Economy/Ranked/QuestConfig
    Visual/     SaberBuilder (Constructible)
    Remotes/    créés au runtime (Combat + Meta)
  ServerScriptService/BladeConcord/
    Combat/     services + ArenaService art pass
    Match/      MatchService BO3 + KoFinisher FX
    Data/ Meta/ …
  StarterPlayer/.../BladeConcord/
    Combat/     Input, SaberPose, Hud, Predict, Bootstrap
    Camera/     SoftLock + CameraShake
    FX/         CombatFx
    Audio/      SoundHooks
    UI/         MetaHud
  Workspace/Arenas/   mapping Rojo (build runtime ArtPass=4)
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

Sabre / arènes / VFX / UI : **Constructible Studio-native** (voir `docs/visual-polish-notes.md` dans l’Agent Store).  
SoundIds et meshes importés restent optionnels (`SoundHooks`, `ServerStorage`). La **logique** serveur P0–P3 est inchangée.

---

## Visual / Playtest polish

Niveau cible : **proto showcase Roblox** jouable — pas un polish live AAA (pas de meshes custom, AnimationClips Editor, skybox textures, pack SFX master).

| Zone | État |
|------|------|
| Sabre Constructible + trail dual + Beam | Showcase |
| Poses Motor6D Light/Heavy | Correct |
| Hitstop client + sparks Perfect densifiés | Bon feeling |
| Countdown 3-2-1 + plaque VS | Soigné |
| KO orbit cam + restore soft-lock | Stub cinématique |
| Arènes ArtPass 4 (drift dust/embers + ambient loops) | Photographiable |
| HUD Theme + vignette faction optionnelle | Soigné |
| Audio library IDs + ambiance map | Jouable (placeholders) |

**Playtest Studio** : `rojo serve` → Play Solo → bot ~2 s → LMB/RMB/F/Shift → KO → touche **M** méta. Vérifier trail Active, countdown VS, ambient arène, pas de caméra stuck post-KO.
