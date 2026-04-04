# FSD — Re-Cercle v1.0.0

## Description

Plugin SketchUp qui restaure les cercles cassés (suites de edges individuels) en vraies courbes (`Curve`) sélectionnables en un clic.

## Problème résolu

Certaines opérations SketchUp (subtract, union, retrace, import/export, manipulations manuelles) cassent les associations `ArcCurve`/`Curve` des cercles. Les cercles deviennent des suites de segments indépendants — un clic ne sélectionne plus qu'un seul segment au lieu du cercle entier.

## Entrées

- **Sélection SketchUp** : un ou plusieurs objets contenant des cercles cassés
  - Edges individuels
  - Groupes (exploration récursive)
  - Composants (exploration récursive)
  - Faces (collecte des edges)

## Algorithme

Le plugin fonctionne en une seule passe, sans inventaire préalable :

### Étape 1 — Edges libres (sans curve)

1. Collecte récursive de tous les edges de la sélection
2. Filtrage des edges sans association `Curve` (edges libres)
3. Pour chaque edge non encore traité :
   - Collecte de tous les voisins aux deux extrémités
   - Pour chaque voisin, calcul du **circumcircle** à partir de 3 points (extrémité libre, vertex partagé, extrémité libre du voisin)
   - Recherche de tous les edges correspondant à cette géométrie :
     - Distance au centre ≈ rayon (tolérance adaptative : `max(0.1, rayon × 0.005)`)
     - Coplanarité (dot product des vecteurs normalisés avec la normale < 0.01)
   - Validation : au moins 8 segments, boucle fermée
   - Si valide → `entities.weld(edges)`

### Étape 2 — Curves fragmentées

1. Filtrage des edges ayant une association `Curve`
2. Groupement par géométrie similaire (même centre, rayon, normale)
3. Si un groupe contient des edges de curves différentes → `entities.weld(edges)`

## Sorties

- Les cercles détectés sont restaurés en `Curve` via `weld`
- Message de confirmation avec le nombre de cercles restaurés
- Opération undoable (Ctrl+Z)

## Paramètres internes

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `TOLERANCE` | 0.1 | Tolérance de base (inches) |
| `MIN_SEGMENTS` | 8 | Nombre minimum de segments pour considérer un cercle |
| Tolérance distance | `max(0.1, r × 0.005)` | Adaptative au rayon |
| Tolérance coplanarité | 0.01 | Sur vecteurs normalisés |

## Limitations

- Ne détecte pas les arcs (portions de cercle non fermées)
- Ne restaure pas les `ArcCurve` natifs (seulement des `Curve` via weld) — le cercle est sélectionnable en un clic mais n'est plus reconnu comme cercle natif par SketchUp (pas d'affichage du rayon dans Entity Info)
- Nécessite SketchUp 2020.1+ (API `entities.weld`)
- Les cercles avec moins de 8 segments ne sont pas détectés (pour éviter les faux positifs avec des polygones réguliers)

## Interface utilisateur

- **Menu** : Extensions > Re-Cercle > Restaurer les cercles
- **Toolbar** : Re-Cercle (icône cercle vert 16×16 / 24×24)
- **Barre de statut** : affiche le résultat après exécution
- **MessageBox** : confirmation du nombre de cercles restaurés
