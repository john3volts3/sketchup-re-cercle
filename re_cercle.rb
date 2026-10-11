# encoding: UTF-8
# Re-Cercle — repair broken circles and arcs into native SketchUp circles.
# Main loader (extension entry point).

require 'sketchup.rb'
require 'extensions.rb'

module ReCercle
  PLUGIN_NAME = 'Re-Cercle'.freeze

  file = __FILE__.dup
  file.force_encoding('UTF-8') if file.respond_to?(:force_encoding)
  PLUGIN_ID  = File.basename(file, '.rb').freeze
  PLUGIN_DIR = File.join(File.dirname(file), PLUGIN_ID).freeze

  require File.join(PLUGIN_DIR, 'version')

  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new(PLUGIN_NAME, File.join(PLUGIN_DIR, 'main'))
    ext.version = VERSION
    ext.description = 'Repairs broken circles and arcs (separate segments, welded curves) ' \
                      'into native SketchUp circles and arcs with center inference.'
    ext.creator = 'Claude Code'
    ext.copyright = '2026'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
