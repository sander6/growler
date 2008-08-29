require 'rubygems'
Gem::manage_gems
require 'rake/gempackagetask'
require 'lib/growler/version'

spec = Gem::Specification.new do |s|
    s.platform          =   Gem::Platform::RUBY
    s.name              =   "growler"
    s.version           =   Growl.version
    s.author            =   "Sander Hartlage"
    s.email             =   "sander6 at rubyforge dot org"
    s.homepage          =   "http://github.com/sander6/growler"
    s.rubyforge_project =   "http://rubyforge.org/projects/growler"
    s.summary           =   "Growl support for your Ruby applications"
    s.files             =   %w( LICENSE README Rakefile TODO ) + Dir["{ext,lib,tests}/**/*"]
    s.require_path      =   "lib"
    s.test_files        =   Dir.glob('tests/*.rb')
    s.has_rdoc          =   true
    s.extra_rdoc_files  =   ["README", "LICENSE"]
end

Rake::GemPackageTask.new(spec) do |package|
    package.gem_spec = spec
    # package.need_tar = true
end

desc "Packages the gem and installs it"
task :install => :package do
  system "sudo gem install pkg/growler-#{Growl.version}.gem"
end