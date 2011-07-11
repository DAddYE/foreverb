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

      stop!

      return if ARGV[0] == "stop"

      fork do
        $0 = "Forever: #{$0}"
        print "=> Process demonized with pid #{Process.pid} with Forever v.#{Forever::VERSION}\n"

        %w(INT TERM KILL).each { |signal| trap(signal)  { stop! } }

        File.open(pid, "w") { |f| f.write(Process.pid.to_s) } if pid

        stream      = log ? File.new(log, "w") : File.open('/dev/null', 'w')
        stream.sync = true

        STDOUT.reopen(stream)
        STDERR.reopen(STDOUT)

        Thread.abort_on_exception = true

        begin
          threads = []
          threads << Thread.new { on_ready.call } if on_ready
          jobs.each do |job|
            threads << Thread.new do
              loop { job.call if job.time?(Time.now); sleep 1 }
            end
          end
          threads.map(&:join)
        rescue Exception => e
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
      if exists?(pid)
        _pid = File.read(pid).to_i
        print "=> Found pid #{_pid}...\n"
        FileUtils.rm_f(pid)
        begin
          print "=> Killing process #{_pid}...\n"
          on_exit.call if on_exit
          Process.kill(:KILL, _pid)
        rescue Errno::ESRCH => e
          puts "=> #{e.message}"
        end
      else
        print "=> Pid not found, process seems don't exist!\n"
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
    # Callback to fire when the daemon start
    #
    def on_ready(&block)
      block_given? ? @_on_ready = block : @_on_ready
    end

    def to_s
      "#<Forever dir:#{dir}, file:#{file}, log:#{log}, pid:#{pid} jobs:#{jobs.size}>"
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