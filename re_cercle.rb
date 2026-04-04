require 'sketchup'
require 'extensions'

module ReCercle
  ext = SketchupExtension.new('Re-Cercle', File.join('re_cercle', 'main'))
  ext.version = '1.0.0'
  ext.description = 'Restaure les cercles cassés (suites de edges) en vraies courbes sélectionnables en un clic.'
  ext.creator = 'Claude Code'
  ext.copyright = '2026'
  Sketchup.register_extension(ext, true)
end
