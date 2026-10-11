# encoding: UTF-8
# Re-Cercle — menu, toolbar and command.
#
# Broken circles and arcs found in the selection (separate segments, plain
# welded Curves, fragmented curves, segments split by extra vertices) are
# rebuilt as native ArcCurves: center inference, radius and segments in
# Entity Info. When SketchUp cannot rebuild one natively, it is welded into
# one Curve (selectable in one click, without center inference).

require 'sketchup.rb'

module ReCercle
  FILES = %w[detector rebuilder volume].freeze

  FILES.each { |f| Sketchup.require(File.join(PLUGIN_DIR, f)) }

  # Command: restores the circles and arcs of the selection, in one
  # undoable operation.
  def self.restore_circles
    model = Sketchup.active_model
    if model.selection.empty?
      UI.messagebox("#{PLUGIN_NAME} — Select edges, faces, groups or components " \
                    'containing broken circles or arcs.', MB_OK)
      return
    end

    chains = Detector.find_chains(Detector.collect_edges(model.selection))
    result = { native: 0, welded: 0, unwelded: 0, reasons: Hash.new(0) }
    unless chains.empty?
      model.start_operation('Restore Circles', true)
      begin
        chains.each_with_index do |found, i|
          Sketchup.status_text = "#{PLUGIN_NAME} — Circle #{i + 1}/#{chains.length}"
          restore_chain(found, result)
        end
        model.commit_operation
      rescue => e
        model.abort_operation
        puts "[#{PLUGIN_NAME}] Error: #{e.message}"
        puts e.backtrace.first(5).join("\n")
        UI.messagebox("#{PLUGIN_NAME} — Error: #{e.message}", MB_OK)
        return
      end
    end
    report(result)
  end

  # Chains are detected again just before their rebuild: rebuilding a
  # cylinder also rebuilds its other end, and may recreate a shared face.
  def self.restore_chain(found, result)
    seed = found.edges.find(&:valid?)
    return unless seed # already rebuilt with its cylinder
    chain = Detector.chain_from(seed)
    return unless chain
    info = Detector.analyse(chain)
    case info[:kind]
    when :planar
      Rebuilder.planar(chain, info[:pieces])
      result[:native] += 1
    when :volume
      Volume.rebuild(chain.entities, info[:volume])
      result[:native] += info[:volume].loops.length
    when :weld
      case Rebuilder.weld(chain)
      when :welded
        result[:welded] += 1
        result[:reasons][info[:reason]] += 1
      when :unavailable
        result[:unwelded] += 1
      end
    end
  end

  def self.report(result)
    lines = []
    if result[:native] > 0
      lines << "#{result[:native]} circle(s)/arc(s) rebuilt as native circles " \
               '(center inference).'
    end
    if result[:welded] > 0
      why = result[:reasons].map { |reason, n| "#{reason} (#{n})" }.join(', ')
      lines << "#{result[:welded]} welded into one curve, not native: #{why}."
    end
    if result[:unwelded] > 0
      lines << "#{result[:unwelded]} could not be welded (SketchUp 2020.1 or later " \
               'is required).'
    end
    lines << 'No broken circle or arc found in the selection.' if lines.empty?
    msg = lines.join("\n")
    Sketchup.status_text = "#{PLUGIN_NAME} — #{lines.join(' ')}"
    puts "[#{PLUGIN_NAME}] #{lines.join(' ')}"
    UI.messagebox("#{PLUGIN_NAME} — #{msg}", MB_OK)
  end

  # Development reload: ReCercle.reload
  def self.reload
    verbose = $VERBOSE
    $VERBOSE = nil
    (FILES + ['main']).each { |f| load File.join(PLUGIN_DIR, "#{f}.rb") }
    puts "[#{PLUGIN_NAME}] Reloaded (#{FILES.size + 1} files)"
  ensure
    $VERBOSE = verbose
  end

  # --- Menu et Toolbar ---
  unless @loaded
    menu = UI.menu('Extensions').add_submenu(PLUGIN_NAME)
    menu.add_item('Restore Circles') { self.restore_circles }

    toolbar = UI::Toolbar.new(PLUGIN_NAME)
    cmd = UI::Command.new('Restore Circles') { self.restore_circles }
    cmd.tooltip = 'Restore broken circles and arcs'
    cmd.status_bar_text = 'Rebuilds broken circles and arcs of the selection as native ' \
                          'circles (center inference)'

    icon_path = File.join(File.dirname(__FILE__), 'icons')
    small_icon = File.join(icon_path, 're_cercle_16.png')
    large_icon = File.join(icon_path, 're_cercle_24.png')
    cmd.small_icon = small_icon if File.exist?(small_icon)
    cmd.large_icon = large_icon if File.exist?(large_icon)

    toolbar.add_item(cmd)
    toolbar.show

    puts "[#{PLUGIN_NAME}] v#{VERSION} loaded"
    @loaded = true
  end

end
