FOREVER_PATH = File.expand_path("../tmp/db.yaml", __FILE__)
require 'rubygems' unless defined?(Gem)
require 'bundler/setup'
require 'rspec'
require 'forever'
require 'fileutils'

ARGV.clear
ARGV << 'up' # now we don't want to start daemons