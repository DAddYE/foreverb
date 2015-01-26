require 'fileutils'

module Forever

  class Base
    attr_reader :started_at

    def initialize(options={}, &block)
      @options = options
      forking = options.delete(:fork)

      # Run others methods
      options.each { |k,v| send(k, v) if respond_to?(k) }

      instance_eval(&block)

      # Setup directories
      Dir.chdir(dir)
      Dir.mkdir(tmp) unless File.exist?(tmp)
      Dir.mkdir(File.dirname(log)) if log && !File.exist?(File.dirname(log))

      write_config!

      case ARGV[0]
        when 'config'
          print config.to_yaml
          exit
        when 'start', 'restart', 'up', nil
          stop
        when 'run', 'live'
          detach = false
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
        when 'remove'
          stop
          remove
          exit
        else
          print <<-RUBY.gsub(/ {10}/,'') % name
            Usage: \e[1m./%s\e[0m [start|stop|kill|restart|config|update]

            Commands:

              start      stop (if present) the daemon and perform a start
              live       run in no-deamon mode
              stop       stop the daemon if a during when it is idle
              restart    same as start
              kill       force stop by sending a KILL signal to the process
              config     show the current daemons config
              update     update the daemon config
              remove     removes the daemon config

          RUBY
          exit
      end

      clean_tmp!

      # Enable REE - http://www.rubyenterpriseedition.com/faq.html#adapt_apps_for_cow
      GC.copy_on_write_friendly = true if GC.respond_to?(:copy_on_write_friendly=)

      maybe_fork(detach) do
        Process.setsid if detach != false

        $0 = "Forever: #{$0}" unless ENV['DONT_TOUCH_PS']
        print "[\e[90m%s\e[0m] Process %s with pid \e[1m%d\e[0m with \e[1m%s\e[0m and Forever v.%s\n" %
          [name, detach != false ? :daemonized : :running, Process.pid, forking ? :fork : :thread, Forever::VERSION]

        %w(INT TERM).each { |signal| trap(signal)  { stop! } }
        trap(:HUP) do
          IO.open(1, 'w'){ |s| s.puts config }
        end

        File.open(pid, "w") { |f| f.write(Process.pid.to_s) } if pid

        stream      = log ? File.new(log, @options[:append_log] ? 'a' : 'w') : File.open('/dev/null', 'w')
        stream.sync = true

        STDOUT.reopen(stream)
        STDERR.reopen(STDOUT)

        @started_at = Time.now

        # Invoke our before :all filters
        filters[:before][:all].each { |block| safe_call(block) }

        # Store pids of childs
        pids = []

        # Start deamons
        until stopping?
          current_queue = 1

          jobs.each do |job|
            next unless job.time?(Time.now)
            if queue && current_queue > queue
              puts "\n\nThe queue limit of #{queue} has been exceeded.\n\n"
              on_limit_exceeded ? on_limit_exceeded.call : sleep(60)
              break
            end
            if forking
              begin
                GC.start
                pids << Process.detach(fork { job_call(job) })
              rescue Errno::EAGAIN
                puts "\n\nWait all processes since os cannot create a new one\n\n"
                Process.waitall
              end
            else
              Thread.new { job_call(job) }
            end
            current_queue += 1
          end

          # Detach zombies, our ps will be happier
          pids.delete_if { |p| p.stop? }

          sleep 0.5
        end


        # Invoke our after :all filters
        filters[:after][:all].each { |block| safe_call(block) }

        # If we are here it means we are exiting so we can remove the pid and pending stop.txt
        clean_tmp!
      end

      self
    end

    ##
    # Define a new job task
    #
    # Example:
    #   every 1.second, :at => '12:00' do
    #     my_long_task
    #   end
    #
    def every(period, options={}, &block)
      jobs << Forever::Job.new(period, options.merge!(:dir => dir), &block)
    end

    ##
    # Our job list
    #
    def jobs
      @_jobs ||= []
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
    # Queue size
    #
    def queue(value=nil)
      value ? @_queue = value : @_queue
    end

    ##
    # Base working Directory
    #
    def dir(value=nil)
      value ? @_dir = value : @_dir
    end
    alias :workspace :dir

    ##
    # Temp directory, used to store pids and jobs status
    #
    def tmp
      File.join(dir, 'tmp')
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
      @_pid ||= File.join(tmp, "#{name}.pid") if exists?(dir, file)
      value.nil? ? @_pid : @_pid = value
    end

    ##
    # Search if there is a running process and stop it
    #
    def stop!
      FileUtils.rm_f(stop_txt)
      if running?
        pid_was = File.read(pid).to_i
        print "[\e[90m%s\e[0m] Killing process \e[1m%d\e[0m...\n" % [name, pid_was]
        filters[:after][:all].each { |block| safe_call(block) }
        clean_tmp!
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
    # Remove the daemon from the config file
    #
    def remove
      print "[\e[90m%s\e[0m] Removed the daemon from the config " % name
      config_was = File.exist?(FOREVER_PATH) ? YAML.load_file(FOREVER_PATH) : []
      config_was.delete_if { |conf| conf[:file] == file }
      File.open(FOREVER_PATH, "w") { |f| f.write config_was.to_yaml }
    end

    ##
    # Callback raised when an error occour
    #
    def on_error(&block)
      block_given? ? @_on_error = block : @_on_error
    end

    ##
    # Callback raised when queue limit was exceeded
    #
    def on_limit_exceeded(&block)
      block_given? ? @_on_limit_exceeded = block : @_on_limit_exceeded
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
        print "[\e[90m%s\e[0m] Pid \e[1mnot found\e[0m, process seems doesn't exist!\n" % name unless silent
        return false
      end

      is_running = begin
        Process.kill(0, current)
      rescue Errno::ESRCH
        false
      end

      is_running
    end

    ##
    # Before :all or :each jobs hook
    #
    def before(filter, &block)
      raise "Filter #{filter.inspect} not supported, available options are: :each, :all" unless [:each, :all].include?(filter)
      filters[:before][filter] << block
    end

    ##
    # After :all or :each jobs hook
    #
    def after(filter, &block)
      raise "Filter #{filter.inspect} not supported, available options are: :each, :all" unless [:each, :all].include?(filter)
      filters[:after][filter] << block
    end

    ##
    # Return config of current worker in a hash
    #
    def config
      { :dir => dir, :file => file, :log => log, :pid => pid }
    end

    ##
    # Convert forever object in a readable string showing current config
    #
    def to_s
      "#<Forever dir:#{dir}, file:#{file}, log:#{log}, pid:#{pid} jobs:#{jobs.size}>"
    end
    alias :inspect :to_s

    private

    def filters
      @_filters ||= {
        :before => { :each => [], :all => [] },
        :after  => { :each => [], :all => [] }
      }
    end

    def stopping?
      File.exist?(stop_txt) && File.mtime(stop_txt) > started_at
    end

    def maybe_fork(detach,&block)
      if detach != false
        fork &block
      else
        yield
      end
    end

    def write_config!
      config_was = File.exist?(FOREVER_PATH) ? YAML.load_file(FOREVER_PATH) : []
      config_was.delete_if { |conf| conf.nil? || conf.empty? || conf[:file] == file }
      config_was << config
      File.open(FOREVER_PATH, "w") { |f| f.write config_was.to_yaml }
    end

    def exists?(*values)
      values.all? { |value| value && File.exist?(value) }
    end

    def job_call(job)
      return unless job.time?(Time.now)
      job.run!
      filters[:before][:each].each { |block| safe_call(block) }
      safe_call(job)
      filters[:after][:each].each { |block| safe_call(block) }
    ensure
      job.stop!
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
      @_stop_txt ||= File.join(tmp, 'stop.txt')
    end

    def clean_tmp!
      return unless File.exist?(tmp)
      Dir[File.join(tmp, '*.job')].each { |f| FileUtils.rm_rf(f) }
      FileUtils.rm_rf(pid)
    end
  end # Base
end # Forever
