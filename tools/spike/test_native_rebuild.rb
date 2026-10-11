# encoding: UTF-8
# Spike test — Re-Cercle v2: rebuild broken circles and arcs as native
# ArcCurves (center inference, Entity Info) instead of welded Curves.
#
# Only the current geometry is analysed, not how it was made:
#   - a chain of edges whose corners lie on one circle, turning by the same
#     angle at each corner (equal chords); an edge split into collinear
#     pieces counts as one segment;
#   - closed chain = circle (6+ segments), open chain = arc (3+ segments).
#
# Rebuild methods tested:
#   PLANAR  every face touching the chain lies in its plane: snapshot the
#           faces, erase the chain, add_arc (same center, radius, segment
#           count and phase), find_faces, restore materials, tags and
#           orientation, erase new faces filling a former void (hole).
#           Corners with a hard line attached split the chain into arcs
#           (key question: does an arc whose ends touch existing edges
#           stay native?).
#   VOLUME  end circle of a straight cylinder or truncated cone: Push/Pull
#           rebuild of Circle Re-Segment with the same segment count (the
#           Circle Re-Segment extension must be installed and enabled).
#   Other cases are only reported (the plugin will weld them).
#
# Usage (Ruby Console):
#   1. load '<project folder>/tools/spike/test_native_rebuild.rb'
#   2. Select one segment of each broken circle/arc (inside its open group),
#      or select groups/components (every chain inside is analysed).
#   3. ReCercleSpike.diag     -> report only, nothing is changed
#      ReCercleSpike.rebuild  -> rebuild + report (Ctrl+Z undoes it all)

