# Re-Cercle — Plugin SketchUp

Plugin SketchUp 2021+ qui restaure les cercles cassés (suites de edges individuels) en vraies courbes (`Curve`) sélectionnables en un clic.

## Problème résolu

Certaines opérations SketchUp (subtract, union, retrace, import/export) cassent les associations `ArcCurve`/`Curve` des cercles. Les cercles deviennent des suites de segments indépendants — un clic ne sélectionne plus qu'un seul segment au lieu du cercle entier.

## Installation

1. Dans SketchUp : **Window > Extension Manager > Install Extension**
2. Sélectionner le fichier `build/re_cercle.rbz`

## Utilisation

1. Sélectionner un ou plusieurs objets (edges, groupes, composants) contenant des cercles cassés
2. **Extensions > Re-Cercle > Restaurer les cercles** (ou bouton dans la toolbar Re-Cercle)
3. Le plugin détecte et restaure automatiquement les cercles
4. Opération annulable avec **Ctrl+Z**

## Algorithme

Le plugin fonctionne en une seule passe :

1. **Collecte** récursive de tous les edges (sélection, groupes, composants)
2. **Détection par circumcircle** : pour chaque paire d'edges adjacents, calcul du cercle passant par 3 points, puis recherche de tous les edges correspondant à cette géométrie (même centre, rayon, plan)
3. **Validation** : vérification que les edges forment une boucle fermée
4. **Restauration** par `entities.weld()` — regroupe les edges en `Curve`

Les tolérances sont adaptatives (proportionnelles au rayon) pour supporter des cercles de toutes tailles.

## Compatibilité

- SketchUp 2021 et versions ultérieures (utilise `entities.weld` disponible depuis SketchUp 2020.1)

## Licence

MIT
