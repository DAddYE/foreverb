FOREVER_PATH = ENV['FOREVER_PATH'] ||= File.expand_path("../tmp/db.yaml", __FILE__)
require 'rubygems' unless defined?(Gem)
require 'bundler/setup'
require 'minitest/autorun'
require 'forever'
require 'fileutils'
require 'tmpdir'

$dir = File.expand_path('.')

class MiniTest::Spec
  def run_example(options={}, &block)
    block = proc { every(1.second) { puts 'foo' } } unless block_given?
    capture_io { @forever = Forever.run(options, &block) }
  end

  let(:example_filename) { File.expand_path(__FILE__) }

  before do
    Dir.chdir($dir)
    FileUtils.rm_rf File.dirname(FOREVER_PATH)
    Dir.mkdir File.dirname(FOREVER_PATH)
    ARGV.clear
  end

  after do
    FileUtils.rm_rf(File.dirname(FOREVER_PATH))
    if @forever
      capture_io { @forever.stop! }
      FileUtils.rm_rf(File.dirname(@forever.log)) if @forever.log
      FileUtils.rm_rf(File.dirname(@forever.pid)) if @forever.pid # this is deleted by Forever
    end
    Dir.chdir($dir)
    ARGV.clear
  end
end
