require 'rubygems'
Gem::manage_gems
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
    s.platform  =   Gem::Platform::RUBY
    s.name      =   "growler"
    s.version   =   "0.4.3"
    s.author    =   "Sander Hartlage"
    s.email     =   "sander dot hartlage at gmail dot com"
    s.summary   =   "A simple, Rubyish wrapper for Growl's CLI, growlnotify."
    s.files     =   FileList['lib/*.rb', 'test/*'].to_a
    s.require_path  = "lib"
    s.test_files    = Dir.glob('tests/*.rb')
    s.has_rdoc      = false
    s.extra_rdoc_files  =   ["README"]
    s.requirements << "RubyCocoa; there's no gem, but if you have Macports you can 'sudo port install rb-cocoa'."
end

Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_tar = true
end