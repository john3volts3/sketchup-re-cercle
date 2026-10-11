# FSD — Re-Cercle v2.0.0

Compatibilité : SketchUp 2020.1+ pour la soudure de secours (`Entities#weld`) ; la reconstruction
native n'utilise que des API anciennes (`add_arc`, `find_faces`, `Face#pushpull`). Validé par
l'utilisateur sur SketchUp 2021 (Windows) le 2026-10-11.

## Description

Plugin SketchUp qui répare les cercles et les arcs cassés en **vrais cercles natifs**
(`Sketchup::ArcCurve`) : inférence du centre, rayon et segments dans *Infos sur l'entité*,
sélection en un clic. Quand SketchUp ne permet pas de reconstruire un cercle natif, il est soudé en
une `Curve` simple (comportement de la v1).

## Problème résolu

Un cercle ou un arc peut être « cassé » : suite d'arêtes indépendantes, `Curve` soudée sans
inférence de centre, courbe fragmentée en plusieurs morceaux, segment recoupé par un sommet en trop.
Seul **l'état actuel** de la géométrie est analysé, pas la façon dont il a été obtenu.

## Contraintes SketchUp (tests de Circle Re-Segment et du script `tools/spike/test_native_rebuild.rb`)

- Aucune API ne convertit des arêtes existantes en `ArcCurve` ; `weld` donne une `Curve` simple.
- `add_arc` posé sur des sommets intermédiaires déjà raccordés est fragmenté ; une arête ajoutée
  après coup sur un sommet intermédiaire casse aussi la courbe.
- `add_arc` dans le vide (extrémités éventuellement raccordées) + `find_faces` + `Face#pushpull`
  donnent des courbes natives (validé le 2026-10-11 : cercle libre, disque, trou, cercle traversé
  par une ligne, coins arrondis, cylindre).

## Entrées

- **Sélection** : arêtes (un segment suffit : toute la chaîne est retrouvée), faces (leurs arêtes),
  groupes et composants (exploration récursive). Dans un composant, la définition est modifiée
  (toutes les instances).

## Algorithme

### 1. Détection (`detector.rb`)

1. **Segments** (« runs ») : arêtes colinéaires consécutives fusionnées (segment recoupé par un
   sommet en trop = un seul segment).
2. **Chaîne** : à partir d'un segment et d'un voisin de même longueur, cercle passant par les
   3 coins ; extension dans les deux sens tant que le segment suivant finit sur le cercle et tourne
   du même angle (± 1 %), dans le même sens. Pas maximal 60° (au moins 6 segments par tour).
