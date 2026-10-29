# Ether Blades

Jeu Roblox de **duels 1v1 aux lames d'énergie**, basé sur la compétence (posture, parade parfaite, esquive, endurance).
Univers 100 % original : aucun nom ni élément de licence existante.

## Lexique
| Concept | Nom en jeu |
|---|---|
| Armes | Lame d'Éther (simple) · Lames Jumelles · Bâton-Lame |
| Formes de combat | les 7 **Voies** : Origine (I), Duelliste (II), Rempart (III), Faucon (IV), Riposte (V), Équilibre (VI), Tempête (VII) |
| Rangs | Initié → Apprenti → Chevalier → Maître → Archonte → Grand Maître (top 50) |
| Monnaie | Cristaux (gagnés en duel, dépensés en relances) |
| Arènes | Sanctuaire du Temple · Forge Volcanique · Ruines sous l'Orage · Chambre du Réacteur · Canyon de Cristal |

## Arborescence (Rojo, `default.project.json`)
- `src/shared` → `ReplicatedStorage.EtherBlades` : `Types`, `Net` (déclaration des remotes), `Config/*` (Voies, armes, cristaux, rangs, arènes, titres, emotes), `Util/Maid`.
- `src/server` → `ServerScriptService.EtherBlades` : `Main.server`, `Services/*` (Guard, RateLimiter, DataService…).
- `src/client` → `StarterPlayerScripts.EtherBlades` : `Main.client`, `ClientState`, contrôleurs.

## Sécurité
Toutes les remotes passent par `Services/Guard` : limite de débit par joueur, vérification des types (NaN/inf refusés), `pcall`.
Aucune valeur client n'est crue : le serveur recalcule tout (dégâts, Elo, relances, équipements).

## Données
`DataService` : verrou de session (UpdateAsync), 5 tentatives avec attente croissante, sauvegarde auto 120 s,
sauvegarde à la sortie et à la fermeture du serveur, migration de schéma. En Studio sans accès API : profils en mémoire.

## Déployer dans Studio sans Rojo
`python3 scripts/gen_deploy.py <sha>` génère un script Luau qui télécharge chaque fichier du commit depuis GitHub
et synchronise exactement les dossiers de `default.project.json` (à exécuter dans la barre de commande / MCP Studio).

Place : `EtherBlades.rbxl` (non versionnée).
