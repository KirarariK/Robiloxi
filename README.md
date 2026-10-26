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
| F8 | Overlay debug anim (set + clip) — ou attribut `BC_AnimDebug` |

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
    Animation/  32 sets KeyframeSequence (AnimationSets, KeyframeFactory, Registry, Procedural)
    Remotes/    créés au runtime (Combat + Meta)
  ServerScriptService/BladeConcord/
    Combat/     services + ArenaService art pass
    Match/      MatchService BO3 + KoFinisher FX
    Data/ Meta/ …
  StarterPlayer/.../BladeConcord/
    Combat/     CombatAnimator (principal), SaberPose (fallback), Input, Hud…
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
SoundIds et meshes importés restent optionnels. La **logique** serveur P0–P3 est inchangée.

---

## Animations (32 sets)

**Count** : **32** sets (formes × rareté 1–16 + Concord situations 17–32) — qualité perçue prioritaire, pas de gonflage catalogue.

| Chemin | Rôle |
|--------|------|
| `AnimationSets` | Catalogue + `resolveForSnapshot` |
| `KeyframeFactory` | KeyframeSequence R15 + HiltGrip + jambes ; **smoothstep** ; **clamp** angles |
| `AnimationRegistry` | `RegisterKeyframeSequence` (Studio) → `Animator:LoadAnimation` |
| `ProceduralPlayer` | Fallback Motor6D.Transform (live / Register fail) |
| `CombatAnimator` | Branche CombatState → set/clip ; attrs `BC_AnimSet` / `BC_AnimClip` |
| `AnimDebugOverlay` | **F8** ou `BC_AnimDebug` → HUD set+clip |

**Playtest Studio**

1. `rojo serve default.project.json` → Rojo Connect → **Play Solo**
2. Output : `AnimationRegistry: … 32 sets` · `CombatAnimator: 32 sets · path=…`
3. **F8** (ou `LocalPlayer:SetAttribute("BC_AnimDebug", true)`) → lire set/clip live
4. LMB Idle→Startup→Active→Recovery (pas de cut) ; hold LMB Heavy ; RMB Guard ; Startup→RMB Feinte
5. Q/E Dodge · Shift Dash · F/G Focus · KO bot → `Concord_KOCollapse`
6. Touche **M** : Legendary / Duelant / Aegis / Epic pour overrides Concord (EdgePressure, ParryBrace, ClashRebound, AegisAbsorb, MurWindup)

Détail catalogue + Pass quality : Agent Store `docs/animation-sets-notes.md`.

---

## Visual / Playtest polish

Niveau cible : **proto showcase Roblox** jouable — pas un polish live AAA (pas de meshes custom Editor uploadés, skybox textures, pack SFX master).

| Zone | État |
|------|------|
| Sabre Constructible + trail dual + Beam | Showcase |
| **32 sets** KeyframeSequence + CombatAnimator (R15 clamp) | Principal (SaberPose fallback) |
| Hitstop client + sparks Perfect densifiés | Bon feeling |
| Countdown 3-2-1 + plaque VS | Soigné |
| KO orbit cam + restore soft-lock | Stub cinématique |
| Arènes ArtPass 4 (drift dust/embers + ambient loops) | Photographiable |
| HUD Theme + vignette faction optionnelle | Soigné |
| Audio library IDs + ambiance map | Jouable (placeholders) |

**Playtest Studio** : `rojo serve` → Play Solo → bot ~2 s → LMB/RMB/F/Shift → KO → **F8** overlay anim → touche **M** méta. Vérifier attributs `BC_AnimSet` / `BC_AnimClip`, trail Active, pas de caméra stuck post-KO.
