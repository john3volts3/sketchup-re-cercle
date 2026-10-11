# Re-Cercle — Manuel utilisateur

[English version](MANUAL.en.md) · [README](../README.fr.md)

Version 2.0.0

## 1. Ce que fait Re-Cercle

Un cercle ou un arc natif SketchUp est un seul objet : un clic le sélectionne, l'outil Ligne
infère son centre et *Infos sur l'entité* affiche son rayon. Après certaines opérations (outils
solides, intersections, imports, *Éclater la courbe*…), un cercle peut perdre ces propriétés : il
devient des segments indépendants, une courbe soudée sans inférence de centre, plusieurs courbes, ou
des segments recoupés par des sommets en trop.

Re-Cercle retrouve ces cercles et arcs cassés et les **reconstruit en cercles et arcs natifs**, au
même endroit, avec le même rayon et le même nombre de segments. Seule la géométrie actuelle est
analysée, pas la façon dont elle a été obtenue.

## 2. Utilisation

1. Sélectionner ce qui contient les cercles ou arcs cassés :
   - **un seul segment** d'un cercle ou d'un arc suffit : tout le cercle est retrouvé ;
   - **des faces** : leurs arêtes sont analysées ;
   - **des groupes et composants** : tout leur contenu est analysé, groupes imbriqués compris.
2. Cliquer sur le bouton **Re-Cercle** de la barre d'outils, ou *Extensions > Re-Cercle > Restore
   Circles*.
3. Lire le message (en anglais) :
   - `N circle(s)/arc(s) rebuilt as native circles (center inference).` — N reconstruits en natif ;
   - `N welded into one curve, not native: <raison>.` — N soudés, voir la section 4 ;
   - `No broken circle or arc found in the selection.` — rien n'a été modifié.
4. *Édition > Annuler* (Ctrl+Z) annule toute la commande en une fois.

Les cercles déjà natifs ne sont pas touchés.

## 3. Ce qui est reconnu

| Forme | Règle |
|-------|-------|
| Cercle | Boucle fermée de 6 segments ou plus, coins sur un même cercle, même angle à chaque coin |
| Arc | Chaîne ouverte de 3 segments ou plus, mêmes règles |
| Segment recoupé | Un segment coupé en morceaux alignés compte pour un seul segment |
| Ignoré | Cercles natifs, anneaux de surfaces lisses (arêtes adoucies ou masquées, ex. sphère) |

Tolérance : 0,001" ou 0,5 % du rayon, la plus grande des deux.

## 4. Comment chaque cas est réparé

| Cas | Résultat |
|-----|----------|
| Cercle libre, disque, trou dans une face plane, coin arrondi | Cercle ou arc **natif** |
| Cercle traversé par une ligne à ses coins | Arcs **natifs** entre les lignes (comme SketchUp) |
| Cercle traversé par une ligne au milieu d'un segment | Arcs **natifs** ; le segment coupé reste en arêtes simples |
| Arc qui se termine au milieu d'un segment | Arc **natif** sur les segments complets ; le morceau partiel reste une arête simple |
| Extrémité d'un trou ou d'un tenon droit (cylindre, tronc de cône) | Les deux extrémités **natives** (reconstruction par Pousser/Tirer) |
| Cercle sur une surface courbe, trous empilés (fraisurage sur un trou), cylindre oblique, tube sans face d'extrémité, face triangulée | **Soudé** en une seule courbe : sélection en un clic, mais sans inférence de centre |

Ce qui est conservé : les faces voisines avec leurs matériaux (recto et verso), leur balise et leur
orientation ; les trous de ces faces ; la balise et l'état adouci/masqué des arêtes ; la paroi lisse
d'un trou.

## 5. Limitations

- Un polygone régulier de 6 côtés ou plus (hexagone…) ressemble exactement à un cercle : il devient
  un cercle natif.
- Les faces reconstruites perdent la position de leur texture et leurs attributs ; leurs
  identifiants changent.
- Dans un composant, la définition est modifiée : toutes les instances sont réparées. Les copies
  d'un groupe partageant la même définition sont modifiées ensemble.
- Un cercle dont les sommets ne sont pas régulièrement répartis n'est pas reconnu.
- La soudure de secours nécessite SketchUp 2020.1 ou plus récent ; sur les versions antérieures,
  ces cercles sont laissés tels quels et signalés.
