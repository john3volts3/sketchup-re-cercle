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
- **FSD.md** — Création de la spécification fonctionnelle
- **`.claude/skills/sketchup-plugin/SKILL.md`** — Création du skill persistant avec sections FSD et Livraison
- **`~/.claude/CLAUDE.md`** — Ajout de la section FSD obligatoire pour tous les projets

## Session du 2026-10-11

- **Cadrage v2** : réparer les cercles ET les arcs cassés en **`ArcCurve` natives** (inférence de centre), à partir de l'état actuel de la géométrie uniquement (pas de son origine). Seuil : 6 segments minimum pour un cercle. Secours si le natif est impossible : soudure `weld` (comportement actuel). Libellés et code en anglais, README et manuel bilingues.
- Analyse de la v1 : tolérance absolue 0.1" trop large pour les petits cercles, centre des fragments de courbe calculé par centroïde (faux pour un arc), cercles mixtes (courbe + arêtes libres) jamais traités, corde rattachée qui fait échouer `closed_chain?`, arcs ignorés, résultat `weld` sans inférence.
- Rappel des résultats de Circle Re-Segment : aucune API ne convertit des arêtes en `ArcCurve` ; `add_arc` posé sur des sommets déjà raccordés est fragmenté ; `add_arc` dans le vide + `find_faces` + `Face#pushpull` donne des cercles natifs. Cylinder Resize répare par `weld` (pas natif).
- `tools/spike/test_native_rebuild.rb` (2026-10-11) — script console de faisabilité : détection par chaînes (coins sur un cercle, pas angulaire constant, segments recoupés fusionnés), `ReCercleSpike.diag` (rapport sans modification) et `ReCercleSpike.rebuild` (reconstruction PLANAR par effacement + `add_arc` + `find_faces` + restauration des faces/trous ; VOLUME par le moteur Push/Pull de Circle Re-Segment). Syntaxe vérifiée (`ruby -wc`), formule du cercle circonscrit vérifiée hors SketchUp. En attente du test utilisateur.
- Test utilisateur du script de faisabilité (2026-10-11) : **toutes les reconstructions natives OK** — cercle libre, disque, disque + face hôte, cercle traversé par une ligne (2 arcs natifs de 180°), 4 coins arrondis (arcs dont les extrémités touchent des arêtes : natifs), cylindre (2 extrémités natives via Push/Pull).
- **Implémentation v2.0.0** (2026-10-11), plan validé par l'utilisateur :
  - `re_cercle/detector.rb` — création : collecte (sélection, groupes/composants récursifs), détection des chaînes (segments recoupés fusionnés), classement `:native` / `:planar` / `:volume` / `:weld`, découpage en arcs aux coins portant une ligne, segments coupés par une ligne laissés tels quels.
  - `re_cercle/rebuilder.rb` — création : reconstruction plane (effacement, `add_arc` même phase, `find_faces`, restauration des faces par point témoin, trous) et soudure de secours.
  - `re_cercle/volume.rb` — création : détection des cylindres/troncs de cône et reconstruction Push/Pull, repris de Circle Re-Segment (boucles détectées par chaînes, points de coupe acceptés, même nombre de segments).
  - `re_cercle/main.rb` — réécrit : commande « Restore Circles » (libellés en anglais), une opération annulable, redétection avant chaque reconstruction, rapport natifs/soudés/non soudables, `ReCercle.reload`.
  - `re_cercle.rb` — loader au format des plugins frères (`PLUGIN_NAME`, `PLUGIN_DIR`, `VERSION`), description en anglais.
  - `re_cercle/version.rb` — 2.0.0.
  - `FSD.md` — réécrit pour la v2.0.0.
  - Syntaxe vérifiée (`ruby -wc`), découpage `pieces_of` testé hors SketchUp (8 cas). Fichiers copiés dans Plugins SketchUp 2021. En attente du test utilisateur (redémarrage de SketchUp nécessaire : loader et nouveaux fichiers).
- `re_cercle/rebuilder.rb` (2026-10-11) — précaution : pas de `find_faces` sur les anciens trous si une face n'a pas de point témoin (la face bouchant le trou ne pourrait pas être supprimée).
- Test utilisateur v2.0.0 sur SketchUp 2021 : **OK** (bouton de la barre d'outils toujours actif).
- **Livraison v2.0.0** (2026-10-11) :
  - `README.md` — réécrit en anglais (fonctionnalités v2, liens vers la version française et le manuel).
  - `README.fr.md` — création (version française).
  - `docs/MANUAL.en.md`, `docs/MANUEL.fr.md` — création du manuel utilisateur bilingue (utilisation, cas reconnus, réparation par cas, limitations).
  - `CHANGELOG.md` — création (2.0.0 et rappel 1.0.0).
  - `FSD.md` — état de validation.
  - Syntaxe Ruby vérifiée, `build/re_cercle.rbz` reconstruit, fichiers déjà copiés dans Plugins SketchUp 2021, commit + push.
