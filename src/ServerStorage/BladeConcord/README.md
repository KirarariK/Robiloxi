# ServerStorage — assets

Placeholders pour assets importés plus tard. Le polish actuel est **100 % Constructible** (Parts / Beams / Particles / UI) + **KeyframeSequences générés en Luau**.

| Chemin prévu | Usage | Statut |
|--------------|--------|--------|
| `SaberMeshes/` | Hilts / cristaux custom | Remplacé par `SaberBuilder` Constructible |
| `Animations/` | Swing Light/Heavy, Guard, Dodge | **24 sets** dans `ReplicatedStorage/BladeConcord/Animation/` (KeyframeFactory). Upload `rbxassetid://` optionnel pour live |
| `Finishers/` | Cinématiques finisher | Stub `KoFinisher` (ring + Billboard CONCORDANCE) |
| `Emotes/` | Emotes salon | TODO |
| `Audio/` | SoundIds combat | Hooks `SoundHooks` — coller `rbxassetid://` |

## Pipeline anim (Studio)

1. `KeyframeFactory` construit des `KeyframeSequence` R15 (+ `HiltGrip`)
2. `KeyframeSequenceProvider:RegisterKeyframeSequence` → ID temporaire Studio
3. `Animator:LoadAnimation` via `CombatAnimator`
4. Hors Studio : `ProceduralPlayer` applique les mêmes courbes sur `Motor6D.Transform`
5. `SaberPose` = fallback Motor6D.C1 + couleurs / trails

La logique gameplay n’attend pas d’upload d’Animation.
