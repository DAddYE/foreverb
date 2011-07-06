require 'fileutils'

module Forever
  class Base
    def initialize(options={})
      options.each { |k,v| send(k, v) }

      Dir.chdir(dir)
      Dir.mkdir(File.dirname(log)) if log && !File.exist?(File.dirname(log))
      Dir.mkdir(File.dirname(pid)) if pid && !File.exist?(File.dirname(pid))

      stop!

      exit if ARGV[0] == "stop"

      fork do
        $0 = "Forever: #{caller}"
        puts "=> Process daemonized with pid #{Process.pid}"

        require 'rubygems'
        require 'mail'

        File.open(pid, "w") { |f| f.write(Process.pid.to_s) }

        stream      = log ? File.new(log, "w") : '/dev/null'
        stream.sync = true

        STDOUT.reopen(stream)
        STDERR.reopen(STDOUT)

        begin
          yield
        rescue Exception => e
          Thread.list.reject { |t| t==Thread.current }.map(&:kill)
          on_error.call(e) if on_error
          stream.print "\n\n%s\n  %s\n\n" % [e.message, e.backtrace.join("\n  ")]
          sleep 30
          retry
        end
      end
    end

    ##
    # Caller file
    #
    def caller(value=nil)
      value ? @_caller = value : @_caller
    end

    ##
    # Base working Directory
    #
    def dir(value=nil)
      value ? @_dir = value : @_dir
    end

    ##
    # File were we redirect STOUT and STDERR, can be false.
    #
    # Default: dir + 'log/production.log'
    #
    def log(value=nil)
      @_log ||= File.join(dir, 'log/production.log')
      value ? @_log = value : @_log
    end

    ##
    # File were we store pid
    #
    # Default: dir + 'tmp/pid'
    #
    def pid(value=nil)
      @_pid ||= File.join(dir, 'tmp/pid')
      value ? @_pid = value : @_pid
    end

    ##
    # Search if there is a running process and stop it
    #
    def stop!
      if File.exist?(pid)
        _pid = File.read(pid).to_i
        puts "=> Found pid #{_pid}..."
        begin
          Process.kill(:KILL, _pid)
          puts "=> Sending KILL process #{_pid}"
        rescue
          puts "=> Process not running!"
        ensure
          FileUtils.rm_f(pid)
        end
      else
        puts "=> Pid not found, process seems that don't exist!"
      end
    end

    ##
    # Callback raised when an error occour
    #
    def on_error(&block)
      block_given? ? @_on_error = block : @_on_error
    end
  end # Base
end # Forever