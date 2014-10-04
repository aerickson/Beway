require "rdoc/task"
require "rubygems/package_task"
require "rspec/core/rake_task"

task :default => [:spec]

RSpec::Core::RakeTask.new(:spec)

Rake::RDocTask.new do |rd|
  rd.main = "README"
  rd.rdoc_files.include("README", "lib/beway/*.rb")
  rd.rdoc_dir = 'doc'
end

gemspec = Gem::Specification.load "beway.gemspec"
Gem::PackageTask.new(gemspec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end
