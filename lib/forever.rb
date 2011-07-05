require "forever/version"
require "fileutils"

module Forever
  extend self

  def run(options={}, &block)
    caller_file = caller(1).map { |line| line.split(/:(?=\d|in )/)[0,1] }.flatten.first

    dir  = options[:dir]  || File.expand_path('../../', caller_file) # => we presume we are calling it from a bin/ dir
    name = options[:name] || caller_file

    base     = File.expand_path(dir)
    log_file = File.join(base, 'log/production.log')
    pid_file = File.join(base, 'tmp/pid')

    Dir.chdir(base)
    Dir.mkdir('log') unless File.exist?('log')
    Dir.mkdir('tmp') unless File.exist?('tmp')

    if File.exist?(pid_file)
      pid = File.read(pid_file).to_i
      puts "=> Found pid #{pid}..."
      begin
        Process.kill(:KILL, pid)
        puts "=> Sending KILL process #{pid}"
      rescue
        puts "=> Process not running!"
      ensure
        FileUtils.rm_f(pid_file)
      end
    else
      puts "=> Pid not found, process seems that don't exist!"
    end

    exit if ARGV[0] == "stop"

    fork do
      $0 = "Worker: #{name}"
      puts "=> Process daemonized with pid #{Process.pid}"

      require 'rubygems'
      require 'mail'

      File.open(pid_file, "w") { |f| f.write(Process.pid.to_s) }

      stream      = File.new(log_file, "w")
      stream.sync = true

      STDOUT.reopen(stream)
      STDERR.reopen(STDOUT)

      begin
        yield
      rescue Exception => e
        Thread.list.reject { |t| t==Thread.current }.map(&:kill)
        @_on_error.call(e) if @_on_error
        stream.print "\n\n%s\n  %s\n\n" % [e.message, e.backtrace.join("\n  ")]
        sleep 30
        retry
      end
    end
  end # New

  def on_error(&block)
    @_on_error = block
  end # on_error
end # Forever