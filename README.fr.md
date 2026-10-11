# Re-Cercle — extension SketchUp

[English version](README.md) · [Manuel utilisateur](docs/MANUEL.fr.md)

Répare les **cercles et arcs cassés** en **vrais cercles et arcs natifs SketchUp** : inférence du
centre, rayon et segments dans *Infos sur l'entité*, sélection en un clic.

## Problème résolu

Certaines opérations (outils solides, intersections, imports, éclatement…) cassent les cercles :
ils deviennent des segments indépendants, des courbes soudées sans inférence de centre, des courbes
en plusieurs morceaux ou des segments recoupés par des sommets en trop. Re-Cercle analyse uniquement
l'état actuel de la géométrie — pas la façon dont elle a été obtenue — et reconstruit chaque cercle
ou arc exactement à sa place.

## Fonctionnalités

- Cercles (6 segments ou plus) et arcs (3 segments ou plus), dans n'importe quel plan.
- Sélection d'un seul segment, de faces, ou de groupes/composants entiers (explorés récursivement).
- Reconstruction en cercles/arcs **natifs**, même centre, rayon, nombre de segments et position des
  sommets :
  - cercles et arcs plans : cercles libres, disques, trous dans une face, coins arrondis ;
  - cercle traversé par une ligne : reconstruit en arcs natifs entre les croisements ;
  - cercles d'extrémité des trous et tenons droits (cylindres, troncs de cône) : reconstruits par
    un Pousser/Tirer natif, les deux extrémités deviennent natives.
- Les faces voisines sont conservées avec leurs matériaux (recto et verso), leur balise et leur
  orientation ; les trous restent ouverts.
- Quand SketchUp ne permet pas de reconstruire un cercle natif (surface courbe, trous empilés comme
  un fraisurage, cylindre oblique…), il est **soudé** en une seule courbe (sélection en un clic,
  mais sans inférence de centre) et la raison est indiquée.
- Une seule annulation par commande.

## Utilisation

1. Sélectionner les cercles/arcs cassés : un segment de chacun, des faces, ou des groupes/composants.
2. Cliquer sur le bouton **Re-Cercle** de la barre d'outils (ou *Extensions > Re-Cercle > Restore
   Circles*).
3. Un message indique le nombre de cercles/arcs reconstruits en natif et le nombre de soudés.

## Installation

Installer `build/re_cercle.rbz` via *Fenêtre > Gestionnaire d'extensions > Installer l'extension*.

## Compatibilité

Testé sur SketchUp 2021 (Windows). La soudure de secours nécessite SketchUp 2020.1 ou plus récent.

## Limitations

- Un polygone régulier de 6 côtés ou plus ne se distingue pas d'un cercle : il devient un cercle
  natif.
- Les faces reconstruites perdent la position de leur texture et leurs attributs (matériau, balise
  et orientation sont conservés).
- Dans un composant, toutes les instances sont modifiées.

## Licence

MIT
