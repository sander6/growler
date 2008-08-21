require 'rubygems'
Gem::manage_gems
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
    s.platform          =   Gem::Platform::RUBY
    s.name              =   "growler"
    s.version           =   "0.2.0"
    s.author            =   "Sander Hartlage"
    s.email             =   "sander6 at rubyforge dot org"
    s.homepage          =   "http://growler.rubyforge.org/"
    s.rubyforge_project =   "http://rubyforge.org/projects/growler/"
    s.summary           =   "Growl support for your Ruby applications"
    s.files             =   FileList['ext/Growl.framework/*', 'lib/*.rb', 'lib/growler/*.rb', 'lib/growler/extractors/*.rb', 'lib/growler/helpers/*.rb', 'test/*'].to_a
    s.require_path      =   "lib"
    s.test_files        =   Dir.glob('tests/*.rb')
    s.has_rdoc          =   true
    s.extra_rdoc_files  =   ["README", "CHANGELOG"]
end

Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_tar = true
end