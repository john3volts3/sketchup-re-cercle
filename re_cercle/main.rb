module ReCercle

  TOLERANCE = 0.1
  MIN_SEGMENTS = 8

  def self.restore_circles
    model = Sketchup.active_model
    selection = model.selection

    if selection.empty?
      UI.messagebox("Sélectionnez un ou plusieurs objets contenant des cercles à restaurer.", MB_OK)
      return
    end

    # Collecter tous les edges de la sélection (y compris dans les groupes/composants)
    all_edges = collect_edges(selection)
    puts "[Re-Cercle] Edges collectés : #{all_edges.length}"

    if all_edges.empty?
      UI.messagebox("Aucun edge trouvé dans la sélection.", MB_OK)
      return
    end

    model.start_operation('Re-Cercle — Restaurer les cercles', true)
    begin
      circles_found = 0

      # --- Étape 1 : Edges libres (pas dans une curve) ---
      loose_edges = all_edges.select { |e| e.valid? && e.curve.nil? }
      puts "[Re-Cercle] Edges libres (sans curve) : #{loose_edges.length}"

      circles_from_loose = find_circles_by_geometry(loose_edges)
      puts "[Re-Cercle] Cercles détectés dans edges libres : #{circles_from_loose.length}"

      circles_from_loose.each do |circle_edges|
        entities_context = find_entities_context(circle_edges.first)
        if entities_context
          puts "[Re-Cercle]   Weld de #{circle_edges.length} edges"
          entities_context.weld(circle_edges)
          circles_found += 1
        end
      end

      # --- Étape 2 : Edges dans des Curves fragmentées ---
      curved_edges = all_edges.select { |e| e.valid? && e.curve }
      puts "[Re-Cercle] Edges avec curve : #{curved_edges.length}"

      curve_groups = group_by_circle_geometry(curved_edges)
      puts "[Re-Cercle] Groupes de curves fragmentées : #{curve_groups.length}"

      curve_groups.each do |group|
        curves = group.map { |e| e.curve }.compact.uniq
        next if curves.length <= 1

        next if group.length < MIN_SEGMENTS
        if edges_form_circle?(group)
          entities_context = find_entities_context(group.first)
          if entities_context
            puts "[Re-Cercle]   Weld curves fragmentées : #{group.length} edges"
            entities_context.weld(group)
            circles_found += 1
          end
        end
      end

      model.commit_operation

      Sketchup.status_text = "Re-Cercle — #{circles_found} cercle(s) restauré(s)"
      puts "[Re-Cercle] Terminé : #{circles_found} cercle(s) restauré(s)"
      if circles_found == 0
        UI.messagebox("Aucun cercle cassé détecté dans la sélection.", MB_OK)
      else
        UI.messagebox("#{circles_found} cercle(s) restauré(s) avec succès.", MB_OK)
      end

    rescue => e
      model.abort_operation
      UI.messagebox("Erreur Re-Cercle : #{e.message}\n#{e.backtrace.first(5).join("\n")}", MB_OK)
    end
  end

  # Détecte les cercles par géométrie (circumcircle) parmi des edges libres
  def self.find_circles_by_geometry(edges)
    return [] if edges.empty?

    # Construire l'adjacence vertex -> edges (uniquement parmi ces edges)
    adj = {}
    edges.each do |e|
      [e.start, e.end].each do |v|
        vid = v.entityID
        adj[vid] ||= []
        adj[vid] << e
      end
    end

    processed = {}
    circles = []

    edges.each do |edge|
      next if processed[edge.entityID]

      # Collecter TOUS les voisins aux deux extrémités
      all_neighbors = []
      [edge.start, edge.end].each do |vertex|
        (adj[vertex.entityID] || []).each do |e|
          next if e == edge || processed[e.entityID]
          all_neighbors << { adj_edge: e, shared_vertex: vertex }
        end
      end
      next if all_neighbors.empty?

      # Essayer chaque voisin jusqu'à trouver un cercle valide
      found = false
      all_neighbors.each do |neighbor_info|
        next if found
        adj_edge = neighbor_info[:adj_edge]
        shared_v = neighbor_info[:shared_vertex]

        # 3 points : extrémité libre de edge, vertex partagé, extrémité libre de adj_edge
        p2 = shared_v.position
        p1 = (edge.start == shared_v) ? edge.end.position : edge.start.position
        p3 = (adj_edge.start == shared_v) ? adj_edge.end.position : adj_edge.start.position

        # Calculer le circumcircle
        circle_info = compute_circumcircle(p1, p2, p3)
        next unless circle_info

        center = circle_info[:center]
        radius = circle_info[:radius]
        normal = circle_info[:normal]

        # Tolérance adaptée au rayon (absolue pour petits cercles, relative pour grands)
        dist_tol = [TOLERANCE, radius * 0.005].max

        # Trouver tous les edges qui correspondent à ce cercle
        matching = edges.select do |e|
          next false if processed[e.entityID]
          next false unless e.valid?
          d1 = (e.start.position.distance(center) - radius).abs
          d2 = (e.end.position.distance(center) - radius).abs
          next false unless d1 < dist_tol && d2 < dist_tol
          # Vérifier coplanarité avec vecteurs normalisés
          v1 = center.vector_to(e.start.position)
          v2 = center.vector_to(e.end.position)
          next false if v1.length < 0.001 || v2.length < 0.001
          v1.normalize!
          v2.normalize!
          next false unless v1.dot(normal).abs < 0.01 && v2.dot(normal).abs < 0.01
          true
        end

        next if matching.length < MIN_SEGMENTS
        next unless closed_chain?(matching)

        puts "[Re-Cercle]   Cercle trouvé : centre=(#{center.x.round(1)}, #{center.y.round(1)}, #{center.z.round(1)}), r=#{radius.round(2)}, #{matching.length} segments"
        matching.each { |e| processed[e.entityID] = true }
        circles << matching
        found = true
      end
    end

    circles
  end

  # Calcule le circumcircle de 3 points (centre, rayon, normale)
  def self.compute_circumcircle(p1, p2, p3)
    v1 = Geom::Vector3d.new(p2.x - p1.x, p2.y - p1.y, p2.z - p1.z)
    v2 = Geom::Vector3d.new(p3.x - p1.x, p3.y - p1.y, p3.z - p1.z)

    normal = v1.cross(v2)
    return nil if normal.length < 0.001
    normal.normalize!

    # Milieux des segments p1-p2 et p1-p3
    m1 = Geom::Point3d.new((p1.x + p2.x) / 2.0, (p1.y + p2.y) / 2.0, (p1.z + p2.z) / 2.0)
    m2 = Geom::Point3d.new((p1.x + p3.x) / 2.0, (p1.y + p3.y) / 2.0, (p1.z + p3.z) / 2.0)

    # Directions des médiatrices (perpendiculaires aux segments, dans le plan)
    d1 = v1.cross(normal)
    d2 = v2.cross(normal)

    # Intersection des deux médiatrices : m1 + t*d1 = m2 + s*d2
    delta = Geom::Vector3d.new(m2.x - m1.x, m2.y - m1.y, m2.z - m1.z)
    d1_cross_d2 = d1.cross(d2)
    denom = d1_cross_d2.dot(d1_cross_d2)
    return nil if denom < 1e-10

    t = delta.cross(d2).dot(d1_cross_d2) / denom

    center = Geom::Point3d.new(m1.x + t * d1.x, m1.y + t * d1.y, m1.z + t * d1.z)
    radius = center.distance(p1)

    return nil if radius < 0.01

    { center: center, radius: radius, normal: normal }
  end

  # Collecte récursive des edges dans la sélection
  def self.collect_edges(entities)
    edges = []
    entities.each do |entity|
      case entity
      when Sketchup::Edge
        edges << entity
      when Sketchup::Group
        edges.concat(collect_edges_from_entities(entity.entities))
      when Sketchup::ComponentInstance
        edges.concat(collect_edges_from_entities(entity.definition.entities))
      when Sketchup::Face
        entity.edges.each { |e| edges << e }
      end
    end
    edges.uniq
  end

  def self.collect_edges_from_entities(entities)
    edges = []
    entities.grep(Sketchup::Edge) { |e| edges << e }
    entities.grep(Sketchup::Group) { |g| edges.concat(collect_edges_from_entities(g.entities)) }
    entities.grep(Sketchup::ComponentInstance) { |c| edges.concat(collect_edges_from_entities(c.definition.entities)) }
    edges
  end

  # Vérifie si une chaîne est fermée (forme une boucle)
  def self.closed_chain?(chain)
    vertex_count = {}
    chain.each do |edge|
      [edge.start.entityID, edge.end.entityID].each do |vid|
        vertex_count[vid] = (vertex_count[vid] || 0) + 1
      end
    end
    vertex_count.values.all? { |c| c == 2 }
  end

  # Vérifie si un ensemble d'edges forme géométriquement un cercle
  def self.edges_form_circle?(edges)
    points = collect_unique_points(edges)
    return false if points.length < MIN_SEGMENTS

    n = points.length.to_f
    cx = points.inject(0.0) { |s, p| s + p.x.to_f } / n
    cy = points.inject(0.0) { |s, p| s + p.y.to_f } / n
    cz = points.inject(0.0) { |s, p| s + p.z.to_f } / n
    center = Geom::Point3d.new(cx, cy, cz)

    dists = points.map { |p| p.distance(center).to_f }
    avg_r = dists.inject(0.0, :+) / dists.length
    return false if avg_r < 0.01

    max_dev = dists.map { |d| (d - avg_r).abs }.max
    dist_tol = [TOLERANCE, avg_r * 0.005].max
    return false unless max_dev < dist_tol

    return false unless points_coplanar?(points, center)
    true
  end

  def self.points_coplanar?(points, center)
    return true if points.length < 4

    v1 = center.vector_to(points[0])
    quarter = points.length / 4
    v2 = center.vector_to(points[quarter])

    normal = v1.cross(v2)
    return false if normal.length < 0.001
    normal.normalize!

    points.all? do |p|
      vec = center.vector_to(p)
      len = vec.length
      next true if len < 0.001
      (vec.dot(normal) / len).abs < 0.01
    end
  end

  def self.collect_unique_points(edges)
    seen = {}
    points = []
    edges.each do |edge|
      [edge.start, edge.end].each do |vertex|
        vid = vertex.entityID
        unless seen[vid]
          seen[vid] = true
          points << vertex.position
        end
      end
    end
    points
  end

  # Groupe les edges courbés par géométrie de cercle similaire
  def self.group_by_circle_geometry(edges)
    return [] if edges.empty?

    by_curve = {}
    edges.each do |e|
      next unless e.valid? && e.curve
      cid = e.curve.entityID
      by_curve[cid] ||= { edges: [], center: nil, radius: nil, normal: nil }
      by_curve[cid][:edges] << e
    end

    by_curve.each_value do |info|
      points = collect_unique_points(info[:edges])
      next if points.length < 3
      n = points.length.to_f
      cx = points.inject(0.0) { |s, p| s + p.x.to_f } / n
      cy = points.inject(0.0) { |s, p| s + p.y.to_f } / n
      cz = points.inject(0.0) { |s, p| s + p.z.to_f } / n
      info[:center] = Geom::Point3d.new(cx, cy, cz)

      dists = points.map { |p| p.distance(info[:center]).to_f }
      info[:radius] = dists.inject(0.0, :+) / dists.length

      v1 = info[:center].vector_to(points[0])
      quarter = [points.length / 4, 1].max
      v2 = info[:center].vector_to(points[quarter])
      normal = v1.cross(v2)
      info[:normal] = normal.length > 0.001 ? normal.normalize! : nil
    end

    groups = []
    curve_infos = by_curve.values.select { |info| info[:center] && info[:normal] }
    used = {}

    curve_infos.each_with_index do |info_a, i|
      next if used[i]
      group = info_a[:edges].dup
      used[i] = true

      curve_infos.each_with_index do |info_b, j|
        next if used[j]
        next unless info_a[:center].distance(info_b[:center]) < TOLERANCE
        next unless (info_a[:radius] - info_b[:radius]).abs < TOLERANCE
        dot = info_a[:normal].dot(info_b[:normal]).abs
        next unless dot > 0.99
        group.concat(info_b[:edges])
        used[j] = true
      end

      groups << group if group.length >= MIN_SEGMENTS
    end

    groups
  end

  def self.find_entities_context(edge)
    return nil unless edge.valid?
    edge.parent.entities
  end

  # --- Menu et Toolbar ---
  unless @loaded
    menu = UI.menu('Extensions').add_submenu('Re-Cercle')
    menu.add_item('Restaurer les cercles') { self.restore_circles }

    toolbar = UI::Toolbar.new('Re-Cercle')
    cmd = UI::Command.new('Restaurer les cercles') { self.restore_circles }
    cmd.tooltip = 'Restaurer les cercles cassés'
    cmd.status_bar_text = 'Restaure les cercles cassés en vraies courbes sélectionnables en un clic'

    icon_path = File.join(File.dirname(__FILE__), 'icons')
    small_icon = File.join(icon_path, 're_cercle_16.png')
    large_icon = File.join(icon_path, 're_cercle_24.png')
    cmd.small_icon = small_icon if File.exist?(small_icon)
    cmd.large_icon = large_icon if File.exist?(large_icon)

    toolbar.add_item(cmd)
    toolbar.show

    @loaded = true
  end

end
