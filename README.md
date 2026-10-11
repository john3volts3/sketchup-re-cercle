# Re-Cercle — SketchUp extension

[Version française](README.fr.md) · [User manual](docs/MANUAL.en.md)

Repairs **broken circles and arcs** into **true native SketchUp circles and arcs**: center
inference, radius and segments in *Entity Info*, one-click selection.

## Problem solved

Some operations (solid tools, intersections, imports, explode…) break circles: they become
separate segments, welded curves without center inference, curves in several pieces, or segments
split by extra vertices. Re-Cercle analyses the current geometry only — not how it was made — and
rebuilds each circle or arc exactly where it was.

## Features

- Circles (6 segments or more) and arcs (3 segments or more), in any plane.
- Select one segment, faces, or whole groups/components (explored recursively).
- Rebuilt as **native** circles/arcs, same center, radius, segment count and vertex positions:
  - flat circles and arcs: free circles, discs, holes in a face, rounded corners;
  - circle crossed by a line: rebuilt as native arcs between the crossings;
  - end circles of straight holes and pins (cylinders, truncated cones): rebuilt with a native
    Push/Pull, both ends become native.
- Neighbouring faces are kept with their materials (front and back), tag and orientation; holes stay
  open.
- When SketchUp cannot rebuild a native circle (curved surface, stacked holes such as a
  countersink, oblique cylinder…), it is **welded** into one curve (one click selects it, but no
  center inference) and the reason is reported.
- One undo step per command.

## Usage

1. Select the broken circles/arcs: one segment of each, faces, or groups/components.
2. Click the **Re-Cercle** toolbar button (or *Extensions > Re-Cercle > Restore Circles*).
3. A message reports how many circles/arcs were rebuilt natively and how many were welded.

## Installation

Install `build/re_cercle.rbz` with *Window > Extension Manager > Install Extension*.

## Compatibility

SketchUp 2021 tested (Windows). The weld fallback requires SketchUp 2020.1 or later.

## Limitations

- A regular polygon with 6 sides or more cannot be told from a circle: it becomes a native circle.
- Rebuilt faces lose their texture position and attributes (material, tag and orientation are kept).
- Inside a component, all instances change.

## License

MIT
