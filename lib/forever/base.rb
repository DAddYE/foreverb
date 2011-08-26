require 'fileutils'

module Forever

  class Base
    include Every

    def initialize(options={}, &block)
      options.each { |k,v| send(k, v) }

      instance_eval(&block)

      Dir.chdir(dir) if exists?(dir)
      Dir.mkdir(File.dirname(log)) if log && !File.exist?(File.dirname(log))
      Dir.mkdir(File.dirname(pid)) if pid && !File.exist?(File.dirname(pid))

      write_config!

      case ARGV[0]
        when 'config'
          print config.to_yaml
          exit
        when 'start', 'restart', 'up', nil
          stop
        when 'stop'
          stop
          exit
        when 'kill'
          stop!
          exit
        when 'help', '-h'
          print <<-RUBY.gsub(/ {10}/,'') % File.basename(file)
            Usage: \e[1m./%s\e[0m [start|stop|kill|restart|config]

            Commands:

              start      stop (if present) the daemon and perform a start
              stop       stop the daemon if a during when it is idle
              restart    same as start
              kill       force stop by sending a KILL signal to the process
              config     show the current daemons config

          RUBY
          exit
      end

      fork do
        $0 = "Forever: #{$0}"
        print "=> Process demonized with pid \e[1m#{Process.pid}\e[0m with Forever v.#{Forever::VERSION}\n"

        %w(INT TERM KILL).each { |signal| trap(signal)  { stop! } }
        trap(:HUP) do
          IO.open(1, 'w'){ |s| s.puts config }
        end

        File.open(pid, "w") { |f| f.write(Process.pid.to_s) } if pid

        stream      = log ? File.new(log, "w") : File.open('/dev/null', 'w')
        stream.sync = true

        STDOUT.reopen(stream)
        STDERR.reopen(STDOUT)

        threads = []
        safe_call(on_ready) if on_ready
        started_at = Time.now

        jobs.each do |job|
          threads << Thread.new do
            loop do
              break if File.exist?(stop_txt) && File.mtime(stop_txt) > started_at
              job.time?(Time.now) ? safe_call(job) : sleep(1)
            end
          end
        end

        # Launch our workers
        threads.map(&:join)

        # If we are here it means we are exiting so we can remove the pid and pending stop.txt
        FileUtils.rm_f(pid)
        FileUtils.rm_f(stop_txt)

        on_exit.call if on_exit
      end

      self
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
      value.nil? ? @_log : @_log = value
    end

    ##
    # File were we store pid
    #
    # Default: dir + 'tmp/[process_name].pid'
    #
    def pid(value=nil)
      @_pid ||= File.join(dir, "tmp/#{File.basename(file)}.pid") if exists?(dir, file)
      value.nil? ? @_pid : @_pid = value
    end

    ##
    # Search if there is a running process and stop it
    #
    def stop!
      FileUtils.rm_f(stop_txt)
      if running?
        pid_was = File.read(pid).to_i
        FileUtils.rm_f(pid)
        print "=> Killing process \e[1m%d\e[0m...\n" % pid_was
        on_exit.call if on_exit
        Process.kill(:KILL, pid_was)
      else
        print "=> Process with \e[1mnot found\e[0m"
      end
    end

    ##
    # Perform a soft stop
    #
    def stop
      if running?
        print '=> Waiting the daemon\'s death '
        FileUtils.touch(stop_txt)
        while running?(true)
          print '.'; $stdout.flush
          sleep 1
        end
        print " \e[1mDONE\e[0m\n"
      end
    end

    ##
    # Callback raised when an error occour
    #
    def on_error(&block)
      block_given? ? @_on_error = block : @_on_error
    end

    ##
    # Callback raised when at exit
    #
    def on_exit(&block)
      block_given? ? @_on_exit = block : @_on_exit
    end

    ##
    # Callback to fire when the daemon start (blocking, not in thread)
    #
    def on_ready(&block)
      block_given? ? @_on_ready = block : @_on_ready
    end

    ##
    # Returns true if the pid exist and the process is running
    #
    def running?(silent=false)
      if exists?(pid)
        current = File.read(pid).to_i
        print "=> Found pid \e[1m%d\e[0m...\n" % current unless silent
      else
        print "=> Pid \e[1mnot found\e[0m, process seems don't exist!\n" unless silent
        return false
      end

      is_running = begin
        Process.kill(0, current)
      rescue Errno::ESRCH
        false
      end

      is_running
    end

    def to_s
      "#<Forever dir:#{dir}, file:#{file}, log:#{log}, pid:#{pid} jobs:#{jobs.size}>"
    end
    alias :inspect :to_s

    def config
      { :dir => dir, :file => file, :log => log, :pid => pid }
    end

    private
      def write_config!
        config_was = File.exist?(FOREVER_PATH) ? YAML.load_file(FOREVER_PATH) : []
        config_was.delete_if { |conf| conf[:file] == file }
        config_was << config
        File.open(FOREVER_PATH, "w") { |f| f.write config_was.to_yaml }
      end

      def exists?(*values)
        values.all? { |value| value && File.exist?(value) }
      end

      def safe_call(block)
        begin
          block.call
        rescue Exception => e
          puts "\n\n%s\n  %s\n\n" % [e.message, e.backtrace.join("\n  ")]
          on_error[e] if on_error
        end
      end

      def stop_txt
        @_stop_txt ||= File.join(dir, 'stop.txt')
      end
  end # Base
end # Forever
