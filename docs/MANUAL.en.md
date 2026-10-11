# Re-Cercle — User manual

[Version française](MANUEL.fr.md) · [README](../README.md)

Version 2.0.0

## 1. What Re-Cercle does

A native SketchUp circle or arc is one object: one click selects it, the Line tool infers its
center, and *Entity Info* shows its radius. After some operations (solid tools, intersections,
imports, *Explode Curve*…), a circle can lose this: it becomes separate segments, a welded curve
without center inference, several curves, or segments split by extra vertices.

Re-Cercle finds these broken circles and arcs and **rebuilds them as native circles and arcs**, at
the same place, with the same radius and the same number of segments. Only the current geometry
is analysed, not how it was made.

## 2. Usage

1. Select what contains the broken circles or arcs:
   - **one segment** of a circle or arc is enough: the whole circle is found;
   - **faces**: their edges are analysed;
   - **groups and components**: everything inside is analysed, nested groups included.
2. Click the **Re-Cercle** toolbar button, or *Extensions > Re-Cercle > Restore Circles*.
3. Read the message:
   - `N circle(s)/arc(s) rebuilt as native circles (center inference).`
   - `N welded into one curve, not native: <reason>.` — see section 4;
   - `No broken circle or arc found in the selection.` — nothing was changed.
4. *Edit > Undo* (Ctrl+Z) undoes the whole command in one step.

Circles that are already native are left untouched.

## 3. What is recognised

| Shape | Rule |
|-------|------|
| Circle | Closed loop of 6 segments or more, corners on one circle, same angle at each corner |
| Arc | Open chain of 3 segments or more, same rules |
| Split segment | A segment cut into aligned pieces counts as one segment |
| Ignored | Native circles, smooth surface rings (soft or hidden edges, e.g. a sphere) |

Tolerance: 0.001" or 0.5 % of the radius, whichever is larger.

## 4. How each case is repaired

| Case | Result |
|------|--------|
| Free circle, disc, hole in a flat face, rounded corner | **Native** circle or arc |
| Circle crossed by a line at its corners | **Native** arcs between the lines (as SketchUp does) |
| Circle crossed by a line in the middle of a segment | **Native** arcs; the cut segment stays as plain edges |
| Arc ending in the middle of a segment | **Native** arc on the full segments; the partial piece stays a plain edge |
| End of a straight hole or pin (cylinder, truncated cone) | Both ends **native** (rebuilt with Push/Pull) |
| Circle on a curved surface, stacked holes (countersink on a hole), oblique cylinder, tube without end face, triangulated face | **Welded** into one curve: one click selects it, but no center inference |

What is kept: neighbouring faces with their materials (front and back), tag and orientation; holes
in those faces; edge tag, softening and hiding; the smooth wall of a hole.

## 5. Limitations

- A regular polygon with 6 sides or more (hexagon…) looks exactly like a circle: it becomes a
  native circle.
- Rebuilt faces lose their texture position and their attributes; their entity IDs change.
- Inside a component, the definition changes: all instances are repaired. Copies of a group sharing
  the same definition change together.
- A circle whose vertices are not evenly spaced is not recognised.
- The weld fallback requires SketchUp 2020.1 or later; on older versions those circles are left as
  they are and reported.