3. Chaîne **fermée** ≥ 6 segments = cercle ; **ouverte** ≥ 3 segments = arc.
4. Centre/rayon affinés sur 3 coins répartis ; tolérance `max(0.001", r × 0,5 %)`.
5. Ignorés : cercles natifs complets (`ArcCurve` de 360°), chaînes uniquement adoucies/masquées
   (anneaux d'une surface lisse, ex. sphère).

### 2. Classement (`Detector.analyse`)

| Classe | Condition | Traitement |
|--------|-----------|------------|
| `:native` | déjà une (ou des) `ArcCurve` exacte(s) | rien |
| `:volume` | une face hors du plan touche le cercle, et c'est l'extrémité d'un cylindre ou tronc de cône droit | reconstruction Push/Pull |
| `:weld` | face hors du plan sans volume reconnu, arêtes adoucies/masquées raccordées dans le plan (face triangulée), tous les segments coupés | soudure `weld` |
| `:planar` | toutes les faces touchées sont dans le plan du cercle | reconstruction plane |

Découpage en **morceaux** (`pieces_of`) : un coin où une ligne visible est raccordée coupe la
chaîne (le cercle devient plusieurs arcs natifs, comme dans SketchUp quand une ligne traverse un
cercle) ; un segment dont un point de coupe intermédiaire porte une ligne reste tel quel (arêtes
simples) et coupe la chaîne. Un arc dont un bout de segment est partiel (coupe au milieu d'un
segment) : l'arc natif couvre les segments complets, le bout partiel reste une arête simple.

### 3. Reconstruction plane (`rebuilder.rb`)

1. Instantané des faces touchant les arêtes à effacer : normale, matériaux recto/verso, balise,
   **point témoin** à l'intérieur de la face près de la chaîne, boucles intérieures (autres trous).
2. Effacement des arêtes (une face hôte se referme d'elle-même), puis `add_arc` par morceau :
   même centre, normale, rayon, nombre de segments et phase → les sommets reviennent au même
   endroit. Propriétés des arêtes reprises (balise, adouci, lissé, masqué, matériau).
3. `find_faces` sur chaque nouvel arc et sur une arête de chaque ancien trou.
4. Nouvelles faces contenant un point témoin : propriétés et orientation restaurées ; les autres
   bouchent un ancien vide (trou, cercle sans face) et sont supprimées. Si une face n'a pas pu
   recevoir de point témoin, rien n'est supprimé.

### 4. Reconstruction d'un volume (`volume.rb`, repris de Circle Re-Segment)

Détection : paroi = faces reliées par arêtes adoucies, exactement 2 boucles de frontière, chacune
étant une chaîne-cercle complète (points de coupe acceptés), coaxiales, même nombre de segments,
aucune autre ligne raccordée, faces voisines dans le plan des cercles, une face au moins à une
extrémité. Reconstruction : effacement paroi + cercles, `add_arc` (même phase, même nombre de
segments) sur l'extrémité portant une face (face hôte de préférence), `find_faces`, `Face#pushpull`
jusqu'à l'autre extrémité, mise à l'échelle pour un tronc de cône, restauration paroi
(orientation, matériaux, balise, arêtes adoucies) et extrémités, réparation des trous. Les deux
cercles deviennent natifs.

### 5. Soudure de secours

`Entities#weld` sur la chaîne (sauf si elle est déjà une seule courbe) : `Curve` simple,
sélection en un clic, pas d'inférence de centre. Avant SketchUp 2020.1 : laissée telle quelle et
signalée.

### Enchaînement

Une seule opération annulable « Restore Circles ». Chaque chaîne est redétectée juste avant sa
reconstruction (reconstruire un cylindre reconstruit aussi son autre extrémité).

## Sorties

- MessageBox, barre d'état et console : nombre de cercles/arcs reconstruits en natif, nombre de
  soudés (non natifs) avec la raison, nombre non soudables ; ou « No broken circle or arc found ».

## Paramètres internes

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| `BASE_TOL` | 0.001" | Tolérance de base |
| `REL_TOL` | 0,5 % | Tolérance relative au rayon |
| `STEP_TOL` | 1 % | Écart relatif admis entre les angles des segments |
| `MAX_STEP` | 60° (+1 %) | Angle maximal d'un segment |
| `MIN_CIRCLE` | 6 | Segments minimum d'un cercle |
| `MIN_ARC` | 3 | Segments minimum d'un arc |

## Limitations

- Un polygone régulier de 6 côtés ou plus (hexagone…) est indiscernable d'un cercle : il devient
  un cercle natif.
- Les faces recréées perdent la position de leur texture et leurs attributs (dictionnaires) ; le
  matériau, la balise et l'orientation sont conservés. Les identifiants d'entités changent.
- Cercle sur une surface courbe (hors cylindre/cône droit), volumes empilés partageant un cercle
  (fraisurage), cylindre oblique, tube sans face, face triangulée : soudure (non natif).
- Les copies d'un groupe partageant la même définition sont modifiées ensemble.
- Sommets d'un cercle non régulièrement répartis : non détecté.

## Interface utilisateur

- **Menu** : Extensions > Re-Cercle > Restore Circles
- **Barre d'outils** : Re-Cercle (icône cercle vert 16×16 / 24×24), info-bulle « Restore broken
  circles and arcs »
- Rechargement en développement : `ReCercle.reload` dans la console Ruby.

## Fichiers

| Fichier | Rôle |
|---------|------|
| `re_cercle.rb` | Loader (`SketchupExtension`) |
| `re_cercle/version.rb` | Constante `VERSION` |
| `re_cercle/main.rb` | Menu, barre d'outils, commande, rapport |
| `re_cercle/detector.rb` | Détection des chaînes (cercles/arcs) et classement |
| `re_cercle/rebuilder.rb` | Reconstruction plane native et soudure de secours |
| `re_cercle/volume.rb` | Détection et reconstruction Push/Pull des cylindres/troncs de cône |
| `re_cercle/icons/*.png` | Icônes de la barre d'outils |
| `tools/spike/test_native_rebuild.rb` | Script console de faisabilité (diagnostic + reconstruction) |