module ReCercleSpike
  TAG        = '[Re-Cercle spike]'.freeze unless defined?(TAG)
  BASE_TOL   = 0.001 unless defined?(BASE_TOL)  # inches, SketchUp tolerance
  REL_TOL    = 0.005 unless defined?(REL_TOL)   # relative to the radius
  STEP_TOL   = 0.01 unless defined?(STEP_TOL)   # relative, between segments
  MAX_STEP   = Math::PI / 3 * 1.01 unless defined?(MAX_STEP) # 6 per turn
  MIN_CIRCLE = 6 unless defined?(MIN_CIRCLE)
  MIN_ARC    = 3 unless defined?(MIN_ARC)
  MAX_RUNS   = 10_000 unless defined?(MAX_RUNS)

  unless defined?(Run)
    # Straight polygon segment: one edge, or collinear edges (split points).
    # vertices: ordered from a to b.
    Run = Struct.new(:edges, :vertices) do
      def a
        vertices.first
      end

      def b
        vertices.last
      end

      def reverse
        Run.new(edges.reverse, vertices.reverse)
      end
    end
  end

  unless defined?(Chain)
    # Runs turn counterclockwise about +normal+ by +step+ (radians).
    Chain = Struct.new(:entities, :runs, :closed, :center, :normal, :radius, :step) do
      def edges
        runs.flat_map(&:edges)
      end

      # Polygon corners (run ends), in order.
      def corners
        list = runs.map(&:a)
        list << runs.last.b unless closed
        list
      end

      # Extra vertices splitting a segment into collinear edges.
      def splits
        runs.flat_map { |r| r.vertices[1..-2] }
      end
    end
  end

  # --- Commands --------------------------------------------------------------

  def self.diag
    chains = find_chains(seed_edges(Sketchup.active_model.selection))
    out "#{chains.length} circle(s)/arc(s) found in the selection"
    chains.each_with_index { |chain, i| report(i, chain, analyse(chain)) }
    nil
  end

  def self.rebuild
    model = Sketchup.active_model
    chains = find_chains(seed_edges(model.selection))
    out "#{chains.length} circle(s)/arc(s) found in the selection"
    return nil if chains.empty?
    model.start_operation('Re-Cercle spike rebuild', true)
    begin
      chains.each_with_index do |found, i|
        seed = found.runs.first.edges.first
        unless seed.valid?
          out "Chain #{i + 1}: already rebuilt with its volume"
          next
        end
        chain = chain_from(seed)
        unless chain
          out "Chain #{i + 1}: no longer found"
          next
        end
        info = analyse(chain)
        report(i, chain, info)
        case info[:kind]
        when :native then out '    -> already native, skipped'
        when :planar then rebuild_planar(chain, info)
        when :volume then rebuild_volume(chain, info)
        else out "    -> not rebuilt (#{info[:reason]}): the plugin will weld it"
        end
      end
      model.commit_operation
    rescue => e
      model.abort_operation
      out "ERROR: #{e.class}: #{e.message}"
      puts e.backtrace.first(8)
    end
    nil
  end

  # --- Collection ------------------------------------------------------------

  def self.seed_edges(selection)
    list = []
    selection.each do |ent|
      case ent
      when Sketchup::Edge then list << ent
      when Sketchup::Face then list.concat(ent.edges)
      when Sketchup::Group then list.concat(all_edges(ent.entities))
      when Sketchup::ComponentInstance then list.concat(all_edges(ent.definition.entities))
      end
    end
    list.uniq
  end

  def self.all_edges(entities)
    list = entities.grep(Sketchup::Edge)
    entities.grep(Sketchup::Group) { |g| list.concat(all_edges(g.entities)) }
    entities.grep(Sketchup::ComponentInstance) do |c|
      list.concat(all_edges(c.definition.entities))
    end
    list
  end

  def self.find_chains(edges)
    done = {}
    chains = []
    edges.each do |edge|
      next if done[edge] || !edge.valid?
      done[edge] = true
      chain = chain_from(edge)
      next unless chain
      chain.edges.each { |e| done[e] = true }
      chains << chain
    end
    chains
  end

  # --- Detection -------------------------------------------------------------

  def self.tol(radius)
    [BASE_TOL, radius * REL_TOL].max
  end

  def self.scale(vector, factor)
    Geom::Vector3d.new(vector.x * factor, vector.y * factor, vector.z * factor)
  end

  # Circle through 3 points: [center, normal, radius], or nil if collinear.
  # p1 -> p2 -> p3 turn counterclockwise about the normal.
  def self.circumcircle(p1, p2, p3)
    a = p3.vector_to(p1)
    b = p3.vector_to(p2)
    axb = a.cross(b)
    d = axb.dot(axb).to_f
    return nil if d < 1e-12
    num = (scale(b, a.dot(a)) - scale(a, b.dot(b))).cross(axb)
    center = p3 + scale(num, 0.5 / d)
    [center, axb.normalize, center.distance(p1).to_f]
  end

  def self.signed_angle(center, normal, p, q)
    u = center.vector_to(p)
    v = center.vector_to(q)
    return 0.0 if u.length.to_f < 1e-12 || v.length.to_f < 1e-12
    ang = u.angle_between(v)
    u.cross(v).dot(normal) < 0 ? -ang : ang
  end

  def self.on_circle?(pt, center, normal, radius)
    v = center.vector_to(pt)
    t = tol(radius)
    (v.length.to_f - radius).abs < t && v.dot(normal).abs < t
  end

  # Maximal straight run of collinear edges containing +edge+.
  def self.run_of(edge)
    edges = [edge]
    verts = [edge.start, edge.end]
    2.times do
      loop do
        v = verts.last
        dir = verts[-2].position.vector_to(v.position)
        nxt = v.edges.select do |e|
          e != edges.last &&
            v.position.vector_to(e.other_vertex(v).position).samedirection?(dir)
        end
        break unless nxt.length == 1 && !edges.include?(nxt.first)
        edges << nxt.first
        verts << nxt.first.other_vertex(v)
      end
      edges.reverse!
      verts.reverse!
    end
    Run.new(edges, verts)
  end

  # Runs leaving +vertex+ (oriented from it), made of edges not in +used+.
  def self.runs_from(vertex, used)
    runs = vertex.edges.reject { |e| used[e] }.map do |e|
      run = run_of(e)
      next nil if run.edges.any? { |x| used[x] }
      if run.a == vertex
        run
      elsif run.b == vertex
        run.reverse
      end
    end
    runs.compact.uniq { |r| r.edges.first.entityID }
  end

  # Run continuing the polygon from +vertex+ by +step+ (signed), or nil.
  def self.next_run(vertex, used, center, normal, radius, step)
    best = nil
    best_err = nil
    runs_from(vertex, used).each do |run|
      q = run.b.position
      next unless on_circle?(q, center, normal, radius)
      err = (signed_angle(center, normal, vertex.position, q) - step).abs
      next unless err < step.abs * STEP_TOL
      next if best && err >= best_err
      best = run
      best_err = err
    end
    best
  end

  # Longest circle or arc through +edge+, or nil.
  def self.chain_from(edge)
    seed = run_of(edge)
    best = nil
    [seed, seed.reverse].each do |r0|
      used = {}
      r0.edges.each { |e| used[e] = true }
      runs_from(r0.b, used).each do |r1|
        circle = circumcircle(r0.a.position, r0.b.position, r1.b.position)
        next unless circle
        center, normal, radius = circle
        step = signed_angle(center, normal, r0.a.position, r0.b.position)
        step1 = signed_angle(center, normal, r0.b.position, r1.b.position)
        next unless step > 0 && step <= MAX_STEP
        next unless (step1 - step).abs < step * STEP_TOL
        chain = grow(edge.parent.entities, [r0, r1], center, normal, radius, step)
        best = chain if chain && (best.nil? || chain.runs.length > best.runs.length)
      end
    end
    best
  end

  def self.grow(entities, runs, center, normal, radius, step)
    used = {}
    runs.each { |r| r.edges.each { |e| used[e] = true } }
    closed = false
    loop do
      if runs.last.b == runs.first.a
        closed = true
        break
      end
      break if runs.length > MAX_RUNS
      run = next_run(runs.last.b, used, center, normal, radius, step)
      break unless run
      run.edges.each { |e| used[e] = true }
      runs << run
    end
    unless closed
      loop do
        break if runs.length > MAX_RUNS
        run = next_run(runs.first.a, used, center, normal, radius, -step)
        break unless run
        run.edges.each { |e| used[e] = true }
        runs.unshift(run.reverse)
      end
    end
    return nil if runs.length < (closed ? MIN_CIRCLE : MIN_ARC)
    chain = Chain.new(entities, runs, closed, center, normal, radius, step)
    refine(chain)
    chain
  end

  # Center and radius from three corners spread along the chain.
  def self.refine(chain)
    c = chain.corners
    n = c.length
    picks = chain.closed ? [c[0], c[n / 3], c[2 * n / 3]] : [c[0], c[n / 2], c[-1]]
    return if picks.uniq.length < 3
    circle = circumcircle(*picks.map(&:position))
    return unless circle && circle[1].dot(chain.normal) > 0
    chain.center, chain.normal, chain.radius = circle
    chain.step = chain.closed ? 2 * Math::PI / chain.runs.length : sweep_of(chain, chain.runs) / chain.runs.length
  end

  def self.sweep_of(chain, runs)
    runs.inject(0.0) do |sum, r|
      sum + signed_angle(chain.center, chain.normal, r.a.position, r.b.position)
    end
  end

  # Fraction of a segment left at an open end (collinear with the expected
  # next segment, ending inside the circle), or nil.
  def self.partial_end(chain, vertex, step)
    used = {}
    chain.edges.each { |e| used[e] = true }
    rot = Geom::Transformation.rotation(chain.center, chain.normal, step)
    expected = vertex.position.transform(rot)
    full = vertex.position.distance(expected).to_f
    dir = vertex.position.vector_to(expected)
    runs_from(vertex, used).each do |run|
      q = run.b.position
      d = vertex.position.distance(q).to_f
      next unless d < full * (1 - STEP_TOL)
      next unless vertex.position.vector_to(q).samedirection?(dir)
      next unless q.distance_to_line([vertex.position, expected]).to_f < tol(chain.radius)
      return d / full
    end
    nil
  end

  # --- Analysis --------------------------------------------------------------

  def self.analyse(chain)
    edge_set = {}
    chain.edges.each { |e| edge_set[e] = true }
    foreign = ->(v) { v.edges.reject { |e| edge_set[e] } }
    hard = ->(e) { !e.soft? && !e.hidden? }
    corners = chain.corners
    inner = chain.closed ? corners : corners[1..-2]
    attached = inner.select { |v| foreign.call(v).any?(&hard) }
    split_attached = chain.splits.reject { |v| foreign.call(v).empty? }
    foreign_edges = (inner + chain.splits).flat_map { |v| foreign.call(v) }.uniq
    t = tol(chain.radius)
    faces = chain.edges.flat_map(&:faces).uniq
    planar, other = faces.partition do |f|
      f.normal.parallel?(chain.normal) &&
        chain.center.vector_to(f.vertices.first.position).dot(chain.normal).abs < t
    end
    info = {
      attached: attached, split_attached: split_attached,
      hard: foreign_edges.count(&hard), soft: foreign_edges.count { |e| !hard.call(e) },
      planar: planar, other: other, pieces: pieces_of(chain, attached)
    }
    if native?(chain, [chain.runs]) || native?(chain, info[:pieces])
      info[:kind] = :native
    elsif !other.empty?
      info[:volume], info[:reason] = volume_of(chain, other)
      info[:kind] = info[:volume] ? :volume : :weld
    elsif !split_attached.empty?
      info[:kind] = :weld
      info[:reason] = 'line attached inside a segment'
    elsif info[:soft] > 0
      info[:kind] = :weld
      info[:reason] = 'soft/hidden edges attached in the plane (triangulated face?)'
    else
      info[:kind] = :planar
    end
    info
  end

  # Runs split at corners where hard lines are attached: each piece becomes
  # one native arc (a full circle when nothing is attached).
  def self.pieces_of(chain, attached)
    runs = chain.runs
    cut = {}
    attached.each { |v| cut[v] = true }
    if chain.closed
      first = runs.index { |r| cut[r.a] }
      return [runs] unless first
      runs = runs.rotate(first)
    end
    pieces = [[]]
    runs.each do |r|
      pieces << [] if cut[r.a] && !pieces.last.empty?
      pieces.last << r
    end
    pieces
  end

  def self.native?(chain, pieces)
    return false unless chain.splits.empty?
    pieces.all? do |runs|
      edges = runs.flat_map(&:edges)
      curve = edges.first.curve
      curve.is_a?(Sketchup::ArcCurve) && curve.count_edges == edges.length &&
        edges.all? { |e| e.curve == curve }
    end
  end

  # Circle Re-Segment volume whose end circle is this chain: [volume, nil]
  # or [nil, reason].
  def self.volume_of(chain, faces)
    unless defined?(CircleReSegment::Detector) && defined?(CircleReSegment::Resegmenter)
      return [nil, 'not planar; Circle Re-Segment not loaded']
    end
    det = CircleReSegment::Detector
    corner_set = {}
    chain.corners.each { |v| corner_set[v] = true }
    seen = {}
    reason = nil
    faces.each do |f|
      next if seen[f]
      surface = det.surface_of(f)
      surface.each { |s| seen[s] = true }
      vol, why = det.build(surface)
      return [vol, nil] if vol && vol.loops.any? { |l| l.vertices.any? { |v| corner_set[v] } }
      reason ||= why
    end
    [nil, "not planar; volume: #{reason || 'not found'}"]
  end

  # --- Rebuild ---------------------------------------------------------------

  def self.rebuild_planar(chain, info)
    ents = chain.entities
    edge_set = {}
    chain.edges.each { |e| edge_set[e] = true }
    snaps = info[:planar].map { |f| snapshot_face(f, edge_set) }
    holes = snaps.flat_map { |s| s[:holes] }
    ref = chain.edges.first
    eprops = [ref.layer, ref.soft?, ref.smooth?, ref.hidden?, ref.material]
    existing = {}
    ents.grep(Sketchup::Face).each { |f| existing[f.entityID] = true }
    plans = info[:pieces].map do |runs|
      full = chain.closed && runs.length == chain.runs.length
      sweep = full ? 2 * Math::PI : sweep_of(chain, runs)
      [runs.first.a.position.clone, sweep, runs.length]
    end

    ents.erase_entities(chain.edges)
    arcs = plans.map do |start, sweep, n|
      xaxis = chain.center.vector_to(start)
      xaxis -= scale(chain.normal, xaxis.dot(chain.normal)) # exactly in the plane
      xaxis.normalize!
      ents.add_arc(chain.center, xaxis, chain.normal, chain.radius, 0, sweep, n)
    end
    arcs.each_with_index { |edges, k| out "    piece #{k + 1} after add_arc: #{describe(edges)}" }
    arcs.flatten.each do |e|
      next unless e.valid?
      e.layer, e.soft, e.smooth, e.hidden, e.material = eprops
    end
    arcs.each do |edges|
      e = edges.find(&:valid?)
      e.find_faces if e
    end
    repair_holes(ents, holes)
    restored, erased, blind = repair_faces(ents, snaps, existing)
    arcs.each_with_index { |edges, k| out "    piece #{k + 1} final: #{describe(edges)}" }
    msg = "    faces: #{snaps.length} before, #{restored} restored, #{erased} erased"
    msg += " (#{blind} face(s) without probe point: nothing erased)" if blind > 0
    out msg
  end

  def self.rebuild_volume(chain, info)
    vol = info[:volume]
    frames = vol.loops.map { |l| [l.center.clone, nil, l.normal.clone, l.radius] }
    CircleReSegment::Resegmenter.resegment(chain.entities, vol, chain.runs.length)
    frames.each_with_index do |frame, k|
      edges = CircleReSegment::Resegmenter.ring_edges(chain.entities, frame)
      out "    end circle #{k + 1} final: #{describe(edges)}"
    end
  end

  def self.snapshot_face(face, edge_set)
    holes = face.loops.reject(&:outer?).reject { |lp| lp.edges.any? { |e| edge_set[e] } }
    {
      normal: face.normal.clone, material: face.material,
      back_material: face.back_material, layer: face.layer,
      probe: probe_point(face, edge_set),
      holes: holes.map { |lp| lp.vertices.map { |v| v.position.clone } }
    }
  end

  # Point inside +face+, close to one of the chain edges (the rebuilt arc
  # has the same chords, so the point stays on the same side).
  def self.probe_point(face, edge_set)
    face.edges.select { |e| edge_set[e] }.each do |e|
      p1 = e.start.position
      p2 = e.end.position
      side = face.normal.cross(p1.vector_to(p2))
      next if side.length.to_f < 1e-12
      side.normalize!
      mid = Geom.linear_combination(0.5, p1, 0.5, p2)
      len = p1.distance(p2).to_f
      [0.05, 0.01, 0.002].each do |k|
        d = [len * k, BASE_TOL * 2].max
        [1, -1].each do |s|
          pt = mid + scale(side, d * s)
          return pt if face.classify_point(pt) == Sketchup::Face::PointInside
        end
      end
    end
    nil
  end

  # A face rebuilt over a former hole may cover its edges without being
  # split: find_faces on one hole edge splits it (from Circle Re-Segment).
  def self.repair_holes(ents, holes)
    t = BASE_TOL * 10
    near = ->(p, h) { h.any? { |q| p.distance(q) < t } }
    holes.each do |h|
      edge = ents.grep(Sketchup::Edge).find do |ed|
        near.call(ed.start.position, h) && near.call(ed.end.position, h)
      end
      edge.find_faces if edge
    end
  end

  # New faces containing a probe point get the former face properties; the
  # others fill a former void (hole) and are erased. Returns
  # [restored, erased, faces without probe].
  def self.repair_faces(ents, snaps, existing)
    restored = 0
    erased = 0
    blind = snaps.count { |s| s[:probe].nil? }
    ents.grep(Sketchup::Face).each do |f|
      next if !f.valid? || existing[f.entityID]
      snap = snaps.find do |s|
        s[:probe] && f.classify_point(s[:probe]) == Sketchup::Face::PointInside
      end
      if snap
        f.reverse! if f.normal.dot(snap[:normal]) < 0
        f.material = snap[:material]
        f.back_material = snap[:back_material]
        f.layer = snap[:layer]
        restored += 1
      elsif blind.zero?
        f.erase!
        erased += 1
      end
    end
    [restored, erased, blind]
  end

  # --- Report ----------------------------------------------------------------

  def self.out(msg)
    puts "#{TAG} #{msg}"
  end

  def self.context_name(entities)
    owner = entities.parent
    return 'model' if owner.is_a?(Sketchup::Model)
    "#{owner.group? ? 'group' : 'component'} '#{owner.name}'"
  end

  def self.fmt(pt)
    "(#{pt.x.to_f.to_l}, #{pt.y.to_f.to_l}, #{pt.z.to_f.to_l})"
  end

  def self.describe(edges)
    edges = edges.select(&:valid?)
    return 'no valid edge' if edges.empty?
    curves = edges.map(&:curve).uniq.compact
    arcs = curves.grep(Sketchup::ArcCurve)
    parts = []
    loose = edges.count { |e| e.curve.nil? }
    parts << "#{loose} loose" if loose > 0
    plain = curves.length - arcs.length
    parts << "#{plain} plain Curve(s)" if plain > 0
    unless arcs.empty?
      a = arcs.first
      sweep = (a.end_angle - a.start_angle).radians.round(1)
      parts << "#{arcs.length} ArcCurve(s) (first: #{a.count_edges} edges, " \
               "r=#{a.radius.to_f.to_l}, #{sweep} deg)"
    end
    verdict = curves.length == 1 && arcs.length == 1 && edges.all?(&:curve) &&
              arcs.first.count_edges == edges.length ? ' => NATIVE' : ''
    "#{edges.length} edges: #{parts.join(', ')}#{verdict}"
  end

  def self.report(i, chain, info)
    corners = chain.corners
    dev = corners.map { |v| (chain.center.distance(v.position).to_f - chain.radius).abs }.max
    kind = chain.closed ? 'CIRCLE' : "ARC #{sweep_of(chain, chain.runs).radians.round(1)} deg"
    out "Chain #{i + 1} — #{context_name(chain.entities)}: #{kind}, " \
        "#{chain.runs.length} segments (#{chain.edges.length} edges, " \
        "#{chain.splits.length} split point(s)), r=#{chain.radius.to_l}, " \
        "center #{fmt(chain.center)}, max deviation #{dev.to_l}"
    out "    now: #{describe(chain.edges)}"
    out "    faces: #{info[:planar].length} in the plane, #{info[:other].length} other; " \
        "attached edges: #{info[:hard]} hard, #{info[:soft]} soft/hidden; " \
        "hard lines at #{info[:attached].length} corner(s), " \
        "#{info[:split_attached].length} inside a segment"
    unless chain.closed
      starts = partial_end(chain, chain.runs.first.a, -chain.step)
      ends = partial_end(chain, chain.runs.last.b, chain.step)
      if starts || ends
        out "    partial segment: start #{starts ? "#{(starts * 100).round}%" : '-'}, " \
            "end #{ends ? "#{(ends * 100).round}%" : '-'}"
      end
    end
    case info[:kind]
    when :native then out '    => already NATIVE'
    when :planar then out "    => PLANAR rebuild: #{info[:pieces].length} native arc(s)/circle"
    when :volume then out "    => VOLUME rebuild (Circle Re-Segment: #{info[:volume].kind})"
    else out "    => WELD only (#{info[:reason]})"
    end
  end
end

puts "#{ReCercleSpike::TAG} loaded. Select, then run ReCercleSpike.diag or ReCercleSpike.rebuild"
