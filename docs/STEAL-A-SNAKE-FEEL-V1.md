# Steal A Snake — Passe « Feel v1 »

## Audit (gaps confirmés dans le code)
| Gap | Où | Statut |
|---|---|---|
| Portes de biome ouvertes pour **tous** dès qu'un joueur est qualifié, recalcul à chaque frame | `World/GateService` | ✅ corrigé |
| Fusion limitée aux vivariums 1/2/3 codés en dur | `UIController` + `PlotManager` | ✅ corrigé |
| Aucun tutoriel : objectif générique, rayon guide sans étapes récolte/tapis | `UIController`, `VFXController` | ✅ corrigé |
| Remote `RequestFusion` sans validation format/proximité/rate-limit | `PlotManager` | ✅ corrigé |
| Lisibilité base : pas de repères DÉPÔT / RÉCOLTE / TAPIS de loin | `MapBuilder.buildPlot` | ✅ corrigé |
| Jungle : sol vide entre les arbres, nid peu repérable | `MapBuilder.jungleProps` | ✅ densifiée |
| Import FBX `tools/steal-a-snake/exports` → MeshParts | aucun outil MCP d'import de fichier local | ⛔ bloqué (voir Risques) |
| `rojo build -o StealASnake.rbxlx` | Rojo non installé + écraserait les MeshParts générés (pas dans `src/`) | ⚠️ non exécuté |

## Changements
### A. Art / lisibilité
- Étiquettes flottantes : `📥 DÉPÔT`, `💰 RÉCOLTE`, `🏃 TAPIS · Vitesse` (MaxDistance 75).
- Anneau néon pulsé autour de la zone de dépôt (`DropRing`, pulsé côté client).
- Jungle : rochers, fougères, troncs couchés, 40 fleurs, 6 torches tiki enflammées autour du nid.

### B. Onboarding 4 étapes
- `Core/TutorialService` (nouveau) : `advance(player, fromStep)`.
  - 1 vol (`CarrySystem.steal`) → 2 dépôt (`PlotManager.depositSnake`) → 3 récolte (`PlotManager.collect`) → 4 tapis (`TrainingSystem`, Vitesse ≥ 1) → 5 terminé.
- `DataManager` : `TutorialStep` + `MaxBiome` sauvegardés.
  - Les anciennes sauvegardes avec progression sont considérées « tutoriel terminé ».
  - Les deux valeurs sont répliquées en attributs joueur par `push()`.
- Client :
  - Objectif « Étape n/4 » prioritaire.
  - Toasts verts ✅ à chaque étape.
  - Rayon guide plus épais, qui vise le bouton de récolte à l'étape 3 puis le tapis à l'étape 4.

### C. Fusion UI
- La fenêtre regroupe les vivariums par espèce + mutation et affiche au plus 5 groupes.
- Chaque groupe est un bouton sélectionnable. La fenêtre montre aussi un aperçu du résultat (mutation suivante, multiplicateur), ou le nombre de serpents qui manquent.
- Le serveur valide :
  - le format `Slot_N` ;
  - que les 3 slots sont distincts ;
  - une distance ≤ 20 studs de SA machine ;
  - 1 requête toutes les 0,5 s maximum.

### D. Portes par joueur
- La porte n'a plus de collision. Le serveur contrôle chaque joueur toutes les 0,2 s :
  - s'il ne remplit pas les conditions, il est repoussé 8 studs devant la porte avec le message « 🔒 il te manque : ⚡ X Vitesse · 💵 $Y » ;
  - s'il les remplit, le biome est débloqué définitivement (`MaxBiome`), sans dépense.
- Côté client, la porte devient transparente une fois débloquée, sinon elle reste rouge. La bannière affiche « ✅ Débloqué » ou ce qu'il faut.
- **Changement documenté** : la condition de Vitesse compare la stat « Vitesse » du HUD (`d.Speed`) et non plus la WalkSpeed.

### Formules
Inchangées : NormalSpeed, CarrySpeed, Income, anti-cheat (fenêtre 0,5 s, ×1,35).

