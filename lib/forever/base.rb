require 'fileutils'

module Forever

  class Base
    include Every
    attr_reader :started_at

    def initialize(options={}, &block)
      forking = options.delete(:fork)

      # Run others methods
      options.each { |k,v| send(k, v) }

      instance_eval(&block)

      raise 'No jobs defined!' if jobs.empty?

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
        when 'update'
          print "[\e[90m%s\e[0m] Config written in \e[1m%s\e[0m\n" % [name, FOREVER_PATH]
          exit
        else
          print <<-RUBY.gsub(/ {10}/,'') % name
            Usage: \e[1m./%s\e[0m [start|stop|kill|restart|config|update]

            Commands:

              start      stop (if present) the daemon and perform a start
              stop       stop the daemon if a during when it is idle
              restart    same as start
              kill       force stop by sending a KILL signal to the process
              config     show the current daemons config
              update     update the daemon config

          RUBY
          exit
      end

      # Enable REE - http://www.rubyenterpriseedition.com/faq.html#adapt_apps_for_cow
      GC.copy_on_write_friendly = true if GC.respond_to?(:copy_on_write_friendly=)

      fork do
        $0 = "Forever: #{$0}"
        print "[\e[90m%s\e[0m] Process demonized with pid \e[1m%d\e[0m with \e[1m%s\e[0m and Forever v.%s\n" %
          [name, Process.pid, forking ? :fork : :thread, Forever::VERSION]

        %w(INT TERM KILL).each { |signal| trap(signal)  { stop! } }
        trap(:HUP) do
          IO.open(1, 'w'){ |s| s.puts config }
        end

        File.open(pid, "w") { |f| f.write(Process.pid.to_s) } if pid

        stream      = log ? File.new(log, "w") : File.open('/dev/null', 'w')
        stream.sync = true

        STDOUT.reopen(stream)
        STDERR.reopen(STDOUT)

        @started_at = Time.now

        # Invoke our before :all filters
        before_filters[:all].each { |block| safe_call(block) }

        # Start deamons
        until stopping?
          if forking
            begin
              jobs.select { |job| job.time?(Time.now) }.each do |job|
                Process.fork { job_call(job) }
              end
            rescue Errno::EAGAIN
              puts "\n\nWait all processes since os cannot create a new one\n\n"
              Process.waitall
            end
          else
            jobs.each { |job| Thread.new { job_call(job) } if job.time?(Time.now) }
          end
          sleep 0.5
        end

        # If we are here it means we are exiting so we can remove the pid and pending stop.txt
        FileUtils.rm_f(pid)
        FileUtils.rm_f(stop_txt)

        # Invoke our after :all filters
        after_filters[:all].each { |block| safe_call(block) }
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
    # Daemon name
    #
    def name
      File.basename(file, '.*')
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
      @_log ||= File.join(dir, "log/#{name}.log") if exists?(dir, file)
      value.nil? ? @_log : @_log = value
    end

    ##
    # File were we store pid
    #
    # Default: dir + 'tmp/[process_name].pid'
    #
    def pid(value=nil)
      @_pid ||= File.join(dir, "tmp/#{name}.pid") if exists?(dir, file)
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
        print "[\e[90m%s\e[0m] Killing process \e[1m%d\e[0m...\n" % [name, pid_was]
        after_filters[:all].each { |block| safe_call(block) }
        Process.kill(:KILL, pid_was)
      else
        print "[\e[90m%s\e[0m] Process with \e[1mnot found\e[0m" % name
      end
    end

    ##
    # Perform a soft stop
    #
    def stop
      if running?
        print "[\e[90m%s\e[0m] Waiting the daemon\'s death " % name
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
      after(:all, &block)
    end

    ##
    # Callback to fire when the daemon start (blocking, not in thread)
    #
    def on_ready(&block)
      before(:all, &block)
    end

    ##
    # Returns true if the pid exist and the process is running
    #
    def running?(silent=false)
      if exists?(pid)
        current = File.read(pid).to_i
        print "[\e[90m%s\e[0m] Found pid \e[1m%d\e[0m...\n" % [name, current] unless silent
      else
        print "[\e[90m%s\e[0m] Pid \e[1mnot found\e[0m, process seems don't exist!\n" % name unless silent
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

    def before(filter, &block)
      raise "Filter #{filter.inspect} not supported, available options are: :each, :all" unless [:each, :all].include?(filter)
      before_filters[filter] << block
    end

    def after(filter, &block)
      raise "Filter #{filter.inspect} not supported, available options are: :each, :all" unless [:each, :all].include?(filter)
      after_filters[filter] << block
    end

  private
    def before_filters
      @_before_filters ||= Hash.new { |hash, k| hash[k] = [] }
    end

    def after_filters
      @_after_filters ||= Hash.new { |hash, k| hash[k] = [] }
    end

    def stopping?
      File.exist?(stop_txt) && File.mtime(stop_txt) > started_at
    end

    def write_config!
      config_was = File.exist?(FOREVER_PATH) ? YAML.load_file(FOREVER_PATH) : []
      config_was.delete_if { |conf| conf[:file] == file }
      config_was << config
      File.open(FOREVER_PATH, "w") { |f| f.write config_was.to_yaml }
    end

    def exists?(*values)
      values.all? { |value| value && File.exist?(value) }
    end

    def job_call(job)
      return unless job.time?(Time.now)
      before_filters[:each].each { |block| safe_call(block) }
      safe_call(job)
      after_filters[:each].each { |block| safe_call(block) }
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
