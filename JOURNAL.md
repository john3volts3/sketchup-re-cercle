# Journal des modifications — Re-Cercle

## Session du 2026-04-04

- **re_cercle.rb** — Création du loader principal (SketchupExtension, register_extension)
- **re_cercle/version.rb** — Création, VERSION = '1.0.0'
- **re_cercle/main.rb** — Création de la logique complète :
  - Collecte récursive des edges (sélection, groupes, composants)
  - Construction de chaînes d'edges connectés
  - Détection géométrique des cercles (centroïde, rayon, coplanarité)
  - Restauration par `entities.weld()` en une seule phase
  - Traitement des edges libres ET des curves fragmentées
  - Menu Extensions > Re-Cercle, toolbar avec icône
- **re_cercle/icons/re_cercle_16.png** — Icône toolbar 16x16 (cercle vert)
- **re_cercle/icons/re_cercle_24.png** — Icône toolbar 24x24 (cercle vert)
- **build/re_cercle.rbz** — Package d'installation généré
- Fichiers copiés dans le dossier plugins SketchUp 2021
- **re_cercle/main.rb** — Fix : algorithme de détection par circumcircle (essai de tous les voisins, pas seulement le premier)
- **re_cercle/main.rb** — Fix : tolérance de coplanarité normalisée (dot product / longueur du vecteur) pour supporter les grands cercles (r>300). Tolérance de distance rendue proportionnelle au rayon.
- **re_cercle/main.rb** — Retrait de tous les puts de debug
