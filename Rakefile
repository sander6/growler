require 'rubygems'
Gem::manage_gems
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
    s.platform          =   Gem::Platform::RUBY
    s.name              =   "growler"
    s.version           =   "0.6.1"
    s.author            =   "Sander Hartlage"
    s.email             =   "sander6 at rubyforge dot org"
    s.homepage          =   ""
    s.rubyforge_project =   ""
    s.summary           =   "Growl support for your Ruby applications"
    s.files             =   FileList['lib/*.rb', 'lib/growler/*.rb', 'test/*'].to_a
    s.require_path      =   "lib"
    s.test_files        =   Dir.glob('tests/*.rb')
    s.has_rdoc          =   true
    s.extra_rdoc_files  =   ["README", "CHANGELOG"]
    s.requirements      <<  "RubyObjC"
    s.add_dependency('RubyObjC')
end

Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_tar = true
end