require 'rubygems'
Gem::manage_gems
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
    s.platform  =   Gem::Platform::RUBY
    s.name      =   "growler"
    s.version   =   "0.5"
    s.author    =   "Sander Hartlage"
    s.email     =   "sander dot hartlage at gmail dot com"
    s.summary   =   "Growl support for your Ruby applications."
    s.files     =   FileList['lib/*.rb', 'test/*'].to_a
    s.require_path  = "lib"
    s.test_files    = Dir.glob('tests/*.rb')
    s.has_rdoc      = true
    s.extra_rdoc_files  =   ["README", "CHANGELOG"]
    s.requirements << "RubyCocoa; there's no gem, but if you have Macports you can 'sudo port install rb-cocoa'."
end

Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_tar = true
end