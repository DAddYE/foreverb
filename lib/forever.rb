require "forever/base"

module Forever
  extend self

  def run(options={}, &block)
    caller = caller(1).map { |line| line.split(/:(?=\d|in )/)[0,1] }.flatten.first
    options[:dir]    ||= File.expand_path('../../', caller) # => we presume we are calling it from a bin|script dir
    options[:caller] ||= caller
    Base.new(options, &block)
  end # run
end # Forever