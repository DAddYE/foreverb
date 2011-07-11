require 'rubygems' unless defined?(Gem)
require 'bundler/gem_tasks'

%w(install release).each do |task|
  Rake::Task[task].enhance do
    sh "rm -rf pkg"
  end
end

desc "Bump version on github"
task :bump do
  version = Bundler.load_gemspec(Dir[File.expand_path('../*.gemspec', __FILE__)].first).version
  sh "git add .; git commit -m \"Bump to version #{version}\""
end

task :release => :bump