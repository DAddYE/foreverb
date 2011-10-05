require 'rubygems' unless defined?(Gem)
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rake/testtask'

%w(install release).each do |task|
  Rake::Task[task].enhance do
    sh "rm -rf pkg"
  end
end

desc 'Bump version on github'
task :bump do
  if `git status -s`.strip == ''
    puts "\e[31mNothing to commit (working directory clean)\e[0m"
  else
    version  = Bundler.load_gemspec(Dir[File.expand_path('../*.gemspec', __FILE__)].first).version
    sh "git add .; git commit -a -m \"Bump to version #{version}\""
  end
end

Rake::TestTask.new(:spec) do |t|
  t.test_files = Dir['spec/**/*_spec.rb']
  t.verbose = true
end

namespace :example do
  Dir['./examples/*'].each do |path|
    next if File.directory?(path)
    name = File.basename(path)
    desc "Run example #{name}"
    task name, :fork do |t, args|
      ENV['FORK'] = args[:fork]
      log = File.expand_path("../log/#{name}.log", path)
      exec "#{Gem.ruby} #{path} && sleep 5 && tail -f -n 150 #{log}; #{path} stop"
    end
  end
end

task :release => :bump
task :default => :spec