## Comment tester (Studio → Play)
1. **Nouveau joueur :**
   - l'objectif affiche « Étape 1/4 » et le rayon jaune/bleu mène au nid ;
   - vole un serpent : toast ✅ et étape 2 ;
   - dépose-le : étape 3, le rayon pointe le bouton de récolte ;
   - récolte : étape 4, le rayon pointe le tapis ;
   - monte sur le tapis : 🎉.
2. **Porte du Désert :** tu es repoussé avec le détail de ce qui manque. Avec 25 Vitesse et $5K, la porte s'ouvre et le reste.
3. **Fusion :** avec 3 serpents identiques n'importe où dans les vivariums, la machine affiche le groupe ▶ ×3/3 et un aperçu du résultat.
4. **Console :** propre (vérifié en Play).

## Analyse de Steal An Egg (observée en jeu)
- **Base :**
  - parcelle clôturée où les familiers géants (voxel) **se promènent** ;
  - chaque familier a une étiquette « Mutation · Nom · $/s » ;
  - icône 🏠 au-dessus de ta base.
- **Stands dans la base :** « Machine de fusion 0/3 » (avec un ?), stand « VENDRE » (anneau vert), PNJ vendeur d'œuf d'événement (anneau jaune) et tapis « +X/pas ».
- **« ZONE SÉCURISÉE »** : bande au sol avec texte, devant les bases.
- **Œufs en croissance :** un panneau à droite montre l'incubation (timer en heures, bouton ▶) et « Tout faire pousser » (accélération payante).
- **Vagues :** « TOUS LES ŒUFS RÉINITIALISÉS ! » à intervalle fixe, avec un compte à rebours en bas à droite.
- **Annonces serveur :**
  - « Œuf secret aux crocs acérés est apparu dans Démons ! » quand un œuf rare apparaît ;
  - événements météo/lune : « Lune sanglante : tout donne ×2 » ;
  - cycle jour/nuit.
- **Index des familiers :**
  - grille par monde (Forêt, Lac…), silhouettes « ??? » colorées par rareté et progression n/8 ;
  - récompenses par découverte ($ + Vitesse) et « RÉCLAMER TOUT » ;
  - onglets Monde / Limité.
- **HUD :**
  - Vitesse et Argent énormes en bas à gauche ;
  - Boutique et Index à gauche, avec un badge rouge de notification ;
  - toggle « Mode lent » pour les vitesses extrêmes ;
  - leaderboard Argent/Vitesse.
- **Barre d'outils :** batte (frapper ou voler), pile d'œufs ×3, familiers, item d'événement.
- **Portail d'événement** « Dimension d'Halloween OUVERT » et panneau compte à rebours géant pour la mise à jour.

### À reprendre pour Steal A Snake (passe suivante)
1. **Vagues de nids :** réinitialisation globale toutes les N min, avec compte à rebours et annonce serveur des serpents Légendaire/Mythique.
2. **Index de collection par biome :** silhouettes, récompense par découverte, « Réclamer tout » et badge HUD.
3. **Événements temporaires :** nuit ou « lune de sang » ×2, cycle jour/nuit.
4. **Serpents vivants dans la base :** ils rampent dans leur vivarium, avec étiquette Mutation · Nom · $/s.
5. **Stand VENDRE** et **Mode lent** quand la Vitesse est extrême.

## Risques restants
- **Assets 3D :**
  - les modèles générés vivent uniquement dans `StealASnake.rbxlx`, pas dans `src/` ;
  - un `rojo build` les perdrait, donc il faut sauvegarder la place (Ctrl+S) après chaque session.
- **Import FBX :**
  - les fichiers de `tools/steal-a-snake/exports/` ne sont pas importables via MCP ;
  - il faut passer par Studio → Importer 3D, ou publier les meshes.
- **Blender MCP :** l'addon « MCP for Blender » (port 9876) ne répond pas aux appels de l'outil Blender actuel (protocole différent).
- **Porte :**
  - le repoussement se base sur la position Z ; un joueur très rapide peut voir un petit à-coup ;
  - la réplication de la porte est uniquement visuelle côté client.
