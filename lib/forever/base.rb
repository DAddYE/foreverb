require 'fileutils'

module Forever
  class Base
    def initialize(options={}, &block)
      options.each { |k,v| send(k, v) }

      Dir.chdir(dir) if exists?(dir)
      FileUtils.mkdir(File.dirname(log), :noop => true) if exists?(log)
      FileUtils.mkdir(File.dirname(pid), :noop => true) if exists?(pid)

      instance_eval(&block)

      stop!

      return if ARGV[0] == "stop" || on_ready.nil?

      fork do
        $0 = "Forever: #{$0}"
        puts "=> Process demonized with pid #{Process.pid}"

        %w(INT TERM KILL).each { |signal| trap(signal)  { stop! } }

        File.open(pid, "w") { |f| f.write(Process.pid.to_s) }

        stream      = exists?(log) ? File.new(log, "w") : '/dev/null'
        stream.sync = true

        STDOUT.reopen(stream)
        STDERR.reopen(STDOUT)

        begin
          on_ready.call
        rescue Exception => e
          Thread.list.reject { |t| t==Thread.current }.map(&:kill)
          on_error[e] if on_error
          stream.print "\n\n%s\n  %s\n\n" % [e.message, e.backtrace.join("\n  ")]
          sleep 30
          retry
        end
      end
    end

    ##
    # Caller file
    #
    def file(value=nil)
      value ? @_file = value : @_file
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
    # Default: dir + 'log/[process_name].log'
    #
    def log(value=nil)
      @_log ||= File.join(dir, "log/#{File.basename(file)}.log") if exists?(dir, file)
      value ? @_log = value : @_log
    end

    ##
    # File were we store pid
    #
    # Default: dir + 'tmp/[process_name].pid'
    #
    def pid(value=nil)
      @_pid ||= File.join(dir, "tmp/#{File.basename(file)}.pid") if exists?(dir, file)
      value ? @_pid = value : @_pid
    end

    ##
    # Search if there is a running process and stop it
    #
    def stop!(kill=true)
      if exists?(pid)
        _pid = File.read(pid).to_i
        puts "=> Found pid #{_pid}..."
        FileUtils.rm_f(pid)
        begin
          puts "=> Killing process #{_pid}..."
          Process.kill(:KILL, _pid)
        rescue Errno::ESRCH => e
          puts "=> #{e.message}"
        end
      else
        puts "=> Pid not found, process seems don't exist!"
      end
    end

    ##
    # Callback raised when an error occour
    #
    def on_error(&block)
      block_given? ? @_on_error = block : @_on_error
    end

    ##
    # Callback to fire when the daemon start
    #
    def on_ready(&block)
      block_given? ? @_on_error = block : @_on_error
    end

    def to_s
      "#<Forever dir:#{dir}, file:#{file}, log:#{log}, pid:#{pid}>"
    end
    alias :inspect :to_s

    def config
      { :dir => dir, :file => file, :log => log, :pid => pid }.to_yaml
    end
    alias :to_yaml :config

    private
      def exists?(*values)
        values.all? { |value| value && File.exist?(value) }
      end
  end # Base
end # Forever