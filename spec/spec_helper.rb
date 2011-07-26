FOREVER_PATH = ENV['FOREVER_PATH'] ||= File.expand_path("../tmp/db.yaml", __FILE__)
require 'rubygems' unless defined?(Gem)
require 'bundler/setup'
require 'rspec'
require 'forever'
require 'fileutils'

module Helper
  def capture_stdout(&block)
    stdout_was, $stdout = $stdout, StringIO.new
    block.call
    return $stdout
  ensure
    $stdout = stdout_was
  end

  def run_example
    capture_stdout do
      @forever = Forever.run do
        on_ready { sleep }
      end
    end
  end

  def cli(task)
    output = `#{Gem.ruby} #{File.expand_path('../../bin/foreverb', __FILE__)} #{task}`
  end
end

RSpec.configure do |config|
  config.include(Helper)

  config.before :each do
    FileUtils.rm_rf File.dirname(FOREVER_PATH)
    Dir.mkdir File.dirname(FOREVER_PATH)
    ARGV.clear
  end

  config.after :each do
    FileUtils.rm_rf(File.dirname(FOREVER_PATH))
    if @forever
      capture_stdout { @forever.stop! }
      FileUtils.rm_rf(File.dirname(@forever.log)) if @forever.log
      FileUtils.rm_rf(File.dirname(@forever.pid)) if @forever.pid
    end
    ARGV.clear
  end
end