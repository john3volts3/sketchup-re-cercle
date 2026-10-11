# Changelog

## [2.0.0] - 2026-10-11

### Added
- Broken circles **and arcs** are rebuilt as **native** SketchUp circles/arcs (center inference,
  radius and segments in Entity Info), with the same center, radius, segment count and vertex
  positions.
- Flat circles and arcs (free circles, discs, holes, rounded corners) rebuilt natively; neighbouring
  faces keep their materials, tag and orientation, holes stay open.
- Circles crossed by lines rebuilt as native arcs between the crossings.
- End circles of straight holes and pins (cylinders, truncated cones) rebuilt with a native
  Push/Pull: both ends become native.
- Segments split by extra vertices are recognised (and merged when rebuilt).
- Report: number rebuilt natively, number welded (not native) with the reason.
- English user interface; README and user manual in English and French.

### Changed
- Detection based on the current geometry only: chains of equal segments turning by the same angle,
  6 segments minimum for a circle, 3 for an arc; tolerance 0.001" or 0.5 % of the radius.
- Weld (plain Curve, no center inference) is now only a fallback when a native rebuild is not
  possible (curved surface, stacked holes, oblique cylinder…).
- Selecting one segment is enough to repair the whole circle.
- Intact native circles and smooth surface rings (e.g. sphere) are left untouched.

## [1.0.0] - 2026-04-04

### Added
- First release: broken circles (closed loops of 8+ loose segments, or fragmented curves) welded
  into one Curve, selectable in one click.
