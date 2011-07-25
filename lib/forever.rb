require 'yaml' unless defined?(YAML)
require "forever/extensions"
require "forever/every"
require "forever/base"
require "forever/version"

YAML::ENGINE.yamler = "syck" if defined?(YAML::ENGINE)

FOREVER_PATH = ENV['FOREVER_PATH'] ||= File.expand_path("~/.foreverb") unless defined?(FOREVER_PATH)
path = File.dirname(FOREVER_PATH)
Dir.mkdir(path) unless File.exist?(path)

module Forever
  extend self

  def run(options={}, &block)
    caller_file = caller(1).map { |line| line.split(/:(?=\d|in )/)[0,1] }.flatten.first
    options[:dir]    ||= File.expand_path('../../', caller_file) # => we presume we are calling it from a bin|script dir
    options[:file]   ||= File.expand_path(caller_file)
    Base.new(options, &block)
  end # run
end # Forever