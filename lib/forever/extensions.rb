LOG_FORMAT  = "[%s] %s"        unless defined?(LOG_FORMAT)
DATE_FORMAT = "%d/%m %H:%M:%S" unless defined?(DATE_FORMAT)

class Numeric
  def seconds; self; end
  alias :second :seconds

  def minutes; self * 60; end
  alias :minute :minutes

  def hours; self * 3600; end
  alias :hour :hours

  def days; self * 86400; end
  alias :day :days
end

module Kernel
  def puts(text="")
    text  = LOG_FORMAT % [Time.now.strftime(DATE_FORMAT), text.to_s]
    text += "\n" unless text[-1] == ?\n
    print text; $stdout.flush
    text
  end
  alias :log :puts
end